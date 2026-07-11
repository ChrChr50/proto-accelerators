// -----------------------------------------------------------------------------
// macc8_serial_rx.sv
// Byte-serial activation front end. Accepts one signed int8 per valid/ready beat
// while accept_en is high (FSM in IDLE), filling lanes 0..active_lanes-1 in order.
// act_full asserts once a full vector is resident. 'consume' (pulse at pass start)
// resets the lane counter so the next vector can be loaded; the activation
// registers themselves are held until overwritten by new beats.
//
// Package symbols use the macc8_pkg:: scope (no wildcard import) for portability.
// -----------------------------------------------------------------------------
module macc8_serial_rx (
  input  logic                                        clk,
  input  logic                                        rst_n,
  input  logic                                        accept_en,     // FSM can accept (IDLE)
  input  logic                                        consume,       // pulse: pass started
  input  logic [3:0]                                  active_lanes,  // 4 or 8
  input  logic [macc8_pkg::ACT_W-1:0]                 act_data,
  input  logic                                        act_valid,
  output logic                                        act_ready,
  output logic                                        act_full,
  output logic [macc8_pkg::LANES*macc8_pkg::ACT_W-1:0] act_bus
);
  localparam int unsigned LANES = macc8_pkg::LANES;
  localparam int unsigned ACT_W = macc8_pkg::ACT_W;

  logic [3:0]             cnt_q;
  logic [LANES*ACT_W-1:0] act_regs_q;

  assign act_full  = (cnt_q >= active_lanes);
  assign act_ready = accept_en & ~act_full;
  assign act_bus   = act_regs_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt_q      <= '0;
      act_regs_q <= '0;
    end else if (consume) begin
      cnt_q <= '0;                                  // keep act_regs_q (in use this cycle)
    end else if (act_ready & act_valid) begin
      act_regs_q[cnt_q*ACT_W +: ACT_W] <= act_data; // variable part-select write
      cnt_q                            <= cnt_q + 4'd1;
    end
  end

endmodule : macc8_serial_rx
