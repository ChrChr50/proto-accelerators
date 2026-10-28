# MACC-8 design spec: a programmable int8 dot-product engine

**Status:** v0.1
**Author:** Chris Choi Lee
**Covers:** RTL design, accelerator architecture, quantized ML hardware, PPA trade-offs

---

## What it is

MACC-8 is a signed int8 multiply-accumulate engine with 8 lanes (4 if you
want). Activations stream in one byte at a time, weights sit in registers,
there's a start/done handshake, and results build up in a 32-bit
accumulator.

## Goal

I wanted a small quantized-ML block that could actually go to tapeout on an
open shuttle, and that goes through the whole front-end flow: architecture,
parameterized SystemVerilog, verification, and PPA closure. It computes the
basic accelerator operation

$$acc \mathrel{+}= \sum_{i=0}^{L-1} a_i \cdot w_i \qquad L \in \{4, 8\}$$

with `a_i` and `w_i` as signed int8. Each pass handles `L` elements and adds
into the accumulator, so a length-`K` dot product (with `K` a multiple of
`L`) is `K/L` passes. I also wanted something I can walk through in an
interview, so the design leaves the input-bandwidth versus compute
trade-off in plain sight on purpose.

Out of scope for v0.1: requantization, activation functions or bias,
systolic tiling into a GEMM, per-channel scaling, and anything other than
int8. They're listed under *Known limitations* and are the obvious next
steps.

## Platforms

| Stage | Platform | Why |
|---|---|---|
| Bring-up | an inexpensive FPGA board (Lattice, or an Artix-class Xilinx) | check the RTL on hardware against the reference model over UART |
| Main tapeout | **Efabless ChipIgnite / Caravel on SkyWater Sky130** | real silicon PPA; Wishbone for control, logic analyzer for probing |
| Backup tapeout | **TinyTapeout** (Sky130) | a smaller, standard slot if area or pins get tight |

The RTL doesn't depend on the PDK and is parameterized, so the same source
works for all three. Caravel is the main target because its Wishbone bus
lines up neatly with the register interface below.

## Clock

- One clock, `clk`. **The target is 100 MHz (10 ns)** at the Sky130 slow
  corner (SS, 1.60 V, 125 °C) after synthesis. An FPGA hits that easily;
  for silicon it's a target until gate-level numbers confirm it.
- The activation port and the register bus both run on `clk`. There are no
  clock crossings in v0.1. That's a conscious scope cut: CDC only becomes a
  concern if a slower serial link gets added later.
- The longest path is multiplier, adder tree, accumulator adder. Pipeline
  registers split it (see *State machine*) so no single cycle has to cover
  the whole MAC.

## Reset

- `rst_n` is active low, **asserted asynchronously and released
  synchronously** through a two-flop synchronizer, the usual arrangement on
  Sky130 and Caravel.
- Reset puts everything in a known state:
  - FSM in `IDLE`
  - accumulator at 0
  - weight registers at 0 (so simulation and silicon agree, instead of
    starting at `X`)
  - activation registers and lane counter at 0
  - `busy`, `done` and `acc_ovf` low; `busy` and `done` are outputs and are
    guaranteed low coming out of reset
- `CTRL.soft_rst` clears the accumulator, the overflow flag and the sticky
  done flag but leaves the weights and mode bits alone, so a new dot product
  can start without a full reset.

## Inputs

There are two independent ways data gets in.

**1. Activations: a byte-wide valid/ready stream.**
Each accepted beat carries one signed int8 activation.

| Signal | Dir | Width | Meaning |
|---|---|---|---|
| `act_data` | in | 8 | signed int8 activation |
| `act_valid` | in | 1 | driven high by the sender when `act_data` is valid |
| `act_ready` | out | 1 | driven high by the engine when it can take a beat |

- A byte transfers on any cycle with `act_valid && act_ready`. It's the
  usual AMBA-style rule: `act_valid` must not depend combinationally on
  `act_ready`, and once `act_valid` is up, it and `act_data` hold until the
  beat is taken.
