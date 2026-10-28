# MACC-8: formal proofs and physical design

Notes on the two SymbiYosys proofs, the OpenLane setup, and one change the
open-source flow forced on the RTL.

## Why there are no package imports

Stock Yosys (`read_verilog -sv`, which both SymbiYosys and OpenLane's default
synthesis use) can't parse wildcard imports like `import macc8_pkg::*;`,
whether they sit in the module header or at file scope. Verilator and slang
are fine with them, so this only showed up once the RTL went through Yosys.

So every module spells out `macc8_pkg::` in its port list, and the modules
that use package constants a lot copy them into local `localparam`s near the
top. That's purely a scoping change; the logic is the same. The modules
involved are:

```
macc8_fsm  macc8_serial_rx  macc8_datapath  macc8_regfile  macc8_top
```

`macc8_pkg`, `macc8_reset_sync`, `macc8_mac_lane`, `macc8_adder_tree` and
`macc8_accumulator` never imported anything and didn't need touching.

After the change I re-ran `verilator --lint-only -Wall` (clean), a Yosys
`read_verilog -sv; hierarchy; proc; check` pass (clean), and the full cocotb
suite (17 tests, 1000 random vectors, all passing as before).

## Formal proofs

There are two sby jobs. Both are full k-induction proofs, so they hold for
any number of cycles, not just up to a BMC depth.

**`fsm_props.sby`** checks `macc8_props_fsm.sv` against the I/O of `macc8_fsm`:

- in reset the engine is idle
- `accept_en` and `busy` are always opposites; the two capture strobes never
  overlap; `done` only appears while busy
- every pass goes MUL, ADACC, DONE, IDLE, one cycle each, with no stall
- `done` only follows ADACC, and MUL is only entered when `go` was true
- a `start` with no vector loaded is ignored (stays in IDLE)
- `consume` only fires on the cycle a pass is accepted

**`handshake_props.sby`** checks `macc8_props_rx.sv` against the I/O of
`macc8_serial_rx`:

- `act_ready == (accept_en && !act_full)`
- never ready while full, never ready unless accepting
- `consume` empties the buffer by the next cycle
- the buffer is empty in reset
- assumes `active_lanes` is either 4 or 8

The properties use clocked immediate assertions, with `$past` gated by a
`past_valid` register. Stock Yosys doesn't accept `assert property` with an
inline clock, and this style works everywhere. To run them:

```bash
cd verif/formal
./run_formal.sh                # runs both jobs
sby -f fsm_props.sby           # or one at a time
sby -f handshake_props.sby
```

Both jobs finish with `DONE (PASS)`. The committed logs are under
`reports/*_formal/`.

## Synthesis and PPA

`pd/openlane/config.json` hardens `macc8_top` with `sky130_fd_sc_hd` at a
10 ns clock (100 MHz) using `constraints/macc8.sdc`. With the package
references written out explicitly, OpenLane's Yosys reads the RTL as is; there's
no need for the slang or synlig plugins.

```bash
make pdk                 # scripts/install_pdk.sh, fetches Sky130 with Volare
scripts/run_synth.sh     # synthesis + STA, the quick loop
scripts/run_gds.sh       # complete RTL-to-GDSII
scripts/run_signoff.sh   # DRC/LVS summary of the latest run
```

### Rough size before the PDK

`syn/yosys_area.tcl` does a technology-independent synthesis. It reports
about **336 flip-flops**: 128 for the product pipeline, 64 for weights, 64
for activations, 32 for the accumulator, 32 for read data, and the rest for
config bits, the lane counter, the FSM and the reset synchronizer. The
combinational side is mostly XOR/XNOR/AOI cells, which is what eight signed
multipliers and an adder tree look like.

That's in line with the `< 0.05 mm²` target in the spec. The real area,
timing and power numbers come from OpenLane (`metrics.json` and the STA
reports).

### Reading the first OpenLane run

- **Timing:** look at the post-synthesis and post-route STA. WNS has to be
  0 or better at 10 ns. If the multiply, adder tree, accumulate path is the
  worst one and only misses by a little, split the tree with another
  pipeline register (the fallback in the spec's timing section; latency goes
  from 3 to 4).
- **Area:** `design__instance__area` in `metrics.json`, and core utilization
  compared with `FP_CORE_UTIL`.
- **Signoff:** `magic__drc__violations` must be 0 and LVS must be clean.

## Tool notes

- The proofs were first run with Yosys 0.33, yosys-smtbmc, z3 and
  SymbiYosys, and re-run on the pinned toolchain in `env/tool-versions.md`.
  Any recent OSS-CAD-Suite should work as long as a solver (z3, yices or
  boolector) is on PATH.
- OpenLane 2 and the Sky130 PDK are set up as described in `env/`.
