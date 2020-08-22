---
layout: post
title:  "Использование команды alias в Elixir"
date:   2020-08-22
categories: programming
uid: aliases-in-elixir
---

Это будет очень короткая заметка, но, так как озарение внезапное, лучше оставить текстом, чем забыть.

Мой основной довод (не только против [Ruby](https://www.ruby-lang.org/), вообще про написание кода) звучит примерно так: "Код должен иметь чёткие аннотации зависимостей и зависимых модулей".

В случае Elixir зависимости отслеживаются легко, достаточно посмотреть список `alias` и `import` (в редких случаях `use`). Однако строгая аннотация зависимых модулей делала бы написание кода бессмысленно сложным. Но есть выход.

В Elixir есть два (ладно, полтора) способа записи директивы `alias`:
```elixir
alias SomeProject.SomeModule1
alias SomeProject.SomeModule2
```
и
```elixir
alias SomeProject.{SomeModule1, SomeModule2}
```

Но я считаю, что первый способ предпочтительнее. Почему? Потому что он автоматически "делает аннотацию" зависимых модулей (спойлер: нужно использовать `grep`).

Предположим, что в системе (`SomeProject`) есть три модуля: `SomeProject.Family.Father`, `SomeProject.Family.Son1`, `SomeProject.Family.Son2`. Модуль `SomeProject.Family.Father` использует модули `..Son1` и `..Son2`.

В случае полной записи
```elixir
defmodule SomeProject.Family.Father do
  alias SomeProject.Family.Son1
  alias SomeProject.Family.Son2
```
поиск по **полному** имени модуля `SomeProject.Family.Son1` покажет, что это имя используется в модуле `SomeProject.Family.Father`, но при использовании сокращённой записи
```elixir
defmodule SomeProject.Family.Father do
  alias SomeProject.Family.{Son1, Son2}
```
поиск по **полному** имени модуля `SomeProject.Family.Son1` не выдаст ничего.

Можно возразить: "Но можно же искать по имени `Son1`, а не по полному"? Но это работает только в том случае, если короткое имя модуля уникально. То есть в ситуации "`SomeProject.Family1.{Father, Son1, Son2}` и `SomeProject.Family2.{Father, Son1, Son2}`" нужно будет вручную отсеивать ненужные результаты, в то время как при полной аннотации этим мог бы заняться grep (его не жалко, он не устаёт).

Резюмирую: проект должен "грепаться", и если не ничего для этого не предпринимать, изучение проекта может не работать вообще (привет, [Ruby](https://www.ruby-lang.org/)).
