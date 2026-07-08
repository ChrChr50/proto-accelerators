// -----------------------------------------------------------------------------
// macc8_accumulator.sv
// Signed int32 accumulator. On acc_capture:
//   acc_en=1 -> acc += sum_in ; acc_en=0 -> acc = sum_in (load).
// Overflow of the int32 result is detected one bit wide (EXT_W = ACC_W+1):
//   acc_sat=1 -> clamp to +/- int32 max/min, acc_ovf stays 0 (saturated).
//   acc_sat=0 -> wrap (truncate) and set sticky acc_ovf.
// acc_clr synchronously zeros the accumulator and the overflow flag.
// -----------------------------------------------------------------------------
module macc8_accumulator #(
  parameter int unsigned SUM_W = 20,
  parameter int unsigned ACC_W = 32
) (
  input  logic                    clk,
  input  logic                    rst_n,
  input  logic                    acc_capture, // register the result this cycle
  input  logic                    acc_en,      // 1: accumulate, 0: load
  input  logic                    acc_clr,     // synchronous clear (acc + flag)
  input  logic                    acc_sat,     // 1: saturate, 0: wrap + flag
  input  logic signed [SUM_W-1:0] sum_in,
  output logic signed [ACC_W-1:0] acc_q,
  output logic                    ovf_q
);

  localparam int unsigned EXT_W = ACC_W + 1;

  localparam logic signed [ACC_W-1:0] ACC_MAX = {1'b0, {(ACC_W-1){1'b1}}}; // +2^31-1
  localparam logic signed [ACC_W-1:0] ACC_MIN = {1'b1, {(ACC_W-1){1'b0}}}; // -2^31

  logic signed [EXT_W-1:0] acc_ext_c;
  logic signed [EXT_W-1:0] sum_ext_c;
  logic signed [EXT_W-1:0] res_ext_c;
  logic signed [ACC_W-1:0] res_sat_c;
  logic                    res_ovf_c;

  always_comb begin
    acc_ext_c = EXT_W'(acc_q);          // sign-extend current accumulator
    sum_ext_c = EXT_W'(sum_in);         // sign-extend incoming tree sum
    res_ext_c = acc_en ? (acc_ext_c + sum_ext_c) : sum_ext_c;

    // signed overflow of int32: the two top bits of the (ACC_W+1) result differ
    res_ovf_c = (res_ext_c[EXT_W-1] != res_ext_c[EXT_W-2]);

    if (res_ovf_c) res_sat_c = res_ext_c[EXT_W-1] ? ACC_MIN : ACC_MAX;
    else           res_sat_c = res_ext_c[ACC_W-1:0];
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_q <= '0;
      ovf_q <= 1'b0;
    end else if (acc_clr) begin
      acc_q <= '0;
      ovf_q <= 1'b0;
    end else if (acc_capture) begin
      acc_q <= acc_sat ? res_sat_c : res_ext_c[ACC_W-1:0];
      ovf_q <= ovf_q | (res_ovf_c & ~acc_sat); // sticky only when wrapping
    end
  end

endmodule : macc8_accumulator
