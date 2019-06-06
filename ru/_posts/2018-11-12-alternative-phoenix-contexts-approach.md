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

А побудило меня то, что понадобилось мне в некоторых контекстах использовать одну и ту же модель.

Оригинал предлагает использовать `alias Modulename`. Но выглядит это как костыль. Посему я нашёл свой подход.

В общем делаем небольшой шаг в сторону [разделения архитектурных слоёв](http://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html). Не то чтобы мы уже там были, но ведь и Рим не один день строился.

Описаний будет мало. В основном листинги. Сорян, может быть когда-нибудь добавлю подробное описание.

## Верхнеуровнево
Контексты уезжают в папку `contexts`, модели уезжают в папку `models`, в ту же папку `models` складываем всё, что связано с `Ecto.Query`.

Это слишком коротко, поэтому сейчас я начну ~~пояснять подробнее~~ приводить примеры.

## Увозим модели в `models`
Пожалуй, самый важный пункт. Остальное — следствия.

Под моделями в данном случае подразумеваются файлы, содержащие **схемы данных** (`Ecto.Schema`) и **changeset'ы**:

```elixir
# lib/my_app/models/pizza.ex

defmodule MyApp.Models.Pizza do
  use Ecto.Schema

  import Ecto.Changeset

  schema "pizzas" do
    field(:name, :string)
    field(:description, :string)
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

## Создаём файл для функций выборки
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
  import Ecto.Query, warn: false
  require Ecto.Query
  alias MyApp.Models.Pizza
  alias MyApp.Models.Pizza.Query
  alias MyApp.Repo

  def discounted?(pizza), do: !!pizza.discounted

  def list do
    list_query()
    |> Repo.all()
  end

  def get!(id) do
    Pizza
    |> Repo.get!(id)
  end

  def get_by!(clauses) do
    Pizza
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

  defp list_query do
    Pizza
    |> Query.by_id()
  end
end
```

## Вместо выводов
На этот раз без выводов. Сами решайте, нужно вам это, или нет. Но мне стало удобнее.
