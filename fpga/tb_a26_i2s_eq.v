// SPDX-License-Identifier: GPL-2.0-or-later
// tb_i2s_eq.v -- the rewritten a26_i2s and the Passo 31 serializer (a26_i2s_old) must drive the same waveform on every pin, clock by clock.
`timescale 1ns / 1ps
module tb_i2s_eq;
  reg clk = 0; reg [15:0] sample = 16'h1234;
  wire sd_n, mc_n, lr_n, sc_n, sd_o, mc_o, lr_o, sc_o;
  a26_i2s     n (.clkin(clk), .sample(sample), .sdout(sd_n), .mclk_out(mc_n), .lrck_out(lr_n), .sclk_out(sc_n));
  a26_i2s_old o (.clkin(clk), .sample(sample), .sdout(sd_o), .mclk_out(mc_o), .lrck_out(lr_o), .sclk_out(sc_o));
  always #5 clk = ~clk;
  integer t = 0, diff = 0, first = -1, last = -1, edges = 0;
  reg lr_d = 0;
  always @(posedge clk) begin
    t <= t + 1;
    if ({sd_n, mc_n, lr_n, sc_n} !== {sd_o, mc_o, lr_o, sc_o}) begin
      diff <= diff + 1; if (first < 0) first <= t; last <= t;
    end
    lr_d <= lr_o; if (lr_o != lr_d) edges <= edges + 1;
    if (t % 977 == 5) sample <= $random;            // new sample at arbitrary times
  end
  initial begin
    #(10 * 400000);
    $display("clocks %0d, pin differences %0d (first at clock %0d, last at %0d), LRCK edges seen %0d", t, diff, first, last, edges);
    if (diff == 0) $display("PASS i2s identical on all pins"); else $display("FAIL i2s");
    $finish;
  end
endmodule
