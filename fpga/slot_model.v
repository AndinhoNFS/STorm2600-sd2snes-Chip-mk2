// SPDX-License-Identifier: GPL-2.0-or-later
// slot_model.v -- behavioural model of one arbiter slot plus the 16-bit PSRAM
// (testbench only).  It reproduces the protocol and the byte lanes that were
// read in sd2snes_base/main.v:
//   * a request is accepted when RDY & (RRQ | WRQ); RDY drops on that edge
//     and returns after LAT + jitter clocks (the SNES owns the bus first);
//   * the PSRAM word at an even address has the even byte in [15:8] and the
//     odd byte in [7:0];
//   * read data is DIN = addr0 ? word : {word[7:0], word[15:8]};
//   * a word write at an even address stores DOUT[7:0] at the even byte and
//     DOUT[15:8] at the odd byte.
// mem is a 1 MB window indexed by ADDR[19:0].
`timescale 1ns / 1ps

module slot_model #(parameter LAT = 10) (
  input             clk,
  input             RRQ,
  input             WRQ,
  input      [23:0] ADDR,
  input      [15:0] DOUT,
  input             WORD,
  output reg        RDY,
  output reg [15:0] DIN
);
  reg [7:0]  mem [0:1048575];
  reg        busy, op_wr, w;
  reg [7:0]  cnt;
  reg [23:0] a;
  reg [15:0] d, rd16;
  reg [7:0]  lfsr;

  initial begin RDY = 1'b1; DIN = 16'h0000; busy = 1'b0; lfsr = 8'hA5; cnt = 8'd0; end

  always @(posedge clk) begin
    lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    if (RDY && (RRQ || WRQ)) begin
      RDY <= 1'b0; busy <= 1'b1;
      cnt <= LAT + {5'b00000, lfsr[2:0]};
      op_wr <= WRQ; a <= ADDR; d <= DOUT; w <= WORD;
    end else if (busy) begin
      if (cnt == 8'd0) begin
        if (op_wr) begin
          mem[a[19:0]] <= d[7:0];
          if (w) mem[{a[19:1], 1'b1}] <= d[15:8];
        end else begin
          rd16 = {mem[{a[19:1], 1'b0}], mem[{a[19:1], 1'b1}]};
          DIN <= a[0] ? rd16 : {rd16[7:0], rd16[15:8]};
        end
        RDY <= 1'b1; busy <= 1'b0;
      end else cnt <= cnt - 8'd1;
    end
  end
endmodule
