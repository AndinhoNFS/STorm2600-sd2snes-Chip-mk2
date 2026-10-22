#!/usr/bin/env python3
"""Check the HDMA tables the core writes against its own per-pixel trace.
usage: check_hdma.py     (six games, one frame each, some with input)
For every line of the window: the four table colours must be the colour ROM applied to the
four TIA registers as the writer sampled them (pixel 16), or black on a line with VBLANK on;
word 0 must be k|k<<8; the window word is left | 207<<8 with left = 56 exactly on the lines
whose pixel 0 is blanked with VBLANK off (48 otherwise); entry 232 black, window 0..255; the
tiles must be the per-pixel trace, 1:1 in columns 48..207, and zero outside."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from a26lib import *

RUNS = [("pitfall", 228, ["+joy0=178", "+joy1=99999", "+joyv=127"]), ("riverraid", 268, []), ("enduro", 268, []),
        ("pacman", 284, []), ("boxing", 268, []), ("frostbite", 268, []), ("enduro", 368, ["+yofs=-16"]), ("pitfall", 268, ["+yofs=47"])]
out = os.path.join(ROOT, "out", "hdma"); os.makedirs(out, exist_ok=True)
bad_total = 0
for game, f, extra in RUNS:
    hexf = os.path.join(ROOT, "build", game + ".hex")
    mapper = rom_to_hex(os.path.join(ROOT, "roms", game + ".a26"), hexf)
    tag = game + (extra[0].replace("+yofs=", "_yofs") if extra and extra[0].startswith("+yofs") else "")
    pre = os.path.join(out, tag)
    r = subprocess.run([os.path.join(ROOT, "build", "obj_trace", "tb_trace"), "+rom=" + hexf, "+mapper=%d" % mapper,
                        "+out=" + pre, "+f0=%d" % f, "+rst0=60", "+rst1=68"] + extra, capture_output=True, text=True)
    if r.returncode != 0: raise SystemExit(r.stdout + r.stderr)
    t = np.array([np.frombuffer(bytes.fromhex(l.split()[1]), np.uint8).reshape(160, 8) for l in open("%s_%d.tr" % (pre, f))])
    meta, C, src, pal = read_fb("%s_%d.fb" % (pre, f))
    n = meta["nlines"]
    regs = t[:, 17, 2:6]                    # the writer reads the registers one clock after pixel 16 is generated
    blank = (t[:, 17, 0] & 1) == 0          # pixel 17 not visible = VBLANK on (the HMOVE bar ends at pixel 7)
    exp = np.where(blank[:, None], 0, ROM555[regs])
    col_bad = int((pal[:n] != exp[:n]).any(1).sum())
    blank0 = ((t[:, 0, 0] & 1) == 0) & ~blank
    w = np.array([int(x, 16) for x in open("%s_%d.fb" % (pre, f)).read().split("\n")[1:16385]], np.uint16)
    left = w[0x2800:0x2800 + n] & 0xFF
    win_bad = int((left != np.where(blank0[:n], BAR_LEFT, WIN_LEFT)).sum())
    tsrc = np.where(t[:, :, 0] & 1, t[:, :, 0] >> 4, 0)       # blanked pixels are colour source 0
    tile_bad = int((src[:n] != tsrc[:n]).any(1).sum())
    bad = col_bad + win_bad + tile_bad + meta["format_errors"]
    bad_total += bad
    print("%-16s frame %3d: %3d lines (%d with VBLANK on) | %3d tiles | tile lines wrong %d | colour lines wrong %d | window lines wrong %d (bar on %d) | format errors %d | distinct colours %d"
          % (tag, f, n, int(blank[:n].sum()), meta["ntiles"], tile_bad, col_bad, win_bad, meta["bar"], meta["format_errors"], len(np.unique(pal[:n]))))
    to_png(meta["C256"], None, os.path.join(out, "%s_%d.png" % (tag, f)))
print("TOTAL wrong: %d" % bad_total)
