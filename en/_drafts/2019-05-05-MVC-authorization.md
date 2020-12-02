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
![Authorized action diagram](/assets/img/posts/2019-05-04-MVC-authorization/en/Generic authorization flow.png)

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
One may have to operate on multiple objects at the same time. Obviously, conjunction of every action will answer the question of "can?":
{% raw %}$$p_{group} = \displaystyle\bigwedge_{i=1}^k p_i$${% endraw %}.

### Action mapping
Generally action mapping depends on input-output system used. But we can have a look at **system objects** to **actions** relation.

For actions "add comment to post #2", "modify post #3", "print my posts report", "drop nuclear bomb at Moscow" there're two approaches.

#### "Wide" actions
With that approach actions would be "add", "modify", "print" and "drop". Therefore **system object** classes would be derived at identification or supplied as action payload.

Wide actions have two types of identificators: for specific **system objects** and for **system object subsets** (also might be called **system object classes**). An example of such object class is "Posts".

#### "Narrow" actions
"Narrow" actions might be described as "add comment to post", "modify post", "print my posts report" and "send a nuclear bomb". Obvoiusly, unlike "wide" actions these already include object class identifier, thus no need to specify it with any identificators.

#### "Wide" vs "narrow" choice
Despite being distinguished in this article actions can be "wide" and "narrow" at the same time, specifying condition both within it's definition and identification data.

## Now to the real world
So, let's talk about typical MVC applications

As ex-RoR and currently Elixir/Phoenix developer I'll describe things assuming [rack](https://github.com/rack/rack) or [plug](https://github.com/elixir-plug/plug) being used.

Usually it looks like this:

![Authorized action in MVC application](/assets/img/posts/2019-05-04-MVC-authorization/en/MVC authorization.png)

### Where's authorization object
This was the first problem I encountered, when I was building real-world authorization.

Most libraries and vendor solutions use this predicate {% raw %}$$p(\{s, a\}), \{s, a\} ∈ S×A$${% endraw %} instead of this {% raw %}$$p(\{s, a, o\})$${% endraw %}. This is used with lots of narrow actions and excluding **authorization object** from predicate domain.\\
Obviously, this approach has now way on object-based restraining. For example: "Non-administrators are not allowed to delete other's posts".

#### No authorization object at all
There is a way to build systems without **authorization object** (but with authorization): moving authorization logic to business logic.

For previous example: `DELETE FROM posts WHERE author_id=&current_user_id AND id=&post_id` to delete only owned posts.\\
And then you make separate action for administrators to do whatever they want.

There're two problems with that approach:
1. Actions are very "narrow" so that subject and action alone are enough for proper restriction.
2. Authorization is partially implemented within business logic.

While first problem is usually ok (but still resolves to bulky interfaces), second one makes things really bad.

Moving restricions from authorization to business logic we separate **a single business rule to separate definitions**.\\
So, engineer might waste a lot of time looking for proper definition to fix or change something regarding certain business rule.\\
Bonus is that user get 404 error instead of 403. Which is not that much of a problem usually.

#### Somehow getting authorization object
It looks like a simple thing on this diagram:

![MVC Authorization with object](/assets/img/posts/2019-05-04-MVC-authorization/en/MVC authorization with object.png)

But in real world `select` should be done before getting to controller.

With modular request processing system it's easy to do so: just put some code before controller and authorization module to preload data and possibly use this data later in controller:
```elixir
defmodule App.PostController do
  use App, :controller

  plug(
    App.Plugs.PreloadObject,
    [function: &__MODULE__.preload_post/2, as: :post]
    when action in [:show, :update, :delete]
  )

  plug(App.Plugs.Authorization, for: :post)

  # ...

  def preload_post(_conn, %{"id" => id}), do: Posts.get!(id)
```

In this scenario `App.Plugs.PreloadObject` uses provided preloading function and puts authorization object into `conn`, then `App.Plugs.Authorization` uses this object to perform authorization check.

So here're some pros for this approach
1. It's possible to fully define predicate {% raw %}$$p(\{s, a, o\})$${% endraw %}.
2. 404 and 403 errors are distinguished.

But here're cons:
1. Controller is not the only data manipulation request handler! In case we need to change something about `select` for controller we'll have to change it **not** in the controller.
2. Obtaining authorization object for every request is not a good idea for systems with high load. Despite going for this specifically there're scenarios where only {% raw %}$$p(\{s, a\})$${% endraw %} "subpredicate" could be used without unnecessary data loading.

#### Applying predicate before authorization object identification
In theory it's possible to make two-step authorization for highload system: {% raw %}$$S×A×O$${% endraw %} predicate could be reduced to {% raw %}$$S×A$${% endraw %}, but
1. It results in writing two predicates instead of one. In real world it would be {% raw %}$$2·n$${% endraw %} predicates instead of {% raw %}$$n$${% endraw %}.\\
   {% raw %}$$\displaystyle\bigvee_{i=1}^{n} {p_{i}(\{s, a\}) ∧ p_i(\{s, a, o\})}$${% endraw %} instead of {% raw %}$$\displaystyle\bigvee_{i=1}^{n} p_i(\{s, a, o\})$${% endraw %}).
2. I'we never done that myself, so I'm not sure of all caveats of this approach.

### Action identification
Problem is, action identification is done multiple times. First, external action is mapped into internal action at controller level, then controller maps internal action into one (or more) business logic actions, which then map these into lower level actions.

So we have to choose, which action level should be used for authorization.

Usually authorization libraries (like some for [Rails](https://github.com/varvet/pundit)) insist on authorizing business logic.

I think that actions that are most close to user-facing IO (controller actions) should be authorized:
1. Controller-level mapping allows for widest business logic and storage level actions, which reduces code duplication and makes it easier to operate with higher-level abstractions.
2. Controller actions could be very "narrow" (specific) to build as small interface as possible (which reduces interface entropy).
3. Authorization won't break if controller action is mapped into multiple business-logic level operations.

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
