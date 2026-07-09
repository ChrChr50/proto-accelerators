# Design Specification — MACC‑8: Programmable int8 Dot‑Product Engine

**Document status:** v0.1 (portfolio proposal)
**Author:** Chris Choi Lee
**Scope:** RTL design · accelerator architecture · quantized ML hardware · PPA (power/performance/area) tradeoff analysis

---

## Project name

**MACC‑8** — a programmable 8‑lane (4‑lane configurable) signed int8 multiply‑accumulate dot‑product engine with serial activation streaming, register‑mapped weights, a start/done handshake, and a wide accumulation output.

## Goal

Build a small, tapeout‑ready quantized‑ML compute primitive that demonstrates the full RTL front‑end flow — micro‑architecture, parameterized SystemVerilog, verification, and PPA closure — on a real open‑source shuttle. The engine computes the fundamental accelerator operation:

$$acc \mathrel{+}= \sum_{i=0}^{L-1} a_i \cdot w_i \qquad L \in \{4, 8\}$$

where `a_i`, `w_i` are signed int8 (two's complement). Chunks of length `L` accumulate into a wide result so that longer length‑`K` dot products (`K` a multiple of `L`) are computed as `K/L` accumulating passes. The deliverable is intended to double as an interview artifact: the design intentionally exposes a clean input‑bandwidth‑vs‑compute tradeoff for discussion rather than papering over it.

Explicit **non‑goals** for v0.1: no requantization/activation‑function/bias stage, no spatial (systolic) tiling to GEMM, no per‑channel scaling, int8‑only. These are listed under *Known limitations* and framed as the natural v0.2 roadmap.

## Target shuttle / platform

| Stage | Platform | Purpose |
|---|---|---|
| Functional bring‑up | Low‑cost FPGA dev board (e.g. Lattice/Xilinx Artix‑class) | RTL validation, on‑board golden‑model check over UART |
| ASIC tapeout (primary) | **Efabless ChipIgnite / Caravel harness on SkyWater Sky130** (open PDK) | Real silicon PPA closure; Wishbone control plane + logic‑analyzer probes |
| ASIC tapeout (fallback) | **TinyTapeout** (Sky130) | Smaller, standardized submission if area/pin budget tightens |

The RTL is PDK‑agnostic and parameterized so the same source targets all three. Caravel is the primary target because its Wishbone bus maps cleanly onto the register interface below.

## Clock assumption

- Single clock domain, `clk`. **Target 100 MHz (10 ns period)** at the Sky130 slow corner (SS, 1.60 V, 125 °C) post‑synthesis. FPGA prototype closes this comfortably; the number is a *target* to be confirmed at gate level.
- The activation serial interface and the register/control bus are synchronous to `clk`. No asynchronous or multi‑clock crossings are required in v0.1 (a deliberate scope reduction — CDC is a v0.2 concern if a slow serial link is added).
- Critical path is `int8×int8 multiplier → adder tree → accumulator adder`. It is broken by pipeline registers (see *State machine*) so the target clock is met without a wide combinational MAC path.

## Reset behavior

- Active‑low reset `rst_n`, **asynchronous assertion, synchronous de‑assertion** via a 2‑flop reset synchronizer (standard for Sky130/Caravel).
- On reset the design deterministically enters a known state:
  - FSM → `IDLE`.
  - Accumulator → `0`.
  - Weight registers → `0` (deterministic for sim/silicon reproducibility rather than left `X`).
  - Activation shift register and lane counter → `0`.
  - `STATUS` flags (`busy`, `done`, `acc_ovf`) → `0`; `busy` and `done` are outputs and are guaranteed low out of reset.
- A separate **soft reset** bit in `CTRL` clears the accumulator and FSM without disturbing loaded weights, enabling a fresh dot product without a full chip reset.

## Input protocol

Two decoupled input planes:

**1. Activation data plane — byte‑serial streaming (`valid`/`ready`).**
One signed int8 activation per accepted beat on an 8‑bit bus.

| Signal | Dir | Width | Description |
|---|---|---|---|
| `act_data` | in | 8 | Signed int8 activation |
| `act_valid` | in | 1 | Producer asserts when `act_data` is valid |
| `act_ready` | out | 1 | Engine asserts when it can accept a beat |

- Transfer occurs on any cycle where `act_valid && act_ready`. Standard AMBA‑style handshake: `act_valid` must not depend combinationally on `act_ready`, and once asserted `act_valid`/`act_data` are held stable until accepted.
- Accepted beats fill lanes `0..L-1` in order. When lane `L-1` is filled the engine either auto‑fires a pass (if `CTRL.auto_start=1`) or waits for an explicit `start`.

**2. Control / weight plane — register‑mapped writes (Wishbone on Caravel).**
Weights and control are written through the register map below. Weights are *stationary*: written once, reused across many activation passes until reloaded.

**Start/done handshake.** `start` is a single‑cycle pulse (from `CTRL.start` or a top‑level pin). It is ignored unless the FSM is in `IDLE` with a full activation vector resident. The engine raises `busy` for the duration of the pass and emits a single‑cycle `done` pulse on completion; a sticky `STATUS.done` bit is also set and is cleared on read (read‑to‑clear) or by writing `CTRL.done_clr`.

## Output protocol

- **Primary:** 32‑bit signed accumulator readable at `ACC_OUT` (register map). Value is valid and stable whenever `busy=0`. It is *not* auto‑cleared between passes — accumulation across chunks is the intended behavior; clear explicitly via `CTRL.acc_clr` or soft reset.
- **Streaming/handshake:** `done` (1‑cycle pulse) marks completion of each pass; consumers may latch `ACC_OUT` on `done`. `acc_ovf` in `STATUS` flags signed overflow of the accumulator (see *Datapath width*).
- Accumulate vs. overwrite is selected by `CTRL.acc_en`: `1` = add the pass result into the running accumulator; `0` = load the pass result (single‑chunk / independent dot products).

## Register map

Byte‑addressed, 32‑bit registers. Offsets relative to the block base (Wishbone slave on Caravel).

| Offset | Name | Access | Bits | Description |
|---|---|---|---|---|
| `0x00` | `CTRL` | R/W | `[0] start` (self‑clearing pulse), `[1] acc_clr`, `[2] acc_en`, `[3] auto_start`, `[4] done_clr`, `[5] soft_rst`, `[6] lane_sel` (0=4 lanes, 1=8 lanes) | Control / command |
| `0x04` | `STATUS` | RO | `[0] busy`, `[1] done` (sticky, read‑to‑clear), `[2] acc_ovf`, `[3] act_full` (vector resident) | Status / flags |
| `0x08` | `CONFIG` | R/W | `[0] act_signed`, `[1] wt_signed`, `[2] acc_sat` (0=wrap+flag, 1=saturate) | Static config, latched in `IDLE` |
| `0x0C` | `WEIGHTS0` | R/W | `[7:0]=w0 … [31:24]=w3` | Lanes 0–3 weights (int8, packed) |
| `0x10` | `WEIGHTS1` | R/W | `[7:0]=w4 … [31:24]=w7` | Lanes 4–7 weights (int8, packed) |
| `0x14` | `ACC_OUT` | RO | `[31:0]` | Signed int32 accumulator |
| `0x18` | `ID` | RO | `[31:0]=0x4D414338` ("MAC8") | Version / identification |

Activations are **not** written through the register map in normal operation — they arrive on the serial data plane. (An optional `ACT_PUSH` write‑only register can be added behind a parameter for register‑only bring‑up on platforms without the streaming port.)

## Datapath width

| Stage | Type / width | Rationale |
|---|---|---|
| Activation `a_i`, weight `w_i` | signed int8 (`[7:0]`, two's complement) | Quantized‑ML native precision |
| Product `p_i = a_i · w_i` | signed int16 (`[15:0]`) | 8×8 signed → 16 bits, no loss (`-128 · -128 = 16384` fits) |
| Adder tree sum (of `L=8` products) | signed int20 | `16 + ⌈log2 8⌉ = 19`; carried as 20 bits, no overflow within a pass |
| Accumulator | signed **int32** | Headroom for `K/L` accumulating chunks; overflow detected, not silent |
| Output `ACC_OUT` | signed int32 | Raw pre‑requantization partial sum |

Overflow handling on the accumulator is `CONFIG.acc_sat`: wrap‑and‑flag (`acc_ovf`) by default, or saturate to `±(2³¹−1)`.

## State machine description

Single FSM, one‑hot encoded, clocked on `clk`. Weight writes and `CONFIG` latching happen combinationally through the bus in `IDLE` and are not FSM states.

```
        rst_n
          │
          ▼
     ┌─────────┐  act_valid&act_ready (fill lanes 0..L-1)
     │  IDLE   │◄─────────────────────────────┐
     └────┬────┘                              │
          │ act_full && (start | auto_start)  │
          ▼                                   │
     ┌─────────┐  pipeline stage 1            │
     │  MUL    │  register L products p_i      │
     └────┬────┘                              │
          ▼                                   │
     ┌─────────┐  pipeline stage 2            │
     │  ADACC  │  adder tree + accumulate      │
     └────┬────┘  (acc_en ? acc+sum : sum)     │
          ▼                                   │
     ┌─────────┐  assert done (1 cyc),         │
     │  DONE   │  latch ACC_OUT, set STATUS ───┘
     └─────────┘
```

- **IDLE:** `act_ready=1`; accept serial activations into lane registers, incrementing a lane counter. Set `STATUS.act_full` when `L` beats are resident. Accept weight/config register writes. On `act_full` and (`start` pulse or `auto_start`): latch config, clear `act_ready`, go to `MUL`.
- **MUL:** compute and register all `L` int16 products (pipeline stage 1). → `ADACC`.
- **ADACC:** balanced int16 adder tree sums the `L` products; result is added into the accumulator when `acc_en=1`, else loaded. Evaluate overflow → `acc_ovf`. Register the accumulator (pipeline stage 2). → `DONE`.
- **DONE:** assert `done` for one cycle, set sticky `STATUS.done`, present `ACC_OUT`. Deassert `busy`. → `IDLE`.

`busy` is high in `MUL`/`ADACC`/`DONE`. `lane_sel` gates lanes 4–7 (weights forced to 0 and their products masked) for the 4‑lane mode. FSM properties (no deadlock, exactly one active state, no `done` without a preceding `start`) are asserted in SVA and are formal‑check targets.

## Latency

Cycle counts at `clk`, with weights pre‑loaded:

| Path | Cycles |
|---|---|
| `start` → `done` (activation vector already resident) | **3** (`MUL` → `ADACC` → `DONE`) — pipeline depth 2 + done cycle |
| End‑to‑end per chunk incl. serial fill | `L + 3` (8‑lane: **11**; 4‑lane: **7**), serial‑fill‑dominated |
| Length‑`K` dot product (`M = K/L` chunks, back‑to‑back) | `≈ M·L + 3` when fills overlap prior compute (fill‑bound) |

Compute latency (`start→done`) is fixed and data‑independent — attractive for scheduling.

## Throughput

The engine has two clearly different regimes, and stating both is the point:

- **Peak (compute‑bound, adder tree active):** `L` MACs/cycle. At 8 lanes × 100 MHz = **0.8 GMAC/s ≈ 1.6 GOP/s** (counting multiply + add).
- **Sustained (input‑bound):** the byte‑serial port accepts **1 int8/cycle**, so a new `L`‑element vector takes `L` cycles to load. With weights stationary and fills overlapping compute, sustained throughput is **≈ 1 MAC/cycle ≈ 0.1 GMAC/s** at 100 MHz — the 8‑lane array is provisioned for 8× the rate the serial front end can feed it.

This ~8× imbalance is the central architectural finding, not a bug: it motivates a v0.2 rebalance (wider input port, bit‑parallel weight+activation load, or replicating lanes only when input bandwidth scales with them). It is the kind of provisioning‑vs‑bandwidth tradeoff a real accelerator front end lives or dies on.

## Area target

Sky130 HD standard cells, core logic only (excludes Caravel harness). **Target < 0.05 mm² / ~12–18k cells**, to be confirmed post‑synthesis — treat as an estimate, not a measurement. Basis for the estimate:

- 8× signed 8×8 multipliers dominate combinational area (roughly two‑thirds of the datapath).
- Adder tree (7 int16 adds) + 32‑bit accumulator adder: modest.
- Registers: 8×8 weights + 8×8 activations + 32‑bit accumulator + pipeline + control ≈ 200–250 flops.
- 4‑lane mode is a synthesis/runtime subset, not a separate netlist.

Multiplier count is the first area knob; sharing multipliers across cycles trades area for the throughput the serial port can't use anyway — a defensible v0.2 optimization.

## Timing target

- **100 MHz (10 ns)** at Sky130 SS corner, met via the 2‑stage compute pipeline that isolates `multiply`, `adder‑tree + accumulate` on separate cycles.
- Reported after synthesis and again after place‑and‑route (with SDF back‑annotation); the RTL number is provisional until gate‑level.
- Expected critical path: multiplier → first adder‑tree level (registered at `MUL`/`ADACC` boundary). If it fails closure, the tree is split across an added pipeline stage (latency 3→4), a documented and cheap fallback.

## Test strategy

1. **Golden reference:** a NumPy int8 model computes expected products, tree sums, and accumulator behavior (including wrap/saturate) bit‑exactly.
2. **Directed tests:** all‑zeros; identity/one‑hot weights; both signs; extremes (`±127`, `−128` boundary; `−128·−128`); accumulate across `M` chunks; `acc_clr`/soft‑reset; 4‑lane vs 8‑lane; overflow and saturation boundaries.
3. **Constrained‑random:** randomized activation/weight streams and control sequences checked every `done` against the golden model.
4. **Protocol assertions (SVA):** `act_valid`/`act_ready` stability and no‑combinational‑dependency; `start`→`done` causality (no `done` without `start`); one‑hot/no‑deadlock FSM; `busy` bracketing; `acc_ovf` correctness.
5. **Functional coverage:** cross of lane mode × sign combos × accumulate/clear × overflow/saturate, targeting closure before sign‑off.
6. **Formal (targeted):** FSM safety/liveness and handshake properties (bounded model check).
7. **Gate‑level sim:** post‑synth and post‑PnR netlist with SDF to confirm timing and reset behavior.
8. **FPGA bring‑up:** stream activations over UART, read back `ACC_OUT`, compare to host golden model on hardware.

## Known limitations

- **Input‑bandwidth bound:** byte‑serial front end caps sustained throughput at ~1 MAC/cycle; the 8‑lane array is ~8× underutilized. Primary v0.2 target.
- **No requantization stage:** raw int32 partial sum only — no scale/shift, bias, or activation function (ReLU/clamp). The output needs host‑side dequant to be useful in a full pipeline.
- **No spatial reuse:** a single dot‑product engine, not a systolic/tiled GEMM array. Scaling to matrix multiply requires replication plus a dataflow/scheduler layer.
- **Weight reload cost:** long dot products (`K ≫ L`) reload 8 weights over the register bus per chunk, adding control‑plane overhead not modeled in the peak number.
- **Precision fixed:** symmetric signed int8 only; no per‑channel scales, no int4/fp8, no mixed precision.
- **Elaboration‑time lane count:** 4/8 selectable, but not arbitrary runtime widths; lanes 4–7 are gated, not repurposed.
- **Single clock domain:** no CDC/slow‑serial‑link support in v0.1 by design.
