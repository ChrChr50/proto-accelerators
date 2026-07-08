#!/usr/bin/env bash
set -euo pipefail
source env/setup.sh
make -C verif/cocotb SIM=verilator
