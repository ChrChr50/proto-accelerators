# Pinned tool versions

Record the exact version of every tool used, for reproducibility.

**Installed 2026-07-11, inside WSL2 (Ubuntu 22.04.3 LTS).** OSS-CAD-Suite does
**not** bundle Verible in this build — installed separately from its own
releases. Toolchain lives at `~/tools/` (native WSL2 filesystem), not inside
the repo; see `env/setup.sh`.

| Tool | Version | Notes |
|---|---|---|
| OSS-CAD-Suite | build 20260711 | bundles yosys, verilator, iverilog, sby, z3, gtkwave — **not** verible |
| Verible | v0.0-4080-ga0a8d8eb (built 2026-06-16) | installed separately from `chipsalliance/verible` releases (`linux-static-x86_64`) |
| Verilator | 5.051 devel (rev v5.050-55-g52287c025, mod) | |
| Icarus Verilog | 14.0 (devel) (s20260301-270-g0723d9a47-dirty) | fallback sim, not yet run against this design |
| cocotb | 1.9.2 | in a dedicated venv at `~/tools/macc8-venv`, matches `env/requirements.txt` pin (`==1.9.*`) |
| SymbiYosys (sby) | v0.67 | |
| Yosys | 0.67+24 (git sha1 0e82bbefe, Release, Clang) | |
| z3 | 4.15.5 - 64 bit | SymbiYosys solver backend |
| GTKWave | 3.4.0 | |
| OpenLane | TBD | 2.x — not yet installed (Phase 7, needs Docker) |
| OpenROAD | TBD | bundled with OpenLane |
| Magic | TBD | bundled with OpenLane |
| KLayout | TBD | bundled with OpenLane |
| Netgen | TBD | bundled with OpenLane |
| Sky130 PDK (Volare) | TBD | `volare ls-remote --pdk sky130` — not yet fetched (Phase 7) |

**Version drift warning:** the delivery notes for this RTL/testbench were
validated against **Yosys 0.33** and **Verilator 5.020** — both dramatically
older than what's installed here (Yosys 0.67, Verilator 5.051-devel). cocotb
matches exactly (1.9.2 both times). This gap is wide enough that new lint
warnings, synthesis behavior, or simulation edge cases not seen during the
original validation are plausible. Treat the first `make lint` / `make sim`
run on this toolchain as a real test, not a formality — don't assume a clean
result just because it passed before on older tools.
