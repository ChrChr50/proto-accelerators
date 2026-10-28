"""MACC-8 cocotb regression.

What's covered:
  basic     reset state, a hand-checked dot product, all-zero, all-positive,
            mixed signs
  corner    int8 extremes, int32 overflow (wrap and saturate), repeated
            passes, back-to-back auto_start passes, junk register traffic
  random    1000 random passes checked against the model
  protocol  start with nothing loaded, reading ACC mid-pass, reset mid-pass
  model     boundary check on the Python model itself

Each hardware result is compared against macc8_ref.Macc8Model. The two
overflow tests need ~16.6k passes to really cross the int32 limit; export
MACC8_FAST=1 to cut them short while iterating.
"""

import os
import random

import cocotb
from cocotb.triggers import RisingEdge

from macc8_env import Macc8Env, CTRL, STATUS, CONFIG, ACC, IDR, ctrl_word
from macc8_ref import (Macc8Model, s8, to_int32, INT8_MAX, INT8_MIN,
                       INT32_MAX, INT32_MIN, ID_VALUE)

FAST = os.environ.get("MACC8_FAST", "0") == "1"
MAX_PASS = 8 * INT8_MAX * INT8_MAX  # 129032, the biggest single 8-lane pass


async def _bringup(dut):
    env = Macc8Env(dut)
    env.start_clock()
    await env.reset()
    return env


# --- basic ----------------------------------------------------------------

@cocotb.test()
async def test_reset_behavior(dut):
    env = await _bringup(dut)
    assert to_int32(await env.rd(ACC)) == 0
    status = await env.rd(STATUS)
    assert (status & 0x7) == 0, f"STATUS should be 0 after reset, read {status:#x}"
    assert (await env.rd(IDR)) == ID_VALUE, "ID register mismatch"


