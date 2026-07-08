// -----------------------------------------------------------------------------
// macc8_top.sv
// Top level for the MACC-8 int8 dot-product engine.
//
// Interface (deliberately boring / silicon-robust):
//   clk, rst_n                 - clock and raw async-assert active-low reset
//   reg_addr/wdata/write/rdata - simple synchronous register bus (1-cycle read)
//   act_data/valid/ready       - byte-serial signed int8 activation stream
//   busy, done                 - status/handshake outputs (done = 1-cycle pulse)
//
// A thin bus adapter (e.g. Wishbone) can wrap the register bus without changing
// the core. Register map and behavior are defined in macc8_pkg and the spec.
//
// Package symbols use the macc8_pkg:: scope (no wildcard import) for portability.
// -----------------------------------------------------------------------------
module macc8_top (
  input  logic                        clk,
  input  logic                        rst_n,       // raw async-assert active-low reset
  // register bus
  input  logic [7:0]                  reg_addr,
  input  logic [31:0]                 reg_wdata,
  input  logic                        reg_write,
  output logic [31:0]                 reg_rdata,
  // serial activation input
  input  logic [macc8_pkg::ACT_W-1:0] act_data,
  input  logic                        act_valid,
  output logic                        act_ready,
  // status / handshake
  output logic                        busy,
  output logic                        done
);
  localparam int unsigned LANES = macc8_pkg::LANES;
  localparam int unsigned ACT_W = macc8_pkg::ACT_W;
  localparam int unsigned WT_W  = macc8_pkg::WT_W;
  localparam int unsigned ACC_W = macc8_pkg::ACC_W;

  // ---- reset synchronizer ---------------------------------------------------
  logic rst_n_sync;
  macc8_reset_sync u_rst_sync (
    .clk   (clk),
    .arst_n(rst_n),
    .srst_n(rst_n_sync)
  );

  // ---- inter-block nets -----------------------------------------------------
  logic                     start_pulse;
  logic                     acc_clr_cmd;
  logic                     done_clr_cmd;
  logic                     soft_rst;
  logic                     auto_start;
  logic                     acc_en;
  logic                     acc_sat;
  logic [3:0]               active_lanes;
  logic [LANES*WT_W-1:0]    wt_bus;

  logic                     act_full;
  logic [LANES*ACT_W-1:0]   act_bus;

  logic                     mul_capture;
  logic                     acc_capture;
  logic                     consume;
  logic                     accept_en;
  logic                     done_pulse;

  logic signed [ACC_W-1:0]  acc_out;
  logic                     acc_ovf;

  logic                     acc_clr;
  assign acc_clr = acc_clr_cmd | soft_rst;   // soft reset clears accumulator + flag
  assign done    = done_pulse;

  // ---- register file --------------------------------------------------------
  macc8_regfile u_regfile (
    .clk         (clk),
    .rst_n       (rst_n_sync),
    .reg_addr    (reg_addr),
    .reg_wdata   (reg_wdata),
    .reg_write   (reg_write),
    .reg_rdata   (reg_rdata),
    .start_pulse (start_pulse),
    .acc_clr_cmd (acc_clr_cmd),
    .done_clr_cmd(done_clr_cmd),
    .soft_rst    (soft_rst),
    .auto_start  (auto_start),
    .acc_en      (acc_en),
    .acc_sat     (acc_sat),
    .active_lanes(active_lanes),
    .wt_bus      (wt_bus),
    .busy        (busy),
    .done_pulse  (done_pulse),
    .acc_ovf     (acc_ovf),
    .acc_out     (acc_out)
  );

  // ---- serial activation front end ------------------------------------------
  macc8_serial_rx u_serial_rx (
    .clk         (clk),
    .rst_n       (rst_n_sync),
    .accept_en   (accept_en),
    .consume     (consume),
    .active_lanes(active_lanes),
    .act_data    (act_data),
    .act_valid   (act_valid),
    .act_ready   (act_ready),
    .act_full    (act_full),
    .act_bus     (act_bus)
  );

  // ---- control FSM ----------------------------------------------------------
  macc8_fsm u_fsm (
    .clk        (clk),
    .rst_n      (rst_n_sync),
    .start_pulse(start_pulse),
    .auto_start (auto_start),
    .act_full   (act_full),
    .busy       (busy),
    .done_pulse (done_pulse),
    .mul_capture(mul_capture),
    .acc_capture(acc_capture),
    .consume    (consume),
    .accept_en  (accept_en)
  );

  // ---- datapath -------------------------------------------------------------
  macc8_datapath u_datapath (
    .clk         (clk),
    .rst_n       (rst_n_sync),
    .mul_capture (mul_capture),
    .acc_capture (acc_capture),
    .acc_clr     (acc_clr),
    .acc_en      (acc_en),
    .acc_sat     (acc_sat),
    .active_lanes(active_lanes),
    .act_bus     (act_bus),
    .wt_bus      (wt_bus),
    .acc_q       (acc_out),
    .ovf_q       (acc_ovf)
  );

endmodule : macc8_top
