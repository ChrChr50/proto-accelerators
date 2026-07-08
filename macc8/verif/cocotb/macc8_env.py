"""
macc8_env.py — UVM-shaped cocotb environment for MACC-8.

Roles (UVM analogues):
  RegBusDriver   -> sequencer/driver for the synchronous register bus
  ActStreamDriver-> driver for the byte-serial valid/ready activation port
  DoneMonitor    -> monitor that observes the done pulse / busy level
  Macc8Env       -> env: owns the golden model + high-level sequences + scoreboard

All bus activity is driven and sampled on the falling edge of clk so that it is
race-free with respect to the DUT's rising-edge sampling (mirrors the RTL smoke TB).
Targets cocotb 2.x + Verilator (SIM=verilator); works under Icarus too.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles

from macc8_ref import Macc8Model, s8, to_int32, INT32_MAX, INT32_MIN, ID_VALUE

# ---- register map -------------------------------------------------------
CTRL, STATUS, CONFIG, W0, W1, ACC, IDR = 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18


def ctrl_word(start=0, acc_clr=0, acc_en=0, auto=0, done_clr=0, soft=0, lane8=1):
    return ((start & 1) | (acc_clr << 1) | (acc_en << 2) | (auto << 3)
            | (done_clr << 4) | (soft << 5) | (lane8 << 6))


class Macc8Env:
    def __init__(self, dut):
        self.dut = dut
        self.model = Macc8Model()
        # persistent CTRL/CONFIG bits mirrored so every CTRL write preserves them
        self._lane8 = 1
        self._acc_en = 0
        self._auto = 0
        self._acc_sat = 0

    # ---- clock / reset --------------------------------------------------
    def start_clock(self):
        # cocotb 1.x uses units=, cocotb 2.x uses unit=
        try:
            clk = Clock(self.dut.clk, 10, units="ns")
        except TypeError:
            clk = Clock(self.dut.clk, 10, unit="ns")
        cocotb.start_soon(clk.start())

    async def reset(self):
        d = self.dut
        d.rst_n.value = 0
        d.reg_addr.value = 0
        d.reg_wdata.value = 0
        d.reg_write.value = 0
        d.act_data.value = 0
        d.act_valid.value = 0
        await ClockCycles(d.clk, 5)
        await FallingEdge(d.clk)
        d.rst_n.value = 1
        await ClockCycles(d.clk, 3)
        self.model.reset()
        self._lane8, self._acc_en, self._auto, self._acc_sat = 1, 0, 0, 0

    async def pulse_reset_mid_op(self, cycles_before_release=2):
        """Assert reset asynchronously for a few cycles, then release (sync deassert)."""
        d = self.dut
        d.rst_n.value = 0
        await ClockCycles(d.clk, cycles_before_release)
        await FallingEdge(d.clk)
        d.rst_n.value = 1
        await ClockCycles(d.clk, 3)
        self.model.reset()
        self._lane8, self._acc_en, self._auto, self._acc_sat = 1, 0, 0, 0

    # ---- register bus ---------------------------------------------------
    async def wr(self, addr, data):
        d = self.dut
        await FallingEdge(d.clk)
        d.reg_addr.value = addr
        d.reg_wdata.value = data & 0xFFFFFFFF
        d.reg_write.value = 1
        await FallingEdge(d.clk)
        d.reg_write.value = 0

    async def rd(self, addr):
        d = self.dut
        await FallingEdge(d.clk)
        d.reg_addr.value = addr
        await FallingEdge(d.clk)   # rising edge in between latches rdata_c -> reg_rdata
        await FallingEdge(d.clk)   # stable
        return int(d.reg_rdata.value)

    # ---- activation stream ---------------------------------------------
    async def send(self, acts):
        d = self.dut
        for a in acts:
            # wait (pre-posedge) until the engine can accept, then present one beat
            while int(d.act_ready.value) != 1:
                await FallingEdge(d.clk)
            d.act_data.value = a & 0xFF
            d.act_valid.value = 1
            await FallingEdge(d.clk)   # one rising edge accepts this beat
        d.act_valid.value = 0

    # ---- monitor --------------------------------------------------------
    async def wait_done(self, timeout=500):
        d = self.dut
        for _ in range(timeout):
            await RisingEdge(d.clk)
            if int(d.done.value) == 1:
                return True
        raise TimeoutError("done not observed within timeout")

    # ---- high-level sequences ------------------------------------------
    async def set_weights(self, wl):
        w0 = sum((wl[i] & 0xFF) << (8 * i) for i in range(4))
        w1 = sum((wl[4 + i] & 0xFF) << (8 * i) for i in range(4))
        await self.wr(W0, w0)
        await self.wr(W1, w1)
        self.model.set_weights_list(wl)

    async def set_mode(self, lane8=1, acc_en=0, acc_sat=0, auto=0):
        self._lane8, self._acc_en, self._auto, self._acc_sat = lane8, acc_en, auto, acc_sat
        await self.wr(CONFIG, (acc_sat << 2))
        # push persistent CTRL bits (no pulse) so lane_sel/acc_en/auto take effect
        await self.wr(CTRL, ctrl_word(lane8=lane8, acc_en=acc_en, auto=auto))
        self.model.set_mode(lane_sel=lane8, acc_en=acc_en, acc_sat=acc_sat, auto_start=auto)

    async def clear_acc(self):
        await self.wr(CTRL, ctrl_word(acc_clr=1, lane8=self._lane8,
                                      acc_en=self._acc_en, auto=self._auto))
        self.model.clear_acc()

    async def start(self):
        await self.wr(CTRL, ctrl_word(start=1, lane8=self._lane8,
                                      acc_en=self._acc_en, auto=self._auto))

    async def run_pass(self, acts, check=True):
        """Send activations, start, wait for done, update model, optionally scoreboard."""
        n = 8 if self._lane8 else 4
        await self.send(acts[:n])
        await self.start()
        await self.wait_done()
        self.model.dot(acts)
        if check:
            await self.check_acc(context=f"acts={list(acts[:n])}")
        return self.model.acc

    # explicit-start pass (alias used by the test suite for clarity)
    async def run_pass_expl(self, acts, check=True):
        return await self.run_pass(acts, check=check)

    async def run_pass_auto(self, acts, check=True):
        """auto_start mode: full vector fires a pass without an explicit start write."""
        n = 8 if self._lane8 else 4
        await self.send(acts[:n])
        await self.wait_done()
        self.model.dot(acts)
        if check:
            await self.check_acc(context=f"auto acts={list(acts[:n])}")
        return self.model.acc

    # ---- scoreboard checks ---------------------------------------------
    async def check_acc(self, context=""):
        got = to_int32(await self.rd(ACC))
        exp = self.model.acc
        assert got == exp, f"ACC mismatch: got {got} exp {exp} [{context}]"

    async def check_ovf(self, expected):
        st = await self.rd(STATUS)
        got = (st >> 2) & 1
        assert got == expected, f"OVF flag mismatch: got {got} exp {expected}"

    async def check_status(self, busy=0):
        st = await self.rd(STATUS)
        assert (st & 1) == busy, f"busy mismatch: got {st & 1} exp {busy}"
        assert ((st >> 1) & 1) == self.model.done_sticky, "done_sticky mismatch"
        assert ((st >> 2) & 1) == self.model.ovf, "ovf mismatch"
