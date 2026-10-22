// tb_trace.v -- like tb_frames.v, plus a per-pixel trace of the frame that is dumped and a
// histogram of the colour-register writes.  Simulation only (Verilator); nothing here is
// part of the core.
//   +rom= +mapper= +out= +f0= +f1= +f2= +rst0= +rst1=      as in tb_frames.v
//   +joy0=<frame> +joy1=<frame> +joyv=<SWCHA value>          joystick held while joy0 <= frame < joy1
//   +h0=<frame>                                              histogram counts writes from this frame on
// Per dumped frame: <out>_<frame>.tr, one text line per captured line:
//   "<y> " then 160 x 16 hex digits: src, vis, drawn colour, COLUBK, COLUPF, COLUP0, COLUP1, NUSIZ0, NUSIZ1
//   (the four registers as they were when that pixel was generated)
// At the end: <out>.hist, lines "<reg 0..3> <colour clock 0..227> <writes on visible lines>"
`timescale 1ns / 1ps
module tb_trace;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;

  reg [7:0] rom [0:32767];
  reg [1023:0] romfile, outp;
  integer mapper_i, f0, f1, f2, rst0, rst1, joy0, joy1, joyv, h0, fire_i;   // +fire=<frame>: fire button held from that frame
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

  wire [7:0] swchb = (frame >= rst0 && frame < rst1) ? 8'h3E : 8'h3F;
  wire [7:0] swcha = (frame >= joy0 && frame < joy1) ? joyv[7:0] : 8'hFF;

  wire        pix_stb, pix_vis, vsync, vblank, cpu_rdy, cpu_sync, rom_miss, rom_miss_ev;
  wire [7:0]  pix_x, hcount;
  wire [1:0]  pix_src;
  wire [6:0]  pix_col, colubk, colupf, colup0, colup1;
  wire [4:0]  aud_mix;
  wire [15:0] cpu_ab;

  a26_core #(.CC_INC(25'd8388608)) core (
    .clk(clk), .rst(rst), .mapper(mapper_i[2:0]),
    .swcha_in(swcha), .swchb_in(swchb), .fire0(~(fire_i >= 0 && frame >= fire_i)), .fire1(1'b1), .inpt(4'h0), .pause(pause),
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
  // the tile words as the writer makes them (the step-20 layout), kept for reference
  reg [15:0] dir [0:65535];
  always @(posedge clk) if (fb_wr && !fb_waddr[13]) dir[fb_waddr] <= fb_wdata;

  reg [15:0] fb [0:65535];
  always @(posedge clk) if (m_wr) fb[m_waddr] <= m_wdata;

  // the four colour registers as they were when the current pixel was generated
  reg [27:0] sh;
  always @(posedge clk) if (core.cc_ce) sh <= {colubk, colupf, colup0, colup1};
  // NUSIZ0[2:0], NUSIZ1[2:0] (player size / copies) when the pixel was generated
  reg [5:0] nsz;
  always @(posedge clk) if (core.cc_ce) nsz <= {core.u_tia.nusiz0[2:0], core.u_tia.nusiz1[2:0]};

  // per-pixel trace of the frame being captured
  reg [63:0] tr [0:35839];
  always @(posedge clk)
    if (pix_stb && ((pix_x == 8'd0) ? vid.cap_new : vid.cap) && vid.y < 8'd232)
      tr[{24'd0, vid.y} * 160 + {24'd0, pix_x}] <= {2'b00, pix_src, 3'b000, pix_vis, 1'b0, pix_col, 1'b0, sh[27:21], 1'b0, sh[20:14], 1'b0, sh[13:7], 1'b0, sh[6:0], 5'd0, nsz[5:3], 5'd0, nsz[2:0]};

  // colour-register writes: the write takes effect on colour clock hcount + 1
  integer hist [0:911];
  integer k;
  initial for (k = 0; k < 912; k = k + 1) hist[k] = 0;
  wire [7:0] wclk = (hcount == 8'd227) ? 8'd0 : hcount + 8'd1;
  always @(posedge clk)
    if (core.tia_wr && frame >= h0 && !vblank && !vsync
        && cpu_ab[5:0] >= 6'h06 && cpu_ab[5:0] <= 6'h09)
      // TIA order is COLUP0 COLUP1 COLUPF COLUBK; store as 0=BK 1=PF 2=P0 3=P1
      hist[(cpu_ab[5:0] == 6'h09 ? 0 : cpu_ab[5:0] == 6'h08 ? 1 : cpu_ab[5:0] == 6'h06 ? 2 : 3) * 228 + {24'd0, wclk}]
        = hist[(cpu_ab[5:0] == 6'h09 ? 0 : cpu_ab[5:0] == 6'h08 ? 1 : cpu_ab[5:0] == 6'h06 ? 2 : 3) * 228 + {24'd0, wclk}] + 1;

  integer fd, i, j, base;
  reg [7:0] frames_d = 0;
  reg [1023:0] fn;
  always @(posedge clk) begin
    frames_d <= fb_frames;
    if (fb_frames != frames_d) begin
      frame = frame + 1;
      if (frame == f0 || frame == f1 || frame == f2) begin
        $sformat(fn, "%0s_%0d.fb", outp, frame);
        fd = $fopen(fn, "w");
        $fwrite(fd, "nlines %0d front %0d\n", fb_nlines, fb_newest);
        base = fb_newest * 16384;
        for (i = 0; i < 16384; i = i + 1) $fwrite(fd, "%04x\n", fb[base + i]);   // tiles + the HDMA tables
        $fclose(fd);
        $sformat(fn, "%0s_%0d.tr", outp, frame);
        fd = $fopen(fn, "w");
        for (i = 0; i < fb_nlines; i = i + 1) begin
          $fwrite(fd, "%0d ", i);
          for (j = 0; j < 160; j = j + 1) $fwrite(fd, "%016x", tr[i * 160 + j]);
          $fwrite(fd, "\n");
        end
        $fclose(fd);
        $display("frame %0d dumped: %0d lines", frame, fb_nlines);
        if (frame >= f0 && frame >= f1 && frame >= f2) begin
          $sformat(fn, "%0s.hist", outp);
          fd = $fopen(fn, "w");
          for (i = 0; i < 912; i = i + 1) if (hist[i] != 0) $fwrite(fd, "%0d %0d %0d\n", i / 228, i % 228, hist[i]);
          $fclose(fd);
          $finish;
        end
      end
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
    if (!$value$plusargs("joy0=%d", joy0)) joy0 = -1;
    if (!$value$plusargs("joy1=%d", joy1)) joy1 = -1;
    if (!$value$plusargs("joyv=%d", joyv)) joyv = 255;
    if (!$value$plusargs("h0=%d", h0)) h0 = 0;
    if (!$value$plusargs("fire=%d", fire_i)) fire_i = -1;
    if (!$value$plusargs("yofs=%d", yofs_i)) yofs_i = 0;
    if (!$value$plusargs("pz_on=%d", pz_on)) pz_on = 0;
    if (!$value$plusargs("pz_per=%d", pz_per)) pz_per = 0;
    $readmemh(romfile, rom);
    repeat (8) @(posedge clk);
    rst = 0;
  end
endmodule
