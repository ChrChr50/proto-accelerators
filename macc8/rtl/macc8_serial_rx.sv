module macc8_serial_rx (
  input  logic                                         clk,
  input  logic                                         rst_n,
  input  logic                                         accept_en,
  input  logic                                         consume,
  input  logic [3:0]                                   active_lanes,
  input  logic [macc8_pkg::ACT_W-1:0]                  act_data,
  input  logic                                         act_valid,
  output logic                                         act_ready,
  output logic                                         act_full,
  output logic [macc8_pkg::LANES*macc8_pkg::ACT_W-1:0] act_bus
);
  localparam int unsigned LANES = macc8_pkg::LANES;
  localparam int unsigned ACT_W = macc8_pkg::ACT_W;

  logic [3:0]             filled;
  logic [LANES*ACT_W-1:0] act_store;

  assign act_full  = (filled >= active_lanes);
  assign act_ready = accept_en & ~act_full;
  assign act_bus   = act_store;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      filled    <= '0;
      act_store <= '0;
    end else if (consume) begin
      filled <= '0;
    end else if (act_ready & act_valid) begin
      act_store[filled*ACT_W +: ACT_W] <= act_data;
      filled                           <= filled + 4'd1;
    end
  end

endmodule : macc8_serial_rx
