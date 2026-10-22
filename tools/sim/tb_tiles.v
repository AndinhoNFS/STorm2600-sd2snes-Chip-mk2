// tb_tiles.v -- (generated from tb_frames.v by step 21a) dumps the TILE words of every
// +step-th published frame from +fa to +fb into <out>.tiles: one line per frame,
// "<frame> <nlines> " + 7168 direct tile words + " " + the first 5120 words of the buffer
// (header, map, tile list) + " <dropped frames>", the source of every captured pixel, the window
// table and (step 23) final colour per pixel, the writer's 4 colours per line, the colour tables.  +joy0/+joyv/+fire as in tb_trace.v.
// tb_frames.v -- runs a26_core + a26_vidwr on a cartridge image and dumps the
// published frame buffer at chosen frame numbers.  Simulation only (Verilator).
// The ROM answers at once and the colour clock is one in 4 clk, so a frame is
// ~240k clk instead of 1.6M: the core's own timing (colour clocks, CPU cycles)
// is unchanged, only the 96 MHz system clock around it is shortened.
//   +rom=<hex file, 32768 lines>  +mapper=<n>  +out=<prefix>
//   +f0=<frame> +f1=<frame> +f2=<frame>   frames to dump (count of published frames)
//   +rst0=<frame> +rst1=<frame>           RESET switch held while rst0 <= frame < rst1
`timescale 1ns / 1ps
module tb_tiles;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;

  reg [7:0] rom [0:32767];
  reg [1023:0] romfile, outp;
  integer mapper_i, f0, f1, f2, rst0, rst1;
  integer frame = 0;
  integer fa, fz, fstep, joy0, joyv, fire_i, tfd;
  // +yofs=<n> signed vertical offset of the window (-16..47);  +pz_on=<clk> +pz_per=<clk>: pause held for pz_on out of every pz_per clk
  integer yofs_i, pz_on, pz_per, pz_cnt = 0;
  reg pause = 0;
  always @(posedge clk) begin
    pz_cnt <= (pz_per > 0 && pz_cnt + 1 >= pz_per) ? 0 : pz_cnt + 1;
    pause  <= (pz_per > 0) && (pz_cnt < pz_on);
  end

  wire [14:0] rom_addr;
  wire        rom_rd;
  reg  [7:0]  rom_data;
  reg         rom_ack = 0;
  always @(posedge clk) begin
    rom_ack  <= rom_rd;
    rom_data <= rom[rom_addr];
  end

  wire [7:0] swchb = (frame >= rst0 && frame < rst1) ? 8'h3E : 8'h3F;   // bit0 = RESET, active low

  wire        pix_stb, pix_vis, vsync, vblank, cpu_rdy, cpu_sync, rom_miss, rom_miss_ev;
  wire [7:0]  pix_x, hcount;
  wire [1:0]  pix_src;
  wire [6:0]  pix_col, colubk, colupf, colup0, colup1;
  wire [4:0]  aud_mix;
  wire [15:0] cpu_ab;

  a26_core #(.CC_INC(25'd8388608)) core (
    .clk(clk), .rst(rst), .mapper(mapper_i[2:0]),
    .swcha_in((joy0 >= 0 && frame >= joy0) ? joyv[7:0] : 8'hFF), .swchb_in(swchb), .fire0(~(fire_i >= 0 && frame >= fire_i)), .fire1(1'b1), .inpt(4'h0), .pause(pause),
    .rom_addr(rom_addr), .rom_rd(rom_rd), .rom_data(rom_data), .rom_ack(rom_ack),
    .pix_stb(pix_stb), .pix_x(pix_x), .pix_vis(pix_vis), .pix_src(pix_src), .pix_col(pix_col),
    .hcount(hcount), .vsync(vsync), .vblank(vblank),
    .colubk(colubk), .colupf(colupf), .colup0(colup0), .colup1(colup1),
    .aud_mix(aud_mix), .cpu_rdy(cpu_rdy), .cpu_ab(cpu_ab), .cpu_sync(cpu_sync),
    .rom_miss(rom_miss), .diag_clr(1'b0), .rom_miss_ev(rom_miss_ev));

  wire        fb_wr;
  wire [1:0]  fb_newest;
  wire [15:0] fb_waddr;
  wire [15:0] fb_wdata;
  wire [7:0]  fb_frames, fb_nlines;
  a26_vidwr vid (.clk(clk), .rst(rst),
    .pix_stb(pix_stb), .pix_x(pix_x), .pix_vis(pix_vis), .pix_src(pix_src),
`ifndef OLD_VIDWR
    .pix_col(pix_col),                 // step 23; -DOLD_VIDWR builds against a writer without it (bak_v11)
