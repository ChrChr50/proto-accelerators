// -----------------------------------------------------------------------------
// macc8_fsm.sv
// Compute sequencer. Explicit 2-bit encoding (see macc8_pkg::state_e).
//   IDLE  : accept serial activations; on (act_full & (start | auto_start)) -> MUL
//   MUL   : capture products                                                -> ADACC
//   ADACC : adder tree + accumulate                                         -> DONE
//   DONE  : assert done_pulse for one cycle                                 -> IDLE
// busy is high in MUL/ADACC/DONE. done_pulse is a single-cycle Moore output.
//
// Package symbols are referenced with the macc8_pkg:: scope (no wildcard import)
// so the file parses under vanilla Yosys read_verilog as well as slang/Verilator.
// -----------------------------------------------------------------------------
module macc8_fsm (
  input  logic clk,
  input  logic rst_n,
  input  logic start_pulse,
  input  logic auto_start,
  input  logic act_full,
  output logic busy,
  output logic done_pulse,
  output logic mul_capture,
  output logic acc_capture,
  output logic consume,
  output logic accept_en
);
  // local aliases so the body reads naturally
  typedef macc8_pkg::state_e state_e;
  localparam state_e S_IDLE  = macc8_pkg::S_IDLE;
  localparam state_e S_MUL   = macc8_pkg::S_MUL;
  localparam state_e S_ADACC = macc8_pkg::S_ADACC;
  localparam state_e S_DONE  = macc8_pkg::S_DONE;

  state_e state_q, state_d;
  logic   go;

  assign go = act_full & (start_pulse | auto_start);

  // ---- state register -------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state_q <= S_IDLE;
    else        state_q <= state_d;
  end

  // ---- next-state -----------------------------------------------------------
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      S_IDLE  : if (go) state_d = S_MUL;
      S_MUL   :         state_d = S_ADACC;
      S_ADACC :         state_d = S_DONE;
      S_DONE  :         state_d = S_IDLE;
      default :         state_d = S_IDLE;
    endcase
  end

  // ---- Moore outputs --------------------------------------------------------
  always_comb begin
    busy        = (state_q != S_IDLE);
    accept_en   = (state_q == S_IDLE);
    mul_capture = (state_q == S_MUL);
    acc_capture = (state_q == S_ADACC);
    done_pulse  = (state_q == S_DONE);
    consume     = (state_q == S_IDLE) & go;
  end

endmodule : macc8_fsm
