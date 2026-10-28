#!/usr/bin/env bash
# Puts OSS-CAD-Suite and Verible on PATH, activates the Python venv, and
# sets PDK_ROOT. Meant to be sourced.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# By default the tools live outside the repo, on WSL2's own filesystem,
# because this folder syncs through OneDrive and nobody wants gigabytes of
# binaries syncing or slow cross-filesystem reads. The MACC8_* variables
# override the paths, and a .venv/ or oss-cad-suite/ inside the repo wins
# over both.
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

# OSS-CAD-Suite's environment script puts its own Python (and its own
# cocotb) at the front of PATH, so it has to be sourced before the venv.
# Otherwise cocotb-config resolves to oss-cad-suite/bin and every sim quietly
# runs cocotb 2.1.0.dev0 instead of the pinned 1.9.2. That happened on
# 2026-07-11 before this ordering was fixed.
if [ -d "$OSS_CAD_SUITE_DIR" ]; then
  source "$OSS_CAD_SUITE_DIR/environment"
fi

if [ -f "$VENV_DIR/bin/activate" ]; then
  source "$VENV_DIR/bin/activate"
fi

# Verible isn't part of OSS-CAD-Suite, so it has its own folder.
if [ -d "$VERIBLE_DIR/bin" ]; then
  export PATH="$VERIBLE_DIR/bin:$PATH"
fi

export PDK_ROOT="${PDK_ROOT:-$REPO_ROOT/pdk}"
export PDK="${PDK:-sky130A}"

echo "env: PDK_ROOT=$PDK_ROOT PDK=$PDK"
echo "env: venv=$VENV_DIR oss-cad-suite=$OSS_CAD_SUITE_DIR verible=$VERIBLE_DIR"
