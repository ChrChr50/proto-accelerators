module macc8_adder_tree #(
  parameter int unsigned LANES  = 8,
  parameter int unsigned PROD_W = 16,
  parameter int unsigned SUM_W  = 20
) (
  input  logic [LANES*PROD_W-1:0] prod_bus,
  output logic signed [SUM_W-1:0] sum
);

  logic signed [SUM_W-1:0]  total;
  logic signed [PROD_W-1:0] term;

  always_comb begin
    total = '0;
    for (int unsigned lane = 0; lane < LANES; lane++) begin
      term  = $signed(prod_bus[lane*PROD_W +: PROD_W]);
      total = total + SUM_W'(term);
    end
    sum = total;
  end

endmodule : macc8_adder_tree
