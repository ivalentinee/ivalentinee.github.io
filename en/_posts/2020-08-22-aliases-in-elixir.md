---
layout: post
title:  "Using alias в Elixir"
date:   2020-08-22
categories: programming
uid: aliases-in-elixir
---

This one is short, but I think I should white down this insight.

My main argument (not just against [Ruby](https://www.ruby-lang.org/), but overall) looks like this: "Code should annotate not only dependancies, but dependants".

In case of Elixir dependancies are easy to track just by looking at `alias` and `import` (rarely `use`). However, annotating dependants would make writing code an unpleasant experience. But there's a way.

There're 2 (okay, 1.5) ways to write `alias`:
```elixir
alias SomeProject.SomeModule1
alias SomeProject.SomeModule2
```
and
```elixir
alias SomeProject.{SomeModule1, SomeModule2}
```

I think, that the first way is preferable. Why? Because it automatically "annotates" dependants (spoiler: use `grep`).

Let's suppose there're three modules in our system: `SomeProject.Family.Father`, `SomeProject.Family.Son1`, `SomeProject.Family.Son2`. Module `SomeProject.Family.Father` uses `..Son1` and `..Son2`.

In case of full annotation
```elixir
defmodule SomeProject.Family.Father do
  alias SomeProject.Family.Son1
  alias SomeProject.Family.Son2
```
searching **full** module name `SomeProject.Family.Son1` would tell, that this name is mentioned in `SomeProject.Family.Father`, but using short annotation
```elixir
defmodule SomeProject.Family.Father do
  alias SomeProject.Family.{Son1, Son2}
```
searching **full** module name `SomeProject.Family.Son1` will tell nothing.

One might argue: "But you can search `Son1` and not the full  name?" But that works only for **unique** short names. In case of "`SomeProject.Family1.{Father, Son1, Son2}` and `SomeProject.Family2.{Father, Son1, Son2}`" you'll have to sort out things manually, when `grep` can easily take care of full annotations (hint: `grep` doesn't get tired like you do).

Summary: project should be "greppable", but doing nothing to make it so will render project almost impossible to understand (hello, [Ruby](https://www.ruby-lang.org/)).
