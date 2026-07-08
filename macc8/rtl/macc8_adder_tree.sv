// -----------------------------------------------------------------------------
// macc8_adder_tree.sv
// Sums LANES signed int16 products into a signed SUM_W result. Written as an
// accumulate loop, which synthesizes to a balanced adder tree. Each product is
// sign-extended into the wider signed accumulator context. Combinational.
// Products are passed as a packed bus (no unpacked-array ports) for portability.
// -----------------------------------------------------------------------------
module macc8_adder_tree #(
  parameter int unsigned LANES  = 8,
  parameter int unsigned PROD_W = 16,
  parameter int unsigned SUM_W  = 20
) (
  input  logic [LANES*PROD_W-1:0] prod_bus,   // each PROD_W slice is a signed int16
  output logic signed [SUM_W-1:0] sum
);

  logic signed [SUM_W-1:0]  acc_c;
  logic signed [PROD_W-1:0] p_c;

  always_comb begin
    acc_c = '0;
    for (int unsigned i = 0; i < LANES; i++) begin
      p_c   = $signed(prod_bus[i*PROD_W +: PROD_W]);
      acc_c = acc_c + SUM_W'(p_c);     // explicit sign-extend of signed product to SUM_W
    end
    sum = acc_c;
  end

endmodule : macc8_adder_tree
