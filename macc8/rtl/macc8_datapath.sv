module macc8_datapath (
  input  logic                                         clk,
  input  logic                                         rst_n,
  input  logic                                         mul_capture,
  input  logic                                         acc_capture,
  input  logic                                         acc_clr,
  input  logic                                         acc_en,
  input  logic                                         acc_sat,
  input  logic [3:0]                                   active_lanes,
  input  logic [macc8_pkg::LANES*macc8_pkg::ACT_W-1:0] act_bus,
  input  logic [macc8_pkg::LANES*macc8_pkg::WT_W-1:0]  wt_bus,
  output logic signed [macc8_pkg::ACC_W-1:0]           acc_q,
  output logic                                         ovf_q
);
  localparam int unsigned LANES  = macc8_pkg::LANES;
  localparam int unsigned ACT_W  = macc8_pkg::ACT_W;
  localparam int unsigned WT_W   = macc8_pkg::WT_W;
  localparam int unsigned PROD_W = macc8_pkg::PROD_W;
  localparam int unsigned TREE_W = macc8_pkg::TREE_W;
  localparam int unsigned ACC_W  = macc8_pkg::ACC_W;

  logic [LANES*PROD_W-1:0]  fresh_prods;
  logic [LANES*PROD_W-1:0]  held_prods;
  logic signed [TREE_W-1:0] tree_sum;

  genvar ln;
  generate
    for (ln = 0; ln < LANES; ln++) begin : g_lane
      logic                     lane_on;
      logic signed [PROD_W-1:0] lane_prod;

      assign lane_on = (ln < active_lanes);

      macc8_mac_lane #(
        .ACT_W (ACT_W),
        .WT_W  (WT_W),
        .PROD_W(PROD_W)
      ) u_lane (
        .enable(lane_on),
        .act   ($signed(act_bus[ln*ACT_W +: ACT_W])),
        .wt    ($signed(wt_bus [ln*WT_W  +: WT_W ])),
        .prod  (lane_prod)
      );

      assign fresh_prods[ln*PROD_W +: PROD_W] = lane_prod;
    end
  endgenerate

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)           held_prods <= '0;
    else if (mul_capture) held_prods <= fresh_prods;
  end

  macc8_adder_tree #(
    .LANES (LANES),
    .PROD_W(PROD_W),
    .SUM_W (TREE_W)
  ) u_tree (
    .prod_bus(held_prods),
    .sum     (tree_sum)
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
    .sum_in     (tree_sum),
    .acc_q      (acc_q),
    .ovf_q      (ovf_q)
  );

endmodule : macc8_datapath