- Bytes fill lanes `0..L-1` in order. Once lane `L-1` is filled, the engine
  either starts a pass on its own (`CTRL.auto_start=1`) or waits for
  `start`.

**2. Control and weights: register writes (Wishbone on Caravel).**
Weights and control go through the register map below. The weights are
*stationary*: write them once and they're reused for every activation pass
until you write new ones.

**Start and done.** `start` is a one-cycle strobe from writing `CTRL.start`.
It's ignored unless the FSM is in `IDLE` and a full activation vector is
loaded. `busy` stays high for the whole pass and `done` pulses for one cycle
at the end. The sticky `STATUS.done` bit gets set as well; reading it
doesn't clear it, only writing `CTRL.done_clr` or `CTRL.soft_rst` does.

## Outputs

- **Main result:** the 32-bit signed accumulator at `ACC_OUT`. It's valid and
  steady any time `busy=0`. It doesn't reset between passes, because adding
  up chunks is the whole idea; clear it with `CTRL.acc_clr` or soft reset.
- **Handshake:** the one-cycle `done` pulse marks the end of each pass, and
  a consumer can grab `ACC_OUT` then. `STATUS.acc_ovf` reports signed
  overflow of the accumulator (see *Datapath widths*).
- `CTRL.acc_en` picks accumulate or overwrite: with `1` the pass result is
  added to the running total, with `0` it replaces it (for single-chunk or
  independent dot products).

## Register map

32-bit registers at byte offsets from the block base (a Wishbone slave on
Caravel).

| Offset | Name | Access | Bits | Purpose |
|---|---|---|---|---|
| `0x00` | `CTRL` | R/W | `[0] start` (strobe), `[1] acc_clr` (strobe), `[2] acc_en`, `[3] auto_start`, `[4] done_clr` (strobe), `[5] soft_rst` (strobe), `[6] lane_sel` (0 = 4 lanes, 1 = 8) | control and commands; strobe bits read back as 0 |
| `0x04` | `STATUS` | RO | `[0] busy`, `[1] done` (sticky), `[2] acc_ovf` | status flags |
| `0x08` | `CONFIG` | R/W | `[0] act_signed`, `[1] wt_signed` (both stored only, no effect in v0.1), `[2] acc_sat` (0 = wrap and flag, 1 = saturate) | configuration; takes effect on write, so change it only while idle |
| `0x0C` | `WEIGHTS0` | R/W | `[7:0]=w0 … [31:24]=w3` | weights for lanes 0-3, packed int8 |
| `0x10` | `WEIGHTS1` | R/W | `[7:0]=w4 … [31:24]=w7` | weights for lanes 4-7, packed int8 |
| `0x14` | `ACC_OUT` | RO | `[31:0]` | signed int32 accumulator |
| `0x18` | `ID` | RO | `[31:0]=0x4D414338` ("MAC8") | identification |

Reads are registered (one cycle of latency) and have no side effects.
Unmapped addresses read as 0 and ignore writes.

Activations don't normally go through the register map; they come in on the
serial port. If a platform has no streaming port, a write-only `ACT_PUSH`
register could be added behind a parameter for register-only bring-up.

## Datapath widths

| Where | Type | Why |
|---|---|---|
| activation `a_i`, weight `w_i` | signed int8 | the native precision for quantized ML |
| product `p_i = a_i · w_i` | signed int16 | 8 × 8 signed is exactly 16 bits (`-128 · -128 = 16384` fits) |
| adder tree sum of 8 products | signed int20 | needs `16 + log2(8) = 19` bits, rounded up to 20; can't overflow within a pass |
| accumulator | signed **int32** | room for `K/L` passes; overflow is caught, not silent |
| `ACC_OUT` | signed int32 | the raw partial sum, before any requantization |

`CONFIG.acc_sat` controls accumulator overflow: wrap and set `acc_ovf` (the
default), or clamp to `2^31 - 1` / `-2^31`.

## State machine

