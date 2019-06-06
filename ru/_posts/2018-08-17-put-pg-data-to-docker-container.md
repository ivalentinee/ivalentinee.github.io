---
layout: post
title:  "Как засунуть pg_data-бекап в docker-контейнер"
date:   2018-08-17
categories: programming
uid: put-pg-data-to-docker-container
---

## Предисловие
Этот пост написан скорее для меня самого, чем для случайно забредших сюда.

Иногда админы, которых попросили скинуть бекап с какого-нибудь стенда, радостно кидают архивчик и говорят: "Сделано". А в архиве вместо православного pg_dump'а лежит богомерзкая папка pg\_data.

Но проблема в том, что накатывание этого даже без докера не всегда удобно. Благо что базёна при dockerway-разработке всего одна на инстанс pg, поэтому разбираться с внутренним устройством pg_data не приходится.

## Накатываем

### Ищем, куда копировать
Я при разработке использую [docker-compose](https://docs.docker.com/compose/), поэтому плясать буду от него.

Для начала получаем ID нужного контейнера. Допустим, в docker-compose.yml он у меня назван `postgres`:
```console
$ docker-compose ps -q postgres
```

Далее для полученного ID надо получить путь до [volume'а](https://docs.docker.com/storage/volumes/), в котором хранится pg_data:
{% raw %}
```console
$ docker inspect -f '{{ .Mounts }}' <id контейнера>
```
{% endraw %}

Получаем что-то вроде
```
[{volume ea8997003c8f70cb8590754b882f644ad4a29c9bdd2074c4799e150a99d5eada /var/lib/docker/volumes/ea8997003c8f70cb8590754b882f644ad4a29c9bdd2074c4799e150a99d5eada/_data /var/lib/postgresql/data local rw true }]
```
где
```
/var/lib/docker/volumes/ea8997003c8f70cb8590754b882f644ad4a29c9bdd2074c4799e150a99d5eada/_data
```
— наше искомое значение.

### Копируем и накатываем права
Перед процедурой желательно тормознуть все контейнеры:
```console
$ docker-compose stop
```

Для полученной директории с pg\_data:
- копируем куда-нибудь действующие конфиги `postgresql.conf` и `pg_hba.conf`
- удаляем всё содержимое папки
- копируем полное содержимое pg_data из архива
- заменяем конфиги `postgresql.conf` и `pg_hba.conf` теми, что мы сохранили в первом пункте.

На всякий случай регулярка для `pg_hba.conf` чтобы всё разрешить:
```console
# sed -i "s/md5\|reject\|trust\|password\|gss\|sspi/trust/g" <путь до pg_data>/pg_hba.conf
```

Так как на стенде имя БД и права скорее всего не совпадают с локальными, надо будет заходить и править это дело руками. Для этого стартуем контейнер с БД и меняем все нужные права/названия. Например:
```console
$ docker-compose start postgres
$ docker-compose exec postgres bash
# psql -U postgres
postgres-# ALTER USER postgres PASSWORD null;
postgres-# \l
postgres-# ALTER DATABASE <продовое название БД> RENAME TO <локальное название БД>;
postgres-# ALTER DATABASE <локальное название БД> OWNER TO postgres;
```

Готово! Вы восхитительны!
