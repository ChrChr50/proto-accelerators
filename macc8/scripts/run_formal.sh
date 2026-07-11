#!/usr/bin/env bash
# Thin wrapper: `make formal` is the source of truth (and writes a
# timestamped, committed report to reports/ -- see reports/README.md).
# For a quick, unrecorded local check instead, run verif/formal/run_formal.sh
# directly (writes ephemeral, git-ignored output under verif/formal/).
set -euo pipefail
source env/setup.sh
make formal
