---
layout: post
title: "What is Temporal and how this works?"
date: 2026-06-30 16:00:00 +0300
categories: workflows Temporal durable_executions ruby
tags: workflows Temporal durable_executions ruby
description: "What is Temporal and how this works — a walkthrough using the Ruby SDK with a bank account transfer example"
canonical_url: https://blog.juliana.dev/what-is-temporal-and-how-this-works
source: dev.to
---

## What is Temporal and how this works?

<div style="background: black; padding: 20px; border-radius: 8px; margin-bottom: 20px; text-align: center;">
  <img src="https://images.ctfassets.net/0uuz8ydxyd9p/65SSC5QL4KNrKD8cWZUv6H/c4fc6fe75e17a556325b2bacbc3f801c/Group_1000001864.svg" alt="Temporal" style="max-width: 100%; height: auto;">
</div>

First of all, we need to get some context about what are workflows.

You know when you're building an application and you have a sequence of steps that need to happen? Like: charge the credit card, send the email, update the database. If one of those steps fails, what happens? Do you retry? Do you rollback? Who keeps track of where you left off?

That's where workflow engines like Temporal come in.

Temporal is a durable execution platform. Think of it as an autosave for your application state. It makes your code resilient to failures — network issues, server crashes, you name it. If something fails mid-execution, Temporal remembers exactly where it was and picks up from there.

## The superpowers

Temporal gives you a bunch of capabilities out of the box that would be painful to build yourself:

**State machines — Autosave for application state**
Every workflow execution is a state machine. Temporal keeps track of every state transition so if your worker crashes, the workflow resumes from the last completed step. No data loss, no manual recovery.

**Native Retries**
Activities (the individual steps in your workflow) can have retry policies built in. You define how many times to retry, the interval between retries, and what errors should *not* be retried. Temporal handles the rest.

**Timeouts/timers — Wait for 3 seconds or 3 months**
Need to wait for a payment confirmation? Or send a reminder email after 7 days? Temporal timers are first-class citizens. You can wait for any duration and the timeout survives server restarts.

**Schedules — Schedule, don't Cron**
Cron is great until you need to manage it across multiple servers. Temporal Schedules let you run workflows on a timer in a reliable, distributed way.

**Idiomatic language support — Many SDKs**
Temporal has SDKs for Go, Java, TypeScript, Python, .NET, and of course Ruby. You write workflows in your language of choice, using the patterns you already know.

**Human in the loop**
Sometimes a workflow needs a human decision — approve a transfer, review a document. Temporal supports external signals so you can pause a workflow and wait for a human to act.

**Execution visibility — Inspect, replay, rewind**
You can see exactly what happened in any workflow execution. Inspect the state, replay it, rewind it. Debugging long-running processes becomes something that's actually feasible.

**Run Temporal locally**
Before taking anything to production, you can spin up Temporal Server locally with Docker and test everything on your machine.

## Architecture

Temporal's architecture has three main pieces:

**Workflows** — The orchestration logic. They define the sequence of steps, handle errors, and manage state. Workflows must be deterministic (no random, no IO, no system clock).

**Activities** — The actual work. They do the real stuff: call APIs, read/write databases, send emails. Activities can be retried and have timeouts.

**Workers** — The processes that host and execute Workflows and Activities. Workers poll the Temporal Server for tasks and execute them.

<img src="/assets/svg/temporal-architecture.svg" alt="Temporal Architecture" style="max-width: 100%; height: auto; display: block; margin: 20px auto;">

## Let's see some code

The classic example is a money transfer between two bank accounts. Here's how it looks with the Temporal Ruby SDK.

<img src="/assets/svg/money-transfer-workflow.svg" alt="Money Transfer Workflow" style="max-width: 100%; height: auto; display: block; margin: 20px auto;">

First, we define the shared data structure and custom errors:

```ruby
# shared.rb
require 'json/add/struct'

module MoneyTransfer
  TASK_QUEUE_NAME = 'money-transfer'

  class InsufficientFundsError < StandardError; end
  class InvalidAccountError < StandardError; end

  TransferDetails = Struct.new(:source_account, :target_account, :amount, :reference_id) do
    def to_s
      "TransferDetails { #{source_account}, #{target_account}, #{amount}, #{reference_id} }"
    end
  end
end
```

Then we define the Activities — the actual bank operations:

```ruby
# activities.rb
require_relative 'shared'
require 'temporalio/activity'

module MoneyTransfer
  module BankActivities
    class Withdraw < Temporalio::Activity::Definition
      def execute(details)
        puts("Doing a withdrawal from #{details.source_account} for #{details.amount}")
        raise InsufficientFundsError, 'Transfer amount too large' if details.amount > 1000

        "OKW-#{details.amount}-#{details.source_account}"
      end
    end

    class Deposit < Temporalio::Activity::Definition
      def execute(details)
        puts("Doing a deposit into #{details.target_account} for #{details.amount}")
        raise InvalidAccountError, 'Invalid account number' if details.target_account == 'B5555'

        "OKD-#{details.amount}-#{details.target_account}"
      end
    end

    class Refund < Temporalio::Activity::Definition
      def execute(details)
        puts("Refunding #{details.amount} back to account #{details.source_account}")

        "OKR-#{details.amount}-#{details.source_account}"
      end
    end
  end
end
```

Now the Workflow — this is where the orchestration happens:

