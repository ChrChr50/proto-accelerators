#!/usr/bin/env bash
# Parse a Yosys `stat` text report into the curated synthesis-summary fields
# used by docs/synthesis_summary.md and reports/<ts>_synth-check/summary.md.
#
#   parse_yosys_stat.sh <full_yosys.log> <stat_only.log> <output.md>
#
# Flip-flop classification is based on the "$_DFF" / "$_SDFF" cell-name
# prefix Yosys's internal gate library uses after `synth -flatten` -- e.g.
# $_DFF_PN0_, $_DFFE_PN0P_. $scopeinfo is a debug/metadata pseudo-cell, not
# real logic, and is excluded from both flip-flop and combinational counts.
set -euo pipefail

full_log="$1"
stat_log="$2"
out_md="$3"

total_cells=$(grep -oE '^[[:space:]]*[0-9]+ cells$' "$stat_log" | grep -oE '[0-9]+' || echo 0)
dff_cells=$(awk '/\$_S?DFF/ {sum += $1} END {print sum+0}' "$stat_log")
scopeinfo=$(awk '/\$scopeinfo/ {sum += $1} END {print sum+0}' "$stat_log")
comb_cells=$(( total_cells - dff_cells - scopeinfo ))
warnings=$(grep -c '^Warning:' "$full_log" || true)
yosys_version=$(yosys -V 2>/dev/null | head -1 || echo "version unknown")

cat > "$out_md" <<EOF
# MACC-8 — Synthesis Summary (Yosys, technology-independent)

Generated $(date -u +%Y-%m-%dT%H:%M:%SZ) by \`make synth-check\`
(\`syn/yosys_area.tcl\`, $yosys_version, no PDK). Raw logs are the timestamped
\`reports/<ts>_synth-check/\` directory this file was copied from.

| Field | Value |
|---|---|
| Total cells | $total_cells |
| Flip-flops | $dff_cells |
| Combinational cells | $comb_cells |
| Estimated area | N/A at this stage — technology-independent proxy only. Real area comes from OpenLane (\`scripts/run_synth.sh\`) once the Sky130 PDK is available. |
| Critical warnings | $warnings |

## Synthesizability checks

\`syn/yosys_area.tcl\` asserts these (the run fails, not just warns, if
violated) — this run passed all of them:

- [x] No inferred latches (\`\$_DLATCH_*\` / \`\$_DLATCHSR_*\` cells)
- [x] No undriven nets
- [x] No multiple drivers
- [x] No unsynthesizable constructs (\`yosys check -assert\`)

See \`docs/flow.md\` for how this step fits into the overall make-target flow.
EOF
