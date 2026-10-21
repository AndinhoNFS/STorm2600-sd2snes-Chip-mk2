// SPDX-License-Identifier: GPL-2.0-or-later
// tb_a26_tdict.v -- self-checking test for a26_tdict.v alone.
//
// Feeds tile words the way a26_vidwr does (one scan line of a tile row at a time, table
// words in between) into a sink that is often busy, and checks:
//   * exactly 512 distinct tiles (tile 0 included) are accepted, header = 512
//   * 513 distinct tiles: eng_ovf, the frame is acknowledged but nothing is claimed
//   * tiles that differ in a single bit of a single word get different numbers
//     (the compare is exact, whatever the hash does), equal tiles get the same number
//   * table words pass through untouched and in order, ahead of the dictionary's words
//   * a frame of 3 lines: lines that were not written are zero, the other map rows are 0
//   * eng_ack only moves when the sink reports idle
//
// run:  iverilog -g2005 -Wall -o tb_tdict tb_a26_tdict.v a26_tdict.v && vvp tb_tdict
`timescale 1ns / 1ps

module tb_a26_tdict;
  reg clk = 0, rst = 1;
  always #5 clk = ~clk;

  reg         v_wr = 0;
  reg  [15:0] v_waddr = 0, v_wdata = 0;
  reg         ev_row = 0, ev_end = 0;
  reg  [7:0]  end_lines = 0;
  wire        eng_ack, eng_ovf, m_wr;
  wire [9:0]  tile_n;
  wire [15:0] m_waddr, m_wdata;
  reg         fifo_low = 1, wr_idle = 1;

  a26_tdict dut (.clk(clk), .rst(rst),
                 .v_wr(v_wr), .v_waddr(v_waddr), .v_wdata(v_wdata),
                 .ev_row(ev_row), .ev_end(ev_end), .end_lines(end_lines),
                 .eng_ack(eng_ack), .eng_ovf(eng_ovf), .tile_n(tile_n),
                 .m_wr(m_wr), .m_waddr(m_waddr), .m_wdata(m_wdata),
                 .fifo_low(fifo_low), .wr_idle(wr_idle));

  // the sink: busy two clocks out of three when `slow`, and "idle" only some clocks after
  // the last word
  reg        slow = 0;
  reg [7:0]  lfsr = 8'h5A;
  integer    since = 0, early_ack = 0, n_wr = 0, tbl_seen = 0, tbl_bad = 0;
  reg [15:0] mem [0:65535];
  reg        ack_d = 0;
  always @(posedge clk) begin
    lfsr     <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    fifo_low <= slow ? (lfsr[1:0] == 2'b00) : 1'b1;
    since    <= m_wr ? 0 : since + 1;
    wr_idle  <= (since > 40);
    ack_d    <= eng_ack;
    if (eng_ack != ack_d && since < 40) early_ack = early_ack + 1;
    if (m_wr) begin
      mem[m_waddr] <= m_wdata; n_wr = n_wr + 1;
      if (m_waddr[13]) begin                       // table words: value = running number
        if (m_wdata !== tbl_seen[15:0]) tbl_bad = tbl_bad + 1;
        tbl_seen = tbl_seen + 1;
      end
    end
  end

  integer errs = 0, mode = 0, tbl_sent = 0;
  integer i, r, c, l, k;

  // tile id of position (r, c): mode 0 -> 511 different non-zero tiles + zero tiles;
  // mode 1 -> 512 different non-zero tiles + zero tiles; mode 2 -> near-identical tiles
  function integer tid; input integer r; input integer c;
    integer p;
    begin
      p = r * 32 + c;
      if (mode == 2) tid = (p % 7 == 0) ? 0 : 1 + (p % 129);
      else if (p % 5 == 4) tid = 0;                                 // zero tile, 179 of them
      else tid = 1 + (((p - p / 5) * 37) % (mode == 0 ? 511 : 512));    // p - p/5 = non-zero tiles so far
    end
  endfunction

  // word l of tile id k.  mode 2: tile k differs from tile 1 in one bit only (128 variants)
  function [15:0] tword; input integer k; input integer l;
    reg [31:0] v;
    begin
      if (k == 0) tword = 16'h0000;
      else if (mode == 2) begin
        tword = 16'hA5C3 ^ (l * 16'h1111);
        if (k >= 2 && ((k - 2) >> 4) == l) tword = tword ^ (16'h0001 << ((k - 2) & 15));
      end else begin
        v = k * 2654435761 + l * 40503; v = v ^ (v >> 15);
        tword = (l == 3) ? k[15:0] : v[15:0];          // word 3 = the id: all tiles differ
      end
    end
  endfunction

  task tile_wr; input [1:0] b; input integer r; input integer c; input integer l; input [15:0] d;
    begin
      @(negedge clk); v_waddr = {b, 1'b0, r[4:0], c[4:0], l[2:0]}; v_wdata = d; v_wr = 1;
      @(negedge clk); v_wr = 0;
      repeat (3) @(negedge clk);
    end
  endtask

  task tbl_wr; input [1:0] b;
    begin
      @(negedge clk); v_waddr = {b, 3'b100, tbl_sent[10:0]}; v_wdata = tbl_sent[15:0]; v_wr = 1;
      @(negedge clk); v_wr = 0; tbl_sent = tbl_sent + 1;
      repeat (2) @(negedge clk);
    end
  endtask

  // a whole frame of nlines scan lines into buffer b; a tile row every `gap` clk at least
  task frame; input [1:0] b; input integer nlines; input integer gap;
    integer y;
    begin
      for (y = 0; y < nlines; y = y + 1) begin
        r = y >> 3; l = y & 7;
        for (c = 0; c < 32; c = c + 1) begin
          tile_wr(b, r, c, l, tword(tid(r, c), l));
          if (c % 4 == 1) tbl_wr(b);
        end
        if (l == 7) begin ev_row = ~ev_row; repeat (gap) @(negedge clk); end
      end
      end_lines = nlines; ev_end = ~ev_end;
      i = 0;
      while (eng_ack !== ev_end && i < 4000000) begin @(negedge clk); i = i + 1; end
      if (eng_ack !== ev_end) begin errs = errs + 1; $display("FAIL  no acknowledge"); end
      repeat (20) @(negedge clk);
    end
  endtask

  // rebuild the frame from header + map + list and compare; nd = expected distinct tiles
  // nd = distinct tiles expected (-1: whatever the brute-force count below says)
  reg [127:0] seen [0:1023];
  reg [127:0] tv;
  task check; input [1:0] b; input integer nlines; input integer nd; input [8*40-1:0] nm;
    integer base, bad, mx, e, y, ns, j, hit;
    begin
      base = b * 16384; bad = 0; mx = 0;
      // brute force: distinct tiles as written (unwritten lines = zero), zero tile first
      seen[0] = 128'd0; ns = 1;
      for (r = 0; r < 29; r = r + 1)
        for (c = 0; c < 32; c = c + 1) begin
          tv = 128'd0;
          for (l = 0; l < 8; l = l + 1) if (r * 8 + l < nlines) tv[l * 16 +: 16] = tword(tid(r, c), l);
          hit = 0;
          for (j = 0; j < ns; j = j + 1) if (seen[j] === tv) hit = 1;
          if (!hit) begin seen[ns] = tv; ns = ns + 1; end
        end
      if (nd >= 0 && ns !== nd) begin bad = bad + 1; $display("      (test pattern has %0d distinct tiles, wanted %0d)", ns, nd); end
      nd = ns;
      for (r = 0; r < 29; r = r + 1)
        for (c = 0; c < 32; c = c + 1) begin
          e = mem[base + 8 + r * 32 + c];
          if (e > mx + 1) bad = bad + 1;
          if (e > mx) mx = e;
          for (l = 0; l < 8; l = l + 1) begin
            y = r * 8 + l;
            if (mem[base + 16'h0400 + e * 8 + l] !== ((y < nlines) ? tword(tid(r, c), l) : 16'h0000)) bad = bad + 1;
          end
          if ((r * 8 >= nlines) && e !== 0) bad = bad + 1;
        end
      if (mem[base] !== nd || mx + 1 !== nd || tile_n !== nd) bad = bad + 1;
      for (l = 1; l < 8; l = l + 1) if (mem[base + l] !== 16'h0000) bad = bad + 1;
      if (bad != 0 || eng_ovf !== 1'b0) begin
        errs = errs + 1; $display("FAIL  %0s: %0d errors, header %0d, largest number %0d, ovf %0d", nm, bad, mem[base], mx, eng_ovf);
      end else $display("ok    %0s: frame rebuilt exactly, %0d distinct tiles", nm, nd);
    end
  endtask

  initial begin
    for (i = 0; i < 65536; i = i + 1) mem[i] = 16'hDEAD;
    repeat (5) @(negedge clk);
    rst = 0;
    repeat (1200) @(negedge clk);                 // the first clearing of the hash table

    mode = 0; frame(2'd1, 232, 3000);
    check(2'd1, 232, 512, "512 distinct tiles (full dictionary)");

    mode = 1; frame(2'd2, 232, 3000);
    if (eng_ovf !== 1'b1) begin errs = errs + 1; $display("FAIL  513 distinct tiles: no overflow"); end
    else $display("ok    513 distinct tiles: overflow flagged, frame acknowledged");

    mode = 2; frame(2'd0, 232, 3000);
    check(2'd0, 232, 130, "tiles one bit apart (after an overflow)");

    slow = 1;
    mode = 0; frame(2'd2, 232, 9000);
    check(2'd2, 232, 512, "512 tiles, sink busy 3 clocks out of 4");
    mode = 2; frame(2'd1, 3, 3000);               // 3 lines: a partial first row only
    check(2'd1, 3, -1, "frame of 3 lines");
    slow = 0;

    if (tbl_seen != tbl_sent || tbl_bad != 0) begin
      errs = errs + 1; $display("FAIL  table words: %0d sent, %0d seen, %0d out of order", tbl_sent, tbl_seen, tbl_bad);
    end else $display("ok    %0d table words passed through in order", tbl_seen);
    if (early_ack != 0) begin errs = errs + 1; $display("FAIL  acknowledge while words were still going out: %0d", early_ack); end
    else $display("ok    acknowledge only after the sink went idle");

    if (errs == 0) $display("PASS  a26_tdict");
    else           $display("FAILED  %0d error(s)", errs);
    $finish;
  end

  initial begin
    #2000000000;
    $display("FAIL  global timeout");
    $finish;
  end
endmodule
