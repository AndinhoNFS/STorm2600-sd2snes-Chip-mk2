// SPDX-License-Identifier: GPL-2.0-or-later
// tb_a26_i2s.v -- self-checking test for a26_i2s.v
//
// Decodes SDOUT on SCLK rising edges, word by word (one word per LRCK edge),
// and checks that the 16-bit sample comes out MSB first, on both channels,
// and that a new sample replaces the old one.  The word may sit either right
// after the LRCK edge or one bit later (I2S style); the test accepts one
// consistent alignment and prints which one it found.
//
// run:  iverilog -g2005 -Wall -o tb_i2s tb_a26_i2s.v a26_i2s.v && vvp tb_i2s
`timescale 1ns / 1ps

module tb_a26_i2s;
  reg         clk = 0;
  reg  [15:0] sample = 16'h1234;
  wire        sdout, mclk_out, lrck_out, sclk_out;

  a26_i2s dut (.clkin(clk), .sample(sample), .sdout(sdout),
               .mclk_out(mclk_out), .lrck_out(lrck_out), .sclk_out(sclk_out));

  always #5 clk = ~clk;

  // ---- word capture --------------------------------------------------------
  // SDOUT is sampled on every SCLK rising edge into a history register.  Each
  // LRCK half carries 16 SCLK periods, so a word is judged at the LRCK edge
  // that ends it:
  //   aligned : the 16 bits sampled just before the edge
  //   delayed : the 16 bits that end at the first SCLK edge after the edge
  //             (I2S style: the last bit spills into the next half)
  reg         lrck_d = 0, sclk_d = 0;
  reg  [31:0] hist = 0;
  reg         pend = 0;
  reg  [15:0] a_val = 0;
  integer     words = 0;
  integer     match_a = 0, match_b = 0, checked = 0;
  reg  [15:0] expect_s = 16'h1234;
  integer     check_from = 6;

  always @(posedge clk) begin
    lrck_d <= lrck_out;
    sclk_d <= sclk_out;
    if (sclk_out && !sclk_d) begin
      hist <= {hist[30:0], sdout};
      if (pend) begin
        pend  <= 1'b0;
        words <= words + 1;
        if (words >= check_from) begin
          checked <= checked + 1;
          if (a_val == expect_s)                match_a <= match_a + 1;
          if ({hist[14:0], sdout} == expect_s)  match_b <= match_b + 1;
        end
      end
    end
    if (lrck_out !== lrck_d) begin
      pend  <= 1'b1;
      a_val <= hist[15:0];
    end
  end

  integer errs = 0;

  task phase; input [8*14-1:0] nm; input [15:0] s; input integer nwords;
    integer start;
    begin
      sample = s; expect_s = s;
      check_from = words + 6;                 // skip the words in flight
      match_a = 0; match_b = 0; checked = 0;
      start = words;
      while (words < start + nwords + 6) @(posedge clk);
      if (checked < 10) begin
        errs = errs + 1; $display("FAIL  %0s: only %0d words checked", nm, checked);
      end else if (match_a == checked) begin
        $display("ok    %0s: %0d words, MSB on the first SCLK edge after LRCK", nm, checked);
      end else if (match_b == checked) begin
        $display("ok    %0s: %0d words, MSB one SCLK edge after LRCK (I2S)", nm, checked);
      end else begin
        errs = errs + 1;
        $display("FAIL  %0s: %0d words, aligned %0d / delayed %0d", nm, checked, match_a, match_b);
      end
    end
  endtask

  // ---- clock ratios ----------------------------------------------------------
  integer lrck_edges = 0, mclk_edges = 0;
  reg     mclk_d = 0;
  always @(posedge clk) begin
    mclk_d <= mclk_out;
    if (mclk_out && !mclk_d) mclk_edges <= mclk_edges + 1;
    if (lrck_out !== lrck_d)  lrck_edges <= lrck_edges + 1;
  end

  initial begin
    phase("sample 1234", 16'h1234, 20);
    phase("sample A55A", 16'hA55A, 20);
    phase("sample 0000", 16'h0000, 12);
    phase("sample FFFF", 16'hFFFF, 12);

    // 64 MCLK periods per LRCK period (two LRCK edges)
    if (mclk_edges < 60 * lrck_edges / 2 || mclk_edges > 68 * lrck_edges / 2) begin
      errs = errs + 1;
      $display("FAIL  clock ratio: %0d MCLK rising edges for %0d LRCK edges", mclk_edges, lrck_edges);
    end else
      $display("ok    clock ratio: %0d MCLK edges / %0d LRCK edges", mclk_edges, lrck_edges);

    if (errs == 0) $display("PASS  a26_i2s");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end

  initial begin
    #50000000;
    $display("FAIL  global timeout");
    $finish;
  end
endmodule
