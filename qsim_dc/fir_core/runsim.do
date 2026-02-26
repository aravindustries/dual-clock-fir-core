##################################################
#  Modelsim do file to run simulation (SystemVerilog)
#  MS 7/2015  (updated)
##################################################

# Setup
vlib work
vmap work work

# Compile (SystemVerilog enabled)
vlog -sv +acc -suppress 12110 -incr /courses/ee6321/share/ibm13rflpvt/verilog/ibm13rflpvt.v
vlog -sv +acc -suppress 12110 -incr ../../dc/fir_core/fir_core.nl.v
vlog -sv +acc -suppress 12110 -incr test_fir_core.v

# Run Simulator
# SDF from DC is annotated for the timing check
vsim -voptargs=+acc -t ps -lib work -sdftyp dut=../../dc/fir_core/fir_core.syn.sdf testbench

# Waves (optional)
do waveformat.do

# -----------------------------
# VCD dump for PrimeTime power
# -----------------------------
# Make sure output directory exists (relative to current sim dir)
file mkdir ../../qsim_dc
file mkdir ../../qsim_dc/fir_core

# Write VCD
vcd file ../../qsim_dc/fir_core/fir_core.vcd

# Dump only DUT hierarchy (recommended for smaller VCD + matches PT strip_path "testbench/dut")
vcd add -r /testbench/dut/*

# If you prefer dumping everything, use this instead:
# vcd add -r /testbench/*

# Run
run -all

# Flush/close VCD cleanly
vcd flush
vcd off
quit -f
