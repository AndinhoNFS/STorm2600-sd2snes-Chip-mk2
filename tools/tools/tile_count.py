#!/usr/bin/env python3
"""Step 21a: how many DIFFERENT 8x8 tiles does a published frame hold?
usage: tile_count.py            runs the six games, prints the table, writes out/tiles/report.txt
For each game the core simulation (build/obj_tiles/tb_tiles = a26_core + a26_vidwr, current
layout: 160 columns 1:1 in tiles 6..25 of 32) is run once and the tile area of the published buffer is
dumped at frames 60, 70 .. 900 (frame N as in the comparison tool: N frames after the ALE's
start-up, i.e. published frame N + 68 + pre).  A tile = its 16 bytes, compared exactly.
Two scenarios: 'idle' (no input at all) and 'play' (fire held from frame 100, joystick right
from frame 200), because several games only show their title/attract screen without input."""
import sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from a26lib import *

GAMES = ["pitfall", "riverraid", "pacman", "enduro", "boxing", "frostbite"]
PRE = {"pacman": 16}
FA, FB, STEP = 60, 900, 10
THR = [200, 240, 300, 400, 500]
OUT = os.path.join(ROOT, "out", "tiles")
# OLD=1: the step-22 writer (build/obj_tiles_v11, sources of atari_core/bak_v11): no colour rule;
# its per-pixel colour errors are kept in out/tiles/err_v11_*.npy for the before / after count
OLD = os.environ.get("OLD", "") == "1"
TB = os.path.join(ROOT, "build", "obj_tiles_v11" if OLD else "obj_tiles", "tb_tiles")
ALE = os.path.join(ROOT, "out", "cor")              # <game>_ale.npy: ALE screens of frames 60, 70 .. 900 (no input)

BITS = 7 - np.arange(8)

