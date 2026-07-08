// -----------------------------------------------------------------------------
// macc8_pkg.sv
// Shared parameters, datapath widths, FSM encoding, and register-map constants.
// Single source of truth for all widths (see design spec / block diagram).
// -----------------------------------------------------------------------------
package macc8_pkg;

  // ---- Datapath widths ------------------------------------------------------
  localparam int unsigned LANES  = 8;   // physical lanes. 4-lane mode is a runtime subset.
  localparam int unsigned ACT_W  = 8;   // signed int8 activation
  localparam int unsigned WT_W   = 8;   // signed int8 weight
  localparam int unsigned PROD_W = 16;  // signed int8 * int8 -> int16 (exact)
  localparam int unsigned TREE_W = 20;  // sum of 8 products; 16 + clog2(8) = 19, rounded to 20
  localparam int unsigned ACC_W  = 32;  // signed int32 accumulator

  // ---- FSM encoding (explicit 2-bit binary) ---------------------------------
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_MUL   = 2'b01,
    S_ADACC = 2'b10,
    S_DONE  = 2'b11
  } state_e;

  // ---- Register map (byte offsets) ------------------------------------------
  localparam logic [7:0] ADDR_CTRL     = 8'h00;
  localparam logic [7:0] ADDR_STATUS   = 8'h04;
  localparam logic [7:0] ADDR_CONFIG   = 8'h08;
  localparam logic [7:0] ADDR_WEIGHTS0 = 8'h0C;  // lanes 0..3
  localparam logic [7:0] ADDR_WEIGHTS1 = 8'h10;  // lanes 4..7
  localparam logic [7:0] ADDR_ACC_OUT  = 8'h14;
  localparam logic [7:0] ADDR_ID       = 8'h18;

  localparam logic [31:0] ID_VALUE = 32'h4D41_4338; // "MAC8"

endpackage : macc8_pkg
