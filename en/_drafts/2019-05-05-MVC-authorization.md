---
layout: post
title:  "MVC authorization"
date:   2019-07-17
categories: programming
math: true
uid: mvc-authorization
---

## Introduction

Some time ago me and colleagues at work argued over authorization. And I came up with some theory around the subject at that discussion. Plus I had to implement authorization myself later, and I have now both theoretical and practical background for authorization which I decided to share.

I strongly recommend to read about [authorization in general]({% uid_url authorization-authentication-and-identification %}) before reading this article.

I haven't read any books on authorization. But if you are to read one — go ahead, it'd be better than reading my blog post.

## Defining the basics
Let's define what base entities are used for authorization and what "authorization" is.

### System
Either an entire system (broad) or specific authorization module (narrow).

#### IO
In case of MVC applications controller and view layers form IO of an application.

### Subject
Action performer.

**External subject** is an actual actor (mostly human beings).

**Internal subject** is system-level object that represents **external subject**. Usually it's a user record.

The process of mapping **external object** into **internal object** is done by either identification or authentication, so I'm not going to discuss it in this article and assume, that we already somehow mapped one into another and operate on **internal subject**.

I'll denote **subject** as **s** ({% raw %}$$s ∈ S$${% endraw %}).

### Action
Subject's intention towards system. Typical web action is one of [CRUD methods](https://ru.wikipedia.org/wiki/CRUD) (but that's just an example — there're many more). Like printing a document. Or dropping nuclear bombs.

I'll denote **subject** as **a** ({% raw %}$$a ∈ A$${% endraw %}).

Likewise subject action is mapped from external to internal. Usually by application router.

### Object
**Subject's** **action** target. Example: user wants to delete his comment. In this example comment is an **object**.

In this article **object** means **authorization object**. **Authorization object** does not equal **system object** and it (**authorization object**) may be a single **system object** as well as many **system objects**. Nuclear bomb example: if user wants to send it to Moscow **authorization object** may consist of just the bomb, just Moscow or even both.

So I'll define **authorization object** as a set of **system objects**, so it (authorization object) naturally is a subset of all **system objects**:
{% raw %}$$O = \{o | o ⊆ SO\}$${% endraw %}

Likewise subjects we're only going to use **internal objects** for this article

### Authorization rules (policies)
**Authorization policy** or **rules** is a predicate {% raw %}$$p$${% endraw %} that tells if **subject** is allowed to perform **action** towards **object**.

It's obvious that such predicate domain is a cartesian product of **subjects**, **actions** and **objects** ({% raw %}$$D_p = S × A × O$${% endraw %}).

#### Black and white lists
This is plain subject, but I'll discuss it anyway.

Rules can be defined in two ways: "allow all but *rules*" or "deny all but *rules*".\\
Set of rules that allow nothing but specified is called white list.\\
Set of rules that allow anything but specified is called black list.

"Allow anything" is considered a bad practice usually, 'cause missing rules result in excess access (rather then insufficient access for white list).

