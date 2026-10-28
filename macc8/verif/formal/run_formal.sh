#!/usr/bin/env bash
# Runs both MACC-8 proofs in place. Needs yosys, yosys-smtbmc, sby and z3.
set -euo pipefail
cd "$(dirname "$0")"
sby -f fsm_props.sby
sby -f handshake_props.sby
echo "Both proofs passed."
