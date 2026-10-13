// tb_d3.v -- (diagnosis 3, from tb_cw.v) a26_core + a26_vidwr + a26_tdict.  Read only: nothing here goes to the FPGA.
// <out>.d3, game frames +fa..+fb step +step:  "F <n> <published frame> <lines>" and per scan line
//   "L <line since VSYNC> <flags> <buffer line> <pixels> <objects>"
//   pixels: 2 hex digits (bit 7 = blanked, 6:0 = colour);  objects: 2 hex digits per pixel,
//   bit 0 P0, 1 P1, 2 M0, 3 M1, 4 BL, 5 PF (what the TIA has ON at that pixel, before priority)
// <out>.ev, the same frames: one line per event, <seg> = game frame counter, <line> = scan line since VSYNC fell,
//   "W <seg> <line> <hcount> <addr hex> <data hex>"            TIA write (hcount of the write = last clock of the CPU cycle)
//   "R <seg> <line> <hcount> <addr hex> <value hex> <pc hex>"  TIA read of $x0..$x7 (collision registers)
//   "C <seg> <line> <x> <15-bit mask hex>"                     collision latches that went 0 -> 1 at pixel x
//     mask bits: 14 m0p1 13 m0p0 12 m1p0 11 m1p1 10 p0pf 9 p0bl 8 p1pf 7 p1bl 6 m0pf 5 m0bl 4 m1pf 3 m1bl 2 blpf 1 p0p1 0 m0m1
// <out>.ram, EVERY frame: "A|B <seg> <published frames> <128 bytes hex>"  A = when VSYNC falls, B = 228 colour clocks later
`timescale 1ns / 1ps
module tb_d3;
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
    .swcha_in((joy0 >= 0 && frame >= joy0 && (joy1 < 0 || frame < joy1)) ? joyv[7:0] : 8'hFF), .swchb_in(swchb), .fire0(~(fire_i >= 0 && frame >= fire_i)), .fire1(1'b1), .inpt(4'h0), .pause(pause),
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


  reg [1279:0] lpix [0:511];
  reg [1279:0] lobj [0:511];
  reg [15:0]   lvl  [0:511];
  reg [7:0]    lfl  [0:511];
  reg [7:0]    lyb  [0:511];
  reg [1279:0] cur, cobj;
  reg [7:0]    fl;
  integer nl = 0, seg = 0, li, lj, selpub, fmid = 0, efd, rfd;
  integer ln = 0, evon = 0, bcnt = -1, ri, lnbad = 0, rcal0, rcal1;
  integer joy1;                      // +joy1=<frame>: the joystick value is released again from this published frame on
  reg vs_d = 0;
  reg [15:0] pc_last = 0;
  wire [14:0] cx = {core.u_tia.c_m0p1, core.u_tia.c_m0p0, core.u_tia.c_m1p0, core.u_tia.c_m1p1, core.u_tia.c_p0pf, core.u_tia.c_p0bl,
                    core.u_tia.c_p1pf, core.u_tia.c_p1bl, core.u_tia.c_m0pf, core.u_tia.c_m0bl, core.u_tia.c_m1pf, core.u_tia.c_m1bl,
                    core.u_tia.c_blpf, core.u_tia.c_p0p1, core.u_tia.c_m0m1};
  reg [14:0] cx_d = 0;
  reg [7:0]  x_d = 0;
  always @(posedge clk) begin
    vs_d <= vsync; cx_d <= cx;
    if (core.cpu_ce && cpu_sync) pc_last <= cpu_ab;
    // collision latches newly set (they were set by the pixel sampled on the clock before)
    if (evon != 0 && (cx & ~cx_d) != 15'd0) $fwrite(efd, "C %0d %0d %0d %04x\n", seg, ln, x_d, cx & ~cx_d);
    if (core.cc_ce) begin
      x_d <= core.u_tia.x;
      if (core.u_tia.vis_area) begin
        cur[core.u_tia.x * 8 +: 8]  = {~core.u_tia.vis_ok, core.u_tia.csel[7:1]};
        cobj[core.u_tia.x * 8 +: 8] = {2'b00, core.u_tia.pf_on, core.u_tia.bl_on, core.u_tia.m1_on, core.u_tia.m0_on, core.u_tia.p1_on, core.u_tia.p0_on};
      end
      if (hcount == 8'd227) ln = ln + 1;
      // calibration (+rcal0/+rcal1 = published-frame range): RAM at the start of every scan line, "Z <seg> <frame> <line> <hex>"
      if (hcount == 8'd227 && frame >= rcal0 && frame <= rcal1) begin
        $fwrite(rfd, "Z %0d %0d %0d ", seg, frame, ln);
        for (ri = 0; ri < 128; ri = ri + 1) $fwrite(rfd, "%02x", core.u_riot.ram[ri]);
        $fwrite(rfd, "\n");
      end
      if (bcnt > 0) bcnt = bcnt - 1;
      else if (bcnt == 0) begin
        bcnt = -1;
        $fwrite(rfd, "B %0d %0d ", seg, frame);
        for (ri = 0; ri < 128; ri = ri + 1) $fwrite(rfd, "%02x", core.u_riot.ram[ri]);
        $fwrite(rfd, "\n");
      end
    end
    if (vs_d && !vsync) begin
      ln = 0; bcnt = 228;
      evon = ((frame + 1) >= fa && (frame + 1) <= fz && (((frame + 1) - fa) % fstep) == 0) ? 1 : 0;
      $fwrite(rfd, "A %0d %0d ", seg + 1, frame);
      for (ri = 0; ri < 128; ri = ri + 1) $fwrite(rfd, "%02x", core.u_riot.ram[ri]);
      $fwrite(rfd, "\n");
    end
    if (evon != 0 && core.tia_wr)
      $fwrite(efd, "W %0d %0d %0d %02x %02x\n", seg, ln, hcount, cpu_ab[5:0], core.cpu_dout);
    if (evon != 0 && core.cpu_ce && !core.cpu_we && core.tia_cs && cpu_ab[3:0] < 4'd8)
      $fwrite(efd, "R %0d %0d %0d %02x %02x %04x\n", seg, ln, hcount, cpu_ab[3:0], core.tia_dout, pc_last);
    if (pix_stb) begin
      if (pix_x == 8'd0)  begin fl[0] = vblank; fl[3] = vsync; end
      if (pix_x == 8'd16) fl[1] = vblank;
      if (pix_x == 8'd1) begin
        if (vid.vl <= 9'd1 && nl > 2 && lvl[nl - 1] > 16'd1) begin
          selpub = fmid + 1;
          if (selpub >= fa && selpub <= fz && ((selpub - fa) % fstep) == 0) begin
            $fwrite(tfd, "F %0d %0d %0d\n", seg, selpub, nl);
            for (li = 0; li < nl; li = li + 1) begin
              $fwrite(tfd, "L %0d %0d %0d ", lvl[li], lfl[li], lyb[li]);
              for (lj = 0; lj < 160; lj = lj + 1) $fwrite(tfd, "%02x", lpix[li][lj * 8 +: 8]);
              $fwrite(tfd, " ");
              for (lj = 0; lj < 160; lj = lj + 1) $fwrite(tfd, "%02x", lobj[li][lj * 8 +: 8]);
              $fwrite(tfd, "\n");
            end
          end
          seg = seg + 1; nl = 0;
          if (selpub > fz) begin $display("line counter mismatches: %0d", lnbad); $fclose(tfd); $fclose(efd); $fclose(rfd); $finish; end
        end
        lvl[nl] = {7'd0, vid.vl}; lyb[nl] = vid.y; fl[5] = vid.cap;
        if (vid.vl != ln[8:0]) lnbad = lnbad + 1;
        if (vid.vl == 9'd100) fmid = frame;
      end
      if (pix_x == 8'd159) begin
        fl[2] = vblank; fl[4] = vsync; fl[6] = vid.hmb; fl[7] = vid.blk;
        lpix[nl] = cur; lobj[nl] = cobj; lfl[nl] = fl;
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
    if (!$value$plusargs("rcal0=%d", rcal0)) rcal0 = 1 << 30;
    if (!$value$plusargs("joy1=%d", joy1)) joy1 = -1;
    if (!$value$plusargs("rcal1=%d", rcal1)) rcal1 = -1;
    $sformat(fn, "%0s.d3", outp);
    tfd = $fopen(fn, "w");
    $sformat(fn, "%0s.ev", outp);
    efd = $fopen(fn, "w");
    $sformat(fn, "%0s.ram", outp);
    rfd = $fopen(fn, "w");
    if (!$value$plusargs("pz_per=%d", pz_per)) pz_per = 0;
    $readmemh(romfile, rom);
    repeat (8) @(posedge clk);
    rst = 0;
  end
endmodule
