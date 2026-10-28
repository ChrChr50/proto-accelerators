#!/usr/bin/env bash
# Prints the DRC, LVS and antenna results from the newest OpenLane run.
set -euo pipefail
latest=$(ls -td pd/openlane/runs/* 2>/dev/null | head -1)
[ -z "$latest" ] && { echo "No OpenLane runs yet. Run scripts/run_gds.sh first."; exit 1; }
echo "Newest run: $latest"
grep -iE '"(magic__drc|klayout__drc|lvs).*"|violations|error' "$latest/metrics.json" 2>/dev/null || \
  echo "Nothing matched in metrics.json; check $latest/*-drc/ and *-lvs/ by hand."
