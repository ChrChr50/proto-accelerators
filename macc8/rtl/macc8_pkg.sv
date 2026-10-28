package macc8_pkg;

  localparam int unsigned LANES  = 8;
  localparam int unsigned ACT_W  = 8;
  localparam int unsigned WT_W   = 8;
  localparam int unsigned PROD_W = 16;
  localparam int unsigned TREE_W = 20;
  localparam int unsigned ACC_W  = 32;

  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_MUL   = 2'b01,
    S_ADACC = 2'b10,
    S_DONE  = 2'b11
  } state_e;

  localparam logic [7:0] ADDR_CTRL     = 8'h00;
  localparam logic [7:0] ADDR_STATUS   = 8'h04;
  localparam logic [7:0] ADDR_CONFIG   = 8'h08;
  localparam logic [7:0] ADDR_WEIGHTS0 = 8'h0C;
  localparam logic [7:0] ADDR_WEIGHTS1 = 8'h10;
  localparam logic [7:0] ADDR_ACC_OUT  = 8'h14;
  localparam logic [7:0] ADDR_ID       = 8'h18;

  localparam logic [31:0] ID_VALUE = 32'h4D41_4338;

endpackage : macc8_pkg
