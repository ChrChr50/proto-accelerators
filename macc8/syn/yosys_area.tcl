# -----------------------------------------------------------------------------
# yosys_area.tcl — technology-independent complexity/area proxy AND a
# synthesizability smoke check, WITHOUT a PDK.
#
#   yosys -c syn/yosys_area.tcl        (run from workspace root)
#
# Fails (nonzero exit) if the design has undriven nets, multiply-driven nets,
# unsynthesizable constructs (yosys 'check -assert'), or inferred latches.
# Raw stat output is captured to reports/synth_yosys.log (git-ignored,
# regenerable) — see docs/synthesis_summary.md for the curated, committed
# summary template to fill in from that output.
#
# For real Sky130 area/timing/power, use OpenLane (scripts/run_gds.sh).
# -----------------------------------------------------------------------------
set rtl {
  rtl/macc8_pkg.sv
  rtl/macc8_reset_sync.sv
  rtl/macc8_mac_lane.sv
  rtl/macc8_adder_tree.sv
  rtl/macc8_accumulator.sv
  rtl/macc8_datapath.sv
  rtl/macc8_serial_rx.sv
  rtl/macc8_fsm.sv
  rtl/macc8_regfile.sv
  rtl/macc8_top.sv
}
yosys read_verilog -sv {*}$rtl
yosys hierarchy -top macc8_top
yosys synth -top macc8_top -flatten

# ---- synthesizability checks: fail loudly instead of just warning ----------
yosys check -assert
yosys select -assert-none t:$_DLATCH_*
yosys select -assert-none t:$_DLATCHSR_*

# ---- reports -----------------------------------------------------------------
file mkdir reports
yosys tee -o reports/synth_yosys.log stat

puts "NOTE: counts above are technology-independent. Flip-flops approximate"
puts "state footprint (~336: 128 product-pipe + 64 weights + 64 act regs +"
puts "32 accumulator + 32 read-data + config/counter/FSM/reset-sync)."
puts "XOR/XNOR/AOI-heavy combinational cells reflect the 8 signed multipliers"
puts "and the adder tree. Real Sky130 area/timing come from OpenLane."
puts ""
puts "Checks passed: no undriven/multi-driven nets, no unsynthesizable"
puts "constructs (yosys 'check -assert'), no inferred latches."
puts "Raw stat output: reports/synth_yosys.log"
puts "Fill in docs/synthesis_summary.md with these numbers after this run."
