// -----------------------------------------------------------------------------
// macc8_reset_sync.sv
// Two-flop reset synchronizer. Reset asserts asynchronously (on arst_n low) and
// de-asserts synchronously to clk. Platform convention for Sky130 / Caravel.
// -----------------------------------------------------------------------------
module macc8_reset_sync (
  input  logic clk,
  input  logic arst_n,   // raw async-asserted active-low reset
  output logic srst_n    // synchronized active-low reset (async assert, sync deassert)
);

  logic meta_q;

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      meta_q <= 1'b0;
      srst_n <= 1'b0;
    end else begin
      meta_q <= 1'b1;
      srst_n <= meta_q;
    end
  end

endmodule : macc8_reset_sync
