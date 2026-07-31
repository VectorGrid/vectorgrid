#!/bin/sh
# install.sh — one-line installer for the VectorGrid Inference Engine CLI.
#
# Usage:
#     curl -fsSL https://raw.githubusercontent.com/VectorGrid/vectorgrid/main/install.sh | sh
#
# What it does:
#   1. Detects the host OS (Darwin or Linux) and CPU arch (arm64 or x86_64).
#   2. Downloads the matching release tarball from GitHub Releases.
#   3. (Optional) Verifies the SHA256 against the sidecar `.sha256` file.
#   4. Extracts the `vectorgrid` binary to $HOME/.vectorgrid/bin/vectorgrid.
#   5. Prints the line the user should add to their shell rc to put the
#      install directory on $PATH.
#
# This script is intentionally POSIX `sh`-compatible (no bashisms) so it
# works under macOS /bin/sh (dash-like) and minimal Linux containers.

# Strict-ish mode. `set -u` and `pipefail` are not portable under pure POSIX
# sh, but `-e` is. We emulate the rest with explicit checks.
set -e

# -----------------------------------------------------------------------------
# Configuration — bump VECTORGRID_VERSION on each release.
# -----------------------------------------------------------------------------
# Empty VECTORGRID_VERSION means "latest release" (resolved via the GitHub
# API in main). Pin with e.g. VECTORGRID_VERSION=v0.1.0 to install a
# specific version.
VECTORGRID_VERSION="${VECTORGRID_VERSION:-}"
GITHUB_OWNER="${VECTORGRID_GITHUB_OWNER:-VectorGrid}"
# Binaries are published to the public releases repository; the source
# repository stays private. Override with VECTORGRID_GITHUB_REPO.
GITHUB_REPO="${VECTORGRID_GITHUB_REPO:-vectorgrid}"
INSTALL_DIR="${VECTORGRID_INSTALL_DIR:-$HOME/.vectorgrid/bin}"

# -----------------------------------------------------------------------------
# Tiny logging helpers.
# -----------------------------------------------------------------------------
info()  { printf '[install] %s\n' "$*"; }
warn()  { printf '[install] WARN: %s\n' "$*" >&2; }
fatal() { printf '[install] ERROR: %s\n' "$*" >&2; exit 1; }

# -----------------------------------------------------------------------------
# Detect platform.
# -----------------------------------------------------------------------------
detect_target() {
  uname_s="$(uname -s)"
  uname_m="$(uname -m)"

  case "${uname_s}" in
    Darwin)
      case "${uname_m}" in
        arm64|aarch64) echo "aarch64-apple-darwin" ;;
        *) fatal "Unsupported macOS architecture: ${uname_m} (only Apple Silicon / arm64 is supported)" ;;
      esac
      ;;
    Linux)
      case "${uname_m}" in
        x86_64|amd64)
          # NVIDIA driver present? Install the CUDA build (runtime libs are
          # bundled in the tarball -- users never install the CUDA toolkit,
          # only the regular NVIDIA driver). VECTORGRID_FORCE_CPU=1 overrides.
          if [ -z "${VECTORGRID_FORCE_CPU:-}" ] && { command -v nvidia-smi >/dev/null 2>&1 || [ -e /proc/driver/nvidia/version ]; }; then
            echo "x86_64-unknown-linux-gnu-cuda"
          else
            echo "x86_64-unknown-linux-gnu"
          fi
          ;;
        *) fatal "Unsupported Linux architecture: ${uname_m} (only x86_64 is supported)" ;;
      esac
      ;;
    *)
      fatal "Unsupported OS: ${uname_s}"
      ;;
  esac
}

# -----------------------------------------------------------------------------
# Pick a download tool. We require `curl`; fall back to `wget` if missing.
# -----------------------------------------------------------------------------
download() {
  # $1 = URL, $2 = output path
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$2" "$1"
  else
    fatal "Neither curl nor wget is installed; cannot download release."
  fi
}

# -----------------------------------------------------------------------------
# SHA256 helper. Tries shasum (macOS) then sha256sum (Linux).
# -----------------------------------------------------------------------------
sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    echo ""  # caller treats empty as "could not verify"
  fi
}

