# Tool versions

Every tool and the exact version used, so results can be reproduced.

**Installed 2026-07-11 in WSL2 (Ubuntu 22.04.3 LTS).** This OSS-CAD-Suite
build doesn't include Verible, so that came from Verible's own releases.
Everything lives in `~/tools/` on the WSL2 filesystem, outside the repo (see
`env/setup.sh`).

| Tool | Version | Notes |
|---|---|---|
| OSS-CAD-Suite | build 20260711 | includes yosys, verilator, iverilog, sby, z3, gtkwave; **not** verible |
| Verible | v0.0-4080-ga0a8d8eb (built 2026-06-16) | from the `chipsalliance/verible` releases (`linux-static-x86_64`) |
| Verilator | 5.051 devel (rev v5.050-55-g52287c025, mod) | |
| Icarus Verilog | 14.0 (devel) (s20260301-270-g0723d9a47-dirty) | 17/17 cocotb tests pass as of 2026-07-11; see the cocotb note below |
| cocotb | 1.9.2 with Verilator, 2.1.0.dev0+41564633 with Icarus | yes, two different versions depending on the simulator; see below |
| SymbiYosys (sby) | v0.67 | |
| Yosys | 0.67+24 (git sha1 0e82bbefe, Release, Clang) | |
| z3 | 4.15.5 - 64 bit | solver for SymbiYosys |
| GTKWave | 3.4.0 | |
| OpenLane | v2.3.10 | pip-installed into `~/tools/macc8-venv` on 2026-07-12; needs the system `python3-tk` package (below) |
| Volare | v0.20.6 | pip-installed into `~/tools/macc8-venv` on 2026-07-12 |
| OpenROAD | TBD | comes with OpenLane's Docker image (see the `--dockerized` note) |
| Magic | TBD | comes with OpenLane's Docker image |
| KLayout | TBD | comes with OpenLane's Docker image |
| Netgen | TBD | comes with OpenLane's Docker image |
| Sky130 PDK (from `scripts/install_pdk.sh`) | `c6d73a35f524070e85faff4a6a9eef49553ebc2b` | fetched 2026-07-12; the newest one `volare ls-remote` listed; about 2.1 GB under `macc8/pdk/` |
| Sky130 PDK (OpenLane's own pin) | `0fe599b2afb6708d281543108caf8310912f54af` | **not the same as above.** On its first run OpenLane 2.3.10 downloaded the version it's pinned to, separately from the "latest" that `install_pdk.sh` grabbed. Both now sit under `macc8/pdk/volare/sky130/versions/`. It only costs disk space, but it should be cleaned up: `install_pdk.sh` ought to ask OpenLane which version it wants instead of taking the newest. |

### OpenLane needs python3-tk (2026-07-12)

`pip install openlane` isn't quite enough. Its `TclUtils` module imports
`tkinter`, which Ubuntu ships separately from `python3`, so without it
`openlane --version` dies with `ModuleNotFoundError: No module named
'tkinter'`. Install it at the OS level with `sudo apt-get install -y
python3-tk`. The venv picks it up from the base interpreter's stdlib; you
don't need to rebuild the venv.

### OpenLane has to run with --dockerized (2026-07-13)

Some OpenLane 2.x steps (Generate JSON Header, for one) call Yosys with
`-y <script.py>`, which only exists when Yosys is built with pyosys
(embedded Python). The OSS-CAD-Suite Yosys used here for `make lint`,
`make formal` and `make synth-check` doesn't have it; `yosys --help` shows
no `-y` option at all. OpenLane then fails with `Error parsing options:
Option 'y' does not exist`.

The fix is to pass `--dockerized` on every `openlane` call
(`scripts/run_synth.sh`, `scripts/run_gds.sh`) so it uses OpenLane's own
Docker image, where pyosys is built in. The upshot is that the backend runs
on a different Yosys, OpenROAD, Magic and Netgen than lint, formal and
synth-check do. The local OSS-CAD-Suite and the OpenLane image are two
separate toolchains for two separate parts of the flow.

### Older validation numbers

The RTL and testbench were first validated on **Yosys 0.33** and
**Verilator 5.020**, both far older than what's installed now (Yosys 0.67,
Verilator 5.051-devel). cocotb was 1.9.2 both times on the Verilator path.
A version gap that big could easily surface new lint warnings or different
synthesis or simulation behavior, so `make lint` and `make sim` were run
again on this exact toolchain on 2026-07-11 and came back clean. Those runs
are the baseline that counts.

### Icarus and cocotb (2026-07-11)

OSS-CAD-Suite's `vvp` is really a wrapper script that always sets
`PYTHONHOME` to the OSS-CAD-Suite root before starting the real binary,
whatever venv you have active. That means `vvp` can only embed
OSS-CAD-Suite's bundled Python and cocotb (2.1.0.dev0, via its `tabbypy3`).
If you point it at the pinned `cocotb==1.9.2` venv, it crashes with `Fatal
Python error: init_fs_encoding ... No module named 'encodings'`, because the
venv is Python 3.10 and `PYTHONHOME` now points at a 3.11 stdlib.

What works (17/17 tests, checked 2026-07-11): only `source
~/tools/oss-cad-suite/environment`, **without** activating `macc8-venv`. In
other words, don't run `env/setup.sh` as is for Icarus; skip the venv step
or `deactivate` first. Verilator doesn't have this problem and really does
use the venv's 1.9.2.

Icarus also prints a few harmless `sorry:` messages about constant selects
inside `always_*` blocks (`macc8_regfile.sv`, `macc8_accumulator.sv`) and
ignores `unique` / `unique0` on case statements. Those are gaps in Icarus's
SystemVerilog support, not test failures; every test still matches bit for
bit.
