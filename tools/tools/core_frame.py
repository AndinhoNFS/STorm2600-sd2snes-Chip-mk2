#!/usr/bin/env python3
"""Run a .a26 in the simulation of our core (a26_core + a26_vidwr, Verilator) and save the
frame buffer published at frame N as a 160-pixel-wide PNG.
usage: core_frame.py ROM.a26 OUT_PREFIX PRE N [N ...]
PRE = frames the emulator played before its frame 0 (after RESET); the RESET switch is held
during frames 60..67, as the ALE does.  Writes OUT_PREFIX_<N>_core.png / .fb."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from a26lib import *

def main():
    rom, out, pre, ns = sys.argv[1], sys.argv[2], int(sys.argv[3]), sorted(int(x) for x in sys.argv[4:])
    build = os.path.join(ROOT, "build")
    hexf = os.path.join(build, os.path.basename(out) + ".hex")
    mapper = rom_to_hex(rom, hexf)
    off = ALE_RESET_FRAMES[1] + pre
    fs = (ns + [ns[-1]] * 3)[:3]
    extra = [a for a in os.environ.get("TB_ARGS", "").split() if a]      # e.g. TB_ARGS="+yofs=-3"
    cmd = [os.path.join(build, "obj_dir", "tb_frames")] + extra + [ "+rom=" + hexf, "+mapper=%d" % mapper,
           "+out=" + out + "_raw", "+rst0=%d" % ALE_RESET_FRAMES[0], "+rst1=%d" % ALE_RESET_FRAMES[1]] + \
          ["+f%d=%d" % (i, f + off) for i, f in enumerate(fs)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(r.stdout + r.stderr)
    pal = ntsc_palette()
    for n in ns:
        raw = "%s_raw_%d.fb" % (out, n + off)
        fb = "%s_%d_core.fb" % (out, n)
        os.replace(raw, fb)
        meta, idx, src, lp = read_fb(fb)
        to_png(idx, pal, "%s_%d_core.png" % (out, n))
        to_png(meta["C256"], pal, "%s_%d_core256.png" % (out, n))
        print("core: frame %d (%d since power-on): %d lines written, %d scan lines per frame, %d colour clocks = %.0f us, first line with VBLANK off = %d"
              % (n, n + off, meta["nlines"], meta["scan_lines"], meta["cc_frame"], meta["cc_frame"] / 3.579553, meta["first_vis_line"]))

main()
