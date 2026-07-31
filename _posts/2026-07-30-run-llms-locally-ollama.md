---
layout: post
title: "Run LLM models locally with Ollama: Pop!_OS and macOS"
date: 2026-07-30 16:00:00 +0300
categories: llm ollama ai popos macos
tags: llm ollama ai popos macos
description: "How to install and use LLM models locally with Ollama on Pop!_OS (Avell A60 MUV with NVIDIA GPU) and macOS Tahoe (MacBook with Apple Silicon) — step by step for both systems"
canonical_url: https://blog.juliana.dev/run-llms-locally-ollama
source: dev.to
---

## Run LLM models locally with Ollama: Pop!_OS and macOS

You know when you're working on something and you need a quick answer — "what's the syntax for this again?", "rewrite this error message", "explain this stack trace" — and you end up pasting your code into a browser tab, sending it to some company's server?

What if you could run a capable LLM on your own machine? No login, no internet, no data leaving your laptop, no pay-per-token. Your code never leaves your hard drive. And on modern hardware it's surprisingly fast.

In this post I'll show you how to set it up on the two machines I use every day:

- **Avell A60 MUV** — Intel i7-9750H, NVIDIA GTX 1660 Ti (6GB), 32GB RAM, 2TB SSD, running **Pop!_OS**
- **MacBook M1** — 16GB unified memory, 1TB SSD, running **macOS Tahoe**

The tool of choice: **Ollama**. It's free, open source, works on Linux, macOS and Windows, and it handles the annoying parts (GPU detection, quantization, model management) for you.

## First, the hardware reality check

Before installing anything, let's be honest about what matters. The two things that limit you are:

**VRAM (GPU memory)** on the Linux machine — your GTX 1660 Ti has 6GB. A 7B parameter model quantized to 4-bit takes roughly 4.5GB. A 14B model takes ~9GB. You can spill over to system RAM, but generation gets slow.

**Unified memory** on the Mac — Apple Silicon Macs share RAM between CPU and GPU, which is a superpower for local inference. An M-series Mac with 16GB can comfortably run 8B models, and even 14B if you're not in a hurry.

Rule of thumb: the model file size should fit in your available memory. Ollama shows you the size right before pulling.

## Install on Pop!_OS

### Step 1: Make sure the NVIDIA driver is happy

Pop!_OS is nice here — if you installed the NVIDIA ISO, your GPU already works out of the box. Let's confirm:

```bash
$ nvidia-smi
```

You should see your GTX 1660 Ti, driver version and memory info. If the command isn't found, install the driver:

```bash
$ sudo apt install system76-driver-nvidia
$ sudo reboot
```

### Step 2: Install Ollama

One command:

```bash
$ curl -fsSL https://ollama.com/install.sh | sh
```

The installer detects your NVIDIA GPU, installs CUDA support automatically, and sets up a systemd service.

Check that it's running:

```bash
$ sudo systemctl status ollama
```

If it's not active, start it with `sudo systemctl start ollama`.

### Step 3: Pull and run a model

Let's pull DeepSeek R1 distilled to 7B — a reasoning model that's great for coding and explains its thinking out loud:

```bash
$ ollama pull deepseek-r1:7b
$ ollama run deepseek-r1:7b
```

And you're in a chat. Type a question:

```
>>> explain the difference between a process and a thread in 3 sentences
```

To exit, type `/bye` or press `Ctrl+D`.

### Step 4: Prove the GPU is being used

This is the part everyone loves. In another terminal, while the model is generating:

```bash
$ ollama ps
```

You should see the model with a `PROCESSOR` column showing `100% GPU`. Or check the GPU directly:

```bash
$ nvidia-smi
```

You'll see an `ollama_llama_server` process eating VRAM and GPU-Util jumping up while it generates. That's your GPU doing the work.

## Install on macOS Tahoe

### Step 1: Install Ollama

Two options. The lazy (and best) one, with Homebrew:

```bash
$ brew install ollama
```

Or download the Ollama.app from [ollama.com/download](https://ollama.com/download), drag it to Applications, and launch it once — it runs a little whale icon in your menu bar and exposes the API on `localhost:11434`.

### Step 2: Pull and run a model

Same commands as Linux, because Ollama is cross-platform by design:

```bash
$ ollama pull qwen3:8b
$ ollama run qwen3:8b
```

On Apple Silicon, Ollama uses the **Metal** framework automatically — no driver installation, no configuration. The GPU just works.

### Step 3: Check the speed

Mac users, you can see exactly what's happening with the verbose flag:

```bash
$ ollama run qwen3:8b --verbose
```

After a response, you get a breakdown: load duration, eval count and speed in tokens per second. On the M1 expect around 15–30 tokens/s with an 8B model — faster than you can read, and the first generation of Apple Silicon is already plenty for everyday use.

## Which model should you pick?

This is the question I get the most. Here's what I'd install first on each machine:

| Hardware | Sweet spot | Also try |
| --- | --- | --- |
| Avell A60 MUV (6GB VRAM) | `deepseek-r1:7b`, `qwen3:4b` | `llama3.2:3b`, `gemma3:4b` |
| MacBook M1 16GB | `qwen3:8b`, `llama3.1:8b` | `deepseek-r1:14b` (slower, smarter) |
| MacBook 8GB (Apple Silicon) | `qwen3:4b`, `llama3.2:3b` | `phi4-mini` |

General rules:

- **Coding** → DeepSeek R1 or Qwen Coder (`qwen2.5-coder:7b`)
- **General chat** → Qwen 3 or Llama 3.2
- **Small/fast** → `llama3.2:3b` fits almost anywhere and answers instantly
- **Bigger is not always better** — a model that fits in memory beats a bigger one that swaps to disk

To browse everything available: `ollama list` shows installed models, and [ollama.com/library](https://ollama.com/library) is the catalog.

## Beyond the terminal

The CLI is just the beginning. Ollama exposes a REST API on `localhost:11434`, so you can wire it into your own tools.

With curl:

```bash
$ curl http://localhost:11434/api/generate -d '{
  "model": "deepseek-r1:7b",
  "prompt": "Explain how a hash map works",
  "stream": false
}'
```

It also speaks OpenAI-compatible format at `/v1/chat/completions` — which means anything written for the OpenAI API can point to your local server instead. Being a Ruby person, here's a tiny example:

```ruby
require 'net/http'
require 'json'

uri = URI('http://localhost:11434/v1/chat/completions')
req = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
req.body = {
  model: 'qwen3:8b',
  messages: [{ role: 'user', content: 'Explain recursion like I am five' }]
}.to_json

response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
puts JSON.parse(response.body)['choices'].first['message']['content']
```

For a chat UI in the browser, [Open WebUI](https://github.com/open-webui/open-webui) runs as a Docker container and connects to Ollama with zero code. And if you prefer a desktop app over the terminal, [LM Studio](https://lmstudio.ai) is a great GUI alternative that uses the same model files.

## Wrapping up

Running LLMs locally in 2026 is genuinely easy: install Ollama, pick a model that fits your memory, and you have a private, offline, unlimited assistant on your laptop.

My setup: the Avell handles the heavier reasoning work on Pop!_OS, and the MacBook gives me a pocket-sized assistant with no configuration drama — both for free, both private.

The full docs live at [docs.ollama.com](https://docs.ollama.com) — it's well maintained and worth a bookmark.