def run(game, scen):
    DICT = dict(frames=0, pix_diff=0, hdr_bad=0, order_bad=0, nmax=0, dropped=0, ref_diff=0, out_bad=0, win_bad=0,
                col_diff=0, col_lines=0, moved=0, broke=0, fixed=0, ale_diff=0, ale_broke=0, ale_shift=0, tab_bad=0)
    errs = []; aerrs = {-1: [], 0: [], 1: []}
    ale = np.load(os.path.join(ALE, game + "_ale.npy")) if scen == "idle" else None
    hexf = os.path.join(ROOT, "build", game + ".hex")
    mapper = rom_to_hex(os.path.join(ROOT, "roms", game + ".a26"), hexf)
    off = ALE_RESET_FRAMES[1] + PRE.get(game, 0)
    pre = os.path.join(OUT, "%s_%s" % (game, scen))
    cmd = [TB, "+rom=" + hexf, "+mapper=%d" % mapper, "+out=" + pre,
           "+rst0=%d" % ALE_RESET_FRAMES[0], "+rst1=%d" % ALE_RESET_FRAMES[1],
           "+fa=%d" % (FA + off), "+fb=%d" % (FB + off), "+step=%d" % STEP]
    if scen == "play":
        cmd += ["+fire=%d" % (100 + off), "+joy0=%d" % (200 + off), "+joyv=127"]      # SWCHA $7F = player 0 right
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0: raise SystemExit(r.stdout + r.stderr)
    res = []
    for ln in open(pre + ".tiles"):
        fr, nl, hx, hb, drop, rx, wx, cx, lx, tx = ln.split()
        w = np.frombuffer(bytes.fromhex(hx), dtype=">u2").reshape(896, 8)       # 28 x 32 tiles, 8 words each
        # step 21b: the same frame as the dictionary wrote it (header, map, list) must rebuild
        # to exactly these tiles, with the tiles numbered in order of first appearance
        b = np.frombuffer(bytes.fromhex(hb), dtype=">u2")
        hn, tmap, tl = int(b[0]), b[8:904].astype(np.int64), b[0x400:0x400 + 4096].reshape(512, 8)
        DICT["frames"] += 1
        DICT["pix_diff"] += int((tl[np.minimum(tmap, 511)] != w).sum())
        DICT["hdr_bad"] += int(hn != len(set(t.tobytes() for t in w) | {bytes(16)})) + int(hn != int(tmap.max()) + 1) + int(b[1:8].any()) + int(tl[0].any())
        order = np.maximum.accumulate(np.concatenate([[0], tmap]))[:-1]
        DICT["order_bad"] += int((tmap > order + 1).sum())
        DICT["nmax"] = max(DICT["nmax"], hn); DICT["dropped"] = int(drop)
        # step 22: the picture rebuilt from map + list against the pixel stream itself, 1:1 in
        # columns 48..207; outside them the tiles are zero and the window (48 or 56 .. 207) is shut
        n = int(nl)
        t = tl[np.minimum(tmap, 511)].reshape(28, 32, 8).astype(np.uint32)
        s256 = (((t[..., None] >> BITS) & 1) | (((t[..., None] >> (BITS + 8)) & 1) << 1)).astype(np.uint8).transpose(0, 2, 1, 3).reshape(224, 256)
        rsrc = np.frombuffer(rx.encode(), np.uint8).reshape(224, 160) - 48
        rc = np.frombuffer(bytes.fromhex(cx), np.uint8).reshape(224, 160)
        vis = (rc & 0x80) == 0; col = np.where(vis, rc & 0x7F, 0)
        lv = np.array([int(lx[i * 7:i * 7 + 7], 16) for i in range(224)])
        cl = np.stack([(lv >> 21) & 127, (lv >> 14) & 127, (lv >> 7) & 127, lv & 127], 1).astype(np.uint8)
        # step 23: the index of every pixel must be what the rule gives (a26lib.rule_index), from
        # the pixel stream alone; the step-22 writer: the source itself
        ref = np.where(vis, rsrc, 0) if OLD else rule_index(rsrc, vis, col, cl)
        DICT["ref_diff"] += int((s256[:n, X0:X1] != ref[:n]).sum()) + int(s256[n:].any())
        DICT["moved"] += int((ref[:n] != np.where(vis, rsrc, 0)[:n]).sum())
        # in COLOUR: what the SNES shows (tile index -> the line's table colour, window applied)
        # against the final colour of every pixel as the TIA made it
        tb = np.frombuffer(bytes.fromhex(tx), dtype=">u2").reshape(4, 256, 2)
        pal = tb[:, :224, 1].T                                              # [line, k] BGR555
        blk = ~vis[:, PAL_X + 1]                                            # VBLANK on: the line is black
        DICT["tab_bad"] += int((pal[:n] != np.where(blk[:n, None], 0, ROM555[cl[:n]])).sum())
        C = np.take_along_axis(pal, s256[:, X0:X1].astype(np.int64), 1)
        left = (np.frombuffer(bytes.fromhex(wx), dtype=">u2")[:224] & 0xFF).astype(np.int64) - X0
        C[np.arange(160)[None, :] < left[:, None]] = 0
        e = (C != ROM555[col]); e[n:] = False
        DICT["col_diff"] += int(e.sum()); DICT["col_lines"] += int(e.any(1).sum()); errs.append(e)
        if ale is not None:                                                 # the ALE screen = lines 0..209 (+shift)
            a = ROM555[ale[DICT["frames"] - 1]]
            for sh in (-1, 0, 1):
                ea = np.zeros((210, 160), bool)
                ys = np.arange(210) + sh; ok = (ys >= 0) & (ys < n)
                ea[ok] = C[ys[ok]] != a[ok]                     # rows outside the buffer are not counted
                aerrs[sh].append(ea)
        win = np.frombuffer(bytes.fromhex(wx), dtype=">u2")
        DICT["out_bad"] += int(s256[:, :X0].any()) + int(s256[:, X1:].any())
        DICT["win_bad"] += int(((win[:n] >> 8) != WIN_RIGHT).sum()) + int((~np.isin(win[:n] & 0xFF, [WIN_LEFT, BAR_LEFT])).sum()) + int(win[224] != 0xFF00)
        tiles = set(t.tobytes() for t in w)
        # flat tile: all 64 pixels the same index = every word is $0000, $00FF, $FF00 or $FFFF, all equal
        flat = set(t for t in tiles if t[:2] in (b"\x00\x00", b"\x00\xff", b"\xff\x00", b"\xff\xff") and t == t[:2] * 8)
        rows = [len(set(w[r * 32:(r + 1) * 32][i].tobytes() for i in range(32))) for r in range(28)]
        res.append((int(fr) - off, int(nl), len(tiles), len(flat), max(rows)))
    os.remove(pre + ".tiles")
    errs = np.array(errs); tag = os.path.join(OUT, "err_v11_%s_%s" % (game, scen))
    if OLD: np.save(tag + ".npy", errs)
    elif os.path.exists(tag + ".npy"):
        old = np.load(tag + ".npy"); DICT["broke"] = int((errs & ~old).sum()); DICT["fixed"] = int((old & ~errs).sum()); DICT["before"] = int(old.sum())
    if ale is not None:
        tot = {sh: int(np.array(v).sum()) for sh, v in aerrs.items()}
        sh = min(tot, key=tot.get); DICT["ale_shift"] = sh; DICT["ale_diff"] = tot[sh]; ea = np.array(aerrs[sh])
        DICT["ale_rows"] = sorted(set(int(y) for y in np.flatnonzero(ea.any(2).any(0))))
        if OLD: np.save(tag + "_ale.npy", ea)
        elif os.path.exists(tag + "_ale.npy"):
            old = np.load(tag + "_ale.npy"); DICT["ale_broke"] = int((ea & ~old).sum()); DICT["ale_fixed"] = int((old & ~ea).sum()); DICT["ale_before"] = int(old.sum())
    return res, DICT

