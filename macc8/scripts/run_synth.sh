#!/usr/bin/env bash
# OpenLane up to pre-route STA: synthesis and timing, no place and route.
# Run it from macc8/.
#
# Two flags matter here:
#   --dockerized     some OpenLane 2 steps run Yosys with -y (pyosys), and
#                    the OSS-CAD-Suite Yosys we lint and prove with isn't
#                    built with it. OpenLane's Docker image is.
#   --docker-no-tty  has to come before --dockerized. Without it docker run
#                    asks for a TTY and fails with "the input device is not
#                    a TTY", since this never runs interactively.
# More background in env/tool-versions.md.
set -euo pipefail
source env/setup.sh 2>/dev/null || true
openlane --docker-no-tty --dockerized --to OpenROAD.STAPrePNR pd/openlane/config.json
echo "Done. Look in pd/openlane/runs/<run>/ (the *-sta/ and 1-*-yosys/ folders)."
