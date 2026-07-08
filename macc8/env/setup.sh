#!/usr/bin/env bash
# Sources OSS-CAD-Suite, activates the Python venv, and exports PDK_ROOT.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$REPO_ROOT/.venv/bin/activate" ]; then
  source "$REPO_ROOT/.venv/bin/activate"
fi

if [ -d "$REPO_ROOT/oss-cad-suite" ]; then
  source "$REPO_ROOT/oss-cad-suite/environment"
fi

export PDK_ROOT="${PDK_ROOT:-$REPO_ROOT/pdk}"
export PDK="${PDK:-sky130A}"

echo "env: PDK_ROOT=$PDK_ROOT PDK=$PDK"
