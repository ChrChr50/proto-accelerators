#!/usr/bin/env bash
# Fetch the Sky130 open PDK via Volare into ./pdk (run from workspace root).
set -euo pipefail
: "${PDK_ROOT:=$(pwd)/pdk}"
mkdir -p "$PDK_ROOT"
export PDK_ROOT
volare enable --pdk sky130 "$(volare ls-remote --pdk sky130 | head -1)"
echo "Sky130 PDK ready at $PDK_ROOT"
