---
layout: post
title: "Durable execution for AI agents: your loop is a distributed system"
date: 2026-11-25 09:00:00 -0300
categories: ai agents temporal durable_executions distributed_systems
tags: ai agents temporal durable_executions distributed_systems
description: "An IEEE SmartCloud 2026 paper formalizes the durable agent loop. Here's what it says about state loss, retries, and how Temporal's Workflow/Activity split maps to it."
---

You know when an agent is halfway through a task and the worker dies? The demo never shows that part.

The model has already called three tools. Two of them wrote to external systems. The process holding the loop is gone. What happens next? Do you retry the whole run? Replay the conversation? Hope the payment didn't go through twice?

That's the failure mode Stenio de Lima Ferreira's paper, [Durable Execution for AI Agents: A Design Pattern for Fault-Tolerant Agent Loops](https://ieeexplore.ieee.org/document/11638700), puts on the table. It was published at IEEE SmartCloud 2026 (DOI: [10.1109/SmartCloud69481.2026.00014](https://doi.org/10.1109/smartcloud69481.2026.00014)), and the short version is uncomfortable: an AI agent loop is a distributed system. If you run it as a script in memory, you're one crash away from losing state, duplicating side effects, or abandoning the workflow.

I've been talking about the Temporal side of this for a while. I presented [Durable Workflows with Temporal](https://www.rug-b.de/events/november-meetup-2026-2927) at RUG::B Berlin in November, and I wrote the [Temporal walkthrough](https://blog.juliana.dev/blog/what-is-temporal-and-how-this-works) earlier this year. This post connects the three: what the paper formalizes, what the talk shows in practice, and where the limits are.

## The failure mode nobody demos

An agent loop looks simple: the model decides on an action, a tool runs, the result goes back into the context, and the loop repeats until the goal is reached. In a demo, that loop lives inside one process and one happy path.

In production, the loop can live for minutes, hours, or days. It waits for a human approval. It calls an API that times out. It runs while you deploy a new version. The process can die at any point, including after a tool has changed the outside world but before the loop records the result.

The paper is precise about why this hurts. Existing agent frameworks such as LangGraph, CrewAI, and AutoGen make prototyping easier, but they often keep state in memory or rely on periodic checkpoints. A checkpoint-based recovery model has a consistency gap: if the process fails after an external tool executes but before the state is saved, the agent's internal state and the external world no longer agree. You get incomplete transactions, duplicated operations, or a workflow that is simply abandoned.

That's not an LLM problem. It's the same partial-failure problem we've had in distributed systems for decades, now with a model in the loop. The model can be non-deterministic; the execution around it still has to be reliable.

## What the paper actually proposes

The paper compares two ways to manage stateful agent execution:

- **Checkpoint-based:** persist a snapshot of the complete runtime state at intervals. Simple, but the gap between "tool ran" and "checkpoint saved" is exactly where failures hurt.
- **Event-sourced:** record every operation as an immutable event before moving on. This gives operation-level atomicity, but it requires deterministic control flow and a clean separation of side effects.

The paper's answer is the **Durable AI Agent Loop Architecture**, built on three primitives:

| Primitive | What it does | Temporal equivalent |
|---|---|---|
| Deterministic control flow | The orchestrator runs the agent loop and makes the same decisions on replay. No direct I/O, clock reads, or random values. | Workflow |
| Managed side-effect abstraction | LLM calls and tool invocations become atomic units that can be retried and persisted. | Activities |
| Event-sourced state persistence | Every operation is written to an immutable log before execution continues. | Event History |

The nuance that matters: determinism here is **structural workflow determinism**, not LLM output determinism. The paper is explicit about this. The model can return a different answer every time; what has to replay identically is the orchestration path against the recorded history. If an agent completes steps 1-5 and fails on step 6, replay returns the recorded results for 1-5 and only re-executes step 6.

That's the same idea behind Temporal's Workflow/Activity split. Workflows hold the control flow and must be deterministic. Activities do the real work: LLM calls, tool calls, database writes, HTTP requests. Once an activity completes, its result is persisted. During replay, the workflow gets the stored result instead of calling the model or the tool again.

The event log also removes a subtle failure the paper calls **side-effect divergence**: an external tool executes successfully, but the result is lost before the agent records it. The paper calls these "ghost executions." If the agent's state says the tool never ran, it can repeat an effect that already happened. With log-first execution, an LLM response is only considered committed once it has been logged, so the agent's internal state stays aligned with its external actions.

## The paper didn't stop at architecture

The reference implementation uses Temporal with Python and LiteLLM, and it's split into four files: `workflow.py` for the deterministic loop, `activities.py` for LLM inference and tool execution, `worker.py` for the worker process, and `start_workflow.py` for the client. Then the authors ran fault injection against it.

The results are the part I'd put in front of every team building agents:

- **Process crash:** they sent a `SIGKILL` right after a successful LLM inference. When the worker restarted, the workflow reconstructed state from the event log. The LLM call was not re-executed; replay returned the recorded result and scheduled the next tool. That preserves both cost and execution intent.
- **External service timeout:** the activity raised `ServiceUnavailable` for the first three attempts. The platform applied exponential backoff, kept the workflow running without consuming compute while waiting, and completed once the service recovered. No manual error handling in the workflow logic.
- **Logic fault and hot fix:** they introduced a runtime exception after the LLM planning result had been committed. After deploying a fix and restarting the worker, the workflow replayed from the event log, retrieved the existing LLM result, and executed the corrected logic. The agent didn't restart from the beginning.

The performance numbers are also more grounded than the usual "durable execution is free" pitch. In the paper's local environment, a real LLM interaction averaged 705 ms; a mock LLM averaged 81 ms. The durability layer added about 81 ms per interaction, roughly 11% of end-to-end latency with a real model. That's a small tax relative to inference, but it's not zero, and the paper says it can accumulate in workflows with many state transitions.

The paper is honest about the tradeoffs: you have to operate durable execution infrastructure, you have to keep workflow code deterministic, and you have to accept the extra latency. The talk adds the operational costs: a Worker fleet to run, versioning discipline for long-lived Executions, and the learning curve around replay and the primitives. The ROI is the code you stop maintaining: hand-rolled state machines and status columns, reconciliation cron jobs, and ad-hoc retry and backoff code. The paper also draws a useful line between durable execution and sagas. Sagas coordinate compensating actions when a business transaction fails logically. They don't recover the state of a worker that crashed mid-step. Durable execution is about continuity of execution; you often need both. The paper also flags dynamic replay/branching, log compaction, and a comparative framework analysis as future work.

And the pattern is not Temporal-only. The paper maps the same primitives to Azure Durable Functions and AWS Step Functions. Temporal was chosen for the reference implementation because it's open source and self-hostable, which makes the experiment reproducible without cloud accounts.

## From the paper to the talk

At RUG::B, I framed the talk around the same problem: how to get crash-proof execution without hand-rolled state machines and retry code. The talk is explicitly about durable execution, not "another job runner."

The paper gives that promise a formal shape for AI agents. The talk gives the mechanics I keep coming back to:

- **Workflow vs Activity:** the Workflow is deterministic orchestration; the Activity is the retried side effect. The selection rule I use is Activity by default, Workflow only for orchestration.
- **Event History and replay:** the append-only log is the source of truth. Replay re-runs Workflow code and matches Commands against recorded Events; Activity results are reused, not recomputed.
- **The guarantees:** exactly-once completion, at-least-once Activities (so idempotency is required), and state recovery after Worker or Service failures.
- **The operational surface:** retries and timeouts are configuration, not code. Signals, Queries, and Updates handle external interaction; Continue-As-New bounds Event History; Child Workflows partition work; Worker Versioning handles deploys while Executions are running.

Retries are configuration: Activity attempts are unlimited by default, `non_retryable_error_types` make permanent failures fail fast, and timeouts bound each attempt and the total duration.

The Service never runs your code; only Workers do. If a worker dies, another one replays the history and continues from the first step that has no recorded result. The talk's code is Ruby, not Python: a `MoneyTransferWorkflow` with `Withdraw`, `Deposit`, and `Refund` activities, a retry policy with `non_retryable_error_types`, and a `begin/rescue ActivityError` that runs the compensating Refund. The shape is the same as the paper's reference implementation: orchestration in the workflow, side effects in activities, recovery from history.

The price is the same one the paper lists: determinism. No `Time.now`, no random values, no direct HTTP calls inside the workflow. Those go into activities or workflow APIs. The determinism rule is not a style guide. A non-deterministic call can fail a running Execution with a non-determinism error. It feels restrictive until you remember what you're buying: a run that can survive a crash, a deploy, or a three-day wait without losing its place.

That exactly-once guarantee is about the workflow's completion, not each external side effect. If a tool charges a card and the response is lost, a retry can charge again. The paper is explicit that activities modifying external state must be idempotent. Durable execution gives you the recorded result and the recovery point; idempotency keys are still your job.

## The Temporal side, if you want the internals

I wrote about the Temporal architecture before: workflows, activities, workers, retries, timers, human-in-the-loop, and a full Ruby money-transfer example. If you want to see the mechanics rather than the paper summary, start here:

[What is Temporal and how this works?](https://blog.juliana.dev/blog/what-is-temporal-and-how-this-works)

The paper's reference implementation is Python; the talk's is Ruby. The mental model is the same. The loop is a workflow. The model call and each tool call are activities. The event history is the autosave, and it's also the audit trail: the Web UI and CLI show inputs, outputs, retries, and timestamps for each Execution. The difference is that the paper measures what happens when you kill the process at the worst possible moment.

## What I'd check in your own architecture

The paper's conclusion points to the right test for your own agents: can yours survive a crash, a timeout, and a code deploy without losing state or repeating a side effect? If the answer depends on the process staying alive, you have a reliability bottleneck.

A few questions I'd ask before adding durable execution:

- If the worker dies after a tool call, do you know whether the tool ran?
- If the agent waits three days for a human, what keeps its state?
- If you deploy while a run is open, does it resume or restart?
- If a retry happens, is the side effect idempotent?

One more distinction from the talk: a webhook is an HTTP request you have to make durable yourself. A Signal is a first-class, durable message that goes into Event History and is replay-safe. Queries read state without writing history; Updates are synchronous, validated writes. If your agent waits for a human, that difference matters.

The talk's fit list is explicit: multi-step business processes, long waits, sagas, bounded fan-out, AI agents with human checkpoints, and systems that need an audit trail. It's not a Sidekiq replacement for every job, and it's not built for sub-second high-throughput streams. Not every agent needs Temporal. A short, read-only agent that finishes inside one request can stay in-process. A bounded background task with safe retries can live on a queue. The threshold changes when the run waits for a person, crosses deploys, spends real tokens, or writes to external systems. At that point, durable execution stops being infrastructure trivia and becomes part of the product.

The paper's contribution isn't a new agent framework. It's a precise way to talk about the problem, plus a reference implementation and failure-injection evidence: an agent loop is a distributed system. Once you treat it like one, the questions change from "which model?" to "where does the state live, and what happens when the process dies?"

I talked about the Temporal mechanics at [RUG::B Berlin](https://www.rug-b.de/events/november-meetup-2026-2927) in November. If you're building agents that outlive a single request, I'd like to hear where your state lives.
