# MACC-8 synthesis summary (generic Yosys, no PDK)

Written by `make synth-check` at 2026-07-11T23:48:56Z, using
`syn/yosys_area.tcl` on Yosys 0.67+24 (git sha1 0e82bbefe, Release, Clang /usr/bin/clang++ 18.1.8). The full logs are in the
`reports/<ts>_synth-check/` folder this file came from.

| | |
|---|---|
| Total cells | 5050 |
| Flip-flops | 336 |
| Combinational cells | 4699 |
| Area | not available yet; these are technology-independent counts. Real Sky130 area comes from OpenLane (`scripts/run_synth.sh`). |
| Yosys warnings | 0 |

## Checks

`syn/yosys_area.tcl` fails the run outright if any of these don't hold. All
passed:

- [x] no latches (`$_DLATCH_*` / `$_DLATCHSR_*` cells)
- [x] no undriven nets
- [x] no nets with more than one driver
- [x] nothing unsynthesizable (`yosys check -assert`)

`docs/flow.md` shows where this fits among the other make targets.
