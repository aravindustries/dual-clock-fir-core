vlib work
vmap work work

vlog -sv +acc -suppress 12110 -incr ../../rtl/fir_core/fir_core.v
vlog -sv +acc -suppress 12110 -incr test_fir_core.v

vsim +acc -suppress 12110 -t ps -lib work testbench

log -r /testbench/*

do waveformat.do
run -all