#### Closed world assumption for authorization rules
[Closed world assumption](https://en.wikipedia.org/wiki/Closed-world_assumption) applied to authorization rules can be described as: "If predicate {% raw %}$$p$${% endraw %} is not explicitly defined for subject {% raw %}$$s_x ∈ S$${% endraw %}, action {% raw %}$$a_y ∈ A$${% endraw %} and object {% raw %}$$o_z ∈ O$${% endraw %} it is implicitly defined as false". Applying such assumption allows us to define only truth-resolving cases omitting all false cases.

To avoid ambiguity either white or black list should be used, but not both. Otherwise CWA can't be applied and both "true" and "false" cases should be explicitly defined. Which leads to redundancy. Not very good.

#### Splitting predicate definition

Defining one massive rule for everything is not that convenient (just imagine that huge `if` statement). So authorization predicate is usually splitted into smaller predicates combined with disjunction:\\
{% raw %}$$p := \displaystyle\bigvee_{i=1}^{n} p_i$${% endraw %}.

#### Grouping objects
As system objects almost always can be changed building rules for every {% raw %}$$\{s, a, o\}$${% endraw %} is nearly impossible. In such case (again, almost always) authorization predicate is defined with rules on subsets of {% raw %}$$D_p$${% endraw %}.

It makes sense use non-intersecting {% raw %}$$D_{pi}$${% endraw %}, thus every lesser predicate {% raw %}$$P_i$${% endraw %} will exclusivly define each case: {% raw %}$$p(D_p) := \displaystyle\bigvee_{i=1}^{n} p_i(D_{pi}), D_{pi} ⊆ D_p, i ≠ j, D_{pi} ⊄ D_{pj}$${% endraw %}.

## Whole process
![Authorized action diagram](/assets/img/posts/2019-05-04-MVC-authorization/Generic authorization flow.png)

### Subject identification
As noted above subject mapping is done by [authenticaiton or identification]({% uid_url authorization-authentication-and-identification %}). Both processes are well described in many books and articles, tons of technologies are developed ([kerberos?](https://ru.wikipedia.org/wiki/Kerberos), [tls?](https://en.wikipedia.org/wiki/Transport_Layer_Security#Client-authenticated_TLS_handshake)), so I won't touch that matter.

### Object identification
But this topic has something to write about.

#### Identification
For most actions object identification is done by IO data. For example getting post by it's identificator: `SELECT * FROM posts WHERE id=&post_id`.

It's important to note that identification is done not for **authorization object** (because there's no explicit authorization object), but for **system object**. And **authorization object** is then made from **system objects**.

#### Authorization object substitution
We'll look at creating object as an example for substitution, though this approach is universal.

Creating object has one problem: new object is not **system object** ({% raw %}$$so_{new} ∉ SO$${% endraw %}) yet, but only some data to create one, so it's not in predicate domain.

In that case a set (or subset) which would be changed can be used as **authorization object**.

Let's look at three cases.

1. Empty set substitution
Sometimes it's impossible to identify authorization object. In such case whole **system objects** set ({% raw %}$$SO$${% endraw %}) can represent **authorization object**, because that set would be expanded (or altered) by some action. But some of such actions don't depend on {% raw %}$$SO$${% endraw %} (only on subject and action), so {% raw %}$$SO$${% endraw %} can be substituted with **empty set**.\\
Sometimes I call such cases "null substitution".\\
Example: adding post. User can add post or can not, and it doen't depend on other posts or even any other system object.
2. Subset substitution
"Adding post" example can be described also for *posts set* as **authorization object** (because that set would be expanded). So {% raw %}$$o = Posts, post ∈ Posts ⊆ SO$${% endraw %} will represent **authorization object**.
3. Owner substitution
Let's have a look at "adding comment to post". In such case *exact post comments set* will be an **authorization object**. But it's more convenient to substitute that *set* with *post* itself.

#### Actions on groups of objects
<!-- Зачастую нужно произвести действие сразу с несколькими объектами. В данном случае ответом на групповое действие, очевидно, будет конъюнкция из атомарных действий: -->
<!-- {% raw %}$$p_{group} = \displaystyle\bigwedge_{i=1}^k p_i$${% endraw %}. -->

<!-- ### Определение действия -->
<!-- В общем случае отображение действия полностью зависит от системы ввода-вывода. Но есть повод рассмотреть определение базового класса объектов для действий. -->

<!-- Для действий «добавить комментарий к посту №2», «изменить пост №3», «распечатать отчёт о всех моих постах», «запустить ядерную ракету в направлении Вашингтона» рассмотрим два подхода. -->

#### "Wide" actions
<!-- В таком случае действия могут описываться как «добавить», «изменить», «распечатать», «запустить». А классы **объектов системы** будут либо выводиться на уровне идентификации, либо поступать в качестве данных. -->

<!-- Идентификацируемое подмножества объектов (а не одного) как **объекта авторизации** я называю **базовым классом действия**, потому что используемый идентификатор в таких случаях используется для выделения класса объектов из всего множества объектов. -->

<!-- Для «широких» действий нет возможности применить «**нуль-замену**», потому что идентифицируемый **объект системы** (или базовый класс) (и на основании него определёный **объект авторизации**) позволяет специфицировать область, на которой определён предикат (или, очевидно, меньший предикат). -->

#### "Narrow" actions
<!-- «Узкие» действия описываются как «добавить комментарий к посту», «изменить пост», «распечатать отчёт о всех моих постах», «запустить ракету в направлении города». Очевидно, что в отличии от «широких» действий класс объектов уже включён в само действие, а потому повторное его использование для специфицирования области не требуется, поэтому «**нуль-замену**» вполне можно и нужно применять. -->

#### "Wide" vs "narrow" choice
<!-- Не смотря на то, что подходы рассмотрены отдельно, в реальных программах предикат может быть одновременно и «узким» и «широким», специфицируя условие и в самом действии и в идентификаторах объектов системы. -->

## Now to real world application
<!-- Теперь можно поговорить про типичные MVC-web приложения. -->

<!-- Тут я буду исходить из модульной rack-/plug-style системы. -->

<!-- Чаще всего (хотя можно и по-другому) используется такая схема: -->

<!-- ![Совершение действия с авторизацией в MVC](/assets/img/posts/2019-05-04-MVC-authorization/MVC authorization.png) -->

### Where's authorization object
<!-- Это была первая проблема, с которой я столкнулся, когда понадобилась полноценная система авторизации. -->

<!-- Большая часть предлагаемых решений работают на основе предиката {% raw %}$$p(\{s, a\}), \{s, a\} ∈ S×A$${% endraw %} вместо {% raw %}$$p(\{s, a, o\})$${% endraw %}. Компенсируется это обычно за счёт использования «узких» действий и исключения объектов авторизации из области определения предиката.\\ -->
<!-- Очевидно, что в таком случае нет никакого способа запретить действия, которые действительно зависят от объекта авторизации. Пример: «Пользователи, которые не являются администраторами не имеют права редактировать и удалять не свои посты». -->

#### No authorization object at all
<!-- На самом деле можно обойтись без объекта авторизации, перенося политику авторизации на уровень логики приложения. -->

<!-- Для указанного выше примера удаление логически делается только среди собственных постов: `DELETE FROM posts WHERE author_id=&current_user_id AND id=&post_id`.\\ -->
<!-- А для администраторов добавляется отдельный доступный только им список постов, где можно делать всё что угодно. -->

<!-- Проблемы, как видно из примера, две: -->
<!-- 1. Действия приходится делать очень «узкими», чтобы с помощью субъекта и действия можно было как-то ограничивать доступ. -->
<!-- 2. Там, где такой способ не позволяет полностью контролировать действие, ограничение переносится на уровень логики работы. -->

<!-- И если в первом случае ещё нет явных проблем (хотя архитектура интерфейса страдает), вторая проблема куда хуже. -->

<!-- Перенося разграничение прав на уровень логики мы **разделяем одно бизнес правило (нельзя/можно что-то делать) на несколько высказываний в коде**.\\ -->
<!-- Таким образом программист, который откроет оригинальную задачу в трекере и начнёт искать соответствующий код в политиках авторизации может потратить на поиск ответственного участка кода больше времени.\\ -->
<!-- Ну и бонусом: пользователь вместо ошибки 403 получит ошибку 404. Хотя чаще всего это не сильно портит проектирование интерфейса. -->

#### Somehow getting authorization object
<!-- Казалось бы, на схеме всё исправляется просто: -->

<!-- ![Совершение действия с авторизацией и объектом в MVC](/assets/img/posts/2019-05-04-MVC-authorization/MVC authorization with object.png) -->

<!-- Но в действительности теперь надо делать `select` в не в контроллере, а до него. -->

<!-- В модульной системе всё достаточно просто: добавляем перед контроллером и модулем авторизации блок, который предзагружает данные, а затем в контроллере делаем на пару селектов меньше: -->
<!-- ```elixir -->
<!-- defmodule App.PostController do -->
<!--   use App, :controller -->

<!--   plug( -->
<!--     App.Plugs.PreloadObject, -->
<!--     [function: &__MODULE__.preload_post/2, as: :post] -->
<!--     when action in [:show, :update, :delete] -->
<!--   ) -->

<!--   plug(App.Plugs.Authorization, for: :post) -->

<!--   # ... -->

<!--   def preload_post(_conn, %{"id" => id}), do: Posts.get!(id) -->
<!-- ``` -->

<!-- В данном случае `App.Plugs.PreloadObject` использует указанную функцию загрузки и складывает объект авторизации в `conn`, а затем `App.Plugs.Authorization` на основе этого объекта и правил авторизации определяет, можно ли выполнять действие. -->

<!-- Преимущества такого подхода очевидны: -->
<!-- 1. Получаем возможность полноценно определить предикат {% raw %}$$p(\{s, a, o\})$${% endraw %}. -->
<!-- 2. Ошибки 404 и 403 теперь чётко разграничены. -->

<!-- Теперь о недостатках: -->
<!-- 1. Теперь контроллер — не единственная точка работы с данными на пути обработки запроса! Если поменяется код работы (в частности `select`) с постами — надо будет идти потенциально в два места. -->
<!-- 2. Теперь при определении полноценного предиката нет возможности проверить доступность до получения объекта. И хотя это — то, к чему мы осознанно шли, в высоконагруженных системах такое поведение может значительно добавить нагрузки в тех сценариях, когда большая часть запросов может быть отвергнута с использованием {% raw %}$$p(\{s, a\})$${% endraw %}. -->

#### Applying predicate before authorization object identification
<!-- Теоретическая возможность сделать двухэтапную авторизацию для высоконагруженных систем есть: достаточно свести предикат в области {% raw %}$$S×A×O$${% endraw %} к предикату в области {% raw %}$$S×A$${% endraw %}, но -->
<!-- 1. Это приведёт к поддержке в коде двух предикатов вместо одного. А в действительности это будет поддержка {% raw %}$$2·n$${% endraw %} меньших предикатов вместо {% raw %}$$n$${% endraw %}\\ -->
<!-- ({% raw %}$$\displaystyle\bigvee_{i=1}^{n} {p_{i}(\{s, a\}) ∧ p_i(\{s, a, o\})}$${% endraw %} вместо {% raw %}$$\displaystyle\bigvee_{i=1}^{n} p_i(\{s, a, o\})$${% endraw %}). -->
<!-- 2. На практике я такого не делал, поэтому про подводные камни рассказать не могу. -->

### Action identification
<!-- Тут тоже есть свои особенности в реальных системах. -->

<!-- Проблема в том, что отображение действия происходит не один раз: сначала внешнее действие отображается на внутреннее на уровне контроллера, потом контроллер отображает это на одно (или несколько) действий модуля бизнес-логики, которые уже отображают свои действия на действия уровня данных или низкоуровневые процедуры (например, печать). -->

<!-- И тут встаёт проблема выбора уровня отображаемых действий для авторизации. -->

<!-- Типичные библиотеки для описания авторизации (как минимум [рельсовые](https://github.com/varvet/pundit)) переносят это на уровень бизнес-логики (а с active record этот слой ещё и смешан со слоем хранения). -->

<!-- Я же считаю, что для авторизации нужно использовать отображение как можно более близкое к вводу, потому что -->
<!-- 1. Отображение уровня контроллера позволяет делать действия бизнес-логики и работы с данными максимально широкими, что уменьшает количество дублируемого кода и позволяет выстроить достаточно высокоуровневые абстракции. -->
<!-- 2. В то же время действия уровня контроллера можно делать максимально узкими для построения минимально-необходимого интерфейса (что уменьшает уровень энтропии интерфейса). -->
<!-- 2. Авторизация не будет «ломаться», если одно действие уровня контроллера будет отображатся на несколько действий более низкого уровня. -->

<!-- Но в общем и целом, помня про текучие абстрации, можно руководствоваться подходом, при котором предикат будет иметь наименее объёмное определение. В частности иногда есть смысл авторизовать действие на уровне бизнес-логики, а не на уровне контроллера. -->

### Reverse authorization
This is more of a hack, than a proper solution, but I had to do it.

Sometimes you may need not only to perform authorization, but "reverse authorization" — get a list of available actions instead of authorizing already identified acion.

I developed this approach: take all actions and apply predicate to all of them with current subject and object.

It worked. But problem is that sometimes button should be disabled not only by authorization rules, but by logic (i.e. action doesn't make sense for that exact object).

There're two ways:
1. Create logically impossible actions predicate and conjunct it with authorization predicate.
2. Add app logic constraints to authorization predicate.

Shame on me, I went with the last. And it's really bad 'cause of two reasons:
1. Authorization and logic rules are not the same so it makes sense to separate em.
2. Authorization predicate grows at {% raw %}$$k$${% endraw %} conditions for every authorization condition: {% raw %}$$\displaystyle\bigvee_{i=1}^{n} {\displaystyle\bigvee_{j=1}^{k_i} p_{ij}(\{s, a, o\})}$${% endraw %}.

## Conclusion
Authorization for simple application is, well, simple. Problems are in choosing approach, not in theoritical volume.

Despite being a simple matter many still implement MVC-application authorization intuitivly, which leads to fragile and "stiff", sometimes even "incorrect" design.
