// tb_frames.v -- runs a26_core + a26_vidwr on a cartridge image and dumps the
// published frame buffer at chosen frame numbers.  Simulation only (Verilator).
// The ROM answers at once and the colour clock is one in 4 clk, so a frame is
// ~240k clk instead of 1.6M: the core's own timing (colour clocks, CPU cycles)
// is unchanged, only the 96 MHz system clock around it is shortened.
//   +rom=<hex file, 32768 lines>  +mapper=<n>  +out=<prefix>
//   +f0=<frame> +f1=<frame> +f2=<frame>   frames to dump (count of published frames)
//   +rst0=<frame> +rst1=<frame>           RESET switch held while rst0 <= frame < rst1
`timescale 1ns / 1ps
module tb_frames;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;

  reg [7:0] rom [0:32767];
  reg [1023:0] romfile, outp;
  integer mapper_i, f0, f1, f2, rst0, rst1;
  integer frame = 0;
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
    .swcha_in(8'hFF), .swchb_in(swchb), .fire0(1'b1), .fire1(1'b1), .inpt(4'h0), .pause(pause),
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
  a26_vidwr #(.DLY(2)) vid (   // DLY = 2: these benches run one colour clock in 4 clk, and the writer needs DLY < pixel spacing (13 is for the real 96 MHz shell)
    .clk(clk), .rst(rst),
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
  // the tile words as the writer makes them (the step-20 layout), kept for reference
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
      if (frame == f0 || frame == f1 || frame == f2) begin
        $sformat(fn, "%0s_%0d.fb", outp, frame);
        fd = $fopen(fn, "w");
        $fwrite(fd, "nlines %0d front %0d scan_lines %0d bar_lines %0d first_vis_line %0d rom_miss %0d cc_frame %0d dropped %0d\n",
                fb_nlines, fb_newest, ln_frame, bar_lines, first_vis_line, rom_miss, cc_frame, fb_dropped);
        base = fb_newest * 16384;
        for (i = 0; i < 16384; i = i + 1) $fwrite(fd, "%04x\n", fb[base + i]);   // tiles + the HDMA tables
        $fclose(fd);
        $display("frame %0d dumped: %0d lines, %0d scan lines, %0d bar lines", frame, fb_nlines, ln_frame, bar_lines);
        if (frame >= f0 && frame >= f1 && frame >= f2) $finish;
      end
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
    if (!$value$plusargs("pz_per=%d", pz_per)) pz_per = 0;
    $readmemh(romfile, rom);
    repeat (8) @(posedge clk);
    rst = 0;
  end
endmodule
