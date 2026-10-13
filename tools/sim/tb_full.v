// tb_full.v -- the whole a26_top (registers, core, writer, tile dictionary, a26_mem) against
// slot_model at the REAL clock ratio (96 MHz, one colour clock every ~26.8 clk), with a slow
// PSRAM slot.  Simulation only (Verilator).  Step 21b.
//   +rom=<hex> +mapper=<n> +out=<prefix> +f0=<published frame to dump and stop at>
//   SLOT_LAT (parameter, -GSLOT_LAT=90): slot latency in clk (+0..7); 10 = normal
// Prints the deepest FIFO fill, fifo overflow, dropped frames, the largest tile count and the
// longest time the dictionary took for one tile row; dumps the newest buffer as <out>_<f0>.fb.
`timescale 1ns / 1ps
module tb_full;
  parameter SLOT_LAT = 10;
  reg clk = 0, reset = 1;
  always #5 clk = ~clk;

  reg  [3:0] reg_addr = 0;
  reg  [7:0] reg_data_in = 0;
  reg        reg_oe_falling = 0, reg_we_rising = 0;
  wire [7:0] reg_data_out;
  wire        BUS_RDY, BUS_RRQ, BUS_WRQ, ROM_WORD_ENABLE, loop_enable;
  wire [23:0] ROM_ADDR;
  wire [15:0] ROM_DATA_OUT, ROM_DATA_IN;
  wire [1:0]  busy;
  wire [4:0]  aud_mix;
  wire signed [15:0] aud_sample;

  a26_top top (.clkin(clk), .reset(reset), .enable(1'b1), .reg_addr(reg_addr), .reg_data_in(reg_data_in),
    .reg_data_out(reg_data_out), .reg_oe_falling(reg_oe_falling), .reg_we_rising(reg_we_rising),
    .loop_enable(loop_enable), .busy(busy),
    .BUS_RDY(BUS_RDY), .BUS_RRQ(BUS_RRQ), .BUS_WRQ(BUS_WRQ), .ROM_ADDR(ROM_ADDR), .ROM_DATA_OUT(ROM_DATA_OUT),
    .ROM_DATA_IN(ROM_DATA_IN), .ROM_WORD_ENABLE(ROM_WORD_ENABLE), .aud_mix(aud_mix), .aud_sample(aud_sample));

  slot_model #(.LAT(SLOT_LAT)) slot (.clk(clk), .RRQ(BUS_RRQ), .WRQ(BUS_WRQ), .ADDR(ROM_ADDR),
    .DOUT(ROM_DATA_OUT), .WORD(ROM_WORD_ENABLE), .RDY(BUS_RDY), .DIN(ROM_DATA_IN));

  reg [7:0] rom [0:32767];
  reg [1023:0] romfile, outp, fn;
  integer mapper_i, f0, i, fd, base;
  integer fifo_max = 0, n_max = 0, row_t = 0, row_max = 0, words = 0, frame = 0;
  reg [7:0] frames_d = 0;
  always @(posedge clk) begin
    if (top.memc.cnt > fifo_max) fifo_max = top.memc.cnt;
    if (BUS_WRQ) words = words + 1;
    if (top.dict.inrow) row_t = row_t + 1;
    else begin if (row_t > row_max) row_max = row_t; row_t = 0; end
    if (top.tile_n > n_max) n_max = top.tile_n;
    frames_d <= top.fb_frames;
    if (top.fb_frames != frames_d) begin
      frame = frame + 1;
      if (frame == f0) begin
        repeat (4000) @(posedge clk);
        $sformat(fn, "%0s_%0d.fb", outp, frame);
        fd = $fopen(fn, "w");
        $fwrite(fd, "nlines %0d front %0d dropped %0d\n", top.fb_nlines, top.fb_newest, top.fb_dropped);
        base = 20'h80000 + top.fb_newest * 32768;
        for (i = 0; i < 16384; i = i + 1) $fwrite(fd, "%02x%02x\n", slot.mem[base + 2 * i + 1], slot.mem[base + 2 * i]);
        $fclose(fd);
        $display("slot latency %0d clk (+0..7): %0d frames, FIFO filled to %0d of 16, overflow %0d, frames dropped %0d, most tiles %0d, longest tile row %0d clk (a row lasts 48900), %0d words written",
                 SLOT_LAT, frame, fifo_max, top.fifo_ovf, top.fb_dropped, n_max, row_max, words);
        $finish;
      end
    end
  end

  initial begin
    if (!$value$plusargs("rom=%s", romfile)) begin $display("no +rom"); $finish; end
    if (!$value$plusargs("out=%s", outp)) outp = "full";
    if (!$value$plusargs("mapper=%d", mapper_i)) mapper_i = 1;
    if (!$value$plusargs("f0=%d", f0)) f0 = 100;
    $readmemh(romfile, rom);
    for (i = 0; i < 32768; i = i + 1) slot.mem[i] = rom[i];       // ROM_BASE $300000 -> index 0
    repeat (8) @(negedge clk);
    reset = 0;
    repeat (8) @(negedge clk);
    reg_addr = 4'd3; reg_data_in = {4'b0000, mapper_i[2:0], 1'b1};   // run, mapper
    @(negedge clk); reg_we_rising = 1;
    @(negedge clk); reg_we_rising = 0;
  end
endmodule
