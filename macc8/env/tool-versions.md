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
| Icarus Verilog | 14.0 (devel) (s20260301-270-g0723d9a47-dirty) | verified 2026-07-11: 17/17 cocotb tests pass -- see cocotb caveat below |
| cocotb | 1.9.2 (Verilator) / 2.1.0.dev0+41564633 (Icarus, forced) | see caveat below -- these are genuinely two different cocotb versions depending on simulator |
| SymbiYosys (sby) | v0.67 | |
| Yosys | 0.67+24 (git sha1 0e82bbefe, Release, Clang) | |
| z3 | 4.15.5 - 64 bit | SymbiYosys solver backend |
| GTKWave | 3.4.0 | |
| OpenLane | v2.3.10 | installed 2026-07-12 via pip into `~/tools/macc8-venv`; needs system `python3-tk` (see note below) |
| Volare | v0.20.6 | installed 2026-07-12 via pip into `~/tools/macc8-venv` |
| OpenROAD | TBD | bundled with OpenLane, pulled as its own Docker image on first real run |
| Magic | TBD | bundled with OpenLane |
| KLayout | TBD | bundled with OpenLane |
| Netgen | TBD | bundled with OpenLane |
| Sky130 PDK (Volare) | TBD | `volare ls-remote --pdk sky130` — not yet fetched |

**OpenLane install note (2026-07-12):** `pip install openlane` alone isn't enough --
its `TclUtils` module imports Python's `tkinter`, which Ubuntu packages
separately from the base `python3` install. Without the system `python3-tk`
package, `openlane --version` fails with `ModuleNotFoundError: No module
named 'tkinter'`. Fix: `sudo apt-get install -y python3-tk` (system-level,
not pip -- venvs share access to the base interpreter's stdlib once it's
installed at the OS level, no need to recreate the venv).

**Version drift warning:** the delivery notes for this RTL/testbench were
validated against **Yosys 0.33** and **Verilator 5.020** — both dramatically
older than what's installed here (Yosys 0.67, Verilator 5.051-devel). cocotb
matches exactly (1.9.2 both times, for the Verilator path). This gap is wide
enough that new lint warnings, synthesis behavior, or simulation edge cases
not seen during the original validation are plausible. `make lint` and
`make sim` were both re-verified clean on this exact toolchain 2026-07-11
(see below) — treat that as the real baseline, not the older delivery notes.

**Icarus/cocotb version caveat (found 2026-07-11):** OSS-CAD-Suite's `vvp`
is a wrapper script that unconditionally does `export PYTHONHOME="<oss-cad-suite
root>"` before exec-ing the real binary, regardless of any active venv. This
means `vvp` can only cleanly embed OSS-CAD-Suite's own bundled Python/cocotb
(2.1.0.dev0, via its bundled `tabbypy3`) -- pointing it at the pinned
`cocotb==1.9.2` venv instead crashes with `Fatal Python error:
init_fs_encoding ... No module named 'encodings'` (mismatched Python 3.10 venv
vs. the 3.11 stdlib layout `PYTHONHOME` now points at). **Verified working
2026-07-11, 17/17 tests, but only when running with just
`source ~/tools/oss-cad-suite/environment` active and *not* the
`macc8-venv`** (i.e. don't run `env/setup.sh` as-is for the Icarus path --
skip the venv activation step, or manually `deactivate` first). The Verilator
path has no such conflict; the venv's 1.9.2 is what's actually used there.
Icarus also emits several non-fatal `sorry:` notices for constant selects in
`always_*` blocks (`macc8_regfile.sv`, `macc8_accumulator.sv`) and ignores
`unique`/`unique0` case qualifiers -- known Icarus SystemVerilog subset
limitations, not functional failures (all tests still passed bit-exact).
