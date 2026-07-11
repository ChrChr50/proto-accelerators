#!/usr/bin/env bash
# Thin wrapper: `make sim` is the source of truth (and writes a timestamped,
# committed report to reports/ -- see reports/README.md). Use `make sim-fast`
# or `make sim-icarus` directly for the other variants.
set -euo pipefail
source env/setup.sh
make sim
