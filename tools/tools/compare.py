#!/usr/bin/env python3
"""Compare emulator and core frames already captured by emu_frame.py / core_frame.py.
usage: compare.py OUT_PREFIX N [N ...]
Writes OUT_PREFIX_<N>_side.png (emulator | core | where they differ) and prints a report."""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from a26lib import *

def load_pal(out):
    pal = ntsc_palette()
    for ln in open(out + "_emu.meta"):
        p = ln.split()
        if p[0] == "pal":
            pal[int(p[1])] = [int(p[2]), int(p[3]), int(p[4])]
    return pal

def best_dy(E, C):
    best = (-1, 0)
    for dy in range(-60, 70):                      # core row y  <->  emulator row y - dy
        ys = [y for y in range(C.shape[0]) if 0 <= y - dy < E.shape[0]]
        if len(ys) < 100: continue
        eq = np.mean([np.mean(C[y] == E[y - dy]) for y in ys])
        if eq > best[0]: best = (eq, dy)
    return best

def mask_shift(me, mc):
    """shift s such that the emulator mask moved by s pixels equals the core mask best"""
    n = int(mc.sum())
    if n < 3 or abs(int(me.sum()) - n) > max(2, n // 4): return None
    best = None
    for s in range(-8, 9):
        sh = np.zeros_like(me)
        if s >= 0: sh[s:] = me[:160 - s]
        else:      sh[:s] = me[-s:]
        mm = int(np.logical_xor(sh, mc).sum())
        if best is None or mm < best[0]: best = (mm, s)
    return best[1] if best[0] <= max(1, n // 10) else None

def lead_black(row):
    n = 0
    while n < 160 and row[n] == 0: n += 1
    return n

def analyse(out, n, pal):
    E = ROM555[np.load("%s_%d_emu.npy" % (out, n))]          # emulator, in the SNES colours of the core's ROM
    meta, C, src, lp = read_fb("%s_%d_core.fb" % (out, n))
    eq, dy = best_dy(E, C)
    rep = []
    # the picture the SNES shows: 256 wide.  The emulator frame is put in columns 48..207 (black
    # outside) and compared row for row, with no vertical adjustment at all (row 0 = row 0)
    E256, C256 = place(E), meta["C256"]
    nr = min(E256.shape[0], C256.shape[0])
    e0 = np.mean(E256[:nr] == C256[:nr])
    top_e = next((r for r in range(E.shape[0]) if E[r].any()), None)
    top_c = next((y for y in range(C.shape[0]) if C[y].any()), None)
    rep.append("256 wide (1:1 in columns 48..207), no adjustment: %.2f%% of %d x 256 pixels equal; first non-black row: emulator %s, core %s; "
               "best vertical match is core row = emulator row %+d  => top difference %+d lines"
               % (100 * e0, nr, top_e, top_c, dy, dy))
    rows = [(y, y - dy) for y in range(C.shape[0]) if 0 <= y - dy < E.shape[0]]
    e_pic = [r for r in range(E.shape[0]) if E[r].any()]
    c_pic = [y for y in range(C.shape[0]) if C[y].any()]
    rep.append("vertical (160 wide from here on): core row y = emulator row y%+d (%.1f%% of the overlapping pixels equal)" % (-dy, 100 * eq))
    rep.append("lines: emulator window 210 rows, picture in rows %s; core captured %d rows (limit 224), picture in rows %s, "
               "%d scan lines per frame (%d colour clocks = %.0f us, %.2f Hz), first line with VBLANK off = line %d after the end of VSYNC"
               % ("%d..%d" % (e_pic[0], e_pic[-1]) if e_pic else "none", C.shape[0],
                  "%d..%d" % (c_pic[0], c_pic[-1]) if c_pic else "none", meta["scan_lines"], meta["cc_frame"],
                  meta["cc_frame"] / 3.579553, 3579553.0 / max(1, meta["cc_frame"]), meta["first_vis_line"]))
    cut_top = sum(1 for r in e_pic if r + dy < 0)
    cut_bot = sum(1 for r in e_pic if r + dy >= C.shape[0])
    rep.append("  emulator picture rows that fall outside the core buffer: %d above, %d below" % (cut_top, cut_bot))

    # horizontal position per colour source
    names = {1: "playfield/ball (COLUPF)", 2: "player 0 / missile 0 (COLUP0)", 3: "player 1 / missile 1 (COLUP1)"}
    for k in (1, 2, 3):
        h = collections.Counter()
        for y, r in rows:
            col = lp[y][k]
            if sum(1 for j in range(4) if lp[y][j] == col) != 1: continue        # colour shared: ambiguous
            s = mask_shift(E[r] == col, src[y] == k)
            if s is not None: h[s] += 1
        if h:
            tot = sum(h.values())
            rep.append("horizontal, %s: core minus emulator, pixels -> %s  (%d rows with an identical shape)"
                       % (names[k], ", ".join("%+d: %d rows" % (s, c) for s, c in sorted(h.items(), key=lambda t: -t[1])[:5]), tot))
        else:
            rep.append("horizontal, %s: no row with an identical shape in both" % names[k])

    # HMOVE bar
    eb = [(y, r) for y, r in rows if lead_black(E[r]) >= 8 and E[r, 8:].any()]
    cb_same = sum(1 for y, r in eb if lead_black(C[y]) >= 8)
    widths = collections.Counter(min(lead_black(E[r]), 16) for y, r in eb)
    rep.append("HMOVE bar: emulator shows a black left edge on %d rows (width: %s); the core frame buffer is black there on %d of them; "
               "the core's window table marks the bar on %d captured lines (map / list / table format errors: %d; %d distinct tiles; %d frames dropped so far)"
               % (len(eb), ", ".join("%d px: %d" % (w, c) for w, c in sorted(widths.items())) or "-", cb_same, meta["bar"], meta["format_errors"], meta["ntiles"], meta.get("dropped", 0)))

    # colours per line
    miss = []; many = 0
    for y, r in rows:
        es = set(int(v) for v in np.unique(E[r, 8:]))     # the first 8 columns are judged as the HMOVE bar
        if len(es) > 4: many += 1
        extra = es - set(int(v) for v in lp[y])
        if extra: miss.append((y, r, sorted(extra)))
    rep.append("colours (columns 8..159): %d of %d rows have a colour in the emulator that is not among the core's 4 for that row; "
               "%d emulator rows use more than 4 colours" % (len(miss), len(rows), many))
    # rows that differ, and whether a plain horizontal shift of the whole row explains it
    nd = 0; hs = collections.Counter()
    for y, r in rows:
        if not (E[r, 8:] != C[y, 8:]).any(): continue
        nd += 1
        for sft in (-3, -2, -1, 1, 2, 3):
            lo, hi = max(8, 8 + sft), min(160, 160 + sft)
            if not (E[r, lo - sft:hi - sft] != C[y, lo:hi]).any(): hs[sft] += 1; break
    rep.append("rows: %d of %d differ somewhere in columns 8..159; of those, identical after shifting the whole row: %s"
               % (nd, len(rows), ", ".join("%+d px: %d" % kv for kv in sorted(hs.items())) or "none"))
    if miss:
        runs = []; a = b = miss[0][0]
        for y, r, ex in miss[1:]:
            if y == b + 1: b = y
            else: runs.append((a, b)); a = b = y
        runs.append((a, b))
        rep.append("  core rows: " + ", ".join("%d..%d" % ab if ab[0] != ab[1] else "%d" % ab[0] for ab in runs[:12]) + (" ..." if len(runs) > 12 else ""))
    diffpal = sum(1 for y, r in rows if E[r, 80] != C[y, 80] and E[r, 80] in lp[y])

    # side by side: emulator | core (aligned) | difference
    H = max(E.shape[0] + max(dy, 0), C.shape[0] + max(-dy, 0))
    ey0, cy0 = max(dy, 0), max(-dy, 0)
    canvas = np.zeros((H, 160 * 3 + 16, 3), np.uint8); canvas[:] = (48, 0, 48)
    canvas[ey0:ey0 + E.shape[0], 0:160] = bgr_to_rgb(E)
    canvas[cy0:cy0 + C.shape[0], 168:328] = bgr_to_rgb(C)
    d = np.zeros((H, 160, 3), np.uint8)
    for y, r in rows:
        ne = E[r] != C[y]
        d[cy0 + y][ne] = (255, 40, 40)
        d[cy0 + y][~ne] = (bgr_to_rgb(C[y])[~ne] // 3)
    canvas[:, 336:496] = d
    Image.fromarray(canvas).resize((canvas.shape[1] * 2, H * 2), Image.NEAREST).save("%s_%d_side.png" % (out, n))
    to_png(C, pal, "%s_%d_core.png" % (out, n))
    return rep

def main():
    out, ns = sys.argv[1], [int(x) for x in sys.argv[2:]]
    pal = load_pal(out)
    for n in ns:
        print("== %s, frame %d" % (os.path.basename(out), n))
        for ln in analyse(out, n, pal): print("   " + ln)

main()
