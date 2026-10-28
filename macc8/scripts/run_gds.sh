#!/usr/bin/env bash
# The whole OpenLane flow, RTL to GDSII. Run it from macc8/.
# Same Docker flags as run_synth.sh, for the same reasons.
set -euo pipefail
source env/setup.sh 2>/dev/null || true
openlane --docker-no-tty --dockerized pd/openlane/config.json
echo "Done. GDS and metrics.json are in pd/openlane/runs/<run>/final/."
