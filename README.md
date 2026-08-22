# VectorGrid Inference Engine — Releases

Official binary releases of the **VectorGrid Inference Engine**: a pure-Rust,
OpenAI-compatible local LLM inference engine. One binary, one GGUF file — no
Python, no CUDA toolkit, no Docker required.

## Install (macOS + Linux)

```bash
curl -sSL https://raw.githubusercontent.com/VectorGrid/vectorgrid/main/install.sh | sh
```

The installer detects your platform (on Linux it picks the CUDA build
automatically when an NVIDIA driver is present — the CUDA runtime libraries
ship inside the tarball), verifies the SHA-256, installs to
`~/.vectorgrid/bin/`, and adds it to your PATH. Then:

```bash
vectorgrid pull tinyllama      # ~640 MB verified starter model
vectorgrid run tinyllama       # interactive chat
```

## Stay up to date

```bash
vectorgrid update
```

Re-running the install one-liner also upgrades in place. Pin a version with
`VECTORGRID_VERSION=vX.Y.Z` (note: the variable goes on `sh`, not `curl`):

```bash
curl -sSL https://raw.githubusercontent.com/VectorGrid/vectorgrid/main/install.sh | VECTORGRID_VERSION=v0.6.0 sh
```

### Pre-release / bleeding-edge builds

The one-liner installs the latest **stable** release. Newer **pre-releases**
(the current tip of development, cut between stable releases) are published on
the [Releases page](https://github.com/VectorGrid/vectorgrid/releases) but are
**not** auto-installed — pin them explicitly. For example, to install the
latest **v0.6.1** pre-release:

```bash
curl -sSL https://raw.githubusercontent.com/VectorGrid/vectorgrid/main/install.sh | VECTORGRID_VERSION=v0.6.1 sh
```

A pre-release may not carry every platform's asset; if yours isn't published for
that version the installer will say so — just fall back to the stable one-liner.

## What's in a release

| Asset | Platform |
|-------|----------|
| `vectorgrid-<tag>-aarch64-apple-darwin.tar.gz` | macOS (Apple Silicon), Metal + Accelerate |
| `vectorgrid-<tag>-x86_64-unknown-linux-gnu.tar.gz` | Linux x86_64, CPU (OpenBLAS) |
| `vectorgrid-<tag>-x86_64-unknown-linux-gnu-cuda.tar.gz` | Linux x86_64 + NVIDIA driver (CUDA runtime bundled) |

Each with a `.sha256` sidecar. Binaries are built for portable CPU baselines
(Apple M1+, x86-64-v2).

## Serve an OpenAI-compatible API

```bash
vectorgrid serve --model tinyllama --port 8080
# then point any OpenAI client at http://localhost:8080/v1
```

---

This repository hosts releases and the installer only. Licensed under the
[MIT License](LICENSE).
