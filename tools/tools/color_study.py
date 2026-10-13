#!/usr/bin/env python3
"""Where should the four TIA colours of a line be sampled?  (study only, nothing here is in the core)
usage: color_study.py            runs the games below, prints the tables, writes out/colors/*
For every game the emulator (ALE) and the core (tb_trace: per-pixel trace of a frame, plus
the colour clock of every colour-register write) are run to the same frames; then each
sampling rule is applied to the core's own trace and judged against
  (a) the core's true per-pixel colour (what a perfect frame buffer would show), and
  (b) the emulator: is the colour the rule gives present on the emulator's row at all?"""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from a26lib import *
from ale_py import ALEInterface, Action

REG = ["COLUBK", "COLUPF", "COLUP0", "COLUP1"]
FIXED = [0, 1, 4, 8, 16, 32, 64, 80, 120, 159]
RULES = ["px%d" % p for p in FIXED] + ["first", "now"]
# game: (frames, joystick (ALE action, SWCHA value, from frame) or None)
GAMES = collections.OrderedDict([
    ("pitfall",   ([100, 160, 220], (Action.RIGHT, 0x7F, 110))),     # standing, then running right
    ("riverraid", ([200, 400], None)),
    ("enduro",    ([200, 400], None)),
    ("pacman",    ([200, 400], None)),
    ("boxing",    ([200, 400], None)),
    ("frostbite", ([200, 400], None)),
])
OUT = os.path.join(ROOT, "out", "colors")


def run_emu(game, frames, joy):
    ale = ALEInterface()
    ale.setInt("random_seed", 0)
    ale.setFloat("repeat_action_probability", 0.0)
    ale.setInt("frame_skip", 1)
    ale.loadROM(os.path.join(ROOT, "roms", game + ".a26"))
    pre = ale.getFrameNumber()
    res = {}
    for n in range(1, max(frames) + 1):
        ale.act(joy[0] if joy and n >= joy[2] else Action.NOOP)
        if n in frames:
            res[n] = ((ale.getScreen() >> 1).astype(np.uint8), ale.getScreenRGB().copy())
    return pre, res


def run_core(game, frames, joy, pre):
    build = os.path.join(ROOT, "build")
    hexf = os.path.join(build, game + ".hex")
    mapper = rom_to_hex(os.path.join(ROOT, "roms", game + ".a26"), hexf)
    off = ALE_RESET_FRAMES[1] + pre
    fs = sorted(frames)
    fs = (fs + [fs[-1]] * 3)[:3]
    outp = os.path.join(OUT, game)
    cmd = [os.path.join(build, "obj_trace", "tb_trace"), "+rom=" + hexf, "+mapper=%d" % mapper, "+out=" + outp,
           "+rst0=%d" % ALE_RESET_FRAMES[0], "+rst1=%d" % ALE_RESET_FRAMES[1], "+h0=%d" % (off + 30)]
    cmd += ["+f%d=%d" % (i, f + off) for i, f in enumerate(fs)]
    if joy:
        cmd += ["+joy0=%d" % (joy[2] + off), "+joy1=100000", "+joyv=%d" % joy[1]]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise SystemExit(r.stdout + r.stderr)
    tr = {}
    for n in frames:
        rows = []
        for ln in open("%s_%d.tr" % (outp, n + off)):
            y, h = ln.split()
            rows.append(np.frombuffer(bytes.fromhex(h), np.uint8).reshape(160, 8))
        # bytes per pixel: src<<4 | vis, drawn colour, COLUBK, COLUPF, COLUP0, COLUP1, NUSIZ0, NUSIZ1
        tr[n] = np.array(rows)
    hist = np.zeros((4, 228), np.int64)
    for ln in open(outp + ".hist"):
        a, c, v = ln.split()
        hist[int(a), int(c)] = int(v)
    return tr, hist


