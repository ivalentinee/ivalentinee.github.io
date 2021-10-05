---
layout: post
title:  "Alternative Phoenix Context approach"
date:   2018-11-12
categories: programming
uid: alternative-phoenix-contexts-approach
---

## Intro
For those who don't know what phoenix *contexts* are here's [link](https://hexdocs.pm/phoenix/contexts.html).

The reason for this approach was a need to use the same model in different contexts. I could have gone with `alias MyApp.AnotherContext.MyModel` but that didn't look good.

This approach is a small step towards [architecture layer separation](http://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html). Not like it gets us there, but Rome wasn't built in a day.

There'll be more code listings than descriptions.

## Top-level
Contexts go to `contexts` directory, models go to `models` directory, everything using `Ecto.Query` goes to `models` too.

I know that's too short, so here is ~~explanation~~ a bunch of examples.

## Models go to `models`
That's the most important one. Everything else is more of a consequence.

By "models" a mean files with **schema definitions** (`Ecto.Schema`) and **changesets** (more on that later):
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

That move allowes us to extract storage layer (definitions to be used by ORM). And solves the problem of using models in multiple contexts.

### Create file for DB queries
As "storage" layer is moved out of contexts, is is moved completely:
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

### About changesets
Changesets could be put into separate file (or even files) so schema file is not bloated. Like `lib/my_app/models/pizza/changesets.ex`.

## Use that in contexts
Contexts go to `contexts` folder forming *data processing* layer (can't call it "business logic").
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

## More on changesets (UPD 2021.10.05)
Apart from schemaless changesets my experience with Ecto tells me of two types of changesets: for *storing* and for *processing*.

### Storing changesets
These are used to handle DB errors not as exceptions but as changeset errors.

Main usage for these changesets are [`validate_required`](https://hexdocs.pm/ecto/Ecto.Changeset.html#validate_required/3) for fields which are non-nullable in DB and applying handlers like [`unique_constraint`](https://hexdocs.pm/ecto/Ecto.Changeset.html#unique_constraint/3), [`check_constraint`](https://hexdocs.pm/ecto/Ecto.Changeset.html#check_constraint/3) and [`foreign_key_constraint`](https://hexdocs.pm/ecto/Ecto.Changeset.html#foreign_key_constraint/3).

Should these changesets have casts? That's an open question for me, because it makes no sense to require fields without filling them in. But combining two types of changesets allows us to move `cast`s out of storing changesets.

There should be only one such changeset per model, accepting only other changesets as an argument (which explicitly tells to put `cast` somewhere else).

Example:
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

### Processing changesets
That's where it gets interesting.

These changesets should go to contexts that use them and go before (and with) storing changesets.

For example we have to set `:name` and `:description` at one place but only `:description` at another:
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

So instead of bloating storage layer with processing definitions like `def admin_changeset(struct, params)` and `def manager_changeset(struct, params)` we put 'em to **user story definition** that uses that exact changeset.

### That looks not very good
Because we use the same word "changeset" (and even implementation under the hood) for two different things: *DB handling* and *user input validation and normalization*.

The only thing I can think of to make it better is to name these changesets so it would be clear which changeset is for what.
