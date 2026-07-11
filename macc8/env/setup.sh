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

if [ -f "$VENV_DIR/bin/activate" ]; then
  source "$VENV_DIR/bin/activate"
fi

if [ -d "$OSS_CAD_SUITE_DIR" ]; then
  source "$OSS_CAD_SUITE_DIR/environment"
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
