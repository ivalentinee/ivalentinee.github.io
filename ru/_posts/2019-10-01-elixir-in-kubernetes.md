---
layout: post
title:  "Еликсиръ в кубернетисах"
date:   2019-10-01
categories: programming
uid: elixir-in-kubernetes
---

## Зачем?
Потому что могу. Потом что это был самый адекватный организовать общение между сервисами.

А, так как я пейсатель на еликсиряхъ, то пояснения буду приводить на них (шучу, примеров кода не будет).

## Исходники
Для организации подхода использовались статьи:
- [Erlang (and Elixir) distribution without epmd](https://www.erlang-solutions.com/blog/erlang-and-elixir-distribution-without-epmd.html) (больше для понимания происходящего)
- [Clustering Elixir/Erlang applications in Kubernetes](https://blog.ispirata.com/clustering-elixir-erlang-applications-in-kubernetes-part-1-the-theory-ca658acbf101) (как пример организации)

## Начнём
Итак, ситуация: готовое приложение на N сервисов (где N <~ 10), развёрнутое в кубернетисах (на самом деле в [шифтах](https://www.openshift.com/), но не суть) в качестве набора deploymentconfig'ов, на нужные сервисы развёрнуты [service'ы](https://kubernetes.io/docs/concepts/services-networking/service/) (слово "сервис" буду использовать для частей приложения, а "service" — для сущности kubernetes'а) и [маршруты](https://docs.openshift.com/enterprise/3.0/architecture/core_concepts/routes.html). Сервисы складывают общую информацию в redis/memcached/postgresql/kafka/whatever, за счёт чего и происходит косвенное взаимодействие.

И тут появилась необходимость прямого взаимодействия между сервисами. Благодаря тому, что приложение написано на elixir'е, вариантов оказалось не один, а два, а именно:
1. Общение через реализацию протоколов (grpc и co.)
2. Общение через [OTP](https://ru.wikipedia.org/wiki/Open_Telecom_Platform)

На второй вариант выбор пал по двум причинам:
1. ~~Лень~~ Некогда имплементить (или прикручивать готовую реализацию) всяких grpc.
2. Ну ерланги жеж, надо всё как у модных людей, в конце концов.

И если на уровне erlang'а всё оказалось [очень просто](http://erlang.org/doc/reference_manual/distributed.html), то на уровне инфраструктуры пришлось городить всякое разное.

## Идеальный мир
Итак, для идеального мира нам нужно иметь __заранее известные__ DN для всех инстансов всех сервисов, которые автоматически доставляются куда нужно и как нужно, а между сервисами есть полная сетевая связность (можно установить tcp-соединение между любыми приложениями по любому порту).

После чего остаётся только запустить ноду:
```shell
ERL_OPTIONS="-name ${SNAME}@${HOSTNAME} -setcookie ${ERLANG_COOKIE}"
elixir --erl "${ERL_OPTIONS}" -S mix run --no-halt
```

Ну и в самой ноде можно спокойно выполнить:
```elixir
Node.ping(:"some_other_node@some.other.domain.name")
# => :pong
```

Но приложение наше развёрнуто было не в идеальном мире с понями и вежливыми девопсами, а в кубернетисах. Увы.

## Доступность по доменным именам
Итак, первая проблема: доменные имена при использовании deploymentconfig'ов __динамические__. Причём discovery-сервис не очень получится использовать, потому что erlang-ноде нужно знать внешний адрес при старте.

Ну то есть не совсем.

Если мы используем [service'ы](https://kubernetes.io/docs/concepts/services-networking/service/), то мы можем получить один DN для конкретного deploymentconfig'а. Но что если мы какой-то dc замасштабируем? Куда пойдёт соединение?

Для этого сервисы необходимо разделить на две группы:
1. Ожидающие соединения
2. Инициирующие соединие

### Ожидающие соединения
Тут всё достаточно просто, но тупо и с ограничениями.

Ожидающие соединения сервисы мы **не масштабируем**.

Таком образом единственный инстанс будет доступен по DN [service'а](https://kubernetes.io/docs/concepts/services-networking/service/) вроде вот такого: `exclusive-service.project.svc.cluster.local`.

Далее запускаем приложение с заранее известным DN (в данном случае я решил не переназначать `HOSTNAME`, а использовать отдельную переменную `CLUSTER_HOSTNAME`):
```shell
ERL_OPTIONS="-name ${SNAME}@${CLUSTER_HOSTNAME} -setcookie ${ERLANG_COOKIE}"
elixir --erl "${ERL_OPTIONS}" -S mix run --no-halt
```

### Инициирующие соединение
Тут всё ещё проще: достаточно запустить процесс с любым FQDN (чтобы erlang запустился в FQDN-режиме). Но я предпочёл оставить дырку для дебага.

Конкретные [поды](https://kubernetes.io/docs/concepts/workloads/pods/pod/) доступны (через [service'ы](https://kubernetes.io/docs/concepts/services-networking/service/)) по адресам `<pod-name>.<service-dn>`, например `pod-12345-qwerty.non-exclusive-service.project.svc.cluster.local`. Но заранее мы знаем только `service-dn`, а `pod-name` прилетает при старте в переменной `HOSTNAME`.

Что делаем? Составляем эффективный DN при старте:
```shell
ERL_OPTIONS="-name ${SNAME}@${HOSTNAME}.${CLUSTER_HOSTNAME} -setcookie ${ERLANG_COOKIE}"
elixir --erl "${ERL_OPTIONS}" -S mix run --no-halt
```

Таким образом если за одним сервисом окажется два инстанса, мы сможем обратиться к каждому по конкретному имени. Можно использовать эту технику с service-discovery. Я использую этот способ просто для дебага (залезть с одной ноды на другую и чего-нибудь дёрнуть).

## Порты
Проблема вторая: проброс портов. Порта нам нужно пробросить два: один для empd, второй для erlang-процесса.

### empd
Тут всё просто.

epmd использует для входящих соединений порт `4369`. Его-то в [service'ах](https://kubernetes.io/docs/concepts/services-networking/service/) и открываем:
```yaml
apiVersion: v1
kind: Service
# ...
spec:
  ports:
    - name: epmd
      port: 4369
      protocol: TCP
      targetPort: 4369
  selector:
    deploymentconfig: some-service
# ...
```

### Erlang-процесс
Тут всё интереснее. Каждый erlang-процесс при старте начинает слушать на каком-то случайном порту входящие OTP-соединения и регистрируется в epmd. При исходящих соединениях erlang-процесс коннектится к epmd на целевой машине и спрашивает: "На каком порту у тебя работает такой-то процесс?"

И если с подключением к epmd вопрос решён, то со "случайным" портом нужно что-то придумывать.

Увы, открыть все 65535 портов — такая себе идея. По крайней мере я не нашёл в документации способа написать "а вот тут открой вообще все порты". Только отображение один-в-один.

Для того, чтобы обеспечить возможность соединения необходимо открыть какой-нибудь один порт и заставить erlang-процесс слушать именно на нём.

Первое делается достаточно просто:
```yaml
apiVersion: v1
kind: Service
# ...
spec:
  ports:
    - name: erlang-process
      port: 43691
      protocol: TCP
      targetPort: 43691
  selector:
    deploymentconfig: some-service
# ...
```

А для второго используем опции запуска `inet_dist_listen_min` и `inet_dist_listen_max`, которые задают диапазон используемых портов, чтобы оставить один единственный порт:
```shell
ERL_PORT=43691
ERL_KERNEL_OPTIONS="-kernel inet_dist_listen_min ${ERL_PORT} inet_dist_listen_max ${ERL_PORT}"
ERL_OPTIONS="-name ${SNAME}@${CLUSTER_HOSTNAME} -setcookie ${ERLANG_COOKIE} ${ERL_KERNEL_OPTIONS}"
elixir --erl "${ERL_OPTIONS}" -S mix run --no-halt
```

И вуаля, erlang-процессы запущены и могут связаться друг с другом!

Очевидно, что с таким подходом запустить неизвестное заранее количество erlang-процессов в одном контейнере мы не сможем. Но для того контейнеры и нужны же, чтобы один процесс запускать.

## Заключение
Данный подход расписан для случая с deploymentconfig'ами. Есть подход [с использованием StatefulSet'ов](https://blog.ispirata.com/clustering-elixir-erlang-applications-in-kubernetes-part-1-the-theory-ca658acbf101) (как пример организации), который в теории круче, но у меня уже было готовое приложение и на его пересборку с даунтаймом никто бы не подписался.
