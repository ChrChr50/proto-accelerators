#!/usr/bin/env bash
# Full RTL-to-GDSII harden with OpenLane. Run from workspace root.
#
# --dockerized is required: several OpenLane 2.x steps need a Yosys built
# with pyosys, which our local OSS-CAD-Suite Yosys doesn't have. OpenLane's
# own Docker image does. See scripts/run_synth.sh / env/tool-versions.md.
set -euo pipefail
source env/setup.sh 2>/dev/null || true
openlane --docker-no-tty --dockerized pd/openlane/config.json
echo "GDS + reports under pd/openlane/runs/<run>/ (final/gds/, metrics.json)."
