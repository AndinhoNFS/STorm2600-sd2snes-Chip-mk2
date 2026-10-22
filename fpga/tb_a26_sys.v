// SPDX-License-Identifier: GPL-2.0-or-later
// tb_a26_sys.v -- end-to-end test of everything built so far, wired the way
// the shell will wire it:
//
//   SNES-side register window (a26_regs) -> a26_core -> a26_vidwr -> a26_tdict
//        -> a26_mem -> arbiter slot (slot_model, 16-bit PSRAM)
//
// A hand-assembled 4K program reads the console ports that the "SNES" wrote
// through the register window, sets up the playfield and loops.  The
// testbench then checks the RAM the program wrote, the frame-buffer words the
// video writer left in the PSRAM model and the status registers.
//
// run:  iverilog -g2005 -Wall -o tb_sys tb_a26_sys.v a26_regs.v a26_mem.v \
//          slot_model.v a26_core.v a26_vidwr.v a26_tdict.v m6507.v riot6532.v tia.v tia_audio.v && vvp tb_sys
`timescale 1ns / 1ps

module tb_a26_sys;
  parameter SLOT_LAT = 10;      // arbiter slot latency in clk (+0..7); -Ptb_a26_sys.SLOT_LAT=90 = six times slower
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;

  integer errs = 0;

  // ---- SNES-side register window ---------------------------------------
  reg  [3:0] reg_addr = 0;
  reg  [7:0] reg_data_in = 0;
  reg        reg_oe_falling = 0, reg_we_rising = 0;
  wire [7:0] reg_data_out;
  wire [7:0] swcha, swchb;
  wire       fire0, fire1, run, pause;
  wire [6:0] yofs;
  wire [1:0] pal;
  wire       lock_v;
  wire [1:0] lock_i, fb_newest;
  wire [3:0] inpt;
  wire [2:0] mapper;

  wire       rom_miss, fifo_ovf, loaded;
  wire [7:0] fb_frames, fb_nlines, fb_dropped;
  wire [9:0] tile_n;
  wire       diag_clr, rom_miss_ev;
  wire [7:0] lat_max;
  reg  [7:0] miss_cnt = 0;                     // same counter as in a26_top
  reg        miss_ev_r = 0;

  a26_regs regs (.clk(clk), .rst(rst), .enable(1'b1), .reg_addr(reg_addr),
                 .reg_data_in(reg_data_in), .reg_data_out(reg_data_out),
                 .reg_oe_falling(reg_oe_falling), .reg_we_rising(reg_we_rising),
                 .swcha(swcha), .swchb(swchb), .fire0(fire0), .fire1(fire1),
                 .inpt(inpt), .run(run), .mapper(mapper), .pause(pause),
                 .yofs(yofs), .pal(pal), .lock_v(lock_v), .lock_i(lock_i),
                 .fb_newest(fb_newest), .fb_frames(fb_frames), .fb_nlines(fb_nlines),
                 .fb_dropped(fb_dropped), .tile_n(tile_n),
                 .rom_miss(rom_miss), .fifo_ovf(fifo_ovf), .loaded(loaded),
                 .diag_clr(diag_clr), .miss_cnt(miss_cnt), .lat_max(lat_max));
  wire core_rst = rst | ~run | ~loaded;        // as in a26_top: the core waits for the ROM
  wire diag_rst = diag_clr | core_rst;
  always @(posedge clk) begin
    miss_ev_r <= rom_miss_ev;
    if (diag_rst)                            miss_cnt <= 8'd0;
    else if (miss_ev_r && miss_cnt != 8'hFF) miss_cnt <= miss_cnt + 8'd1;
  end

  // ---- core ---------------------------------------------------------------
  wire [14:0] rom_addr;
  wire        rom_rd, rom_ack;
  wire [7:0]  rom_data;
  wire        pix_stb, pix_vis, vsync, vblank, cpu_rdy, cpu_sync;
  wire [7:0]  pix_x, hcount;
  wire [1:0]  pix_src;
  wire [6:0]  pix_col, colubk, colupf, colup0, colup1;
  wire [4:0]  aud_mix;
  wire [15:0] cpu_ab;

  // default CC_INC = 1251142: the real 96 MHz clock, so one CPU cycle is ~80 clk
  // and the arbiter latency is tested against the real time budget
  a26_core core (
    .clk(clk), .rst(core_rst), .mapper(mapper),
    .swcha_in(swcha), .swchb_in(swchb), .fire0(fire0), .fire1(fire1), .inpt(inpt), .pause(pause),
    .rom_addr(rom_addr), .rom_rd(rom_rd), .rom_data(rom_data), .rom_ack(rom_ack),
    .pix_stb(pix_stb), .pix_x(pix_x), .pix_vis(pix_vis), .pix_src(pix_src), .pix_col(pix_col),
    .hcount(hcount), .vsync(vsync), .vblank(vblank),
    .colubk(colubk), .colupf(colupf), .colup0(colup0), .colup1(colup1),
    .aud_mix(aud_mix), .cpu_rdy(cpu_rdy), .cpu_ab(cpu_ab), .cpu_sync(cpu_sync),
    .rom_miss(rom_miss), .diag_clr(diag_clr), .rom_miss_ev(rom_miss_ev));

  // ---- video writer -----------------------------------------------------
  wire        fb_wr;
  wire [15:0] fb_waddr;
  wire [15:0] fb_wdata;

  a26_vidwr vid (.clk(clk), .rst(core_rst),
                 .pix_stb(pix_stb), .pix_x(pix_x), .pix_vis(pix_vis), .pix_src(pix_src), .pix_col(pix_col),
                 .vsync(vsync), .vblank(vblank),
                 .colubk(colubk), .colupf(colupf), .colup0(colup0), .colup1(colup1),
                 .fb_wr(fb_wr), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata),
                 .fb_newest(fb_newest), .fb_frames(fb_frames), .fb_nlines(fb_nlines),
                 .lock_v(lock_v), .lock_i(lock_i), .yofs(yofs), .pal(pal),
                 .ev_row(ev_row), .ev_end(ev_end), .end_lines(end_lines),
                 .eng_ack(eng_ack), .eng_ovf(eng_ovf), .fb_dropped(fb_dropped));

  // ---- tile dictionary ----------------------------------------------------
  wire        ev_row, ev_end, eng_ack, eng_ovf, m_wr, fifo_low, wr_idle;
  wire [7:0]  end_lines;
  wire [15:0] m_waddr, m_wdata;
  a26_tdict dict (.clk(clk), .rst(core_rst),
                  .v_wr(fb_wr), .v_waddr(fb_waddr), .v_wdata(fb_wdata),
                  .ev_row(ev_row), .ev_end(ev_end), .end_lines(end_lines),
                  .eng_ack(eng_ack), .eng_ovf(eng_ovf), .tile_n(tile_n),
                  .m_wr(m_wr), .m_waddr(m_waddr), .m_wdata(m_wdata),
                  .fifo_low(fifo_low), .wr_idle(wr_idle));

  // ---- memory client + arbiter slot --------------------------------------
  wire        BUS_RDY, BUS_RRQ, BUS_WRQ, ROM_WORD_ENABLE;
  wire [23:0] ROM_ADDR;
  wire [15:0] ROM_DATA_OUT, ROM_DATA_IN;

  a26_mem memc (.clk(clk), .rst(rst),
                .core_addr(rom_addr), .rom_rd(rom_rd), .rom_data(rom_data), .rom_ack(rom_ack),
                .fb_wr(m_wr), .fb_waddr(m_waddr), .fb_wdata(m_wdata),
                .BUS_RDY(BUS_RDY), .BUS_RRQ(BUS_RRQ), .BUS_WRQ(BUS_WRQ),
                .ROM_ADDR(ROM_ADDR), .ROM_DATA_OUT(ROM_DATA_OUT),
                .ROM_WORD_ENABLE(ROM_WORD_ENABLE), .ROM_DATA_IN(ROM_DATA_IN),
                .fifo_ovf(fifo_ovf), .fifo_low(fifo_low), .wr_idle(wr_idle),
                .loaded(loaded), .diag_clr(diag_clr), .rd_lat_max(lat_max));

  // the CPU must not take a single cycle before the block RAM is loaded
  // (rom_rd itself is high all through the core's reset, by design)
  reg early = 0;
  integer fifo_max = 0, wr_words = 0;       // deepest FIFO fill, words written to the PSRAM
  always @(posedge clk) begin
    if (memc.cnt > fifo_max) fifo_max = memc.cnt;
    if (BUS_WRQ) wr_words = wr_words + 1;
  end
  always @(posedge clk) if (core.cpu_ce && !loaded) early = 1;

  slot_model #(.LAT(SLOT_LAT)) slot (.clk(clk), .RRQ(BUS_RRQ), .WRQ(BUS_WRQ), .ADDR(ROM_ADDR),
                               .DOUT(ROM_DATA_OUT), .WORD(ROM_WORD_ENABLE),
                               .RDY(BUS_RDY), .DIN(ROM_DATA_IN));

  // ---- program: ROM_BASE = $300000 -> model index 0 ---------------------
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
    pr(12'h01B, 8'h4C); pr(12'h01C, 8'h1B); pr(12'h01D, 8'hF0);   // JMP *
    pr(12'hFFC, 8'h00); pr(12'hFFD, 8'hF0);               // reset vector
  end

  // ---- SNES-side bus tasks -----------------------------------------------
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

  integer ty, tx, r, bad_a, bad_b, base, idx, ent;
  reg [7:0] v;

  initial begin
    repeat (6) @(negedge clk);
    rst = 0;
    repeat (4) @(negedge clk);

    // the "SNES player" fills the window, then starts the core
    sreg_rd(3'd4, v); expect8("signature 'A'", v, 8'h41);
    sreg_rd(3'd5, v); expect8("signature '2'", v, 8'h32);
    sreg_wr(3'd0, 8'hD7);                                // SWCHA
    sreg_wr(3'd1, 8'h3F);                                // SWCHB
    sreg_wr(3'd2, 8'h01);                                // fire0 released, fire1 pressed
    sreg_wr(3'd3, 8'h03);                                // run = 1, mapper = 1 (4K)
    sreg_rd(3'd3, v); expect8("control readback", v, 8'h03);

    sreg_rd(4'd11, v); expect8("status: not loaded yet", v & 8'h10, 8'h00);
    k = 0;
    while (loaded !== 1'b1 && k < 2000000) begin @(negedge clk); k = k + 1; end
    $display("      ROM loaded %0d clk after run was set", k);
    sreg_rd(4'd11, v); expect8("status: loaded", v & 8'h10, 8'h10);

    #44000000;                                           // 44 ms = ~688 lines (a line is ~61 us): the
                                                         // program has no VSYNC, so the first frame starts
                                                         // after 320 lines and is published after 640

    // ---- what the program saw through the console ports ---------------
    expect8("RAM $80 = SWCHA",  core.u_riot.ram[0], 8'hD7);
    expect8("RAM $81 = SWCHB",  core.u_riot.ram[1], 8'h3F);
    expect8("RAM $82 = INPT4",  core.u_riot.ram[2], 8'h8C);   // D5..D0 = last bus byte ($0C, the operand), Passo 29
    expect8("rom_miss",         {7'b0, rom_miss},   8'h00);
    expect8("CPU cycles before loaded", {7'b0, early}, 8'h00);
    expect8("fifo overflow",    {7'b0, fifo_ovf},   8'h00);
    $display("      slot latency %0d clk (+0..7): FIFO filled to %0d of 16, %0d words written", SLOT_LAT, fifo_max, wr_words);

    // ---- status registers ----------------------------------------------
    sreg_rd(3'd1, v);
    if (v == 8'h00) begin errs = errs + 1; $display("FAIL  no frame published"); end
    else $display("ok    frames published = %0d", v);
    sreg_rd(3'd2, v); expect8("picture lines", v, 8'hE8);        // 232 = MAXLINES

    // ---- diagnostics: no miss, and a latency inside the CPU cycle (~80 clk) ----
    sreg_rd(4'd8, v); expect8("miss counter", v, 8'h00);
    sreg_rd(4'd9, v);
    if (v == 8'h00 || v > SLOT_LAT + 50) begin errs = errs + 1; $display("FAIL  loader (slot) latency = %0d clk", v); end
    else $display("ok    loader (slot) latency = %0d clk", v);

    // ---- the first frame, in buffer 1, as left in the PSRAM model ------------
    // playfield PF0=$F0: TIA pixels 0..15 and 80..95 use colour source 1.  1:1 from tile 6:
    //   tiles 6, 7 and 16, 17 are all playfield (plane0 = $FF); plane1 = $00 everywhere
    sreg_rd(4'd0, v); expect8("R0 = newest buffer", v, 8'h01);
    base = 20'h88000;                                    // buffer 1 = PSRAM $388000 -> model index
    // through the map: tile (ty, tx) is map entry ty*32 + tx at +$0010, its 16 bytes at
    // +$0800 + 16 * entry.  Two distinct tiles: 0 = background, 1 = playfield
    bad_a = 0; bad_b = 0;
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
      $display("ok    frame buffer: map and tile list give the playfield (232 lines, 20 tiles 1:1 in columns 6..25)");
    expect8("header: distinct tiles", slot.mem[base], 8'h02);
    expect8("header: high byte and word 1",  slot.mem[base + 1] | slot.mem[base + 2] | slot.mem[base + 3], 8'h00);
    sreg_rd(4'd13, v); expect8("dropped frames", v, 8'h00);
    sreg_rd(4'd14, v); expect8("tile count register", v, 8'h02);

    // colour tables, line 40: 4 bytes k, k, BGR555 low, high.  COLUBK = 0 -> $0000,
    // COLUPF = $0E -> TIA colour 7 -> $77BD (white of Color-1, the palette after reset)
    idx = base + 20'h4000 + 40 * 4;
    expect8("COLUBK table, line 40: index",  slot.mem[idx],     8'h00);
    expect8("COLUBK table, line 40: colour", slot.mem[idx + 2] | slot.mem[idx + 3], 8'h00);
    idx = base + 20'h4400 + 40 * 4;
    expect8("COLUPF table, line 40: index",  slot.mem[idx] & slot.mem[idx + 1], 8'h01);
    expect8("COLUPF table, line 40: low",    slot.mem[idx + 2], 8'hBD);
    expect8("COLUPF table, line 40: high",   slot.mem[idx + 3], 8'h77);
    idx = base + 20'h5000 + 40 * 2;
    expect8("window table, line 40: left",   slot.mem[idx],     8'd48);
    expect8("window table, line 40: right",  slot.mem[idx + 1], 8'd207);
    idx = base + 20'h4400 + 232 * 4;
    expect8("COLUPF table, entry 232: black", slot.mem[idx + 2] | slot.mem[idx + 3], 8'h00);
    expect8("COLUPF table, entry 232: index", slot.mem[idx], 8'h01);
    idx = base + 20'h5000 + 232 * 2;
    expect8("window table, entry 232: left",  slot.mem[idx],     8'd0);
    expect8("window table, entry 232: right", slot.mem[idx + 1], 8'd255);

    if (errs == 0) $display("PASS  a26 system");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end

  initial begin
    #400000000;
    $display("FAIL  global timeout");
    $finish;
  end
endmodule
