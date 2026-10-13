#!/usr/bin/env python3
"""Horizontal offset of the players against the emulator, by player size (NUSIZ).
usage: nusiz_study.py TB_TRACE_EXE [label]
Runs six games in the ALE and in the given tb_trace build, and for every line where a
player has exactly the same shape in both, records core minus emulator in pixels, split
into normal width (NUSIZ 0-4, 6), double (5) and quad (7)."""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from a26lib import *
from ale_py import ALEInterface, Action

# game: (frames, (ALE action, SWCHA value, fire, from frame) or None)
GAMES = collections.OrderedDict([
    ("riverraid", ([200, 330, 420, 520], (Action.FIRE, 0xFF, True, 100))),
    ("enduro",    ([200, 400], None)),
    ("pitfall",   ([100, 160, 220], (Action.RIGHT, 0x7F, False, 110))),
    ("pacman",    ([200, 400, 600], None)),
    ("boxing",    ([200, 400], None)),
    ("frostbite", ([200, 400], None)),
])
CLASS = {5: "double (5)", 7: "quad (7)"}

def mask_shift(me, mc):
    n = int(mc.sum())
    if n < 3 or abs(int(me.sum()) - n) > max(2, n // 4): return None
    best = None
    for s in range(-8, 9):
        sh = np.zeros_like(me)
        if s >= 0: sh[s:] = me[:160 - s]
        else:      sh[:s] = me[-s:]
        mm = int(np.logical_xor(sh, mc).sum())
        if best is None or mm < best[0] or (mm == best[0] and abs(s) < abs(best[1])): best = (mm, s)
    return best[1] if best[0] == 0 else None

def main():
    exe = sys.argv[1]
    label = sys.argv[2] if len(sys.argv) > 2 else os.path.basename(os.path.dirname(exe))
    out = os.path.join(ROOT, "out", "nusiz", label)
    os.makedirs(out, exist_ok=True)
    H = collections.defaultdict(collections.Counter)
    for game, (frames, joy) in GAMES.items():
        ale = ALEInterface()
        ale.setInt("random_seed", 0); ale.setFloat("repeat_action_probability", 0.0); ale.setInt("frame_skip", 1)
        ale.loadROM(os.path.join(ROOT, "roms", game + ".a26"))
        pre = ale.getFrameNumber(); emu = {}
        for n in range(1, max(frames) + 1):
            ale.act(joy[0] if joy and n >= joy[3] else Action.NOOP)
            if n in frames: emu[n] = (ale.getScreen() >> 1).astype(np.uint8)
        hexf = os.path.join(ROOT, "build", game + ".hex")
        mapper = rom_to_hex(os.path.join(ROOT, "roms", game + ".a26"), hexf)
        off = ALE_RESET_FRAMES[1] + pre
        groups = [frames[i:i + 3] for i in range(0, len(frames), 3)]
        for grp in groups:
            fs = (grp + [grp[-1]] * 3)[:3]
            cmd = [exe, "+rom=" + hexf, "+mapper=%d" % mapper, "+out=" + os.path.join(out, game),
                   "+rst0=%d" % ALE_RESET_FRAMES[0], "+rst1=%d" % ALE_RESET_FRAMES[1]] + ["+f%d=%d" % (i, f + off) for i, f in enumerate(fs)]
            if joy:
                cmd += ["+joy0=%d" % (joy[3] + off), "+joy1=100000", "+joyv=%d" % joy[1]]
                if joy[2]: cmd += ["+fire=%d" % (joy[3] + off)]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0: raise SystemExit(r.stdout + r.stderr)
            for n in grp:
                t = np.array([np.frombuffer(bytes.fromhex(l.split()[1]), np.uint8).reshape(160, 8)
                              for l in open("%s_%d.tr" % (os.path.join(out, game), n + off))])
                E = emu[n]
                src = t[:, :, 0] >> 4; vis = (t[:, :, 0] & 1) != 0
                T = np.where(vis, t[:, :, 1], 0)
                best = (-1, 0)
                for dy in range(-10, 70):
                    ys = [y for y in range(T.shape[0]) if 0 <= y - dy < 210]
                    if len(ys) < 60: continue
                    eq = np.mean([np.mean(T[y] == E[y - dy]) for y in ys])
                    if eq > best[0]: best = (eq, dy)
                dy = best[1]
                for y in range(T.shape[0]):
                    r_ = y - dy
                    if not (0 <= r_ < 210): continue
                    for k in (0, 1):
                        mc = (src[y] == k + 2) & vis[y]
                        if mc.sum() < 3: continue
                        cols = np.unique(T[y][mc])
                        if len(cols) != 1: continue
                        c = cols[0]
                        if ((T[y] == c) & ~mc).any(): continue          # colour shared with something else
                        s = mask_shift(E[r_] == c, mc)
                        if s is None: continue
                        ns = int(t[y, np.nonzero(mc)[0][0], 6 + k]) & 7
                        H[(game, CLASS.get(ns, "normal"))][s] += 1
                        H[("ALL", CLASS.get(ns, "normal"))][s] += 1
    print("== %s: core minus emulator, pixels (lines where the player has the same shape in both)" % label)
    for game in list(GAMES) + ["ALL"]:
        for cl in ("normal", "double (5)", "quad (7)"):
            h = H.get((game, cl))
            if not h: continue
            print("   %-10s %-11s %s" % (game, cl, ", ".join("%+d: %d" % (s, c) for s, c in sorted(h.items()))))

main()
