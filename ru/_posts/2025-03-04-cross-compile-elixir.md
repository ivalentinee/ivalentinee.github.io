---
layout: post
title:  "Кросс-сборка Elixir-релизов amd64→arm64"
date:   2025-03-04
categories: programming
uid: cross-compile-elixir
---

## Введение
Как обычно, начнём с «Зачем?»

Всё очень просто: Elixir-приложение я пишу на машине с amd64, а запускать релиз я буду на arm64 (RaspberryPi).

И — чтобы не потерять рецепт — оставлю тут заметочку.

## А есть простой путь?
Нет. Elixir сам в такое не умеет, а — учитывая тот факт, что в Elixir-релизе лежит весь Erlang/OTP — вариант как со скриптовыми языками не прокатит.

Да, конечно, можно собирать релиз без бинарей и требовать установки Erlang/OTP на машине, где оно будет запускаться, но это не наш метод. Нам надо `tar -xf release.tar.gz && ./bin/release start`.

## А как?
Тут нам на помощь приходят две технологии: [Docker](https://www.docker.com/) и [qemu](https://www.qemu.org/). Конечно, вместо докера можно использовать связку [Buildah](https://buildah.io/) и [Podman](https://podman.io/), но я для такого уже староват.

### Что-то мешает?
Да.

Казалось бы, можно просто добавить `--platform=linux/arm64` в образ `FROM elixir:_version_`, но, увы, есть одна проблема: [qemu не совместим с JIT-компилятором Erlang'а](https://stackoverflow.com/questions/73954808/how-to-run-erlang-in-arm64-docker-image-on-x86-64-host).

А отключается JIT только _при сборке Erlang/OTP_.

### Что делать?
Собирать руками Erlang/OTP и Elixir, принудительно отключив JIT.

Получится что-то примерно такое:
```Dockerfile
FROM --platform=linux/arm64 ubuntu:jammy-20250126

## Build OTP + Elixir
RUN apt update && \
    apt install --no-install-recommends -y apt-utils libncurses-dev libwxgtk3.0-gtk3-dev libssl-dev openssl ca-certificates inotify-tools build-essential wget && \
    apt clean

ENV OTP_VERSION="27.2.4" ELIXIR_VERSION="1.18.2"

ENV BUILD_PATH=/root/elixir \
    OTP_URL="https://github.com/erlang/otp/releases/download/OTP-$OTP_VERSION/otp_src_$OTP_VERSION.tar.gz" \
    ELIXIR_VERSION="1.18.2" \
    ELIXIR_URL="https://github.com/elixir-lang/elixir/archive/v$ELIXIR_VERSION.tar.gz"

RUN mkdir -p $BUILD_PATH && \
    rm -rf $BUILD_PATH && \
    mkdir -p $BUILD_PATH/

RUN cd $BUILD_PATH/ && \
    wget "$OTP_URL" && tar -xf "otp_src_$OTP_VERSION.tar.gz" && \
    cd "$BUILD_PATH/otp_src_$OTP_VERSION" && \
    ./configure --disable-jit && make && make install

RUN cd $BUILD_PATH/ && \
    wget $ELIXIR_URL && tar -xf "v$ELIXIR_VERSION.tar.gz" && \
    cd "$BUILD_PATH/elixir-$ELIXIR_VERSION" && \
    make && make install
```
Ну и дальше собираем релиз в этом образе
```
## Build the app
RUN mkdir /app
WORKDIR /app

ARG RELEASE_NAME=my_app
ENV MIX_ENV=prod RELEASE_NAME=${RELEASE_NAME}

COPY ./mix.exs ./mix.lock /app
RUN mix deps.get && mix deps.compile
RUN mix esbuild.install && mix tailwind.install

COPY . /app
RUN mix compile
RUN mix assets.deploy && mix phx.digest
RUN mix release $RELEASE_NAME
RUN tar -C "./_build/prod/rel/${RELEASE_NAME}" -cf release.tar ./
```

### Собираем образ и вытаскиваем релиз из докера
```shell
docker build -t my_app_arm64 . -f Dockerfile.arm64
docker run --rm -v $(pwd):/build my_app_arm64 bash -c "cp /app/release.tar /build/release.tar"
```

### Работать будет долго
Очень долго. Надо потерпеть. Или купить машинку для сборки вместо ноутбука.

### Получилось не всё
Шаг `RUN mix assets.deploy` у меня застревает — думаю, проще ассеты будет собрать на родной платформе (там всё равно кроме css и js ничего нет) и скопировать в образ перед сборкой релиза.

Для этого в контейнере с родной архитектурой делаем `MIX_ENV=prod mix do assets.deploy, mix phx.digest`, а в Dockerfile.arm64 вместо `RUN mix assets.deploy` делаем `COPY ./priv/static /app/priv/static`.

Полная команда получается такая:
```shell
docker build -t my_app .
docker run --rm -v $(pwd):/app my_app bash -c "MIX_ENV=prod mix assets.deploy"
docker build -t my_app_arm64 . -f Dockerfile.arm64
docker run --rm -v $(pwd):/build my_app_arm64 bash -c "cp /app/release.tar /build/release.tar"
```
