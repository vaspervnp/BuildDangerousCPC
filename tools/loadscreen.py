#!/usr/bin/env python3
"""Loading screen: a full-colour 320x200 picture -> Amstrad CPC Mode 0 (160x200, 16 inks).

  loadscreen.py IN.png SCREEN.BIN LOADER.BAS [--preview OUT.png]

Halves the width (Mode 0 pixels are twice as wide), picks the 16 of the CPC's 27 colours
that fit the picture best (black always kept for pen 0, the border), dithers with
Floyd-Steinberg, and writes the screen as the 16K at #C000 in CPC memory order. LOADER.BAS
is the disk's BD.BAS (ASCII BASIC; RUN"BD finds it before BD.BIN): Mode 0, the inks, load
the picture to #C000 (it appears as it loads, the classic way), then run the game (GAME.BIN).
"""
import argparse
from PIL import Image

LEVELS = (0, 128, 255)
# firmware colour n = 9*green + 3*red + blue, each 0/1/2
CPC = [(LEVELS[(n // 3) % 3], LEVELS[n // 9], LEVELS[n % 3]) for n in range(27)]
WEIGHTS = (3, 4, 2)            # rough perceptual weighting for R, G, B


def dist(a, b):
    return sum(w * (x - y) ** 2 for w, x, y in zip(WEIGHTS, a, b))


def pick_inks(pixels, count=16):
    """Greedily drop the CPC colour whose loss hurts least, until `count` remain."""
    # histogram of the picture snapped to 6 levels per channel, to keep it quick
    hist = {}
    for p in pixels:
        q = tuple(round(c / 51) * 51 for c in p)
        hist[q] = hist.get(q, 0) + 1
    inks = list(range(27))

    def cost(set_):
        return sum(n * min(dist(c, CPC[i]) for i in set_) for c, n in hist.items())
    while len(inks) > count:
        best = None
        for i in inks:
            if i == 0:
                continue                    # keep black
            trial = [j for j in inks if j != i]
            c = cost(trial)
            if best is None or c < best[0]:
                best = (c, i)
        inks.remove(best[1])
    # pen 0 black; the rest darkest to brightest
    inks.sort(key=lambda i: (i != 0, sum(CPC[i])))
    return inks


def dither(img, inks, strength=0.85):
    w, h = img.size
    buf = [[list(img.getpixel((x, y))) for x in range(w)] for y in range(h)]
    pal = [CPC[i] for i in inks]
    out = [[0] * w for _ in range(h)]
    for y in range(h):
        xs = range(w) if y % 2 == 0 else range(w - 1, -1, -1)
        d = 1 if y % 2 == 0 else -1
        for x in xs:
            old = [min(255, max(0, v)) for v in buf[y][x]]
            k = min(range(len(pal)), key=lambda i: dist(old, pal[i]))
            out[y][x] = k
            err = [(o - n) * strength for o, n in zip(old, pal[k])]
            for dx, dy, f in ((d, 0, 7 / 16), (-d, 1, 3 / 16), (0, 1, 5 / 16), (d, 1, 1 / 16)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and yy < h:
                    for c in range(3):
                        buf[yy][xx][c] += err[c] * f
    return out


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def dither_ordered(img, inks, spread=56):
    """4x4 Bayer: a fixed pattern, the regular cross-hatch of classic CPC screens."""
    w, h = img.size
    pal = [CPC[i] for i in inks]
    out = [[0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            t = (BAYER[y & 3][x & 3] + 0.5) / 16 - 0.5
            p = [v + t * spread for v in img.getpixel((x, y))]
            out[y][x] = min(range(len(pal)), key=lambda i: dist(p, pal[i]))
    return out


def encode(pens):
    """160x200 pens -> 16384 bytes of Mode 0 screen at #C000."""
    scr = bytearray(16384)
    for y in range(200):
        base = (y >> 3) * 80 + (y & 7) * 2048
        for bx in range(80):
            p0, p1 = pens[y][bx * 2], pens[y][bx * 2 + 1]
            b = (((p0 >> 0) & 1) << 7 | ((p1 >> 0) & 1) << 6 |
                 ((p0 >> 2) & 1) << 5 | ((p1 >> 2) & 1) << 4 |
                 ((p0 >> 1) & 1) << 3 | ((p1 >> 1) & 1) << 2 |
                 ((p0 >> 3) & 1) << 1 | ((p1 >> 3) & 1) << 0)
            scr[base + bx] = b
    return scr


def loader(inks):
    lines = [
        "10 MODE 0:BORDER 0",
        "20 FOR i=0 TO 15:READ c:INK i,c:NEXT",
        "30 LOAD\"SCREEN.BIN\",&C000",
        "40 RUN\"GAME\"",
        "50 DATA " + ",".join(str(i) for i in inks),
    ]
    return ("\r\n".join(lines) + "\r\n").encode('ascii') + b"\x1a"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('src')
    ap.add_argument('screen')
    ap.add_argument('basic')
    ap.add_argument('--preview')
    ap.add_argument('--dither', choices=('ordered', 'fs'), default='ordered')
    args = ap.parse_args()
    im = Image.open(args.src).convert('RGB')
    if im.size != (320, 200):
        raise SystemExit(f"{args.src}: expected 320x200, got {im.size}")
    half = Image.new('RGB', (160, 200))
    for y in range(200):
        for x in range(160):
            a, b = im.getpixel((2 * x, y)), im.getpixel((2 * x + 1, y))
            half.putpixel((x, y), tuple((p + q) // 2 for p, q in zip(a, b)))
    inks = pick_inks([half.getpixel((x, y)) for y in range(200) for x in range(160)])
    pens = dither_ordered(half, inks) if args.dither == 'ordered' else dither(half, inks)
    open(args.screen, 'wb').write(encode(pens))
    open(args.basic, 'wb').write(loader(inks))
    if args.preview:
        pv = Image.new('RGB', (640, 400))
        for y in range(200):
            for x in range(160):
                c = CPC[inks[pens[y][x]]]
                for dx in range(4):
                    pv.putpixel((x * 4 + dx, y * 2), c)
                    pv.putpixel((x * 4 + dx, y * 2 + 1), c)
        pv.save(args.preview)
    print(f"{args.screen}: Mode 0, inks {inks}")


if __name__ == '__main__':
    main()
