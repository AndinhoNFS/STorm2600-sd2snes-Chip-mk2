// SPDX-License-Identifier: GPL-2.0-or-later
// tb_a26_vidwr.v -- self-checking test for a26_vidwr.v
//
// Drives synthetic NTSC-like frames (3 VSYNC lines, 37 VBLANK, 192 picture,
// 30 overscan) through a26_vidwr + a26_tdict and checks, in the buffer as the SNES
// reads it: header, tile map and tile list (rebuilt into the 256-column picture and
// compared pixel for pixel), the numbering of the tiles, the colour and window
// tables, the fixed picture window (YS0 + offset lines after VSYNC), the three
// buffers, the lock and the dropped frame when the dictionary overflows.
// One colour clock is 4 clk, as in the Verilator benches.
//
// run:  iverilog -g2005 -Wall -o tb_vidwr tb_a26_vidwr.v a26_vidwr.v a26_tdict.v && vvp tb_vidwr
`timescale 1ns / 1ps

module tb_a26_vidwr;
  reg        clk = 0, rst = 1;
  always #5 clk = ~clk;

  reg        pix_stb = 0, pix_vis = 1, vsync = 0, vblank = 0;
  reg [7:0]  pix_x = 0;
  reg [1:0]  pix_src = 0;
  reg [6:0]  pix_col = 0;
  reg [6:0]  colubk = 0, colupf = 0, colup0 = 0, colup1 = 0;
  wire       fb_wr, v_wr, ev_row, ev_end, eng_ack, eng_ovf;
  wire [15:0] v_waddr, v_wdata;
  wire [7:0]  end_lines, fb_dropped;
  wire [9:0]  tile_n;
  wire [1:0] fb_newest;
  wire [15:0] fb_waddr;
  wire [15:0] fb_wdata;
  wire [7:0]  fb_frames, fb_nlines;
  reg         lock_v = 0;
  reg  [1:0]  lock_i = 0;
  reg  [6:0]  yofs = 0;

  localparam YS0 = 34;
  reg     sink_ok = 1;                 // 0: the PSRAM side takes no word from the dictionary

  a26_vidwr #(.YS0(YS0)) dut (.clk(clk), .rst(rst),
                 .pix_stb(pix_stb), .pix_x(pix_x), .pix_vis(pix_vis), .pix_src(pix_src), .pix_col(pix_col),
                 .vsync(vsync), .vblank(vblank),
                 .colubk(colubk), .colupf(colupf), .colup0(colup0), .colup1(colup1),
                 .fb_wr(v_wr), .fb_waddr(v_waddr), .fb_wdata(v_wdata),
                 .fb_newest(fb_newest), .fb_frames(fb_frames), .fb_nlines(fb_nlines),
                 .lock_v(lock_v), .lock_i(lock_i), .yofs(yofs),
                 .ev_row(ev_row), .ev_end(ev_end), .end_lines(end_lines),
                 .eng_ack(eng_ack), .eng_ovf(eng_ovf), .fb_dropped(fb_dropped));

  // the PSRAM side accepts a word whenever one is offered
  a26_tdict dict (.clk(clk), .rst(rst),
                  .v_wr(v_wr), .v_waddr(v_waddr), .v_wdata(v_wdata),
                  .ev_row(ev_row), .ev_end(ev_end), .end_lines(end_lines),
                  .eng_ack(eng_ack), .eng_ovf(eng_ovf), .tile_n(tile_n),
                  .m_wr(fb_wr), .m_waddr(fb_waddr), .m_wdata(fb_wdata),
                  .fifo_low(sink_ok), .wr_idle(1'b1));

  reg [15:0] mem [0:65535];
  integer i;
  initial for (i = 0; i < 65536; i = i + 1) mem[i] = 16'h0000;
  always @(posedge clk) if (fb_wr) mem[fb_waddr] <= fb_wdata;

  integer errs = 0, last_n = 0;
  reg     vs_mid = 0;

  // ---- monitors -------------------------------------------------------------------
  // writes per line (a line may carry 32 tile words + 9 table words + 1 word of entry 224),
  // writes into the locked buffer, writes into a buffer that does not exist, and how
  // often the newest buffer changed
  integer wr_line = 0, wr_line_max = 0, lock_wr = 0, bad_buf = 0, n_changes = 0, lock_arm = 0;
  reg [1:0] newest_d = 0;
  always @(posedge clk) begin
    if (pix_stb && pix_x == 8'd0) begin
      if (wr_line > wr_line_max) wr_line_max = wr_line;
      wr_line = 0;
    end
    if (fb_wr) begin
      wr_line = wr_line + 1;
      if (fb_waddr[15:14] == 2'd3) bad_buf = bad_buf + 1;
      if (lock_arm != 0 && lock_v && fb_waddr[15:14] == lock_i) lock_wr = lock_wr + 1;
    end
    newest_d <= fb_newest;
    if (fb_newest != newest_d) n_changes = n_changes + 1;
    if (fb_newest == 2'd3) bad_buf = bad_buf + 1;
  end

  // the colour ROM, read from the same table the writer's function was generated from
  reg [15:0] bgr [0:127];
  initial $readmemh("a26_bgr555.hex", bgr);

  // test pattern: deterministic source code per pixel, per frame number f.  Frames 100 and
  // up are noise (every tile different: more than the dictionary holds)
  function [1:0] srcf; input integer x; input integer y; input integer f;
    reg [31:0] v;
    begin
      if (f >= 100) begin
        v = (x * 40503 + y * 30011 + f * 7919) * 1103515245 + 12345;
        v = v ^ (v >> 13); v = v * 1664525 + 1013904223;
        srcf = v[21:20];
      end else begin
        v = (x * 3 + y * 5 + f) >> 1; srcf = v[1:0];
      end
    end
  endfunction

  // frame 0 has a blanked stretch (HMOVE-bar style) on picture line 10
  function visf; input integer x; input integer y; input integer f;
    begin visf = !(f == 0 && y == 10 && x < 8); end
  endfunction

  // the colour registers at pixel x of picture line y (k = 0 BK, 1 PF, 2 P0, 3 P1).  The
  // colours of the line (y + k) are only in the registers from pixel 10 to pixel 99: before
  // and after they hold something else (the writer must sample at pixel 16).  On the lines
  // with y % 4 == 1 the "something else" is chosen to hit colours the line holds:
  //   x >= 100: COLUPF = the line's COLUBK, COLUP1 = the line's COLUP0, COLUP0 unchanged
  //   x <  10 : COLUPF = the line's COLUBK (before pixel 17: the writer must NOT act on it)
  function [6:0] regf; input integer k; input integer x; input integer y;
    integer v;
    begin
      v = y + k + ((x < 10 || x >= 100) ? 40 : 0);
      if ((y & 3) == 1) begin
        if (x >= 100) v = (k == 1) ? y : (k == 3) ? y + 2 : (k == 2) ? y + 2 : v;
        else if (x < 10 && k == 1) v = y;
      end
      regf = v[6:0];
    end
  endfunction

  // the index the writer must give pixel x: its source, unless (from pixel 17 on) the colour
  // held for the source is not the pixel's final colour and a held colour is
  function [1:0] idxf; input integer x; input integer y; input integer f;
    reg [1:0] sv;
    reg [6:0] fin;
    integer k, got;
    begin
      sv = srcf(x, y, f); fin = regf(sv, x, y); idxf = sv; got = 0;
      if (x > 16 && fin !== regf(sv, 16, y))
        for (k = 0; k < 4; k = k + 1)
          if (!got && fin === regf(k, 16, y)) begin idxf = k[1:0]; got = 1; end
    end
  endfunction
  integer n_fix = 0;                   // pixels the rule must move to another index (frame 0)

  // tile tx = 6..25 holds TIA pixels 8(tx-6) .. 8(tx-6)+7, one column each; the other tiles are zero
  function inpic; input integer tx;
    begin inpic = (tx >= 6 && tx <= 25); end
  endfunction

  // one scan line.  line 0..2 = VSYNC, picture on lines 40..231 (picture line y = line - 40)
  task run_line; input integer f; input integer line;
    integer c, y, x, g;
    begin
      y = line - 40;
      for (c = 0; c < 228; c = c + 1) begin
        @(negedge clk);
        if (c == 0) begin                 // VSYNC and VBLANK change in HBLANK, as after a WSYNC
          vsync  = (line < 3);
          vblank = (line < 40) || (line >= 232);
          // a noise frame shows picture on every line of the window: 28 x 20 = 560 different
          // tiles (with 192 lines there would be 480, which fit)
          if (f >= 100) vblank = (line < 30);
        end
        if (vs_mid && line == 2 && c == 150) vsync = 0;   // ... or VSYNC ends inside the picture part
        x = c - 68;
        colubk = regf(0, x, y);
        colupf = regf(1, x, y);
        colup0 = regf(2, x, y);
        colup1 = regf(3, x, y);
        pix_stb = (c >= 68);
        pix_x   = (c >= 68) ? x : 0;
        pix_src = srcf(x, y, f);
        pix_col = regf(pix_src, x, y);      // the final colour: the source's register right now
        pix_vis = !vblank && visf(x, y, f);
        @(negedge clk); pix_stb = 0;      // one colour clock = 4 clk
        @(negedge clk); @(negedge clk);
      end
    end
  endtask

  task run_frame; input integer f;
    integer line;
    begin for (line = 0; line < 262; line = line + 1) run_line(f, line); end
  endtask

  // buffer row r holds scan line 3 + YS0 + ofs + r (VSYNC ends on line 3); nl = rows written
  task check_buf; input integer b; input integer f; input [8*32-1:0] nm; input integer ofs; input integer nl;
    integer ty, tx, r, i2, y, row, line, bad_t, bad_p, bad_m, nmax, base, blank;
    reg [7:0] p0, p1;
    reg [1:0] s;
    reg [15:0] got, expw;
    reg [6:0] kbk, kpf, kp0, kp1;
    begin
      bad_t = 0; bad_p = 0; base = b * 16384;
      for (ty = 0; ty < 28; ty = ty + 1)
        for (tx = 0; tx < 32; tx = tx + 1)
          for (r = 0; r < 8; r = r + 1) if (ty * 8 + r < nl) begin
            row = ty * 8 + r; line = 3 + YS0 + ofs + row; y = line - 40;
            blank = (line < 40) || (line >= 232);
            p0 = 8'd0; p1 = 8'd0;
            for (i2 = 0; i2 < 8; i2 = i2 + 1) begin
              s = (!blank && inpic(tx) && visf((tx - 6) * 8 + i2, y, f)) ? idxf((tx - 6) * 8 + i2, y, f) : 2'b00;
              if (f == 0 && !blank && inpic(tx) && s !== srcf((tx - 6) * 8 + i2, y, f)) n_fix = n_fix + 1;
              p0 = {p0[6:0], s[0]};
              p1 = {p1[6:0], s[1]};
            end
            expw = {p1, p0};
            got  = mem[base + 16'h0400 + mem[base + 8 + ty * 32 + tx] * 8 + r];     // through the map
            if (got !== expw) bad_t = bad_t + 1;
          end else begin
            // a line that was not written counts as zero (and a row with none is tile 0)
            if (mem[base + 16'h0400 + mem[base + 8 + ty * 32 + tx] * 8 + r] !== 16'h0000) bad_t = bad_t + 1;
          end
      // colour tables: channel k at word $2000 + k*$200, row = 2 words {k,k} and BGR555;
      // window table at word $2800: left 48 (56 with the HMOVE bar), right 207
      for (row = 0; row < nl; row = row + 1) begin
        line = 3 + YS0 + ofs + row; y = line - 40;
        blank = (line < 40) || (line >= 232);
        kbk = y & 127; kpf = (y + 1) & 127; kp0 = (y + 2) & 127; kp1 = (y + 3) & 127;
        if (mem[base + 16'h2000 + row * 2]     !== 16'h0000)  bad_p = bad_p + 1;
        if (mem[base + 16'h2000 + row * 2 + 1] !== (blank ? 16'h0000 : bgr[kbk]))  bad_p = bad_p + 1;
        if (mem[base + 16'h2200 + row * 2]     !== 16'h0101)  bad_p = bad_p + 1;
        if (mem[base + 16'h2200 + row * 2 + 1] !== (blank ? 16'h0000 : bgr[kpf]))  bad_p = bad_p + 1;
        if (mem[base + 16'h2400 + row * 2]     !== 16'h0202)  bad_p = bad_p + 1;
        if (mem[base + 16'h2400 + row * 2 + 1] !== (blank ? 16'h0000 : bgr[kp0]))  bad_p = bad_p + 1;
        if (mem[base + 16'h2600 + row * 2]     !== 16'h0303)  bad_p = bad_p + 1;
        if (mem[base + 16'h2600 + row * 2 + 1] !== (blank ? 16'h0000 : bgr[kp1]))  bad_p = bad_p + 1;
        if (mem[base + 16'h2800 + row] !== {8'd207, (!blank && !visf(0, y, f)) ? 8'd56 : 8'd48}) bad_p = bad_p + 1;
      end
      // entry 224: black in every channel, full window
      if (mem[base + 16'h2000 + 448] !== 16'h0000 || mem[base + 16'h2000 + 449] !== 16'h0000) bad_p = bad_p + 1;
      if (mem[base + 16'h2200 + 448] !== 16'h0101 || mem[base + 16'h2200 + 449] !== 16'h0000) bad_p = bad_p + 1;
      if (mem[base + 16'h2400 + 448] !== 16'h0202 || mem[base + 16'h2400 + 449] !== 16'h0000) bad_p = bad_p + 1;
      if (mem[base + 16'h2600 + 448] !== 16'h0303 || mem[base + 16'h2600 + 449] !== 16'h0000) bad_p = bad_p + 1;
      if (mem[base + 16'h2800 + 224] !== {8'd255, 8'd0}) bad_p = bad_p + 1;
      // the map: numbers in order of first appearance (each entry is at most one more than
      // the largest before it), no two numbers with the same 8 words, tile 0 = zero, and
      // the header = how many numbers were used; words 1..7 of the header are 0
      bad_m = 0; nmax = 0;
      for (ty = 0; ty < 896; ty = ty + 1) begin
        i2 = mem[base + 8 + ty];
        if (i2 > nmax + 1 || i2 > 1023) bad_m = bad_m + 1;
        if (i2 > nmax) nmax = i2;
      end
      for (ty = 0; ty <= nmax; ty = ty + 1)
        for (tx = ty + 1; tx <= nmax; tx = tx + 1) begin
          row = 1;
          for (r = 0; r < 8; r = r + 1) if (mem[base + 16'h0400 + ty * 8 + r] !== mem[base + 16'h0400 + tx * 8 + r]) row = 0;
          if (row) bad_m = bad_m + 1;
        end
      for (r = 0; r < 8; r = r + 1) if (mem[base + 16'h0400 + r] !== 16'h0000) bad_m = bad_m + 1;
      if (mem[base] !== nmax + 1) bad_m = bad_m + 1;
      for (r = 1; r < 8; r = r + 1) if (mem[base + r] !== 16'h0000) bad_m = bad_m + 1;
      last_n = mem[base];
      if (bad_t != 0 || bad_p != 0 || bad_m != 0) begin
        errs = errs + 1;
        $display("FAIL  %0s: %0d wrong tile words, %0d wrong table words, %0d map/list/header errors", nm, bad_t, bad_p, bad_m);
      end else
        $display("ok    %0s: %0d tile words (through the map) and %0d table words match; %0d distinct tiles", nm, nl * 32, nl * 9 + 9, mem[base]);
    end
  endtask

  task expect_val; input [8*48-1:0] nm; input integer got; input integer exp;
    begin
      if (got !== exp) begin errs = errs + 1; $display("FAIL  %0s: got %0d, expected %0d", nm, got, exp); end
      else $display("ok    %0s = %0d", nm, got);
    end
  endtask

  // ---- the "SNES" of the lock test: copies the locked buffer a piece at a time ---------
  reg [15:0] snap [0:16383];
  reg [15:0] ref [0:16383];
  integer rd_bad, f, line, lk, held, piece, n0, w_seen, q;

  // lines 0..n-1 of frame f (the frame before it is published during them)
  task run_lines; input integer f; input integer l0; input integer l1;
    integer l;
    begin for (l = l0; l < l1; l = l + 1) run_line(f, l); end
  endtask

  initial begin
    repeat (5) @(negedge clk);
    rst = 0;

    run_frame(0);
    expect_val("frames after frame 0", fb_frames, 0);     // not published yet
    run_line(1, 0);                                       // VSYNC of frame 1 ends frame 0 ...
    expect_val("frames right after the VSYNC", fb_frames, 0);   // ... but the dictionary is not done
    run_lines(1, 1, 4);
    expect_val("frames 3 lines later", fb_frames, 1);
    expect_val("newest buffer",        fb_newest, 1);
    expect_val("lines written",        fb_nlines, 224);
    run_lines(1, 4, 262);
    check_buf(1, 0, "buffer 1 = frame 0", 0, 224);
    expect_val("tile count register = header", tile_n, last_n);
    // buffer row 3 is picture line 0 (scan line 40 = 3 + 34 + 3); the HMOVE-bar line is row 13
    expect_val("window left, row 13 (HMOVE bar)", mem[16384 + 16'h2800 + 13][7:0], 56);
    expect_val("window left, row 12",   mem[16384 + 16'h2800 + 12][7:0], 48);
    expect_val("window left, row 14",   mem[16384 + 16'h2800 + 14][7:0], 48);
    expect_val("window right, row 13",  mem[16384 + 16'h2800 + 13][15:8], 207);
    expect_val("COLUBK row 13 = colour 10", mem[16384 + 16'h2000 + 27], bgr[10]);
    expect_val("COLUP1 row 13 = colour 13", mem[16384 + 16'h2600 + 27], bgr[13]);
    expect_val("COLUP1 row 2 (VBLANK) = black", mem[16384 + 16'h2600 + 5], 0);
    expect_val("COLUP1 row 3 = colour 3",       mem[16384 + 16'h2600 + 7], bgr[3]);
    expect_val("COLUP1 row 194 = colour 66",    mem[16384 + 16'h2600 + 389], bgr[(191 + 3) & 127]);
    expect_val("COLUP1 row 195 (VBLANK) = black", mem[16384 + 16'h2600 + 391], 0);
    expect_val("map entry of a VBLANK tile row (row 27)", mem[16384 + 8 + 27 * 32 + 5], 0);
    expect_val("colour ROM entry 7 (white)", bgr[7], 16'h7FFF);
    begin : hmcount
      integer nset;
      nset = 0;
      for (q = 0; q < 224; q = q + 1) if (mem[16384 + 16'h2800 + q][7:0] == 8'd56) nset = nset + 1;
      expect_val("lines with the bar in frame 0", nset, 1);
      // nothing may land outside header, map, the tiles in use and the five tables
      nset = 0;
      for (q = 0; q < 16384; q = q + 1)
        if (mem[16384 + q] !== 16'h0000
            && !(q < 8 + 896) && !(q >= 16'h0400 && q < 16'h0400 + last_n * 8)
            && !(q >= 16'h2000 && q < 16'h2000 + 450) && !(q >= 16'h2200 && q < 16'h2200 + 450)
            && !(q >= 16'h2400 && q < 16'h2400 + 450) && !(q >= 16'h2600 && q < 16'h2600 + 450)
            && !(q >= 16'h2800 && q < 16'h2800 + 225)) nset = nset + 1;
      expect_val("words written outside the layout", nset, 0);
    end

    run_frame(2);                                         // publishes frame 1
    expect_val("frames after frame 2", fb_frames, 2);
    expect_val("newest buffer",        fb_newest, 2);
    check_buf(2, 1, "buffer 2 = frame 1", 0, 224);
    run_frame(3);
    expect_val("newest buffer",        fb_newest, 0);
    check_buf(0, 2, "buffer 0 = frame 2", 0, 224);

    // ---- vertical offset: taken when VSYNC ends -----------------------------------------
    yofs = -7'sd16;                                       // window 16 lines earlier
    run_frame(4);                                         // publishes frame 3 (offset 0)
    run_frame(5);                                         // publishes frame 4, offset -16
    expect_val("lines, offset -16", fb_nlines, 224);
    check_buf(fb_newest, 4, "offset -16: frame 4", -16, 224);
    yofs = 7'sd47;                                        // 47 lines later: only 178 lines fit,
    run_frame(6); run_frame(7);                           // 22 tile rows and 2 lines of the 23rd
    expect_val("lines, offset +47", fb_nlines, 178);
    check_buf(fb_newest, 6, "offset +47: frame 6", 47, 178);
    expect_val("map of an unwritten row (row 23) = 0", mem[fb_newest * 16384 + 8 + 23 * 32 + 9], 0);
    expect_val("map of an unwritten row (row 27) = 0", mem[fb_newest * 16384 + 8 + 27 * 32 + 31], 0);
    yofs = 7'sd0;
    run_frame(8); run_frame(9);                           // publishes frame 8
    expect_val("lines, offset 0 again", fb_nlines, 224);
    check_buf(fb_newest, 8, "offset 0 again: frame 8", 0, 224);

    // ---- VSYNC that ends in the picture part of a line: that line is line 0 (as in Stella),
    // ---- so the window starts one scan line earlier than when it ends in the next HBLANK
    vs_mid = 1;
    run_frame(10); run_frame(11);                         // publishes frame 10
    expect_val("lines, VSYNC ending mid-line", fb_nlines, 224);
    check_buf(fb_newest, 10, "VSYNC ending mid-line: frame 10", -1, 224);
    vs_mid = 0;
    run_frame(8); run_frame(9);                           // back to normal; publishes frame 8
    check_buf(fb_newest, 8, "VSYNC ending in HBLANK again", 0, 224);

    // ---- more distinct tiles than the dictionary holds: the frame is dropped ---------------
    run_lines(100, 0, 4);                                 // (publishes frame 9)
    n0 = fb_newest; q = fb_frames;
    for (piece = 0; piece < 16384; piece = piece + 1) ref[piece] = mem[n0 * 16384 + piece];
    run_lines(100, 4, 262);                               // noise: 896 different tiles
    run_frame(12);                                        // would publish frame 100
    expect_val("dropped frames", fb_dropped, 1);
    expect_val("newest buffer unchanged by the drop", fb_newest, n0);
    expect_val("frame counter unchanged by the drop", fb_frames, q);
    rd_bad = 0;
    for (piece = 0; piece < 16384; piece = piece + 1) if (mem[n0 * 16384 + piece] !== ref[piece]) rd_bad = rd_bad + 1;
    expect_val("newest buffer: words changed by the drop", rd_bad, 0);
    run_frame(13);                                        // publishes frame 12: back to normal
    expect_val("frames after the drop", fb_frames, (q + 1) & 255);
    check_buf(fb_newest, 12, "first frame after the drop", 0, 224);
    expect_val("dropped frames, still", fb_dropped, 1);

    // ---- lock: the SNES copies one buffer, 64 words every 5 scan lines, while the core --------
    // ---- completes 4 frames ---------------------------------------------------------------
    run_lines(14, 0, 4);                                  // publishes frame 13
    lk = fb_newest; lock_i = lk[1:0]; lock_v = 1; lock_arm = 1;
    for (piece = 0; piece < 16384; piece = piece + 1) ref[piece] = mem[lk * 16384 + piece];
    n_changes = 0; piece = 0;
    f = 14; line = 4;
    while (piece < 256) begin
      run_line(f, line);
      line = line + 1;
      if (line == 262) begin line = 0; f = f + 1; end
      if ((line % 5) == 0) begin
        for (q = 0; q < 64; q = q + 1) snap[piece * 64 + q] = mem[lk * 16384 + piece * 64 + q];
        piece = piece + 1;
      end
    end
    expect_val("newest changed during the read", n_changes, 4);
    expect_val("writes into the locked buffer", lock_wr, 0);
    rd_bad = 0;
    for (piece = 0; piece < 16384; piece = piece + 1) if (snap[piece] !== ref[piece]) rd_bad = rd_bad + 1;
    expect_val("words of the read that differ", rd_bad, 0);
    for (piece = 0; piece < 16384; piece = piece + 1) mem[49152 + piece] = snap[piece];   // buffer 3 does not exist: scratch
    check_buf(3, 13, "what the SNES read = frame 13", 0, 224);
    if (fb_newest == lk[1:0]) begin errs = errs + 1; $display("FAIL  newest is still the locked buffer"); end

    // ---- the newest buffer changes between the read of R0 and the write of the lock ---------
    lock_v = 0;
    while (line != 261) begin run_line(f, line); line = line + 1; end
    n0 = fb_newest;                                       // the SNES reads R0 ...
    for (piece = 0; piece < 16384; piece = piece + 1) ref[piece] = mem[n0 * 16384 + piece];
    run_line(f, 261); f = f + 1;
    run_lines(f, 0, 4);                                   // ... a frame ends and is published ...
    if (fb_newest == n0[1:0]) begin errs = errs + 1; $display("FAIL  no frame ended in the gap"); end
    else $display("ok    newest moved from %0d to %0d before the lock was written", n0, fb_newest);
    lock_i = n0[1:0]; lock_v = 1;                         // ... and only now the lock arrives
    lock_wr = 0;
    for (held = 0; held < 3; held = held + 1) begin
      run_lines(f, (held == 0) ? 4 : 0, 262);
      f = f + 1;
    end
    expect_val("writes into the late-locked buffer", lock_wr, 0);
    rd_bad = 0;
    for (piece = 0; piece < 16384; piece = piece + 1) if (mem[n0 * 16384 + piece] !== ref[piece]) rd_bad = rd_bad + 1;
    expect_val("late-locked buffer: changed words", rd_bad, 0);

    // ---- the lock moves every frame: all three buffers get locked in turn -----------------
    w_seen = 0;
    for (held = 0; held < 9; held = held + 1) begin
      run_lines(f, 0, 4);
      lock_i = fb_newest; lock_v = 1;                     // lock what was just completed
      run_lines(f, 4, 262);
      w_seen = w_seen | (1 << lock_i);
      f = f + 1;
    end
    expect_val("writes into a locked buffer (moving lock)", lock_wr, 0);
    expect_val("buffers that were locked (mask)", w_seen, 7);
    expect_val("writes to / reports of a buffer 3", bad_buf, 0);
    lock_v = 0; lock_arm = 0;
    run_frame(f); run_frame(f + 1);
    check_buf(fb_newest, f, "after the lock: newest frame", 0, 224);
    expect_val("dropped frames before the stall", fb_dropped, 1);

    // ---- the PSRAM side stalls for 80 lines after a frame: that frame is published late but
    // ---- whole, the next one (whose window started meanwhile) is left out whole, and the
    // ---- one after it is in place again
    q = fb_frames;
    sink_ok = 0;
    run_lines(f + 2, 0, 80);                              // frame f+1 has ended, its header cannot go out
    expect_val("frames while stalled", fb_frames, q);
    sink_ok = 1;
    run_lines(f + 2, 80, 262);
    expect_val("frames after the stall", fb_frames, (q + 1) & 255);
    check_buf(fb_newest, f + 1, "frame published late", 0, 224);
    expect_val("dropped frames: the one left out", fb_dropped, 2);
    n0 = fb_newest;
    run_frame(f + 3);                                     // frame f+2 had no line: nothing is published
    expect_val("frames after the left-out frame", fb_frames, (q + 1) & 255);
    expect_val("newest after the left-out frame", fb_newest, n0);
    run_frame(f + 4);                                     // publishes frame f+3
    expect_val("frames, back to normal", fb_frames, (q + 2) & 255);
    check_buf(fb_newest, f + 3, "first frame after the stall", 0, 224);
    expect_val("dropped frames at the end", fb_dropped, 2);

    if (n_fix == 0) begin errs = errs + 1; $display("FAIL  the test pattern never exercised the colour rule"); end
    else $display("ok    colour rule: %0d pixels of frame 0 checked with an index other than their source", n_fix);
    if (errs == 0) $display("PASS  a26_vidwr + a26_tdict");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end

  initial begin
    #2000000000; #2000000000; #2000000000;
    $display("FAIL  global timeout");
    $finish;
  end
endmodule
