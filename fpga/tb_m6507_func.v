// SPDX-License-Identifier: GPL-2.0-or-later
// tb_m6507_func.v -- runs Klaus Dormann's 6502_functional_test.bin on m6507.v
//
// Needs func_test.hex in the current directory: one byte per line, 65536
// lines, loaded at address $0000 (see the commands in the instructions).
// The test starts at $0400 and ends in an endless loop; success is the loop
// at $3469.  Any other loop address is a failure -- $0200 then holds the
// number of the failing test case.
//
// run:  iverilog -g2005 -o tb_func tb_m6507_func.v m6507.v && vvp tb_func
`timescale 1ns / 1ps

module tb_m6507_func;
  reg clk = 0, rst = 1;
  wire ce = 1'b1;                 // one CPU cycle per clock: fastest simulation
  reg [7:0] mem [0:65535];

  wire [15:0] ab;
  wire        we, sync;
  wire [7:0]  dout;
  wire [7:0]  din = mem[ab];

  m6507 dut (.clk(clk), .rst(rst), .ce(ce), .din(din),
             .ab(ab), .we(we), .dout(dout), .sync(sync));

  always #5 clk = ~clk;
  always @(posedge clk) if (!rst && we) mem[ab] <= dout;

  initial begin
    $readmemh("func_test.hex", mem);
    mem[16'hFFFC] = 8'h00;        // reset vector -> $0400
    mem[16'hFFFD] = 8'h04;
    repeat (6) @(posedge clk);
    rst = 0;
  end

  integer    cycles = 0;
  reg [15:0] last = 16'hFFFF;

  always @(posedge clk) if (!rst) begin
    cycles = cycles + 1;
    if (sync) begin
      if (ab == last) begin
        $display("trap at %04h after %0d cycles, test case = %0d", ab, cycles, mem[16'h0200]);
        if (ab == 16'h3469) $display("PASS");
        else                $display("FAIL");
        $finish;
      end
      last = ab;
    end
    if (cycles % 10000000 == 0) $display("... %0d M cycles, PC at %04h", cycles / 1000000, ab);
    if (cycles > 150000000) begin
      $display("FAIL  timeout, PC at %04h, test case = %0d", ab, mem[16'h0200]);
      $finish;
    end
  end
endmodule
