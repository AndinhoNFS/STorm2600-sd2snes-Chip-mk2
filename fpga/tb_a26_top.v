// SPDX-License-Identifier: GPL-2.0-or-later
// tb_a26_top.v -- end-to-end test of a26_top through its dma-compatible ports.
//
// The "SNES" talks to the 4-bit register window, the arbiter slot is the
// behavioural slot_model, and a hand-assembled 4K program reads the ports the
// SNES wrote, sets the playfield, starts a square wave on audio channel 0 and
// loops.  Checks: RAM written by the program, frame buffer in the PSRAM
// model, status registers, and the audio sample range.
//
// run:  iverilog -g2005 -Wall -o tb_top tb_a26_top.v a26_top.v a26_regs.v a26_mem.v \
//          slot_model.v a26_core.v a26_vidwr.v a26_tdict.v m6507.v riot6532.v tia.v tia_audio.v && vvp tb_top
`timescale 1ns / 1ps

module tb_a26_top;
  reg clk = 0, reset = 1;
  always #5 clk = ~clk;

  integer errs = 0;

  reg  [3:0] reg_addr = 0;
  reg  [7:0] reg_data_in = 0;
  reg        reg_oe_falling = 0, reg_we_rising = 0;
  wire [7:0] reg_data_out;

  wire        BUS_RDY, BUS_RRQ, BUS_WRQ, ROM_WORD_ENABLE;
  wire [23:0] ROM_ADDR;
  wire [15:0] ROM_DATA_OUT, ROM_DATA_IN;
  wire        loop_enable;
  wire [1:0]  busy;
  wire [4:0]  aud_mix;
  wire signed [15:0] aud_sample;

  a26_top top (
    .clkin(clk), .reset(reset),
    .enable(1'b1), .reg_addr(reg_addr), .reg_data_in(reg_data_in),
    .reg_data_out(reg_data_out),
    .reg_oe_falling(reg_oe_falling), .reg_we_rising(reg_we_rising),
    .loop_enable(loop_enable), .busy(busy),
    .BUS_RDY(BUS_RDY), .BUS_RRQ(BUS_RRQ), .BUS_WRQ(BUS_WRQ),
    .ROM_ADDR(ROM_ADDR), .ROM_DATA_OUT(ROM_DATA_OUT),
    .ROM_DATA_IN(ROM_DATA_IN), .ROM_WORD_ENABLE(ROM_WORD_ENABLE),
    .aud_mix(aud_mix), .aud_sample(aud_sample));

  slot_model #(.LAT(10)) slot (.clk(clk), .RRQ(BUS_RRQ), .WRQ(BUS_WRQ), .ADDR(ROM_ADDR),
                               .DOUT(ROM_DATA_OUT), .WORD(ROM_WORD_ENABLE),
                               .RDY(BUS_RDY), .DIN(ROM_DATA_IN));

  // ---- program (ROM_BASE = $300000 -> model index 0) ------------------------
  integer k;
  task pr; input [11:0] off; input [7:0] v; begin slot.mem[off] = v; end endtask

  initial begin
    for (k = 0; k < 4096; k = k + 1) slot.mem[k] = 8'hEA;
    pr(12'h000, 8'h78);                                   // SEI
    pr(12'h001, 8'hD8);                                   // CLD
    pr(12'h002, 8'hA2); pr(12'h003, 8'hFF);               // LDX #$FF
    pr(12'h004, 8'h9A);                                   // TXS
    pr(12'h005, 8'hA9); pr(12'h006, 8'h0E);               // LDA #$0E
    pr(12'h007, 8'h85); pr(12'h008, 8'h08);               // STA COLUPF
    pr(12'h009, 8'hA9); pr(12'h00A, 8'hF0);               // LDA #$F0
    pr(12'h00B, 8'h85); pr(12'h00C, 8'h0D);               // STA PF0
    pr(12'h00D, 8'hAD); pr(12'h00E, 8'h80); pr(12'h00F, 8'h02);   // LDA SWCHA
    pr(12'h010, 8'h85); pr(12'h011, 8'h80);               // STA $80
    pr(12'h012, 8'hAD); pr(12'h013, 8'h82); pr(12'h014, 8'h02);   // LDA SWCHB
    pr(12'h015, 8'h85); pr(12'h016, 8'h81);               // STA $81
    pr(12'h017, 8'hA5); pr(12'h018, 8'h0C);               // LDA INPT4
    pr(12'h019, 8'h85); pr(12'h01A, 8'h82);               // STA $82
    pr(12'h01B, 8'hA9); pr(12'h01C, 8'h04);               // LDA #$04   (AUDC: square wave)
    pr(12'h01D, 8'h85); pr(12'h01E, 8'h15);               // STA AUDC0
    pr(12'h01F, 8'hA9); pr(12'h020, 8'h0F);               // LDA #$0F
    pr(12'h021, 8'h85); pr(12'h022, 8'h19);               // STA AUDV0
    pr(12'h023, 8'h4C); pr(12'h024, 8'h23); pr(12'h025, 8'hF0);   // JMP *
    pr(12'hFFC, 8'h00); pr(12'hFFD, 8'hF0);               // reset vector
  end

  // ---- SNES-side tasks --------------------------------------------------------
  task sreg_wr; input [3:0] a; input [7:0] d;
    begin
      reg_addr = a; reg_data_in = d;
      @(negedge clk); reg_we_rising = 1;
      @(negedge clk); reg_we_rising = 0;
    end
  endtask

  task sreg_rd; input [3:0] a; output [7:0] d;
    begin
      reg_addr = a;
      @(negedge clk); reg_oe_falling = 1;
      @(negedge clk); reg_oe_falling = 0;
      @(negedge clk); d = reg_data_out;
    end
  endtask

  task expect8; input [8*28-1:0] nm; input [7:0] got; input [7:0] exp;
    begin
      if (got !== exp) begin
        errs = errs + 1; $display("FAIL  %0s: got %02h, expected %02h", nm, got, exp);
      end else
        $display("ok    %0s = %02h", nm, got);
    end
  endtask

  // ---- audio watcher: range of the mix and of the sample ------------------------
  integer mix_min = 99, mix_max = 0;      // aud_mix is unsigned: avoid mixed signed/unsigned compares
  integer smp_min = 100000, smp_max = -100000;
  reg     watch = 0;
  always @(posedge clk) if (watch) begin
    if (aud_mix < mix_min) mix_min = aud_mix;
    if (aud_mix > mix_max) mix_max = aud_mix;
    if (aud_sample < smp_min) smp_min = aud_sample;
    if (aud_sample > smp_max) smp_max = aud_sample;
  end

  integer ty, tx, r, bad_a, bad_b, base, idx, ent;
  reg [7:0] v;

  // pause test bookkeeping
  integer   pz_cc = 0, pz_wr = 0, pz_mixchg = 0, pz_sum = 0, k2 = 0;
  reg       pz_on = 0;
  reg [7:0] pz_frames, pz_hc;
  reg [4:0] pz_mix, pz_mix_d;
  reg [15:0] pz_ab, pz_pc;
  always @(posedge clk) begin
    pz_mix_d <= aud_mix;
    if (pz_on) begin
      if (top.core.cc_ce) pz_cc = pz_cc + 1;
      if (BUS_WRQ)        pz_wr = pz_wr + 1;
      if (aud_mix !== pz_mix_d) pz_mixchg = pz_mixchg + 1;
    end
  end

  // the CPU must not take a single cycle before the block RAM is loaded
  // (rom_rd itself is high all through the core's reset, by design)
  reg early = 0;
  always @(posedge clk) if (top.core.cpu_ce && !top.loaded) early = 1;

  task wait_loaded;
    integer t;
    begin
      t = 0;
      while (top.loaded !== 1'b1 && t < 2000000) begin @(negedge clk); t = t + 1; end
      if (top.loaded !== 1'b1) begin errs = errs + 1; $display("FAIL  ROM not loaded after %0d clk", t); end
      else $display("      ROM loaded after %0d clk", t);
    end
  endtask

  // ---- mapper runs: a fresh image, a SNES reset (new load), then a look at the RIOT RAM ----
  // Banked image, the same skeleton in every 4 KB bank b:
  //   $FF00  LDA #sig+b : STA $80+b
  //   $FF04  LDA hotspot(b-1)        (bank 0: JMP $FF04, the end)
  //   $FF07  JMP $FF00               (fetched from the bank just switched to)
  // The core starts in the last bank, so it walks nb-1 .. 0 and leaves sig+b in $80+b.
  task run_banked; input [2:0] m; input integer nb; input [7:0] hot0; input [7:0] sig;
    integer b, o, bad;
    begin
      for (k = 0; k < 16384; k = k + 1) slot.mem[k] = 8'hEE;
      for (b = 0; b < nb; b = b + 1) begin
        o = b * 4096 + 3840;                       // $F00 inside the bank
        slot.mem[o + 0] = 8'hA9; slot.mem[o + 1] = sig + b;
        slot.mem[o + 2] = 8'h85; slot.mem[o + 3] = 8'h80 + b;
        if (b == 0) begin
          slot.mem[o + 4] = 8'h4C; slot.mem[o + 5] = 8'h04; slot.mem[o + 6] = 8'hFF;
        end else begin
          slot.mem[o + 4] = 8'hAD; slot.mem[o + 5] = hot0 + b - 1; slot.mem[o + 6] = 8'hFF;
        end
        slot.mem[o + 7] = 8'h4C; slot.mem[o + 8] = 8'h00; slot.mem[o + 9] = 8'hFF;
        slot.mem[b * 4096 + 4092] = 8'h00; slot.mem[b * 4096 + 4093] = 8'hFF;   // reset vector
      end
      reset = 1; repeat (3) @(negedge clk); reset = 0; repeat (3) @(negedge clk);
      sreg_wr(4'd3, {4'b0000, m, 1'b1});
      wait_loaded;
      #1000000;
      bad = 0;
      for (b = 0; b < nb; b = b + 1)
        if (top.core.u_riot.ram[b] !== sig + b) begin
          bad = bad + 1;
          $display("FAIL  mapper %0d: RAM $%02h = %02h, expected %02h", m, 8'h80 + b, top.core.u_riot.ram[b], sig + b);
        end
      sreg_rd(4'd8, v);
      if (bad != 0 || v != 8'h00 || top.core.cpu_ab !== 16'hFF04 && top.core.cpu_ab !== 16'hFF05 && top.core.cpu_ab !== 16'hFF06) begin
        errs = errs + 1;
        $display("FAIL  mapper %0d: %0d wrong bytes, %0d misses, CPU at %04h", m, bad, v, top.core.cpu_ab);
      end else
        $display("ok    mapper %0d: %0d bank(s) executed, CPU parked in bank 0", m, nb);
    end
  endtask

  // FE (mapper 5, step 24): the bank follows D5 of the byte after an access to $01FE.
  //   first 4K ($F000):  LDX #$FF : TXS : LDA #$A1 : STA $80 : JSR $D100 : LDA #$A3 : STA $82 : JMP *
  //   second 4K ($D100): LDA #$A2 : STA $81 : RTS
  // The JSR pushes to $01FF/$01FE and then reads the target's high byte $D1 (D5 = 0 -> second 4K);
  // the RTS pulls $01FE/$01FF and the high byte $F0 (D5 = 1) brings the first 4K back.
  task run_fe;
    integer bad;
    begin
      for (k = 0; k < 16384; k = k + 1) slot.mem[k] = 8'hEE;
      slot.mem[0]  = 8'hA2; slot.mem[1]  = 8'hFF; slot.mem[2]  = 8'h9A;
      slot.mem[3]  = 8'hA9; slot.mem[4]  = 8'hA1; slot.mem[5]  = 8'h85; slot.mem[6] = 8'h80;
      slot.mem[7]  = 8'h20; slot.mem[8]  = 8'h00; slot.mem[9]  = 8'hD1;
      slot.mem[10] = 8'hA9; slot.mem[11] = 8'hA3; slot.mem[12] = 8'h85; slot.mem[13] = 8'h82;
      slot.mem[14] = 8'h4C; slot.mem[15] = 8'h0E; slot.mem[16] = 8'hF0;
      slot.mem[4092] = 8'h00; slot.mem[4093] = 8'hF0;                       // reset vector, in the first 4K
      slot.mem[4096 + 256] = 8'hA9; slot.mem[4096 + 257] = 8'hA2;
      slot.mem[4096 + 258] = 8'h85; slot.mem[4096 + 259] = 8'h81;
      slot.mem[4096 + 260] = 8'h60;
      slot.mem[8188] = 8'h55; slot.mem[8189] = 8'h55;                       // the end of the image is NOT a vector
      reset = 1; repeat (3) @(negedge clk); reset = 0; repeat (3) @(negedge clk);
      sreg_wr(4'd3, {4'b0000, 3'd5, 1'b1});
      wait_loaded;
      #1000000;
      bad = 0;
      if (top.core.u_riot.ram[0] !== 8'hA1) bad = bad + 1;
      if (top.core.u_riot.ram[1] !== 8'hA2) bad = bad + 1;
      if (top.core.u_riot.ram[2] !== 8'hA3) bad = bad + 1;
      sreg_rd(4'd8, v);
      if (bad != 0 || v != 8'h00 || top.core.bank !== 3'd0 || top.core.cpu_ab < 16'hF00E || top.core.cpu_ab > 16'hF010) begin
        errs = errs + 1;
        $display("FAIL  mapper 5 (FE): RAM $80..$82 = %02h %02h %02h, %0d misses, bank %0d, CPU at %04h", top.core.u_riot.ram[0],
                 top.core.u_riot.ram[1], top.core.u_riot.ram[2], v, top.core.bank, top.core.cpu_ab);
      end else
        $display("ok    mapper 5 (FE): JSR into the second 4K and RTS back, CPU parked in the first 4K");
    end
  endtask

  // 2K: the 2 KB image is mirrored, so $FFF0 and $F7F0 are the same byte (offset $7F0)
  task run_2k;
    begin
      for (k = 0; k < 16384; k = k + 1) slot.mem[k] = 8'hEE;
      slot.mem[1792] = 8'hA9; slot.mem[1793] = 8'h2A;                           // $FF00 LDA #$2A
      slot.mem[1794] = 8'h85; slot.mem[1795] = 8'h80;                           //       STA $80
      slot.mem[1796] = 8'hAD; slot.mem[1797] = 8'hF0; slot.mem[1798] = 8'hFF;   //       LDA $FFF0
      slot.mem[1799] = 8'h85; slot.mem[1800] = 8'h81;                           //       STA $81
      slot.mem[1801] = 8'h4C; slot.mem[1802] = 8'h09; slot.mem[1803] = 8'hFF;   // $FF09 JMP $FF09
      slot.mem[2032] = 8'h5C;                                                   // offset $7F0
      slot.mem[2044] = 8'h00; slot.mem[2045] = 8'hFF;                           // reset vector
      reset = 1; repeat (3) @(negedge clk); reset = 0; repeat (3) @(negedge clk);
      sreg_wr(4'd3, 8'h01);                                // run, mapper 0 (2K)
      wait_loaded;
      #1000000;
      expect8("mapper 0 (2K): RAM $80", top.core.u_riot.ram[0], 8'h2A);
      expect8("mapper 0 (2K): mirror byte", top.core.u_riot.ram[1], 8'h5C);
    end
  endtask

  // Superchip (F6SC, Passo 36): register 3 bit 5.  The first 256 bytes of every bank are the RAM, code starts at $F100.
  //   bank 3 (power-on): RAM[x] = x ^ $A5 through $1000,X ; verify through $1080,X ; $80 = $11 ; LDA $1FF6 -> bank 0
  //   bank 0: $81 = $1080 (RAM[0]) ; $82 = $1000 (a read of the write port gives the ROM byte, $77) ; $83 = $10FF ; JMP *
  task pk; input integer o; input [7:0] val; begin slot.mem[o] = val; end endtask
  task run_sc;
    integer b3, b, bad;
    begin
      b3 = 3 * 4096;
      for (k = 0; k < 16384; k = k + 1) slot.mem[k] = 8'hEE;
      pk(b3+12'h100, 8'hA2); pk(b3+12'h101, 8'h7F);  pk(b3+12'h102, 8'h8A);  pk(b3+12'h103, 8'h49); pk(b3+12'h104, 8'hA5);
      pk(b3+12'h105, 8'h9D); pk(b3+12'h106, 8'h00);  pk(b3+12'h107, 8'h10);  pk(b3+12'h108, 8'hCA);
      pk(b3+12'h109, 8'h10); pk(b3+12'h10A, 8'hF7);  pk(b3+12'h10B, 8'hA2);  pk(b3+12'h10C, 8'h7F);
      pk(b3+12'h10D, 8'h8A); pk(b3+12'h10E, 8'h49);  pk(b3+12'h10F, 8'hA5);  pk(b3+12'h110, 8'hDD);
      pk(b3+12'h111, 8'h80); pk(b3+12'h112, 8'h10);  pk(b3+12'h113, 8'hD0);  pk(b3+12'h114, 8'h1B);
      pk(b3+12'h115, 8'hCA); pk(b3+12'h116, 8'h10);  pk(b3+12'h117, 8'hF5);  pk(b3+12'h118, 8'hA9);
      pk(b3+12'h119, 8'h11); pk(b3+12'h11A, 8'h85);  pk(b3+12'h11B, 8'h80);
      pk(b3+12'h11C, 8'hAD); pk(b3+12'h11D, 8'hF6);  pk(b3+12'h11E, 8'h1F);                     // LDA $1FF6 -> bank 0
      pk(b3+12'h130, 8'hA9); pk(b3+12'h131, 8'hEE);  pk(b3+12'h132, 8'h85);  pk(b3+12'h133, 8'h80);
      pk(b3+12'h134, 8'h4C); pk(b3+12'h135, 8'h34);  pk(b3+12'h136, 8'hF1);                     // bad: $80 = $EE
      pk(0, 8'h77);
      pk(12'h11F, 8'hAD); pk(12'h120, 8'h00); pk(12'h121, 8'h10); pk(12'h122, 8'h85); pk(12'h123, 8'h82);
      pk(12'h124, 8'hAD); pk(12'h125, 8'h80); pk(12'h126, 8'h10); pk(12'h127, 8'h85); pk(12'h128, 8'h81);
      pk(12'h129, 8'hAD); pk(12'h12A, 8'hFF); pk(12'h12B, 8'h10); pk(12'h12C, 8'h85); pk(12'h12D, 8'h83);
      pk(12'h12E, 8'h4C); pk(12'h12F, 8'h2E); pk(12'h130, 8'hF1);
      for (b = 0; b < 4; b = b + 1) begin slot.mem[b*4096+4092] = 8'h00; slot.mem[b*4096+4093] = 8'hF1; end
      reset = 1; repeat (3) @(negedge clk); reset = 0; repeat (3) @(negedge clk);
      for (b = 0; b < 4; b = b + 1) top.core.u_riot.ram[b] = 8'h00;
      sreg_wr(4'd3, {2'b10, 3'd3, 1'b1});                  // run, F6, Superchip
      sreg_rd(4'd3, v); expect8("control readback with SC", v, 8'h27);
      wait_loaded;
      #6000000;                                           // fill + verify twice ~ 3.5 ms of console time
      expect8("F6SC: fill+verify flag", top.core.u_riot.ram[0], 8'h11);
      expect8("F6SC: RAM[0] via $1080", top.core.u_riot.ram[1], 8'hA5);
      expect8("F6SC: $1000 read = ROM", top.core.u_riot.ram[2], 8'h77);
      expect8("F6SC: RAM[127] via $10FF", top.core.u_riot.ram[3], 8'hDA);
      expect8("F6SC: RAM[5] direct",  top.core.sc_ram[5], 8'hA0);
      sreg_rd(4'd8, v); expect8("F6SC: miss counter", v, 8'h00);
      // the same image with the SC bit off: the window is plain ROM, so the program must NOT find its bytes
      reset = 1; repeat (3) @(negedge clk); reset = 0; repeat (3) @(negedge clk);
      for (b = 0; b < 4; b = b + 1) top.core.u_riot.ram[b] = 8'h00;
      sreg_wr(4'd3, {2'b00, 3'd3, 1'b1});
      wait_loaded;
      #6000000;
      if (top.core.u_riot.ram[0] === 8'h11) begin errs = errs + 1; $display("FAIL  F6 without SC passed the Superchip test"); end
      else $display("ok    F6 without SC: the Superchip test fails, as it must");
    end
  endtask

  initial begin
    repeat (6) @(negedge clk);
    reset = 0;
    repeat (4) @(negedge clk);

    sreg_rd(4'd4, v); expect8("signature 'A'", v, 8'h41);
    sreg_rd(4'd7, v); expect8("version",       v, 8'h0E);
    sreg_rd(4'd13, v); expect8("dropped frames at start", v, 8'h00);
    if (loop_enable !== 1'b0 || busy !== 2'b00) begin errs = errs + 1; $display("FAIL  loop_enable/busy not idle"); end
    sreg_wr(4'd0, 8'hD7);
    sreg_wr(4'd1, 8'h3F);
    sreg_wr(4'd2, 8'h01);
    sreg_wr(4'd3, 8'h03);                                // run, mapper 1 (4K)
    sreg_rd(4'd3, v); expect8("control readback", v, 8'h03);
    sreg_rd(4'd11, v); expect8("status: not loaded yet", v & 8'h10, 8'h00);
    wait_loaded;                                         // the core is held until then
    sreg_rd(4'd11, v); expect8("status: loaded", v & 8'h10, 8'h10);

    #3000000;                                            // let the program start the tone
    watch = 1;
    #41000000;                                           // total ~44 ms: no VSYNC in this program, so the
                                                         // first frame (lines 320..639) is published by now
    watch = 0;

    expect8("RAM $80 = SWCHA",  top.core.u_riot.ram[0], 8'hD7);
    expect8("RAM $81 = SWCHB",  top.core.u_riot.ram[1], 8'h3F);
    expect8("RAM $82 = INPT4",  top.core.u_riot.ram[2], 8'h8C);   // D5..D0 = last bus byte ($0C, the operand), Passo 29

    sreg_rd(4'd11, v); expect8("status: rom_miss/ovf clear", v & 8'h60, 8'h00);
    sreg_rd(4'd0, v); expect8("R0 = newest buffer, other bits 0", v, 8'h01);
    sreg_rd(4'd1, v);
    if (v == 8'h00) begin errs = errs + 1; $display("FAIL  no frame published"); end
    else $display("ok    frames published = %0d", v);
    sreg_rd(4'd2, v); expect8("picture lines", v, 8'hE8);

    base = 20'h88000;                                    // the first frame goes to buffer 1
    bad_a = 0; bad_b = 0;                                // through the map (+$0010) and the tile list (+$0800)
    for (ty = 0; ty < 28; ty = ty + 1)
      for (tx = 0; tx < 32; tx = tx + 1) begin
        ent = slot.mem[base + 16 + 2 * (ty * 32 + tx)] + 256 * slot.mem[base + 17 + 2 * (ty * 32 + tx)];
        if (ent !== ((tx == 6 || tx == 7 || tx == 16 || tx == 17) ? 1 : 0)) bad_b = bad_b + 1;
        for (r = 0; r < 8; r = r + 1) begin
          idx = base + 20'h0800 + ent * 16 + r * 2;
          if (tx == 6 || tx == 7 || tx == 16 || tx == 17) begin
            if (slot.mem[idx] !== 8'hFF || slot.mem[idx + 1] !== 8'h00) bad_a = bad_a + 1;
          end else begin
            if (slot.mem[idx] !== 8'h00 || slot.mem[idx + 1] !== 8'h00) bad_a = bad_a + 1;
          end
        end
      end
    if (bad_a != 0 || bad_b != 0) begin
      errs = errs + 1;
      $display("FAIL  frame buffer: %0d wrong tile words, %0d wrong map entries", bad_a, bad_b);
    end else
      $display("ok    frame buffer: map and tile list correct (232 lines, 20 tiles 1:1 in columns 6..25)");
    expect8("header: distinct tiles", slot.mem[base], 8'h02);
    sreg_rd(4'd14, v); expect8("tile count register", v, 8'h02);
    sreg_rd(4'd15, v); expect8("tile count register, high", v, 8'h00);

    // square wave on channel 0 with AUDV = 15: mix swings 0..15,
    // sample = (mix - 15) * 1536 swings -23040 .. 0
    if (mix_min == 0 && mix_max == 15) $display("ok    audio mix swings %0d..%0d", mix_min, mix_max);
    else begin errs = errs + 1; $display("FAIL  audio mix range %0d..%0d, expected 0..15", mix_min, mix_max); end
    if (smp_min == -23040 && smp_max == 0) $display("ok    audio sample swings %0d..%0d", smp_min, smp_max);
    else begin errs = errs + 1; $display("FAIL  audio sample range %0d..%0d, expected -23040..0", smp_min, smp_max); end

    // ---- pause (reg 3 bit 4): no colour clocks, nothing reset, frame and audio held ----
    // ---- vertical offset (reg 6, signed, clamped to -16..+47) and lock (reg 7) ----------
    sreg_wr(4'd6, 8'h25); sreg_rd(4'd10, v); expect8("offset +37 readback", v, 8'h25);
    sreg_wr(4'd6, 8'h2F); sreg_rd(4'd10, v); expect8("offset +47 readback", v, 8'h2F);
    sreg_wr(4'd6, 8'h30); sreg_rd(4'd10, v); expect8("offset +48 clamps to +47", v, 8'h2F);
    sreg_wr(4'd6, 8'h7F); sreg_rd(4'd10, v); expect8("offset +127 clamps to +47", v, 8'h2F);
    sreg_wr(4'd6, 8'hFF); sreg_rd(4'd10, v); expect8("offset -1 readback", v, 8'hFF);
    sreg_wr(4'd6, 8'hF0); sreg_rd(4'd10, v); expect8("offset -16 readback", v, 8'hF0);
    sreg_wr(4'd6, 8'hEF); sreg_rd(4'd10, v); expect8("offset -17 clamps to -16", v, 8'hF0);
    sreg_wr(4'd6, 8'h80); sreg_rd(4'd10, v); expect8("offset -128 clamps to -16", v, 8'hF0);
    sreg_wr(4'd6, 8'h00); sreg_rd(4'd10, v); expect8("offset 0 readback", v, 8'h00);
    sreg_wr(4'd7, 8'hFE); sreg_rd(4'd12, v); expect8("lock readback (valid, 2)", v, 8'h82);
    if (top.vid.lock_v !== 1'b1 || top.vid.lock_i !== 2'd2) begin errs = errs + 1; $display("FAIL  lock does not reach the writer"); end
    sreg_wr(4'd7, 8'h01); sreg_rd(4'd12, v); expect8("lock readback (released)", v, 8'h01);
    sreg_wr(4'd7, 8'h00);
    // palette (reg 8, bits 1:0): reaches the writer, which takes it only when VSYNC ends
    if (top.vid.pal !== 2'd0) begin errs = errs + 1; $display("FAIL  palette after reset is not 0"); end
    sreg_wr(4'd8, 8'hFE);
    if (top.vid.pal !== 2'd2) begin errs = errs + 1; $display("FAIL  reg 8 = $FE does not give palette 2"); end
    else $display("ok    reg 8 = $FE -> palette 2 at the writer (bits 7:2 ignored)");
    sreg_wr(4'd8, 8'h03);
    if (top.vid.pal !== 2'd3) begin errs = errs + 1; $display("FAIL  reg 8 = 3 does not give palette 3"); end
    else $display("ok    reg 8 = 3 -> palette 3 at the writer");
    sreg_wr(4'd8, 8'h00);
    if (top.vid.pal !== 2'd0) begin errs = errs + 1; $display("FAIL  reg 8 = 0 does not give palette 0"); end
    sreg_wr(4'd3, 8'h13);                                // run, mapper 1, pause
    sreg_rd(4'd3, v); expect8("control readback (pause)", v, 8'h13);
    repeat (60000) @(negedge clk);                       // the dictionary may still be writing a tile row
    sreg_rd(4'd1, v); pz_frames = v;
    pz_ab = top.core.cpu_ab; pz_hc = top.core.hcount; pz_mix = aud_mix; pz_pc = top.core.u_cpu.PC;
    pz_sum = 0;
    for (k = 0; k < 98304; k = k + 1) pz_sum = pz_sum + slot.mem[20'h80000 + k] * (k + 1);
    pz_cc = 0; pz_wr = 0; pz_mixchg = 0; pz_on = 1;
    repeat (400000) @(negedge clk);                      // ~60 scan lines' worth of clocks
    pz_on = 0;
    expect8("pause: colour clocks",        pz_cc[7:0] | {8{|pz_cc[31:8]}}, 8'h00);
    expect8("pause: frame-buffer writes",  pz_wr[7:0] | {8{|pz_wr[31:8]}}, 8'h00);
    expect8("pause: audio level changes",  pz_mixchg[7:0], 8'h00);
    expect8("pause: audio level held",     {3'b000, aud_mix}, {3'b000, pz_mix});
    expect8("pause: scan position held",   top.core.hcount, pz_hc);
    if (top.core.cpu_ab !== pz_ab || top.core.u_cpu.PC !== pz_pc) begin errs = errs + 1; $display("FAIL  pause: CPU moved"); end
    else $display("ok    pause: CPU held at %04h", pz_ab);
    k2 = 0;
    for (k = 0; k < 98304; k = k + 1) k2 = k2 + slot.mem[20'h80000 + k] * (k + 1);
    if (k2 !== pz_sum) begin errs = errs + 1; $display("FAIL  pause: frame buffer changed"); end
    else $display("ok    pause: frame buffer unchanged");
    sreg_rd(4'd1, v); expect8("pause: frame counter held", v, pz_frames);
    sreg_rd(4'd11, v); expect8("pause: still loaded, no miss", v & 8'h50, 8'h10);
    sreg_wr(4'd3, 8'h03);                                // resume
    pz_mixchg = 0; pz_on = 1;
    #25000000;                                           // more than one frame (320 lines = 19.6 ms)
    pz_on = 0;
    sreg_rd(4'd1, v);
    if (v <= pz_frames) begin errs = errs + 1; $display("FAIL  resume: frame counter %0d, was %0d (reset or stuck)", v, pz_frames); end
    else $display("ok    resume: frame counter went on from %0d to %0d (no reset)", pz_frames, v);
    if (pz_mixchg == 0) begin errs = errs + 1; $display("FAIL  resume: audio did not come back"); end
    else $display("ok    resume: audio running again");
    expect8("resume: RAM $80 kept", top.core.u_riot.ram[0], 8'hD7);

    // ---- diagnostics --------------------------------------------------------------
    sreg_rd(4'd8, v); expect8("miss counter", v, 8'h00);
    sreg_rd(4'd9, v);
    if (v == 8'h00 || v > 8'd60) begin errs = errs + 1; $display("FAIL  loader (slot) latency = %0d clk", v); end
    else $display("ok    loader (slot) latency = %0d clk", v);

    // With the ROM in block RAM a miss cannot happen any more; hold rom_ack down to
    // make some (the CPU then runs on stale bytes, so this comes after the checks above)
    force top.memc.rom_ack = 1'b0;
    repeat (14000) @(negedge clk);                       // > 2 scan lines
    release top.memc.rom_ack;
    repeat (400) @(negedge clk);
    sreg_rd(4'd11, v); expect8("rom_miss flag after forced misses", v & 8'h40, 8'h40);
    sreg_rd(4'd8, v);
    if (v < 8'd2) begin errs = errs + 1; $display("FAIL  miss counter = %0d, expected several", v); end
    else $display("ok    miss counter after forced misses = %0d", v);

    sreg_wr(4'd5, 8'h00);                                // clear the diagnostics
    sreg_rd(4'd11, v); expect8("flags after clear (loaded stays)", v & 8'h50, 8'h10);
    sreg_rd(4'd8, v); expect8("miss counter after clear", v, 8'h00);
    sreg_rd(4'd9, v); expect8("loader latency after clear", v, 8'h00);
    sreg_rd(4'd3, v); expect8("control untouched by reg 5", v, 8'h03);

    // ---- every supported mapper runs from the block RAM (4K was the program above) ----
    run_2k;
    run_banked(3'd1, 1, 8'h00, 8'hB0);                   // 4K again, with the common skeleton
    run_banked(3'd2, 2, 8'hF8, 8'hC0);                   // F8: hotspots $1FF8/$1FF9
    run_banked(3'd3, 4, 8'hF6, 8'hD0);                   // F6: hotspots $1FF6..$1FF9
    run_fe;                                              // FE: bank from the byte after $01FE
    run_sc;                                              // F6 + Superchip RAM (register 3 bit 5)
    expect8("CPU cycles before loaded", {7'b0, early}, 8'h00);

    if (errs == 0) $display("PASS  a26_top");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end

  initial begin
    #600000000;
    $display("FAIL  global timeout");
    $finish;
  end
endmodule
