# MACC-8 timing constraints: 100 MHz (10 ns) at the Sky130 slow corner.
#
# The data inputs are listed by hand (every macc8_top input except clk).
# The usual all_inputs + remove_from_collection trick doesn't work because
# OpenSTA, the STA in OpenLane's image, has no remove_from_collection and
# just says "invalid command name". If macc8_top's ports change, update
# this list.
set clk_period 10.0
set data_inputs {rst_n reg_addr reg_wdata reg_write act_data act_valid}

create_clock -name clk -period $clk_period [get_ports clk]

# 20% of the period for the outside world, as a starting point
set io_delay 2.0
set_input_delay  -clock clk $io_delay [get_ports $data_inputs]
set_output_delay -clock clk $io_delay [all_outputs]

set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition  0.15 [get_clocks clk]

# rst_n asserts asynchronously, so there is nothing to time on it
set_false_path -from [get_ports rst_n]

# plausible drive and load for a block-level harden
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 -pin Y [get_ports $data_inputs]
set_load 0.05 [all_outputs]
