# MACC-8 block diagram and microarchitecture

This goes with `int8_mac_design_spec.md`. It covers bit widths, signedness,
overflow, latency, and why the activation input is serial and what that
costs in throughput.

---

## 1. Datapath

```mermaid
flowchart TD
    ACT["act_data<br/>int8 [7:0]<br/>valid/ready, one byte per cycle"]:::in
    WB["register writes<br/>WEIGHTS0 / WEIGHTS1"]:::in

    ASR["activation registers<br/>8 x int8<br/>filled from lane 0 up"]:::reg
    WREG["weight registers<br/>8 x int8, reused across passes"]:::reg

    ACT --> ASR
    WB --> WREG

    subgraph MUL["MUL stage (pipeline reg 1)"]
        M0["a_i * w_i<br/>int8 x int8 = int16<br/>signed"]
    end
    ASR -->|"8 x int8"| M0
    WREG -->|"8 x int8"| M0
    M0 -->|"8 x int16<br/>(-128)(-128) = 16384 fits"| PREG["product registers<br/>8 x int16"]:::reg

    subgraph ADACC["ADACC stage (pipeline reg 2)"]
        TREE["adder tree<br/>8 x int16 summed into int20"]
        ACCADD["accumulate<br/>acc_en ? acc + sum : sum<br/>int20 sign-extended to int32"]
        OVF["overflow handling<br/>acc_sat ? clamp<br/>: wrap and set acc_ovf"]
    end
    PREG -->|"8 x int16"| TREE
    TREE -->|"int20"| ACCADD
    ACC["accumulator<br/>int32 [31:0]"]:::reg
    ACCADD --> OVF
    OVF --> ACC
    ACC -->|"fed back when acc_en=1"| ACCADD

    ACC -->|"int32"| OUT["ACC_OUT [31:0]<br/>stable whenever busy=0"]:::out

    classDef in fill:#e8f0ff,stroke:#3b6fb0,color:#12263a;
    classDef reg fill:#eef7ee,stroke:#4a8f4a,color:#12341a;
    classDef out fill:#fff2e6,stroke:#c07a2c,color:#3a2612;
```

**Signed arithmetic.** Everything is two's complement. An int8 times an int8
always fits in int16; the worst case, -128 × -128 = 16384, has plenty of
room. The adder tree sign-extends each product and works in 20 bits, so
eight products can't overflow inside a pass (8 × 2^15 is less than 2^19).
The tree output is then sign-extended to 32 bits for the accumulator. The
datapath is signed × signed only. `CONFIG.act_signed` and `wt_signed` can be
written and read back, but in v0.1 they don't change anything.

**Overflow and saturation.** The only place overflow can happen is the
int32 accumulator, after many accumulating passes. `CONFIG.acc_sat` picks
what happens:

```mermaid
flowchart LR
    S["accumulate result<br/>(computed in 33 bits)"] --> D{"acc_sat?"}
    D -->|"1: saturate"| SAT["clamp to<br/>2^31 - 1 or -2^31<br/>acc_ovf unchanged"]
    D -->|"0: wrap"| WRAP["keep the low 32 bits<br/>acc_ovf = 1, stays set"]
    SAT --> R["ACC_OUT"]
    WRAP --> R
```

The add is done in 33 bits only so the signed carry-out can be seen. What
gets stored is always 32 bits.

---

## 2. Control FSM and latency

```mermaid
stateDiagram-v2
    [*] --> IDLE : rst_n (async assert, sync release)

    IDLE --> IDLE : act_valid & act_ready<br/>store byte, bump lane count<br/>(register writes allowed)
    IDLE --> MUL : act_full & (start | auto_start)<br/>act_ready drops

    MUL --> ADACC : 8 products registered
    ADACC --> DONE : tree + accumulate<br/>overflow handled
    DONE --> IDLE : done high for 1 cycle<br/>STATUS.done set

    note right of IDLE
        busy = 0, act_ready = 1
        takes one byte per cycle
    end note
    note right of ADACC
        busy = 1 through MUL, ADACC, DONE
        2-bit binary state, proven deadlock-free
    end note
```

**Latency** in `clk` cycles, assuming the weights are already loaded:

```mermaid
flowchart LR
    subgraph FILL["serial fill"]
        F["L bytes<br/>8 cycles (or 4)"]
    end
    subgraph DECIDE["IDLE check"]
        G["act_full seen,<br/>go decided<br/>1 cycle"]
    end
    subgraph COMPUTE["compute, always the same"]
        C1["MUL<br/>1"] --> C2["ADACC<br/>1"] --> C3["DONE<br/>1"]
    end
    FILL --> DECIDE --> COMPUTE
    COMPUTE -->|"next fill waits for IDLE<br/>(one activation buffer)"| FILL
```

