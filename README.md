# VectorGrid Inference Engine — Releases

Official binary releases of the **VectorGrid Inference Engine**: a pure-Rust,
OpenAI-compatible local LLM inference engine with a built-in agentic assistant.
One binary, one GGUF file — no Python, no CUDA toolkit, no Docker required.

## Install (macOS + Linux)

```bash
curl -sSL https://raw.githubusercontent.com/VectorGrid/vectorgrid/main/install.sh | sh
```

The installer detects your platform (on Linux it picks the CUDA build
automatically when an NVIDIA driver is present — the CUDA runtime libraries
ship inside the tarball, so you only need the driver), verifies the SHA-256,
installs to `~/.vectorgrid/bin/`, and adds it to your PATH.

## Two ways to use it

**1. Chat with a model, or talk to an agent that can do things on your machine.**
The `vectorgrid` binary includes an agentic assistant — Claude-Code-style, fully
local — that can run commands, read/write files, search your code, browse the
web, and call MCP servers.

```bash
vectorgrid pull qwen2.5-7b-instruct    # download a capable model (agent-grade)
vectorgrid                             # bare command opens the agent
#   › fix the failing test in this repo
vectorgrid agent -p "summarize what changed in the last commit"   # one-shot
```

First run with no server up? The agent detects your hardware, recommends a model,
and offers to download + start it for you.

**2. Serve an OpenAI-compatible API** for your own apps and tools:

```bash
vectorgrid serve --model qwen2.5-7b-instruct    # defaults to port 28100
# then point any OpenAI client at http://localhost:28100/v1
```

> The default port is **28100** — deliberately uncommon, so it won't collide
> with the busy ports other local servers grab (8080, 8000, 3000, Ollama's
> 11434). Override any time with `--port`.

A quick smoke test with a tiny model:

```bash
vectorgrid pull tinyllama      # ~640 MB verified starter model
vectorgrid run tinyllama       # plain model chat REPL (no tools)
```

## Stay up to date

```bash
vectorgrid update
```

Re-running the install one-liner also upgrades in place. Pin a specific version
with `VECTORGRID_VERSION` (the variable goes on `sh`, not `curl`):

```bash
curl -sSL https://raw.githubusercontent.com/VectorGrid/vectorgrid/main/install.sh | VECTORGRID_VERSION=v0.6.4 sh
```

The one-liner always installs the latest **stable** release (currently
**v0.6.4**). Occasional pre-releases appear on the
[Releases page](https://github.com/VectorGrid/vectorgrid/releases) and are never
auto-installed — pin them explicitly if you want to try one. A pre-release may
not carry every platform's asset; if yours isn't published the installer says so
and you can fall back to the stable one-liner.

## What's in a release

| Asset | Platform |
|-------|----------|
| `vectorgrid-<tag>-aarch64-apple-darwin.tar.gz` | macOS (Apple Silicon), Metal + Accelerate |
| `vectorgrid-<tag>-x86_64-unknown-linux-gnu.tar.gz` | Linux x86_64, CPU |
| `vectorgrid-<tag>-x86_64-unknown-linux-gnu-cuda.tar.gz` | Linux x86_64 + NVIDIA driver (CUDA runtime bundled) |
| `vectorgrid-<tag>-aarch64-unknown-linux-gnu.tar.gz` | Linux ARM64, CPU |
| `vectorgrid-<tag>-x86_64-pc-windows-msvc.zip` | Windows x86_64 |

Each with a `.sha256` sidecar. Binaries are built for portable CPU baselines
(Apple M1+, x86-64-v2).

---

This repository hosts releases and the installer only. Licensed under the
[MIT License](LICENSE).
