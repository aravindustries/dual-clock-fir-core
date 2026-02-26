# ------------------------------------------------------------
# FIR core timing constraints (units assumed in ns)
# clk1: 10 kS/s  -> 10 kHz  -> 100 us period  -> 100000 ns
# clk2: 1 MHz    -> 1 us period    -> 1000 ns
# ------------------------------------------------------------

set clk1_period           100000.0
set clk2_period           1000.0

set clk_uncertainty       0.0
set clk_transition        0.010
set typical_input_delay   0.05
set typical_output_delay  0.05
set typical_wire_load     0.005

# ------------------------------------------------------------
# Clocks
# ------------------------------------------------------------
if {[sizeof_collection [get_ports clk1]] > 0} {
    create_clock -name clk1 -period $clk1_period [get_ports clk1]
    set_drive 0 [get_clocks clk1]
}

if {[sizeof_collection [get_ports clk2]] > 0} {
    create_clock -name clk2 -period $clk2_period [get_ports clk2]
    set_drive 0 [get_clocks clk2]
}

set_clock_uncertainty  $clk_uncertainty [get_clocks {clk1 clk2}]
set_clock_transition   $clk_transition  [get_clocks {clk1 clk2}]

set_fix_hold           [all_clocks]
set_dont_touch_network [get_ports {clk1 clk2}]
set_ideal_network      [get_ports {clk1 clk2}]

# Treat the two clocks as asynchronous (CDC handled structurally via FIFO)
if {[sizeof_collection [get_clocks clk1]] > 0 && \
    [sizeof_collection [get_clocks clk2]] > 0} {

    set_clock_groups -asynchronous \
        -group {clk1} \
        -group {clk2}
}

# ------------------------------------------------------------
# I/O constraints
# ------------------------------------------------------------
# Non-clock inputs (exclude clocks)
set non_clock_inputs [remove_from_collection [all_inputs] [get_ports {clk1 clk2}]]

# Give them a generic driver
set_driving_cell -lib_cell INVX1TS $non_clock_inputs

# Split inputs by domain for fir_core:
#  - clk1 domain: FIFO write side
set clk1_inputs {}
if {[sizeof_collection [get_ports valid_in]] > 0} { set clk1_inputs [add_to_collection $clk1_inputs [get_ports valid_in]] }
if {[sizeof_collection [get_ports din]]      > 0} { set clk1_inputs [add_to_collection $clk1_inputs [get_ports din]] }

#  - clk2 domain: coefficient load / control side
set clk2_inputs {}
if {[sizeof_collection [get_ports cload]] > 0} { set clk2_inputs [add_to_collection $clk2_inputs [get_ports cload]] }
if {[sizeof_collection [get_ports caddr]] > 0} { set clk2_inputs [add_to_collection $clk2_inputs [get_ports caddr]] }
if {[sizeof_collection [get_ports cin]]   > 0} { set clk2_inputs [add_to_collection $clk2_inputs [get_ports cin]] }

# Apply input delays to the appropriate clock
if {[sizeof_collection [get_clocks clk1]] > 0 && [sizeof_collection $clk1_inputs] > 0} {
    set_input_delay $typical_input_delay $clk1_inputs -clock clk1
}

if {[sizeof_collection [get_clocks clk2]] > 0 && [sizeof_collection $clk2_inputs] > 0} {
    set_input_delay $typical_input_delay $clk2_inputs -clock clk2
}

# Outputs are produced on clk2 (dout_reg updates on clk2 when valid_out)
if {[sizeof_collection [get_clocks clk2]] > 0} {
    set_output_delay $typical_output_delay [all_outputs] -clock clk2
}

# ------------------------------------------------------------
# Reset: async, exclude from timing
# ------------------------------------------------------------
if {[sizeof_collection [get_ports rstn]] > 0} {
    set_false_path -from [get_ports rstn]
}

# ------------------------------------------------------------
# Loads
# ------------------------------------------------------------
set_load $typical_wire_load [all_outputs]

