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
| OpenROAD | TBD | bundled with OpenLane's own Docker image (see `--dockerized` note below) |
| Magic | TBD | bundled with OpenLane's own Docker image |
| KLayout | TBD | bundled with OpenLane's own Docker image |
| Netgen | TBD | bundled with OpenLane's own Docker image |
| Sky130 PDK (Volare, via `scripts/install_pdk.sh`) | `c6d73a35f524070e85faff4a6a9eef49553ebc2b` | fetched 2026-07-12, "latest" per `volare ls-remote`, ~2.1G under `macc8/pdk/` |
| Sky130 PDK (Volare, via OpenLane's own pin) | `0fe599b2afb6708d281543108caf8310912f54af` | **different from the above** — OpenLane 2.3.10 auto-fetched its own pinned-compatible version on first run, separate from whatever `scripts/install_pdk.sh` grabbed as "latest." Both now coexist under `macc8/pdk/volare/sky130/versions/`. Harmless (just extra disk), but a design mismatch worth resolving later: `scripts/install_pdk.sh` could instead read OpenLane's expected version rather than blindly grabbing "latest." |

**OpenLane install note (2026-07-12):** `pip install openlane` alone isn't enough --
its `TclUtils` module imports Python's `tkinter`, which Ubuntu packages
separately from the base `python3` install. Without the system `python3-tk`
package, `openlane --version` fails with `ModuleNotFoundError: No module
named 'tkinter'`. Fix: `sudo apt-get install -y python3-tk` (system-level,
not pip -- venvs share access to the base interpreter's stdlib once it's
installed at the OS level, no need to recreate the venv).

**OpenLane needs `--dockerized` (found 2026-07-13):** several OpenLane 2.x
steps (e.g. Generate JSON Header) run Yosys via `-y <script.py>`, which
requires **pyosys** (Yosys built with embedded Python scripting). Our local
OSS-CAD-Suite Yosys (0.67+24, used for `make lint`/`make formal`/
`make synth-check`) was not built with pyosys support -- confirmed via
`yosys --help` showing no `-y` flag at all. Running OpenLane against it fails
with `Error parsing options: Option 'y' does not exist`. Fix: pass
`--dockerized` to every `openlane` invocation (`scripts/run_synth.sh`,
`scripts/run_gds.sh`) so it runs inside OpenLane's own official Docker image
(which has a properly-built pyosys) instead of using the local toolchain.
This means Phase 7's actual harden uses a *different* Yosys/OpenROAD/Magic/
Netgen than Phases 4-5's lint/formal/synth-check -- the local OSS-CAD-Suite
install and the Dockerized OpenLane image are two separate, non-overlapping
toolchains serving different phases of this flow.

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