def main():
    os.makedirs(OUT, exist_ok=True)
    rep = []
    hdr = "%-10s %-5s %6s | %4s %7s %4s %4s | %s | %-13s | %s" % ("game", "input", "frames", "min", "median", "p90", "max",
          " ".join(">%-4d" % t for t in THR), "flat tiles", "non-flat: median / max")
    rep += ["Distinct 8x8 tiles per published frame (896 map entries = 28 rows x 32, picture in columns 6..25; frames %d..%d step %d)" % (FA, FB, STEP),
            "columns >N = %% of the frames with more than N distinct tiles; flat = distinct tiles whose 64 pixels share one index (at most 4)", "", hdr, "-" * len(hdr)]
    drep = ["", "DICTIONARY (step 21b): frame rebuilt from header + map + tile list against the direct tiles of the writer"]
    rrep = ["", "1:1 PICTURE (step 22): frame rebuilt from header + map + tile list against the pixel stream (index per pixel: %s)" % ("the source" if OLD else "source + step-23 colour rule, a26lib.rule_index")]
    crep = ["", "COLOUR (step 23): colour the SNES shows (index -> table colour of the line, window applied) against the final colour of each pixel in the TIA stream",
            "   'before' = the step-22 writer on the same frames (OLD=1 run); right -> wrong = pixels correct before and wrong now"]
    arep = ["", "COLOUR AGAINST THE ALE (no input only; ALE screen = buffer lines 0..209, Pac-Man 1 line off): pixels of 85 x 210 x 160 with another colour",
            "   (most of them are the game itself being in another state in the ALE; rows = buffer lines with any difference)"]
    csv = ["game,input,frame,lines,distinct,flat,max_distinct_in_one_tile_row"]
    from concurrent.futures import ThreadPoolExecutor
    jobs = [(g, scen) for scen in ("idle", "play") for g in GAMES]
    with ThreadPoolExecutor(int(os.environ.get("JOBS", "6"))) as ex:
        done = dict(zip(jobs, ex.map(lambda j: run(*j), jobs)))
    for scen in ("idle", "play"):
        for g in GAMES:
            res, DICT = done[(g, scen)]
            d = np.array([r[2] for r in res]); fl = np.array([r[3] for r in res]); nf = d - fl
            rep.append("%-10s %-5s %6d | %4d %7d %4d %4d | %s | %-13s | %d / %d" % (g, scen, len(d), d.min(), int(np.median(d)),
                       int(np.percentile(d, 90, method="higher")), d.max(),
                       " ".join("%4.0f%%" % (100.0 * (d > t).mean()) for t in THR),
                       "%d..%d (med %d)" % (fl.min(), fl.max(), int(np.median(fl))), int(np.median(nf)), nf.max()))
            csv += ["%s,%s,%d,%d,%d,%d,%d" % ((g, scen) + r) for r in res]
            drep.append("%-10s %-5s %6d frames | tile words different from the direct frame %d | header errors %d | numbering errors %d | max N %d | frames dropped %d"
                        % (g, scen, DICT["frames"], DICT["pix_diff"], DICT["hdr_bad"], DICT["order_bad"], DICT["nmax"], DICT["dropped"]))
            rrep.append("%-10s %-5s %6d frames | pixels different in columns 48..207 %d | frames with a non-zero tile outside them %d | window entries not 48/56..207 %d"
                        % (g, scen, DICT["frames"], DICT["ref_diff"], DICT["out_bad"], DICT["win_bad"]))
            crep.append("%-10s %-5s %6d frames | pixels with the wrong colour %d (on %d lines)%s | pixels given another index by the rule %d | colour table words wrong %d"
                        % (g, scen, DICT["frames"], DICT["col_diff"], DICT["col_lines"],
                           " | before %d, fixed %d, right -> wrong %d" % (DICT["before"], DICT["fixed"], DICT["broke"]) if "before" in DICT else "", DICT["moved"], DICT["tab_bad"]))
            if scen == "idle":
                rows = DICT["ale_rows"]
                arep.append("%-10s shift %+d | pixels different %d%s | rows %s" % (g, DICT["ale_shift"], DICT["ale_diff"],
                            " | before %d, now equal %d, equal -> different %d" % (DICT["ale_before"], DICT["ale_fixed"], DICT["ale_broke"]) if "ale_before" in DICT else "",
                            ("%d..%d (%d rows)" % (rows[0], rows[-1], len(rows))) if rows else "-"))
            if any(r[1] != 224 for r in res): rep.append("   note: %d frame(s) with fewer than 224 lines written" % sum(r[1] != 224 for r in res))
        rep.append("")
    rep += drep + rrep + crep + arep
    open(os.path.join(OUT, "report_v11_again.txt" if OLD else "report.txt"), "w").write("\n".join(rep) + "\n")
    open(os.path.join(OUT, "frames_v11_again.csv" if OLD else "frames.csv"), "w").write("\n".join(csv) + "\n")
    print("\n".join(rep))

main()