def best_dy(E, T):
    best = (-1, 0)
    for dy in range(-10, 70):
        ys = [y for y in range(T.shape[0]) if 0 <= y - dy < E.shape[0]]
        if len(ys) < 60:
            continue
        eq = np.mean([np.mean(T[y] == E[y - dy]) for y in ys])
        if eq > best[0]:
            best = (eq, dy)
    return best


def rule_palette(rule, src, vis, regs):
    """colour a rule would store for each line and register -> [lines, 4]"""
    L = src.shape[0]
    if rule.startswith("px"):
        return regs[:, int(rule[2:]), :].copy()
    pal = regs[:, 0, :].copy()                  # "first": the value when the object is first drawn,
    for y in range(L):                          # pixel 0 if the object is not on the line
        for k in range(4):
            xs = np.nonzero((src[y] == k) & vis[y])[0]
            if len(xs):
                pal[y, k] = regs[y, xs[0], k]
    return pal


def main():
    os.makedirs(OUT, exist_ok=True)
    pal_rgb = ntsc_palette()
    stat = collections.defaultdict(lambda: np.zeros(3, np.int64))      # (game, rule, k) -> used, bad vs true, bad vs emu
    multi = collections.defaultdict(lambda: np.zeros(2, np.int64))     # (game, k) -> used, lines with >1 colour
    hists = {}
    notes = []
    for game, (frames, joy) in GAMES.items():
        pre, emu = run_emu(game, frames, joy)
        tr, hist = run_core(game, frames, joy, pre)
        hists[game] = hist
        for n in frames:
            t = tr[n]
            E, rgb = emu[n]
            for v in np.unique(E):
                yy, xx = np.argwhere(E == v)[0]
                pal_rgb[int(v)] = rgb[yy, xx]
            src = (t[:, :, 0] >> 4).astype(np.int64)
            vis = (t[:, :, 0] & 1) != 0
            T = np.where(vis, t[:, :, 1], 0).astype(np.uint8)      # true picture; blanked pixels are black
            regs = t[:, :, 2:6]
            L = T.shape[0]
            eq, dy = best_dy(E, T)
            notes.append("%-9s frame %3d: %3d lines, core row y = emulator row y%+d, true core picture equals the emulator on %.1f%% of the pixels"
                         % (game, n, L, -dy, 100 * eq))
            erow = [set(int(v) for v in np.unique(E[y - dy])) if 0 <= y - dy < E.shape[0] else None for y in range(L)]
            use = np.zeros((L, 4), bool)
            for y in range(L):
                for k in range(4):
                    m = (src[y, 8:] == k) & vis[y, 8:]
                    use[y, k] = m.any()
                    if use[y, k]:
                        multi[(game, k)][0] += 1
                        if len(np.unique(T[y, 8:][m])) > 1:
                            multi[(game, k)][1] += 1
            imgs = {}
            for rule in RULES:
                pal = None if rule == "now" else rule_palette(rule, src, vis, regs)
                R = T if rule == "now" else np.where(vis, np.take_along_axis(pal, src, 1), 0).astype(np.uint8)
                imgs[rule] = R
                for y in range(L):
                    for k in range(4):
                        if not use[y, k]:
                            continue
                        m = (src[y, 8:] == k) & vis[y, 8:]
                        s = stat[(game, rule, k)]
                        s[0] += 1
                        if (R[y, 8:][m] != T[y, 8:][m]).any():
                            s[1] += 1
                        if erow[y] is not None and not set(int(v) for v in np.unique(R[y, 8:][m])) <= erow[y]:
                            s[2] += 1
            # picture: emulator | true core | px1 (close to today) | px159 | first
            H = max(E.shape[0] + max(dy, 0), L + max(-dy, 0))
            show = [("emu", E, max(dy, 0))] + [(r, imgs[r], max(-dy, 0)) for r in ("now", "px1", "px159", "first")]
            canvas = np.zeros((H, 168 * len(show) - 8, 3), np.uint8)
            canvas[:] = (48, 0, 48)
            for i, (nm, im, y0) in enumerate(show):
                canvas[y0:y0 + im.shape[0], i * 168:i * 168 + 160] = pal_rgb[im]
            Image.fromarray(canvas).resize((canvas.shape[1] * 2, H * 2), Image.NEAREST).save(
                os.path.join(OUT, "%s_%d_rules.png" % (game, n)))

    rep = []
    rep.append("FRAMES")
    rep += ["  " + s for s in notes]
    rep.append("")
    rep.append("COLOUR-REGISTER WRITES ON VISIBLE LINES, by the colour clock on which the write takes effect")
    rep.append("  (0..67 = horizontal blank, 68 = pixel 0, 227 = pixel 159); share of the writes of that register")
    rep.append("  %-10s %-7s %7s | %6s %6s %6s %6s %6s %6s | most common clocks" %
               ("game", "reg", "writes", "hblank", "px0-7", "8-39", "40-79", "80-119", "120-159"))
    for game, hist in hists.items():
        for k in range(4):
            h = hist[k]
            tot = int(h.sum())
            if tot == 0:
                rep.append("  %-10s %-7s %7d |" % (game, REG[k], 0))
                continue
            px = lambda a, b: 100.0 * h[68 + a:68 + b].sum() / tot
            top = sorted(range(228), key=lambda c: -h[c])[:4]
            rep.append("  %-10s %-7s %7d | %5.0f%% %5.0f%% %5.0f%% %5.0f%% %5.0f%% %5.0f%% | %s" %
                       (game, REG[k], tot, 100.0 * h[:68].sum() / tot, px(0, 8), px(8, 40), px(40, 80), px(80, 120), px(120, 160),
                        ", ".join("%d (%s) %d%%" % (c, "hblank" if c < 68 else "px %d" % (c - 68), round(100.0 * h[c] / tot)) for c in top if h[c])))
    for title, col in (("LINES WHERE THE RULE GIVES A COLOUR DIFFERENT FROM THE CORE'S OWN PER-PIXEL COLOUR", 1),
                       ("LINES WHERE THE COLOUR THE RULE GIVES IS NOT ON THE EMULATOR'S ROW AT ALL", 2)):
        rep.append("")
        rep.append(title)
        rep.append("  (lines counted per register only where that colour source is on screen, columns 8..159;")
        rep.append("   'first' = value when the object is first drawn on the line; 'now' = per pixel, no sampling)")
        rep.append("  %-10s %-7s %5s | " % ("game", "reg", "lines") + " ".join("%5s" % r for r in RULES))
        allsum = collections.defaultdict(lambda: np.zeros(3, np.int64))
        for game in GAMES:
            for k in range(4):
                used = int(stat[(game, RULES[0], k)][0])
                rep.append("  %-10s %-7s %5d | " % (game, REG[k], used) + " ".join("%5d" % int(stat[(game, r, k)][col]) for r in RULES))
                for r in RULES:
                    allsum[(r, k)] += stat[(game, r, k)]
        for k in range(4):
            rep.append("  %-10s %-7s %5d | " % ("ALL", REG[k], int(allsum[(RULES[0], k)][0])) + " ".join("%5d" % int(allsum[(r, k)][col]) for r in RULES))
        rep.append("  %-10s %-7s %5s | " % ("ALL", "sum", "") + " ".join("%5d" % int(sum(allsum[(r, k)][col] for k in range(4))) for r in RULES))
    rep.append("")
    rep.append("LINES WHERE ONE COLOUR SOURCE SHOWS MORE THAN ONE COLOUR (no single sample per line can be right)")
    for game in GAMES:
        rep.append("  %-10s " % game + "  ".join("%s %d of %d" % (REG[k], int(multi[(game, k)][1]), int(multi[(game, k)][0])) for k in range(4)))
    txt = "\n".join(rep)
    open(os.path.join(OUT, "report.txt"), "w").write(txt + "\n")
    print(txt)


main()
