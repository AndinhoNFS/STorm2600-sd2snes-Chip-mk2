// SPDX-License-Identifier: GPL-2.0-or-later
// tb_a26_mem.v -- self-checking test for a26_mem.v against slot_model.v
//
// Checks: byte lanes of ROM reads (even and odd addresses), little-endian
// word writes into the three buffers, the FIFO (16 queued writes are fine, a
// longer burst overflows),
// and the worst-case ROM read latency when video writes are in flight.
//
// run:  iverilog -g2005 -Wall -o tb_mem tb_a26_mem.v a26_mem.v slot_model.v && vvp tb_mem
`timescale 1ns / 1ps

module tb_a26_mem;
  reg         clk = 0, rst = 1;
  reg  [14:0] rom_addr = 0;
  reg         rom_rd = 0;
  wire [7:0]  rom_data;
  wire        rom_ack;
  reg         fb_wr = 0;
  reg  [15:0] fb_waddr = 0;
  reg  [15:0] fb_wdata = 0;
  wire        BUS_RDY, BUS_RRQ, BUS_WRQ, ROM_WORD_ENABLE, fifo_ovf, loaded;
  wire [23:0] ROM_ADDR;
  wire [15:0] ROM_DATA_OUT, ROM_DATA_IN;
  wire [7:0]  lat_max;

  a26_mem dut (.clk(clk), .rst(rst),
               .core_addr(rom_addr), .rom_rd(rom_rd), .rom_data(rom_data), .rom_ack(rom_ack),
               .fb_wr(fb_wr), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata),
               .BUS_RDY(BUS_RDY), .BUS_RRQ(BUS_RRQ), .BUS_WRQ(BUS_WRQ),
               .ROM_ADDR(ROM_ADDR), .ROM_DATA_OUT(ROM_DATA_OUT),
               .ROM_WORD_ENABLE(ROM_WORD_ENABLE), .ROM_DATA_IN(ROM_DATA_IN),
               .fifo_ovf(fifo_ovf), .loaded(loaded), .diag_clr(1'b0), .rd_lat_max(lat_max));

  slot_model #(.LAT(10)) slot (.clk(clk), .RRQ(BUS_RRQ), .WRQ(BUS_WRQ), .ADDR(ROM_ADDR),
                               .DOUT(ROM_DATA_OUT), .WORD(ROM_WORD_ENABLE),
                               .RDY(BUS_RDY), .DIN(ROM_DATA_IN));

  always #5 clk = ~clk;

  integer errs = 0;
  integer maxlat = 0, minlat = 1000;
  integer i, x, n, bad, t0;

  // wait for the loader; fails after `lim` clocks
  task wait_loaded; input integer lim;
    integer t;
    begin
      t = 0;
      while (loaded !== 1'b1 && t < lim) begin @(negedge clk); t = t + 1; end
      if (loaded !== 1'b1) begin errs = errs + 1; $display("FAIL  loader did not finish in %0d clk", lim); end
      else $display("ok    ROM loaded after %0d clk (%0d clk per byte)", t, t / 16384);
    end
  endtask

  function [7:0] rv; input integer a;
    begin rv = (a * 5 + (a >> 8) * 3 + 1) & 255; end
  endfunction

  // expected content of the frame-buffer window (index = byte offset)
  reg [7:0] shadow [0:131071];
  reg       wrote  [0:131071];

  task rd_chk; input [14:0] a;
    integer t;
    begin
      @(negedge clk); rom_addr = a; rom_rd = 1;
      @(negedge clk); rom_rd = 0;
      t = 0;
      while (!rom_ack && t < 300) begin @(negedge clk); t = t + 1; end
      if (t >= 300) begin
        errs = errs + 1; $display("FAIL  read %04h: no ack", a);
      end else begin
        // only 16 KB are held: bit 14 of the address is ignored
        if (rom_data !== rv({18'd0, a[13:0]})) begin
          errs = errs + 1;
          $display("FAIL  read %04h: got %02h, expected %02h", a, rom_data, rv({18'd0, a[13:0]}));
        end
        if (t > maxlat) maxlat = t;
        if (t < minlat) minlat = t;
      end
    end
  endtask

  task fb_push; input [15:0] wa; input [15:0] wd;
    begin
      @(negedge clk); fb_waddr = wa; fb_wdata = wd; fb_wr = 1;
      @(negedge clk); fb_wr = 0;
      shadow[{wa, 1'b0}] = wd[7:0];
      shadow[{wa, 1'b1}] = wd[15:8];
      wrote[{wa, 1'b0}] = 1'b1; wrote[{wa, 1'b1}] = 1'b1;
    end
  endtask

  task check_fb; input [8*20-1:0] nm;
    integer j, b;
    begin
      b = 0;
      for (j = 0; j < 98304; j = j + 1)
        if (wrote[j] === 1'b1 && slot.mem[20'h80000 + j] !== shadow[j]) b = b + 1;
      if (b != 0) begin errs = errs + 1; $display("FAIL  %0s: %0d wrong bytes", nm, b); end
      else $display("ok    %0s", nm);
    end
  endtask

  initial begin
    for (i = 0; i < 32768; i = i + 1) slot.mem[i] = rv(i);   // ROM_BASE = $300000 -> index 0
    for (i = 0; i < 131072; i = i + 1) begin wrote[i] = 1'b0; shadow[i] = 8'h00; end
    // ---- nothing is loaded before the first reset ----------------------------
    rst = 0;
    repeat (200) @(negedge clk);
    if (loaded !== 1'b0 || BUS_RRQ !== 1'b0 || dut.state !== 3'd0) begin
      errs = errs + 1; $display("FAIL  loader active before the first reset");
    end else $display("ok    idle before the first reset");
    rst = 1; repeat (4) @(negedge clk); rst = 0;
    repeat (4) @(negedge clk);
    if (loaded !== 1'b0) begin errs = errs + 1; $display("FAIL  loaded right after reset"); end

    // ---- the loader copies 16 KB from ROM_BASE into the block RAM ------------
    wait_loaded(2000000);
    bad = 0;
    for (i = 0; i < 16384; i = i + 1) if (dut.cart[i] !== rv(i)) bad = bad + 1;
    if (bad != 0) begin errs = errs + 1; $display("FAIL  block RAM: %0d wrong bytes", bad); end
    else $display("ok    block RAM = the 16384 bytes at ROM_BASE");
    if (lat_max == 8'd0 || lat_max > 8'd60) begin errs = errs + 1; $display("FAIL  loader latency = %0d clk", lat_max); end
    else $display("ok    rd_lat_max (loader, slot latency) = %0d clk", lat_max);

    // ---- the core's reads come from the block RAM (even, odd, alias) ---------
    rd_chk(15'h0000); rd_chk(15'h0001); rd_chk(15'h0002); rd_chk(15'h0003);
    rd_chk(15'h1234); rd_chk(15'h1235); rd_chk(15'h3FFF);
    rd_chk(15'h4000); rd_chk(15'h7FFE); rd_chk(15'h7FFF);
    $display("ok    ROM reads (even, odd and aliased addresses) done");

    // ---- sixteen quick writes fit the FIFO; all three buffers ---------------
    fb_push(16'd0,     16'hA55A);
    fb_push(16'd1,     16'h1234);
    fb_push(16'd100,   16'hFEDC);
    fb_push(16'h3FFF,  16'h0F0F);            // last word of buffer 0
    fb_push(16'h4000,  16'h1111);            // buffer 1 = PSRAM $388000
    fb_push(16'h6800,  16'h2222);
    fb_push(16'h8000,  16'h3333);            // buffer 2 = PSRAM $390000
    fb_push(16'hBFFF,  16'h4444);            // last word of buffer 2
    for (i = 0; i < 8; i = i + 1) fb_push(16'h2000 + i, 16'h5000 + i);
    repeat (600) @(negedge clk);
    check_fb("16 quick writes");
    if (fifo_ovf !== 1'b0) begin errs = errs + 1; $display("FAIL  overflow with 16 writes"); end
    if (slot.mem[20'h88000] !== 8'h11 || slot.mem[20'h90000] !== 8'h33 || slot.mem[20'h97FFF] !== 8'h44) begin
      errs = errs + 1; $display("FAIL  buffers 1 and 2 are not at $388000 / $390000");
    end else $display("ok    buffers 1 and 2 at PSRAM $388000 and $390000");

    // ---- a long burst overflows (and is reported) ----------------------
    for (i = 0; i < 40; i = i + 1) fb_push(16'd200 + i, 16'h1000 + i);
    repeat (1200) @(negedge clk);
    if (fifo_ovf !== 1'b1) begin errs = errs + 1; $display("FAIL  burst did not set overflow"); end
    else $display("ok    burst overflow flagged");

    // ---- realistic traffic: writes every ~26 clk, reads in between -----
    // (the reset starts a new load: a different image must replace the old one)
    for (i = 0; i < 16384; i = i + 1) slot.mem[i] = rv(i) ^ 8'h5A;
    rst = 1; repeat (3) @(negedge clk); rst = 0; repeat (3) @(negedge clk);
    if (loaded !== 1'b0) begin errs = errs + 1; $display("FAIL  loaded not cleared by reset"); end
    wait_loaded(2000000);
    bad = 0;
    for (i = 0; i < 16384; i = i + 1) if (dut.cart[i] !== (rv(i) ^ 8'h5A)) bad = bad + 1;
    if (bad != 0) begin errs = errs + 1; $display("FAIL  reload: %0d wrong bytes", bad); end
    else $display("ok    reload after reset picked up the new image");
    for (i = 0; i < 16384; i = i + 1) slot.mem[i] = rv(i);
    rst = 1; repeat (3) @(negedge clk); rst = 0; repeat (3) @(negedge clk);
    wait_loaded(2000000);
    for (i = 0; i < 131072; i = i + 1) begin wrote[i] = 1'b0; end
    x = 12345; maxlat = 0; minlat = 1000;
    for (n = 0; n < 300; n = n + 1) begin
      fb_push(16'd1000 + n, 16'h8000 + n * 7);
      repeat (20) @(negedge clk);
      x = (x * 1103515245 + 12345) & 32'h7FFFFFFF;
      rd_chk(x[22:8]);
    end
    repeat (200) @(negedge clk);
    check_fb("300 mixed writes");
    if (fifo_ovf !== 1'b0) begin errs = errs + 1; $display("FAIL  overflow in realistic traffic"); end
    // rom_ack must come a fixed ACK_DLY + 1 clk after the request as seen here (the core
    // takes it one clk later), whatever the video writes do: never early (ucf.extra relies
    // on the block RAM output being stable for 12 clk first) and far inside the CPU cycle
    $display("      ROM read latency: %0d..%0d clocks", minlat, maxlat);
    if (minlat != 15 || maxlat != 15) begin errs = errs + 1; $display("FAIL  read latency is not the fixed 15 clocks"); end

    if (errs == 0) $display("PASS  a26_mem");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end

  initial begin
    #100000000;
    $display("FAIL  global timeout");
    $finish;
  end
endmodule
