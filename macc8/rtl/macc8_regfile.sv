// -----------------------------------------------------------------------------
// macc8_regfile.sv
// Simple, robust synchronous register interface (no wait states):
//   - Write:  when reg_write=1, reg_wdata is written to the register at reg_addr.
//   - Read:   reg_rdata is registered and reflects the register at reg_addr from
//             the previous cycle (1-cycle read latency). Reads are side-effect free.
// Pulse-style CTRL bits (start / acc_clr / done_clr / soft_rst) are decoded from
// the write and emitted as single-cycle strobes; they are not stored.
// NOTE: act_signed / wt_signed CONFIG bits are stored for readback but are
// RESERVED / non-functional in v0.1 (datapath is signed-only).
//
// Package symbols use the macc8_pkg:: scope (no wildcard import) for portability.
// -----------------------------------------------------------------------------
module macc8_regfile (
  input  logic                                       clk,
  input  logic                                       rst_n,
  // simple register bus
  input  logic [7:0]                                 reg_addr,
  input  logic [31:0]                                reg_wdata,
  input  logic                                       reg_write,
  output logic [31:0]                                reg_rdata,
  // command strobes to core
  output logic                                       start_pulse,
  output logic                                       acc_clr_cmd,
  output logic                                       done_clr_cmd,
  output logic                                       soft_rst,
  // config to core
  output logic                                       auto_start,
  output logic                                       acc_en,
  output logic                                       acc_sat,
  output logic [3:0]                                 active_lanes,
  output logic [macc8_pkg::LANES*macc8_pkg::WT_W-1:0] wt_bus,
  // status from core
  input  logic                                       busy,
  input  logic                                       done_pulse,
  input  logic                                       acc_ovf,
  input  logic signed [macc8_pkg::ACC_W-1:0]         acc_out
);
  localparam int unsigned LANES = macc8_pkg::LANES;
  localparam int unsigned WT_W  = macc8_pkg::WT_W;

  localparam logic [7:0] ADDR_CTRL     = macc8_pkg::ADDR_CTRL;
  localparam logic [7:0] ADDR_STATUS   = macc8_pkg::ADDR_STATUS;
  localparam logic [7:0] ADDR_CONFIG   = macc8_pkg::ADDR_CONFIG;
  localparam logic [7:0] ADDR_WEIGHTS0 = macc8_pkg::ADDR_WEIGHTS0;
  localparam logic [7:0] ADDR_WEIGHTS1 = macc8_pkg::ADDR_WEIGHTS1;
  localparam logic [7:0] ADDR_ACC_OUT  = macc8_pkg::ADDR_ACC_OUT;
  localparam logic [7:0] ADDR_ID       = macc8_pkg::ADDR_ID;
  localparam logic [31:0] ID_VALUE     = macc8_pkg::ID_VALUE;

  // ---- stored control/config ------------------------------------------------
  logic        ctrl_auto_start_q;
  logic        ctrl_acc_en_q;
  logic        ctrl_lane_sel_q;     // 0 = 4 lanes, 1 = 8 lanes
  logic        cfg_acc_sat_q;
  logic        cfg_act_signed_q;    // reserved (readback only)
  logic        cfg_wt_signed_q;     // reserved (readback only)
  logic [LANES*WT_W-1:0] wt_q;

  // ---- sticky status --------------------------------------------------------
  logic        done_sticky_q;

  // ---- write decode ---------------------------------------------------------
  logic wr_ctrl, wr_config, wr_w0, wr_w1;
  assign wr_ctrl   = reg_write & (reg_addr == ADDR_CTRL);
  assign wr_config = reg_write & (reg_addr == ADDR_CONFIG);
  assign wr_w0     = reg_write & (reg_addr == ADDR_WEIGHTS0);
  assign wr_w1     = reg_write & (reg_addr == ADDR_WEIGHTS1);

  // ---- CTRL pulse strobes (not stored) --------------------------------------
  assign start_pulse  = wr_ctrl & reg_wdata[0];
  assign acc_clr_cmd  = wr_ctrl & reg_wdata[1];
  assign done_clr_cmd = wr_ctrl & reg_wdata[4];
  assign soft_rst     = wr_ctrl & reg_wdata[5];

  // ---- config outputs -------------------------------------------------------
  assign auto_start   = ctrl_auto_start_q;
  assign acc_en       = ctrl_acc_en_q;
  assign acc_sat      = cfg_acc_sat_q;
  assign active_lanes = ctrl_lane_sel_q ? 4'd8 : 4'd4;
  assign wt_bus       = wt_q;

  // ---- stored register updates ----------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ctrl_auto_start_q <= 1'b0;
      ctrl_acc_en_q     <= 1'b0;
      ctrl_lane_sel_q   <= 1'b1;   // default 8 lanes
      cfg_acc_sat_q     <= 1'b0;
      cfg_act_signed_q  <= 1'b1;   // reserved; signed by default
      cfg_wt_signed_q   <= 1'b1;   // reserved; signed by default
      wt_q              <= '0;
      done_sticky_q     <= 1'b0;
    end else begin
      if (wr_ctrl) begin
        ctrl_acc_en_q     <= reg_wdata[2];
        ctrl_auto_start_q <= reg_wdata[3];
        ctrl_lane_sel_q   <= reg_wdata[6];
      end
      if (wr_config) begin
        cfg_act_signed_q <= reg_wdata[0];
        cfg_wt_signed_q  <= reg_wdata[1];
        cfg_acc_sat_q    <= reg_wdata[2];
      end
      if (wr_w0) wt_q[0*WT_W +: 4*WT_W] <= reg_wdata; // lanes 0..3
      if (wr_w1) wt_q[4*WT_W +: 4*WT_W] <= reg_wdata; // lanes 4..7

      // sticky done: set on completion, clear on explicit command or soft reset
      if (done_clr_cmd | soft_rst) done_sticky_q <= 1'b0;
      else if (done_pulse)         done_sticky_q <= 1'b1;
    end
  end

  // ---- read mux (combinational select, registered output) -------------------
  logic [31:0] rdata_c;
  always_comb begin
    unique case (reg_addr)
      // [6]lane_sel [3]auto_start [2]acc_en; pulse bits (start/acc_clr/done_clr/soft_rst) read 0
      ADDR_CTRL     : rdata_c = {25'd0, ctrl_lane_sel_q, 2'b00, ctrl_auto_start_q,
                                 ctrl_acc_en_q, 2'b00};
      ADDR_STATUS   : rdata_c = {29'd0, acc_ovf, done_sticky_q, busy};   // [2]ovf [1]done [0]busy
      ADDR_CONFIG   : rdata_c = {29'd0, cfg_acc_sat_q, cfg_wt_signed_q, cfg_act_signed_q};
      ADDR_WEIGHTS0 : rdata_c = wt_q[0*WT_W +: 4*WT_W];
      ADDR_WEIGHTS1 : rdata_c = wt_q[4*WT_W +: 4*WT_W];
      ADDR_ACC_OUT  : rdata_c = acc_out;
      ADDR_ID       : rdata_c = ID_VALUE;
      default       : rdata_c = 32'd0;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) reg_rdata <= 32'd0;
    else        reg_rdata <= rdata_c;
  end

endmodule : macc8_regfile
