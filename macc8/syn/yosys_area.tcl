# -----------------------------------------------------------------------------
# yosys_area.tcl — quick technology-independent complexity/area proxy.
# Runs generic synthesis and reports cell + flip-flop counts WITHOUT a PDK,
# so you can sanity-check RTL changes fast before a full OpenLane harden.
#
#   yosys -c syn/yosys_area.tcl        (run from workspace root)
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
yosys stat
puts "NOTE: counts above are technology-independent. Flip-flops approximate"
puts "state footprint (~336: 128 product-pipe + 64 weights + 64 act regs +"
puts "32 accumulator + 32 read-data + config/counter/FSM/reset-sync)."
puts "XOR/XNOR/AOI-heavy combinational cells reflect the 8 signed multipliers"
puts "and the adder tree. Real Sky130 area/timing come from OpenLane."
