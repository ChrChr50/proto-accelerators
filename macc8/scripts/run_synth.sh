#!/usr/bin/env bash
# Fast loop: OpenLane synthesis + STA only (no place/route). Run from workspace root.
set -euo pipefail
source env/setup.sh 2>/dev/null || true
openlane --to sta pd/openlane/config.json
echo "Synthesis + STA reports under pd/openlane/runs/<run>/ (see *-sta/ and 1-*-yosys/)."
