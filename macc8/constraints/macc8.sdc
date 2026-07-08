# -----------------------------------------------------------------------------
# macc8.sdc — timing constraints for MACC-8
# Target: 100 MHz (10 ns) at the Sky130 slow corner. See design spec.
# -----------------------------------------------------------------------------
set clk_period 10.0

create_clock -name clk -period $clk_period [get_ports clk]

# input/output external delays (~20% of period as a starting budget)
set io_delay 2.0
set_input_delay  -clock clk $io_delay [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk $io_delay [all_outputs]

# clock uncertainty / transition budget
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition  0.15 [get_clocks clk]

# reset is async-assert / sync-deassert -> assertion path is not timed
set_false_path -from [get_ports rst_n]

# reasonable driving/load assumptions for a block-level harden
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y [remove_from_collection [all_inputs] [get_ports clk]]
set_load 0.05 [all_outputs]
