---
layout: post
title: "AJDC vs Temporal: durable execution for Rails and beyond"
date: 2026-09-26 16:00:00 +0300
categories: workflows temporal ajdc durable_executions ruby rails
tags: workflows temporal ajdc durable_executions ruby rails
description: "AJDC vs Temporal: two ways to never lose your place again — ActiveJob with durable continuations in Rails vs a full durable execution platform"
canonical_url: https://blog.juliana.dev/ajdc-vs-temporal
source: dev.to
---

You know when you're building an application and you have a sequence of steps that need to happen? Like: charge the credit card, send the email, update the database. If one of those steps fails, what happens? Do you retry? Do you rollback? Who keeps track of where you left off?

In my [last post about Temporal](/blog/what-is-temporal-and-how-this-works) we looked at one answer: a durable execution platform that acts like an autosave for your application state. If something fails mid-execution, Temporal remembers exactly where it was and picks up from there.

But what if you are in Rails, with Active Job and Solid Queue, and you don't want a whole new cluster to operate? That's where AJ/DC comes in.

In this post I'll compare the two side by side: [palkan/ajdc](https://github.com/palkan/ajdc) — Active Job Durable Continuation — and [Temporal](https://temporal.io). Same problem, very different tradeoffs.

## Meet AJ/DC