`endif
    .vsync(vsync), .vblank(vblank),
    .colubk(colubk), .colupf(colupf), .colup0(colup0), .colup1(colup1),
    .fb_wr(fb_wr), .fb_waddr(fb_waddr), .fb_wdata(fb_wdata),
    .fb_newest(fb_newest), .fb_frames(fb_frames), .fb_nlines(fb_nlines),
    .lock_v(1'b0), .lock_i(2'd0), .yofs(yofs_i[6:0]),
    .ev_row(ev_row), .ev_end(ev_end), .end_lines(end_lines),
    .eng_ack(eng_ack), .eng_ovf(eng_ovf), .fb_dropped(fb_dropped));

  // tile dictionary; the PSRAM side takes every word at once
  wire        ev_row, ev_end, eng_ack, eng_ovf, m_wr;
  wire [7:0]  end_lines, fb_dropped;
  wire [9:0]  tile_n;
  wire [15:0] m_waddr, m_wdata;
  a26_tdict dict (.clk(clk), .rst(rst),
    .v_wr(fb_wr), .v_waddr(fb_waddr), .v_wdata(fb_wdata),
    .ev_row(ev_row), .ev_end(ev_end), .end_lines(end_lines),
    .eng_ack(eng_ack), .eng_ovf(eng_ovf), .tile_n(tile_n),
    .m_wr(m_wr), .m_waddr(m_waddr), .m_wdata(m_wdata), .fifo_low(1'b1), .wr_idle(1'b1));
  // reference picture, taken from the pixel stream itself (step 22): the colour source of
  // every pixel of every captured line, filed under the writer's buffer and line number
  reg [1:0] lin [0:159];
  reg [1:0] refp [0:262143];                       // { buffer, line, x }
  reg [7:0] linc [0:159];
  reg [7:0] refc [0:262143];                       // step 23: final colour (bit 7 = blanked)
  reg [27:0] refl [0:1023];                        // the four colours the writer holds for the line
  integer rx;
  always @(posedge clk) if (pix_stb) begin
    lin[pix_x] = pix_src;
    linc[pix_x] = {~pix_vis, pix_col};
    if (pix_x == 8'd159 && vid.cap)
    begin
      for (rx = 0; rx < 160; rx = rx + 1) begin refp[{vid.wb, vid.y, rx[7:0]}] = lin[rx]; refc[{vid.wb, vid.y, rx[7:0]}] = linc[rx]; end
      refl[{vid.wb, vid.y}] = vid.cl;
    end
  end
  // the tile words as the writer makes them, kept for reference
  reg [15:0] dir [0:65535];
  always @(posedge clk) if (fb_wr && !fb_waddr[13]) dir[fb_waddr] <= fb_wdata;

  reg [15:0] fb [0:65535];
  always @(posedge clk) if (m_wr) fb[m_waddr] <= m_wdata;

  // HBLANK-side facts the frame buffer cannot show: per frame, how many visible lines had
  // their first 8 pixels blanked (the HMOVE bar), and the scan line count
  integer bar_lines = 0, scan_lines = 0, first_vis_line = -1, cc_frame = 0;
  // scan lines and colour clocks are counted from one VSYNC start to the next (line starts
  // with VSYNC newly high), so they are the game's own frame length
  reg bar_seen;
  reg vs_p = 0;
  integer cc_run = 0, ln_run = 0, ln_frame = 0;
  reg clr_req = 0, clr_ack = 0;
  always @(posedge clk) begin
    if (core.cc_ce) cc_run <= cc_run + 1;
    if (pix_stb && pix_x == 8'd0) begin
      vs_p <= vsync;
      if (vsync && !vs_p) begin cc_frame <= cc_run + (core.cc_ce ? 1 : 0); cc_run <= 0; ln_frame <= ln_run + 1; ln_run <= 0; end
      else ln_run <= ln_run + 1;
    end
    if (clr_req != clr_ack) begin
      clr_ack <= clr_req; bar_lines <= 0; scan_lines <= 0; first_vis_line <= -1;
    end else if (pix_stb) begin
      if (pix_x == 8'd0) begin
        bar_seen <= ~pix_vis & ~vblank & ~vsync;
        scan_lines <= scan_lines + 1;
        if (first_vis_line < 0 && !vblank && !vsync && vid.armed && !vid.f_start) first_vis_line <= vid.vl + 1;   // line number after VSYNC
      end
      if (pix_x == 8'd7 && bar_seen && !pix_vis) bar_lines <= bar_lines + 1;
    end
  end

  // +vsdbg=<frame>: print where VSYNC and VBLANK change (line since the last VSYNC fall, hcount) from that frame on
  integer vsdbg, dbg_ln = 0;
  reg dv = 0, db = 0;
  always @(posedge clk) begin
    dv <= vsync; db <= vblank;
    if (core.cc_ce && hcount == 8'd227) dbg_ln <= dbg_ln + 1;
    if (vsdbg >= 0 && frame >= vsdbg && frame < vsdbg + 2) begin
      if (vsync != dv)  $display("  frame %0d line %0d hcount %0d: VSYNC -> %0d (vl %0d)", frame, dbg_ln, hcount, vsync, vid.vl);
      if (vblank != db) $display("  frame %0d line %0d hcount %0d: VBLANK -> %0d (vl %0d)", frame, dbg_ln, hcount, vblank, vid.vl);
    end
    if (dv && !vsync) dbg_ln <= 0;
  end

  integer fd, i, base;
  reg [7:0] frames_d = 0;
  reg [1023:0] fn;
  always @(posedge clk) begin
    frames_d <= fb_frames;
    if (fb_frames != frames_d) begin
      frame = frame + 1;
      if (frame >= fa && frame <= fz && ((frame - fa) % fstep) == 0) begin
        $fwrite(tfd, "%0d %0d ", frame, fb_nlines);
        base = fb_newest * 16384;
        for (i = 0; i < 7168; i = i + 1) $fwrite(tfd, "%04x", dir[base + i]);     // direct tiles (step 20)
        $fwrite(tfd, " ");
        for (i = 0; i < 5120; i = i + 1) $fwrite(tfd, "%04x", fb[base + i]);      // header, map, 512 tiles
        $fwrite(tfd, " %0d ", fb_dropped);
        for (i = 0; i < 232 * 256; i = i + 1) if ((i & 255) < 160) $fwrite(tfd, "%0d", refp[{fb_newest, i[15:0]}]);
        $fwrite(tfd, " ");
        for (i = 0; i < 233; i = i + 1) $fwrite(tfd, "%04x", fb[base + 16'h2800 + i]);   // window table
        $fwrite(tfd, " ");
        for (i = 0; i < 232 * 256; i = i + 1) if ((i & 255) < 160) $fwrite(tfd, "%02x", refc[{fb_newest, i[15:0]}]);
        $fwrite(tfd, " ");
        for (i = 0; i < 232; i = i + 1) $fwrite(tfd, "%07x", refl[{fb_newest, i[7:0]}]);
        $fwrite(tfd, " ");
        for (i = 0; i < 2048; i = i + 1) $fwrite(tfd, "%04x", fb[base + 16'h2000 + i]);   // colour tables
        $fwrite(tfd, "\n");
      end
      if (frame >= fz) begin $fclose(tfd); $finish; end
      clr_req <= ~clr_req;
    end
  end

  initial begin
    if (!$value$plusargs("rom=%s", romfile)) begin $display("no +rom"); $finish; end
    if (!$value$plusargs("out=%s", outp)) outp = "frame";
    if (!$value$plusargs("mapper=%d", mapper_i)) mapper_i = 1;
    if (!$value$plusargs("f0=%d", f0)) f0 = 2;
    if (!$value$plusargs("f1=%d", f1)) f1 = f0;
    if (!$value$plusargs("f2=%d", f2)) f2 = f1;
    if (!$value$plusargs("rst0=%d", rst0)) rst0 = -1;
    if (!$value$plusargs("rst1=%d", rst1)) rst1 = -1;
    if (!$value$plusargs("yofs=%d", yofs_i)) yofs_i = 0;
    if (!$value$plusargs("pz_on=%d", pz_on)) pz_on = 0;
    if (!$value$plusargs("vsdbg=%d", vsdbg)) vsdbg = -1;
    if (!$value$plusargs("fa=%d", fa)) fa = 2;
    if (!$value$plusargs("fb=%d", fz)) fz = fa;
    if (!$value$plusargs("step=%d", fstep)) fstep = 1;
    if (!$value$plusargs("joy0=%d", joy0)) joy0 = -1;
    if (!$value$plusargs("joyv=%d", joyv)) joyv = 255;
    if (!$value$plusargs("fire=%d", fire_i)) fire_i = -1;
    $sformat(fn, "%0s.tiles", outp);
    tfd = $fopen(fn, "w");
    if (!$value$plusargs("pz_per=%d", pz_per)) pz_per = 0;
    $readmemh(romfile, rom);
    repeat (8) @(posedge clk);
    rst = 0;
  end
endmodule
