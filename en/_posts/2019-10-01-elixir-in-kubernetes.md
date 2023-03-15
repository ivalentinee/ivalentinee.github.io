---
layout: post
title:  "Elixir in k8s"
date:   2020-08-22
categories: programming
uid: elixir-in-kubernetes
---

## Why?
Because I can. Because this was the only way to setup service communication.

And as I'm an [Elixir](https://elixir-lang.org/) writer, I'll give code examples in Elixir (just joking, there'll be no code examples).

## Source materials
I used these articles:
- [Erlang (and Elixir) distribution without epmd](https://www.erlang-solutions.com/blog/erlang-and-elixir-distribution-without-epmd.html) (more to understand what's going on)
- [Clustering Elixir/Erlang applications in Kubernetes](https://blog.ispirata.com/clustering-elixir-erlang-applications-in-kubernetes-part-1-the-theory-ca658acbf101) (as an example for the setup)

## Let's begin
So, this is the situation: there's production app with N services (N ≤ 10) deployed to k8s ([openshift](https://www.openshift.com/) actually, but that doesnt matter) as a set of deploymentconfig, some deployments have [k8s services](https://kubernetes.io/docs/concepts/services-networking/service/) and [routes](https://docs.openshift.com/enterprise/3.0/architecture/core_concepts/routes.html) pointed at them. Some services (not k8s services) use redis/memcached/PG/kafka/whatever to exchange data.

But *suddenly* (as it usually goes) a need for direct service communication appeared. For an Elixir app there're more than one (two actually) ways of such communication:
1. Using "third-party" protocols (grpc and others)
2. Using [OTP](https://ru.wikipedia.org/wiki/Open_Telecom_Platform)

I decided to go with OTP for these reasons:
1. ~~Too lazy~~ not enough time to implement (even with libraries) grpc and others.
2. Dude, that's erlang, c'mon, we're *fashion-driven* programmers, aren't we?

Erlang part of things is [really simple](http://erlang.org/doc/reference_manual/distributed.html), but infrastructure caused a bit of pain.

## Fairytale-case scenario
For fairytale-case there should be __fixed__ [DN](https://en.wikipedia.org/wiki/Domain_name) for all instances of each service which automatically properly deployed and services have full network interconnection (tcp, ofc).

Then we'll just start the node:
```shell
ERL_OPTIONS="-name ${SNAME}@${HOSTNAME} -setcookie ${ERLANG_COOKIE}"
elixir --erl "${ERL_OPTIONS}" -S mix run --no-halt
```
And run:
```elixir
Node.ping(:"some_other_node@some.other.domain.name")
# => :pong
```

But I don't work in fairytale infrastructure with ponies, rainbows and respectful infrastructure ingeneers. Ugh.

## DN discoverability
So, first problem: DNs are __dynamic__ with regular deploymentconfig. And using some sort of service-discovery won't work properly because erlang node wants to know it's full DN at start.

Or something like that.

If we use [service'ы](https://kubernetes.io/docs/concepts/services-networking/service/), we can have one DN for one deploymentconfig. But what if we have multiple instances? Where the connection will go?

To sort this out we have to divide services in two groups:
1. Waiting for connection
2. Initiating connection

### Waiting for connection
This one's simple but has it's limitations.

We just **don't scale** these services (urghhh...).

So the only instance will be available at [service](https://kubernetes.io/docs/concepts/services-networking/service/) DN like `exclusive-service.project.svc.cluster.local`.

Then we start an application with known DN (I decided not to set `HOSTNAME`, but use separate `CLUSTER_HOSTNAME` variable):
```shell
ERL_OPTIONS="-name ${SNAME}@${CLUSTER_HOSTNAME} -setcookie ${ERLANG_COOKIE}"
elixir --erl "${ERL_OPTIONS}" -S mix run --no-halt
```

### Initiating connection
This one's even simpler: just start this process with any FQDN (so erlang to start with FQDN-mode). I just added some breach for debugging.

[Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod/) are available (through [services](https://kubernetes.io/docs/concepts/services-networking/service/)) at `<pod-name>.<service-dn>` addresses, like `pod-12345-qwerty.non-exclusive-service.project.svc.cluster.local`. But we only know `service-dn` beforehand and `pod-name` is put into `HOSTNAME` variable as start.

What should we do? Build effective DN at start:
```shell
ERL_OPTIONS="-name ${SNAME}@${HOSTNAME}.${CLUSTER_HOSTNAME} -setcookie ${ERLANG_COOKIE}"
elixir --erl "${ERL_OPTIONS}" -S mix run --no-halt
```

So if one service will have to instances we'll be able to communicate to every instance with it's name. This method could be used with service-discovery. I just use it for debugging.

## Ports
Problem #2: port forwarding. There're to ports required: [epmd](https://erlang.org/doc/man/epmd.html) and erlang process itself

### empd
Again, pretty simple.

[epmd](http://erlang.org/doc/man/epmd.html) uses `4369` as listening port. So we need to forward it in [services](https://kubernetes.io/docs/concepts/services-networking/service/):
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

### Erlang process
That one's a bit tricky. Every erlang process listens at some random port for OTP connections and registers at empd. For outgoing connections erlang process connects to epmd and asks "which port *this* process runs at?"

And, as epmd problem is easily solved, "random" port requires some more handling.

Forwarding all 65535 ports is not a good idea for many reasons (including me not finding directive "forward everything, I don't care").

To enable erlang processes communication we should forward some **exact** port and force erlang process to listen on that port.

First one is, again, simple:
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

For the second one we can use `inet_dist_listen_min` и `inet_dist_listen_max` start options, which set listening port range, to limit erlang process to exactly one port:
```shell
ERL_PORT=43691
ERL_KERNEL_OPTIONS="-kernel inet_dist_listen_min ${ERL_PORT} inet_dist_listen_max ${ERL_PORT}"
ERL_OPTIONS="-name ${SNAME}@${CLUSTER_HOSTNAME} -setcookie ${ERLANG_COOKIE} ${ERL_KERNEL_OPTIONS}"
elixir --erl "${ERL_OPTIONS}" -S mix run --no-halt
```

And, voila, erlang processes are running and communicating!

Obviously, running multiple OS erlang processes is impossible with this approach. But don't we use k8s just for that "one process per container"?

Of course, we can just [omit empd at all](https://www.erlang-solutions.com/blog/erlang-and-elixir-distribution-without-epmd.html) for single-process setup, but that requires copy-pasting some actual erlang code.

## Conclusion
This approach is for deploymentconfigs. There's alternatice [using StatefulSets](https://blog.ispirata.com/clustering-elixir-erlang-applications-in-kubernetes-part-1-the-theory-ca658acbf101), which, in theory, looks cooler, but required complete resetup for an already running production app (no downtimes allowed, ofc).