```ruby
# workflow.rb
require_relative 'activities'
require_relative 'shared'
require 'temporalio/retry_policy'
require 'temporalio/workflow'

module MoneyTransfer
  class MoneyTransferWorkflow < Temporalio::Workflow::Definition
    def execute(details)
      retry_policy = Temporalio::RetryPolicy.new(
        max_interval: 10,
        non_retryable_error_types: [
          'InvalidAccountError',
          'InsufficientFundsError'
        ]
      )

      Temporalio::Workflow.logger.info("Starting workflow (#{details})")

      withdraw_result = Temporalio::Workflow.execute_activity(
        BankActivities::Withdraw,
        details,
        start_to_close_timeout: 5,
        retry_policy: retry_policy
      )
      Temporalio::Workflow.logger.info("Withdrawal confirmation: #{withdraw_result}")

      begin
        deposit_result = Temporalio::Workflow.execute_activity(
          BankActivities::Deposit,
          details,
          start_to_close_timeout: 5,
          retry_policy: retry_policy
        )
        Temporalio::Workflow.logger.info("Deposit confirmation: #{deposit_result}")

        "Transfer complete (transaction IDs: #{withdraw_result}, #{deposit_result})"
      rescue Temporalio::Error::ActivityError => e
        Temporalio::Workflow.logger.error("Deposit failed: #{e}")

        begin
          refund_result = Temporalio::Workflow.execute_activity(
            BankActivities::Refund,
            details,
            start_to_close_timeout: 5,
            retry_policy: retry_policy
          )
          Temporalio::Workflow.logger.info("Refund confirmation: #{refund_result}")

          "Transfer complete (transaction IDs: #{withdraw_result}, #{refund_result})"
        rescue Temporalio::Error::ActivityError => refund_error
          Temporalio::Workflow.logger.error("Refund failed: #{refund_error}")
        end
      end
    end
  end
end
```

Notice how the Workflow doesn't do the actual bank operations — it just orchestrates them. The Activities do the real work. If a deposit fails after a successful withdrawal, the Workflow automatically refunds the amount. That's the kind of safety net that's hard to build manually.

The Worker ties everything together:

```ruby
# worker.rb
require_relative 'activities'
require_relative 'shared'
require_relative 'workflow'
require 'logger'
require 'temporalio/client'
require 'temporalio/worker'

client = Temporalio::Client.connect(
  'localhost:7233',
  'default',
  logger: Logger.new($stdout, level: Logger::INFO)
)

worker = Temporalio::Worker.new(
  client:,
  task_queue: MoneyTransfer::TASK_QUEUE_NAME,
  workflows: [MoneyTransfer::MoneyTransferWorkflow],
  activities: [
    MoneyTransfer::BankActivities::Withdraw,
    MoneyTransfer::BankActivities::Deposit,
    MoneyTransfer::BankActivities::Refund
  ]
)

puts 'Starting Worker (press Ctrl+C to exit)'
worker.run(shutdown_signals: ['SIGINT'])
```

And finally, a client to start the workflow:

```ruby
# starter.rb
require_relative 'shared'
require_relative 'workflow'
require 'securerandom'
require 'temporalio/client'

client = Temporalio::Client.connect('localhost:7233', 'default')

details = MoneyTransfer::TransferDetails.new('A1001', 'B2002', 100, SecureRandom.uuid)
details.source_account = ARGV[0] if ARGV.length >= 1
details.target_account = ARGV[1] if ARGV.length >= 2
details.amount = ARGV[2].to_i if ARGV.length >= 3
details.reference_id = ARGV[3] if ARGV.length >= 4

handle = client.start_workflow(
  MoneyTransfer::MoneyTransferWorkflow,
  details,
  id: "moneytransfer-#{details.reference_id}",
  task_queue: MoneyTransfer::TASK_QUEUE_NAME
)

puts "Initiated transfer of $#{details.amount} from #{details.source_account} to #{details.target_account}"
puts "Workflow ID: #{handle.id}"

begin
  puts "Workflow result: #{handle.result}"
rescue Temporalio::Error::RPCError
  puts 'Temporal Service unavailable while awaiting result'
  retry
end
```

Here's what this looks like in practice — the Temporal Web UI showing a workflow being executed and automatically recovering from failures:

<video controls style="max-width: 100%; border-radius: 8px; margin: 20px 0;">
  <source src="https://videos.ctfassets.net/0uuz8ydxyd9p/1VMi8Xh2bEWjaln45C01Bj/1035ec4209abe85ecb74ec90542791d2/SelfHealingWorkflow.mp4" type="video/mp4">
  Your browser does not support the video tag.
</video>

## How it all fits together

You spin up a Worker, it connects to the Temporal Server and listens on a Task Queue. When you run the starter, it tells the Server "hey, I want to execute a MoneyTransferWorkflow with these details". The Server schedules it on the Task Queue, the Worker picks it up, and executes the workflow step by step — persisting state after each step.

If the Worker crashes mid-transfer, no problem. Another Worker (or the same one after restart) picks up where it left off.

That's the magic of Temporal. You write your business logic like a simple Ruby class, and you get reliability, retries, timeouts, and visibility for free.

The code is available on the [Temporal money-transfer-project-template-ruby](https://github.com/temporalio/money-transfer-project-template-ruby) repository if you want to play with it yourself.
