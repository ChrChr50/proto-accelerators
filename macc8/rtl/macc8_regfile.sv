module macc8_regfile (
  input  logic                                        clk,
  input  logic                                        rst_n,
  input  logic [7:0]                                  reg_addr,
  input  logic [31:0]                                 reg_wdata,
  input  logic                                        reg_write,
  output logic [31:0]                                 reg_rdata,
  output logic                                        start_pulse,
  output logic                                        acc_clr_cmd,
  output logic                                        done_clr_cmd,
  output logic                                        soft_rst,
  output logic                                        auto_start,
  output logic                                        acc_en,
  output logic                                        acc_sat,
  output logic [3:0]                                  active_lanes,
  output logic [macc8_pkg::LANES*macc8_pkg::WT_W-1:0] wt_bus,
  input  logic                                        busy,
  input  logic                                        done_pulse,
  input  logic                                        acc_ovf,
  input  logic signed [macc8_pkg::ACC_W-1:0]          acc_out
);
  localparam int unsigned LANES = macc8_pkg::LANES;
  localparam int unsigned WT_W  = macc8_pkg::WT_W;
  localparam int unsigned HALF  = 4 * WT_W;

  localparam logic [7:0] ADDR_CTRL     = macc8_pkg::ADDR_CTRL;
  localparam logic [7:0] ADDR_STATUS   = macc8_pkg::ADDR_STATUS;
  localparam logic [7:0] ADDR_CONFIG   = macc8_pkg::ADDR_CONFIG;
  localparam logic [7:0] ADDR_WEIGHTS0 = macc8_pkg::ADDR_WEIGHTS0;
  localparam logic [7:0] ADDR_WEIGHTS1 = macc8_pkg::ADDR_WEIGHTS1;
  localparam logic [7:0] ADDR_ACC_OUT  = macc8_pkg::ADDR_ACC_OUT;
  localparam logic [7:0] ADDR_ID       = macc8_pkg::ADDR_ID;
  localparam logic [31:0] ID_VALUE     = macc8_pkg::ID_VALUE;

  logic                  auto_r;
  logic                  accum_r;
  logic                  eight_lanes_r;
  logic                  sat_r;
  logic                  act_signed_r;
  logic                  wt_signed_r;
  logic [LANES*WT_W-1:0] weights_r;
  logic                  done_flag_r;

  logic hit_ctrl, hit_config, hit_w_lo, hit_w_hi;
  assign hit_ctrl   = reg_write & (reg_addr == ADDR_CTRL);
  assign hit_config = reg_write & (reg_addr == ADDR_CONFIG);
  assign hit_w_lo   = reg_write & (reg_addr == ADDR_WEIGHTS0);
  assign hit_w_hi   = reg_write & (reg_addr == ADDR_WEIGHTS1);

  assign start_pulse  = hit_ctrl & reg_wdata[0];
  assign acc_clr_cmd  = hit_ctrl & reg_wdata[1];
  assign done_clr_cmd = hit_ctrl & reg_wdata[4];
  assign soft_rst     = hit_ctrl & reg_wdata[5];

  assign auto_start   = auto_r;
  assign acc_en       = accum_r;
  assign acc_sat      = sat_r;
  assign active_lanes = eight_lanes_r ? 4'd8 : 4'd4;
  assign wt_bus       = weights_r;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      auto_r        <= 1'b0;
      accum_r       <= 1'b0;
      eight_lanes_r <= 1'b1;
      sat_r         <= 1'b0;
      act_signed_r  <= 1'b1;
      wt_signed_r   <= 1'b1;
      weights_r     <= '0;
      done_flag_r   <= 1'b0;
    end else begin
      if (hit_ctrl) begin
        accum_r       <= reg_wdata[2];
        auto_r        <= reg_wdata[3];
        eight_lanes_r <= reg_wdata[6];
      end
      if (hit_config) begin
        act_signed_r <= reg_wdata[0];
        wt_signed_r  <= reg_wdata[1];
        sat_r        <= reg_wdata[2];
      end
      if (hit_w_lo) weights_r[0    +: HALF] <= reg_wdata;
      if (hit_w_hi) weights_r[HALF +: HALF] <= reg_wdata;

      if (done_clr_cmd | soft_rst) done_flag_r <= 1'b0;
      else if (done_pulse)         done_flag_r <= 1'b1;
    end
  end

  logic [31:0] read_mux;
  always_comb begin
    unique case (reg_addr)
      ADDR_CTRL     : read_mux = {25'd0, eight_lanes_r, 2'b00, auto_r, accum_r, 2'b00};
      ADDR_STATUS   : read_mux = {29'd0, acc_ovf, done_flag_r, busy};
      ADDR_CONFIG   : read_mux = {29'd0, sat_r, wt_signed_r, act_signed_r};
      ADDR_WEIGHTS0 : read_mux = weights_r[0    +: HALF];
      ADDR_WEIGHTS1 : read_mux = weights_r[HALF +: HALF];
      ADDR_ACC_OUT  : read_mux = acc_out;
      ADDR_ID       : read_mux = ID_VALUE;
      default       : read_mux = 32'd0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) reg_rdata <= 32'd0;
    else        reg_rdata <= read_mux;
  end

endmodule : macc8_regfile
