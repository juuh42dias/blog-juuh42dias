---
layout: post
title: "Finite State Machine"
date: 2017-08-10 14:14:58 +0000
categories: programming tecnologia
tags: programming tecnologia
canonical_url: https://medium.com/meucredere/finite-state-machine-f80da78a4965?source=rss-88eca5a5b283------2
source: medium
---

Sometimes we need to apply a state in some cases when we want to modify a status of an object. A basic example is water state: gaseous, liquid and solid and the events responsible for change it:

> Object: Water

> Event: Fusion
States: From solid to liquid

> Event: Evaporation
States: From liquid to gaseous

> Event: Condensation
States: From gaseous to liquid

> Event: Solidification
States: From liquid to solid
Look at this as a simple example that happens around us. As in many other cases, we can apply it in programming using something called state machine.

![](https://cdn-images-1.medium.com/proxy/1*DRWWhBcOin28vDCiIjGeyg.png)In the above example, we have different states and events responsible for change these states. Proposed, accepted, rejected and pending are possible states for a object and the state of an object can change when an event occurs. Pretty similar to the example of water states, right?

*Originally published at *[*medium.com*](https://medium.com/@railsgirlsgyn/finite-state-machine-f56d652c1e6f)* on August 10, 2017.*

![](https://medium.com/_/stat?event=post.clientViewed&referrerSource=full_rss&postId=f80da78a4965)[Finite State Machine](https://medium.com/meucredere/finite-state-machine-f80da78a4965) was originally published in [MeuCredere](https://medium.com/meucredere) on Medium, where people are continuing the conversation by highlighting and responding to this story.