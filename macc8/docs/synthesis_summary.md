# MACC-8 — Synthesis Summary (Yosys, technology-independent)

**Status: template — not yet populated in this repo.** Run
`yosys -c syn/yosys_area.tcl` from the workspace root (needs Yosys; see
`env/setup.sh`) and fill in the fields below from its output /
`reports/synth_yosys.log`.

| Field | Value |
|---|---|
| Total cells | TBD |
| Flip-flops | TBD |
| Combinational cells | TBD |
| Estimated area | N/A at this stage — technology-independent proxy only. Real area comes from OpenLane (`scripts/run_synth.sh`) once the Sky130 PDK is available. |
| Critical warnings | TBD |

## Synthesizability checks

`syn/yosys_area.tcl` asserts these (the run fails, not just warns, if violated):

- [ ] No inferred latches (`$_DLATCH_*` / `$_DLATCHSR_*` cells)
- [ ] No undriven nets
- [ ] No multiple drivers
- [ ] No unsynthesizable constructs (`yosys check -assert`)

Check these boxes once a real run confirms them.

## Prior claim (external, not yet reproduced here)

The RTL delivery notes (`docs/formal_and_pd.md`) report a prior run on
Yosys 0.33: elaborate/check clean, ≈336 flip-flops, XOR/XNOR/AOI-heavy
combinational logic consistent with the multiplier-plus-adder-tree signature.
That run happened outside this repo and hasn't been independently reproduced
here yet — treat it as a prior claim, not a verified result, until this
file's table above is actually filled in from a run in this environment.

See `docs/flow.md` for how this step fits into the overall make-target flow.
