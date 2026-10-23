// tb_cw.v -- (diagnosis 2, from tb_lines.v) a26_core + a26_vidwr + a26_tdict.  <out>.cw, frames
// +fa..+fb step +step only: "F <n> <published frame> <lines>" and per scan line
//   "L <line since VSYNC> <flags> <buffer line> <cl> <regs> <pixels> <sources> <events>"
// flags as in tb_lines.v plus 64 = a26_vidwr's hmb, 128 = blk;  cl = the 4 colours a26_vidwr
// holds for the line (28 bits, BK PF P0 P1), regs = the 4 registers at pixel 159 (same packing);
// pixels: 2 hex digits (bit 7 = blanked, 6:0 = colour);  sources: 1 digit (pix_src);
// events: ",<reg 0=BK 1=PF 2=P0 3=P1>:<hcount of the write>:<old value>:<new value>" for each write since pixel 159 of the line before
`timescale 1ns / 1ps
module tb_cw;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;

  reg [7:0] rom [0:32767];
  reg [1023:0] romfile, outp;
  integer sc_i = 0, mapper_i, f0, f1, f2, rst0, rst1;
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
    .clk(clk), .rst(rst), .mapper(mapper_i[2:0]), .sc_en(sc_i[0]),
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

  // every scan line of every frame, numbered as a26_vidwr numbers it (vid.vl after pixel 0:
  // line 0 = the line in which VSYNC falls).  A game frame = the lines from one restart of
  // vid.vl to the next.  Kept per frame and written out when the next one starts.
  reg [1279:0] lpix [0:511];          // 160 x 8 bits: bit 7 = blanked (pix_vis low), 6:0 = colour
  reg [15:0]   lvl  [0:511];
  reg [7:0]    lfl  [0:511];          // vblank at pixel 0, 16, 159; vsync at pixel 0, 159; captured
  reg [7:0]    lyb  [0:511];          // buffer line when captured
  reg [8:0]    lvbx [0:511];          // hcount where VBLANK last changed in this line + 1 (0 = no change)
  reg [319:0]  lsrc [0:511];
  reg [27:0]   lcl [0:511], lrg [0:511];
  reg [319:0]  csrc;
  reg [23:0]   ev [0:511][0:15];
  reg [4:0]    evn [0:511];
  reg [23:0]   cev [0:15];
  reg [4:0]    cevn = 0;
  integer ek;
  reg [1279:0] cur;
  reg [7:0]    fl;
  reg [8:0]    vbx;
  reg          vb_d = 0;
  integer nl = 0, seg = 0, li, lj, selpub, fmid = 0;
  always @(posedge clk) begin
    vb_d <= vblank;
    if (vblank != vb_d) vbx = {1'b0, hcount} + 9'd1;
    if (core.tia_wr && cpu_ab[5:0] >= 6'h06 && cpu_ab[5:0] <= 6'h09 && cevn < 16) begin
      cev[cevn[3:0]] = {(cpu_ab[5:0] == 6'h09) ? 2'd0 : (cpu_ab[5:0] == 6'h08) ? 2'd1 : (cpu_ab[5:0] == 6'h06) ? 2'd2 : 2'd3, hcount,
                        (cpu_ab[5:0] == 6'h09) ? colubk : (cpu_ab[5:0] == 6'h08) ? colupf : (cpu_ab[5:0] == 6'h06) ? colup0 : colup1, core.cpu_dout[7:1]};
      cevn = cevn + 1;
    end
    if (pix_stb) begin
      cur[pix_x * 8 +: 8] = {~pix_vis, pix_col};
      csrc[pix_x * 2 +: 2] = pix_src;
      if (pix_x == 8'd0)  begin fl[0] = vblank; fl[3] = vsync; end
      if (pix_x == 8'd16) fl[1] = vblank;
      if (pix_x == 8'd1) begin
        // vid.vl now holds this line's number; a restart = a new frame: flush the old one
        if (vid.vl <= 9'd1 && nl > 2 && lvl[nl - 1] > 16'd1) begin
          selpub = fmid + 1;        // frame count taken in mid frame: the frame just ended is the next one published
          if (selpub >= fa && selpub <= fz && ((selpub - fa) % fstep) == 0) begin
            $fwrite(tfd, "F %0d %0d %0d\n", seg, selpub, nl);
            for (li = 0; li < nl; li = li + 1) begin
              $fwrite(tfd, "L %0d %0d %0d %07x %07x ", lvl[li], lfl[li], lyb[li], lcl[li], lrg[li]);
              for (lj = 0; lj < 160; lj = lj + 1) $fwrite(tfd, "%02x", lpix[li][lj * 8 +: 8]);
              $fwrite(tfd, " ");
              for (lj = 0; lj < 160; lj = lj + 1) $fwrite(tfd, "%0d", lsrc[li][lj * 2 +: 2]);
              $fwrite(tfd, " ");
              for (lj = 0; lj < evn[li]; lj = lj + 1) $fwrite(tfd, ",%0d:%0d:%0d:%0d", ev[li][lj][23:22], ev[li][lj][21:14], ev[li][lj][13:7], ev[li][lj][6:0]);
              $fwrite(tfd, "\n");
            end
          end
          seg = seg + 1; nl = 0;
          if (selpub > fz) begin $fclose(tfd); $finish; end
        end
        lvl[nl] = {7'd0, vid.vl}; lyb[nl] = vid.y; fl[5] = vid.cap;
        if (vid.vl == 9'd100) fmid = frame;
      end
      if (pix_x == 8'd159) begin
        fl[2] = vblank; fl[4] = vsync;
        fl[6] = vid.hmb; fl[7] = vid.blk;
        lpix[nl] = cur; lfl[nl] = fl; lvbx[nl] = vbx; vbx = 9'd0;
        lsrc[nl] = csrc; lcl[nl] = vid.cl; lrg[nl] = {colubk, colupf, colup0, colup1};
        for (ek = 0; ek < 16; ek = ek + 1) ev[nl][ek] = cev[ek];
        evn[nl] = cevn; cevn = 0;
        if (nl < 511) nl = nl + 1;
      end
    end
  end

  reg [7:0] frames_d = 0;
  reg [1023:0] fn;
  always @(posedge clk) begin
    frames_d <= fb_frames;
    if (fb_frames != frames_d) frame = frame + 1;
  end

  initial begin
    if (!$value$plusargs("rom=%s", romfile)) begin $display("no +rom"); $finish; end
    if (!$value$plusargs("out=%s", outp)) outp = "frame";
    if (!$value$plusargs("mapper=%d", mapper_i)) mapper_i = 1;
    if (!$value$plusargs("sc=%d", sc_i)) sc_i = 0;                 // Superchip RAM (F8 / F6)
    if (!$value$plusargs("f0=%d", f0)) f0 = 2;
    if (!$value$plusargs("f1=%d", f1)) f1 = f0;
    if (!$value$plusargs("f2=%d", f2)) f2 = f1;
    if (!$value$plusargs("rst0=%d", rst0)) rst0 = -1;
    if (!$value$plusargs("rst1=%d", rst1)) rst1 = -1;
    if (!$value$plusargs("yofs=%d", yofs_i)) yofs_i = 0;
    if (!$value$plusargs("pz_on=%d", pz_on)) pz_on = 0;
    if (!$value$plusargs("fa=%d", fa)) fa = 2;
    if (!$value$plusargs("fb=%d", fz)) fz = fa;
    if (!$value$plusargs("step=%d", fstep)) fstep = 1;
    if (!$value$plusargs("joy0=%d", joy0)) joy0 = -1;
    if (!$value$plusargs("joyv=%d", joyv)) joyv = 255;
    if (!$value$plusargs("fire=%d", fire_i)) fire_i = -1;
    $sformat(fn, "%0s.cw", outp);
    tfd = $fopen(fn, "w");
    if (!$value$plusargs("pz_per=%d", pz_per)) pz_per = 0;
    $readmemh(romfile, rom);
    repeat (8) @(posedge clk);
    rst = 0;
  end
endmodule
