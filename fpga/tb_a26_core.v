// SPDX-License-Identifier: GPL-2.0-or-later
// tb_a26_core.v -- integration test for a26_core.v
//
// Two cores run two tiny hand-assembled programs against a ROM model with a
// fixed read latency:
//   core A (4K mapper): RAM, stack (JSR/RTS in the RIOT RAM), TIA writes,
//                       WSYNC halting, RIOT timer polling.
//   core B (F8 mapper): bank switching through the $1FF8 / $1FF9 hotspots.
//   core C (F8 + Superchip): fills the 128 bytes of RAM through $1000-$107F, reads them back through
//                       $1080-$10FF, switches bank and sees the same RAM; a read of the write port
//                       gives the ROM byte; the ROM bytes under the window are never seen.
//
// run:  iverilog -g2005 -Wall -o tb_core tb_a26_core.v a26_core.v m6507.v \
//                riot6532.v tia.v tia_audio.v && vvp tb_core
`timescale 1ns / 1ps

// --------------------------------------------------------------------------
module rom_model #(parameter LAT = 3) (
  input             clk,
  input             rd,
  input      [14:0] addr,
  output reg [7:0]  data,
  output reg        ack
);
  reg [7:0]  mem [0:32767];
  reg [3:0]  cnt;
  reg [14:0] a_l;
  reg        busy;
  initial begin busy = 0; ack = 0; data = 8'hEA; cnt = 0; a_l = 0; end
  always @(posedge clk) begin
    ack <= 1'b0;
    if (rd && !busy) begin
      busy <= 1'b1; cnt <= LAT; a_l <= addr;
    end else if (busy) begin
      if (cnt == 4'd1) begin data <= mem[a_l]; ack <= 1'b1; busy <= 1'b0; end
      else cnt <= cnt - 4'd1;
    end
  end
endmodule

// --------------------------------------------------------------------------
module tb_a26_core;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;

  integer errs = 0;

  // ---------------- core A : 4K ------------------------------------------
  wire [14:0] a_addr;  wire a_rd, a_ack;  wire [7:0] a_data;
  wire        a_stb, a_vis, a_rdy, a_miss, a_vs, a_vb, a_sync;
  wire [7:0]  a_px, a_hc;
  wire [1:0]  a_src;
  wire [6:0]  a_col, a_cbk, a_cpf, a_cp0, a_cp1;
  wire [4:0]  a_aud;
  wire [15:0] a_ab;

  a26_core #(.CC_INC(25'd8388608)) coreA (
    .clk(clk), .rst(rst), .mapper(3'd1), .sc_en(1'b0),
    .swcha_in(8'hFF), .swchb_in(8'hFF), .fire0(1'b1), .fire1(1'b1), .inpt(4'h0), .pause(1'b0),
    .rom_addr(a_addr), .rom_rd(a_rd), .rom_data(a_data), .rom_ack(a_ack),
    .pix_stb(a_stb), .pix_x(a_px), .pix_vis(a_vis), .pix_src(a_src), .pix_col(a_col),
    .hcount(a_hc), .vsync(a_vs), .vblank(a_vb),
    .colubk(a_cbk), .colupf(a_cpf), .colup0(a_cp0), .colup1(a_cp1),
    .aud_mix(a_aud), .cpu_rdy(a_rdy), .cpu_ab(a_ab), .cpu_sync(a_sync), .rom_miss(a_miss),
    .diag_clr(1'b0), .rom_miss_ev());
  rom_model #(.LAT(3)) romA (.clk(clk), .rd(a_rd), .addr(a_addr), .data(a_data), .ack(a_ack));

  // ---------------- core B : F8 ------------------------------------------
  wire [14:0] b_addr;  wire b_rd, b_ack;  wire [7:0] b_data;
  wire        b_stb, b_vis, b_rdy, b_miss, b_vs, b_vb, b_sync;
  wire [7:0]  b_px, b_hc;
  wire [1:0]  b_src;
  wire [6:0]  b_col, b_cbk, b_cpf, b_cp0, b_cp1;
  wire [4:0]  b_aud;
  wire [15:0] b_ab;

  a26_core #(.CC_INC(25'd8388608)) coreB (
    .clk(clk), .rst(rst), .mapper(3'd2), .sc_en(1'b0),
    .swcha_in(8'hFF), .swchb_in(8'hFF), .fire0(1'b1), .fire1(1'b1), .inpt(4'h0), .pause(1'b0),
    .rom_addr(b_addr), .rom_rd(b_rd), .rom_data(b_data), .rom_ack(b_ack),
    .pix_stb(b_stb), .pix_x(b_px), .pix_vis(b_vis), .pix_src(b_src), .pix_col(b_col),
    .hcount(b_hc), .vsync(b_vs), .vblank(b_vb),
    .colubk(b_cbk), .colupf(b_cpf), .colup0(b_cp0), .colup1(b_cp1),
    .aud_mix(b_aud), .cpu_rdy(b_rdy), .cpu_ab(b_ab), .cpu_sync(b_sync), .rom_miss(b_miss),
    .diag_clr(1'b0), .rom_miss_ev());
  rom_model #(.LAT(3)) romB (.clk(clk), .rd(b_rd), .addr(b_addr), .data(b_data), .ack(b_ack));

  // ---------------- core C : F8 + Superchip ------------------------------
  wire [14:0] c_addr;  wire c_rd, c_ack;  wire [7:0] c_data;
  wire        c_stb, c_vis, c_rdy, c_miss, c_vs, c_vb, c_sync;
  wire [7:0]  c_px, c_hc;
  wire [1:0]  c_src;
  wire [6:0]  c_col, c_cbk, c_cpf, c_cp0, c_cp1;
  wire [4:0]  c_aud;
  wire [15:0] c_ab;

  a26_core #(.CC_INC(25'd8388608)) coreC (
    .clk(clk), .rst(rst), .mapper(3'd2), .sc_en(1'b1),
    .swcha_in(8'hFF), .swchb_in(8'hFF), .fire0(1'b1), .fire1(1'b1), .inpt(4'h0), .pause(1'b0),
    .rom_addr(c_addr), .rom_rd(c_rd), .rom_data(c_data), .rom_ack(c_ack),
    .pix_stb(c_stb), .pix_x(c_px), .pix_vis(c_vis), .pix_src(c_src), .pix_col(c_col),
    .hcount(c_hc), .vsync(c_vs), .vblank(c_vb),
    .colubk(c_cbk), .colupf(c_cpf), .colup0(c_cp0), .colup1(c_cp1),
    .aud_mix(c_aud), .cpu_rdy(c_rdy), .cpu_ab(c_ab), .cpu_sync(c_sync), .rom_miss(c_miss),
    .diag_clr(1'b0), .rom_miss_ev());
  rom_model #(.LAT(3)) romC (.clk(clk), .rd(c_rd), .addr(c_addr), .data(c_data), .ack(c_ack));

  // ---------------- program images ---------------------------------------
  integer k;

  task pa; input [11:0] off; input [7:0] v; begin romA.mem[off] = v; end endtask
  task pb; input [14:0] off; input [7:0] v; begin romB.mem[off] = v; end endtask
  task pc; input [14:0] off; input [7:0] v; begin romC.mem[off] = v; end endtask

  initial begin
    for (k = 0; k < 32768; k = k + 1) begin romA.mem[k] = 8'hEA; romB.mem[k] = 8'hEA; romC.mem[k] = 8'hEA; end

    // ---- program A (4K at $F000) ----
    pa(12'h000, 8'h78);                                   // SEI
    pa(12'h001, 8'hD8);                                   // CLD
    pa(12'h002, 8'hA2); pa(12'h003, 8'hFF);               // LDX #$FF
    pa(12'h004, 8'h9A);                                   // TXS
    pa(12'h005, 8'hA9); pa(12'h006, 8'h5A);               // LDA #$5A
    pa(12'h007, 8'h85); pa(12'h008, 8'h80);               // STA $80
    pa(12'h009, 8'hA9); pa(12'h00A, 8'h0E);               // LDA #$0E
    pa(12'h00B, 8'h85); pa(12'h00C, 8'h08);               // STA COLUPF
    pa(12'h00D, 8'hA9); pa(12'h00E, 8'hF0);               // LDA #$F0
    pa(12'h00F, 8'h85); pa(12'h010, 8'h0D);               // STA PF0
    pa(12'h011, 8'h20); pa(12'h012, 8'h30); pa(12'h013, 8'hF0);   // JSR $F030
    pa(12'h014, 8'h85); pa(12'h015, 8'h02);               // STA WSYNC
    pa(12'h016, 8'hA9); pa(12'h017, 8'h05);               // LDA #$05
    pa(12'h018, 8'h8D); pa(12'h019, 8'h96); pa(12'h01A, 8'h02);   // STA TIM64T
    pa(12'h01B, 8'hAD); pa(12'h01C, 8'h84); pa(12'h01D, 8'h02);   // loop: LDA INTIM
    pa(12'h01E, 8'hD0); pa(12'h01F, 8'hFB);               // BNE loop
    pa(12'h020, 8'hA9); pa(12'h021, 8'hAA);               // LDA #$AA
    pa(12'h022, 8'h85); pa(12'h023, 8'h81);               // STA $81
    pa(12'h024, 8'h4C); pa(12'h025, 8'h24); pa(12'h026, 8'hF0);   // JMP *
    pa(12'h030, 8'hA9); pa(12'h031, 8'h77);               // sub: LDA #$77
    pa(12'h032, 8'h85); pa(12'h033, 8'h82);               //      STA $82
    pa(12'h034, 8'h60);                                   //      RTS
    pa(12'hFFC, 8'h00); pa(12'hFFD, 8'hF0);               // reset vector

    // ---- program B (F8, 2 x 4K) : starts in bank 1 ----
    pb(15'h1000, 8'hAD); pb(15'h1001, 8'hF8); pb(15'h1002, 8'h1F);   // bank1: LDA $1FF8 (-> bank 0)
    pb(15'h100A, 8'hA9); pb(15'h100B, 8'h33);                        // bank1 @F00A: LDA #$33
    pb(15'h100C, 8'h85); pb(15'h100D, 8'h81);                        //              STA $81
    pb(15'h100E, 8'h4C); pb(15'h100F, 8'h0E); pb(15'h1010, 8'hF0);   //              JMP *
    pb(15'h0003, 8'hA9); pb(15'h0004, 8'h22);                        // bank0 @F003: LDA #$22
    pb(15'h0005, 8'h85); pb(15'h0006, 8'h80);                        //              STA $80
    pb(15'h0007, 8'hAD); pb(15'h0008, 8'hF9); pb(15'h0009, 8'h1F);   //              LDA $1FF9 (-> bank 1)
    pb(15'h1FFC, 8'h00); pb(15'h1FFD, 8'hF0);                        // vectors, bank 1
    pb(15'h0FFC, 8'h00); pb(15'h0FFD, 8'hF0);                        // vectors, bank 0
    // ---- program C (F8 + Superchip, 2 x 4K): the first 256 bytes of a bank are the RAM, code starts at $F100 ----
    // bank 1 (power-on): RAM[x] = x ^ $A5 through $1000,X ; verify through $1080,X (CMP) ; flag $80 = $11 ; LDA $1FF8 -> bank 0
    pc(15'h1100, 8'hA2); pc(15'h1101, 8'h7F);                        // LDX #$7F
    pc(15'h1102, 8'h8A);                                             // fill: TXA
    pc(15'h1103, 8'h49); pc(15'h1104, 8'hA5);                        //       EOR #$A5
    pc(15'h1105, 8'h9D); pc(15'h1106, 8'h00); pc(15'h1107, 8'h10);   //       STA $1000,X
    pc(15'h1108, 8'hCA);                                             //       DEX
    pc(15'h1109, 8'h10); pc(15'h110A, 8'hF7);                        //       BPL fill
    pc(15'h110B, 8'hA2); pc(15'h110C, 8'h7F);                        //       LDX #$7F
    pc(15'h110D, 8'h8A);                                             // chk:  TXA
    pc(15'h110E, 8'h49); pc(15'h110F, 8'hA5);                        //       EOR #$A5
    pc(15'h1110, 8'hDD); pc(15'h1111, 8'h80); pc(15'h1112, 8'h10);   //       CMP $1080,X
    pc(15'h1113, 8'hD0); pc(15'h1114, 8'h1B);                        //       BNE bad
    pc(15'h1115, 8'hCA);                                             //       DEX
    pc(15'h1116, 8'h10); pc(15'h1117, 8'hF5);                        //       BPL chk
    pc(15'h1118, 8'hA9); pc(15'h1119, 8'h11);                        //       LDA #$11
    pc(15'h111A, 8'h85); pc(15'h111B, 8'h80);                        //       STA $80
    pc(15'h111C, 8'hAD); pc(15'h111D, 8'hF8); pc(15'h111E, 8'h1F);   //       LDA $1FF8 (-> bank 0)
    pc(15'h1130, 8'hA9); pc(15'h1131, 8'hEE);                        // bad:  LDA #$EE
    pc(15'h1132, 8'h85); pc(15'h1133, 8'h80);                        //       STA $80
    pc(15'h1134, 8'h4C); pc(15'h1135, 8'h34); pc(15'h1136, 8'hF1);   //       JMP *
    // bank 0: the same RAM is there; a read of the write port ($1000) gives the ROM byte ($77 at image offset 0)
    pc(15'h0000, 8'h77);
    pc(15'h011F, 8'hAD); pc(15'h0120, 8'h00); pc(15'h0121, 8'h10);   //       LDA $1000
    pc(15'h0122, 8'h85); pc(15'h0123, 8'h82);                        //       STA $82
    pc(15'h0124, 8'hAD); pc(15'h0125, 8'h80); pc(15'h0126, 8'h10);   //       LDA $1080
    pc(15'h0127, 8'h85); pc(15'h0128, 8'h81);                        //       STA $81
    pc(15'h0129, 8'hAD); pc(15'h012A, 8'hFF); pc(15'h012B, 8'h10);   //       LDA $10FF
    pc(15'h012C, 8'h85); pc(15'h012D, 8'h83);                        //       STA $83
    pc(15'h012E, 8'h4C); pc(15'h012F, 8'h2E); pc(15'h0130, 8'hF1);   //       JMP *
    pc(15'h1FFC, 8'h00); pc(15'h1FFD, 8'hF1);
    pc(15'h0FFC, 8'h00); pc(15'h0FFD, 8'hF1);
  end

  // ---------------- video capture (core A) -------------------------------
  reg [1:0] lb_src [0:159];
  reg       lb_vis [0:159];
  initial for (k = 0; k < 160; k = k + 1) begin lb_src[k] = 2'd0; lb_vis[k] = 1'b0; end
  always @(posedge clk) if (a_stb) begin lb_src[a_px] <= a_src; lb_vis[a_px] <= a_vis; end

  reg wsync_seen = 0;
  always @(posedge clk) if (!rst && !a_rdy) wsync_seen <= 1'b1;

  task expect8; input [8*24-1:0] nm; input [7:0] got; input [7:0] exp;
    begin
      if (got !== exp) begin
        errs = errs + 1;
        $display("FAIL  %0s: got %02h, expected %02h", nm, got, exp);
      end else
        $display("ok    %0s = %02h", nm, got);
    end
  endtask

  integer j, bad;

  initial begin
    repeat (8) @(posedge clk);
    rst = 0;
    #1000000;                                             // 1 ms of simulated time

    // ---- core A ----
    expect8("A ram[$80]",        coreA.u_riot.ram[0],   8'h5A);
    expect8("A ram[$81] timer",  coreA.u_riot.ram[1],   8'hAA);
    expect8("A ram[$82] subr",   coreA.u_riot.ram[2],   8'h77);
    expect8("A stack hi ($1FF)", coreA.u_riot.ram[127], 8'hF0);
    expect8("A stack lo ($1FE)", coreA.u_riot.ram[126], 8'h13);
    expect8("A rom_miss",        {7'b0, a_miss},        8'h00);
    expect8("A wsync seen",      {7'b0, wsync_seen},    8'h01);
    expect8("A COLUPF",          {1'b0, a_cpf},         8'h07);
    bad = 0;
    for (j = 0; j < 16;  j = j + 1) if (!(lb_vis[j] === 1'b1 && lb_src[j] === 2'd1)) bad = bad + 1;
    for (j = 16; j < 80; j = j + 1) if (!(lb_vis[j] === 1'b1 && lb_src[j] === 2'd0)) bad = bad + 1;
    for (j = 80; j < 96; j = j + 1) if (!(lb_vis[j] === 1'b1 && lb_src[j] === 2'd1)) bad = bad + 1;
    if (bad != 0) begin errs = errs + 1; $display("FAIL  A playfield: %0d wrong pixels", bad); end
    else $display("ok    A playfield F0 on screen");

    // ---- core B ----
    expect8("B ram[$80] bank0",  coreB.u_riot.ram[0],   8'h22);
    expect8("B ram[$81] bank1",  coreB.u_riot.ram[1],   8'h33);
    expect8("B rom_miss",        {7'b0, b_miss},        8'h00);

    // ---- core C (Superchip) ----
    expect8("C fill+verify flag", coreC.u_riot.ram[0],  8'h11);
    expect8("C ram[0] via $1080", coreC.u_riot.ram[1],  8'hA5);
    expect8("C $1000 read = ROM", coreC.u_riot.ram[2],  8'h77);
    expect8("C ram[127] $10FF",   coreC.u_riot.ram[3],  8'hDA);
    expect8("C sc_ram[5] direct", coreC.sc_ram[5],      8'hA0);
    expect8("C rom_miss",        {7'b0, c_miss},        8'h00);

    if (errs == 0) $display("PASS  a26_core");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end
endmodule