AJ/DC is a tiny Ruby gem by Vladimir Dementyev ([palkan](https://github.com/palkan)). The pitch fits in one line:

> Make an `ActiveJob::Continuable` job's run and steps durable: recorded in the database, not only in the job payload, so progress survives a crash, not only a graceful restart.

If you are on Rails 8.1+, you already know `ActiveJob::Continuable` with `step`, `cursor` and `attribute`. AJ/DC is a drop-in swap:

```ruby
# before
class ImportJob < ApplicationJob
  include ActiveJob::Continuable
end

# after
class ImportJob < ApplicationJob
  include ActiveJob::Durable
end
```

That's it. `step`, cursors and `attribute` keep working exactly as they do today. But every checkpoint now commits the run and the current step's cursor to the database, so a `SIGKILL` loses at most the work since the last checkpoint.

Setup is pure Rails:

```bash
bundle add ajdc
bin/rails generate ajdc:install
bin/rails db:migrate
```

You get two tables: `active_job_durable_runs` and `active_job_durable_steps`. No new service, no Go binary, no cluster. It reuses whatever queue you already have — Solid Queue included.

Requirements today: Ruby (MRI) >= 3.3, Rails >= 8.1, SQLite / PostgreSQL / MySQL.

## Quick recap: Temporal

Temporal is the other end of the spectrum: a full durable execution platform.

Three pieces, as we saw last time:

**Workflows** — The orchestration logic. They define the sequence of steps, handle errors, and manage state. Workflows must be deterministic (no random, no IO, no system clock).

**Activities** — The actual work. They do the real stuff: call APIs, read/write databases, send emails. Activities can be retried and have timeouts.

**Workers** — The processes that host and execute Workflows and Activities. Workers poll the Temporal Server for tasks and execute them.

The Temporal Service keeps a full event history of every execution. If a worker crashes, another one replays that history to recover the state and continues. SDKs exist for Go, Java, TypeScript, Python, .NET, PHP, and Ruby.

It's MIT-licensed and open source (~23k stars, 9 years in production), and you can self-host or pay for Temporal Cloud.

## The superpowers, side by side

Both give you the things that are painful to build yourself. Here's how they map:

| Capability | AJ/DC | Temporal |
|---|---|---|
| Crash recovery | DB checkpoint per `step` / `checkpoint!` | Event history replay after every Activity |
| Long runs | Weeks/months via DB rows + heartbeat | Years, 200M+ executions/sec on Cloud |
| Retries | `retry_on`, `resume!` after `failed` | `RetryPolicy` with exponential backoff, infinite retries |
| Timers | `step :expire, wait_until: date` / `wait: 2.weeks` + `WakeJob` | `sleep("30 days")`, Timeouts, Schedules (cron replacement) |
| Human in the loop | `await :confirmation` + `wake_up(:confirmation, true)` | Signals / Queries / Updates, `await condition` |
| Uniqueness | `unique_by :import, on_conflict: :skip/:reject/:replace` | `WorkflowId` + `IdReusePolicy` |
| Visibility | `workflow_runs` ActiveRecord relation + scopes | Web UI: inspect, replay, rewind every execution |
| Language | Ruby on Rails only | Polyglot: Go, Java, TS, Python, .NET, PHP, Ruby |

Let's unpack the interesting ones.

**State machines — autosave for application state**

In Temporal, every workflow execution *is* a state machine. State is captured automatically.

In AJ/DC, the state machine is explicit and queryable:

```ruby
run = ActiveJob::Durable::Run.last
run.status          # => "completed"
run.current_step    # => nil
run.completed_steps # => ["validate", "process"]
run.state           # => {"processed_count" => 128}
```

And your job class knows its runs, newest first:

```ruby
ImportJob.workflow_runs
ImportJob.workflow_runs.failed.at_step(:process)
ImportJob.workflow_runs.live # enqueued, running, waiting, awaiting
ImportJob.workflow_runs.stuck_for(1.hour)
```

If you've ever debugged a stuck Solid Queue job by digging through logs, this feels like a superpower.

**Timeouts / timers — wait for 3 seconds or 3 months**

This is my favorite parallel. In Temporal with the Ruby SDK you'd write:

```ruby
class TrialWorkflow < Temporalio::Workflow::Definition
  def execute(user)
    until Temporalio::Workflow.execute_activity(
      HasUpgradedActivity,
      user,
      start_to_close_timeout: 10
    )
      Temporalio::Workflow.execute_activity(
        SendReminderEmailActivity,
        user,
        start_to_close_timeout: 10
      )
      Temporalio::Workflow.sleep(30 * 24 * 60 * 60, summary: 'wait 30 days')
    end
  end
end
```

In AJ/DC you declare it on the step:

```ruby
class License::LifecycleJob < ApplicationJob
  include ActiveJob::Durable

  unique_by :license, on_conflict: :replace

  def perform(license)
    step :remind, wait_until: license.expires_at - 2.weeks
    step :expire, wait_until: license.expires_at
    step :revoke, wait: 2.weeks
  end
end
```

When the run reaches a waiting step, its status becomes `waiting` and it leaves the queue. To wake sleepers you run one recurring job:

```yaml
# config/recurring.yml
durable_wake:
  class: ActiveJob::Durable::WakeJob
  schedule: every minute
```

Same idea, Rails flavor: the clock is a Solid Queue recurring job instead of a Temporal timer service.

**Human in the loop**

Sometimes a workflow needs a human decision — approve a transfer, review a document, confirm an import.

Temporal pauses on a signal. AJ/DC has `await`:

```ruby
class BulkImportJob < ApplicationJob
  include ActiveJob::Durable

  attribute :confirmed, :boolean, default: false

  def perform(import)
    await :confirmation, wait: 10.minutes
    return import.destroy! unless confirmed

    step :apply do
      BulkImportService.new.call(import)
    end
  end

  private
    def confirmation(signal) = self.confirmed = signal.presence
end
```

From a controller you send the signal:

```ruby
BulkImportJob.workflow_runs.for(import).live.sole.wake_up(:confirmation, true)
```

A signal sent *before* the `await` line is stored and replayed when the job reaches it. And if the deadline passes with no signal, the handler is called with `nil` so you decide how to continue. You can list everyone waiting:

```ruby
CardGenerationJob.workflow_runs.awaiting.at_step(:review)
```

If you built approval flows with `pending` columns and cron jobs before, you know how much boilerplate this removes.

**Uniqueness — don't double-book**

AJ/DC lets you enforce run uniqueness straight in the job:

```ruby
class ImportJob < ApplicationJob
  include ActiveJob::Durable

  unique_by :import

  def perform(import)
    step :check
    step :process
  end
end

ImportJob.perform_later(import) # => the job
ImportJob.perform_later(import) # => false, nothing enqueued
```

With `on_conflict: :skip` (default), `:reject` (raises `RunAlreadyExists`), or `:replace` (cancels the current run and starts a new one — perfect for something like a license lifecycle).

You can narrow the key with `identified_by` or set it verbatim with `set(workflow_key: ...)`. It's the Rails equivalent of Temporal's `WorkflowId`.

**Halting, cancelling, resuming**

This is where AJ/DC feels very Rails-y:

```ruby
halt_on InsufficientStorageSpaceError
discard_on ZipFile::InvalidFileError
```

`halt!` pauses for a human to fix something (out of storage, broken file) and keeps the cursor. `resume!` puts the job back in the queue from the same step. `cancel!` ends a non-terminal run — a queued job for a cancelled run performs nothing, a running job stops at its next checkpoint.

Terminal runs are kept 14 days by default via `HousekeepingJob`, and `failed` / `halted` runs are never auto-deleted. Stuck runs are yours to find with `stuck_for` — `enqueued` runs whose message never arrived, `running` runs with no heartbeat, parked runs the clock missed.

## Let's see some code

The classic Temporal example is money transfer — withdraw, deposit, refund on failure. The workflow orchestrates, activities do the work, retry policies handle the flakiness. You can find the full Ruby version in my last post and in the [money-transfer-project-template-ruby](https://github.com/temporalio/money-transfer-project-template-ruby) repo.

The AJ/DC equivalent is less ceremony because there's no Workflow/Activity split. Here's a bulk import with progress tracking:

```ruby
class ImportJob < ApplicationJob
  include ActiveJob::Durable

  attribute :processed_count, :integer, default: 0

  def perform(import)
    step :validate
    step :process do |step|
      import.records.find_each(start: step.cursor) do |record|
        record.process!
        self.processed_count += 1
        step.advance! from: record.id
      end
    end
  end
end
```

Notice how familiar this is: it's just Active Job with `step` blocks. `step.advance!` is your checkpoint. `processed_count` survives restarts because it's in `run.state`. Step callbacks work like Active Job callbacks:

```ruby
after_step :broadcast_update

def broadcast_update
  # @cable.broadcast_replace(...) with current_step.name
end
```

Before taking anything to production, you test it like any other job — plus `travel_to` + `ActiveJob::Durable.wake_up_due` for timers. No Docker, no `temporal server start-dev`. That's the whole appeal.

## How it all fits together

With AJ/DC: you enqueue as usual. The run row is written at first enqueue and at every re-enqueue. A worker executes it, heartbeats at every step boundary and checkpoint. If it dies, the run stays `running` or `enqueued` with a cursor. Another Solid Queue worker picks it up and re-runs the open step from its cursor.

With Temporal: you start a workflow via a client. The Server schedules it on a Task Queue. A worker polls, executes step by step, persisting history. If the worker crashes, another replays history and continues.

Same narrative — autosave + resume — different storage: your Postgres/SQLite vs Temporal's history store, your queue vs Temporal's task queues.

## When to pick which

Be honest about what matters:

**Pick AJ/DC when:**

- You are a Rails app with Active Job + Solid Queue and want durability next week, not next quarter
- Your workflows are per-record jobs: imports, billing lifecycles, reminders, diagnostics with `isolated: true` steps
- You want everything queryable with ActiveRecord and visible in your own admin
- You can't (or don't want to) operate another stateful service

**Pick Temporal when:**

- You are polyglot or multi-service: sagas across payments, inventory, notifications with compensations
- You need replay/rewind debugging, infinite retries, schedules at massive scale
- Your workflows live for months/years and cross team boundaries
- You are already building AI agents, MCP orchestration, or training pipelines — that's where Temporal is investing heavily right now

They're not mutually exclusive. Think of AJ/DC as "durable Active Job" and Temporal as "a distributed OS for reliable code." Start with AJ/DC, and if you outgrow DB-backed jobs or leave Rails, you'll already understand workflows, signals, timers and idempotency keys.

## Wrapping up

Running durable workflows in 2026 is genuinely a choice, not a chore: add a gem and two tables, or add a platform and get a UI, polyglot SDKs and Cloud scale.

My setup: for a Rails app with Active Job + Solid Queue + SQLite, AJ/DC is the obvious first try — same mental model, zero new infra. For cross-service money movement or long-lived AI pipelines, I'd still reach for Temporal.

> Note: part of that recommendation is maturity — AJ/DC is at 0.1.0 as of this writing, very new, versus Temporal's 9 years in production. Of course this solution will grow and evolve fast.

The docs worth bookmarking: [github.com/palkan/ajdc](https://github.com/palkan/ajdc) (small, readable, start with the README) and [docs.temporal.io](https://docs.temporal.io) + [temporal.io/how-it-works](https://temporal.io/how-it-works) for the full picture.

Want to run both sides yourself? The companion repo has the full demo — AJ/DC jobs on Rails + PostgreSQL and Temporal workflows in Ruby, with a verify script and step-by-step instructions: [github.com/juuh42dias/ajdc-vs-temporalio](https://github.com/juuh42dias/ajdc-vs-temporalio).

If you try AJ/DC on Rails 8.1, tell me how the `WakeJob` + `HousekeepingJob` recurring setup went.
