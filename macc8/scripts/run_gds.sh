#!/usr/bin/env bash
# Full RTL-to-GDSII harden with OpenLane. Run from workspace root.
set -euo pipefail
source env/setup.sh 2>/dev/null || true
openlane pd/openlane/config.json
echo "GDS + reports under pd/openlane/runs/<run>/ (final/gds/, metrics.json)."
