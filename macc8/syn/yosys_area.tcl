# Generic synthesis with no PDK. Gives a rough cell/flop count and makes sure
# the RTL synthesizes cleanly.
#
#   yosys -c syn/yosys_area.tcl                         output in reports/
#   MACC8_REPORT_DIR=<dir> yosys -c syn/yosys_area.tcl  output in <dir>
#
# `make synth-check` points MACC8_REPORT_DIR at a fresh
# reports/<ts>_synth-check/ folder.
#
# Exits nonzero on undriven nets, nets with several drivers, anything
# `check -assert` objects to, or a latch. Real Sky130 numbers come from
# OpenLane (scripts/run_gds.sh).
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

# Fail the run rather than warn. The cell globs are in braces because this is
# Tcl: a bare $_DLATCH_* gets read as a Tcl variable and dies with "can't
# read '_DLATCH_'" before Yosys sees it.
yosys check -assert
yosys select -assert-none {t:$_DLATCH_*}
yosys select -assert-none {t:$_DLATCHSR_*}

yosys tee -o $report_dir/yosys_stat.log stat

puts "These counts are technology-independent; OpenLane (scripts/run_gds.sh)"
puts "gives the real Sky130 area and timing."
puts "All checks passed: no undriven or multi-driven nets, nothing"
puts "unsynthesizable, no latches."
puts "stat output saved to $report_dir/yosys_stat.log"
