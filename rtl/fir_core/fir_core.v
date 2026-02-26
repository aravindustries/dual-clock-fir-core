`timescale 1ns/1ps





module alu(
  input  wire               clk2,
  input  wire               rstn,
  input  wire               clear_acc,
  input  wire       [15:0]  x,
  input  wire       [15:0]  coeff,
  input  wire               done_flag,
  output reg  signed [31:0] product,
  output reg  signed [40:0] acc,
  output reg  signed [15:0] acc_shifted
);


  wire signed [15:0] x_s     = x;
  wire signed [15:0] coeff_s = coeff;


  wire signed [31:0] prod_s  = x_s * coeff_s;


  wire signed [40:0] prod_ext = {{9{prod_s[31]}}, prod_s};


  wire signed [40:0] acc_s  = acc;
  wire signed [40:0] acc_sh = acc_s >>> 21;

  wire signed [15:0] raw_out = acc_sh[15:0];


  localparam signed [15:0] OUT_MAX = 16'sh7FFF;
  localparam signed [15:0] OUT_MIN = 16'sh8000;


  always @(*) begin
    if (acc_sh > OUT_MAX)
      acc_shifted = OUT_MAX;
    else if (acc_sh < OUT_MIN)
      acc_shifted = OUT_MIN;
    else
      acc_shifted = raw_out;
  end


  always @(posedge clk2 or negedge rstn) begin
    if (!rstn) begin
      product <= 32'sd0;
      acc     <= 41'sd0;
    end else if (clear_acc) begin
      product <= 32'sd0;
      acc     <= 41'sd0;
    end else begin
      product <= prod_s;
      if (!done_flag) begin
        acc <= acc + prod_ext;
      end
    end
  end

endmodule




module counter(
  input  wire       clk2,
  input  wire       rstn,
  input  wire       clear,
  input  wire       en,
  output reg [5:0]  q
);

  always @(posedge clk2 or negedge rstn) begin
    if (!rstn)
      q <= 6'd0;
    else if (clear)
      q <= 6'd0;
    else if (en)
      q <= q + 6'd1;
  end

endmodule




module cmem (
  input  wire        clk,
  input  wire        rstn,
  input  wire        cload,
  input  wire [15:0] cin,
  input  wire [5:0]  caddr,
  output wire [15:0] tap
);

  reg [15:0] taps [0:63];
  integer i;


  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      for (i = 0; i < 64; i = i + 1)
        taps[i] <= 16'sd0;
    end else if (cload) begin
      taps[caddr] <= cin;
    end
  end


  assign tap = taps[caddr];

endmodule






module imem(
  input  wire        clk2,
  input  wire        rstn,
  input  wire        load_sample,
  input  wire [15:0] din,
  input  wire [5:0]  raddr,
  output wire [15:0] x
);

  reg [15:0] X_REG [0:63];
  integer i;


  always @(posedge clk2 or negedge rstn) begin
    if (!rstn) begin
      for (i = 0; i < 64; i = i + 1)
        X_REG[i] <= 16'sd0;
    end else if (load_sample) begin
      X_REG[0] <= din;
      for (i = 63; i > 0; i = i - 1)
        X_REG[i] <= X_REG[i-1];
    end
  end


  assign x = X_REG[raddr];

endmodule






module fifo (

    input  wire               clk1,
    input  wire               rst_wr_n,
    input  wire               valid_in,
    input  wire signed [15:0] din,
    output wire               full,


    input  wire               clk2,
    input  wire               rst_rd_n,
    input  wire               rd_en,
    output reg  signed [15:0] dout,
    output wire               empty
);

    localparam integer DATA_WIDTH = 16;
    localparam integer ADDR_WIDTH = 2;
    localparam integer FIFO_DEPTH = (1 << ADDR_WIDTH);

    reg signed [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];


    reg [ADDR_WIDTH:0] wptr_bin,  wptr_bin_next;
    reg [ADDR_WIDTH:0] wptr_gray, wptr_gray_next;

    reg [ADDR_WIDTH:0] rptr_bin,  rptr_bin_next;
    reg [ADDR_WIDTH:0] rptr_gray, rptr_gray_next;


    reg [ADDR_WIDTH:0] wq1_rptr_gray, wq2_rptr_gray;
    reg [ADDR_WIDTH:0] rq1_wptr_gray, rq2_wptr_gray;

    integer j;


    function [ADDR_WIDTH:0] bin2gray;
      input [ADDR_WIDTH:0] bin;
      begin
        bin2gray = (bin >> 1) ^ bin;
      end
    endfunction


    always @(*) begin
      wptr_bin_next  = wptr_bin;
      wptr_gray_next = wptr_gray;
      if (valid_in && !full) begin
        wptr_bin_next  = wptr_bin + 1'b1;
        wptr_gray_next = bin2gray(wptr_bin_next);
      end
    end


    always @(posedge clk1 or negedge rst_wr_n) begin
      if (!rst_wr_n) begin
        wptr_bin  <= { (ADDR_WIDTH+1){1'b0} };
        wptr_gray <= { (ADDR_WIDTH+1){1'b0} };

        for (j = 0; j < FIFO_DEPTH; j = j + 1)
          mem[j] <= {DATA_WIDTH{1'b0}};
      end else begin
        wptr_bin  <= wptr_bin_next;
        wptr_gray <= wptr_gray_next;
        if (valid_in && !full)
          mem[wptr_bin[ADDR_WIDTH-1:0]] <= din;
      end
    end


    always @(posedge clk1 or negedge rst_wr_n) begin
      if (!rst_wr_n) begin
        wq1_rptr_gray <= { (ADDR_WIDTH+1){1'b0} };
        wq2_rptr_gray <= { (ADDR_WIDTH+1){1'b0} };
      end else begin
        wq1_rptr_gray <= rptr_gray;
        wq2_rptr_gray <= wq1_rptr_gray;
      end
    end


    assign full = (wptr_gray_next ==
                   {~wq2_rptr_gray[ADDR_WIDTH:ADDR_WIDTH-1],
                      wq2_rptr_gray[ADDR_WIDTH-2:0]});


    always @(*) begin
      rptr_bin_next  = rptr_bin;
      rptr_gray_next = rptr_gray;
      if (rd_en && !empty) begin
        rptr_bin_next  = rptr_bin + 1'b1;
        rptr_gray_next = bin2gray(rptr_bin_next);
      end
    end


    always @(posedge clk2 or negedge rst_rd_n) begin
      if (!rst_rd_n) begin
        rptr_bin  <= { (ADDR_WIDTH+1){1'b0} };
        rptr_gray <= { (ADDR_WIDTH+1){1'b0} };
      end else begin
        rptr_bin  <= rptr_bin_next;
        rptr_gray <= rptr_gray_next;
      end
    end


    always @(posedge clk2 or negedge rst_rd_n) begin
      if (!rst_rd_n) begin
        dout <= {DATA_WIDTH{1'b0}};
      end else begin
        dout <= mem[rptr_bin[ADDR_WIDTH-1:0]];
      end
    end


    always @(posedge clk2 or negedge rst_rd_n) begin
      if (!rst_rd_n) begin
        rq1_wptr_gray <= { (ADDR_WIDTH+1){1'b0} };
        rq2_wptr_gray <= { (ADDR_WIDTH+1){1'b0} };
      end else begin
        rq1_wptr_gray <= wptr_gray;
        rq2_wptr_gray <= rq1_wptr_gray;
      end
    end


    assign empty = (rptr_gray == rq2_wptr_gray);

endmodule




module fir_fsm(
  input  wire       clk2,
  input  wire       rstn,
  input  wire       cload,
  input  wire       empty,
  input  wire [5:0] q,

  output reg        rd_en,
  output reg        load_sample,
  output reg        counter_en,
  output reg        counter_clear,
  output reg        done_flag,
  output reg        valid_out,
  output reg [2:0]  state
);

  localparam [2:0]
    S_RESET = 3'b000,
    S_WAIT  = 3'b001,
    S_LOAD  = 3'b010,
    S_READ  = 3'b011,
    S_SHIFT = 3'b110,
    S_MAC   = 3'b100,
    S_DONE  = 3'b101;

  reg [2:0] next_state;


  always @(posedge clk2 or negedge rstn) begin
    if (!rstn)
      state <= S_RESET;
    else
      state <= next_state;
  end


  always @(*) begin

    next_state    = state;
    rd_en         = 1'b0;
    load_sample   = 1'b0;
    counter_en    = 1'b0;
    counter_clear = 1'b0;
    done_flag     = 1'b1;
    valid_out     = 1'b0;

    case (state)
      S_RESET: begin
        next_state = S_WAIT;
      end

      S_WAIT: begin
        if (cload)
          next_state = S_LOAD;
        else if (!empty)
          next_state = S_READ;
      end


      S_LOAD: begin
        if (!cload)
          next_state = S_WAIT;
      end


      S_READ: begin
        rd_en = 1'b1;
        if (empty)
          next_state = S_WAIT;
        else
          next_state = S_SHIFT;
      end


      S_SHIFT: begin
        load_sample   = 1'b1;
        counter_clear = 1'b1;
        done_flag     = 1'b0;
        next_state    = S_MAC;
      end


      S_MAC: begin
        counter_en = 1'b1;
        done_flag  = 1'b0;
        if (q == 6'd63)
          next_state = S_DONE;
      end


      S_DONE: begin
        valid_out = 1'b1;
        done_flag = 1'b1;
        next_state = S_WAIT;
      end

      default: begin
        next_state = S_RESET;
      end
    endcase
  end

endmodule




module fir_core(
  input  wire               clk1,
  input  wire               clk2,
  input  wire               rstn,
  input  wire               valid_in,
  input  wire signed [15:0] din,
  input  wire               cload,
  input  wire [5:0]         caddr,
  input  wire [15:0]        cin,
  output wire signed [15:0] dout,
  output wire               valid_out
);


  wire               full;
  wire               empty;
  wire signed [15:0] fifo_dout;


  wire [15:0]         tap;
  wire [15:0]         x;
  wire signed [31:0]  product;
  wire signed [40:0]  acc;
  wire signed [15:0]  acc_shifted;
  wire [5:0]          q;


  wire rd_en;
  wire load_sample;
  wire counter_en;
  wire counter_clear;
  wire done_flag;
  wire valid_out_int;
  wire [2:0] state;


  wire clear_acc = counter_clear;






  wire [5:0] q_addr_adj = (q == 6'd0) ? 6'd63 : (q - 6'd1);
  wire [5:0] caddr_eff  = cload ? caddr : q_addr_adj;


  reg signed [15:0] dout_reg;


  fifo u_fifo (
    .clk1     (clk1),
    .rst_wr_n (rstn),
    .valid_in (valid_in),
    .din      (din),
    .full     (full),

    .clk2     (clk2),
    .rst_rd_n (rstn),
    .rd_en    (rd_en),
    .dout     (fifo_dout),
    .empty    (empty)
  );

  cmem u_cmem (
    .clk   (clk2),
    .rstn  (rstn),
    .cload (cload),
    .cin   (cin),
    .caddr (caddr_eff),
    .tap   (tap)
  );

  imem u_imem (
    .clk2        (clk2),
    .rstn        (rstn),
    .load_sample (load_sample),
    .din         (fifo_dout),
    .raddr       (q),
    .x           (x)
  );

  counter u_counter (
    .clk2  (clk2),
    .rstn  (rstn),
    .clear (counter_clear),
    .en    (counter_en),
    .q     (q)
  );

  alu u_alu (
    .clk2        (clk2),
    .rstn        (rstn),
    .clear_acc   (clear_acc),
    .x           (x),
    .coeff       (tap),
    .done_flag   (done_flag),
    .product     (product),
    .acc         (acc),
    .acc_shifted (acc_shifted)
  );

  fir_fsm u_fsm (
    .clk2         (clk2),
    .rstn         (rstn),
    .cload        (cload),
    .empty        (empty),
    .q            (q),
    .rd_en        (rd_en),
    .load_sample  (load_sample),
    .counter_en   (counter_en),
    .counter_clear(counter_clear),
    .done_flag    (done_flag),
    .valid_out    (valid_out_int),
    .state        (state)
  );


  always @(posedge clk2 or negedge rstn) begin
    if (!rstn)
      dout_reg <= 16'sd0;
    else if (valid_out_int)
      dout_reg <= acc_shifted;
  end

  assign dout       = dout_reg;
  assign valid_out  = valid_out_int;

endmodule

