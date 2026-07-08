"""
test_macc8.py — cocotb regression for MACC-8.

Groups:
  basic     : reset, one known dot product, all-zero, all-positive, mixed-sign
  corner    : max +int8, max -int8, overflow boundary (wrap + saturate),
              repeated ops, back-to-back (auto_start), invalid commands
  random    : 1000+ random vectors checked against the golden model
  protocol  : start-before-load, read-before-done, reset-during-operation
  model     : pure-model boundary self-check (fast, no DUT)

Every DUT result is scoreboarded against macc8_ref.Macc8Model.
Set env MACC8_FAST=1 to shrink the (slow) accumulate-to-overflow loops for
quick local iteration; the default runs the true int32 crossing in hardware.
"""

import os
import random

import cocotb
from cocotb.triggers import RisingEdge

from macc8_env import Macc8Env, CTRL, STATUS, CONFIG, ACC, IDR, ctrl_word
from macc8_ref import (Macc8Model, s8, to_int32, INT8_MAX, INT8_MIN,
                       INT32_MAX, INT32_MIN, ID_VALUE)

FAST = os.environ.get("MACC8_FAST", "0") == "1"


async def _bringup(dut):
    env = Macc8Env(dut)
    env.start_clock()
    await env.reset()
    return env


# =========================================================================
# BASIC
# =========================================================================
@cocotb.test()
async def test_reset_behavior(dut):
    env = await _bringup(dut)
    # after reset: acc = 0, not busy, done sticky clear, no overflow, ID readable
    assert to_int32(await env.rd(ACC)) == 0
    st = await env.rd(STATUS)
    assert (st & 0x7) == 0, f"STATUS not clean after reset: {st:#x}"
    assert (await env.rd(IDR)) == ID_VALUE, "ID mismatch"


@cocotb.test()
async def test_simple_known_dot(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)          # 8 lanes, load
    await env.set_weights([1, 2, 3, 4, 5, 6, 7, 8])
    # 1*1+2*2+...+8*8 = 204
    await env.run_pass([1, 2, 3, 4, 5, 6, 7, 8])
    assert env.model.acc == 204


