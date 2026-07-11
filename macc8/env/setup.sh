#!/usr/bin/env bash
# Sources OSS-CAD-Suite + Verible, activates the Python venv, and exports PDK_ROOT.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Toolchain defaults to living outside the repo (e.g. WSL2's native
# filesystem, not a OneDrive-synced project folder) to avoid syncing
# multi-GB binaries and slow cross-filesystem I/O. Override via env vars,
# or drop a .venv/ or oss-cad-suite/ directly in the repo root and it wins.
TOOLS_ROOT="${MACC8_TOOLS_ROOT:-$HOME/tools}"
VENV_DIR="${MACC8_VENV_DIR:-$TOOLS_ROOT/macc8-venv}"
OSS_CAD_SUITE_DIR="${MACC8_OSS_CAD_SUITE_DIR:-$TOOLS_ROOT/oss-cad-suite}"
VERIBLE_DIR="${MACC8_VERIBLE_DIR:-$TOOLS_ROOT/verible}"

if [ -f "$REPO_ROOT/.venv/bin/activate" ]; then
  VENV_DIR="$REPO_ROOT/.venv"
fi
if [ -d "$REPO_ROOT/oss-cad-suite" ]; then
  OSS_CAD_SUITE_DIR="$REPO_ROOT/oss-cad-suite"
fi

# Order matters: OSS-CAD-Suite's own environment script prepends its bundled
# Python (with its own bundled cocotb) to PATH. Source it *before* activating
# the venv, so the venv's `python3`/`cocotb-config` end up first on PATH and
# win -- otherwise every cocotb run silently uses OSS-CAD-Suite's bundled
# cocotb instead of the env/requirements.txt-pinned version, which is exactly
# the version drift this venv exists to avoid. Learned the hard way 2026-07-11
# (was resolving cocotb-config to oss-cad-suite/bin/cocotb-config, running
# cocotb 2.1.0.dev0 instead of the pinned 1.9.2).
if [ -d "$OSS_CAD_SUITE_DIR" ]; then
  source "$OSS_CAD_SUITE_DIR/environment"
fi

if [ -f "$VENV_DIR/bin/activate" ]; then
  source "$VENV_DIR/bin/activate"
fi

# OSS-CAD-Suite doesn't bundle Verible; installed separately (see
# env/tool-versions.md).
if [ -d "$VERIBLE_DIR/bin" ]; then
  export PATH="$VERIBLE_DIR/bin:$PATH"
fi

export PDK_ROOT="${PDK_ROOT:-$REPO_ROOT/pdk}"
export PDK="${PDK:-sky130A}"

echo "env: PDK_ROOT=$PDK_ROOT PDK=$PDK"
echo "env: venv=$VENV_DIR oss-cad-suite=$OSS_CAD_SUITE_DIR verible=$VERIBLE_DIR"
