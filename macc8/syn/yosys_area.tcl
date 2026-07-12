# -----------------------------------------------------------------------------
# yosys_area.tcl — technology-independent complexity/area proxy AND a
# synthesizability smoke check, WITHOUT a PDK.
#
#   yosys -c syn/yosys_area.tcl                         (writes to reports/)
#   MACC8_REPORT_DIR=<dir> yosys -c syn/yosys_area.tcl  (writes to <dir>)
#
# `make synth-check` sets MACC8_REPORT_DIR to a timestamped
# reports/<ts>_synth-check/ directory automatically -- see the Makefile and
# reports/README.md.
#
# Fails (nonzero exit) if the design has undriven nets, multiply-driven nets,
# unsynthesizable constructs (yosys 'check -assert'), or inferred latches.
#
# For real Sky130 area/timing/power, use OpenLane (scripts/run_gds.sh).
# -----------------------------------------------------------------------------
if {[info exists ::env(MACC8_REPORT_DIR)]} {
  set report_dir $::env(MACC8_REPORT_DIR)
} else {
  set report_dir "reports"
}
file mkdir $report_dir

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
# NOTE: this is a Tcl script (run via `yosys -c`), so a literal "$" in a cell
# type glob (e.g. $_DLATCH_*) must be brace-quoted -- otherwise Tcl treats it
# as a variable reference and errors with "can't read '_DLATCH_': no such
# variable" before Yosys ever sees the argument. Learned the hard way 2026-07-11.
yosys check -assert
yosys select -assert-none {t:$_DLATCH_*}
yosys select -assert-none {t:$_DLATCHSR_*}

# ---- reports -----------------------------------------------------------------
yosys tee -o $report_dir/yosys_stat.log stat

puts "NOTE: counts above are technology-independent. Real Sky130 area/timing"
puts "come from OpenLane (scripts/run_gds.sh) once the PDK is available."
puts "Checks passed: no undriven/multi-driven nets, no unsynthesizable"
puts "constructs (yosys 'check -assert'), no inferred latches."
puts "Raw stat output: $report_dir/yosys_stat.log"
