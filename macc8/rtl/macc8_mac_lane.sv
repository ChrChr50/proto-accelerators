// -----------------------------------------------------------------------------
// macc8_mac_lane.sv
// One combinational multiply lane: signed int8 * signed int8 -> signed int16.
// 'enable' low forces the product to zero (used to mask lanes in 4-lane mode).
// Purely combinational; every output assigned on all paths (no latch).
// -----------------------------------------------------------------------------
module macc8_mac_lane #(
  parameter int unsigned ACT_W  = 8,
  parameter int unsigned WT_W   = 8,
  parameter int unsigned PROD_W = 16
) (
  input  logic                     enable,
  input  logic signed [ACT_W-1:0]  act,
  input  logic signed [WT_W-1:0]   wt,
  output logic signed [PROD_W-1:0] prod
);

  logic signed [PROD_W-1:0] mult_c;

  always_comb begin
    mult_c = act * wt;                 // signed * signed (both operands declared signed)
    prod   = enable ? mult_c : '0;
  end

endmodule : macc8_mac_lane