One FSM on `clk` with a 2-bit binary state encoding. Register writes
(weights, config) are just bus writes; they aren't FSM states.

```
          rst_n
            |
            v
       +---------+   act_valid & act_ready: fill lanes 0..L-1
       |  IDLE   |<-------------------------------------+
       +----+----+                                      |
            | act_full && (start || auto_start)         |
            v                                           |
       +---------+   pipeline stage 1:                  |
       |   MUL   |   register the L products            |
       +----+----+                                      |
            v                                           |
       +---------+   pipeline stage 2: adder tree,      |
       |  ADACC  |   then acc_en ? acc + sum : sum      |
       +----+----+                                      |
            v                                           |
       +---------+   done high for one cycle,           |
       |  DONE   |   STATUS.done set                    |
       +----+----+                                      |
            +-------------------------------------------+
```

- **IDLE:** `act_ready` is high. Incoming bytes go into the lane registers
  and bump a counter; `act_full` goes high once `L` are in. Register writes
  are accepted. When `act_full` is set and there's a `start` (or
  `auto_start` is on), drop `act_ready` and go to MUL.
- **MUL:** compute all `L` int16 products and register them (stage 1), then
  go to ADACC.
- **ADACC:** the adder tree sums the products, and the sum is added to the
  accumulator (`acc_en=1`) or replaces it (`acc_en=0`). Check overflow,
  update `acc_ovf`, register the accumulator (stage 2), go to DONE.
- **DONE:** raise `done` for one cycle and set `STATUS.done`; `ACC_OUT`
  holds the new value. Go back to IDLE, where `busy` falls.

`busy` is high in MUL, ADACC and DONE. In 4-lane mode (`lane_sel=0`) the
products of lanes 4-7 are forced to zero. The FSM's safety properties (no
deadlock, fixed state sequence, no `done` without a `start`) are proven with
SymbiYosys; see `docs/formal_and_pd.md`.

## Latency

In `clk` cycles, with the weights already written:

| Path | Cycles |
|---|---|
| `start` to `done`, vector already loaded | **3** (MUL, ADACC, DONE): two pipeline stages plus the done cycle |
| one chunk end to end, including the fill (`auto_start=1`) | `L + 4` (**12** with 8 lanes, **8** with 4): `L` fill beats, 1 IDLE decision cycle, 3 compute |
| length-`K` dot product, `M = K/L` chunks back to back | `M·(L + 4)`; fill and compute **take turns**, they don't overlap (see below) |

Why `L + 4` and not `L + 3`: `act_full` comes from the registered lane
counter, so it shows up the cycle *after* the last byte is accepted, and
`go` is evaluated in that IDLE cycle. Why no overlap: v0.1 has only one
activation buffer, and `act_ready = accept_en & ~act_full` where `accept_en`
is only high in IDLE, so the next vector can't start loading until the
current pass is back in IDLE. Overlapping them needs a second (ping-pong)
buffer, which is planned for v0.2. If you use `CTRL.start` instead of
`auto_start`, add the bus write latency on top.

The compute part (`start` to `done`) is fixed and doesn't depend on the
data, which is nice for scheduling.

## Throughput

There are two very different numbers here, and the point is to state both.

- **Peak (compute-bound):** `L` MACs per cycle. With 8 lanes at 100 MHz
  that's **0.8 GMAC/s, about 1.6 GOP/s** counting each multiply and add.
- **Sustained (input-bound), v0.1 as built:** the serial port takes **one
  byte per cycle**, so loading an `L`-element vector takes `L` cycles, and
  with fill and compute taking turns each chunk costs `L + 4` cycles.
  That's `L/(L+4)`: **about 0.67 MAC/cycle (67 MMAC/s)** with 8 lanes and
  **0.5 MAC/cycle** with 4, at 100 MHz. The 8-lane array could go about 12×
  faster than the input lets it.
- **The ceiling:** one activation per cycle means nothing behind this port
  can ever do more than **one MAC per cycle**. Getting there needs fill and
  compute to overlap (the ping-pong buffer), so v0.1 is leaving about a
  third of even the serial bandwidth unused.

