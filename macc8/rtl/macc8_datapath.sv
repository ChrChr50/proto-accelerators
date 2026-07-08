// -----------------------------------------------------------------------------
// macc8_datapath.sv
// Assembles the compute datapath:
//   MUL stage  : LANES combinational multipliers -> product pipeline registers
//                (captured when mul_capture is high).
//   ADACC stage: adder tree over registered products -> accumulator
//                (captured when acc_capture is high).
// Lanes with index >= active_lanes are masked (product forced to 0) so the same
// hardware serves both 8-lane and 4-lane modes.
//
// Package symbols use the macc8_pkg:: scope (no wildcard import) for portability.
// -----------------------------------------------------------------------------
module macc8_datapath (
  input  logic                                         clk,
  input  logic                                         rst_n,
  // control (from FSM)
  input  logic                                         mul_capture,
  input  logic                                         acc_capture,
  input  logic                                         acc_clr,
  // config
  input  logic                                         acc_en,
  input  logic                                         acc_sat,
  input  logic [3:0]                                   active_lanes,   // 4 or 8
  // operands (packed)
  input  logic [macc8_pkg::LANES*macc8_pkg::ACT_W-1:0] act_bus,
  input  logic [macc8_pkg::LANES*macc8_pkg::WT_W-1:0]  wt_bus,
  // results
  output logic signed [macc8_pkg::ACC_W-1:0]           acc_q,
  output logic                                         ovf_q
);
  localparam int unsigned LANES  = macc8_pkg::LANES;
  localparam int unsigned ACT_W  = macc8_pkg::ACT_W;
  localparam int unsigned WT_W   = macc8_pkg::WT_W;
  localparam int unsigned PROD_W = macc8_pkg::PROD_W;
  localparam int unsigned TREE_W = macc8_pkg::TREE_W;
  localparam int unsigned ACC_W  = macc8_pkg::ACC_W;

  logic [LANES*PROD_W-1:0]  prod_comb;
  logic [LANES*PROD_W-1:0]  prod_q;
  logic signed [TREE_W-1:0] sum_c;

  // ---- MUL: combinational multipliers, one per lane -------------------------
  genvar g;
  generate
    for (g = 0; g < LANES; g++) begin : g_lane
      logic                     lane_en;
      logic signed [PROD_W-1:0] p_lane;

      assign lane_en = (g < active_lanes);

      macc8_mac_lane #(
        .ACT_W (ACT_W),
        .WT_W  (WT_W),
        .PROD_W(PROD_W)
      ) u_lane (
        .enable(lane_en),
        .act   ($signed(act_bus[g*ACT_W +: ACT_W])),
        .wt    ($signed(wt_bus [g*WT_W  +: WT_W ])),
        .prod  (p_lane)
      );

      assign prod_comb[g*PROD_W +: PROD_W] = p_lane;
    end
  endgenerate

  // ---- Product pipeline register (MUL stage) --------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)           prod_q <= '0;
    else if (mul_capture) prod_q <= prod_comb;
  end

  // ---- ADACC: adder tree + accumulator --------------------------------------
  macc8_adder_tree #(
    .LANES (LANES),
    .PROD_W(PROD_W),
    .SUM_W (TREE_W)
  ) u_tree (
    .prod_bus(prod_q),
    .sum     (sum_c)
  );

  macc8_accumulator #(
    .SUM_W(TREE_W),
    .ACC_W(ACC_W)
  ) u_acc (
    .clk        (clk),
    .rst_n      (rst_n),
    .acc_capture(acc_capture),
    .acc_en     (acc_en),
    .acc_clr    (acc_clr),
    .acc_sat    (acc_sat),
    .sum_in     (sum_c),
    .acc_q      (acc_q),
    .ovf_q      (ovf_q)
  );

endmodule : macc8_datapath
