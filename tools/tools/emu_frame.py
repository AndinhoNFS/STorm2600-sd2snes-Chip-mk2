#!/usr/bin/env python3
"""Run a .a26 in the ALE (Stella core, headless) and save frame N as a 160-pixel-wide PNG.
usage: emu_frame.py ROM.a26 OUT_PREFIX N [N ...]
Writes OUT_PREFIX_<N>_emu.png and OUT_PREFIX_<N>_emu.npy (7-bit colour indices, 210 x 160).
N counts frames after the ALE's own start-up (power-on, 60 idle frames, RESET, start actions)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from a26lib import *
from ale_py import ALEInterface, Action

def main():
    rom, out, ns = sys.argv[1], sys.argv[2], sorted(int(x) for x in sys.argv[3:])
    ale = ALEInterface()
    ale.setInt("random_seed", 0)
    ale.setFloat("repeat_action_probability", 0.0)
    ale.setInt("frame_skip", 1)
    ale.loadROM(rom)
    pre = ale.getFrameNumber()                 # frames of start actions the ALE already played
    pal = ntsc_palette()
    seen = {}
    for n in range(1, ns[-1] + 1):
        ale.act(Action.NOOP)
        if n in ns:
            s = ale.getScreen()                # 210 x 160, TIA colour value (even, 0..254)
            rgb = ale.getScreenRGB()
            idx = (s >> 1).astype(np.uint8)
            for v in np.unique(idx):
                yy, xx = np.argwhere(idx == v)[0]
                seen[int(v)] = [int(c) for c in rgb[yy, xx]]
            np.save("%s_%d_emu.npy" % (out, n), idx)
            np.save("%s_%d_emu_rgb.npy" % (out, n), rgb)
            Image.fromarray(rgb).save("%s_%d_emu.png" % (out, n))
    with open(out + "_emu.meta", "w") as f:
        f.write("pre %d\n" % pre)
        for v in sorted(seen):
            f.write("pal %d %d %d %d\n" % (v, *seen[v]))
    print("emulator: %s frames %s saved (start actions: %d frames)" % (os.path.basename(rom), ns, pre))

main()
