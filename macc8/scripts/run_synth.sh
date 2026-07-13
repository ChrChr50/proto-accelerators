#!/usr/bin/env bash
# Fast loop: OpenLane synthesis + STA only (no place/route). Run from workspace root.
#
# --dockerized is required: several OpenLane 2.x steps (e.g. Generate JSON
# Header) need a Yosys built with pyosys (embedded Python scripting, the -y
# flag), which our local OSS-CAD-Suite Yosys (used for lint/formal/
# synth-check) doesn't have. OpenLane's own Docker image does.
# --docker-no-tty is also required (must precede --dockerized): Docker's
# default -t (allocate a TTY) fails with "the input device is not a TTY"
# when run from a non-interactive shell, which this always is here.
# Learned the hard way 2026-07-13 -- see env/tool-versions.md.
set -euo pipefail
source env/setup.sh 2>/dev/null || true
openlane --docker-no-tty --dockerized --to OpenROAD.STAPrePNR pd/openlane/config.json
echo "Synthesis + STA reports under pd/openlane/runs/<run>/ (see *-sta/ and 1-*-yosys/)."