@cocotb.test()
async def test_simple_known_dot(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([1, 2, 3, 4, 5, 6, 7, 8])
    await env.run_pass([1, 2, 3, 4, 5, 6, 7, 8])
    assert env.model.acc == 204  # 1 + 4 + 9 + ... + 64


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
    await env.run_pass([2] * 8)


@cocotb.test()
async def test_mixed_signed(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([-5, 6, -7, 8, -9, 10, -11, 12])
    await env.run_pass([3, -4, 5, -6, 7, -8, 9, -10])


# --- corner cases ---------------------------------------------------------

@cocotb.test()
async def test_max_positive_int8(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([INT8_MAX] * 8)
    await env.run_pass([INT8_MAX] * 8)
    assert env.model.acc == MAX_PASS


@cocotb.test()
async def test_max_negative_int8(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)

    # -128 * -128 is the largest product an int8 pair can make
    await env.set_weights([INT8_MIN] * 8)
    await env.run_pass([INT8_MIN] * 8)
    assert env.model.acc == 8 * 16384

    # 127 * -128 is the most negative one
    await env.set_weights([INT8_MAX] * 8)
    await env.set_mode(lane8=1, acc_en=0)
    await env.run_pass([INT8_MIN] * 8)
    assert env.model.acc == 8 * (127 * -128)


@cocotb.test()
async def test_overflow_boundary_wrap(dut):
    env = await _bringup(dut)
    await env.set_weights([INT8_MAX] * 8)
    await env.set_mode(lane8=1, acc_en=1, acc_sat=0)
    await env.clear_acc()

    max_passes = 25 if FAST else INT32_MAX // MAX_PASS + 2
    wrapped = False
    for _ in range(max_passes):
        await env.run_pass_expl([INT8_MAX] * 8, check=False)
        if env.model.ovf:
            wrapped = True
            break

    if FAST:
        await env.check_acc(context="fast-wrap")
    else:
        assert wrapped, "accumulator never overflowed"
        await env.check_acc(context="post-wrap")
        await env.check_ovf(1)


@cocotb.test()
async def test_overflow_boundary_saturate(dut):
    env = await _bringup(dut)
    await env.set_weights([INT8_MAX] * 8)
    await env.set_mode(lane8=1, acc_en=1, acc_sat=1)
    await env.clear_acc()

    max_passes = 25 if FAST else INT32_MAX // MAX_PASS + 3
    for _ in range(max_passes):
        await env.run_pass_expl([INT8_MAX] * 8, check=False)
        if env.model.acc == INT32_MAX:
            break

    if not FAST:
        assert env.model.acc == INT32_MAX, "model never reached the clamp"
        await env.check_acc(context="saturated")
        await env.check_ovf(0)  # saturating is not supposed to raise the flag


@cocotb.test()
async def test_repeated_operations(dut):
    env = await _bringup(dut)
    await env.set_weights([1] * 8)
    await env.set_mode(lane8=1, acc_en=1)
    await env.clear_acc()
    for _ in range(50):
        await env.run_pass_expl([1] * 8, check=True)
    assert env.model.acc == 50 * 8


@cocotb.test()
async def test_back_to_back_auto(dut):
    env = await _bringup(dut)
    await env.set_weights([2, -2, 2, -2, 2, -2, 2, -2])
    await env.set_mode(lane8=1, acc_en=1, auto=1)
    await env.clear_acc()
    rng = random.Random(1)
    for _ in range(20):
        await env.run_pass_auto([rng.randint(-128, 127) for _ in range(8)], check=True)


@cocotb.test()
async def test_invalid_command_handling(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([3] * 8)
    await env.run_pass([4] * 8)
    acc_before = env.model.acc

    # unmapped addresses and CONFIG's unused upper bits should all be inert
    await env.wr(0x1C, 0xDEADBEEF)
    await env.wr(0xFC, 0xFFFFFFFF)
    await env.wr(CONFIG, 0xFFFFFFF8)
    assert (await env.rd(0x1C)) == 0
    assert (await env.rd(0xFC)) == 0

    assert to_int32(await env.rd(ACC)) == acc_before
    await env.set_mode(lane8=1, acc_en=0)
    await env.run_pass([4] * 8)


# --- random ---------------------------------------------------------------

@cocotb.test()
async def test_random_1000(dut):
    env = await _bringup(dut)
    rng = random.Random(0xC0FFEE)
    goal = int(os.environ.get("MACC8_RANDN", "1000"))
    done = 0

    def rand_bytes():
        return [rng.randint(-128, 127) for _ in range(8)]

    while done < goal:
        await env.set_mode(lane8=rng.randint(0, 1),
                           acc_en=rng.randint(0, 1),
                           acc_sat=rng.randint(0, 1))
        await env.set_weights(rand_bytes())
        await env.clear_acc()
        for _ in range(rng.randint(5, 30)):
            await env.run_pass_expl(rand_bytes(), check=True)
            done += 1
            if done >= goal:
                break

    dut._log.info(f"random test checked {done} passes")


# --- protocol -------------------------------------------------------------

@cocotb.test()
async def test_start_before_load(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([7] * 8)

    # nothing loaded yet, so this start should do nothing
    await env.start()
    for _ in range(10):
        await RisingEdge(dut.clk)
        assert int(dut.done.value) == 0, "done fired with no vector loaded"
    assert int(dut.busy.value) == 0, "went busy with no vector loaded"
    assert to_int32(await env.rd(ACC)) == 0

    await env.run_pass([7] * 8)
    assert env.model.acc == 8 * 49


@cocotb.test()
async def test_read_before_done(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([1, 2, 3, 4, 5, 6, 7, 8])
    await env.run_pass([1] * 8)
    old_acc = env.model.acc  # 36

    acts = [2] * 8  # this pass loads 72
    await env.send(acts)
    await env.start()
    mid_read = to_int32(await env.rd(ACC))  # overlaps the compute cycles

    env.model.dot(acts)
    new_acc = env.model.acc
    assert mid_read in (old_acc, new_acc), \
        f"read {mid_read} while busy, expected {old_acc} or {new_acc}"
    await env.check_acc(context="after mid-pass read")


@cocotb.test()
async def test_reset_during_operation(dut):
    env = await _bringup(dut)
    await env.set_mode(lane8=1, acc_en=1)
    await env.set_weights([9] * 8)
    await env.clear_acc()
    await env.run_pass_expl([3] * 8, check=True)  # 216

    await env.send([5] * 8)
    await env.start()
    await RisingEdge(dut.clk)
    await env.pulse_reset_mid_op(cycles_before_release=2)

    assert to_int32(await env.rd(ACC)) == 0
    assert ((await env.rd(STATUS)) & 0x7) == 0

    # reset wiped the weights too, so load them again before checking recovery
    await env.set_mode(lane8=1, acc_en=0)
    await env.set_weights([9] * 8)
    await env.run_pass([3] * 8)
    assert env.model.acc == 216


# --- model ----------------------------------------------------------------

@cocotb.test()
async def test_model_boundary_selfcheck(dut):
    await _bringup(dut)

    def one_below_limit(saturate):
        m = Macc8Model()
        m.set_mode(acc_en=1, acc_sat=saturate)
        m.set_weights_list([1] + [0] * 7)
        m.acc = INT32_MAX
        return m.dot([1] + [0] * 7)

    acc, ovf = one_below_limit(saturate=0)
    assert (acc, ovf) == (INT32_MIN, 1), (acc, ovf)

    acc, ovf = one_below_limit(saturate=1)
    assert (acc, ovf) == (INT32_MAX, 0), (acc, ovf)
