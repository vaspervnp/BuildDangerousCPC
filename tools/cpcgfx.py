#!/usr/bin/env python3
"""Asset converter for Build Dangerous (Amstrad CPC, Mode 1).

  cpcgfx.py tiles   IN.png OUT.bin            8x8 tiles, 16 bytes each (8 lines x 2 bytes)
  cpcgfx.py sprites IN.png OUT.bin [--mirror] 16x16 masked frames, 128 bytes each
                                              (16 lines x 4 x (mask,data)); --mirror appends
                                              horizontally flipped copies of every frame
  cpcgfx.py room    IN.txt OUT.bin            40x23 text room -> RLE (count,tile)... 0
"""
import sys
from PIL import Image

# Pen RGB values; must match the ink table in src/video.asm.
PENS = [(0, 0, 0), (255, 128, 0), (0, 128, 255), (255, 255, 255)]

# Room text legend -> tile id; must match TILE_* in src/tiles.asm.
ROOM_LEGEND = {
    ' ': 0, '.': 1, '=': 2, '#': 3, '[': 4, ']': 5, 'w': 6, 'D': 7, 'd': 8, 'L': 9,
}
ROOM_W, ROOM_H = 40, 23


def pen_of(rgba):
    r, g, b, a = rgba
    if a < 128:
        return None
    best = min(range(4), key=lambda i: sum((c - p) ** 2 for c, p in zip((r, g, b), PENS[i])))
    if sum((c - p) ** 2 for c, p in zip((r, g, b), PENS[best])) > 3 * 40 ** 2:
        raise ValueError(f"colour {rgba[:3]} is not in the Mode 1 palette")
    return best


def encode_byte(pens):
    """4 pens (left->right) -> Mode 1 byte. Pixel n: bit(7-n)=pen bit0, bit(3-n)=pen bit1."""
    v = 0
    for n, p in enumerate(pens):
        v |= ((p & 1) << (7 - n)) | (((p >> 1) & 1) << (3 - n))
    return v


def load(path):
    return Image.open(path).convert('RGBA')


def convert_tiles(src, dst):
    im = load(src)
    w, h = im.size
    if h != 8 or w % 8:
        sys.exit(f"{src}: tiles sheet must be N*8 x 8, got {w}x{h}")
    out = bytearray()
    for t in range(w // 8):
        for y in range(8):
            for bx in range(2):
                pens = []
                for n in range(4):
                    p = pen_of(im.getpixel((t * 8 + bx * 4 + n, y)))
                    pens.append(0 if p is None else p)
                out.append(encode_byte(pens))
    open(dst, 'wb').write(out)
    print(f"{dst}: {w // 8} tiles, {len(out)} bytes")


def frame_bytes(im, ox, mirror):
    out = bytearray()
    for y in range(16):
        for bx in range(4):
            pens, mask = [], 0
            for n in range(4):
                x = bx * 4 + n
                if mirror:
                    x = 15 - x
                p = pen_of(im.getpixel((ox + x, y)))
                if p is None:
                    mask |= (1 << (7 - n)) | (1 << (3 - n))
                    p = 0
                pens.append(p)
            out.append(mask)
            out.append(encode_byte(pens))
    return out


def convert_sprites(src, dst, mirror):
    im = load(src)
    w, h = im.size
    if h != 16 or w % 16:
        sys.exit(f"{src}: sprite sheet must be N*16 x 16, got {w}x{h}")
    n = w // 16
    out = bytearray()
    for f in range(n):
        out += frame_bytes(im, f * 16, False)
    if mirror:
        for f in range(n):
            out += frame_bytes(im, f * 16, True)
    open(dst, 'wb').write(out)
    print(f"{dst}: {len(out) // 128} frames, {len(out)} bytes")


def convert_room(src, dst):
    lines = open(src, encoding='utf-8').read().split('\n')
    lines = [l for l in lines if not l.startswith(';')]
    while lines and lines[-1] == '':
        lines.pop()
    if len(lines) != ROOM_H:
        sys.exit(f"{src}: expected {ROOM_H} rows, got {len(lines)}")
    cells = []
    for y, line in enumerate(lines):
        if len(line) != ROOM_W:
            sys.exit(f"{src}:{y + 1}: expected {ROOM_W} columns, got {len(line)}")
        for x, ch in enumerate(line):
            if ch not in ROOM_LEGEND:
                sys.exit(f"{src}:{y + 1}:{x + 1}: unknown tile char {ch!r}")
            cells.append(ROOM_LEGEND[ch])
    out = bytearray()
    i = 0
    while i < len(cells):
        run = 1
        while i + run < len(cells) and cells[i + run] == cells[i] and run < 255:
            run += 1
        out += bytes((run, cells[i]))
        i += run
    out.append(0)
    open(dst, 'wb').write(out)
    print(f"{dst}: {len(cells)} cells -> {len(out)} bytes RLE")


def main(argv):
    if len(argv) < 4:
        sys.exit(__doc__)
    cmd, src, dst = argv[1:4]
    if cmd == 'tiles':
        convert_tiles(src, dst)
    elif cmd == 'sprites':
        convert_sprites(src, dst, '--mirror' in argv[4:])
    elif cmd == 'room':
        convert_room(src, dst)
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
