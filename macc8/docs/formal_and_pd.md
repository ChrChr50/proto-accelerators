# MACC‑8 — Formal Verification + Physical Design (RTL‑to‑GDSII)

This delivery adds formal property proofs and the OpenLane synthesis/PD setup,
and includes a small **RTL portability fix** required for the open‑source flow.

## 1. RTL portability fix (important — read first)

Vanilla open‑source **Yosys** `read_verilog -sv` (used by both SymbiYosys and by
OpenLane's default synthesis) does **not** accept SystemVerilog wildcard package
imports (`import macc8_pkg::*;`), in either header or file scope. The original
RTL used header imports, which parse fine in Verilator/slang but fail in Yosys.

Fix: the five modules that imported the package now reference package symbols with
the explicit `macc8_pkg::` scope in their port lists, plus small local aliases in
the body so the logic reads naturally. **No behavior changed** — only symbol
scoping. Affected files (these supersede the earlier RTL delivery):

```
macc8_fsm.sv  macc8_serial_rx.sv  macc8_datapath.sv  macc8_regfile.sv  macc8_top.sv
```

The leaf modules (`macc8_pkg`, `macc8_reset_sync`, `macc8_mac_lane`,
`macc8_adder_tree`, `macc8_accumulator`) were already import‑free and are unchanged.

Re‑validation after the fix (all run here):
- `verilator --lint-only -Wall` — clean.
- Yosys `read_verilog -sv … ; hierarchy ; proc ; check` — clean.
- Full cocotb suite (17 tests incl. 1000‑vector random) — all PASS, behavior identical.

## 2. Formal proofs (SymbiYosys + Yosys + z3)

Two jobs, both **proven unbounded by k‑induction** (not just BMC):

`fsm_props.sby` → `macc8_props_fsm.sv` (over macc8_fsm I/O):
- reset ⇒ engine idle
- IDLE xor busy; capture phases mutually exclusive; done only while busy
- fixed 3‑cycle progression MUL→ADACC→DONE→IDLE (no deadlock, no stall)
- causality: done only right after ADACC; MUL entered only via `go`
- start‑before‑load is a no‑op (stay IDLE while `!go`)
- `consume` strobe only at an accepted pass start

`handshake_props.sby` → `macc8_props_rx.sv` (over macc8_serial_rx I/O):
- `act_ready == (accept_en && !act_full)`
- never ready when full (no overrun); ready ⇒ accepting enabled
- a pass‑start `consume` empties the buffer next cycle
- reset ⇒ buffer empty
- (assumes `active_lanes ∈ {4,8}`)

The properties are written as clocked immediate assertions with `$past` guarded by
a past‑valid flag — the portable idiom vanilla Yosys accepts (it rejects inline‑
clocked `assert property`). Run them with:

```bash
cd verif/formal && ./run_formal.sh      # or: sby -f fsm_props.sby ; sby -f handshake_props.sby
```

Result observed here: **both jobs `DONE (PASS)` — successful proof by k‑induction.**

## 3. Synthesis / PPA

`pd/openlane/config.json` hardens `macc8_top` on **Sky130** (`sky130_fd_sc_hd`) at
`CLOCK_PERIOD 10.0` (100 MHz), with `constraints/macc8.sdc`. Because the RTL is
`macc8_pkg::`‑scoped, OpenLane's Yosys reads it directly — no slang/synlig plugin
needed.

```bash
make pdk            # scripts/install_pdk.sh (Volare -> Sky130)
scripts/run_synth.sh   # OpenLane synthesis + STA (fast loop)
scripts/run_gds.sh     # full RTL-to-GDSII
scripts/run_signoff.sh # DRC / LVS summary from the latest run
```

### First‑order complexity proxy (measured here with Yosys, no PDK)

`syn/yosys_area.tcl` runs technology‑independent synthesis:

- **≈336 flip‑flops** — 128 product‑pipeline + 64 weights + 64 activation regs +
  32 accumulator + 32 read‑data + config/counter/FSM/reset‑sync.
- Combinational cells are **XOR/XNOR/AOI‑heavy**, the signature of the 8 signed
  int8 multipliers plus the adder tree.

This is consistent with the spec's `< 0.05 mm²` Sky130 target; the authoritative
area/timing/power numbers come from the OpenLane run (`metrics.json`, STA reports).

### How to read the first OpenLane report

- **Timing:** check the post‑synth and post‑route STA — worst negative slack (WNS)
  must be ≥ 0 at 10 ns. If MUL→adder‑tree→accumulate is the critical path and WNS
  is slightly negative, split the tree with one more pipeline stage (spec §Timing,
  documented fallback; latency 3→4).
- **Area:** `metrics.json` `design__instance__area` / core utilization vs `FP_CORE_UTIL`.
- **Sign‑off:** `magic__drc__violations` and LVS status must be 0 / clean.

## 4. Tool notes

- Proven here with **Yosys 0.33 + yosys‑smtbmc + z3 + SymbiYosys**. Any oss‑cad‑suite
  build works; a solver (z3/yices/boolector) must be on PATH.
- OpenLane 2 + Volare Sky130 as per the workspace `env/`.
