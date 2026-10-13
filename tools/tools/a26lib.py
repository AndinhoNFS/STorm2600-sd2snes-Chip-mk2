"""Shared helpers for the Atari 2600 core-vs-emulator comparison."""
import os, sys, math, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "pylib"))
import numpy as np
from PIL import Image

MAPPER = {2048: 0, 4096: 1, 8192: 2, 16384: 3, 32768: 4}
ALE_RESET_FRAMES = (60, 68)     # ALE: 60 no-op frames after power-on, then RESET held 2 x 4 frames

def ntsc_palette():
    """128 colours (index = hue<<3 | lum), a plain YIQ approximation of the NTSC TIA palette.
    palette_ntsc.inc of the SNES player was not available, so this stands in for it; entries
    seen in the emulator are replaced by the emulator's own RGB (see harvest)."""
    pal = np.zeros((128, 3), np.uint8)
    for hue in range(16):
        for lum in range(8):
            y = 0.05 + lum / 8.0 * 0.95
            if hue == 0:
                i = q = 0.0
            else:
                ang = math.radians(123.0 - (hue - 1) * 25.7)      # hue 1 = gold, going round the wheel
                sat = 0.26
                i, q = sat * math.cos(ang), sat * math.sin(ang)
            r = y + 0.956 * i + 0.621 * q
            g = y - 0.272 * i - 0.647 * q
            b = y - 1.106 * i + 1.703 * q
            pal[hue * 8 + lum] = [int(max(0, min(1, v)) * 255 + 0.5) for v in (r, g, b)]
    return pal

