# Build flow

## Make targets

| Target | Runs | Output |
|---|---|---|
| `make lint` | Verible and `verilator --lint-only` | `reports/<ts>_lint/` |
| `make sim` | cocotb on Verilator, full length (crosses the real int32 limit) | `reports/<ts>_sim-full/` |
| `make sim-fast` | same, with `MACC8_FAST=1` so the overflow loops stop early | `reports/<ts>_sim-fast/` |
| `make sim-icarus` | cocotb on Icarus, fast mode | `reports/<ts>_sim-icarus/` (cocotb version caveat in `env/tool-versions.md`) |
| `make formal` | SymbiYosys | `reports/<ts>_formal/`, logs plus the full sby work dirs |
| `make synth-check` | generic Yosys synthesis, no PDK | `reports/<ts>_synth-check/`; the summary is also copied to `docs/synthesis_summary.md`. Fails on latches, undriven nets, multiple drivers, or anything unsynthesizable. |
| `make pdk` | Volare | `pdk/sky130A` (git-ignored) |
| `make synth` | OpenLane 2, stopping after STA | netlist and timing in `pd/openlane/runs/` (git-ignored) |
| `make gds` | OpenLane 2, full harden | GDSII and reports in `pd/openlane/runs/` (git-ignored) |
| `make signoff` | Magic DRC, Netgen LVS | results in `pd/openlane/runs/` (git-ignored) |
| `make vectors` | `scripts/gen_vectors.py` | vectors in `verif/vectors/` (not written yet) |

The lint, sim, formal and synth-check reports are committed; see
`reports/README.md` for why. The OpenLane targets still write into
`pd/openlane/runs/`, since OpenLane keeps its own run history there. Moving
those into `reports/` as well is something I may do once the backend runs are
routine.

## Order of work

Don't move to the next step until the current one passes:

1. `make lint` comes back clean, or every warning has a written waiver.
2. `make sim` matches the reference model bit for bit.
3. `make formal` proves every property.
4. `make pdk && make synth` meets 10 ns; note the area.
5. `make gds`, then `make signoff` with zero DRC and LVS errors.

After synth and gds, write the achieved clock, cell area and critical path
into `reports/` next to the spec targets (100 MHz, under 0.05 mm²). If a
target is missed, say so; don't quietly loosen it.