@cocotb.test()
async def test_all_zero(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([0] * 8)
    await env.run_pass([0] * 8)
    assert env.model.acc == 0


@cocotb.test()
async def test_all_positive(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([10, 20, 30, 40, 50, 60, 70, 80])
    await env.run_pass([2, 2, 2, 2, 2, 2, 2, 2])


@cocotb.test()
async def test_mixed_signed(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([-5, 6, -7, 8, -9, 10, -11, 12])
    await env.run_pass([3, -4, 5, -6, 7, -8, 9, -10])


# =========================================================================
# CORNER CASES
# =========================================================================
@cocotb.test()
async def test_max_positive_int8(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([INT8_MAX] * 8)
    await env.run_pass([INT8_MAX] * 8)              # 8 * 127 * 127 = 129032
    assert env.model.acc == 8 * 127 * 127


@cocotb.test()
async def test_max_negative_int8(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    # -128 * -128 = 16384 (largest-magnitude positive product)
    await env.set_weights([INT8_MIN] * 8)
    await env.run_pass([INT8_MIN] * 8)
    assert env.model.acc == 8 * 16384
    # 127 * -128 = -16256 (most negative product)
    await env.set_weights([INT8_MAX] * 8)
    await env.set_mode(lane8=1, acc_en=0)
    await env.run_pass([INT8_MIN] * 8)
    assert env.model.acc == 8 * (127 * -128)


@cocotb.test()
async def test_overflow_boundary_wrap(dut):
    env = await _bringup(dut)
    await env.set_weights([INT8_MAX] * 8)
    await env.set_mode(lane8=1, acc_en=1, acc_sat=0)   # accumulate, wrap+flag
    await env.clear_acc()
    step = 8 * 127 * 127
    limit = 25 if FAST else (INT32_MAX // step) + 2
    saw_overflow = False
    for _ in range(limit):
        await env.run_pass_expl([INT8_MAX] * 8, check=False)
        if env.model.ovf == 1:
            saw_overflow = True
            break
    if not FAST:
        assert saw_overflow, "expected int32 overflow while accumulating max passes"
        await env.check_acc(context="post-wrap")       # wrapped value matches model
        await env.check_ovf(1)                          # sticky flag set
    else:
        await env.check_acc(context="fast-wrap")


@cocotb.test()
async def test_overflow_boundary_saturate(dut):
    env = await _bringup(dut)
    await env.set_weights([INT8_MAX] * 8)
    await env.set_mode(lane8=1, acc_en=1, acc_sat=1)   # accumulate, saturate
    await env.clear_acc()
    step = 8 * 127 * 127
    limit = 25 if FAST else (INT32_MAX // step) + 3
    for _ in range(limit):
        await env.run_pass_expl([INT8_MAX] * 8, check=False)
        if env.model.acc == INT32_MAX:
            break
    if not FAST:
        assert env.model.acc == INT32_MAX, "model should have clamped"
        await env.check_acc(context="saturated")        # clamped value matches
        await env.check_ovf(0)                           # saturate does not flag


@cocotb.test()
async def test_repeated_operations(dut):
    env = await _bringup(dut)
    await env.set_weights([1, 1, 1, 1, 1, 1, 1, 1])
    await env.set_mode(lane8=1, acc_en=1)
    await env.clear_acc()
    for _ in range(50):                                # same op repeated, accumulating
        await env.run_pass_expl([1, 1, 1, 1, 1, 1, 1, 1], check=True)
    assert env.model.acc == 50 * 8


@cocotb.test()
async def test_back_to_back_auto(dut):
    env = await _bringup(dut)
    await env.set_weights([2, -2, 2, -2, 2, -2, 2, -2])
    await env.set_mode(lane8=1, acc_en=1, auto=1)      # auto_start: streaming passes
    await env.clear_acc()
    rng = random.Random(1)
    for _ in range(20):
        acts = [rng.randint(-128, 127) for _ in range(8)]
        await env.run_pass_auto(acts, check=True)


@cocotb.test()
async def test_invalid_command_handling(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([3] * 8)
    await env.run_pass([4] * 8)                         # acc = 96
    before = env.model.acc

    # writes to undefined addresses must be ignored
    await env.wr(0x1C, 0xDEADBEEF)
    await env.wr(0xFC, 0xFFFFFFFF)
    # reserved CONFIG bits [31:3] must be ignored
    await env.wr(CONFIG, 0xFFFFFFF8)
    # reads of undefined addresses return 0
    assert (await env.rd(0x1C)) == 0
    assert (await env.rd(0xFC)) == 0

    # state undisturbed and engine still functional
    assert to_int32(await env.rd(ACC)) == before
    await env.set_mode(lane8=1, acc_en=0)
    await env.run_pass([4] * 8)


# =========================================================================
# RANDOM (>= 1000 vectors)
# =========================================================================
@cocotb.test()
async def test_random_1000(dut):
    env = await _bringup(dut)
    rng = random.Random(0xC0FFEE)
    total = 0
    target = int(os.environ.get("MACC8_RANDN", "1000"))
    while total < target:
        lane8 = rng.randint(0, 1)
        acc_en = rng.randint(0, 1)
        acc_sat = rng.randint(0, 1)
        weights = [rng.randint(-128, 127) for _ in range(8)]
        await env.set_mode(lane8=lane8, acc_en=acc_en, acc_sat=acc_sat)
        await env.set_weights(weights)
        await env.clear_acc()
        n_passes = rng.randint(5, 30)
        for _ in range(n_passes):
            acts = [rng.randint(-128, 127) for _ in range(8)]
            await env.run_pass_expl(acts, check=True)
            total += 1
            if total >= target:
                break
    dut._log.info(f"random test completed {total} checked passes")


# =========================================================================
# PROTOCOL
# =========================================================================
@cocotb.test()
async def test_start_before_load(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([7] * 8)
    # start with NO activations resident -> must be ignored (act_full == 0)
    await env.start()
    for _ in range(10):
        await RisingEdge(dut.clk)
        assert int(dut.done.value) == 0, "done asserted without a loaded vector"
    assert int(dut.busy.value) == 0, "engine became busy without a loaded vector"
    assert to_int32(await env.rd(ACC)) == 0
    # now a proper pass still works
    await env.run_pass([7] * 8)
    assert env.model.acc == 8 * 49


@cocotb.test()
async def test_read_before_done(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([1, 2, 3, 4, 5, 6, 7, 8])
    await env.run_pass([1, 1, 1, 1, 1, 1, 1, 1])       # acc = 36 (load)
    old = env.model.acc

    # launch a new pass and read ACC while the engine is busy
    acts = [2, 2, 2, 2, 2, 2, 2, 2]                    # would load to 72
    await env.send(acts)
    await env.start()
    mid = to_int32(await env.rd(ACC))                  # read spans the compute window
    # mid must be a coherent accumulator value (old or new), never corrupt
    env.model.dot(acts)
    new = env.model.acc
    assert mid in (old, new), f"incoherent read during busy: {mid} not in {{{old},{new}}}"
    # final value is correct -> the read did not disturb the datapath
    await env.check_acc(context="post read-before-done")


@cocotb.test()
async def test_reset_during_operation(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=1)
    await env.set_weights([9] * 8)
    await env.clear_acc()
    await env.run_pass_expl([3] * 8, check=True)       # acc = 8*27 = 216

    # start a pass, then assert reset mid-compute
    await env.send([5] * 8)
    await env.start()
    await RisingEdge(dut.clk)                           # 1 cycle into compute
    await env.pulse_reset_mid_op(cycles_before_release=2)

    # after reset everything is cleared
    assert to_int32(await env.rd(ACC)) == 0
    st = await env.rd(STATUS)
    assert (st & 0x7) == 0

    # recovery: weights were also cleared by reset -> reload and run
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([9] * 8)
    await env.run_pass([3] * 8)
    assert env.model.acc == 216


# =========================================================================
# MODEL SELF-CHECK (fast, no DUT interaction beyond bring-up)
# =========================================================================
@cocotb.test()
async def test_model_boundary_selfcheck(dut):
    await _bringup(dut)                                 # keep sim happy
    m = Macc8Model()
    # wrap
    m.set_mode(lane_sel=1, acc_en=1, acc_sat=0)
    m.acc = INT32_MAX
    m.dot([1] + [0] * 7)                                # +1 wraps to INT32_MIN (weights 0 though)
    # weights default 0 -> tree 0 -> no change; set weight to force +1
    m2 = Macc8Model(); m2.set_mode(acc_en=1, acc_sat=0); m2.set_weights_list([1] + [0]*7)
    m2.acc = INT32_MAX
    acc, ovf = m2.dot([1] + [0]*7)
    assert acc == INT32_MIN and ovf == 1, (acc, ovf)
    # saturate
    m3 = Macc8Model(); m3.set_mode(acc_en=1, acc_sat=1); m3.set_weights_list([1] + [0]*7)
    m3.acc = INT32_MAX
    acc, ovf = m3.dot([1] + [0]*7)
    assert acc == INT32_MAX and ovf == 0, (acc, ovf)
