// SPDX-License-Identifier: GPL-2.0-or-later
//
// a26_vidwr.v -- turns the TIA pixel stream into a SNES-ready frame buffer.
//                Milestone 6; 160 columns 1:1, three buffers with a lock, fixed window.
//
// WHY THIS FORMAT
//   The FPGA cannot drive the TV: the SNES PPU draws everything, so the frame
//   has to reach VRAM.  Per frame the budget is a few KB, hence:
//     * 2 bits per pixel = which of the 4 colours of its line (normally the TIA source:
//       BK, PF, P0, P1; see COLOURS OF A LINE)
//     * 4 colours per line, already as SNES colours in HDMA table form
//   The pixels are written already in SNES 2bpp TILE format, 256 pixels wide
//   (the 160 TIA pixels 1:1 in columns 48..207), so the 65816 only has to start a DMA
//   from this buffer to VRAM, and point four HDMA channels (CGRAM) plus one for
//   the window at the tables: nothing is converted on the SNES side.
//
// MEMORY FORMAT (16-bit word writes, little endian; 3 buffers of 16384 words = $8000 bytes)
//   fb_waddr = { buffer[1:0], offset[13:0] } in words; byte offsets below are per buffer
//   tiles    : NOT written to the PSRAM as they leave here.  A tile word comes out as
//             fb_waddr = { buffer, 0, r[4:0], c[4:0], line[2:0] } (tile row r = y/8, tile c,
//             line y%8) and a26_tdict.v turns the stream into header + map + list of the
//             distinct tiles at +$0000..+$3FFF (see there).
//             word = { plane1 byte, plane0 byte } -> plane0 at the even byte, SNES 2bpp
//             (bit 7 = left); tile c = 6..25 holds TIA pixels 8(c-6)..8(c-6)+7, one column
//             each (no stretching); tiles 0..5 and 26..31 are written as zero
//   colour tables, ready for the SNES HDMA (CGADD, CGADD, CGDATA, CGDATA):
//             channel k (0 COLUBK, 1 COLUPF, 2 COLUP0, 3 COLUP1) at +$4000 + k*$400,
//             line L (0..223) is 4 bytes at +4*L:
//               word 0 = k | k<<8
//               word 1 = the SNES BGR555 colour of the TIA colour (bgr555 below),
//                        $0000 on a line with VBLANK (or VSYNC) on
//             entry L = 224 of every channel is black (word 1 = $0000)
//   window table +$5000 : line L is one word at +2*L = left | right<<8,
//             left = 48, right = 207 (the 160 columns of the picture); left = 56 when the
//             first 8 TIA pixels of the line were blanked (the HMOVE bar; the tiles hold
//             colour source 0 there); entry 224 = 0 | 255<<8
//   Entry 224 is rewritten every frame, one word per line on lines 0..8.
//   The four colours of a line are allocated as its pixels come (see below).  Per line the
//   writes are: 20 tile words on pixels 7, 15 .. 159 (tiles 6..25); 12 zero tile words on
//   pixels 5, 13 .. 93 (tiles 0..5 and 26..31); 9 table words on pixels 19, 35 .. 147:
//   the four index words and the window word of THIS line (pixels 19 .. 83), then the
//   four colour words of the PREVIOUS line (pixels 99 .. 147), whose colours are only
//   final at its pixel 159; on lines 0..8 one word of entry 224 on pixel 155.  The
//   colour words of the last line of the window go out on the line after it.
//
// FRAMING
//   Lines are numbered from the end of VSYNC, as Stella does: line 0 is the scan
//   line (HBLANK first) in which VSYNC goes low.  VSYNC is looked at on pixels 0
//   and 159 only: low on pixel 159 after high on pixel 0 means it fell during the
//   picture part, so the line that starts next is already line 1.  The buffer holds the MAXLINES lines from
//   line YS = YS0 + yofs on, whatever VBLANK does: a line with VBLANK on is written
//   as black (tiles 0, the four colours black).  yofs is taken when
//   VSYNC ends.  Without any VSYNC a frame is AUTO_LINES lines long.
//
// THREE BUFFERS (for the SNES side)
//   fb_newest : buffer holding the last COMPLETE frame
//   fb_frames : counts completed frames (wraps)
//   fb_nlines : lines written in that frame (MAXLINES when the window was complete)
//   A frame ends at the first line start after VSYNC rises (ev_end toggles, end_lines =
//   its lines).  It is published only when a26_tdict has written its last tile row
//   (eng_ack == ev_end), on the next pixel; if the dictionary overflowed (eng_ovf) the
//   frame is dropped instead: fb_newest stays and fb_dropped counts.  If the window of
//   the next frame starts while one is still waiting, that next frame is left out whole
//   (and counted in fb_dropped too).  ev_row toggles after the 8th line of
//   every tile row.  The buffer of the next
//   frame is only chosen when its first line is about to be written: any buffer that
//   is neither fb_newest nor the one locked by the SNES (lock_v, lock_i), preferring
//   the one that was not fb_newest before.  So a buffer the SNES locks right after
//   reading fb_newest is never written, even if a frame ended in between.
//
// COLOURS OF A LINE (Passo 26)
//   The four indices of a line start free at every line.  Each visible pixel, with its
//   final colour (pix_col, the register as it was when the TIA made the pixel), takes
//   the index that already holds that colour (its own source first, then the lowest);
//   else its own source's index if that one is still free; else the lowest free index;
//   the index then holds the colour for the rest of the line.  With all four taken and
//   none matching, the pixel keeps its source's index (colour lost).  So a colour
//   written anywhere in the line (Checkers' board, the POWER / OXYGEN bars of H.E.R.O.
//   and Seaquest) is kept as long as the line has at most four colours.
//
// LIMITS: a line with more than four colours loses the later ones.  An index never
// taken on a line keeps the colour of the line before.  The HMOVE bar is detected as
// "pixel 0 is blanked with VBLANK off".
//
// TIMING NOTE: everything here changes on pix_stb only (ucf.extra gives those paths
// 125 ns), except fb_wr, vsync_d and pub_pend.  What arrives at clock rate (vsync,
// pub_pend, the lock) only goes through a few gates before a register.
//
// STATUS: untested when written.  Verify with tb_a26_vidwr.v.
//
`timescale 1ns / 1ps

module a26_vidwr #(
  parameter       MAXLINES   = 224,
  parameter       AUTO_LINES = 320,
  parameter [8:0] YS0        = 9'd34      // first line of the window when yofs = 0
) (
  input             clk,
  input             rst,

  input             pix_stb,
  input      [7:0]  pix_x,
  input             pix_vis,
  input      [1:0]  pix_src,
  input      [6:0]  pix_col,          // final colour of the pixel (COLUxx[7:1] when it was made)
  input             vsync,
  input             vblank,
  input      [6:0]  colubk,           // colubk..colup1: not used since Passo 26 (colours come from pix_col)
  input      [6:0]  colupf,
  input      [6:0]  colup0,
  input      [6:0]  colup1,

  output reg        fb_wr,
  output reg [15:0] fb_waddr,
  output reg [15:0] fb_wdata,

  output reg [1:0]  fb_newest,
  output reg [7:0]  fb_frames,
  output reg [7:0]  fb_nlines,

  input             lock_v,           // the SNES is reading buffer lock_i: do not write it
  input      [1:0]  lock_i,
  input      [6:0]  yofs,             // signed, -16..+47: lines added to YS0

  // to / from a26_tdict
  output reg        ev_row,
  output reg        ev_end,
  output reg [7:0]  end_lines,
  input             eng_ack,
  input             eng_ovf,
  output reg [7:0]  fb_dropped        // frames dropped (dictionary full / not ready), saturates
);

  // VBLANK / VSYNC are looked at on pixel PAL_X, not at pixel 0: games
  // write COLUPx up to pixel 7 for the line being drawn (Pitfall at 4, River Raid at 7).
  localparam [7:0]  PAL_X   = 8'd16;

  // SNES BGR555 colour of a TIA colour (index = COLUxx[7:1] = hue<<3 | lum)
  function [14:0] bgr555;
    input [6:0] c;
    begin
      case (c)
        7'd0  : bgr555 = 15'h0000;
        7'd1  : bgr555 = 15'h14A5;
        7'd2  : bgr555 = 15'h294A;
        7'd3  : bgr555 = 15'h39CE;
        7'd4  : bgr555 = 15'h4E73;
        7'd5  : bgr555 = 15'h5EF7;
        7'd6  : bgr555 = 15'h6F7B;
        7'd7  : bgr555 = 15'h7FFF;
        7'd8  : bgr555 = 15'h0024;
        7'd9  : bgr555 = 15'h00C9;
        7'd10 : bgr555 = 15'h016D;
        7'd11 : bgr555 = 15'h01F2;
        7'd12 : bgr555 = 15'h1696;
        7'd13 : bgr555 = 15'h2B1A;
        7'd14 : bgr555 = 15'h3B9E;
        7'd15 : bgr555 = 15'h4FFF;
        7'd16 : bgr555 = 15'h0007;
        7'd17 : bgr555 = 15'h008C;
        7'd18 : bgr555 = 15'h0130;
        7'd19 : bgr555 = 15'h0DB4;
        7'd20 : bgr555 = 15'h2259;
        7'd21 : bgr555 = 15'h36DD;
        7'd22 : bgr555 = 15'h475F;
        7'd23 : bgr555 = 15'h57DF;
        7'd24 : bgr555 = 15'h0009;
        7'd25 : bgr555 = 15'h004D;
        7'd26 : bgr555 = 15'h10F2;
        7'd27 : bgr555 = 15'h2196;
        7'd28 : bgr555 = 15'h361A;
        7'd29 : bgr555 = 15'h469E;
        7'd30 : bgr555 = 15'h571F;
        7'd31 : bgr555 = 15'h679F;
        7'd32 : bgr555 = 15'h0009;
        7'd33 : bgr555 = 15'h142E;
        7'd34 : bgr555 = 15'h28D2;
        7'd35 : bgr555 = 15'h3956;
        7'd36 : bgr555 = 15'h4DFA;
        7'd37 : bgr555 = 15'h5E7E;
        7'd38 : bgr555 = 15'h6EFF;
        7'd39 : bgr555 = 15'h7F7F;
        7'd40 : bgr555 = 15'h1C08;
        7'd41 : bgr555 = 15'h2C0C;
        7'd42 : bgr555 = 15'h40B0;
        7'd43 : bgr555 = 15'h5155;
        7'd44 : bgr555 = 15'h61D9;
        7'd45 : bgr555 = 15'h727D;
        7'd46 : bgr555 = 15'h7EFF;
        7'd47 : bgr555 = 15'h7F7F;
        7'd48 : bgr555 = 15'h3004;
        7'd49 : bgr555 = 15'h4029;
        7'd50 : bgr555 = 15'h50CE;
        7'd51 : bgr555 = 15'h6572;
        7'd52 : bgr555 = 15'h75F6;
        7'd53 : bgr555 = 15'h7E7A;
        7'd54 : bgr555 = 15'h7EFE;
        7'd55 : bgr555 = 15'h7F7F;
        7'd56 : bgr555 = 15'h3800;
        7'd57 : bgr555 = 15'h4C65;
        7'd58 : bgr555 = 15'h5CEA;
        7'd59 : bgr555 = 15'h6D8E;
        7'd60 : bgr555 = 15'h7E13;
        7'd61 : bgr555 = 15'h7EB7;
        7'd62 : bgr555 = 15'h7F3B;
        7'd63 : bgr555 = 15'h7FBF;
        7'd64 : bgr555 = 15'h3800;
        7'd65 : bgr555 = 15'h48A1;
        7'd66 : bgr555 = 15'h5D26;
        7'd67 : bgr555 = 15'h6DCB;
        7'd68 : bgr555 = 15'h7E4F;
        7'd69 : bgr555 = 15'h7ED3;
        7'd70 : bgr555 = 15'h7F58;
        7'd71 : bgr555 = 15'h7FDC;
        7'd72 : bgr555 = 15'h2C40;
        7'd73 : bgr555 = 15'h40E0;
        7'd74 : bgr555 = 15'h5163;
        7'd75 : bgr555 = 15'h6208;
        7'd76 : bgr555 = 15'h728C;
        7'd77 : bgr555 = 15'h7F11;
        7'd78 : bgr555 = 15'h7F95;
        7'd79 : bgr555 = 15'h7FF9;
        7'd80 : bgr555 = 15'h1880;
        7'd81 : bgr555 = 15'h2D20;
        7'd82 : bgr555 = 15'h3DA1;
        7'd83 : bgr555 = 15'h5226;
        7'd84 : bgr555 = 15'h62CB;
        7'd85 : bgr555 = 15'h734F;
        7'd86 : bgr555 = 15'h7FD4;
        7'd87 : bgr555 = 15'h7FF8;
        7'd88 : bgr555 = 15'h00A0;
        7'd89 : bgr555 = 15'h1540;
        7'd90 : bgr555 = 15'h25C1;
        7'd91 : bgr555 = 15'h3A46;
        7'd92 : bgr555 = 15'h4AEB;
        7'd93 : bgr555 = 15'h5B6F;
        7'd94 : bgr555 = 15'h6BF4;
        7'd95 : bgr555 = 15'h7BF8;
        7'd96 : bgr555 = 15'h00A0;
        7'd97 : bgr555 = 15'h0140;
        7'd98 : bgr555 = 15'h0DC4;
        7'd99 : bgr555 = 15'h2268;
        7'd100: bgr555 = 15'h32ED;
        7'd101: bgr555 = 15'h4771;
        7'd102: bgr555 = 15'h57F5;
        7'd103: bgr555 = 15'h67FA;
        7'd104: bgr555 = 15'h00A0;
        7'd105: bgr555 = 15'h0122;
        7'd106: bgr555 = 15'h01C7;
        7'd107: bgr555 = 15'h0E4B;
        7'd108: bgr555 = 15'h22D0;
        7'd109: bgr555 = 15'h3354;
        7'd110: bgr555 = 15'h47D8;
        7'd111: bgr555 = 15'h57FC;
        7'd112: bgr555 = 15'h0061;
        7'd113: bgr555 = 15'h0106;
        7'd114: bgr555 = 15'h018B;
        7'd115: bgr555 = 15'h022F;
        7'd116: bgr555 = 15'h16B3;
        7'd117: bgr555 = 15'h2B37;
        7'd118: bgr555 = 15'h3BBB;
        7'd119: bgr555 = 15'h4FFF;
        7'd120: bgr555 = 15'h0025;
        7'd121: bgr555 = 15'h00CA;
        7'd122: bgr555 = 15'h014E;
        7'd123: bgr555 = 15'h05F2;
        7'd124: bgr555 = 15'h1A77;
        7'd125: bgr555 = 15'h2AFB;
        7'd126: bgr555 = 15'h3F7F;
        7'd127: bgr555 = 15'h4FFF;
      endcase
    end
  endfunction

  function [1:0] inc3;                // next buffer, modulo 3
    input [1:0] b;
    begin inc3 = (b == 2'd0) ? 2'd1 : (b == 2'd1) ? 2'd2 : 2'd0; end
  endfunction

  reg [7:0] y;                        // lines written so far in this frame
  reg [8:0] vl;                       // line number since the end of VSYNC
  reg [6:0] yofs_r;
  reg       cap, armed, vs_l, vs_e, pub_pend, vsync_d;   // vs_l / vs_e: VSYNC on pixel 0 / 159
  reg [1:0] wb, pb;                   // buffer being written; fb_newest before the last frame
  reg       pend;                     // a frame has ended and waits for the dictionary
  reg       skipf;                    // this frame could not start in time: it is left out whole
  reg       hmb;                      // pixel 0 of this line was blanked with VBLANK off (HMOVE bar)
  reg       blk;                      // VBLANK or VSYNC on at PAL_X: the line is black
  reg [6:0] sh0, sh1;
  reg [2:0] ph;                       // pixel within the group of 8
  reg [4:0] grp;                      // group 0..19 = tile column - 6
  reg [3:0] tj;                       // table word of this line: 0..8, 9 = the entry-MAXLINES slot
  reg [27:0] cl;                      // colours of indices 0, 1, 2, 3 (bits 27:21 .. 6:0) on this line
  reg        clv;                     // set on pixels PAL_X + 1 .. 159 (no longer read since Passo 26)

  // the pixel's index (COLOURS OF A LINE): c_eq = which indices hold the pixel's final colour
  wire [1:0] s_own = pix_vis ? pix_src : 2'b00;
  wire [3:0] c_eq  = {pix_col == cl[6:0], pix_col == cl[13:7], pix_col == cl[20:14], pix_col == cl[27:21]};
  // allocation of the four colours (COLOURS OF A LINE above): val = indices taken on this line;
  // the colour words of a line are written during the NEXT line, from the copy clp taken at pixel 159
  reg  [3:0] val;
  reg         capp, blkp;
  reg  [7:0]  yp;
  reg  [27:0] clp;
  wire [3:0] c_eqv   = c_eq & val;
  wire       s_hit   = |c_eqv;
  wire [1:0] s_hitix = c_eqv[s_own] ? s_own : c_eqv[0] ? 2'd0 : c_eqv[1] ? 2'd1 : c_eqv[2] ? 2'd2 : 2'd3;
  wire [1:0] s_free  = ~val[0] ? 2'd0 : ~val[1] ? 2'd1 : ~val[2] ? 2'd2 : 2'd3;
  wire       s_alloc = pix_vis & ~s_hit & ~(&val);
  wire [1:0] s_new   = ~val[s_own] ? s_own : s_free;
  wire [1:0] s       = ~pix_vis ? 2'd0 : s_hit ? s_hitix : s_alloc ? s_new : s_own;
  // the line's colours including the one this pixel allocates (copied to clp on pixel 159)
  wire [27:0] cl_fin = {(s_alloc && s_new == 2'd0) ? pix_col : cl[27:21], (s_alloc && s_new == 2'd1) ? pix_col : cl[20:14],
                        (s_alloc && s_new == 2'd2) ? pix_col : cl[13:7],  (s_alloc && s_new == 2'd3) ? pix_col : cl[6:0]};

  // ---- line start (pixel 0): frame boundary, line number, capture decision ---------
  wire       p0       = (pix_x == 8'd0);
  wire       vs_rise  = vsync & ~vsync_d;
  wire       ev_vend  = pub_pend | vs_rise;                 // VSYNC rose since the last line start
  wire       ev_fall  = (vs_l | ev_vend) & ~vsync;           // ... and is low again
  wire       fell_vis = vs_l & ~vs_e;                       // it fell before pixel 159: this is line 1
  wire       auto_ev  = (vl == AUTO_LINES - 1);
  wire       f_start  = ev_fall | auto_ev;
  wire       f_end    = ev_vend | auto_ev;
  wire [8:0] vl_inc   = vl + 9'd1;
  wire [8:0] ys       = YS0 + {{2{yofs_r[6]}}, yofs_r};
  wire       cap_want = armed & ~ev_vend & ~f_start & (vl_inc >= ys) & (y != MAXLINES);
  wire       cap_new  = cap_want & ~pend & ~skipf;

  // buffer for a new frame: not fb_newest, not the locked one, rather not the old fb_newest
  wire [1:0] c1 = inc3(fb_newest);
  wire [1:0] c2 = inc3(c1);
  wire [1:0] wb_new = (lock_v & (lock_i == c1)) ? c2
                    : (lock_v & (lock_i == c2)) ? c1
                    : (pb == c1)                ? c2 : c1;

  // ---- table words: one on pixel 8*g + 3 for g = 2, 4 .. 18 ---------------------------
  // word j = 0..7 is channel j/2, word j%2; j = 8 is the window word.  The tenth slot
  // (g = 19) carries word y of entry MAXLINES on lines 0..8.
  wire       tb_term = (tj == 4'd9);
  wire       tb_reg  = ~grp[0] & (grp != 5'd0) & ~tb_term;
  wire       tb_slot = (ph == 3'd3) & (tb_reg | ((grp == 5'd19) & tb_term & (y < 8'd9)));
  // ---- zero tile words: tiles 0..5 and 26..31, one on pixel 8*g + 5 for g = 0 .. 11 ------
  wire       z_slot  = (ph == 3'd5) & (grp < 5'd12);
  wire [4:0] z_col   = (grp < 5'd6) ? grp : grp + 5'd20;
  // table slots: tj 0..4 = index words of channels 0..3 and the window word (j = 0, 2, 4, 6, 8) of this line,
  // tj 5..8 = the colour words (j = 1, 3, 5, 7) of the previous line
  wire [3:0] tj_map  = (tj < 4'd5) ? {tj[2:0], 1'b0} : {tj[2:0] - 3'd5, 1'b1};
  wire [3:0] tb_j    = tb_term ? y[3:0] : tj_map;
  wire [1:0] tb_k    = tb_j[2:1];
  wire [7:0] tb_l    = tb_term ? MAXLINES : y;
  wire [6:0] tb_cp   = (tb_k == 2'd0) ? clp[27:21] : (tb_k == 2'd1) ? clp[20:14] : (tb_k == 2'd2) ? clp[13:7] : clp[6:0];
  wire [6:0] tb_c    = (tb_k == 2'd0) ? cl[27:21] : (tb_k == 2'd1) ? cl[20:14]
                     : (tb_k == 2'd2) ? cl[13:7]  : cl[6:0];

  always @(posedge clk) begin
    if (rst) begin
      fb_wr <= 1'b0; fb_waddr <= 16'd0; fb_wdata <= 16'd0;
      fb_newest <= 2'd0; fb_frames <= 8'd0; fb_nlines <= 8'd0;
      y <= 8'd0; vl <= 9'd0; yofs_r <= yofs; cap <= 1'b0; armed <= 1'b0; vs_l <= 1'b0; vs_e <= 1'b0;
      pub_pend <= 1'b0; vsync_d <= 1'b0; wb <= 2'd1; pb <= 2'd2;
      hmb <= 1'b0; blk <= 1'b0; sh0 <= 7'd0; sh1 <= 7'd0;
      ph <= 3'd0; grp <= 5'd0; tj <= 4'd0; cl <= 28'd0; clv <= 1'b0; val <= 4'd0; capp <= 1'b0; blkp <= 1'b0; yp <= 8'd0; clp <= 28'd0;
      ev_row <= 1'b0; ev_end <= 1'b0; end_lines <= 8'd0; pend <= 1'b0; skipf <= 1'b0; fb_dropped <= 8'd0;
    end else begin
      fb_wr   <= 1'b0;
      vsync_d <= vsync;
      if (vs_rise) pub_pend <= 1'b1;

      if (pix_stb) begin
        sh0 <= {sh0[5:0], s[0]};
        sh1 <= {sh1[5:0], s[1]};
        if (s_alloc) begin
          val[s_new] <= 1'b1;
          case (s_new)
            2'd0: cl[27:21] <= pix_col;
            2'd1: cl[20:14] <= pix_col;
            2'd2: cl[13:7]  <= pix_col;
            2'd3: cl[6:0]   <= pix_col;
          endcase
        end
        if (pix_x == PAL_X) begin
          blk <= vblank | vsync;
          clv <= 1'b1;
        end

        if (p0) begin
          pub_pend <= 1'b0;
          vs_l     <= vsync;
          hmb      <= ~pix_vis & ~vblank & ~vsync;
          cap      <= cap_new;
          vl       <= f_start ? {8'd0, ev_fall & fell_vis} : vl_inc;
          if (f_start)     begin armed <= 1'b1; yofs_r <= yofs; end
          else if (ev_vend) armed <= 1'b0;
          if (f_end) begin
            y <= 8'd0;
            if (y != 8'd0) begin                 // a frame with at least one line: hand it over
              pend      <= 1'b1;
              ev_end    <= ~ev_end;
              end_lines <= y;
            end
          end
          if (cap_new && y == 8'd0) wb <= wb_new;
          // the window starts while the last frame is still waiting for the dictionary:
          // this frame is left out whole (starting it later would shift the picture)
          if (f_start) skipf <= 1'b0;
          else if (cap_want && pend && !skipf) begin
            skipf <= 1'b1;
            if (fb_dropped != 8'hFF) fb_dropped <= fb_dropped + 8'd1;
          end
        end else if (pend && eng_ack == ev_end) begin
          pend <= 1'b0;                          // the dictionary is done with the frame
          if (eng_ovf) begin
            if (fb_dropped != 8'hFF) fb_dropped <= fb_dropped + 8'd1;
          end else begin
            fb_newest <= wb;
            pb        <= fb_newest;
            fb_frames <= fb_frames + 8'd1;
            fb_nlines <= end_lines;
          end
        end

        if (capp && tb_slot && !tb_term && tb_j[0]) begin      // colour word k of the PREVIOUS line
          fb_wr    <= 1'b1;
          fb_waddr <= {wb, 3'b100, tb_k, yp, 1'b1};
          fb_wdata <= blkp ? 16'h0000 : {1'b0, bgr555(tb_cp)};
        end
        // nothing is written on pixel 0, so the registered cap is enough from here on
        if (cap) begin
          if (tb_slot && (tb_term || !tb_j[0])) begin
            fb_wr <= 1'b1;
            if (tb_j[3]) begin                             // window: left | right << 8
              fb_waddr <= {wb, 6'b101000, tb_l};           // +$5000 + 2*L
              fb_wdata <= tb_term      ? {8'd255, 8'd0}
                        : (hmb & ~blk) ? {8'd207, 8'd56} : {8'd207, 8'd48};
            end else begin                                 // +$4000 + k*$400 + 4*L (+2)
              fb_waddr <= {wb, 3'b100, tb_k, tb_l, tb_j[0]};
              fb_wdata <= ~tb_j[0]       ? {6'd0, tb_k, 6'd0, tb_k}
                        : (tb_term | blk) ? 16'h0000
                        :                   {1'b0, bgr555(tb_c)};
            end
          end
          if (z_slot) begin                                // a tile outside the picture
            fb_wr    <= 1'b1;
            fb_waddr <= {wb, 1'b0, y[7:3], z_col, y[2:0]};
            fb_wdata <= 16'h0000;
          end
          if (ph == 3'd7) begin                            // 8 pixels, both planes
            fb_wr    <= 1'b1;
            fb_waddr <= {wb, 1'b0, y[7:3], grp + 5'd6, y[2:0]};
            fb_wdata <= {sh1, s[1], sh0, s[0]};
          end
        end

        // position within the line
        if (pix_x == 8'd159) begin
          vs_e <= vsync;
          clv <= 1'b0; val <= 4'd0;
          capp <= cap; yp <= y; clp <= cl_fin; blkp <= blk;
          ph <= 3'd0; grp <= 5'd0; tj <= 4'd0;
          if (cap) begin
            y <= y + 8'd1;
            if (y[2:0] == 3'd7) ev_row <= ~ev_row;
          end
        end else begin
          ph <= ph + 3'd1;
          if (ph == 3'd7) grp <= grp + 5'd1;
          if (ph == 3'd3 && tb_reg) tj <= tj + 4'd1;
        end
      end
    end
  end

endmodule
