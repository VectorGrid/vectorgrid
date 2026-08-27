# VectorGrid — run any open model on a grid you own

Official releases of the **VectorGrid Inference Engine**: a pure-Rust,
OpenAI-compatible local LLM engine with a built-in agentic assistant and a
network layer that pools every machine you own into one inference grid.
One binary, one GGUF file — no Python, no CUDA toolkit, no Docker required.

**Website:** [vectorgrid.net](https://www.vectorgrid.net) ·
**Your console:** [vectorgrid.net/console.html](https://www.vectorgrid.net/console.html)

## Three commands to your first token

```bash
curl -sSL https://raw.githubusercontent.com/VectorGrid/vectorgrid/main/install.sh | sh
vectorgrid login        # sign in once per machine (or create an account right there)
vectorgrid              # opens the agent
```

The installer detects your platform (on Linux it picks the CUDA build
automatically when an NVIDIA driver is present — the CUDA runtime libraries
ship inside the tarball, so you only need the driver), verifies the SHA-256,
installs to `~/.vectorgrid/bin/`, and adds it to your PATH.

VectorGrid uses accounts: product commands require a one-time `vectorgrid login`
per machine (there's a 72-hour offline grace window, and scripts/services
inherit the machine's stored sign-in). Diagnostics — `vectorgrid doctor`,
`vectorgrid analyse` — and account commands always work without it.

## Three ways to use it

**1. The agent.** The `vectorgrid` binary includes an agentic assistant —
Claude-Code-style, fully local — that can run commands, read/write files,
search your code, browse the web, and call MCP servers.

```bash
vectorgrid pull qwen2.5-7b-instruct    # download a capable model (agent-grade)
vectorgrid                             # bare command opens the agent
#   › fix the failing test in this repo
vectorgrid agent -p "summarize what changed in the last commit"   # one-shot
```

First run with no server up? The agent detects your hardware, recommends a
model, and offers to download + start it for you.

**2. An OpenAI-compatible API** for your own apps and tools:

```bash
vectorgrid serve --model qwen2.5-7b-instruct    # defaults to port 28100
# then point any OpenAI client at http://localhost:28100/v1
```

> The default port is **28100** — deliberately uncommon, so it won't collide
> with the busy ports other local servers grab (8080, 8000, 3000, Ollama's
> 11434). Override any time with `--port`.

**3. A pooled grid.** A gaming PC, a MacBook, an old workstation — each too
small for the model you want. Pooled over your LAN they run it together,
splitting layers across machines over a UDP transport built for inference
(selective-ACK ARQ, Reed-Solomon parity, AEAD encryption). Greedy decoding is
byte-identical, split or not.

```bash
# on the machines with GPUs
vectorgrid worker --listen vgt://0.0.0.0:19310 --announce

# on your laptop — workers are auto-discovered
vectorgrid run r1-distill-qwen-14b --pool
```

A quick smoke test with a tiny model:

```bash
vectorgrid pull tinyllama      # ~640 MB verified starter model
vectorgrid run tinyllama       # plain model chat REPL (no tools)
```

## Your console

Everything your account runs shows up at
[vectorgrid.net/console.html](https://www.vectorgrid.net/console.html): your
machines (hardware, roles, versions, active-now), how they pool, usage and
performance per session, and a full command guide.

## Telemetry, in the open

Signed-in installs report anonymous usage metadata (command used, model
*alias*, tokens/sec, crash locations with the panic message *hashed*) so we
can see what breaks and what matters. The schema is content-free by
construction — prompts, outputs, file paths, and addresses have no fields to
live in. Inspect the queue with `vectorgrid telemetry status`; opt out
permanently with `vectorgrid telemetry off` (the local queue is purged).
Details: [vectorgrid.net/#telemetry](https://www.vectorgrid.net/#telemetry).

## Stay up to date

```bash
vectorgrid update
```

Re-running the install one-liner also upgrades in place. Pin a specific version
with `VECTORGRID_VERSION` (the variable goes on `sh`, not `curl`):

```bash
curl -sSL https://raw.githubusercontent.com/VectorGrid/vectorgrid/main/install.sh | VECTORGRID_VERSION=v0.6.29 sh
```

The one-liner always installs the latest **stable** release (currently
**v0.6.30**). Occasional pre-releases appear on the
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
| `vectorgrid-<tag>-x86_64-pc-windows-msvc.zip` | Windows x86_64, CPU |
| `vectorgrid-<tag>-x86_64-pc-windows-msvc-cuda.zip` | Windows x86_64 + NVIDIA driver (CUDA runtime bundled) |

Each with a `.sha256` sidecar. Binaries are built for portable CPU baselines
(Apple M1+, x86-64-v2).

---

This repository hosts releases, the installer, and the
[vectorgrid.net](https://www.vectorgrid.net) site. Licensed under the
[MIT License](LICENSE).
