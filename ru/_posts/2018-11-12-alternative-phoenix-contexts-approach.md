---
layout: post
title:  "Используем контексты из Phoenix по-другому"
date:   2018-11-12
categories: programming
uid: alternative-phoenix-contexts-approach
---

## Предисловие
Обычно в предисловии я рассказываю, что меня привело к появлению текста статьи. Этот раз — не исключение.

Для тех, кто не знает, что такое *контексты* в phoenix, вот [ссылка](https://hexdocs.pm/phoenix/contexts.html).

А побудило меня то, что понадобилось мне в некоторых контекстах использовать одну и ту же модель. Можно использовать подход вида `alias MyApp.AnotherContext.MyModel`, но выглядит это как костыль.

Описанный мной подход делает небольшой шаг в сторону [разделения архитектурных слоёв](http://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html). Не то чтобы мы уже там были, но ведь и Рим не один день строился.

Описаний будет мало, в основном листинги.

## Верхнеуровнево
Контексты уезжают в папку `contexts`, модели уезжают в папку `models`, в ту же папку `models` складываем всё, что связано с `Ecto.Query`.

Это слишком коротко, поэтому сейчас я начну ~~пояснять подробнее~~ приводить примеры.

## Увозим модели в `models`
Пожалуй, самый важный пункт. Остальное — следствия.

Под моделями в данном случае подразумеваются файлы, содержащие **схемы данных** (`Ecto.Schema`) и **changeset'ы** (про changeset'ы подробно расписано ниже):

```elixir
# lib/my_app/models/pizza.ex

defmodule MyApp.Models.Pizza do
  use Ecto.Schema

  import Ecto.Changeset

  schema "pizzas" do
    field(:name, :string)
    field(:description, :string)
    field(:discounted, :boolean)
    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
  end
end
```

Такой переезд позволяет нам выделить слой работы с хранилищем данных (то есть описания, требуемые для ORM). И заодно решает проблему использования одной модели в нескольких контекстах.

### Создаём файл для функций выборки
Раз уж увозим **слой хранения**, то увозим его полностью:
```elixir
# lib/my_app/models/pizza/query.ex

defmodule MyApp.Models.Pizza.Query do
  import Ecto.Query, warn: false
  require Ecto.Query

  def discounted(query) do
    from(q in query, where: discounted == true)
  end

  def non_discounted(query) do
    from(q in query, where: discounted != true)
  end

  def by_id(query) do
    from(q in query, order_by: [desc: q.id])
  end
end
```

### Тут же про changeset'ы
Changeset'ы тоже можно увезти в отдельный файл (или даже несколько), чтобы не засорять файл со схемой. Например в `lib/my_app/models/pizza/changesets.ex`.

## Используем это всё в контексте
Контексты же уезжают в свою отдельную папку, формируя слой *обработки данных*. Назвать это *бизнес-логикой* у меня ~~язык~~ клавиатура ~~не поворачивается~~ не даёт.

```elixir
# lib/my_app/contexts/pizzas.ex

defmodule MyApp.Contexts.Pizzas do
  alias MyApp.Models.Pizza
  alias MyApp.Models.Pizza.Query
  alias MyApp.Repo

  def list do
    list_query()
    |> Query.non_discounted()
    |> Repo.all()
  end

  def get!(id) do
    Pizza
    |> Query.non_discounted()
    |> Repo.get!(id)
  end

  def get_by!(clauses) do
    Pizza
    |> Query.non_discounted()
    |> Repo.get_by!(clauses)
  end

  def create(params) do
    changeset = Pizza.changeset(%Pizza{}, params)
    Repo.insert(changeset)
  end

  def update(%Pizza{} = pizza, params) do
    pizza
    |> Pizza.changeset(params)
    |> Repo.update()
  end
end
```

## Про changeset'ы (UPD 2021.10.05)
Если не трогать schemaless changeset'ы, то мой опыт общения с Ecto позволяет выделить два вида changeset'ов: для *хранения* и для *обработки*.

### Changeset'ы для хранения
Эти changeset'ы нужны по большей части для того, чтобы ошибки СУБД возвращались не исключениями, а ошибками в changeset'ах.

Это место для того, чтобы делать [`validate_required`](https://hexdocs.pm/ecto/Ecto.Changeset.html#validate_required/3) для полей, которые помечены как обязательные в схеме БД и делать обработки вроде [`unique_constraint`](https://hexdocs.pm/ecto/Ecto.Changeset.html#unique_constraint/3), [`check_constraint`](https://hexdocs.pm/ecto/Ecto.Changeset.html#check_constraint/3) и [`foreign_key_constraint`](https://hexdocs.pm/ecto/Ecto.Changeset.html#foreign_key_constraint/3).

Нужно ли в этих changeset'ах делать какие-либо cast'ы? Для меня это открытый вопрос, потому что было бы нелогично требовать обязательность полей, но при этом эти поля ничем не заполнять. Однако при обязательном комбинировании обоих видов changeset'ов можно ничего здесь не кастовать.

Эти changeset'ы должны быть по одному на "модель", принимать на вход только другие changeset'ы (что позволяет нам __явно__ указать на то, что `cast` должен делаться где-то в другом месте) и, очевидно, описываться внутри файлов модели.

Пример:
```elixir
# lib/my_app/models/pizza.ex

defmodule MyApp.Models.Pizza do
  use Ecto.Schema

  alias Ecto.Changeset
  import Ecto.Changeset

  schema "pizzas" do
    field(:name, :string)
    field(:description, :string)
    field(:discounted, :boolean)
    timestamps()
  end

  def db_changeset(%Changeset{} = changeset) do
    changeset
    |> validate_required([:name])
    |> unique_constraint(:name, name: :unique_name_index)
  end
end
```

### Changeset'ы для обработки
Вот тут всё интереснее.

Эти changeset'ы должны описываться в контестах и использоваться как входные для changeset'ов хранения.

Допустим, в одном месте мы можем редактировать название и описание, а в другом — только описание. В соответствующих контекстах у нас будет следующий (гипотетический) код:
```elixir
defmodule MyApp.Contexts.Admin.Pizzas do
  alias Ecto.Changeset
  alias MyApp.Models.Pizza
  alias MyApp.Repo

  def update(%Pizza{} = pizza, params) do
    pizza
    |> changeset(params)
    |> Repo.update()
  end

  def changeset(%Pizza{} = pizza, params) do
    pizza
    |> Changeset.cast(params, [:name, :description])
    |> Pizza.db_changeset()
  end
end
```
```elixir
defmodule MyApp.Contexts.Manager.Pizzas do
  alias Ecto.Changeset
  alias MyApp.Models.Pizza
  alias MyApp.Repo

  def update(%Pizza{} = pizza, params) do
    pizza
    |> changeset(params)
    |> Repo.update()
  end

  def changeset(%Pizza{} = pizza, params) do
    pizza
    |> Changeset.cast(params, [:description])
    |> Changeset.validate_required([:description])
    |> Pizza.db_changeset()
  end
end
```

В результате вместо того, чтобы плодить в области хранения данных их обработку в виде `def admin_changeset(struct, params)` и `def manager_changeset(struct, params)` мы пишем **специфичные для каждого пользовательского сценария** changeset'ы в том месте, где описываем сам сценарий.

### Выглядит это так себе
Потому что одним и тем же словом "changeset" (да и механизмом, если смотреть под капот) мы описываем два совершенно разных действия: работу с базой данных и работу с пользовательским вводом.

Единственное, что я могу придумать в данной ситуации — делать такие названия changeset'ам, чтобы было понятно, какие относятся к БД, а какие — к обработке пользовательских сценариев.