# -----------------------------------------------------------------------------
# Main install flow.
# -----------------------------------------------------------------------------
main() {
  # Resolve "latest" unless the caller pinned a version.
  if [ -z "${VECTORGRID_VERSION}" ]; then
    info "Resolving latest release..."
    api="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest"
    if command -v curl >/dev/null 2>&1; then
      VECTORGRID_VERSION="$(curl -fsSL "${api}" 2>/dev/null | sed -n 's/.*"tag_name"[^"]*"\([^"]*\)".*/\1/p' | head -1)"
    else
      VECTORGRID_VERSION="$(wget -qO- "${api}" 2>/dev/null | sed -n 's/.*"tag_name"[^"]*"\([^"]*\)".*/\1/p' | head -1)"
    fi
    [ -n "${VECTORGRID_VERSION}" ] || fatal "Could not determine the latest release. Pin one with VECTORGRID_VERSION=vX.Y.Z"
  fi

  TARGET="$(detect_target)"
  PKG="vectorgrid-${VECTORGRID_VERSION}-${TARGET}"
  BASE_URL="https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}/releases/download/${VECTORGRID_VERSION}"
  TARBALL_URL="${BASE_URL}/${PKG}.tar.gz"
  SHA_URL="${TARBALL_URL}.sha256"

  info "Installing vectorgrid ${VECTORGRID_VERSION} for ${TARGET}"
  info "Source: ${TARBALL_URL}"

  TMPDIR="$(mktemp -d 2>/dev/null || mktemp -d -t vectorgrid)"
  trap 'rm -rf "${TMPDIR}"' EXIT INT TERM

  # Download the tarball.
  info "Downloading release archive..."
  download "${TARBALL_URL}" "${TMPDIR}/${PKG}.tar.gz"

  # Try to download the sidecar checksum and verify. Treat a missing checksum
  # as a warning, not an error — older releases may not have published one.
  info "Verifying SHA256..."
  if download "${SHA_URL}" "${TMPDIR}/${PKG}.tar.gz.sha256" 2>/dev/null; then
    expected="$(awk '{print $1}' "${TMPDIR}/${PKG}.tar.gz.sha256")"
    actual="$(sha256_of "${TMPDIR}/${PKG}.tar.gz")"
    if [ -z "${actual}" ]; then
      warn "No sha256/shasum tool found; skipping checksum verification."
    elif [ "${expected}" != "${actual}" ]; then
      fatal "Checksum mismatch: expected ${expected}, got ${actual}"
    else
      info "Checksum OK (${actual})"
    fi
  else
    warn "No sidecar .sha256 found at ${SHA_URL}; skipping verification."
  fi

  # Extract.
  info "Extracting archive..."
  tar -xzf "${TMPDIR}/${PKG}.tar.gz" -C "${TMPDIR}"

  # Locate the binary inside the extracted tree (it lives in ${PKG}/vectorgrid).
  if [ ! -f "${TMPDIR}/${PKG}/vectorgrid" ]; then
    fatal "Archive did not contain the expected 'vectorgrid' binary."
  fi

  # Install to $INSTALL_DIR.
  mkdir -p "${INSTALL_DIR}"
  install_target="${INSTALL_DIR}/vectorgrid"
  cp "${TMPDIR}/${PKG}/vectorgrid" "${install_target}"
  chmod +x "${install_target}"
  info "Installed to ${install_target}"

  # PATH hint. Detect which shell rc to suggest.
  shell_name="$(basename "${SHELL:-sh}")"
  case "${shell_name}" in
    zsh)  rc_file="$HOME/.zshrc" ;;
    bash) rc_file="$HOME/.bashrc" ;;
    fish) rc_file="$HOME/.config/fish/config.fish" ;;
    *)    rc_file="$HOME/.profile" ;;
  esac

  # Put the install dir on PATH. Appended to the shell rc automatically
  # (set VECTORGRID_NO_MODIFY_PATH=1 to opt out and get a hint instead).
  path_line="export PATH=\"${INSTALL_DIR}:\$PATH\""
  case ":${PATH}:" in
    *":${INSTALL_DIR}:"*)
      info "'${INSTALL_DIR}' is already on your PATH."
      ;;
    *)
      if [ -n "${VECTORGRID_NO_MODIFY_PATH:-}" ]; then
        printf '\n'
        info "Add this line to ${rc_file} to use 'vectorgrid':"
        printf '\n    %s\n\n' "${path_line}"
      elif [ "${shell_name}" = "fish" ]; then
        mkdir -p "$(dirname "${rc_file}")"
        if ! grep -qs "${INSTALL_DIR}" "${rc_file}" 2>/dev/null; then
          printf '\nfish_add_path %s\n' "${INSTALL_DIR}" >> "${rc_file}"
          info "Added ${INSTALL_DIR} to PATH in ${rc_file}"
        fi
      else
        if ! grep -qs "${INSTALL_DIR}" "${rc_file}" 2>/dev/null; then
          printf '\n# Added by the VectorGrid installer\n%s\n' "${path_line}" >> "${rc_file}"
          info "Added ${INSTALL_DIR} to PATH in ${rc_file}"
        fi
      fi
      info "Open a new terminal (or 'source ${rc_file}') to pick it up."
      ;;
  esac

  printf '\n'
  info "vectorgrid ${VECTORGRID_VERSION} installed. Get started:"
  printf '\n    vectorgrid pull tinyllama     # ~640 MB verified starter model\n'
  printf '    vectorgrid run tinyllama      # interactive chat\n\n'
  info "Keep it current later with: vectorgrid update"
}

main "$@"
