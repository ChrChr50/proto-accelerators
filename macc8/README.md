# MACC-8

Programmable int8, 8-lane (4-lane configurable) dot-product engine — RTL-to-GDSII
on the open SkyWater Sky130 PDK via OpenLane 2.

Companion docs: `docs/int8_mac_design_spec.md`, `docs/int8_mac_block_diagram.md`,
`docs/flow.md`.

## Toolchain

| Stage | Tool |
|---|---|
| Lint | Verible + `verilator --lint-only` |
| Simulation / DV | cocotb + Verilator (fast) / Icarus (fallback) |
| Golden model | Python + NumPy int8 reference |
| Formal | SymbiYosys (sby) + Yosys |
| Equivalence (opt.) | Yosys `eqy` |
| Synthesis + Physical | OpenLane 2 (Yosys, OpenROAD, Magic, KLayout, Netgen) |
| PDK | Sky130 via Volare/ciel |
| Front-end bundle | OSS-CAD-Suite |
| CI | GitHub Actions |

## Quickstart

```bash
# one-time
python -m venv .venv && source .venv/bin/activate
pip install -r env/requirements.txt
source env/setup.sh          # OSS-CAD-Suite on PATH
make pdk                     # fetch Sky130

# inner loop
make lint
make sim
make formal

# implementation
make synth                   # fast: synthesis + STA
make gds                     # full RTL-to-GDSII
make signoff                 # DRC + LVS
```

## Layout

- `rtl/` — synthesizable SystemVerilog only (populate this to run the flow end-to-end)
- `include/` — compile-time macros shared across RTL
- `constraints/` — SDC + pin placement hints
- `verif/` — cocotb testbenches, golden model, SVA, formal properties
- `lint/` — Verible/Verilator rule configs and waivers
- `pd/openlane/` — OpenLane 2 config and run outputs (git-ignored)
- `pdk/` — Volare-managed Sky130 (git-ignored)
- `scripts/` — one-shot flow scripts invoked by the Makefile
- `reports/` — collected area/timing/power/DRC summaries (git-ignored)
- `docs/` — design spec, block diagram, flow notes
- `caravel/` — optional Caravel user-project integration

See `CLAUDE.md` for the authoritative build/verify order of work.
