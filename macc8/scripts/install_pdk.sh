#!/usr/bin/env bash
# Downloads Sky130 with Volare into ./pdk. Run it from macc8/.
set -euo pipefail
: "${PDK_ROOT:=$(pwd)/pdk}"
mkdir -p "$PDK_ROOT"
export PDK_ROOT
volare enable --pdk sky130 "$(volare ls-remote --pdk sky130 | head -1)"
echo "Sky130 installed in $PDK_ROOT"
