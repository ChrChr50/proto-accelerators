#!/usr/bin/env bash
set -euo pipefail
source env/setup.sh
verible-verilog-lint --rules_config lint/.rules.verible_lint $(cat rtl/macc8.f | grep -v '^#')
verilator --lint-only -Wall -f rtl/macc8.f
