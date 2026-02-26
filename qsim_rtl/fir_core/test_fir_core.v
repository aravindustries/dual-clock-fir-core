`timescale 1ns/1ps

`define X_FILE         "../../matlab/x_q15_in_hex.txt"
`define C_FILE         "../../matlab/cmem_in_hex.txt"
`define YQ_FILE        "../../matlab/y_q79_out.txt"
`define YF32_GOLD_HEX  "../../matlab/y_f32_gold_unquant_hex.txt"

module testbench;

  localparam int  NUM_TAPS        = 64;
  localparam int  NUM_SAMPLES     = 256;
  localparam int  OUT_LAT         = 1;
  localparam int  MAX_IDLE_CYCLES = 5000;
  localparam real Q79_SCALE       = 512.0;

  reg                clk1;
  reg                clk2;
  reg                rstn;

  reg                valid_in;
  reg  signed [15:0] din;

  reg                cload;
  reg        [5:0]   caddr;
  reg  signed [15:0] cin;

  wire signed [15:0] dout;
  wire               valid_out;

  fir_core dut (
    .clk1      (clk1),
    .clk2      (clk2),
    .rstn      (rstn),
    .valid_in  (valid_in),
    .din       (din),
    .cload     (cload),
    .caddr     (caddr),
    .cin       (cin),
    .dout      (dout),
    .valid_out (valid_out)
  );

  initial begin
    clk1 = 1'b0;
    forever #50000 clk1 = ~clk1;
  end

  initial begin
    clk2 = 1'b0;
    #25000;
    forever #500 clk2 = ~clk2;
  end

  reg  signed [15:0] x_mem        [0:NUM_SAMPLES-1];
  reg  signed [15:0] yq_mem       [0:NUM_SAMPLES-1];
  reg  signed [15:0] c_mem        [0:NUM_TAPS-1];
  reg  [31:0]        ygold_u32mem [0:NUM_SAMPLES-1];

  initial begin
    $readmemh(`X_FILE,        x_mem);
    $readmemh(`YQ_FILE,       yq_mem);
    $readmemh(`C_FILE,        c_mem);
    $readmemh(`YF32_GOLD_HEX, ygold_u32mem);
    $display("%t: Loaded vectors: X=%s, C=%s, YQ=%s, YF32_HEX=%s",
             $time, `X_FILE, `C_FILE, `YQ_FILE, `YF32_GOLD_HEX);
  end

  initial begin
    rstn     = 1'b0;
    valid_in = 1'b0;
    din      = 16'sd0;
    cload    = 1'b0;
    caddr    = 6'd0;
    cin      = 16'sd0;
    #200000;
    rstn = 1'b1;
  end

  wire [2:0]          dbg_state         = dut.u_fsm.state;
  wire [5:0]          dbg_q             = dut.u_counter.q;
  wire [15:0]         dbg_tap           = dut.u_cmem.tap;
  wire [15:0]         dbg_x             = dut.u_imem.x;
  wire                dbg_empty         = dut.empty;
  wire                dbg_full          = dut.full;
  wire                dbg_rd_en         = dut.rd_en;
  wire                dbg_load_sample   = dut.load_sample;
  wire                dbg_counter_clear = dut.counter_clear;
  wire                dbg_done_flag     = dut.done_flag;
  wire signed [15:0]  dbg_acc_sh        = dut.acc_shifted;

  integer i;
  initial begin : LOAD_COEFFS
    @(posedge rstn);
    cload = 1'b1;
    for (i = 0; i < NUM_TAPS; i = i + 1) begin
      @(negedge clk2);
      caddr = i[5:0];
      cin   = c_mem[i];
      @(posedge clk2);
      $display("%t: CMEM load: caddr=%0d, cin=%0d (0x%0h)",
               $time, caddr, cin, cin);
    end
    @(negedge clk2);
    cload = 1'b0;
    $display("%t: Finished CMEM load", $time);
  end

  integer in_idx;
  initial begin : DRIVE_INPUTS
    in_idx = 0;
    @(posedge rstn);
    @(negedge cload);
    repeat (5) @(posedge clk1);

    while (in_idx < NUM_SAMPLES) begin
      @(negedge clk1);
      if (!dut.full) begin
        din      = x_mem[in_idx];
        valid_in = 1'b1;
        $display("%t: IN[%0d] = %0d (0x%0h)", $time, in_idx, din, din);
        in_idx   = in_idx + 1;
      end else begin
        valid_in = 1'b0;
      end
      @(posedge clk1);
      #1 valid_in = 1'b0;
    end
  end

  integer out_evt_idx;
  integer compare_idx;
  integer match_count, mismatch_count;
  integer idle_cycles;

  reg signed [15:0] y_dut_q79;
  reg signed [15:0] y_exp_q79;

  real      y_dut_real;
  real      y_exp_real;
  real      diff_r;
  real      abs_diff_r;
  shortreal ygold_sr;

  real sse;
  real rmse;
  real nrmse_avg;

  real exp_min_r;
  real exp_max_r;

  real    max_abs_err;
  integer max_err_idx;
  real    max_err_dut_real;
  real    max_err_gold_real;
  real    nrmse_worst;

  integer y_exp_i;
  integer y_dut_i;

  initial begin
    out_evt_idx        = 0;
    compare_idx        = 0;
    match_count        = 0;
    mismatch_count     = 0;
    idle_cycles        = 0;

    sse                = 0.0;
    rmse               = 0.0;
    nrmse_avg          = 0.0;
    exp_min_r          = 0.0;
    exp_max_r          = 0.0;

    diff_r             = 0.0;
    abs_diff_r         = 0.0;

    max_abs_err        = 0.0;
    max_err_idx        = -1;
    max_err_dut_real   = 0.0;
    max_err_gold_real  = 0.0;
    nrmse_worst        = 0.0;

    y_exp_i            = 0;
    y_dut_i            = 0;
    ygold_sr           = 0.0;
  end

  task automatic print_summary_and_finish;
    real range_r;
    begin
      range_r = (exp_max_r - exp_min_r);

      if (compare_idx > 0) begin
        rmse = $sqrt(sse / real'(compare_idx));
        if (range_r != 0.0) begin
          nrmse_avg   = rmse / range_r;
          nrmse_worst = max_abs_err / range_r;
        end else begin
          nrmse_avg   = 0.0;
          nrmse_worst = 0.0;
        end
      end else begin
        rmse        = 0.0;
        nrmse_avg   = 0.0;
        nrmse_worst = 0.0;
      end

      $display("==================================================");
      $display("FIR verification finished.");
      $display("Matches         : %0d", match_count);
      $display("Mismatches      : %0d", mismatch_count);
      $display("Avg NRMSE   (RMSE/(ymax-ymin))        : %0.6f", nrmse_avg);
      $display("Worst NRMSE (max|e|/(ymax-ymin))      : %0.6f", nrmse_worst);
      $display("Expected float range used for norm    : [%0.9g, %0.9g] (range=%0.9g)",
               exp_min_r, exp_max_r, range_r);
      if (max_err_idx >= 0) begin
        $display("Worst error sample idx                : %0d", max_err_idx);
        $display("  DUT_REAL=%0.9g  GOLD_F32=%0.9g  |e|=%0.9g",
                 max_err_dut_real, max_err_gold_real, max_abs_err);
      end
      $display("==================================================");
      #1000;
      $finish;
    end
  endtask

  always @(posedge clk2) begin
    if (!rstn) begin
      idle_cycles = 0;
    end else begin
      if (valid_out) idle_cycles = 0;
      else           idle_cycles = idle_cycles + 1;

      if ((in_idx >= NUM_SAMPLES) && (idle_cycles >= MAX_IDLE_CYCLES)) begin
        print_summary_and_finish();
      end
    end
  end

  always @(posedge clk2) begin
    if (rstn && valid_out) begin
      #1;
      y_dut_q79 = dout;

      if (out_evt_idx >= OUT_LAT) begin
        y_exp_q79 = yq_mem[compare_idx];

        y_exp_i = $signed(y_exp_q79);
        y_dut_i = $signed(y_dut_q79);

        if (y_dut_q79 === y_exp_q79) match_count++;
        else                         mismatch_count++;

        y_dut_real = real'(y_dut_i) / Q79_SCALE;

        ygold_sr   = $bitstoshortreal(ygold_u32mem[compare_idx]);
        y_exp_real = real'(ygold_sr);

        if (compare_idx == 0) begin
          exp_min_r = y_exp_real;
          exp_max_r = y_exp_real;
        end else begin
          if (y_exp_real < exp_min_r) exp_min_r = y_exp_real;
          if (y_exp_real > exp_max_r) exp_max_r = y_exp_real;
        end

        diff_r     = (y_exp_real - y_dut_real);
        abs_diff_r = (diff_r < 0.0) ? -diff_r : diff_r;

        sse = sse + (diff_r * diff_r);

        if (abs_diff_r > max_abs_err) begin
          max_abs_err       = abs_diff_r;
          max_err_idx       = compare_idx;
          max_err_dut_real  = y_dut_real;
          max_err_gold_real = y_exp_real;
        end

        $display("%t: OUT_EVT[%0d] DUT_Q79=%0d (0x%0h) EXP_Q79[%0d]=%0d (0x%0h)  %s  |  DUT_REAL=%0.9g  GOLD_F32HEX=0x%08X GOLD_F32=%0.9g diff=%0.9g  {state=%0d, q=%0d, empty=%b, full=%b, rd_en=%b, load_sample=%b, counter_clear=%b, done_flag=%b, acc_shifted=%0d}",
                 $time,
                 out_evt_idx, y_dut_q79, y_dut_q79,
                 compare_idx, y_exp_q79, y_exp_q79,
                 (y_dut_q79 === y_exp_q79) ? "[OK]" : "**MISMATCH**",
                 y_dut_real, ygold_u32mem[compare_idx], y_exp_real, diff_r,
                 dbg_state, dbg_q, dbg_empty, dbg_full,
                 dbg_rd_en, dbg_load_sample, dbg_counter_clear,
                 dbg_done_flag, dbg_acc_sh);

        compare_idx++;

        if (compare_idx == NUM_SAMPLES) begin
          print_summary_and_finish();
        end
      end

      out_evt_idx++;
    end
  end

endmodule

