"""
macc8_ref.py — Golden reference model for the MACC-8 int8 dot-product engine.

Bit-exact software twin of the RTL. Every RTL test compares against this model.
The model mirrors the hardware register/compute semantics exactly:

  - operands are signed int8 (two's complement)
  - product is signed int16, tree sum is signed (fits int20 for 8 lanes)
  - accumulator is signed int32
  - acc_en = 1 -> acc += sum ; acc_en = 0 -> acc = sum (load)
  - overflow of int32:
        acc_sat = 1 -> clamp to +/- int32 max/min, overflow flag NOT set
        acc_sat = 0 -> wrap (two's complement) and set sticky overflow flag
  - acc_clr / soft reset zero the accumulator and the overflow flag
  - active lanes = 8 when lane_sel else 4 (extra lanes masked to 0)

This module has no cocotb dependency and is independently unit-testable.
"""

INT8_MIN, INT8_MAX = -128, 127
INT32_MIN, INT32_MAX = -(2**31), 2**31 - 1
ID_VALUE = 0x4D414338  # "MAC8"


def s8(b: int) -> int:
    """Interpret the low 8 bits of b as a signed int8."""
    b &= 0xFF
    return b - 256 if b >= 128 else b


def to_int32(x: int) -> int:
    """Wrap an arbitrary integer into signed int32 (two's complement)."""
    return ((x + 2**31) % 2**32) - 2**31


class Macc8Model:
    def __init__(self):
        self.reset()

    # ---- reset / state --------------------------------------------------
    def reset(self):
        self.acc = 0
        self.ovf = 0
        self.weights = [0] * 8
        self.lane_sel = 1       # default 8 lanes (matches RTL reset default)
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

    # ---- configuration --------------------------------------------------
    def set_weights_list(self, wl):
        assert len(wl) == 8
        self.weights = [s8(w) for w in wl]

    def set_weights_words(self, w0: int, w1: int):
        for i in range(4):
            self.weights[i] = s8((w0 >> (8 * i)) & 0xFF)
        for i in range(4):
            self.weights[4 + i] = s8((w1 >> (8 * i)) & 0xFF)

    def set_mode(self, lane_sel=None, acc_en=None, acc_sat=None, auto_start=None):
        if lane_sel is not None:
            self.lane_sel = int(bool(lane_sel))
        if acc_en is not None:
            self.acc_en = int(bool(acc_en))
        if acc_sat is not None:
            self.acc_sat = int(bool(acc_sat))
        if auto_start is not None:
            self.auto_start = int(bool(auto_start))

    # ---- compute one pass ----------------------------------------------
    def dot(self, acts):
        """Apply one MAC pass over 'acts' (len >= active_lanes). Returns (acc, ovf)."""
        n = self.active_lanes
        prods = [s8(acts[i]) * self.weights[i] for i in range(n)]
        tree = sum(prods)                      # exact; fits int20 for 8 lanes

        res = self.acc + tree if self.acc_en else tree
        overflow = (res > INT32_MAX) or (res < INT32_MIN)

        if self.acc_sat:
            if res > INT32_MAX:
                self.acc = INT32_MAX
            elif res < INT32_MIN:
                self.acc = INT32_MIN
            else:
                self.acc = res
            # overflow flag not set when saturating
        else:
            self.acc = to_int32(res)
            if overflow:
                self.ovf = 1                   # sticky

        self.done_sticky = 1
        return self.acc, self.ovf

    # ---- expected register readback ------------------------------------
    def status_word(self, busy=0):
        return (self.ovf << 2) | (self.done_sticky << 1) | (busy & 1)

    def acc_word(self):
        return to_int32(self.acc) & 0xFFFFFFFF
