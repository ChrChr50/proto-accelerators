# MACC-8 verification

The testbench is cocotb on Verilator, checked against a Python reference
model. Every result the RTL produces is compared bit for bit with
`macc8_ref.Macc8Model`.

## Why cocotb instead of UVM

UVM needs a simulator with full SystemVerilog class, constraint and UVM
library support, which in practice means VCS, Questa or Xcelium. The open
Sky130 flow here uses Verilator and Icarus, and neither runs UVM. cocotb
lets me keep the same structure (driver, monitor, scoreboard, sequences) in
Python on free tools, and the testbench and the model end up in the same
language. Roughly how the pieces line up:

| UVM | Here |
|---|---|
| register bus driver/sequencer | `Macc8Env.wr` / `rd` |
| activation stream driver | `Macc8Env.send` |
| monitor | `Macc8Env.wait_done`, plus sampling `busy`/`done` |
| scoreboard | `Macc8Env.check_acc` / `check_ovf` / `check_status` |
| reference model | `models/macc8_ref.py` |
| sequences and tests | `test_macc8.py` |

## Files

```
verif/
├── models/macc8_ref.py     reference model, no cocotb needed
├── cocotb/
│   ├── Makefile            Verilator by default, or Icarus; WAVES and FAST options
│   ├── macc8_env.py        drivers, monitor, scoreboard, helper sequences
│   ├── test_macc8.py       the tests
│   └── gtkwave_macc8.gtkw  saved GTKWave layout
└── formal/                 SymbiYosys jobs and property harnesses
```

## Running it

```bash
cd verif/cocotb
make                                # everything, on Verilator
make SIM=icarus                     # on Icarus
make WAVES=1                        # also write macc8.fst
make MACC8_FAST=1                   # stop the overflow loops early
make MACC8_RANDN=200                # change the random pass count (default 1000)
make TESTCASE=test_reset_behavior   # just one test
make clean
```

To look at waves: `make WAVES=1`, then `gtkwave macc8.fst gtkwave_macc8.gtkw`.

## Tests

- **Basic:** reset state, one hand-checked dot product, all zeros, all
  positive, mixed signs.
- **Corner:** largest positive and negative int8, int32 overflow with
  wrap-and-flag and with saturation, the same pass many times, back-to-back
  passes with auto_start, writes and reads to unmapped addresses.
- **Random:** at least 1000 passes with random lane count, acc_en,
  saturation, weights and activations, each checked against the model.
- **Protocol:** start with nothing loaded, reading ACC mid-pass, reset in
  the middle of a pass.
- **Model:** a quick check of the model at exactly ±2^31, with no DUT
  traffic.

## About the overflow tests

To really reach the int32 limit you have to accumulate the largest 8-lane
pass (`8·127·127 = 129032`) about 16.6k times, so
`test_overflow_boundary_wrap` and `test_overflow_boundary_saturate` are the
slow ones. With `MACC8_FAST=1` they stop after a few passes, and
`test_model_boundary_selfcheck` still covers the boundary math right away.
CI runs the fast mode on every push; the full version is meant for a nightly
job.

## Status

All tests pass, including the full-length int32 wrap and saturate runs and
the 1000-pass random test. They were first run on Verilator 5.020 with
cocotb 1.9.2, and again on the pinned toolchain in `env/tool-versions.md`;
the committed logs are in `reports/*_sim-*`.

## Version notes

- **cocotb 2.x needs Verilator 5.036 or newer.** With an older Verilator
  (5.020, say), stay on `cocotb==1.9.x`. The clock setup in the env handles
  both 1.x and 2.x.
- Icarus works too (`make SIM=icarus`) if you don't have a recent Verilator.
