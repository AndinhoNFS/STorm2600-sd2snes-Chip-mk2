// SPDX-License-Identifier: GPL-2.0-or-later
// tb_tia.v -- self-checking test for tia.v
//
// The testbench captures every rendered line into a 160-pixel buffer and
// checks pixel positions against the positioning model documented at the
// top of tia.v.  It checks coherence with that model, not with real
// hardware.
//
// run:  iverilog -g2005 -Wall -o tb_tia tb_tia.v tia.v && vvp tb_tia
`timescale 1ns / 1ps

module tb_tia;
  reg        clk = 0, rst = 1, wr = 0;
  reg [5:0]  a = 0;
  reg [7:0]  din = 0;
  reg [3:0]  inpt = 4'hF;
  reg        inpt4 = 1, inpt5 = 1;
  wire [7:0] dout, hcount, pix_x;
  wire [6:0] pix_col, colubk, colupf, colup0, colup1;
  wire [1:0] pix_src;
  wire [3:0] audc0, audc1, audv0, audv1;
  wire [4:0] audf0, audf1;
  wire       rdy, phi2_ce, vsync, vblank, pix_stb, pix_vis;

  tia dut (.clk(clk), .rst(rst), .cc_ce(1'b1), .a(a), .wr(wr), .din(din),
           .dout(dout), .inpt(inpt), .inpt4(inpt4), .inpt5(inpt5),
           .rdy(rdy), .phi2_ce(phi2_ce), .hcount_o(hcount),
           .vsync(vsync), .vblank(vblank),
           .pix_stb(pix_stb), .pix_x(pix_x), .pix_vis(pix_vis),
           .pix_src(pix_src), .pix_col(pix_col),
           .colubk(colubk), .colupf(colupf), .colup0(colup0), .colup1(colup1),
           .audc0(audc0), .audc1(audc1), .audf0(audf0), .audf1(audf1),
           .audv0(audv0), .audv1(audv1));

  always #5 clk = ~clk;                 // cc_ce = 1: one colour clock per clk

  // ---- line capture ----------------------------------------------------
  reg [1:0] lb_src [0:159];
  reg       lb_vis [0:159];
  always @(posedge clk) if (pix_stb) begin
    lb_src[pix_x] <= pix_src;
    lb_vis[pix_x] <= pix_vis;
  end

  integer errs = 0;

  // ---- helpers ---------------------------------------------------------
  task wait_h; input [7:0] h;           // block until hcount == h (at a falling edge)
    begin while (hcount !== h) @(negedge clk); end
  endtask

  task tia_wr; input [5:0] aa; input [7:0] d;   // write at the next phi2_ce
    begin
      @(negedge clk);
      while (!phi2_ce) @(negedge clk);
      a = aa; din = d; wr = 1;
      @(negedge clk);
      wr = 0;
    end
  endtask

  task tia_wr_at; input [7:0] h; input [5:0] aa; input [7:0] d;  // h % 3 must be 2
    begin
      wait_h(h);
      a = aa; din = d; wr = 1;
      @(negedge clk);
      wr = 0;
    end
  endtask

  task tia_rd; input [5:0] aa; output [7:0] d;
    begin a = aa; #1; d = dout; end
  endtask

  // after the configuration writes: the buffer then holds one complete
  // line drawn with the new configuration (read it at hcount 10)
  task settle;
    begin wait_h(8'd100); wait_h(8'd20); wait_h(8'd10); end
  endtask

  task expect_range; input [8*20-1:0] nm; input [1:0] src; input integer from; input integer to;
    integer j, bad;
    begin
      bad = 0;
      for (j = from; j <= to; j = j + 1)
        if (!(lb_vis[j] === 1'b1 && lb_src[j] === src)) bad = bad + 1;
      if (bad != 0) begin
        errs = errs + 1;
        $display("FAIL  %0s: %0d wrong pixel(s) in [%0d..%0d], expected src %0d", nm, bad, from, to, src);
      end
    end
  endtask

  task expect_nz; input [8*20-1:0] nm; input integer n;
    integer j, c;
    begin
      c = 0;
      for (j = 0; j < 160; j = j + 1)
        if (lb_vis[j] === 1'b1 && lb_src[j] !== 2'd0) c = c + 1;
      if (c != n) begin
        errs = errs + 1;
        $display("FAIL  %0s: %0d non-background pixels, expected %0d", nm, c, n);
      end
    end
  endtask

  task expect8; input [8*20-1:0] nm; input [7:0] got; input [7:0] exp;
    begin
      if (got !== exp) begin
        errs = errs + 1;
        $display("FAIL  %0s: got %02h, expected %02h", nm, got, exp);
      end
    end
  endtask

  // clear everything except what the caller then sets
  task clear_all;
    begin
      tia_wr(6'h0D, 8'h00); tia_wr(6'h0E, 8'h00); tia_wr(6'h0F, 8'h00);
      tia_wr(6'h0A, 8'h00); tia_wr(6'h1B, 8'h00); tia_wr(6'h1C, 8'h00);
      tia_wr(6'h1F, 8'h00); tia_wr(6'h1D, 8'h00); tia_wr(6'h04, 8'h00);
      tia_wr(6'h0B, 8'h00); tia_wr(6'h25, 8'h00); tia_wr(6'h27, 8'h00);
    end
  endtask

  integer k;
  reg [7:0] v;

  initial begin
    for (k = 0; k < 160; k = k + 1) begin lb_src[k] = 2'd0; lb_vis[k] = 1'b0; end
    repeat (4) @(negedge clk);
    rst = 0;
    wait_h(8'd100); wait_h(8'd20);      // let two lines run

    // ================= playfield, repeated ===========================
    wait_h(8'd10);
    clear_all;
    tia_wr(6'h0D, 8'h10); tia_wr(6'h0E, 8'h80); tia_wr(6'h0F, 8'h01);
    settle;
    expect_range("pf0 left",  2'd1,   0,   3);
    expect_range("pf1 left",  2'd1,  16,  19);
    expect_range("pf2 left",  2'd1,  48,  51);
    expect_range("pf0 right", 2'd1,  80,  83);
    expect_range("pf1 right", 2'd1,  96,  99);
    expect_range("pf2 right", 2'd1, 128, 131);
    expect_nz("pf repeat count", 24);

    // ================= playfield, reflected ==========================
    tia_wr(6'h0A, 8'h01);
    settle;
    expect_range("rf pf0 left",  2'd1,   0,   3);
    expect_range("rf pf1 left",  2'd1,  16,  19);
    expect_range("rf pf2 left",  2'd1,  48,  51);
    expect_range("rf pf2 right", 2'd1, 108, 111);
    expect_range("rf pf1 right", 2'd1, 140, 143);
    expect_range("rf pf0 right", 2'd1, 156, 159);
    expect_nz("pf reflect count", 24);

    // ================= playfield, score mode =========================
    tia_wr(6'h0A, 8'h02);
    settle;
    expect_range("score left a",  2'd2,   0,   3);
    expect_range("score left b",  2'd2,  16,  19);
    expect_range("score left c",  2'd2,  48,  51);
    expect_range("score right a", 2'd3,  80,  83);
    expect_range("score right b", 2'd3,  96,  99);
    expect_range("score right c", 2'd3, 128, 131);

    // ================= player position, copies, size =================
    wait_h(8'd10);
    clear_all;
    tia_wr(6'h1B, 8'hFF);                         // GRP0
    tia_wr_at(8'd98, 6'h10, 8'h00);               // RESP0 written at hcount 98: takes effect at 99 -> pos 99-68+5 = 36
    settle;
    expect_range("p0 single", 2'd2, 36, 43);
    expect_nz("p0 single count", 8);

    tia_wr(6'h04, 8'h01); settle;                 // two copies close
    expect_range("p0 copy1", 2'd2, 36, 43);
    expect_range("p0 copy2", 2'd2, 52, 59);
    expect_nz("p0 close count", 16);

    tia_wr(6'h04, 8'h02); settle;                 // two copies medium
    expect_range("p0 med 1", 2'd2, 36, 43);
    expect_range("p0 med 2", 2'd2, 68, 75);
    expect_nz("p0 medium count", 16);

    tia_wr(6'h04, 8'h03); settle;                 // three copies close
    expect_range("p0 c3 a", 2'd2, 36, 43);
    expect_range("p0 c3 b", 2'd2, 52, 59);
    expect_range("p0 c3 c", 2'd2, 68, 75);
    expect_nz("p0 3close count", 24);

    tia_wr(6'h04, 8'h04); settle;                 // two copies wide
    expect_range("p0 wide 1", 2'd2, 36, 43);
    expect_range("p0 wide 2", 2'd2, 100, 107);
    expect_nz("p0 wide count", 16);

    tia_wr(6'h04, 8'h06); settle;                 // three copies medium
    expect_range("p0 m3 a", 2'd2, 36, 43);
    expect_range("p0 m3 b", 2'd2, 68, 75);
    expect_range("p0 m3 c", 2'd2, 100, 107);
    expect_nz("p0 3med count", 24);

    tia_wr(6'h04, 8'h05); settle;                 // double size
    expect_range("p0 double", 2'd2, 37, 52);          // stretched players start 1 pixel later
    expect_nz("p0 double count", 16);

    tia_wr(6'h04, 8'h07); settle;                 // quad size
    expect_range("p0 quad", 2'd2, 37, 68);
    expect_nz("p0 quad count", 32);

    tia_wr(6'h04, 8'h00);                         // reflection
    tia_wr(6'h1B, 8'h80); settle;
    expect_range("grp 80 normal", 2'd2, 36, 36);
    expect_nz("grp 80 count", 1);
    tia_wr(6'h0B, 8'h08); settle;
    expect_range("grp 80 reflect", 2'd2, 43, 43);
    expect_nz("grp 80 refl count", 1);
    tia_wr(6'h0B, 8'h00);

    // ================= stretched players start one pixel later ========
    // Same RESPx strobe for every NUSIZ: sizes 5 (double) and 7 (quad) begin at 37,
    // every other size at 36.  Missiles keep their place whatever the player size.
    begin : nusiz_start
      integer ns, pl, j, first, run, exp_first, exp_run;
      for (pl = 0; pl < 2; pl = pl + 1) begin
        wait_h(8'd10);
        clear_all;
        tia_wr(pl ? 6'h1C : 6'h1B, 8'hFF);                    // GRP1 / GRP0
        tia_wr_at(8'd98, pl ? 6'h11 : 6'h10, 8'h00);          // RESP1 / RESP0 -> pos 36
        for (ns = 0; ns < 8; ns = ns + 1) begin
          tia_wr(pl ? 6'h05 : 6'h04, ns);                     // NUSIZ1 / NUSIZ0
          settle;
          first = -1; run = 0;
          for (j = 0; j < 160; j = j + 1)
            if (lb_vis[j] === 1'b1 && lb_src[j] === (pl ? 2'd3 : 2'd2)) begin
              if (first < 0) first = j;
              if (j == first + run) run = run + 1;
            end
          exp_first = (ns == 5 || ns == 7) ? 37 : 36;
          exp_run   = (ns == 5) ? 16 : (ns == 7) ? 32 : 8;
          if (first != exp_first || run != exp_run) begin
            errs = errs + 1;
            $display("FAIL  player %0d NUSIZ %0d: starts at %0d, %0d wide (expected %0d, %0d)", pl, ns, first, run, exp_first, exp_run);
          end
        end
      end
      $display("ok    players: NUSIZ 5 and 7 start at 37, the other six sizes at 36");
      // missile 0 with the player at double size: still at 35
      wait_h(8'd10);
      clear_all;
      tia_wr(6'h1D, 8'h02);                                   // ENAM0
      tia_wr_at(8'd98, 6'h12, 8'h00);                         // RESM0 -> pos 35
      tia_wr(6'h04, 8'h05); settle;
      first = -1;
      for (j = 0; j < 160; j = j + 1) if (first < 0 && lb_vis[j] === 1'b1 && lb_src[j] === 2'd2) first = j;
      tia_wr(6'h04, 8'h00); settle;
      run = -1;
      for (j = 0; j < 160; j = j + 1) if (run < 0 && lb_vis[j] === 1'b1 && lb_src[j] === 2'd2) run = j;
      if (first != 35 || run != 35) begin errs = errs + 1; $display("FAIL  missile 0 at %0d (NUSIZ 5) / %0d (NUSIZ 0), expected 35", first, run); end
      else $display("ok    missile 0 stays at 35 with the player at double size");
      tia_wr(6'h1D, 8'h00);
      wait_h(8'd10);
      clear_all;
      tia_wr(6'h1B, 8'hFF);
      tia_wr_at(8'd98, 6'h10, 8'h00);                         // back to the state the HMOVE test expects
      settle;
    end

    // ================= HMOVE =========================================
    tia_wr(6'h1B, 8'hFF);
    tia_wr(6'h20, 8'h70);                         // HMP0: move left 7
    wait_h(8'd2); tia_wr_at(8'd5, 6'h2A, 8'h00);  // HMOVE strobed early in HBLANK
    wait_h(8'd20); wait_h(8'd10);                 // buffer = the HMOVE line
    expect_range("hmove p0", 2'd2, 29, 36);
    expect_nz("hmove count", 8);
    begin : bar
      integer j, blanks;
      blanks = 0;
      for (j = 0; j < 8; j = j + 1) if (lb_vis[j] === 1'b0) blanks = blanks + 1;
      if (blanks != 8) begin errs = errs + 1; $display("FAIL  hmove bar: %0d/8 blanked", blanks); end
    end
    wait_h(8'd20); wait_h(8'd10);                 // next line: no bar, same position
    expect_range("hmove next line", 2'd2, 29, 36);
    expect_range("no bar after", 2'd2, 29, 36);
    if (lb_vis[0] !== 1'b1) begin errs = errs + 1; $display("FAIL  bar still present on the next line"); end

    tia_wr(6'h20, 8'h80);                         // move right 8
    wait_h(8'd2); tia_wr_at(8'd5, 6'h2A, 8'h00);
    wait_h(8'd20); wait_h(8'd10);
    expect_range("hmove right", 2'd2, 37, 44);

    // ================= missile + ball, priority ======================
    wait_h(8'd10);
    clear_all;
    tia_wr(6'h1D, 8'h02);                         // ENAM0
    tia_wr(6'h1F, 8'h02);                         // ENABL
    tia_wr(6'h04, 8'h20);                         // missile width 4
    tia_wr(6'h0A, 8'h20);                         // ball width 4, PF priority off
    tia_wr_at(8'd98,  6'h12, 8'h00);              // RESM0: 99-68+4 = 35
    tia_wr_at(8'd101, 6'h14, 8'h00);              // RESBL: 102-68+4 = 38
    settle;
    expect_range("m0", 2'd2, 35, 38);
    expect_range("ball behind", 2'd1, 39, 41);
    expect_nz("m0+ball count", 7);

    tia_wr(6'h0A, 8'h24);                         // PF/ball priority on
    settle;
    expect_range("m0 under", 2'd2, 35, 37);
    expect_range("ball over", 2'd1, 38, 41);
    expect_nz("priority count", 7);

    // ================= collisions ====================================
    wait_h(8'd10);
    clear_all;
    tia_wr(6'h1B, 8'hFF);
    tia_wr(6'h0D, 8'h10);                         // PF0: x 0..3
    tia_wr_at(8'd50, 6'h10, 8'h00);               // RESP0 inside HBLANK: pos 3
    tia_wr(6'h2C, 8'h00);                         // CXCLR
    settle;
    tia_rd(6'h02, v); expect8("CXP0FB", v, 8'h80);
    tia_rd(6'h03, v); expect8("CXP1FB", v, 8'h00);
    tia_rd(6'h00, v); expect8("CXM0P",  v, 8'h00);
    tia_rd(6'h06, v); expect8("CXBLPF", v, 8'h00);
    tia_wr(6'h2C, 8'h00);
    tia_rd(6'h02, v); expect8("CXP0FB after CXCLR", v, 8'h00);

    // ================= vertical delay ================================
    wait_h(8'd10);
    tia_wr(6'h0D, 8'h00);
    tia_wr(6'h1B, 8'hFF);                         // GRP0
    tia_wr(6'h1C, 8'h00);                         // GRP1 -> copies GRP0 to old GRP0
    tia_wr(6'h1B, 8'h00);                         // GRP0 = 0
    tia_wr(6'h25, 8'h01);                         // VDELP0
    settle;
    expect_range("vdelp0 old gfx", 2'd2, 3, 10);
    expect_nz("vdelp0 count", 8);
    tia_wr(6'h25, 8'h00);
    settle;
    expect_nz("vdelp0 off count", 0);

    // ================= WSYNC =========================================
    wait_h(8'd40);
    if (rdy !== 1'b1) begin errs = errs + 1; $display("FAIL  rdy low before WSYNC"); end
    tia_wr_at(8'd50, 6'h02, 8'h00);
    if (rdy !== 1'b0) begin errs = errs + 1; $display("FAIL  rdy not low after WSYNC"); end
    wait_h(8'd227);
    if (rdy !== 1'b0) begin errs = errs + 1; $display("FAIL  rdy released early"); end
    @(negedge clk);
    if (hcount !== 8'd0 || rdy !== 1'b1) begin errs = errs + 1; $display("FAIL  rdy not released at line start"); end

    // ================= fire buttons ==================================
    inpt4 = 1; tia_rd(6'h0C, v); expect8("INPT4 released", v, 8'h80);
    inpt4 = 0; tia_rd(6'h0C, v); expect8("INPT4 pressed",  v, 8'h00);
    inpt4 = 1;

    // ================= VBLANK ========================================
    wait_h(8'd10);
    tia_wr(6'h01, 8'h02);
    settle;
    begin : vb
      integer j, vis;
      vis = 0;
      for (j = 0; j < 160; j = j + 1) if (lb_vis[j] === 1'b1) vis = vis + 1;
      if (vis != 0) begin errs = errs + 1; $display("FAIL  VBLANK: %0d visible pixels", vis); end
    end
    tia_wr(6'h01, 8'h00);

    if (errs == 0) $display("PASS  tia");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end

  initial begin
    #50000000;
    $display("FAIL  global timeout");
    $finish;
  end
endmodule
