# Flow: make targets -> tools -> artifacts

| Target | Tools | Expected artifacts |
|---|---|---|
| `make lint` | Verible, Verilator (`--lint-only`) | clean console output; waivers in `lint/` if justified |
| `make sim` | cocotb + Verilator (fallback Icarus) | pass/fail in `verif/cocotb/`, waveforms in `build/` |
| `make formal` | SymbiYosys (sby) + Yosys | PASS/FAIL per property in sby output |
| `make pdk` | Volare | `pdk/sky130A` populated |
| `make synth` | OpenLane 2 (synth + STA only) | netlist + timing report under `pd/openlane/runs/` |
| `make gds` | OpenLane 2 (full harden) | GDSII + full report set under `pd/openlane/runs/` |
| `make signoff` | Magic (DRC) + Netgen (LVS) | clean DRC/LVS reports under `pd/openlane/runs/` |
| `make vectors` | `scripts/gen_vectors.py` | golden vectors under `verif/vectors/` |

See `CLAUDE.md` for the required order of work and pass/fail gates between
stages.