def rom_to_hex(rom_path, hex_path):
    d = open(rom_path, "rb").read()
    if len(d) not in MAPPER:
        raise SystemExit("unsupported ROM size %d" % len(d))
    img = (d * (32768 // len(d)))[:32768]
    with open(hex_path, "w") as f:
        f.write("".join("%02x\n" % b for b in img))
    return MAPPER[len(d)]

CORE = os.path.join(os.path.dirname(ROOT), "fpga")
ROM555 = np.array([int(x, 16) for x in open(os.path.join(CORE, "a26_bgr555.hex")).read().split()], np.uint16)

def bgr_to_rgb(a):
    """SNES BGR555 (uint16 array) -> uint8 RGB array"""
    a = a.astype(np.uint32)
    r, g, b = a & 31, (a >> 5) & 31, (a >> 10) & 31
    return np.stack([(r << 3) | (r >> 2), (g << 3) | (g >> 2), (b << 3) | (b >> 2)], -1).astype(np.uint8)

X0, X1 = 48, 208                                      # the 160 TIA pixels are SNES columns 48..207, 1:1
WIN_LEFT, WIN_RIGHT = 48, 207                         # window of a normal line
BAR_LEFT = 56                                         # window left on a line with the HMOVE bar

def place(img):
    """160-wide picture -> 256 wide as the SNES shows it: columns 48..207, black outside"""
    out = np.zeros((img.shape[0], 256), img.dtype)
    out[:, X0:X1] = img
    return out

def read_fb(path):
    """Frame buffer as the core publishes it (header, tile map, list of distinct tiles, HDMA tables).
    -> (meta, C[nlines,160] BGR555 as the SNES would show it (columns 48..207), src[nlines,160] 0..3,
        pal[nlines,4] BGR555)
    meta also gets 'bar' (lines whose window starts at 56), 'format_errors' (tables, window,
    and tiles outside columns 48..207 that are not zero) and 'C256' (the 256-wide picture,
    window applied: black outside it)."""
    lines = open(path).read().split("\n")
    kv = lines[0].split()
    meta = {kv[i]: int(kv[i + 1]) for i in range(0, len(kv), 2)}
    w = np.array([int(x, 16) for x in lines[1:1 + 16384]], np.uint16)
    n = meta["nlines"]
    ntiles = int(w[0])                                                # header: distinct tiles
    tmap = w[8:8 + 896].astype(np.int64)                             # byte +$0010: 28 x 32 map entries
    tlist = w[0x400:0x400 + 8192].reshape(1024, 8)                    # byte +$0800: tile i = 8 words
    t = tlist[np.minimum(tmap, 1023)].reshape(28, 32, 8).astype(np.uint32)   # tile row, tile, line of the tile
    merr = int((tmap >= max(ntiles, 1)).sum()) + int(w[1:8].any()) + int(tlist[0].any())
    run = np.maximum.accumulate(np.concatenate([[0], tmap]))[:-1]    # first appearance: at most 1 above all before
    merr += int((tmap > run + 1).sum()) + int(ntiles != int(tmap.max()) + 1)
    merr += ntiles - len(set(x.tobytes() for x in tlist[:ntiles]))  # two numbers with the same 16 bytes
    bits = 7 - np.arange(8)
    p0 = (t[..., None] >> bits) & 1
    p1 = (t[..., None] >> (bits + 8)) & 1
    src256 = (p0 | (p1 << 1)).astype(np.uint8).transpose(0, 2, 1, 3).reshape(224, 256)
    src = src256[:, X0:X1]
    err = int(src256[:n, :X0].any(1).sum()) + int(src256[:n, X1:].any(1).sum()) + merr   # tiles outside the picture are zero
    pal = np.zeros((224, 4), np.uint16)
    for k in range(4):
        base = 0x2000 + k * 0x200                     # byte +$4000 + k*$400
        tb = w[base:base + 450].reshape(225, 2)
        err += int((tb[:n, 0] != (k | (k << 8))).sum()) + int(tb[224, 0] != (k | (k << 8))) + int(tb[224, 1] != 0)
        pal[:, k] = tb[:224, 1]
    win = w[0x2800:0x2800 + 225]                      # byte +$5000
    err += int(((win[:n] >> 8) != WIN_RIGHT).sum()) + int(win[224] != (255 << 8))
    err += int((~np.isin(win[:n] & 0xFF, [WIN_LEFT, BAR_LEFT])).sum())
    bar = (win[:224] & 0xFF) == BAR_LEFT
    C256 = np.take_along_axis(pal, src256.astype(np.int64), 1)
    xs = np.arange(256)[None, :]                      # the window: black left of 'left' and right of 'right'
    C256[(xs < (win[:224] & 0xFF)[:, None]) | (xs > (win[:224] >> 8)[:, None])] = 0
    C = C256[:, X0:X1].copy()
    meta["bar"] = int(bar[:n].sum()); meta["format_errors"] = err; meta["C256"] = C256[:n]; meta["ntiles"] = ntiles
    return meta, C[:n], src[:n], pal[:n]

def to_png(img, pal_rgb, path, scale=1):
    """img: BGR555 (uint16) or palette indices (uint8, looked up in pal_rgb)"""
    im = Image.fromarray(bgr_to_rgb(img) if img.dtype == np.uint16 else pal_rgb[img])
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    im.save(path)
    return im

PAL_X = 16                                            # the writer samples the four colours of a line at this pixel

def rule_index(src, vis, col, cl):
    """Step 23, the index a26_vidwr gives each pixel.  src, vis, col: [lines, 160] (source 0..3,
    visible, final colour 0..127); cl: [lines, 4] the colours held for the line (BK PF P0 P1).
    A blanked pixel is index 0.  From pixel PAL_X + 1 on, a visible pixel whose source's held
    colour is not its final colour takes the lowest index whose held colour is; else its source."""
    s = np.where(vis, src, 0).astype(np.int64)
    own = np.take_along_axis(cl, s, 1)
    act = vis & (own != col) & (np.arange(src.shape[1])[None, :] > PAL_X)
    idx = s.copy()
    for k in (3, 2, 1, 0):
        idx = np.where(act & (cl[:, k:k + 1] == col), k, idx)
    return idx
