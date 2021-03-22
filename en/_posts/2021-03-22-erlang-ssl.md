---
layout: post
title:  ":ssl and :httpc in Erlang/Elixir"
date:   2021-03-22
categories: programming
math: true
uid: erlang-ssl
---

## Source

This text is a short (very) summary on [ElixirConfEU 2019 speech about ssl in Erlang](https://youtu.be/0jzcPnsE4nQ) from [Bram Verburg](https://twitter.com/voltonez). More to have copy-paste code than to explain anything.

To get a proper explanation on that topic I highly recommend watching the video.

## Problem
Problem is, Erlang `:ssl` is somewhat complicated. Especially for guys like me who knows almost nothing about SSL/TLS.

By default `:ssl` (and `:httpc`) supports TLS connection (successfully connects to TLS hosts) but does not make so securely, because it does not perform server authenticity check. Default options look (somewhat) like this: `[ssl: [verify: :verify_none]]`.

If you want (like me) to perform secure http requests default options do not work.

## Solution
First, turn on authenticity check:
```elixir
verify: :verify_peer
```
Then configure cert file. Ubuntu with `openssl` installed have them at `/etc/ssl/certs/ca-certificates.crt`:
```elixir
cacertfile: '/etc/ssl/certs/ca-certificates.crt'
```
Next, to enable wildcard sertificates we should specify custom (somewhat) hostname check function:
```elixir
customize_hostname_check: [
  match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
]
```
And finally, if you need to connect to an old server with outdated algorithms these algorightms should be enabled:
```elixir
ciphers: :ssl.cipher_suites(:all, :"tlsv1.2")
```

Resulting config looks like this (without `ciphers`):
```elixir
[
  verify: :verify_peer,
  cacertfile: '/etc/ssl/certs/ca-certificates.crt',
  customize_hostname_check: [
    match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
  ]
]
```

And some code with `:httpc`:
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

## Storing configuration
Sometimes it's important to be able to turn server authenticity check off, because insecurely running program is less of an issue than not running at all. In that case there has to be a way to turn it off [without rewriting the program]({% uid_url exploitation-first %}).

I prefer to have a separate module for `:ssl` options which gets configuration from ENV and saves it in [persistent_term](https://erlang.org/doc/man/persistent_term.html):
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
And then use that module:
```elixir
url = 'https://www.google.com:443/'
:httpc.request(:get, {url, []}, [ssl: MyApp.HTTPCSSLOptions.get()], [])
```
