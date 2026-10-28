"""Test environment for MACC-8.

Loosely follows the UVM split, just in Python:

  wr / rd        register bus driver
  send           activation stream driver (valid/ready)
  wait_done      monitor for the done pulse
  check_*        scoreboard against Macc8Model

Inputs are changed on the falling edge and the DUT samples on the rising
edge, so there are no races between the testbench and the RTL. Runs on
cocotb 1.9 or 2.x, under Verilator or Icarus.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, ClockCycles

from macc8_ref import Macc8Model, s8, to_int32, INT32_MAX, INT32_MIN, ID_VALUE

CTRL, STATUS, CONFIG, W0, W1, ACC, IDR = 0x00, 0x04, 0x08, 0x0C, 0x10, 0x14, 0x18


def ctrl_word(start=0, acc_clr=0, acc_en=0, auto=0, done_clr=0, soft=0, lane8=1):
    return ((start & 1) | (acc_clr << 1) | (acc_en << 2) | (auto << 3)
            | (done_clr << 4) | (soft << 5) | (lane8 << 6))


def pack4(bytes4):
    return sum((b & 0xFF) << (8 * i) for i, b in enumerate(bytes4))


class Macc8Env:
    def __init__(self, dut):
        self.dut = dut
        self.model = Macc8Model()
        self._forget_mode()

    def _forget_mode(self):
        # CTRL is one register holding both strobes and sticky mode bits, so
        # every write has to resend the current mode or it gets clobbered.
        self._lane8, self._acc_en, self._auto, self._acc_sat = 1, 0, 0, 0

    def _lanes(self):
        return 8 if self._lane8 else 4

    def start_clock(self):
        try:
            clock = Clock(self.dut.clk, 10, units="ns")  # cocotb 1.x
        except TypeError:
            clock = Clock(self.dut.clk, 10, unit="ns")   # cocotb 2.x
        cocotb.start_soon(clock.start())

    async def reset(self):
        dut = self.dut
        dut.rst_n.value = 0
        dut.reg_addr.value = 0
        dut.reg_wdata.value = 0
        dut.reg_write.value = 0
        dut.act_data.value = 0
        dut.act_valid.value = 0
        await ClockCycles(dut.clk, 5)
        await self._release_reset()

    async def pulse_reset_mid_op(self, cycles_before_release=2):
        """Drop rst_n while something is in flight, then let it go again."""
        self.dut.rst_n.value = 0
        await ClockCycles(self.dut.clk, cycles_before_release)
        await self._release_reset()

    async def _release_reset(self):
        await FallingEdge(self.dut.clk)
        self.dut.rst_n.value = 1
        # two cycles for the reset synchronizer plus one spare
        await ClockCycles(self.dut.clk, 3)
        self.model.reset()
        self._forget_mode()

    async def wr(self, addr, data):
        dut = self.dut
        await FallingEdge(dut.clk)
        dut.reg_addr.value = addr
        dut.reg_wdata.value = data & 0xFFFFFFFF
        dut.reg_write.value = 1
        await FallingEdge(dut.clk)
        dut.reg_write.value = 0

    async def rd(self, addr):
        dut = self.dut
        await FallingEdge(dut.clk)
        dut.reg_addr.value = addr
        await FallingEdge(dut.clk)  # read data is registered: one edge to load it
        await FallingEdge(dut.clk)
        return int(dut.reg_rdata.value)

    async def send(self, acts):
        dut = self.dut
        for a in acts:
            while int(dut.act_ready.value) != 1:
                await FallingEdge(dut.clk)
            dut.act_data.value = a & 0xFF
            dut.act_valid.value = 1
            await FallingEdge(dut.clk)
        dut.act_valid.value = 0

    async def wait_done(self, timeout=500):
        for _ in range(timeout):
            await RisingEdge(self.dut.clk)
            if int(self.dut.done.value) == 1:
                return True
        raise TimeoutError(f"no done pulse after {timeout} cycles")

    async def set_weights(self, wl):
        await self.wr(W0, pack4(wl[:4]))
        await self.wr(W1, pack4(wl[4:8]))
        self.model.set_weights_list(wl)

    async def set_mode(self, lane8=1, acc_en=0, acc_sat=0, auto=0):
        self._lane8, self._acc_en, self._auto, self._acc_sat = lane8, acc_en, auto, acc_sat
        await self.wr(CONFIG, acc_sat << 2)
        await self.wr(CTRL, ctrl_word(lane8=lane8, acc_en=acc_en, auto=auto))
        self.model.set_mode(lane_sel=lane8, acc_en=acc_en, acc_sat=acc_sat, auto_start=auto)

    async def _ctrl_strobe(self, **bits):
        await self.wr(CTRL, ctrl_word(lane8=self._lane8, acc_en=self._acc_en,
                                      auto=self._auto, **bits))

    async def clear_acc(self):
        await self._ctrl_strobe(acc_clr=1)
        self.model.clear_acc()

    async def start(self):
        await self._ctrl_strobe(start=1)

    async def _finish_pass(self, acts, check, label):
        await self.wait_done()
        self.model.dot(acts)
        if check:
            await self.check_acc(context=f"{label}{list(acts[:self._lanes()])}")
        return self.model.acc

    async def run_pass(self, acts, check=True):
        """Load a vector, kick it off with CTRL.start, and check the result."""
        await self.send(acts[:self._lanes()])
        await self.start()
        return await self._finish_pass(acts, check, "acts=")

    async def run_pass_expl(self, acts, check=True):
        return await self.run_pass(acts, check=check)

    async def run_pass_auto(self, acts, check=True):
        """Same as run_pass, but relies on auto_start instead of a start write."""
        await self.send(acts[:self._lanes()])
        return await self._finish_pass(acts, check, "auto acts=")

    async def check_acc(self, context=""):
        got = to_int32(await self.rd(ACC))
        want = self.model.acc
        assert got == want, f"ACC is {got}, model says {want} [{context}]"

    async def check_ovf(self, expected):
        flag = ((await self.rd(STATUS)) >> 2) & 1
        assert flag == expected, f"overflow flag is {flag}, expected {expected}"

    async def check_status(self, busy=0):
        status = await self.rd(STATUS)
        assert (status & 1) == busy, f"busy is {status & 1}, expected {busy}"
        assert ((status >> 1) & 1) == self.model.done_sticky, "done flag differs from model"
        assert ((status >> 2) & 1) == self.model.ovf, "overflow flag differs from model"
