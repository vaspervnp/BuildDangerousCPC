#!/usr/bin/env python3
"""Asset converter for Build Dangerous (Amstrad CPC, Mode 1).

  cpcgfx.py tiles    IN.png OUT.bin            8x8 tiles, 16 bytes each (8 lines x 2 bytes)
  cpcgfx.py sprites  IN.png OUT.bin [--mirror] 16x16 masked frames, 128 bytes each
                                               (16 lines x 4 x (mask,data)); --mirror appends
                                               horizontally flipped copies of every frame
  cpcgfx.py sprites8 IN.png OUT.bin            8x8 masked frames, 32 bytes each
  cpcgfx.py room     IN.txt OUT.bin            40x23 text room -> RLE (count,tile)... 0,
                                               then hazards: count, (x, row, type, state)...
  cpcgfx.py text     IN.txt OUT.asm FONT.png   "ID | English | Greek" lines -> string tables
"""
import sys
import unicodedata
from PIL import Image

# Pen RGB values; must match the ink table in src/video.asm.
PENS = [(0, 0, 0), (255, 128, 0), (0, 128, 255), (255, 255, 255)]

# Room text legend -> tile id; must match TILE_* in src/tiles.asm.
ROOM_LEGEND = {
    ' ': 0, '.': 1, '=': 2, '#': 3, '[': 4, ']': 5, 'w': 6, 'D': 7, 'd': 8, 'L': 9, 's': 10,
    'X': 15, 'x': 16,
}
ROOM_W, ROOM_H = 40, 23
HUD_ROWS = 2

# Hazard type names used in room files -> HZ_* in src/hazards.asm.
HAZARD_TYPES = ['electric', 'bite', 'drown', 'head', 'cut', 'impale', 'squash', 'fire', 'ice',
                'poison', 'suck', 'catapult']

# Glyph order of assets/gfx/font.png (see FONT in tools/art/gen_placeholder_art.lua).
FONT_CHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,!?:;-'/ΓΔΘΛΞΠΣΦΨΩ"
# Greek capitals drawn with the Latin glyph of the same shape.
GREEK_AS_LATIN = dict(zip("ΑΒΕΖΗΙΚΜΝΟΡΤΥΧ", "ABEZHIKMNOPTYX"))
TEXT_MAX = 40


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


def frame_bytes(im, ox, mirror, size=16):
    out = bytearray()
    for y in range(size):
        for bx in range(size // 4):
            pens, mask = [], 0
            for n in range(4):
                x = bx * 4 + n
                if mirror:
                    x = size - 1 - x
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


def convert_sprites8(src, dst):
    im = load(src)
    w, h = im.size
    if h != 8 or w % 8:
        sys.exit(f"{src}: sprite sheet must be N*8 x 8, got {w}x{h}")
    out = bytearray()
    for f in range(w // 8):
        out += frame_bytes(im, f * 8, False, 8)
    open(dst, 'wb').write(out)
    print(f"{dst}: {w // 8} frames, {len(out)} bytes")


def convert_room(src, dst):
    lines = open(src, encoding='utf-8').read().split('\n')
    lines = [l for l in lines if not l.startswith(';')]
    hazard_lines = [l for l in lines if l.startswith('hazard ')]
    lines = [l for l in lines if not l.startswith('hazard ')]
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

    # hazard <type> <x> <row>   (row counted within the room, 0-22)
    out.append(len(hazard_lines))
    seen = set()
    for l in hazard_lines:
        parts = l.split()
        if len(parts) != 4 or parts[1] not in HAZARD_TYPES:
            sys.exit(f"{src}: bad hazard line {l!r} (types: {', '.join(HAZARD_TYPES)})")
        x, y = int(parts[2]), int(parts[3])
        if not (0 <= x < ROOM_W and 0 <= y < ROOM_H) or (x, y) in seen:
            sys.exit(f"{src}: hazard position out of range or duplicated: {l!r}")
        seen.add((x, y))
        out += bytes((x, y + HUD_ROWS, HAZARD_TYPES.index(parts[1]), 0))
    open(dst, 'wb').write(out)
    print(f"{dst}: {len(cells)} cells, {len(hazard_lines)} hazards -> {len(out)} bytes")


def encode_text(s, where):
    s = ''.join(c for c in unicodedata.normalize('NFD', s.upper())
                if unicodedata.category(c) != 'Mn')
    codes = []
    for c in s:
        c = GREEK_AS_LATIN.get(c, c)
        if c not in FONT_CHARS:
            sys.exit(f"{where}: no glyph for {c!r}")
        codes.append(FONT_CHARS.index(c))
    if len(codes) > TEXT_MAX:
        sys.exit(f"{where}: {len(codes)} characters, max {TEXT_MAX}")
    return codes


def convert_text(src, dst, font_png):
    w, _ = Image.open(font_png).size
    if w // 8 != len(FONT_CHARS):
        sys.exit(f"{font_png} has {w // 8} glyphs but FONT_CHARS has {len(FONT_CHARS)}")
    rows = []
    for n, line in enumerate(open(src, encoding='utf-8'), 1):
        line = line.rstrip('\n')
        if not line.strip() or line.lstrip().startswith(';'):
            continue
        parts = [p.strip() for p in line.split('|')]
        if len(parts) != 3:
            sys.exit(f"{src}:{n}: expected 'ID | English | Greek'")
        rows.append((parts[0], encode_text(parts[1], f"{src}:{n} EN"),
                     encode_text(parts[2], f"{src}:{n} GR")))
    out = [f"; Generated by tools/cpcgfx.py from {src}. Do not edit.", ""]
    for i, (sid, _, _) in enumerate(rows):
        out.append(f"STR_{sid} equ {i}")
    for lang in ('en', 'gr'):
        out.append(f"\nstrings_{lang}:")
        out += [f"        dw str_{lang}_{sid}" for sid, _, _ in rows]
    for lang, col in (('en', 1), ('gr', 2)):
        for r in rows:
            out.append(f"str_{lang}_{r[0]}: db {','.join(map(str, r[col] + [255]))}")
    open(dst, 'w').write('\n'.join(out) + '\n')
    print(f"{dst}: {len(rows)} strings")


def main(argv):
    if len(argv) < 4:
        sys.exit(__doc__)
    cmd, src, dst = argv[1:4]
    if cmd == 'tiles':
        convert_tiles(src, dst)
    elif cmd == 'sprites':
        convert_sprites(src, dst, '--mirror' in argv[4:])
    elif cmd == 'sprites8':
        convert_sprites8(src, dst)
    elif cmd == 'room':
        convert_room(src, dst)
    elif cmd == 'text' and len(argv) > 4:
        convert_text(src, dst, argv[4])
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
