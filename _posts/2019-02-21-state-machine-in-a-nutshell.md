---
layout: post
title: "State Machine in a nutshell"
date: 2019-02-21 18:15:13 +0000
categories: ruby statemachine water
tags: ruby statemachine water
description: "Sometimes we need to apply a state in some cases when we want to modify a status of an object. A basic example is water state: gaseous, liquid and solid and the events responsible for change it"
canonical_url: https://dev.to/juuh42dias/state-machine-in-a-nutshell-13o2
source: dev.to
---

---
title: State Machine in a nutshell
published: true
description: "Sometimes we need to apply a state in some cases when we want to modify a status of an object. A basic example is water state: gaseous, liquid and solid and the events responsible for change it"
tags: ruby, state machine, water 
---

Sometimes we need to apply a state in some cases when we want to modify a status of an object. A basic example is water state: gaseous, liquid and solid and the events responsible for change it:

```ruby
Object: Water
Event: Fusion
States: From solid to liquid
Event: Evaporation
States: From liquid to gaseous
Event: Condensation
States: From gaseous to liquid
Event: Solidification
States: From liquid to solid
```

Look at this as a simple example that happens around us. As in many other cases, we can apply it in programming using something called state machine.

![State Machine code screenshot](https://thepracticaldev.s3.amazonaws.com/i/s7enneflko6syr2zp99a.png)

In the above example, we have different states and events responsible for change these states. `Proposed`, `accepted`, `rejected` and `pending` are possible states for a object and the state of an object can change when an event occurs. Pretty similar to the example of water states, right?
