# Claude Code — build instructions for the MACC-8 workspace

You are scaffolding an RTL-to-GDSII workspace for MACC-8, a programmable int8
8-lane (4-lane configurable) dot-product engine. Authoritative specs live in
docs/int8_mac_design_spec.md and docs/int8_mac_block_diagram.md — read them first.

## Ground rules
- Create the exact directory tree in this repo's structure spec. Do not invent
  extra top-level dirs.
- rtl/ contains SYNTHESIZABLE SystemVerilog only: no classes, interfaces,
  program blocks, or `initial` outside testbenches. Keep to a subset OpenLane's
  Yosys front end accepts.
- All parameters (LANES, ACT_W=8, PROD_W=16, TREE_W=20, ACC_W=32) live in
  rtl/macc8_pkg.sv. Never hardcode widths in leaf modules.
- Signed arithmetic is explicit: use `signed` types / `$signed()` casts. The
  int8xint8->int16 multiply must be signed; the tree sign-extends to int20; the
  accumulator sign-extends to int32 with wrap+flag OR saturate per CONFIG.acc_sat.
- FSM (rtl/macc8_fsm.sv) is one-hot: IDLE -> MUL -> ADACC -> DONE. busy high in
  MUL/ADACC/DONE. done is a 1-cycle pulse; STATUS.done is sticky read-to-clear.
- Reset is active-low rst_n, async assert / sync deassert via macc8_reset_sync.
- Register map, protocols, and latencies MUST match the spec tables exactly.

## Order of work
1. Create tree + all stub/config files listed in the structure spec (Makefile,
   .gitignore, SDC, OpenLane config.json, cocotb Makefile, sby files, requirements).
2. Write rtl/macc8_pkg.sv, then leaf modules, then composites, then macc8_top.sv.
   Keep rtl/macc8.f compile order correct.
3. Write verif/models/macc8_ref.py (NumPy golden: products, tree sum, acc
   wrap/saturate) and verif/cocotb/test_macc8.py (directed: zeros, one-hot,
   +/-127, -128*-128, multi-chunk accumulate, 4- vs 8-lane, overflow/sat;
   plus constrained-random checked against the golden model).
4. Write verif/sva/ + verif/formal/props.sv properties (handshake stability,
   start->done causality, one-hot FSM, no deadlock).

## Verify each stage before moving on
- `make lint`   -> Verible + Verilator clean (fix or justify-waive warnings).
- `make sim`    -> cocotb regression passes bit-exact vs golden.
- `make formal` -> all sby properties PASS.
- `make pdk && make synth` -> OpenLane synthesis + STA meets 10 ns; report area.
- `make gds`    -> full harden; then `make signoff` -> DRC + LVS clean.

## Reporting
After synth/gds, summarize achieved clock, cell area, and critical path into
reports/ and note them against the spec's targets (100 MHz, < 0.05 mm2).
Flag any deviation explicitly; do not silently relax targets.
