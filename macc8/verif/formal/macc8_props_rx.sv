// Properties for macc8_serial_rx: the valid/ready handshake and the full
// flag, checked through the ports only. Same immediate-assert style as
// macc8_props_fsm.sv so plain Yosys can read it.
module macc8_props_rx (
  input logic       clk,
  input logic       rst_n,
  input logic       accept_en,
  input logic       consume,
  input logic [3:0] active_lanes,
  input logic [7:0] act_data,
  input logic       act_valid
);
  logic                                          act_ready, act_full;
  logic [macc8_pkg::LANES*macc8_pkg::ACT_W-1:0]  act_bus;

  macc8_serial_rx dut (
    .clk(clk), .rst_n(rst_n),
    .accept_en(accept_en), .consume(consume),
    .active_lanes(active_lanes),
    .act_data(act_data), .act_valid(act_valid),
    .act_ready(act_ready), .act_full(act_full), .act_bus(act_bus)
  );

  logic past_valid;
  initial past_valid = 1'b0;
  always @(posedge clk) past_valid <= 1'b1;

  always @(posedge clk) begin
    // the regfile can only ever produce 4 or 8
    m_lanes: assume (active_lanes == 4'd4 || active_lanes == 4'd8);

    if (!rst_n) begin
      a_reset_empty: assert (!act_full);
    end else begin
      a_ready_def:       assert (act_ready == (accept_en && !act_full));
      a_full_blocks:     assert (!act_full || !act_ready);
      a_ready_needs_en:  assert (!act_ready || accept_en);
      if (past_valid && $past(rst_n)) begin
        a_consume_clears: assert (!$past(consume) || !act_full);
      end
    end
  end

endmodule