This roughly 8× mismatch is the main architectural takeaway, and it's
intentional. It's what v0.2 is for: a wider input port, loading weights and
activations in parallel, or only adding lanes when input bandwidth grows
with them. Real accelerator front ends live or die on exactly this
provisioning-versus-bandwidth balance.

## Area target

Sky130 HD cells, core logic only (no Caravel harness). **Target: under
0.05 mm², about 12-18k cells.** This is an estimate until synthesis says
otherwise. Where it comes from:

- the 8 signed 8×8 multipliers dominate, at roughly two thirds of the
  datapath logic
- the adder tree (7 int16 adds) and 32-bit accumulator adder are small by
  comparison
- registers: 8×8 weights, 8×8 activations, the 32-bit accumulator, the
  pipeline and control, around 200-250 flops by the original estimate (the
  first Yosys run counted 336, see `docs/synthesis_summary.md`)
- 4-lane mode uses the same netlist; it isn't a separate build

The multiplier count is the first thing to turn down for area. Sharing
multipliers across cycles gives up throughput the serial port can't use
anyway, which makes it an easy v0.2 optimization to defend.

## Timing target

- **100 MHz (10 ns)** at the Sky130 SS corner, made possible by the two-stage
  pipeline that puts the multiply on one cycle and the adder tree plus
  accumulate on the next.
- Measured after synthesis and again after place and route (with SDF back
  annotation). Anything from RTL alone is provisional.
- The expected critical path is the adder tree plus accumulate after the
  MUL/ADACC register. If it doesn't close, split the tree with one more
  pipeline stage (latency 3 to 4). That's a cheap, known fallback.

## Test plan

1. **Reference model:** a Python model predicts products, tree sums and the
   accumulator (including wrap and saturate) bit for bit.
2. **Directed tests:** all zeros; identity and one-hot weights; both signs;
   extremes (`±127`, `-128`, `-128 · -128`); accumulating over `M` chunks;
   `acc_clr` and soft reset; 4 vs 8 lanes; overflow and saturation edges.
3. **Random tests:** random activations, weights and control, checked
   against the model after every `done`.
4. **Protocol checks:** valid/ready stability with no combinational loop
   between them; `done` only after a `start`; FSM never deadlocks; `busy`
   brackets every pass; `acc_ovf` is correct.
5. **Functional coverage:** lane mode × sign mix × accumulate/clear ×
   overflow/saturate, closed before signoff.
6. **Formal:** FSM and handshake properties, proven by k-induction.
7. **Gate-level sim:** post-synthesis and post-route netlists with SDF, to
   check timing and reset.
8. **FPGA bring-up:** stream activations over UART, read back `ACC_OUT`, and
   compare with the model on the host.

## Known limitations

- **Bound by input bandwidth.** The serial port caps sustained throughput at
  one MAC per cycle, and because v0.1 has a single activation buffer it only
  reaches `L/(L+4)`, about 0.67, in 8-lane mode. The 8-lane array sits idle
  about 92% of the time. This is the main thing to fix in v0.2.
- **No requantization.** Output is the raw int32 partial sum: no scale or
  shift, no bias, no ReLU or clamp. The host has to dequantize before it's
  useful in a real pipeline.
- **No spatial reuse.** It's one dot-product engine, not a systolic or tiled
  GEMM array. Matrix multiply would need many copies plus a dataflow and
  scheduling layer.
- **Weight reloads cost time.** For long dot products (`K` much larger than
  `L`), each chunk reloads 8 weights over the register bus, and that
  overhead isn't in the peak number.
- **Fixed precision.** Symmetric signed int8 only: no per-channel scales, no
  int4 or fp8, no mixed precision. The `act_signed`/`wt_signed` bits are
  placeholders.
- **Lane count is 4 or 8.** You can't pick an arbitrary width at runtime,
  and in 4-lane mode lanes 4-7 just sit idle.
- **One clock domain.** No CDC or slow serial link in v0.1, by design.
