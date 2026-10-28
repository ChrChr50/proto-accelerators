module macc8_reset_sync (
  input  logic clk,
  input  logic arst_n,
  output logic srst_n
);

  logic first_stage;

  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) begin
      first_stage <= 1'b0;
      srst_n      <= 1'b0;
    end else begin
      first_stage <= 1'b1;
      srst_n      <= first_stage;
    end
  end

endmodule : macc8_reset_sync
