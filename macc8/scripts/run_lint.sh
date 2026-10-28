#!/usr/bin/env bash
# Shortcut for `make lint`. Use make directly if you prefer; either way the
# results land in a new reports/<ts>_lint/ folder.
set -euo pipefail
source env/setup.sh
make lint
