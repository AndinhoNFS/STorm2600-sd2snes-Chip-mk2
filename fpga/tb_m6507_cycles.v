// SPDX-License-Identifier: GPL-2.0-or-later
// tb_m6507_cycles.v -- directed cycle-count test for m6507.v
//
// Assembles a small program in memory, runs it with ce gated (one pulse
// every 3 clocks) and checks that every instruction takes the number of
// cycles in the documented 6502 table.  Self-checking: prints PASS / FAIL.
//
// run:  iverilog -g2005 -Wall -o tb_cycles tb_m6507_cycles.v m6507.v && vvp tb_cycles
`timescale 1ns / 1ps

module tb_m6507_cycles;
  reg clk = 0, rst = 1, ce = 0;
  reg [7:0] mem  [0:65535];
  reg [3:0] expc [0:65535];      // expected cycles, indexed by opcode address

  wire [15:0] ab;
  wire        we, sync;
  wire [7:0]  dout;
  wire [7:0]  din = mem[ab];

  m6507 dut (.clk(clk), .rst(rst), .ce(ce), .din(din),
             .ab(ab), .we(we), .dout(dout), .sync(sync));

  always #5 clk = ~clk;

  reg [1:0] div = 0;
  always @(posedge clk) begin
    div <= (div == 2'd2) ? 2'd0 : div + 2'd1;
    ce  <= (div == 2'd2);
  end

  // memory write at the ce edge that completes a write cycle
  always @(posedge clk) if (ce && !rst && we) mem[ab] <= dout;

  // ---- tiny assembler ------------------------------------------------
  reg [15:0] p;
  integer    n_exp;
  reg [15:0] exp_trap;

  task b;  input [7:0] v; begin mem[p] = v; p = p + 16'd1; end endtask
  task i1; input [3:0] c; input [7:0] o;
           begin expc[p] = c; n_exp = n_exp + 1; b(o); end endtask
  task i2; input [3:0] c; input [7:0] o; input [7:0] a;
           begin expc[p] = c; n_exp = n_exp + 1; b(o); b(a); end endtask
  task i3; input [3:0] c; input [7:0] o; input [7:0] l; input [7:0] h;
           begin expc[p] = c; n_exp = n_exp + 1; b(o); b(l); b(h); end endtask

  integer k;
  initial begin
    n_exp = 0;
    for (k = 0; k < 65536; k = k + 1) begin mem[k] = 8'hEA; expc[k] = 4'd0; end

    // ---- block 1: addressing modes at $0200 --------------------------
    p = 16'h0200;
    i2(2, 8'hA2, 8'h05);            // LDX #$05
    i2(2, 8'hA9, 8'h10);            // LDA #$10
    i2(3, 8'h85, 8'h20);            // STA $20
    i2(3, 8'hA5, 8'h20);            // LDA $20
    i2(4, 8'h95, 8'h20);            // STA $20,X
    i2(4, 8'hB5, 8'h20);            // LDA $20,X
    i3(4, 8'h8D, 8'h00, 8'h08);     // STA $0800
    i3(4, 8'hAD, 8'h00, 8'h08);     // LDA $0800
    i3(5, 8'h9D, 8'h00, 8'h08);     // STA $0800,X
    i3(4, 8'hBD, 8'h00, 8'h08);     // LDA $0800,X       no page cross
    i2(2, 8'hA0, 8'hFF);            // LDY #$FF
    i3(5, 8'hB9, 8'h05, 8'h08);     // LDA $0805,Y       page cross (+1)
    i3(4, 8'hB9, 8'h00, 8'h08);     // LDA $0800,Y       no cross
    i3(5, 8'hBD, 8'hFF, 8'h08);     // LDA $08FF,X       page cross (+1)
    i2(5, 8'hE6, 8'h20);            // INC $20
    i2(6, 8'hF6, 8'h20);            // INC $20,X
    i3(6, 8'hEE, 8'h00, 8'h08);     // INC $0800
    i3(7, 8'hFE, 8'h00, 8'h08);     // INC $0800,X
    i1(2, 8'h0A);                   // ASL A
    i2(5, 8'h06, 8'h20);            // ASL $20
    i3(6, 8'h4E, 8'h00, 8'h08);     // LSR $0800
    i2(2, 8'hA9, 8'h01);            // LDA #$01
    i2(3, 8'h85, 8'h40);            // STA $40
    i2(2, 8'hA9, 8'h08);            // LDA #$08
    i2(3, 8'h85, 8'h41);            // STA $41          pointer $0801
    i2(2, 8'hA9, 8'h00);            // LDA #$00
    i2(3, 8'h85, 8'h45);            // STA $45
    i2(2, 8'hA9, 8'h08);            // LDA #$08
    i2(3, 8'h85, 8'h46);            // STA $46          ($40,X) -> $0800
    i2(6, 8'hB1, 8'h40);            // LDA ($40),Y       Y=$FF: page cross
    i2(2, 8'hA0, 8'h00);            // LDY #$00
    i2(5, 8'hB1, 8'h40);            // LDA ($40),Y       no cross
    i2(6, 8'h91, 8'h40);            // STA ($40),Y
    i2(6, 8'hA1, 8'h40);            // LDA ($40,X)
    i2(6, 8'h81, 8'h40);            // STA ($40,X)
    i3(5, 8'h99, 8'h00, 8'h08);     // STA $0800,Y
    i3(3, 8'h4C, 8'hF8, 8'h02);     // JMP $02F8

    // ---- block 2: page-crossing branch (opcode at $02FC) -------------
    p = 16'h02F8;
    i2(2, 8'hA9, 8'h00);            // LDA #$00          Z=1
    i1(2, 8'hEA);                   // NOP
    i1(2, 8'hEA);                   // NOP
    i2(4, 8'hF0, 8'h02);            // BEQ +2  taken, crosses $02FE->$0300
    b(8'hEA); b(8'hEA);             // skipped

    // ---- block 3: at $0300 ------------------------------------------
    i2(3, 8'hF0, 8'h02);            // BEQ +2  taken, same page
    b(8'hEA); b(8'hEA);             // skipped
    i2(2, 8'hD0, 8'h02);            // BNE +2  not taken
    i1(2, 8'hEA);
    i1(2, 8'hEA);
    i1(3, 8'h48);                   // PHA
    i1(4, 8'h68);                   // PLA
    i1(3, 8'h08);                   // PHP
    i1(4, 8'h28);                   // PLP
    i1(2, 8'hAA);                   // TAX
    i1(2, 8'h8A);                   // TXA
    i2(2, 8'hA2, 8'hFF);            // LDX #$FF
    i1(2, 8'h9A);                   // TXS
    i1(2, 8'hBA);                   // TSX
    i3(6, 8'h20, 8'h00, 8'h06);     // JSR $0600
    i3(5, 8'h6C, 8'h00, 8'h0A);     // JMP ($0A00)  -> $0380

    p = 16'h0380;
    i3(3, 8'h4C, 8'h90, 8'h03);     // JMP $0390
    p = 16'h0390;
    i1(7, 8'h00);                   // BRK
    b(8'hEA);                       // BRK padding byte
    i1(2, 8'hEA);                   // NOP at BRK+2
    exp_trap = p;
    i3(3, 8'h4C, p[7:0], p[15:8]);  // JMP * (trap)

    p = 16'h0600;  i1(6, 8'h60);    // RTS
    p = 16'h0700;  i1(6, 8'h40);    // RTI
    mem[16'h0A00] = 8'h80;  mem[16'h0A01] = 8'h03;   // JMP ind pointer
    mem[16'hFFFC] = 8'h00;  mem[16'hFFFD] = 8'h02;   // reset -> $0200
    mem[16'hFFFE] = 8'h00;  mem[16'hFFFF] = 8'h07;   // BRK   -> $0700

    repeat (6) @(posedge clk);
    rst = 0;
  end

  // ---- monitor -------------------------------------------------------
  integer cyc = 0, pcyc = 0, checked = 0, errs = 0;
  reg [15:0] pa = 0;
  reg        havep = 0;
  reg        done = 0;

  always @(posedge clk) if (ce && !rst && !done) begin
    if (sync) begin
      if (havep) begin
        if (expc[pa] != 4'd0) begin
          checked = checked + 1;
          if ((cyc - pcyc) != expc[pa]) begin
            errs = errs + 1;
            $display("FAIL  opcode %02h at %04h: %0d cycles, expected %0d",
                     mem[pa], pa, cyc - pcyc, expc[pa]);
          end
        end
        if (ab == pa) begin
          done = 1;
          $display("trap at %04h (expected %04h)", ab, exp_trap);
          if (ab != exp_trap) begin errs = errs + 1; $display("FAIL  program diverged"); end
          if (checked != n_exp) begin
            errs = errs + 1;
            $display("FAIL  checked %0d instructions, expected %0d", checked, n_exp);
          end
          if (errs == 0) $display("PASS  %0d instructions, all cycle counts match", checked);
          else           $display("FAILED  %0d error(s)", errs);
          $finish;
        end
      end
      pa = ab; pcyc = cyc; havep = 1;
    end
    cyc = cyc + 1;
    if (cyc > 5000) begin
      $display("FAIL  timeout (program never reached the trap), last opcode at %04h", pa);
      $finish;
    end
  end
endmodule
