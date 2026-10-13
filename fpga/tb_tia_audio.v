// SPDX-License-Identifier: GPL-2.0-or-later
// tb_tia_audio.v -- self-checking test for tia_audio.v
//
// Checks the structure of the model documented in tia_audio.v: period and
// number of high samples per period for each generator, constant modes and
// the channel mix.  It does not prove the timbre matches a real TIA.
//
// run:  iverilog -g2005 -Wall -o tb_audio tb_tia_audio.v tia_audio.v && vvp tb_audio
`timescale 1ns / 1ps

module tb_tia_audio;
  reg        clk = 0, rst = 1, tick = 0;
  reg [3:0]  audc0 = 0, audc1 = 0, audv0 = 0, audv1 = 0;
  reg [4:0]  audf0 = 0, audf1 = 0;
  wire [3:0] vol0, vol1;
  wire [4:0] mix;

  tia_audio dut (.clk(clk), .rst(rst), .tick(tick),
                 .audc0(audc0), .audc1(audc1), .audf0(audf0), .audf1(audf1),
                 .audv0(audv0), .audv1(audv1),
                 .vol0(vol0), .vol1(vol1), .mix(mix));

  always #5 clk = ~clk;

  integer errs = 0;
  reg [3:0] s [0:2047];

  // reset, program channel 0, run n audio ticks, record vol0 after each tick
  task capture;
    input [3:0] c; input [4:0] f; input integer n;
    integer i;
    begin
      audc0 = c; audf0 = f; audv0 = 4'd10; audc1 = 4'd0; audv1 = 4'd0;
      rst = 1; repeat (2) @(negedge clk);
      rst = 0; @(negedge clk);
      for (i = 0; i < n; i = i + 1) begin
        tick = 1; @(negedge clk);
        tick = 0; @(negedge clk);
        s[i] = vol0;
      end
    end
  endtask

  // the recorded sequence must repeat with period P and have `ones` high
  // samples per period; only 0 and AUDV (10) may appear
  task check_period;
    input [8*24-1:0] nm; input integer P; input integer ones; input integer n;
    integer i, bad, cnt1, other;
    begin
      bad = 0; cnt1 = 0; other = 0;
      for (i = 100; i < n - P; i = i + 1) if (s[i] !== s[i + P]) bad = bad + 1;
      for (i = 100; i < 100 + P; i = i + 1) if (s[i] === 4'd10) cnt1 = cnt1 + 1;
      for (i = 0; i < n; i = i + 1) if (s[i] !== 4'd0 && s[i] !== 4'd10) other = other + 1;
      if (bad != 0 || cnt1 != ones || other != 0) begin
        errs = errs + 1;
        $display("FAIL  %0s: period violations %0d, high samples %0d (expected %0d), bad values %0d",
                 nm, bad, cnt1, ones, other);
      end else
        $display("ok    %0s: period %0d, %0d high", nm, P, ones);
    end
  endtask

  // output must stay legal and must not be stuck at a single level
  task check_alive;
    input [8*24-1:0] nm; input integer n;
    integer i, trans, other;
    begin
      trans = 0; other = 0;
      for (i = 1; i < n; i = i + 1) if (s[i] !== s[i - 1]) trans = trans + 1;
      for (i = 0; i < n; i = i + 1) if (s[i] !== 4'd0 && s[i] !== 4'd10) other = other + 1;
      if (trans == 0 || other != 0) begin
        errs = errs + 1;
        $display("FAIL  %0s: %0d transitions, %0d bad values", nm, trans, other);
      end else
        $display("ok    %0s: %0d transitions", nm, trans);
    end
  endtask

  integer i, constbad;

  initial begin
    repeat (3) @(negedge clk);

    capture(4'd1, 5'd0, 400);   check_period("mode 1  poly4",        15,  7, 400);
    capture(4'd9, 5'd0, 400);   check_period("mode 9  poly5",        31, 16, 400);
    capture(4'd6, 5'd0, 400);   check_period("mode 6  div31",        31, 13, 400);
    capture(4'd10, 5'd0, 400);  check_period("mode 10 div31",        31, 13, 400);
    capture(4'd8, 5'd0, 1700);  check_period("mode 8  poly9",       511, 256, 1700);
    capture(4'd4, 5'd0, 400);   check_period("mode 4  div2",          2,  1, 400);
    capture(4'd5, 5'd0, 400);   check_period("mode 5  div2",          2,  1, 400);
    capture(4'd4, 5'd3, 400);   check_period("mode 4  AUDF=3",        8,  4, 400);
    capture(4'd12, 5'd0, 400);  check_period("mode 12 div6",          6,  3, 400);
    capture(4'd13, 5'd1, 400);  check_period("mode 13 AUDF=1",       12,  6, 400);
    capture(4'd14, 5'd0, 600);  check_period("mode 14 div93",        93, 39, 600);
    capture(4'd1, 5'd1, 600);   check_period("mode 1  AUDF=1",       30, 14, 600);

    capture(4'd2, 5'd0, 800);   check_alive("mode 2  poly4/div31", 800);
    capture(4'd3, 5'd0, 800);   check_alive("mode 3  poly4/poly5", 800);
    capture(4'd7, 5'd0, 400);   check_alive("mode 7  div2/poly5",  400);
    capture(4'd15, 5'd0, 400);  check_alive("mode 15 poly5 div6",  400);

    // constant modes
    capture(4'd0, 5'd7, 100);
    constbad = 0;
    for (i = 0; i < 100; i = i + 1) if (s[i] !== 4'd10) constbad = constbad + 1;
    if (constbad != 0) begin errs = errs + 1; $display("FAIL  mode 0 not constant"); end
    else $display("ok    mode 0 constant");
    capture(4'd11, 5'd7, 100);
    constbad = 0;
    for (i = 0; i < 100; i = i + 1) if (s[i] !== 4'd10) constbad = constbad + 1;
    if (constbad != 0) begin errs = errs + 1; $display("FAIL  mode 11 not constant"); end
    else $display("ok    mode 11 constant");

    // mix: two constant channels
    audc0 = 4'd0;  audv0 = 4'd5;
    audc1 = 4'd11; audv1 = 4'd7;
    #1;
    if (mix !== 5'd12) begin errs = errs + 1; $display("FAIL  mix: got %0d, expected 12", mix); end
    else $display("ok    mix 5 + 7 = 12");
    audv0 = 4'd15; audv1 = 4'd15; #1;
    if (mix !== 5'd30) begin errs = errs + 1; $display("FAIL  mix max: got %0d, expected 30", mix); end
    else $display("ok    mix max = 30");

    if (errs == 0) $display("PASS  tia_audio");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end

  initial begin
    #200000000;
    $display("FAIL  global timeout");
    $finish;
  end
endmodule
