# MACC‑8 Verification Environment

A cocotb + Verilator regression with a Python golden reference model. Every RTL
result is scoreboarded bit‑exact against `macc8_ref.Macc8Model`.

## Why cocotb (and not UVM)

UVM requires a SystemVerilog simulator with full class/constraint/UVM‑library
support (commercial: VCS / Questa / Xcelium). The open‑source Sky130 flow this
workspace targets uses **Verilator** and **Icarus**, neither of which runs UVM.
cocotb gives the same testbench *architecture* — driver, monitor, scoreboard,
sequences — in Python, runs on the free toolchain, and shares one language with
the golden model. The mapping to UVM roles lives in `macc8_env.py`:

| UVM role | cocotb here |
|---|---|
| driver / sequencer (reg bus) | `Macc8Env.wr` / `rd` |
| driver (activation stream)   | `Macc8Env.send` |
| monitor                      | `Macc8Env.wait_done` (+ `busy`/`done` sampling) |
| scoreboard                   | `Macc8Env.check_acc` / `check_ovf` / `check_status` |
| reference model              | `models/macc8_ref.py` |
| sequences / tests            | `test_macc8.py` |

## Layout

```
verif/
├── models/macc8_ref.py     # golden reference model (no cocotb dependency)
└── cocotb/
    ├── Makefile            # Verilator (default) / Icarus; WAVES + FAST knobs
    ├── macc8_env.py        # drivers, monitor, scoreboard, sequences
    ├── test_macc8.py       # the test suite
    └── gtkwave_macc8.gtkw  # GTKWave save file
```

## Running

```bash
cd verif/cocotb
make                       # full suite on Verilator
make SIM=icarus            # run on Icarus Verilog instead
make WAVES=1               # also dump macc8.fst
make MACC8_FAST=1          # shrink the accumulate-to-overflow loops (quick)
make MACC8_RANDN=200       # override random-vector count (default 1000)
make TESTCASE=test_reset_behavior   # run a single test
make clean
```

Waveforms: `make WAVES=1` then `gtkwave macc8.fst gtkwave_macc8.gtkw`.

## Test inventory

**Basic:** reset behavior · one known dot product · all‑zero · all‑positive · mixed‑signed.
**Corner:** max +int8 · max −int8 · overflow boundary (wrap+flag and saturate) ·
repeated operations · back‑to‑back (auto_start streaming) · invalid command handling.
**Random:** ≥1000 random vectors (lane count, acc_en, saturate, weights, activations
all randomized), each checked against the model.
**Protocol:** start‑before‑load · read‑before‑done · reset‑during‑operation.
**Model:** exact ±2³¹ boundary self‑check (fast, no DUT).

## Notes on the overflow tests

Reaching the real int32 boundary requires accumulating the maximum 8‑lane pass
(`8·127·127 = 129032`) ~16.6k times, so `test_overflow_boundary_wrap` and
`…_saturate` are the slow tests. `MACC8_FAST=1` shrinks their loops for quick
iteration; the exact boundary arithmetic is additionally proven instantly by
`test_model_boundary_selfcheck`. In CI, run the full suite nightly and
`MACC8_FAST=1` on every push.

## Validation status (as delivered)

Run on Verilator 5.020 + cocotb 1.9.2. All tests pass, including the full
(non‑FAST) int32 wrap and saturate crossings and the 1000‑vector random sweep.

## Tool version note

- **cocotb 2.x requires Verilator ≥ 5.036.** With older Verilator (e.g. 5.020),
  pin `cocotb==1.9.x`. The env's clock setup works under both 1.x and 2.x.
- Icarus is supported as a drop‑in (`make SIM=icarus`) for environments without
  a recent Verilator.
