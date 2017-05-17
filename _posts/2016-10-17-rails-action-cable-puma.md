---
layout: post
title:  "Rails ActionCable и почему он у меня сразу не запустился"
date:   2016-10-17
categories: rails
---

# Предисловие
[ActionCable](http://edgeguides.rubyonrails.org/action_cable_overview.html) — надстройка над рельсами для [websocket](https://ru.wikipedia.org/wiki/WebSocket). Содержит в себе как frontend (js) так и backend части. Документацию описывать не буду, примеры кода приводить тоже не буду, но опишу проблему, с которой я столкнулся и на которую потратил больше часа времени.

# Проблема
Как это обычно бывает, сделал "как в документации", но при попытке [подписаться](http://edgeguides.rubyonrails.org/action_cable_overview.html#client-server-interactions-subscriptions) в логах [unicorn'а](http://unicorn.bogomips.org/), ответственного за ActionCable я увидел вот это:
~~~
web-sockets_1 | Rack::Lint::LintError: Status must be >=100 seen as integer
web-sockets_1 | 	/usr/local/bundle/gems/rack-2.0.1/lib/rack/lint.rb:20:in `assert'
web-sockets_1 | 	/usr/local/bundle/gems/rack-2.0.1/lib/rack/lint.rb:620:in `check_status'
web-sockets_1 | 	/usr/local/bundle/gems/rack-2.0.1/lib/rack/lint.rb:51:in `_call'
web-sockets_1 | 	/usr/local/bundle/gems/rack-2.0.1/lib/rack/lint.rb:37:in `call'
...
~~~
WTF?

Гугление сначала указывает на проблемы с [faye](https://github.com/faye/faye), что нам совершенно не интересно. Но дальше в поиске я обнаружил [вот этот issue](https://github.com/rails/rails/issues/26179). Если вкратце, то ActionCable устанавливает статус ответа в `-1`, а включенный unicorn'ом в development-окружении Rack::Lint требует
~~~ruby
status.to_i >= 100
~~~

# Решение
Я для себя выбрал более простой и бездумный путь: использовать [Puma](https://github.com/puma/puma). Просто потому что puma не включает в себя Rack::Lint.

Найти способ отключить Rack::Lint я не смог, хотя и не искал особо долго.
