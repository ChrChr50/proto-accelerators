# Flow: make targets -> tools -> artifacts

| Target | Tools | Expected artifacts |
|---|---|---|
| `make lint` | Verible, Verilator (`--lint-only`) | `reports/<ts>_lint/` (committed) |
| `make sim` | cocotb + Verilator, full incl. real int32 overflow crossing | `reports/<ts>_sim-full/` (committed) |
| `make sim-fast` | cocotb + Verilator, `MACC8_FAST=1` (capped overflow loop) | `reports/<ts>_sim-fast/` (committed) |
| `make sim-icarus` | cocotb + Icarus Verilog, fast mode | `reports/<ts>_sim-icarus/` (committed) -- see `env/tool-versions.md` for a cocotb-version caveat specific to this path |
| `make formal` | SymbiYosys (sby) + Yosys | `reports/<ts>_formal/` (committed): logs + full SymbiYosys work dirs (SMT2 models, PASS/FAIL markers) |
| `make pdk` | Volare | `pdk/sky130A` populated (git-ignored) |
| `make synth` | OpenLane 2 (synth + STA only) | netlist + timing report under `pd/openlane/runs/` (git-ignored) |
| `make gds` | OpenLane 2 (full harden) | GDSII + full report set under `pd/openlane/runs/` (git-ignored) |
| `make signoff` | Magic (DRC) + Netgen (LVS) | clean DRC/LVS reports under `pd/openlane/runs/` (git-ignored) |
| `make vectors` | `scripts/gen_vectors.py` | golden vectors under `verif/vectors/` |

`lint`/`sim*`/`formal` write timestamped, **committed** reports -- see
`reports/README.md` for the naming convention and why these aren't just
overwritten in place. `synth`/`gds`/`signoff` still land under the
git-ignored `pd/openlane/runs/` (OpenLane manages its own run history there
already); folding those into `reports/` too is a possible follow-up once
Phase 7 is running for real.

See `CLAUDE.md` for the required order of work and pass/fail gates between
stages.
