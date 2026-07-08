#!/usr/bin/env bash
# Run all MACC-8 formal proofs. Requires: yosys, yosys-smtbmc, sby, and a solver (z3).
set -euo pipefail
cd "$(dirname "$0")"
sby -f fsm_props.sby
sby -f handshake_props.sby
echo "All formal proofs passed."
