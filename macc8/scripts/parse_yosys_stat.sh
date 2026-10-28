#!/usr/bin/env bash
# Turns Yosys `stat` output into the short summary in docs/synthesis_summary.md
# (and reports/<ts>_synth-check/summary.md).
#
#   parse_yosys_stat.sh <full_yosys.log> <stat_only.log> <output.md>
#
# After `synth -flatten`, every flop is a $_DFF* or $_SDFF* cell
# ($_DFF_PN0_, $_DFFE_PN0P_, ...), so that prefix is what gets counted.
# $scopeinfo cells only carry hierarchy names, so they're left out of both
# counts.
set -euo pipefail

full_log="$1"
stat_log="$2"
out_md="$3"

n_cells=$(grep -oE '^[[:space:]]*[0-9]+ cells$' "$stat_log" | grep -oE '[0-9]+' || echo 0)
n_ffs=$(awk '/\$_S?DFF/ {n += $1} END {print n+0}' "$stat_log")
n_scope=$(awk '/\$scopeinfo/ {n += $1} END {print n+0}' "$stat_log")
n_comb=$(( n_cells - n_ffs - n_scope ))
n_warn=$(grep -c '^Warning:' "$full_log" || true)
yosys_ver=$(yosys -V 2>/dev/null | head -1 || echo "(version unknown)")
yosys_ver=${yosys_ver#Yosys }

cat > "$out_md" <<EOF
# MACC-8 synthesis summary (generic Yosys, no PDK)

Written by \`make synth-check\` at $(date -u +%Y-%m-%dT%H:%M:%SZ), using
\`syn/yosys_area.tcl\` on Yosys $yosys_ver. The full logs are in the
\`reports/<ts>_synth-check/\` folder this file came from.

| | |
|---|---|
| Total cells | $n_cells |
| Flip-flops | $n_ffs |
| Combinational cells | $n_comb |
| Area | not available yet; these are technology-independent counts. Real Sky130 area comes from OpenLane (\`scripts/run_synth.sh\`). |
| Yosys warnings | $n_warn |

## Checks

\`syn/yosys_area.tcl\` fails the run outright if any of these don't hold. All
passed:

- [x] no latches (\`\$_DLATCH_*\` / \`\$_DLATCHSR_*\` cells)
- [x] no undriven nets
- [x] no nets with more than one driver
- [x] nothing unsynthesizable (\`yosys check -assert\`)

\`docs/flow.md\` shows where this fits among the other make targets.
EOF
