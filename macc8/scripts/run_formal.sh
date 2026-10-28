#!/usr/bin/env bash
# Shortcut for `make formal`, which saves its results under reports/.
# verif/formal/run_formal.sh runs the same proofs without saving anything,
# which is handy while editing properties.
set -euo pipefail
source env/setup.sh
make formal
