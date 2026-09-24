# Flow: make targets -> tools -> artifacts

| Target | Tools | Expected artifacts |
|---|---|---|
| `make lint` | Verible, Verilator (`--lint-only`) | `reports/<ts>_lint/` (committed) |
| `make sim` | cocotb + Verilator, full incl. real int32 overflow crossing | `reports/<ts>_sim-full/` (committed) |
| `make sim-fast` | cocotb + Verilator, `MACC8_FAST=1` (capped overflow loop) | `reports/<ts>_sim-fast/` (committed) |
| `make sim-icarus` | cocotb + Icarus Verilog, fast mode | `reports/<ts>_sim-icarus/` (committed) -- see `env/tool-versions.md` for a cocotb-version caveat specific to this path |
| `make formal` | SymbiYosys (sby) + Yosys | `reports/<ts>_formal/` (committed): logs + full SymbiYosys work dirs (SMT2 models, PASS/FAIL markers) |
| `make synth-check` | Yosys generic synth, no PDK | `reports/<ts>_synth-check/` (committed): full log, raw `stat` output, curated `summary.md` -- also copied to `docs/synthesis_summary.md` as the latest snapshot. Asserts no inferred latches / undriven nets / multiple drivers / unsynthesizable constructs. |
| `make pdk` | Volare | `pdk/sky130A` populated (git-ignored) |
| `make synth` | OpenLane 2 (synth + STA only) | netlist + timing report under `pd/openlane/runs/` (git-ignored) |
| `make gds` | OpenLane 2 (full harden) | GDSII + full report set under `pd/openlane/runs/` (git-ignored) |
| `make signoff` | Magic (DRC) + Netgen (LVS) | clean DRC/LVS reports under `pd/openlane/runs/` (git-ignored) |
| `make vectors` | `scripts/gen_vectors.py` | golden vectors under `verif/vectors/` |

`lint`/`sim*`/`formal`/`synth-check` write timestamped, **committed** reports -- see
`reports/README.md` for the naming convention and why these aren't just
overwritten in place. `synth`/`gds`/`signoff` still land under the
git-ignored `pd/openlane/runs/` (OpenLane manages its own run history there
already); folding those into `reports/` too is a possible follow-up once
Phase 7 is running for real.

## Order of work and pass/fail gates

Each stage must pass before moving on to the next:

1. `make lint` -> Verible + Verilator clean (fix or justify-waive warnings).
2. `make sim` -> cocotb regression passes bit-exact vs the golden model.
3. `make formal` -> all sby properties PASS.
4. `make pdk && make synth` -> OpenLane synthesis + STA meets 10 ns; report area.
5. `make gds` -> full harden; then `make signoff` -> DRC + LVS clean.

After synth/gds, summarize achieved clock, cell area, and critical path into
`reports/` against the spec's targets (100 MHz, < 0.05 mm²). Flag any
deviation explicitly; do not silently relax targets.
