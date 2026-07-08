#!/usr/bin/env bash
# Report DRC/LVS/antenna outcomes from the most recent OpenLane run.
set -euo pipefail
run=$(ls -td pd/openlane/runs/* 2>/dev/null | head -1)
[ -z "$run" ] && { echo "No OpenLane run found; run scripts/run_gds.sh first."; exit 1; }
echo "Latest run: $run"
grep -iE '"(magic__drc|klayout__drc|lvs).*"|violations|error' "$run/metrics.json" 2>/dev/null || \
  echo "Inspect $run/*-drc/ , *-lvs/ and metrics.json for sign-off status."
