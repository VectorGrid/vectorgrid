# install.ps1 — one-line installer for the VectorGrid Inference Engine CLI
# on Windows. The PowerShell sibling of install.sh.
#
# Usage (PowerShell 5.1+ / pwsh):
#     irm https://raw.githubusercontent.com/VectorGrid/vectorgrid/main/install.ps1 | iex
#
# What it does:
#   1. Detects the CPU arch (only x64 has prebuilt binaries today).
#   2. Downloads the matching release .zip from GitHub Releases.
#   3. Verifies the SHA256 against the sidecar `.sha256` file.
#   4. Extracts vectorgrid.exe to $env:USERPROFILE\.vectorgrid\bin
#      (same layout as the Unix installer, no admin rights needed).
#   5. Adds the install directory to the *user* PATH with clear messaging
#      (set VECTORGRID_NO_MODIFY_PATH=1 to opt out).
#
# Configuration mirrors install.sh:
#   VECTORGRID_VERSION      pin a release (e.g. v0.4.0); empty = latest
#   VECTORGRID_GITHUB_OWNER / VECTORGRID_GITHUB_REPO   override the repo
#   VECTORGRID_INSTALL_DIR  override the install directory
#   VECTORGRID_NO_MODIFY_PATH  print the PATH hint instead of editing PATH

$ErrorActionPreference = "Stop"

# -----------------------------------------------------------------------------
# Configuration.
# -----------------------------------------------------------------------------
$Version    = if ($env:VECTORGRID_VERSION) { $env:VECTORGRID_VERSION } else { "" }
$Owner      = if ($env:VECTORGRID_GITHUB_OWNER) { $env:VECTORGRID_GITHUB_OWNER } else { "VectorGrid" }
# Binaries are published to the public releases repository; the source
# repository stays private.
$Repo       = if ($env:VECTORGRID_GITHUB_REPO) { $env:VECTORGRID_GITHUB_REPO } else { "vectorgrid" }
$InstallDir = if ($env:VECTORGRID_INSTALL_DIR) { $env:VECTORGRID_INSTALL_DIR } else { Join-Path $env:USERPROFILE ".vectorgrid\bin" }

function Write-Info([string]$msg)  { Write-Host "[install] $msg" }
function Write-Fatal([string]$msg) { Write-Host "[install] ERROR: $msg" -ForegroundColor Red; exit 1 }

# -----------------------------------------------------------------------------
# Detect platform. Windows x64 only for now; the ARM64 build is future work.
# -----------------------------------------------------------------------------
$arch = $env:PROCESSOR_ARCHITECTURE
if ($arch -ne "AMD64") {
    Write-Fatal "Unsupported Windows architecture: $arch (only x64 is supported)"
}
$Target = "x86_64-pc-windows-msvc"

# -----------------------------------------------------------------------------
# Resolve "latest" unless the caller pinned a version.
# -----------------------------------------------------------------------------
if (-not $Version) {
    Write-Info "Resolving latest release..."
    $api = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
    try {
        $Version = (Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "vectorgrid-install" }).tag_name
    } catch {
        Write-Fatal "Could not determine the latest release. Pin one with `$env:VECTORGRID_VERSION = 'vX.Y.Z'"
    }
}

$Pkg     = "vectorgrid-$Version-$Target"
$BaseUrl = "https://github.com/$Owner/$Repo/releases/download/$Version"
$ZipUrl  = "$BaseUrl/$Pkg.zip"
$ShaUrl  = "$ZipUrl.sha256"

Write-Info "Installing vectorgrid $Version for $Target"
Write-Info "Source: $ZipUrl"

$TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "vectorgrid-install-$PID"
New-Item -ItemType Directory -Force -Path $TmpDir | Out-Null

try {
    # Download the archive.
    Write-Info "Downloading release archive..."
    $ZipPath = Join-Path $TmpDir "$Pkg.zip"
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing

    # Verify against the sidecar checksum. Treat a missing sidecar as a
    # warning, not an error — older releases may not have published one.
    # (Generic catch: PowerShell 5.1 throws WebException, pwsh 7 throws
    # HttpResponseException; only the download lives in the try so a real
    # verification failure can never be swallowed.)
    Write-Info "Verifying SHA256..."
    $expected = $null
    try {
        $expected = ((Invoke-WebRequest -Uri $ShaUrl -UseBasicParsing).Content.Trim() -split '\s+')[0].ToLower()
    } catch {
        Write-Info "WARN: no sidecar .sha256 found at $ShaUrl; skipping verification."
    }
    if ($expected) {
        $actual = (Get-FileHash $ZipPath -Algorithm SHA256).Hash.ToLower()
        if ($expected -ne $actual) {
            Write-Fatal "Checksum mismatch: expected $expected, got $actual"
        }
        Write-Info "Checksum OK ($actual)"
    }

    # Extract. The zip contains a `$Pkg\vectorgrid.exe` top-level directory.
    Write-Info "Extracting archive..."
    Expand-Archive -Path $ZipPath -DestinationPath $TmpDir -Force
    $Binary = Join-Path $TmpDir "$Pkg\vectorgrid.exe"
    if (-not (Test-Path $Binary)) {
        Write-Fatal "Archive did not contain the expected 'vectorgrid.exe' binary."
    }

    # Install. A previously installed exe that is still running cannot be
    # overwritten — park it as .old first (same trick `vectorgrid update`
    # uses; the .old is cleaned up on the next vectorgrid start).
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $Dest = Join-Path $InstallDir "vectorgrid.exe"
    if (Test-Path $Dest) {
        $Old = "$Dest.old"
        Remove-Item $Old -ErrorAction SilentlyContinue
        Move-Item $Dest $Old -ErrorAction SilentlyContinue
    }
    Move-Item $Binary $Dest -Force
    Write-Info "Installed to $Dest"
} finally {
    Remove-Item -Recurse -Force $TmpDir -ErrorAction SilentlyContinue
}

# -----------------------------------------------------------------------------
# PATH handling: add the install dir to the *user* PATH unless opted out.
# -----------------------------------------------------------------------------
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$onPath = ($userPath -split ';' | Where-Object { $_ -eq $InstallDir }).Count -gt 0
if ($onPath) {
    Write-Info "'$InstallDir' is already on your PATH."
} elseif ($env:VECTORGRID_NO_MODIFY_PATH) {
    Write-Host ""
    Write-Info "Add this directory to your PATH to use 'vectorgrid':"
    Write-Host ""
    Write-Host "    $InstallDir"
    Write-Host ""
} else {
    $newPath = if ($userPath) { "$userPath;$InstallDir" } else { $InstallDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    # Make it usable in THIS session too, not just future ones.
    $env:Path = "$env:Path;$InstallDir"
    Write-Info "Added $InstallDir to your user PATH."
    Write-Info "Open a new terminal for other sessions to pick it up."
}

Write-Host ""
Write-Info "vectorgrid $Version installed. Get started:"
Write-Host ""
Write-Host "    vectorgrid pull tinyllama     # ~640 MB verified starter model"
Write-Host "    vectorgrid run tinyllama      # interactive chat"
Write-Host ""
Write-Info "Keep it current later with: vectorgrid update"
