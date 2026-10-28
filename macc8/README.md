# MACC-8

An int8 dot-product engine with 8 lanes (switchable to 4), built for the
SkyWater Sky130 open PDK with OpenLane 2.

More detail lives in `docs/`: the spec (`int8_mac_design_spec.md`), the block
diagram and microarchitecture notes (`int8_mac_block_diagram.md`), and the
make-target flow (`flow.md`).

## Tools

| What | Using |
|---|---|
| Lint | Verible, `verilator --lint-only` |
| Simulation | cocotb on Verilator (main) or Icarus |
| Reference model | Python/NumPy |
| Formal | SymbiYosys + Yosys |
| Equivalence (optional) | Yosys `eqy` |
| Synthesis and P&R | OpenLane 2 (Yosys, OpenROAD, Magic, KLayout, Netgen) |
| PDK | Sky130 through Volare |
| Front-end toolchain | OSS-CAD-Suite |
| CI | GitHub Actions |

## Getting started

```bash
# first time only
python -m venv .venv
source .venv/bin/activate
pip install -r env/requirements.txt
source env/setup.sh     # puts OSS-CAD-Suite on PATH
make pdk                # downloads Sky130

# day to day
make lint
make sim
make formal

# backend
make synth              # synthesis + STA only
make gds                # the whole RTL-to-GDSII run
make signoff            # DRC and LVS
```

## What's where

| Folder | Contents |
|---|---|
| `rtl/` | the synthesizable SystemVerilog |
| `include/` | shared compile-time macros |
| `constraints/` | SDC and pin placement hints |
| `verif/` | cocotb tests, the reference model, formal properties |
| `lint/` | Verible/Verilator settings and waivers |
| `pd/openlane/` | OpenLane config (run outputs are git-ignored) |
| `pdk/` | Sky130 installed by Volare (git-ignored) |
| `scripts/` | helper scripts the Makefile calls |
| `reports/` | timestamped lint/sim/formal/synth results, committed |
| `docs/` | spec, block diagram, flow notes |
| `caravel/` | placeholder for a future Caravel wrapper |
