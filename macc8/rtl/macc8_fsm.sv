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
  typedef macc8_pkg::state_e state_e;
  localparam state_e S_IDLE  = macc8_pkg::S_IDLE;
  localparam state_e S_MUL   = macc8_pkg::S_MUL;
  localparam state_e S_ADACC = macc8_pkg::S_ADACC;
  localparam state_e S_DONE  = macc8_pkg::S_DONE;

  state_e cur_state, nxt_state;
  logic   fire;

  assign fire = act_full & (start_pulse | auto_start);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) cur_state <= S_IDLE;
    else        cur_state <= nxt_state;
  end

  always_comb begin
    nxt_state = cur_state;
    unique case (cur_state)
      S_IDLE  : if (fire) nxt_state = S_MUL;
      S_MUL   :           nxt_state = S_ADACC;
      S_ADACC :           nxt_state = S_DONE;
      S_DONE  :           nxt_state = S_IDLE;
      default :           nxt_state = S_IDLE;
    endcase
  end

  always_comb begin
    accept_en   = (cur_state == S_IDLE);
    busy        = !accept_en;
    mul_capture = (cur_state == S_MUL);
    acc_capture = (cur_state == S_ADACC);
    done_pulse  = (cur_state == S_DONE);
    consume     = accept_en & fire;
  end

endmodule : macc8_fsm
