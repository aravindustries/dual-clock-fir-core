onerror {resume}
quietly WaveActivateNextPane {} 0

add wave -noupdate -divider {Clocks / Reset}
add wave -noupdate /testbench/clk1
add wave -noupdate /testbench/clk2
add wave -noupdate /testbench/rstn

add wave -noupdate -divider {TB -> DUT Inputs}
add wave -noupdate /testbench/valid_in
add wave -noupdate -radix decimal     /testbench/din
add wave -noupdate -radix hexadecimal /testbench/din

add wave -noupdate /testbench/cload
add wave -noupdate -radix decimal     /testbench/caddr
add wave -noupdate -radix hexadecimal /testbench/caddr
add wave -noupdate -radix decimal     /testbench/cin
add wave -noupdate -radix hexadecimal /testbench/cin

add wave -noupdate -divider {DUT Outputs}
add wave -noupdate /testbench/valid_out
add wave -noupdate -radix decimal     /testbench/dout
add wave -noupdate -radix hexadecimal /testbench/dout

add wave -noupdate -divider {Top-level DUT Internals}
add wave -noupdate /testbench/dut/full
add wave -noupdate /testbench/dut/empty
add wave -noupdate -radix decimal     /testbench/dut/fifo_dout
add wave -noupdate -radix hexadecimal /testbench/dut/fifo_dout

add wave -noupdate -divider {FSM / Control (dut.u_fsm)}
add wave -noupdate -radix unsigned /testbench/dut/u_fsm/state
add wave -noupdate /testbench/dut/u_fsm/rd_en
add wave -noupdate /testbench/dut/u_fsm/load_sample
add wave -noupdate /testbench/dut/u_fsm/counter_en
add wave -noupdate /testbench/dut/u_fsm/counter_clear
add wave -noupdate /testbench/dut/u_fsm/done_flag
add wave -noupdate /testbench/dut/u_fsm/valid_out

add wave -noupdate -divider {Counter / Addressing}
add wave -noupdate -radix unsigned /testbench/dut/u_counter/q
add wave -noupdate -radix unsigned /testbench/dut/q_addr_adj
add wave -noupdate -radix unsigned /testbench/dut/caddr_eff

add wave -noupdate -divider {CMEM / IMEM}
add wave -noupdate -radix decimal     /testbench/dut/u_cmem/tap
add wave -noupdate -radix hexadecimal /testbench/dut/u_cmem/tap
add wave -noupdate -radix decimal     /testbench/dut/u_imem/x
add wave -noupdate -radix hexadecimal /testbench/dut/u_imem/x

add wave -noupdate -divider {ALU / MAC (dut.u_alu)}
add wave -noupdate -radix decimal     /testbench/dut/u_alu/product
add wave -noupdate -radix hexadecimal /testbench/dut/u_alu/product
add wave -noupdate -radix decimal     /testbench/dut/u_alu/acc
add wave -noupdate -radix hexadecimal /testbench/dut/u_alu/acc
add wave -noupdate -radix decimal     /testbench/dut/u_alu/acc_shifted
add wave -noupdate -radix hexadecimal /testbench/dut/u_alu/acc_shifted
add wave -noupdate /testbench/dut/u_alu/clear_acc
add wave -noupdate /testbench/dut/u_alu/done_flag

add wave -noupdate -divider {FIFO internals (dut.u_fifo)}
add wave -noupdate -radix binary /testbench/dut/u_fifo/wptr_bin
add wave -noupdate -radix binary /testbench/dut/u_fifo/wptr_gray
add wave -noupdate -radix binary /testbench/dut/u_fifo/rptr_bin
add wave -noupdate -radix binary /testbench/dut/u_fifo/rptr_gray
add wave -noupdate -radix binary /testbench/dut/u_fifo/wq1_rptr_gray
add wave -noupdate -radix binary /testbench/dut/u_fifo/wq2_rptr_gray
add wave -noupdate -radix binary /testbench/dut/u_fifo/rq1_wptr_gray
add wave -noupdate -radix binary /testbench/dut/u_fifo/rq2_wptr_gray

configure wave -namecolwidth 200
configure wave -valuecolwidth 80
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns

update

