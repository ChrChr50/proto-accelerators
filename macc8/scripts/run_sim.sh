#!/usr/bin/env bash
# Shortcut for `make sim` (the full-length regression). For the quicker
# variants run `make sim-fast` or `make sim-icarus` yourself.
set -euo pipefail
source env/setup.sh
make sim
