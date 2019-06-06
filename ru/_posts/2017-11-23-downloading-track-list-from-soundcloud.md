---
layout: post
title:  "Скачиваем список песенок с Soundcloud"
date:   2017-11-23
categories: programming
uid: downloading-track-list-from-soundcloud
---

## Морально-юридический вопрос
Я понимаю, что это хак. Мне даже немного стыдно, хотя я ничего не ломаю, эксплоиты не использую. Если сюда набежит кто-то из Soundcloud, то я заранее перед этим человеком извиняюсь =)

## С чего началось
В последнее время я немного подсел на [вот такие dubstep-подборки](https://youtu.be/yma_s460sfc).

Но
1. Не всегда удобно гонять с ютуба (особенно без интернета).
2. Хочется песенки из всех этих подборок разом в перемешанном виде играть, составляя плейлисты на 3-4 часа.

Выход? Скачать эти песенки и положить на проигрыватель (у меня, кстати, [вот такой](http://www.fiio.net/en/products/39)).

## Немного входных допущений
Ну, во-первых, названия всех нужных мне песенок уже написаны. С шазамом я тут не интегрируюсь. То есть входными данными у меня является файл со списком названий песен.

Во-вторых, все эти песни являются ремиксами ремиксов и потому с большой вероятностью доступны для бесплатного прослушивания на [Soundcloud](https://soundcloud.com/). Песни, которые отсутствуют на Soundcloud, я готов пропустить.

## Чего я жду от программы
Есть список песен, который я руками скопипастил из описания на ютубе. В этом списке каждая строка — название песни (полное, с исполнителем). Этот файл я скармливаю своей программе, которая скачивает мне все эти песни в папку.

## Скачиваем песни
### Получаем ссылку на Soundcloud
Чтобы скачать песню на Soundcloud, надо её сначала найти. Так как в современном мире есть куча поисковиков, то заниматься написанием своего я не решился.

Сналача я посмотрел на [Google](https://www.google.com/). У него есть какой-то [Custom Search](https://developers.google.com/custom-search/), но я не особо понял, как его использовать, да и там надо и приложение регать и ещё и денежку вроде как платить, если запросов в день больше 100. Короче, не моя история.

Потом я рещил обратить внимание на одну [нидерладнскую компанию](https://yandex.ru/). Там была та же история, что и с гуглом — надо регаться и потом с некоторой вероятностью денежку платить. Снова мимо.

Но, хвала опенсорцу и безумному сообществу, есть [DuckDuckGo](https://duckduckgo.com/).

#### DuckDuckGo
Сначала я нашёл [Instant Answer API](https://duckduckgo.com/api). Отличная штука, подходит. Выдаёт красивые json'ы (не надо парсить DOM), ограничений нет, регаться не надо. Но, увы, использовать это API не получилось, потому что "из-за ряда юридических проблем Instant Answer API не может осуществлять глубокие запросы". А мне именно они и нужны...

Но не беда. Оказалось, что DuckDuckGo умеет отдавать отрендреный html (а не кусок обфусцированного js, как у Гугла или Яндекса), поэтому не надо использовать никаких headless-браузеров — достаточно просто попарсить DOM.

Получить страницу можно по ссылке [https://duckduckgo.com/html/?q=текст запроса](https://duckduckgo.com/html/?q=%D0%A1%D0%BA%D0%B0%D1%87%D0%B8%D0%B2%D0%B0%D0%B5%D0%BC%20%D1%81%D0%BF%D0%B8%D1%81%D0%BE%D0%BA%20%D0%BF%D0%B5%D1%81%D0%B5%D0%BD%D0%BE%D0%BA%20%D1%81%20Soundcloud).

Я сделал допущение, что первый результат — то, что нужно.

После того, как получили текст запроса, достаточно найти нужную ссылку в DOM. Для этого нужно выгрести элемент с классом `result__a` и `href` со ссылкой на Soundcloud. Можно, конечно, сделать это попарсив дом, но я обошёлся регуляркой. Например, такой: `/class="result__a".+href=".+(https.+soundcloud\.com.+)"/` (здесь первый capture как раз даст нам нужную ссылку).

Готово! Осталось только скачать песенку с Soundcloud.

### Качаем песенку с Soundcloud
Тут начинается самое интересное.

Есть два способа получить песенку с Soundcloud:
1. Постучаться к ним в API. Снова история с ограничением, регистрацией приложения и прочим.
2. Забрать её так, как её проигрывает браузер.

Я, как адепт Emacs (на момент написания этой статьи) считаю, что всё можно похачить. Не взломать, так как это не вопрос информационной безопасности, а просто воспользоваться тем, что доступно, своим, нужным для меня способом. Поэтому я решил воспользоваться вторым способом получения песни — похачить Soundcloud.

Так как плеер Soundcloud — поделка на js, а не тег `<audio>`, просто дёрнуть из тела страницы и скачать не получится. Но ведь должен же как-то плеер идентифицировать песню? Вопрос в том, как получить этот идентификатор.

#### Получаем идентификатор песни
Для начала скачиваем текст страницы песни на Soundcloud (ссылка у нас уже есть).

Эмпирически я выяснил, что выдернуть идентификатор можно из ссылок "share" где-то наверху страницы. Регулярка получилась примерно такая: `/api.soundcloud.com%2Ftracks%2F([0-9]+)/`. В результате мы получаем некоторый набор цифр, который нам и нужен (из первого capture).

#### Получаем идентификатор клиента
У Soundcloud есть клиенты. Эти клиенты имеют право проигрывать музыку. Либо это стронний клиент (регистрация на доступ в API и создаёт такого клиента), либо собственный (soundcloud'а), который используется в браузере. Мне нужен был последний.

Идентификатор этого клиента есть в файле `/assets/app-a6bbad0-a3829ac-3.js` (хеш, конечно же, может быть любой).

1. Для начала выгребем ссылку на это файл из тела страницы регуляркой `/(https?:\/\/[^\/]+\/assets\/app[^\.]+\.js)/`.
2. Потом качаем его.
3. И затем в нём ищем идентификатор клиента вот такой регуляркой: `/client_id:"([0-9a-zA-Z]+)"/`.

#### Ищем ссылку на песенку по идентификатору
Тут всё ещё интереснее, потому как все ссылки я выгреб из инспектора браузера, а допущения в этом пункте настолько сильны, что способ может сломаться в любой момент.

Из инспектора я выгреб ссылку `https://api.soundcloud.com/i1/tracks/291177064/streams?client_id=Z4iXVvmpbal2YXoYjBZVHxCJjcifbljN`. В этой ссылке `291177064` — идентификатор песни, а `Z4iXVvmpbal2YXoYjBZVHxCJjcifbljN` — идентификатор браузерного клиента Soundcloud.

По ссылке (которую собираем для каждой песни) мы получаем json такого вида:
```json
{
  "http_mp3_128_url": "https://cf-media.sndcdn.com/Xlvvl47X5snD.128.mp3?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiKjovL2NmLW1lZGlhLnNuZGNkbi5jb20vWGx2dmw0N1g1c25ELjEyOC5tcDMiLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE1MTE0MjI4OTd9fX1dfQ__&Signature=ljJuP5xFAg-63FUBENz9kdDTAUPhQ5dZXKR7Oly92KRI01X50w55~Umnm8Y2OzPmupUKX8XFUwFtGRLx5cxNGY8apK44PKGqpojS9oPl~y9QvrD1~x2~1IEUxiX6ekl-vVT8O~x3NlfQZD-RuBuaa8w6tUsOayJKb2SyGsWlf3tWywj5MIKKvIQj7EPbDiwwKm7Pjykiu4EOCJc~7Zaoh-BYZSEmn7Sf~1lRXuMYThjTIkyLEPXS3XxIcz8R0KE5UqlWzX-gJF7qE7ONk5RGiojEM6kitH-Tjo7PYhGcP474H4dNGSfG9DgThshedG4U4o6OgeKgzbQcaR40cieZQA__&Key-Pair-Id=APKAJAGZ7VMH2PFPW6UQ",
  "hls_mp3_128_url": "https://cf-hls-media.sndcdn.com/playlist/Xlvvl47X5snD.128.mp3/playlist.m3u8?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiKjovL2NmLWhscy1tZWRpYS5zbmRjZG4uY29tL3BsYXlsaXN0L1hsdnZsNDdYNXNuRC4xMjgubXAzL3BsYXlsaXN0Lm0zdTgiLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE1MTE0MjI4OTd9fX1dfQ__&Signature=OSNoc56u8svEduVUSpsJwCRV3FrshVxFLSafaHEN4PgLzu0klPTVTUQtvIi6fJUvY3vL1LbaW-4wH1VxIEqNSB5WEHK-~-2Xwy6a9RuDeWDerNQCyP6MjkA~KbgLGW0VRBHW2CR1PzfhNubG6Irm1vAzEbKiWY7fzy7EI3ngN16~HjAgJdwRbg~n7oM9eOjj94PJD5EChQcMTl2e1kjRcBB-XkcDCQKxXCIMXuIcYAVVxO1YU-V40w373UmALyfat-ggfLIErebHx4a85dfk~h4YVYntmXPkdLiNMJHydA2-IBrm967vDS8EbHm07OEDDvt2XOMRooMLPqGerwKIXg__&Key-Pair-Id=APKAJAGZ7VMH2PFPW6UQ",
  "hls_opus_64_url": "https://cf-hls-opus-media.sndcdn.com/playlist/Xlvvl47X5snD.64.opus/playlist.m3u8?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiKjovL2NmLWhscy1vcHVzLW1lZGlhLnNuZGNkbi5jb20vcGxheWxpc3QvWGx2dmw0N1g1c25ELjY0Lm9wdXMvcGxheWxpc3QubTN1OCIsIkNvbmRpdGlvbiI6eyJEYXRlTGVzc1RoYW4iOnsiQVdTOkVwb2NoVGltZSI6MTUxMTQyMjg5N319fV19&Signature=AjcgtA-xawQQKJB3jlUFcT~7~kPb-M2vmmGPSBeLQ6LPZF-slEcf0xpr6hhNRSZah32Q5fzyE2U~ntuIMvAQ7BfgEx8l~ZFK~p5487kJV5~UZb5E-AodmzETm6O9tihIm812X1R1tgutK0UpIII4ovYdT1~JwRqRfqxBW71ZwbM-88VKndln424PgeFWCHRJLlJQaCZ0bU8myOQ3jRyXgN2ADgn3TmwzBTmcoXQhvSTyc7EevS8tk-0GPdTuNsNIhs0pVoLj2I-MbA8~UdlimMdj-SYbz3ycorwOsMUFkJBIC5HhygT0BQt1z-sP~FY2wijcW7JPgiWjS5ceEJERMA__&Key-Pair-Id=APKAJAGZ7VMH2PFPW6UQ",
  "preview_mp3_128_url": "https://cf-preview-media.sndcdn.com/preview/0/30/Xlvvl47X5snD.128.mp3?Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiKjovL2NmLXByZXZpZXctbWVkaWEuc25kY2RuLmNvbS9wcmV2aWV3LzAvMzAvWGx2dmw0N1g1c25ELjEyOC5tcDMiLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE1MTE0MjI3MjZ9fX1dfQ__&Signature=MMKxbBT-pmgHRMV4x5aRdr21gxRnxyfGqcZ452JTTA8C6fy6c0s-VaVtYrr39EtJlEws5FyUiMPvUA9cgNBy-Ms0ogF5zpKinyCanusXUC~QvhMGDjjmTD2DdDk0ehZcv3cDJnBcObp1Rdm1qkiPVxhuDMCuwGAp10ea2~qF7q2N6AJAB0t8nljJe-uRkt~6IgCkUK-UywWlZmZQYAUyDnR8QLORzw5vGsCSXipYN2jSqQK~RIwuCCoX4qXFODdLSIzhIoyMJ-eeFlhF9fcdqNcYn93h5sinTxZOung4AZDENkdeEDtmEMXA5LobO1eR2os0QTgk6zVFGNn1eoDk8g__&Key-Pair-Id=APKAJAGZ7VMH2PFPW6UQ"
}
```

В этом json'е все ссылки ведут уже на наши целевые файлы. Осталось только выбрать нужный формат и скачать. Я пользую `http_mp3_128_url`.

Готово! Можно качать песенку, сохранив с именем файла из списка, потому как в json'е имена файлов не очень хорошо читаются.

### Ну и остальное
Описывать построчный разбор файла со списком песенок я не буду, ибо задача тривиальна. Как и скачивание файлов. Это можете и сами сделать =)

## Результат?
Песенки скачаны, можно копировать на проигрыватель и слушать =)

Готово, вы восхитительны!

~~Как-нибудь выложу свой говнокод на [elixir'е](https://elixir-lang.org/) на Github~~ Выложил [свой говнокод на Github](https://github.com/ivalentinee/Track-downloader).
