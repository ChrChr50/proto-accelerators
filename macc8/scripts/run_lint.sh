#!/usr/bin/env bash
# Thin wrapper: `make lint` is the source of truth (and writes a timestamped,
# committed report to reports/ -- see reports/README.md).
set -euo pipefail
source env/setup.sh
make lint
