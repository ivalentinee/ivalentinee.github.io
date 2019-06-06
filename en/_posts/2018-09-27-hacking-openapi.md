---
layout: post
title:  "Hacking OpenAPI"
date:   2018-09-27
categories: programming
uid: hacking-openapi
---

## Introduction
Back in the days I used [apiDoc](http://apidocjs.com/). Wonderful tool. But growing project caused apiDoc to fail.

When time has come to look for something else there were two options: [API Blueprint](https://apiblueprint.org/) and [OpenAPI](https://www.openapis.org/).

Spent some time (about 4 hour) failing to make API Blueprint work with deepObject parameters I went with the only option left — mysterious OpenAPI.

## Sample data model and API
To demonstrate canonical OpenAPI approach problem I need to describe some model and few API methods on it.
I'll take online-store product as an example.

### Data model
Attributes (there might be more, but that's enough):
- Name (string) — `name`
- Description (string) — `description`
- Vendor code (number) — `vendor_code`
- Picture (file) — `picture`

Let's describe canonical [OpenAPI scheme](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#schemaObject):
```yaml
components:
  schemas:
    Product:
      type: object
      description: Product
      properties:
        name:
          type: string
          description: Name
        description:
          type: string
          description: Description
        vendor_code:
          type: number
          description: Vendor code
        picture:
          type: string
          format: binary
          description: Picture
```

### HTTP API
We need to describe two [API-methods](https://github.com/OAI/OpenAPI-Specification/blob/master/versions/3.0.1.md#pathItemObject): "create" and "get".

**Create** method will look like this:
```yaml
paths:
  /api/products:
    post:
      summary: Create product
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
And **get** method will look like this:
```yaml
paths:
  /api/products/{id}:
    get:
      summary: Get product
      parameters:
        - name: id
          in: query
          description: Product ID
          schema:
            type: string
      responses:
        '200':
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/Product"
```

Seems legit? Well, yes, but no.

[Broken API Example](/assets/other/posts/2018-09-27-hacking-openapi/broken-api.html)

## What's wrong?
In real world scenario no one is going to build an API that consumes file as binary date (as part of `multipart/form-data`) and returns file as binary date (as part of `application/json`).
Response will most probably look like:
```yaml
picture:
  type: object
  description: Picture
  properties:
    link:
      type: string
      description: File url
    filename:
      type: string
      description: File name
```

In terms of OpenAPI it means, that producer is not equal to consumer. So we can't use the same schema for both. Is there any thing we can do?

In the world of ponies and rainbows we'll be able to describe a model and then cut/amend it however we need. But not only it's unsupported ([such merge won't ever be part of standard](https://github.com/OAI/OpenAPI-Specification/issues/674) and `allOf` is both [broken](https://github.com/swagger-api/swagger-ui/issues/3674) and not meant for amending but combination), it's also dangerous, because no one can guess how base model changes will affect derived model.

### Don't use common schemas
And just write full descriptions at every place.

But that's going to be hell of a duplication. And, considering how redundant OpenAPI description is, the documentat is going to be huge. Impractically huge.

### Take common descriptions to the upper level
I'm not talking about files, but abstraction level.

Common descriptions are *property* descriptions. And that's what we're going to take from method descriptions somewhere else.

OpenAPI does not specify what exact schemas we ~~must~~ should describe, so describing subschemas should be easy.

Then we'll describe final schemas inside methods, but use property refs instead of full property descriptions.

## «Hacked» API
### Model properties description:
```yaml
components:
  schemas:
    Product::name:
      type: string
      description: Name
    Product::description:
      type: string
      description: Description
    Product::vendor_code:
      type: number
      description: Vendor code
    Product::picture:
      type: object
      description: Picture
      properties:
        link:
          type: string
          description: File url
        filename:
          type: string
          description: File name
    Product::picture::upload:
      type: string
      format: binary
      description: Picture
```
### Use property descriptions in methods
**Create** will now look like this:
```yaml
paths:
  /api/products:
    post:
      summary: Create product
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
And **get** will now look like this::
```yaml
paths:
  /api/products/{id}:
    get:
      summary: Get product
      parameters:
        - name: id
          in: query
          description: Product ID
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

[Hacked API example](/assets/other/posts/2018-09-27-hacking-openapi/hacked-api.html)

### Some sort of conclusion
That way of describing is closer to real life actually.

One rarely write the same code to consume and to render data. But properties (even within code) are often the same (types and descriptions), except files (and alike).

## Some additional shitty code
The other OpenAPI problem is this: descriptions can only be in one file. I can understand why they (OpenAPI authors) did it but it's not that convenient.

It's easy to fix: parse all files, merge and render into a single file.

It happend so that [I already built such tool](https://github.com/ivalentinee/openapi-merger). Not sure if it works :)
