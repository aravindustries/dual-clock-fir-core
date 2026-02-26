set clk1_period           100000.0
set clk2_period           1000.0

set clk_uncertainty       0.0
set clk_transition        0.010
set typical_input_delay   0.05
set typical_output_delay  0.05
set typical_wire_load     0.005

if {[sizeof_collection [get_ports -quiet clk1]] > 0} {
    create_clock -name clk1 -period $clk1_period [get_ports clk1]
}

if {[sizeof_collection [get_ports -quiet clk2]] > 0} {
    create_clock -name clk2 -period $clk2_period [get_ports clk2]
}

if {[sizeof_collection [get_clocks -quiet clk1]] > 0} {
    set_clock_uncertainty $clk_uncertainty [get_clocks clk1]
    set_clock_transition  $clk_transition  [get_clocks clk1]
}
if {[sizeof_collection [get_clocks -quiet clk2]] > 0} {
    set_clock_uncertainty $clk_uncertainty [get_clocks clk2]
    set_clock_transition  $clk_transition  [get_clocks clk2]
}

if {[sizeof_collection [get_clocks -quiet clk1]] > 0 && \
    [sizeof_collection [get_clocks -quiet clk2]] > 0} {
    set_clock_groups -asynchronous -group {clk1} -group {clk2}
}

set non_clock_inputs [remove_from_collection [all_inputs] [get_ports -quiet {clk1 clk2}]]

set drv [get_lib_cells -quiet */INVX1TS]
if {[sizeof_collection $drv] == 0} { set drv [get_lib_cells -quiet */INVX1] }

if {[sizeof_collection $drv] > 0} {
    set drv_name [get_object_name [index_collection $drv 0]]
    set_driving_cell -lib_cell $drv_name $non_clock_inputs
} else {
    set_drive 0 $non_clock_inputs
}

set clk1_inputs {}
if {[sizeof_collection [get_ports -quiet valid_in]] > 0} { set clk1_inputs [add_to_collection $clk1_inputs [get_ports valid_in]] }
if {[sizeof_collection [get_ports -quiet din]]      > 0} { set clk1_inputs [add_to_collection $clk1_inputs [get_ports din]] }

set clk2_inputs {}
if {[sizeof_collection [get_ports -quiet cload]] > 0} { set clk2_inputs [add_to_collection $clk2_inputs [get_ports cload]] }
if {[sizeof_collection [get_ports -quiet caddr]] > 0} { set clk2_inputs [add_to_collection $clk2_inputs [get_ports caddr]] }
if {[sizeof_collection [get_ports -quiet cin]]   > 0} { set clk2_inputs [add_to_collection $clk2_inputs [get_ports cin]] }

if {[sizeof_collection [get_clocks -quiet clk1]] > 0 && [sizeof_collection $clk1_inputs] > 0} {
    set_input_delay $typical_input_delay $clk1_inputs -clock clk1
}

if {[sizeof_collection [get_clocks -quiet clk2]] > 0 && [sizeof_collection $clk2_inputs] > 0} {
    set_input_delay $typical_input_delay $clk2_inputs -clock clk2
}

if {[sizeof_collection [get_clocks -quiet clk2]] > 0} {
    set_output_delay $typical_output_delay [all_outputs] -clock clk2
}

if {[sizeof_collection [get_ports -quiet rstn]] > 0} {
    set_false_path -from [get_ports rstn]
}

set_load $typical_wire_load [all_outputs]

