# MACC-8 — Synthesis Summary (Yosys, technology-independent)

Generated 2026-07-11T23:48:56Z by `make synth-check`
(`syn/yosys_area.tcl`, Yosys 0.67+24 (git sha1 0e82bbefe, Release, Clang /usr/bin/clang++ 18.1.8), no PDK). Raw logs are the timestamped
`reports/<ts>_synth-check/` directory this file was copied from.

| Field | Value |
|---|---|
| Total cells | 5050 |
| Flip-flops | 336 |
| Combinational cells | 4699 |
| Estimated area | N/A at this stage — technology-independent proxy only. Real area comes from OpenLane (`scripts/run_synth.sh`) once the Sky130 PDK is available. |
| Critical warnings | 0 |

## Synthesizability checks

`syn/yosys_area.tcl` asserts these (the run fails, not just warns, if
violated) — this run passed all of them:

- [x] No inferred latches (`$_DLATCH_*` / `$_DLATCHSR_*` cells)
- [x] No undriven nets
- [x] No multiple drivers
- [x] No unsynthesizable constructs (`yosys check -assert`)

See `docs/flow.md` for how this step fits into the overall make-target flow.
