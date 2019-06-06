---
layout: post
title:  "Хачим OpenAPI"
date:   2018-09-27
categories: programming
uid: hacking-openapi
---

## Предисловие
Так исторически сложилось, что я на проектах пользовался [apiDoc'м](http://apidocjs.com/). Прекрасный инструмент. Но, увы, при росте размеров и количества HTTP API он (apiDoc) всё хуже справлялся.

Когда пришло время выбирать новый инструмент, выбор, по сути, свёлся к двум ~~стульям~~ вариантам: [API Blueprint](https://apiblueprint.org/) и [OpenAPI](https://www.openapis.org/).

Продолбавшись с API Blueprint часа 4 и так и не заставив его нормально работать с deepObject-параметрами строки запроса, остался только туманный OpenAPI.

## Предполагаемая модель данных и API
Для демонстрации того, что поломало мне пропагандируемый OpenAPI-документацией подход, необходимо обозначить некоторую модель и пару методов API для работы с ней
Пусть это будет товар в интернет-магазине.

### Модель данных
Атрибутами (их было бы больше, но для примера хватит этих) будут:
- Название (строка) — `name`
- Описание (строка) — `description`
- Артикул (число) — `vendor_code` (Шоколад не виноват, гугель-транслейт так перевёл)
- Картинка (файл) — `picture`

Составим канонiчную [OpenAPI-схему](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#schemaObject):
```yaml
components:
  schemas:
    Product:
      type: object
      description: Продукт
      properties:
        name:
          type: string
          description: Название товара
        description:
          type: string
          description: Описание товара
        vendor_code:
          type: number
          description: Артикул
        picture:
          type: string
          format: binary
          description: Изображение
```

### HTTP API
Тут нам понадобится описание двух [методов](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#pathItemObject): создания и получения.

Ввиду наличия картинки метод **создания** гипотетически будет описываться примерно так:
```yaml
paths:
  /api/products:
    post:
      summary: Создание продукта
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              "$ref": "#/components/schemas/Product"

      responses:
        '200':
          # ...
```
А метод **получения** гипотетически будет описываться примерно так:
```yaml
paths:
  /api/products/{id}:
    get:
      summary: Получение проекта
      parameters:
        - name: id
          in: query
          description: Идентификатор продукта
          schema:
            type: string
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Product"
```

Всё правильно? Да нет, не очень.

[Пример сломанного API](/assets/other/posts/2018-09-27-hacking-openapi/broken-api.html)

## А что, собственно, сломалось-то?
На деле никто не будет делать API, которое получает файл бинарником (в составе `multipart/form-data`), и отдавать бинарником (в составе `application/json`).
Скорее всего ответ будет в виде:
```yaml
picture:
  type: object
  description: Изображение
  properties:
    link:
      type: string
      description: Ссылка на файл
    filename:
      type: string
      description: Имя файла
```

То есть, в терминологии OpenAPI producer (производитель) не равен cunsumer'у (потребителю). А это значит, что использовать одну и ту же схему не получится. Как быть?

В идеальном мире можно было бы описать модель, а потом сокращать/дополнять её до нужного нам состояния. Однако такой метод мало того, что не поддерживается ([merge в стандарт не включат](https://github.com/OAI/OpenAPI-Specification/issues/674), а `allOf` не только [сломан](https://github.com/swagger-api/swagger-ui/issues/3674), но и создан не столько для сращивания схем, сколько для объединения), так ещё и опасен, потому что изменения исходной модели неизвестно как скажутся на производной модели.

### Забить на вынесение схемы
И просто везде писать всё целиком.

Но это будет лютое дублирование. А учитывая то, как многословно (я бы даже сказал "многострочо") описание в OpenAPI, это приведёт к огромному файлу. Нецелесообразно огромному.

### Вынести общее описание на уровень выше
Ну я не про yaml-файлы сейчас, а про уровень абстракции.

А общими являются описания отдельных полей (не всех, но почти). Их и будем выносить из описания методов.

Ввиду того, что OpenAPI явно не указывает, какие именно схемы мы ~~должны~~ можем описывать, сделать это для подсхем это достаточно легко.

После чего в описании методов будем всё-таки писать схему, но не целиком описывать модель, а только перечислять нужные свойства.

## «Похаченное» API
### Описываем свойства модели
```yaml
components:
  schemas:
    Product::name:
      type: string
      description: Название товара
    Product::description:
      type: string
      description: Описание товара
    Product::vendor_code:
      type: number
      description: Артикул
    Product::picture:
      type: object
      description: Изображение
      properties:
        link:
          type: string
          description: Ссылка на файл
        filename:
          type: string
          description: Имя файла
    Product::picture::upload:
      type: string
      format: binary
      description: Изображение
```
### Используем их в схемах методов
Метод **создания** теперь выглядит так:
```yaml
paths:
  /api/products:
    post:
      summary: Создание продукта
      requestBody:
        required: true
        content:
          multipart/form-data:
            schema:
              type: object
              properties:
                name: {"$ref": "#/components/schemas/Product::name"}
                description: {"$ref": "#/components/schemas/Product::description"}
                vendor_code: {"$ref": "#/components/schemas/Product::vendor_code"}
                picture: {"$ref": "#/components/schemas/Product::picture::upload"}
      responses:
        '200':
          # ...
```
А метод **получения** теперь выглядит так:
```yaml
paths:
  /api/products/{id}:
    get:
      summary: Получение проекта
      parameters:
        - name: id
          in: query
          description: Идентификатор продукта
          schema:
            type: string
      responses:
        '200':
          content:
            application/json:
              schema:
                type: object
                properties:
                  name: {"$ref": "#/components/schemas/Product::name"}
                  description: {"$ref": "#/components/schemas/Product::description"}
                  vendor_code: {"$ref": "#/components/schemas/Product::vendor_code"}
                  picture: {"$ref": "#/components/schemas/Product::picture"}
```

[Пример похаченного API](/assets/other/posts/2018-09-27-hacking-openapi/hacked-api.html)

### Немного выводов
Такое описание, по сути, отображает реальное положение дел.

Мало кто пишет один и тот же код как для получения данных, так и для их отображения. Однако общими для них (в коде) являются поля (их типы и описания). Ну кроме случая с файлами (и подобные).

## Авторский говнокод
Ещё одна крохотная проблема исходного OpenAPI заключается в том, что описание нельзя разбить на несколько файлов. Что, конечно, можно понять, но на практике — крайне неудобное ограничение.

Проблема решается в пару строк кода: парсим все файлы, мержим, рендерим в один файл.

Так случилось, что [подобное решение я уже написал](https://github.com/ivalentinee/openapi-merger). Не ручаюсь за его работоспособность :)
