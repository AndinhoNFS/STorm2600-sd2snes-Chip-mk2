// SPDX-License-Identifier: GPL-2.0-only
//
// a26_i2s.v -- minimal DAC serializer with the pin timing of sd2snes_base/dac.v
//              (no sample buffer, no CIC filter, no volume ramp).  Milestone 7b.
//
// ORIGIN: the clocking part of this file (the MCLK/LRCK/SCLK shift registers and the
// sample shift register, about 15 lines) is copied from verilog/sd2snes_base/dac.v of
// the sd2snes project (Maximilian Rehkopf and contributors, https://github.com/ludufre/sd2snes,
// commit 1b5d9d79), which is licensed under the GNU GPL version 2; so is this file.
//
// Clocking, copied from dac.v and valid for clkin = 96 MHz:
//   MCLK = clkin/8 (12 MHz), LRCK = MCLK/64 (187.5 kHz), SCLK = LRCK*32.
//   Each LRCK half carries one 16-bit word, MSB first, shifted out on SCLK
//   falling edges; the word is loaded on every LRCK edge.
//
// `sample` is signed and is sent on both channels; the TIA mix changes at
// 31.4 kHz, so this is a zero-order hold.  sclk_out is only for debugging /
// the testbench (the board's DAC does not use it).
//
// STATUS: untested when written.  Verify with tb_a26_i2s.v.
//
`timescale 1ns / 1ps

module a26_i2s_old (
  input         clkin,
  input  [15:0] sample,
  output        sdout,
  output        mclk_out,
  output        lrck_out,
  output        sclk_out
);

  reg [10:0] cnt;
  reg [15:0] smpshift;
  reg        sdout_reg;
  reg [2:0]  mclk_sreg;
  reg [2:0]  lrck_sreg;
  reg [1:0]  sclk_sreg;

  wire mclk = cnt[2];                 // clk/8
  wire lrck = cnt[8];                 // mclk/64
  wire sclk = cnt[3];                 // lrck*32

  assign mclk_out = ~mclk_sreg[2];
  assign lrck_out = lrck_sreg[2];
  assign sclk_out = sclk_sreg[1];
  assign sdout    = sdout_reg;

  wire lrck_rising  = ({lrck_sreg[0], lrck} == 2'b01);
  wire lrck_falling = ({lrck_sreg[0], lrck} == 2'b10);
  wire sclk_falling = ({sclk_sreg[0], sclk} == 2'b10);

  initial begin
    cnt = 11'h100;
    smpshift = 16'h0000;
    sdout_reg = 1'b0;
    mclk_sreg = 3'b000;
    lrck_sreg = 3'b000;
    sclk_sreg = 2'b00;
  end

  always @(posedge clkin) begin
    cnt       <= cnt + 11'd1;
    mclk_sreg <= {mclk_sreg[1:0], mclk};
    lrck_sreg <= {lrck_sreg[1:0], lrck};
    sclk_sreg <= {sclk_sreg[0], sclk};
  end

  always @(posedge clkin) begin
    if (sclk_falling) begin
      sdout_reg <= smpshift[15];
      if (lrck_rising | lrck_falling) smpshift <= sample;
      else                            smpshift <= {smpshift[14:0], 1'b0};
    end
  end

endmodule
