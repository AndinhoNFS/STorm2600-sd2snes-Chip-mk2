// SPDX-License-Identifier: GPL-2.0-or-later
// tb_riot.v -- self-checking test for riot6532.v
//
// run:  iverilog -g2005 -Wall -o tb_riot tb_riot.v riot6532.v && vvp tb_riot
`timescale 1ns / 1ps

module tb_riot;
  reg        clk = 0, rst = 1, tick = 0, rd = 0, wr = 0, rs = 0;
  reg [6:0]  a = 0;
  reg [7:0]  din = 0;
  reg [7:0]  pa_in = 8'hFF, pb_in = 8'hFF;
  wire [7:0] dout, pa_out, pa_oe, pb_out, pb_oe;

  riot6532 dut (.clk(clk), .rst(rst), .tick(tick), .rd(rd), .wr(wr),
                .rs(rs), .a(a), .din(din), .dout(dout),
                .pa_in(pa_in), .pa_out(pa_out), .pa_oe(pa_oe),
                .pb_in(pb_in), .pb_out(pb_out), .pb_oe(pb_oe));

  always #5 clk = ~clk;

  integer errs = 0;

  // one CPU cycle = 3 clocks; tick/rd/wr last exactly one clock edge.
  // Callers are always sitting on a falling clock edge.
  task step;
    begin
      tick = 1;
      @(negedge clk);
      tick = 0; rd = 0; wr = 0;
      @(negedge clk);
      @(negedge clk);
    end
  endtask

  task wr_io;  input [6:0] aa; input [7:0] d;
    begin rs = 1; a = aa; din = d; wr = 1; step; end
  endtask
  task wr_ram; input [6:0] aa; input [7:0] d;
    begin rs = 0; a = aa; din = d; wr = 1; step; end
  endtask
  task look;   input r; input [6:0] aa;     // select an address, let RAM settle
    begin rs = r; a = aa; @(negedge clk); @(negedge clk); end
  endtask
  task expect8; input [8*24-1:0] nm; input [7:0] got; input [7:0] exp;
    begin
      if (got !== exp) begin
        errs = errs + 1;
        $display("FAIL  %0s: got %02h, expected %02h", nm, got, exp);
      end
    end
  endtask

  // ---- timer sweep: N, divisor code (0=1, 1=8, 2=64, 3=1024) ---------
  task test_timer;
    input [7:0] N; input [1:0] dsel;
    integer d, k, limit, expv, bad;
    begin
      d = (dsel == 0) ? 1 : (dsel == 1) ? 8 : (dsel == 2) ? 64 : 1024;
      bad = 0;
      wr_io(7'h14 | dsel, N);               // k = 0
      rs = 1; a = 7'h04;                    // INTIM
      limit = (N + 1) * d + 12;
      for (k = 1; k <= limit; k = k + 1) begin
        step;
        #1;
        // first decrement on the cycle after the write, then one every d cycles
        if (k <= N * d) expv = N - 1 - ((k - 1) / d);
        else            expv = (8'hFF - (k - (N * d + 1))) & 8'hFF;
        if (dout !== expv[7:0] && bad < 3) begin
          bad = bad + 1; errs = errs + 1;
          $display("FAIL  timer N=%0d d=%0d k=%0d: got %02h, expected %02h",
                   N, d, k, dout, expv[7:0]);
        end
      end
      look(1, 7'h05);                       // INSTAT: timer flag must be set
      expect8("timer flag set", {7'b0, dout[7]}, 8'h01);
      rs = 1; a = 7'h04; rd = 1; step;      // reading INTIM clears it
      look(1, 7'h05);
      expect8("timer flag cleared", {7'b0, dout[7]}, 8'h00);
      $display("timer N=%0d d=%0d done", N, d);
    end
  endtask

  initial begin
    @(negedge clk); @(negedge clk);
    rst = 0;
    @(negedge clk);

    // ---- RAM ---------------------------------------------------------
    wr_ram(7'h00, 8'hA5);
    wr_ram(7'h7F, 8'h5A);
    wr_ram(7'h40, 8'h11);
    look(0, 7'h00); expect8("ram[00]", dout, 8'hA5);
    look(0, 7'h7F); expect8("ram[7F]", dout, 8'h5A);
    look(0, 7'h40); expect8("ram[40]", dout, 8'h11);
    wr_io(7'h00, 8'hEE);                    // an I/O write must not touch RAM
    look(0, 7'h00); expect8("ram[00] after io write", dout, 8'hA5);

    // ---- ports ---------------------------------------------------------
    wr_io(7'h01, 8'hF0);                    // SWACNT = $F0 (high nibble out)
    wr_io(7'h00, 8'hA5);                    // SWCHA latch
    pa_in = 8'h3C;
    look(1, 7'h00); expect8("SWCHA read", dout, 8'hAC);
    look(1, 7'h01); expect8("SWACNT read", dout, 8'hF0);
    expect8("pa_out", pa_out, 8'hA5);
    expect8("pa_oe",  pa_oe,  8'hF0);
    wr_io(7'h03, 8'h00);                    // SWBCNT = inputs
    pb_in = 8'hCB;
    look(1, 7'h02); expect8("SWCHB read", dout, 8'hCB);

    // ---- PA7 edge detect ----------------------------------------------
    wr_io(7'h01, 8'h00);                    // PA all inputs again
    pa_in = 8'hFF; step;
    wr_io(7'h04, 8'h00);                    // negative edge
    pa_in = 8'h7F; step;
    look(1, 7'h05); expect8("neg edge flag", {7'b0, dout[6]}, 8'h01);
    rs = 1; a = 7'h05; rd = 1; step;        // read INSTAT clears bit 6
    look(1, 7'h05); expect8("neg edge cleared", {7'b0, dout[6]}, 8'h00);
    wr_io(7'h05, 8'h00);                    // positive edge
    pa_in = 8'hFF; step;
    look(1, 7'h05); expect8("pos edge flag", {7'b0, dout[6]}, 8'h01);
    rs = 1; a = 7'h05; rd = 1; step;
    look(1, 7'h05); expect8("pos edge cleared", {7'b0, dout[6]}, 8'h00);

    // ---- timer ---------------------------------------------------------
    test_timer(8'd3,  2'd0);
    test_timer(8'd5,  2'd1);
    test_timer(8'd2,  2'd2);
    test_timer(8'd1,  2'd3);
    test_timer(8'd43, 2'd2);                // the classic TIM64T,43 vblank

    if (errs == 0) $display("PASS  riot6532");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end

  initial begin
    #200000000;
    $display("FAIL  global timeout");
    $finish;
  end
endmodule
