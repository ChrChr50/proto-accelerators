"""Reference model for MACC-8.

A plain-Python copy of what the RTL computes, used by the cocotb tests to
predict every accumulator and status value. The rules it follows:

  * activations and weights are signed int8
  * each product is int16; the 8-lane sum always fits in int20
  * the accumulator is int32
  * acc_en=1 adds the pass result to the accumulator, acc_en=0 overwrites it
  * on int32 overflow:
      acc_sat=1  clamp to INT32_MAX / INT32_MIN, overflow flag stays clear
      acc_sat=0  wrap around and set the (sticky) overflow flag
  * acc_clr and soft reset zero both the accumulator and the flag
  * lane_sel=1 uses 8 lanes, lane_sel=0 uses 4 (the rest contribute 0)

No cocotb import here, so it can be exercised on its own.
"""

INT8_MIN, INT8_MAX = -128, 127
INT32_MIN, INT32_MAX = -(2**31), 2**31 - 1
ID_VALUE = 0x4D414338  # ASCII "MAC8"


def s8(byte: int) -> int:
    """Read the low 8 bits of `byte` as a signed int8."""
    byte &= 0xFF
    return byte - 256 if byte >= 128 else byte


def to_int32(value: int) -> int:
    """Wrap any Python int into the signed int32 range."""
    return ((value + 2**31) % 2**32) - 2**31


class Macc8Model:
    def __init__(self):
        self.reset()

    def reset(self):
        self.acc = 0
        self.ovf = 0
        self.weights = [0] * 8
        self.lane_sel = 1  # RTL comes out of reset in 8-lane mode
        self.acc_en = 0
        self.acc_sat = 0
        self.auto_start = 0
        self.done_sticky = 0

    @property
    def active_lanes(self) -> int:
        return 8 if self.lane_sel else 4

    def clear_acc(self):
        self.acc = 0
        self.ovf = 0

    def clear_done(self):
        self.done_sticky = 0

    def set_weights_list(self, wl):
        assert len(wl) == 8
        self.weights = [s8(w) for w in wl]

    def set_weights_words(self, w0: int, w1: int):
        for lane in range(4):
            self.weights[lane] = s8(w0 >> (8 * lane))
            self.weights[lane + 4] = s8(w1 >> (8 * lane))

    def set_mode(self, lane_sel=None, acc_en=None, acc_sat=None, auto_start=None):
        updates = dict(lane_sel=lane_sel, acc_en=acc_en,
                       acc_sat=acc_sat, auto_start=auto_start)
        for name, val in updates.items():
            if val is not None:
                setattr(self, name, int(bool(val)))

    def dot(self, acts):
        """Run one pass over `acts` (needs at least active_lanes entries).

        Returns the new (acc, ovf) pair.
        """
        lanes = self.active_lanes
        pass_sum = sum(s8(acts[i]) * self.weights[i] for i in range(lanes))

        result = self.acc + pass_sum if self.acc_en else pass_sum
        too_big = result > INT32_MAX
        too_small = result < INT32_MIN

        if self.acc_sat:
            if too_big:
                result = INT32_MAX
            elif too_small:
                result = INT32_MIN
            self.acc = result
        else:
            self.acc = to_int32(result)
            if too_big or too_small:
                self.ovf = 1

        self.done_sticky = 1
        return self.acc, self.ovf

    def status_word(self, busy=0):
        return (self.ovf << 2) | (self.done_sticky << 1) | (busy & 1)

    def acc_word(self):
        return to_int32(self.acc) & 0xFFFFFFFF
