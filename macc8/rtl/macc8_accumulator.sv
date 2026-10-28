module macc8_accumulator #(
  parameter int unsigned SUM_W = 20,
  parameter int unsigned ACC_W = 32
) (
  input  logic                    clk,
  input  logic                    rst_n,
  input  logic                    acc_capture,
  input  logic                    acc_en,
  input  logic                    acc_clr,
  input  logic                    acc_sat,
  input  logic signed [SUM_W-1:0] sum_in,
  output logic signed [ACC_W-1:0] acc_q,
  output logic                    ovf_q
);

  localparam int unsigned WIDE_W = ACC_W + 1;

  localparam logic signed [ACC_W-1:0] POS_LIMIT = {1'b0, {(ACC_W-1){1'b1}}};
  localparam logic signed [ACC_W-1:0] NEG_LIMIT = {1'b1, {(ACC_W-1){1'b0}}};

  logic signed [WIDE_W-1:0] running;
  logic signed [WIDE_W-1:0] incoming;
  logic signed [WIDE_W-1:0] next_val;
  logic signed [ACC_W-1:0]  clamped;
  logic                     overflowed;

  always_comb begin
    running  = WIDE_W'(acc_q);
    incoming = WIDE_W'(sum_in);
    next_val = acc_en ? (running + incoming) : incoming;

    overflowed = next_val[WIDE_W-1] ^ next_val[WIDE_W-2];

    if (!overflowed)             clamped = next_val[ACC_W-1:0];
    else if (next_val[WIDE_W-1]) clamped = NEG_LIMIT;
    else                         clamped = POS_LIMIT;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_q <= '0;
      ovf_q <= 1'b0;
    end else if (acc_clr) begin
      acc_q <= '0;
      ovf_q <= 1'b0;
    end else if (acc_capture) begin
      acc_q <= acc_sat ? clamped : next_val[ACC_W-1:0];
      ovf_q <= ovf_q | (overflowed & ~acc_sat);
    end
  end

endmodule : macc8_accumulator
