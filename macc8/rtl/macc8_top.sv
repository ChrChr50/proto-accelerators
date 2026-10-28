module macc8_top (
  input  logic                        clk,
  input  logic                        rst_n,
  input  logic [7:0]                  reg_addr,
  input  logic [31:0]                 reg_wdata,
  input  logic                        reg_write,
  output logic [31:0]                 reg_rdata,
  input  logic [macc8_pkg::ACT_W-1:0] act_data,
  input  logic                        act_valid,
  output logic                        act_ready,
  output logic                        busy,
  output logic                        done
);
  localparam int unsigned LANES = macc8_pkg::LANES;
  localparam int unsigned ACT_W = macc8_pkg::ACT_W;
  localparam int unsigned WT_W  = macc8_pkg::WT_W;
  localparam int unsigned ACC_W = macc8_pkg::ACC_W;

  logic core_rst_n;

  macc8_reset_sync u_rst_sync (
    .clk   (clk),
    .arst_n(rst_n),
    .srst_n(core_rst_n)
  );

  logic                    start_pulse;
  logic                    acc_clr_cmd;
  logic                    done_clr_cmd;
  logic                    soft_rst;
  logic                    auto_start;
  logic                    acc_en;
  logic                    acc_sat;
  logic [3:0]              active_lanes;
  logic [LANES*WT_W-1:0]   wt_bus;

  logic                    act_full;
  logic [LANES*ACT_W-1:0]  act_bus;

  logic                    mul_capture;
  logic                    acc_capture;
  logic                    consume;
  logic                    accept_en;
  logic                    done_pulse;

  logic signed [ACC_W-1:0] acc_out;
  logic                    acc_ovf;

  logic wipe_acc;
  assign wipe_acc = acc_clr_cmd | soft_rst;
  assign done     = done_pulse;

  macc8_regfile u_regfile (
    .clk         (clk),
    .rst_n       (core_rst_n),
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

  macc8_serial_rx u_serial_rx (
    .clk         (clk),
    .rst_n       (core_rst_n),
    .accept_en   (accept_en),
    .consume     (consume),
    .active_lanes(active_lanes),
    .act_data    (act_data),
    .act_valid   (act_valid),
    .act_ready   (act_ready),
    .act_full    (act_full),
    .act_bus     (act_bus)
  );

  macc8_fsm u_fsm (
    .clk        (clk),
    .rst_n      (core_rst_n),
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

  macc8_datapath u_datapath (
    .clk         (clk),
    .rst_n       (core_rst_n),
    .mul_capture (mul_capture),
    .acc_capture (acc_capture),
    .acc_clr     (wipe_acc),
    .acc_en      (acc_en),
    .acc_sat     (acc_sat),
    .active_lanes(active_lanes),
    .act_bus     (act_bus),
    .wt_bus      (wt_bus),
    .acc_q       (acc_out),
    .ovf_q       (acc_ovf)
  );

endmodule : macc8_top
