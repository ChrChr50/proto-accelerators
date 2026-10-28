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

  logic signed [PROD_W-1:0] raw_prod;

  always_comb begin
    raw_prod = act * wt;
    prod     = enable ? raw_prod : '0;
  end

endmodule : macc8_mac_lane
