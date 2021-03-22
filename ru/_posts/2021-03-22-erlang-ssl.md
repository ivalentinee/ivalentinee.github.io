---
layout: post
title:  ":ssl и :httpc в Erlang/Elixir"
date:   2021-03-22
categories: programming
math: true
uid: erlang-ssl
---

## Источник

Эта статья — краткий (очень) конспект [доклада про ssl с ElixirConfEU 2019](https://youtu.be/0jzcPnsE4nQ) от [Bram Verburg](https://twitter.com/voltonez). Не столько для объяснения, сколько для копирования кода.

Для полноценного изучения вопроса крайне рекомендую посмотреть сам доклад.

## Проблема
В том, что ssl в Erlang — скользкая тема (для тех, кто не шарит, т.е. для меня).

По-умолчанию `:ssl` (и, соответственно, `:httpc`) поддерживают tls (то есть не выдают ошибку при подключении к tls-хостам), но не обеспечивают безопасность соединения, так как не выполняют проверку аутентичности сервера. Опции по-умолчанию выглядят так: `[ssl: [verify: :verify_none]]`.

Если вам (как мне) нужно ходить на сервер, аутентичность которого лучше бы подтверждать, опции по-умолчанию не подходят.

## Решение
Для начала нужно влючить проверку подлинности сервера:
```elixir
verify: :verify_peer
```
Затем указать файл с сертификатами опцией `cacertfile`. В Ubuntu при установленном пакете `openssl` сертификаты лежат в `/etc/ssl/certs/ca-certificates.crt`. Получаем
```elixir
cacertfile: '/etc/ssl/certs/ca-certificates.crt'
```
Далее для возможности работы с wildcard-сертификатами нужно указать функцию проверки доменного имени подходящую для https:
```elixir
customize_hostname_check: [
  match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
]
```
Если нужно обращаться к старому серверу, который по какой-то причине работает со старыми алгоритмами, нужно эти алгоритмы включить:
```elixir
ciphers: :ssl.cipher_suites(:all, :"tlsv1.2")
```

В результате получаем следующую конфигурацию (без `ciphers`):
```elixir
[
  verify: :verify_peer,
  cacertfile: '/etc/ssl/certs/ca-certificates.crt',
  customize_hostname_check: [
    match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
  ]
]
```

И финальный код с `:httpc` выглядит примерно вот так:
```elixir
ssl_options = [
  verify: :verify_peer,
  cacertfile: '/etc/ssl/certs/ca-certificates.crt',
  customize_hostname_check: [
    match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
  ]
]

connection_options = [ssl: ssl_options]
url = 'https://www.google.com:443/'
:httpc.request(:get, {url, []}, connection_options, [])
```

## Сохраняем конфигурацию
Часто так бывает, что из-за каких-то проблем нужно включить `verify_none`. Например, небезопасная работа приложения принесёт меньше бед, чем неработоспособное приложение. В таком случае нужна возможность [управлять подключением без внесения изменений в программу]({% uid_url exploitation-first %}).

Я предпочитаю для такого делать отдельный модуль, который для ускорения работы сохраняет настройки в [persistent_term](https://erlang.org/doc/man/persistent_term.html):
```elixir
defmodule MyApp.HTTPCSSLOptions do
  def get do
    get_stored() || get_from_env!()
  end

  defp get_stored do
    :persistent_term.get(__MODULE__, nil)
  end

  defp get_from_env! do
    options =
      case verify_type() do
        :verify_none -> verify_none_options()
        :verify_peer -> verify_peer_options()
      end

    :persistent_term.put(__MODULE__, options)

    options
  end

  defp verify_type do
    case String.downcase(Application.get_env(:my_app, :ssl)[:verify]) do
      "verify_none" -> :verify_none
      "verify_peer" -> :verify_peer
      _ -> :verify_peer
    end
  end

  defp verify_none_options do
    [verify: :verify_none]
  end

  defp verify_peer_options do
    cacertfile = Application.get_env(:my_app, :ssl)[:casertfile]
    [
      verify: :verify_peer,
      cacertfile: to_charlist(cacertfile),
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ]
    ]
  end
end
```
И затем использовать этот модуль:
```elixir
url = 'https://www.google.com:443/'
:httpc.request(:get, {url, []}, [ssl: MyApp.HTTPCSSLOptions.get()], [])
```