| Operation | Cycles |
|---|---|
| `start` to `done`, vector already loaded | **3** (MUL, ADACC, DONE) |
| one chunk including the fill, `auto_start=1` | `L + 4`: **12** with 8 lanes, **8** with 4 |
| length-`K` dot product, `M = K/L` chunks in a row | `M·(L + 4)`, since fill and compute don't overlap |

Compute time never depends on the data, which makes scheduling easy. The
total is dominated by the `L`-cycle fill, which is what the next two
sections are about. The extra cycle in `L + 4` is the IDLE cycle where the
FSM first sees the registered `act_full`. Fill and compute can't overlap
because `act_ready` is only high in IDLE and there's a single activation
buffer (`rtl/macc8_serial_rx.sv`).

---

## 3. Why the input is serial

A parallel port would take all `L` activations (and maybe the weights) in
one cycle. I went with one byte at a time instead, for these reasons:

- **Pins.** A parallel 8-lane activation port is 64 data pins plus
  handshake. On Caravel or TinyTapeout, GPIO is the thing you run out of
  first. The serial port needs about 10 pins (8 data plus valid/ready). For
  a shuttle tapeout, pins are the limiting resource, not gates.
- **It's how real accelerators behave.** Production engines are rarely
  short on multipliers; they're short on operand bandwidth from memory or
  the NoC. A serial front end puts that bottleneck in plain view in a small
  design, which makes it easy to measure and talk about.
- **A real handshake to verify.** valid/ready means real back-pressure,
  stalls, and protocol properties to prove, which carry over to other
  blocks.
- **Weights stay put.** Weights are written through registers and reused,
  so only activations stream in. The serial cost is paid once per
  activation vector, not once per MAC.

The price is lower sustained throughput. The next section puts numbers on
it, and fixing it is the main goal for v0.2.

```mermaid
flowchart TD
    P["parallel input"] --> P1["+ can feed 8 MAC/cycle"]
    P --> P2["- 64+ I/O pins, too many for a shuttle"]
    P --> P3["- hides the bandwidth limit"]
    SER["serial input (used here)"] --> S1["+ about 10 pins"]
    SER --> S2["+ shows the bandwidth vs compute trade-off"]
    SER --> S3["+ valid/ready back-pressure to verify"]
    SER --> S4["- at most 1 MAC/cycle sustained;<br/>v0.1 gets 0.67 (fill and compute serialized)"]
```

---

## 4. Area versus throughput

The 8-lane array can do 8 MACs per cycle, but the serial port delivers at
most one byte per cycle, so at most one MAC per cycle. v0.1 only gets
`L/(L+4)`, about 0.67, because filling and computing take turns. In steady
state roughly 11 out of every 12 multiplier-cycles do nothing useful.

```mermaid
flowchart LR
    subgraph V01["v0.1 as built"]
        A1["8 int8 multipliers<br/>about 2/3 of datapath area"]
        A2["peak 8 MAC/cycle"]
        A3["sustained 0.67 MAC/cycle<br/>(input-bound, fill and compute serialized)"]
        A1 --> A2 --> A3
    end
```

| Option | Multipliers | Peak MAC/cycle | Sustained MAC/cycle | Area | Utilization |
|---|---|---|---|---|---|
| 8 lanes (v0.1) | 8 | 8 | 0.67 (8/12) | high | ~8% |
| 4 lanes (`lane_sel=0`, v0.1) | 4 used | 4 | 0.5 (4/8) | high (same netlist, lanes 4-7 masked, still there) | ~12% |
| 8 lanes + ping-pong activation buffer (v0.2) | 8 | 8 | ~1 | high + 64 flops | ~12% |
| **one shared multiplier (v0.2)** | 1 | 1 | ~1 (MAC as each byte arrives) | **low** | **~100%** |
| wider input + 8 lanes + ping-pong (v0.2) | 8 | 8 | ~8 | high, plus pins | ~100% |

**What the table says.** With one byte per cycle coming in, paying for 8
multipliers buys a peak number you can never sustain. There are two sensible
ways out:

1. **Shrink the compute to match the input.** Time-share 1 or 2 multipliers
   across the 8 lanes. Throughput stays around 1 MAC/cycle, utilization goes
   to nearly 100%, and multiplier area drops by about 8×. This is the most
   area-efficient option for this input width.
2. **Widen the input to match the compute.** A multi-byte port, or loading
   weights and activations in parallel, pushes sustained throughput toward 8
   MAC/cycle, and then the 8 multipliers pay for themselves. This is the
   fastest option, at the pin and area cost from section 3.

For sustained work, v0.1's 8 parallel lanes are the worst choice on this
list. I built it that way to make the trade-off concrete, and to have the
full multiplier array and adder tree in the RTL and the tests. The design is
parameterized (`LANES` now, a `MUL_SHARE` factor planned), so every row
above is meant to be the same source code with different parameters. That
way PPA becomes a setting you change, not a rewrite.
