---
layout: post
title:  "Прикручиваем webpack к phoenix 1.3"
date:   2017-10-07
categories: programming
---

## Почему решил написать

Пришла тут мне с elixir-radar'а в ленте [вот эта статеечка](https://blog.danivovich.com/2017/08/30/webpack-phoenix). Ну и я подумал: "А чем, собственно, я хуже?" Да ничем не хуже. Тем более, что у меня подход более радикальный. Да и с докерами.

Сразу скажу, что результат можно посмотреть [тут](https://github.com/ivalentinee/impressioner/tree/master/frontend).

Пост предполагает, что следующий инструкциям **уже имел дело с webpack'ом и phoenix'ом**, потому что я не обещаю, что всё будет хорошо =).

## Почему webpack вместо brunch?

Потому что у меня не завелись css-модули. Я пробовал подключить их с [postcss-brunch](https://github.com/brunch/postcss-brunch), но у меня не получилось, увы. Да и вообще под вебпак куда больше модулей, шире поддержка.

## Изменения в структуре проекта

### 1. Отказался от от phoenix'ового watch'ера

Потому что у меня docker и docker-compose, и я привык распихивать сервисы по контейнерам.

### 2. Перенёс файлы фронта в папку "frontend"

Потому что засовывать целое фронтовое приложение в папку assets... Ну, не знаю. Во-первых, современный фронт уже давно перестал морально быть "ассетами" и зачастую содержит не меньше сложной логики, чем бэк, а во-вторых будет гораздо понятнее, что где искать, если в корне проекта будет папка `/frontend`, а не фронтовые файлы в `/assets/static`.

## Поехали

### Добавляем папку `/frontend`, переделываем package.json и переходим на yarn

#### Переделываем папки

Для начала создаём папку `/frontend` (`mkdir frontend`). В ней будет лежать наше фронтовое приложение. \\

Затем переносим `socket.js` из `/assets` в `/frontend` на случай, если он понадобится в будущем. Для этого надо будет создать подпапки `application` и `application/lib`:
```sh
$ mkdir -p frontend/application/lib
$ cp assets/js/socket.js frontend/application/lib/socket.js
```

Добавляем файл `/frontend/application/app.js`:
```javascript
console.log('It works!');
```

Ну и наконец концами удаляем папку `/assets` (`rm -rf assets`), ибо она нам больше не понадобится.

#### package.json

Теперь добавляем файл `package.json` в корень проекта с примерно таким содержимым (версии пакетов, конечно, лучше поменять на последние):
```json
{
  "repository": {},
  "license": "MIT",
  "scripts": {
    "build": "node ./node_modules/webpack/bin/webpack.js --config frontend/webpack.config.js",
    "watch": "node ./node_modules/webpack/bin/webpack.js -w --config frontend/webpack.config.js"
  },
  "dependencies": {
    // много бабелевых плагинов
    "babel": "^6.23.0",
    "babel-core": "^6.25.0",
    "babel-loader": "^7.1.1",
    "babel-plugin-transform-object-rest-spread": "^6.23.0",
    "babel-polyfill": "^6.23.0",
    "babel-preset-env": "^1.6.0",
    "babel-preset-es2015": "^6.24.1",
    "babel-preset-react": "^6.24.1",
    "babel-runtime": "^6.25.0",
    // и прочих библиотек, которые для предмета поста не важны
    "autoprefixer": "^7.1.2",
    "css-loader": "^0.28.4",
    "eslint": "^4.4.1",
    "extract-text-webpack-plugin": "^3.0.0",
    "file-loader": "^0.11.2",
    "style-loader": "^0.18.2",
    "postcss-loader": "^2.0.6",
    "prop-types": "^15.5.10",
    "react": "^15.6.1",
    "react-dom": "^15.6.1",
    "react-redux": "^5.0.6",
    "redux": "^3.7.2",
    // ну и кэп подсказывает, что это вебпак
    "webpack": "^3.5.1"
    // это файлы, которые необходимы для работы с channels в фениксе.
    "phoenix": "file:./deps/phoenix",
    "phoenix_html": "file:./deps/phoenix_html",
  }
}
```

#### webpack.config.js

Теперь надо создать конфиг для webpack'а. Хотя его можно положить куда угодно, я считаю, что неплохо его сложить в папку `/frontend`.

В конфиге экспорт настроен так, чтобы выходные файлы складывать в `/priv/static/assets` (`app.js` и `app.css`), чтобы потом их мог раздавать сервер приложения.

"Входным" файлом приложения является `/frontend/application/app.js`, что можно увидеть в конфиге, который приведён ниже.

Digest'ами в webpack не занимаюсь, потому что это [делает phoenix](https://hexdocs.pm/phoenix/1.3.0-rc.3/Mix.Tasks.Phoenix.Digest.html).

`/frontend/webpack.config.js`:
```javascript
const ExtractTextPlugin = require('extract-text-webpack-plugin');

module.exports = {
  entry: ['./frontend/application/app.js'],
  output: {
    path: `${__dirname}/../priv/static/assets`,
    filename: 'app.js',
  },
  devtool: 'source-map',
  resolve: {
    extensions: ['.js', '.jsx'],
  },
  module: {
    loaders: [
      {
        test: /\.jsx?$/,
        exclude: /node_modules/,
        loader: 'babel-loader',
      },
      {
        test: /\.css$/,
        use: ExtractTextPlugin.extract({
          fallback: 'style-loader',
          use: [
            {
              loader: 'css-loader',
              options: {
                modules: true,
                localIdentName: '[path][name]__[local]--[hash:base64:5]',
              },
            },
            { loader: 'postcss-loader' },
          ],
        }),
      },
      {
        test: /\.(png|jpg|gif)$/,
        use: [{
          loader: 'file-loader',
          options: {
            publicPath: '/assets/',
          },
        }],
      },
    ],
  },
  plugins: [
    new ExtractTextPlugin('app.css'),
  ],
};
```
Лоадеры, понятное дело, надо переделать под себя.

Ну и `.babelrc` для полноты, хотя это не так важно:
```json
{
  "presets": [
    [
      "env",
      {
        "modules": false
      }
    ],
    "react",
    "es2015",
  ]
}
```

#### (Бонус-контент) создаём структуру папок под проект

"Бонус-контент" это потому, что структура моя заточена под [react](https://reactjs.org/) + [redux](http://redux.js.org/), так что скорее всего её надо будет переделывать под свой проект.

Комментировать не буду особо. Кому надо, то сам разберётся или спросит.

```
/frontend
  /application
    /actionTypes
    /actions
    app.js
    /components
    /constants
    /containers
    /lib
    /reducers
    /sagas
    /store
    webpack.config.js
```

### Раздаём ассеты веб-сервером:

В файле `lib/<projectname>_web/endpoint.ex` строку
```elixir
    only: ~w(css fonts images js favicon.ico robots.txt)
```
надо заменить на такую
```elixir
    only: ~w(assets favicon.ico robots.txt)
```

И затем используем в шаблонах ассеты так:
```erb
<script src="<%= static_path(@conn, "/assets/app.js") %>"></script>
<link rel="stylesheet" href="<%= static_path(@conn, "/assets/app.css") %>">
```

### Выпиливаем brunch из config/dev.exs, добавляем сервис webpack'а в docker-compose.yml

Открываем файл `config/dev.exs` и выпиливаем вот это:
```elixir
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin",
                    cd: Path.expand("../frontend", __DIR__)]]
```

Затем в [`docker-compose.yml`](https://github.com/ivalentinee/DM-Assistant/blob/b418648e9959914afb6e6667b628a30fccaca8e6/docker-compose.yml) надо сделать две вещи:
1. Добавить сервис для webpack'а.
2. Сделать общий volume для контейнеров с cowboy (web) и webpack, чтобы собранные webpack'ом файлы раздавались веб-сервером приложения.

Просто приведу часть кода (полный `docker-compose.yml` будет чуть дальше):
```yaml
services:
  web:
    # ...
    volumes: &web-volumes
      - /priv/static/

  webpack:
    build: .
    volumes: *web-volumes
    command: npm run watch
    environment:
      NODE_ENV: development
```

### Собираем Dockerfile

#### Dockerfile

```conf
# Кэп подсказывает, что тут мы ставим elixir
FROM elixir:1.5.1

# ставим inotify-tools для вотчеров
# required packages
RUN apt-get update && \
    apt-get install -y inotify-tools && \
    apt-get clean

# Устанавливаем nodejs и yarn
RUN curl --silent --location https://deb.nodesource.com/setup_6.x | bash - && \
    apt-get install -y nodejs && \
    npm install yarn -g && \
    apt-get clean

# Создаём директорию для проекта
RUN mkdir /app
WORKDIR /app

# Устанавливаем окружение нашего приложения в production
# чтобы потом можно было этот контейнер поднимать в проде (например, в kubernetes)
ENV MIX_ENV=prod NODE_ENV=production

# Устанавливаем пакеты elixir (hex deps)
COPY mix.exs mix.lock /app/
RUN mix local.hex --force && \
    mix deps.get && \
    mix local.rebar --force

# Устанавливаем пакеты nodejs
COPY package.json yarn.lock /app/
RUN yarn install -s --frozen-lockfile --non-interactive

# Выпячиваем наружу порт
EXPOSE 4000

# Добавляем файлы приложения в образ
ADD . /app

# Компилируем приложение (elixir и javascript)
RUN mix compile && \
    npm run build && \
    mix phx.digest

# Ну и команда для запуска проекта
CMD bash -c "mix ecto.create && mix ecto.migrate && mix phoenix.server"
```

#### docker-compose.yml
```yaml
version: "3"

services:
  db:
    image: postgres:9.6.2
    ports:
      - "5432"

  web:
    build: .
    links:
      - db
    ports:
      - "4000:4000"
    volumes: &web-volumes
      - ./:/app
      - ~/.bash_history:/root/.bash_history
      - /priv/static/
    environment:
      MIX_ENV: null
      NODE_ENV: development
      POSTGRESQL_HOST: db

  webpack:
    build: .
    volumes: *web-volumes
    command: npm run watch
    environment:
      NODE_ENV: development
```

#### .dockerignore

Стоит добавить в корень проекта файл `.dockerignore`, чтобы всякий шлак не попал в образ с нашим приложением во время выполнения команды `ADD`. Этот файл обычно почти повторяет `.gitignore`:

```conf
# App artifacts
/_build
/db
/deps
/*.ez

# Generated on crash by the VM
erl_crash.dump

# Static artifacts
yarn-error.log
/node_modules
npm-debug.log

# Since we are building assets from web/static,
# we ignore priv/static. You may want to comment
# this depending on your deployment strategy.
/priv/static/

# The config/prod.secret.exs file by default contains sensitive
# data and you should not commit it into version control.
#
# Alternatively, you may comment the line below and commit the
# secrets file as long as you replace its contents by environment
# variables.
/config/prod.secret.exs
```

## Готово! Вы восхитительны!

Осталось только написать в `README` о том, как поднимать проект:
```sh
$ docker-compose build
$ docker-compose run --rm web mix deps.get
$ docker-compose run --rm web yarn -s --frozen-lockfile --non-interactive
$ docker-compose up -d
```
