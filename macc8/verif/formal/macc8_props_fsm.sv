// -----------------------------------------------------------------------------
// macc8_props_fsm.sv
// Formal properties for macc8_fsm, written as clocked immediate assertions so
// they parse under vanilla open-source Yosys (which does not accept inline-
// clocked `assert property`). Properties are expressed purely over the FSM I/O.
// FSM outputs are a one-hot view of the state:
//   accept_en=IDLE, mul_capture=MUL, acc_capture=ADACC, done_pulse=DONE,
//   busy = !IDLE.
// -----------------------------------------------------------------------------
module macc8_props_fsm (
  input logic clk,
  input logic rst_n,
  input logic start_pulse,
  input logic auto_start,
  input logic act_full
);
  logic busy, done_pulse, mul_capture, acc_capture, consume, accept_en;

  macc8_fsm dut (
    .clk(clk), .rst_n(rst_n),
    .start_pulse(start_pulse), .auto_start(auto_start), .act_full(act_full),
    .busy(busy), .done_pulse(done_pulse),
    .mul_capture(mul_capture), .acc_capture(acc_capture),
    .consume(consume), .accept_en(accept_en)
  );

  logic go;
  assign go = act_full & (start_pulse | auto_start);

  logic past_valid;
  initial past_valid = 1'b0;
  always @(posedge clk) past_valid <= 1'b1;

  always @(posedge clk) begin
    if (!rst_n) begin
      // reset: engine is idle
      a_reset_idle: assert (accept_en && !busy && !done_pulse);
    end else begin
      // ---- single-cycle invariants ----
      a_idle_xor_busy:  assert (accept_en == !busy);
      a_cap_excl:       assert (!(mul_capture && acc_capture));
      a_done_is_phase:  assert (!done_pulse || busy);
      a_consume_valid:  assert (!consume || (accept_en && go));

      // ---- temporal (guarded so we never check across the reset edge) ----
      if (past_valid && $past(rst_n)) begin
        // fixed 3-cycle pipeline progression: MUL -> ADACC -> DONE -> IDLE
        a_mul_to_adacc:  assert (!$past(mul_capture) || acc_capture);
        a_adacc_to_done: assert (!$past(acc_capture) || done_pulse);
        a_done_to_idle:  assert (!$past(done_pulse) || accept_en);

        // causality: done only right after ADACC; MUL only entered via go
        a_done_after_adacc: assert (!done_pulse || $past(acc_capture));
        a_mul_needs_go:     assert (!(mul_capture && !$past(mul_capture)) || $past(go));

        // start-before-load / no-op: stay IDLE while there is no go
        a_stay_idle: assert (!($past(accept_en) && !$past(go)) || accept_en);
      end
    end
  end

endmodule
