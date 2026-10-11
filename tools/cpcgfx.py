#!/usr/bin/env python3
"""Asset converter for Build Dangerous (Amstrad CPC, Mode 1).

  cpcgfx.py tiles    IN.png OUT.bin            8x8 tiles, 16 bytes each (8 lines x 2 bytes)
  cpcgfx.py sprites  IN.png OUT.bin [--mirror] 16x16 masked frames, 128 bytes each
                                               (16 lines x 4 x (mask,data)); --mirror appends
                                               horizontally flipped copies of every frame
  cpcgfx.py sprites8 IN.png OUT.bin            8x8 masked frames, 32 bytes each
  cpcgfx.py portrait IN.png OUT.bin X Y W H    32x32 face + the WxH patch at X,Y where the
                                               second frame differs (the mouth), unmasked
  cpcgfx.py building IN.txt OUT.asm LABEL      building (rooms + exits) -> asm, room data
                                               included (see convert_building)
  cpcgfx.py room     IN.txt OUT.asm LABEL      one standalone room -> asm (outdoor scene)
  cpcgfx.py text     IN.txt OUT.asm FONT.png   "ID | English | Greek" lines -> string tables
  cpcgfx.py tilemap  IN.txt OUT.asm LABEL      40-wide grid of room characters -> RLE (title logo)
"""
import sys
import unicodedata
from PIL import Image

# Pen RGB values; must match the ink table in src/video.asm.
PENS = [(0, 0, 0), (255, 128, 0), (0, 128, 255), (255, 255, 255)]

# Room text legend -> tile id; must match TILE_* in src/tiles.asm.
ROOM_LEGEND = {
    ' ': 0, '.': 1, '=': 2, '#': 3, '[': 4, ']': 5, 'w': 6, 'D': 7, 'd': 8, 'L': 9, 's': 10,
    'X': 15, 'x': 16, '*': 28, 'o': 29, 'r': 30,
    'h': 32, 'p': 33, 'b': 34, 'e': 35, '+': 36, 'k': 37, 'K': 38, 'C': 39,
    'g': 40, 'q': 41, 'v': 42,
    '/': 43, '\\': 44,                         # stairs rising right / left
    'u': 45, 'U': 46, 'n': 47, 'N': 48,         # escalators: up rising right / left, down ...
    'T': 49, 'Z': 50, 'I': 51,                  # title logo: bricks, barrier stripes, girder
    '$': 52, 'G': 53, 'A': 54,                  # Hard Knock: slot machine, guitar, amp
    'y': 55, 'z': 56, 'P': 57, 'c': 58,         # furniture: sofa left/right, picture, clock,
    't': 59, 'F': 60, 'f': 61, 'm': 62,         # TV, fridge top/bottom, bin
    'B': 63, 'E': 64, 'W': 65, 'V': 66,         # bookcase top/bottom, water cooler top/bottom
    'R': 67, 'M': 68, 'J': 69,                  # reception desk left/middle/right
}

# Building palettes: hardware ink for pen 2 (walls, windows... and Thanos's suit).
PALETTES = {'skyblue': 0x57, 'green': 0x56, 'mauve': 0x5D, 'cyan': 0x5B, 'paleblue': 0x5F,
            'magenta': 0x4D}
ROOM_W, ROOM_H = 40, 23
HUD_ROWS = 2

# Hazard type names used in room files -> HZ_* in src/hazards.asm.
HAZARD_TYPES = ['electric', 'bite', 'drown', 'head', 'cut', 'impale', 'squash', 'fire', 'ice',
                'poison', 'suck', 'catapult', 'evidence']

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


def convert_portrait(src, dst, patch, size=32):
    """Phone portrait: two square frames side by side, the second differing only inside
    patch = (x, y, w, h) (x and w multiples of 4). Out: frame 0 unmasked (size/4 bytes a
    line, size lines), then just the patch of frame 1 (w/4 bytes a line, h lines) - the
    open mouth, drawn over frame 0 to animate it."""
    im = load(src)
    w, h = im.size
    if (w, h) != (2 * size, size):
        sys.exit(f"{src}: expected two {size}x{size} frames side by side, got {w}x{h}")
    px, py, pw, ph = patch
    if px % 4 or pw % 4:
        sys.exit(f"{src}: the patch must start and end on a byte (4 pixels)")
    for y in range(size):
        for x in range(size):
            inside = px <= x < px + pw and py <= y < py + ph
            if not inside and im.getpixel((x, y)) != im.getpixel((size + x, y)):
                sys.exit(f"{src}: frames differ at ({x},{y}), outside the patch {patch}")

    def rows(ox, x0, x1, y0, y1):
        out = bytearray()
        for y in range(y0, y1):
            for bx in range(x0 // 4, x1 // 4):
                pens = [pen_of(im.getpixel((ox + bx * 4 + n, y))) for n in range(4)]
                out.append(encode_byte([0 if p is None else p for p in pens]))
        return out
    out = rows(0, 0, size, 0, size) + rows(size, px, px + pw, py, py + ph)
    open(dst, 'wb').write(out)
    print(f"{dst}: {size}x{size} face + {pw}x{ph} mouth, {len(out)} bytes")


def convert_tilemap(src, dst, label):
    """A 40-wide grid of room characters (any number of rows, ';' comments) -> RLE
    (count, tile)... 0, drawn from the top-left of the screen (draw_tilemap)."""
    rows = [l.rstrip('\n') for l in open(src, encoding='utf-8') if not l.startswith(';')]
    while rows and rows[-1] == '':
        rows.pop()
    cells = []
    for y, row in enumerate(rows):
        if len(row) != ROOM_W:
            sys.exit(f"{src}:{y + 1}: expected {ROOM_W} columns, got {len(row)}")
        for x, ch in enumerate(row):
            if ch not in ROOM_LEGEND:
                sys.exit(f"{src}:{y + 1}:{x + 1}: unknown tile char {ch!r}")
            cells.append(ROOM_LEGEND[ch])
    out, i = bytearray(), 0
    while i < len(cells):
        run = 1
        while i + run < len(cells) and cells[i + run] == cells[i] and run < 255:
            run += 1
        out += bytes((run, cells[i]))
        i += run
    out.append(0)
    lines = [f"; Generated by tools/cpcgfx.py from {src}. Do not edit.", f"{label}:"]
    for j in range(0, len(out), 24):
        lines.append("        db " + ','.join(map(str, out[j:j + 24])))
    open(dst, 'w').write('\n'.join(lines) + '\n')
    print(f"{dst}: {len(rows)} rows, {len(out)} bytes")


def encode_cells(cells, width=ROOM_W):
    """Room tiles, row by row, as byte codes (room.asm room_load decodes them):
      1-127, tile        a run of that many of one tile
      %10tttttt          one tile (0-63; tiles 64-127 go as a run of 1)
      %11nnnnnn          copy n+1 cells from the row above (rooms repeat a lot vertically)
      0                  end
    Greedy: the longer of a run and a copy; a single cell is one byte."""
    assert max(cells) < 128, "tile ids must stay below 128 (bit 7 marks hazards in the map)"
    out, i, n = bytearray(), 0, len(cells)
    while i < n:
        run = 1
        while i + run < n and cells[i + run] == cells[i] and run < 127:
            run += 1
        copy = 0
        if i >= width:
            while i + copy < n and cells[i + copy] == cells[i + copy - width] and copy < 64:
                copy += 1
        if copy >= 2 and copy >= run:
            out.append(0xC0 | (copy - 1))
            i += copy
        elif run >= 2 or cells[i] >= 64:
            out += bytes((run, cells[i]))
            i += run
        else:
            out.append(0x80 | cells[i])
            i += 1
    out.append(0)
    return out


def skip_cells(data):
    """Offset just past encode_cells' end marker."""
    i = 0
    while data[i]:
        i += 2 if data[i] < 0x80 else 1
    return i + 1


def load_room(src):
    """Room text -> (grid of chars, room data bytes): the tiles (encode_cells), then
    hazard count and (x, row, type, state) per hazard, then the owner's nephew: 0, or 1 and
    (x, top row, xmin, xmax) - he paces xmin..xmax on one floor.

      hazard <type> <x> <row>          (row within the room, 0-22)
      nephew <xmin> <xmax> <feet row>  (the row his feet are on, e.g. 20 on the ground floor)"""
    lines = open(src, encoding='utf-8').read().split('\n')
    lines = [l for l in lines if not l.startswith(';')]
    hazard_lines = [l for l in lines if l.startswith('hazard ')]
    nephew_lines = [l for l in lines if l.startswith('nephew ')]
    lines = [l for l in lines if not l.startswith(('hazard ', 'nephew '))]
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
    out = encode_cells(cells)

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

    if len(nephew_lines) > 1:
        sys.exit(f"{src}: one nephew per room")
    if not nephew_lines:
        out.append(0)
        return lines, out
    try:
        xmin, xmax, feet = (int(v) for v in nephew_lines[0].split()[1:])
    except ValueError:
        sys.exit(f"{src}: bad nephew line {nephew_lines[0]!r} (nephew <xmin> <xmax> <feet row>)")
    if not (0 <= xmin < xmax <= ROOM_W - 2 and 1 <= feet < ROOM_H - 1):
        sys.exit(f"{src}: nephew out of range: {nephew_lines[0]!r}")
    for x in range(xmin, xmax + 2):
        if lines[feet + 1][x] not in SOLID_CHARS + '/\\uUnN':
            sys.exit(f"{src}: nephew: no floor under column {x}")
        if lines[feet][x] in SOLID_CHARS or lines[feet - 1][x] in SOLID_CHARS:
            sys.exit(f"{src}: nephew: column {x} is blocked")
    out += bytes((1, xmin, feet - 1 + HUD_ROWS, xmin, xmax))
    return lines, out


SOLID_CHARS = '=#'
LADDER_CHARS = '[]'
STAIR_DX = {'/': 1, '\\': -1}                 # stairs that can cross into the room above
DIRS = ['left', 'right', 'up', 'down']
OPPOSITE = {'left': 'right', 'right': 'left', 'up': 'down', 'down': 'up'}
NO_EXIT = 255


def parse_building(src):
    """Read and validate a building file. Returns a dict: rooms (names, in index order),
    links {room: {dir: room}}, start (room, x, screen row), clock, misses_ok, sign, welcome,
    palette, loaded {room: (grid, data bytes)}.

      room <name> [left=<room>] [right=<room>] [up=<room>] [down=<room>]
      start <room> <x> <screen row>
      clock <seconds>        time before the ribbon is cut (default 300, max 999)
      misses_ok <n>          Misses still graded "good" (default 2)
      sign <STRING_ID>       name lit up on the facade in the outdoor scene
      welcome <STRING_ID>    the owner's first line
      palette <name>         wall colour (pen 2): skyblue (default), green, mauve, cyan, paleblue,
                             magenta
      calls <n>              Tasha phones n times (1-3, default 2), at random times: the
                             first 20-51 s into the inspection, then every 30-61 s

    Rooms are assets/rooms/<name>.txt, indexed in the order listed."""
    rooms, links, start = [], {}, None
    clock, misses_ok, sign, welcome, palette = 300, 2, None, None, 'skyblue'
    calls = 2
    for n, line in enumerate(open(src, encoding='utf-8'), 1):
        parts = line.split(';', 1)[0].split()
        if not parts:
            continue
        if parts[0] == 'room':
            name = parts[1]
            rooms.append(name)
            links[name] = {}
            for kv in parts[2:]:
                k, _, v = kv.partition('=')
                if k not in DIRS or not v:
                    sys.exit(f"{src}:{n}: bad exit {kv!r}")
                links[name][k] = v
        elif parts[0] == 'start' and len(parts) == 4:
            start = (parts[1], int(parts[2]), int(parts[3]))
        elif parts[0] == 'clock' and len(parts) == 2 and 8 <= int(parts[1]) <= 999:
            clock = int(parts[1])
        elif parts[0] == 'misses_ok' and len(parts) == 2:
            misses_ok = int(parts[1])
        elif parts[0] == 'palette' and len(parts) == 2 and parts[1] in PALETTES:
            palette = parts[1]
        elif parts[0] == 'calls' and len(parts) == 2 and parts[1] in '123':
            calls = int(parts[1])
        elif parts[0] in ('sign', 'welcome') and len(parts) == 2:
            if parts[0] == 'sign':
                sign = parts[1]
            else:
                welcome = parts[1]
        else:
            sys.exit(f"{src}:{n}: expected room / start / clock / misses_ok")
    if not rooms or start is None or start[0] not in rooms or not sign or not welcome:
        sys.exit(f"{src}: needs rooms, a start line naming one of them, sign and welcome")
    if len(rooms) > 32:
        sys.exit(f"{src}: at most 32 rooms (bld_marked is 4 bytes)")

    loaded = {r: load_room(f"assets/rooms/{r}.txt") for r in rooms}
    for a in rooms:
        for d, b in links[a].items():
            if b not in links:
                sys.exit(f"{src}: {a} {d}={b}: no such room")
            if links[b].get(OPPOSITE[d]) != a:
                sys.exit(f"{src}: {a} {d}={b} but {b} has no {OPPOSITE[d]}={a}")
            ga, gb = loaded[a][0], loaded[b][0]
            if d == 'right':
                for y in range(ROOM_H):
                    if (ga[y][-1] in SOLID_CHARS) != (gb[y][0] in SOLID_CHARS):
                        sys.exit(f"{src}: {a} right edge and {b} left edge differ at row {y}")
            if d == 'up':
                below = {x for x, c in enumerate(ga[0]) if c in LADDER_CHARS}
                above = {x for x, c in enumerate(gb[-1]) if c in LADDER_CHARS}
                if below != above:
                    sys.exit(f"{src}: ladders through {a}'s ceiling {sorted(below)} and "
                             f"{b}'s floor {sorted(above)} must line up")
                # A flight through the ceiling skips one row each side, so it carries on
                # two columns along: its last step here in row 0, the next ones in the room
                # above at rows 22 and 21.
                flights = 0
                for x, c in enumerate(ga[0]):
                    if c in STAIR_DX:
                        dx = STAIR_DX[c]
                        if not (0 <= x + 2 * dx < ROOM_W and gb[-1][x + dx] == c and gb[-2][x + 2 * dx] == c):
                            sys.exit(f"{src}: the flight through {a}'s ceiling at column {x} "
                                     f"must carry on in {b} at row {ROOM_H - 1} column {x + dx} "
                                     f"and row {ROOM_H - 2} column {x + 2 * dx}")
                        flights += 1
                for x, c in enumerate(gb[-1]):
                    if c in STAIR_DX and not (0 <= x - STAIR_DX[c] < ROOM_W and ga[0][x - STAIR_DX[c]] == c):
                        sys.exit(f"{src}: the flight in {b}'s floor at column {x} doesn't come "
                                 f"from {a}'s ceiling")
                if not below and not flights:
                    sys.exit(f"{src}: {a} up={b} needs a ladder or a flight of stairs between them")
    return dict(rooms=rooms, links=links, start=start, clock=clock, misses_ok=misses_ok,
                sign=sign, welcome=welcome, palette=palette, calls=calls, loaded=loaded)


def convert_building(src, dst, label):
    """Building text -> asm: header, per-room record (data pointer + 4 exits), room data.
    See parse_building for the file format."""
    b = parse_building(src)
    rooms, links, start, loaded = b['rooms'], b['links'], b['start'], b['loaded']
    clock, misses_ok, sign, welcome, palette = (b[k] for k in
                                                ('clock', 'misses_ok', 'sign', 'welcome', 'palette'))
    out = [f"; Generated by tools/cpcgfx.py from {src}. Do not edit.", "",
           f"{label}:",
           f"        db {len(rooms)}, {rooms.index(start[0])}, {start[1]}, {start[2]}"
           "   ; rooms, start room, x, row",
           f"        db #{clock // 100:02x}, #{clock % 100 // 10}{clock % 10}, {-(-clock // 8)}, {misses_ok}"
           "   ; clock (BCD hi, lo), seconds per dial step, misses graded good",
           f"        db STR_{sign}, STR_{welcome}, #{PALETTES[palette]:02x}"
           "   ; outdoor scene: facade sign, owner's welcome; pen 2 ink",
           f"        db {b['calls']}   ; Tasha phones this many times"]
    for i, r in enumerate(rooms):
        ex = [rooms.index(links[r][d]) if d in links[r] else NO_EXIT for d in DIRS]
        out.append(f"        dw {label}_{i}")
        out.append(f"        db {', '.join(map(str, ex))}   ; {r}: left right up down")
    for i, r in enumerate(rooms):
        data = loaded[r][1]
        out.append(f"{label}_{i}:   ; {r}")
        for j in range(0, len(data), 24):
            out.append("        db " + ','.join(map(str, data[j:j + 24])))
    open(dst, 'w').write('\n'.join(out) + '\n')
    print(f"{dst}: {len(rooms)} rooms")


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
    out = [f"; Generated by tools/cpcgfx.py from {src}. Do not edit.", "",
           f"GLYPH_0 equ {FONT_CHARS.index('0')}", f"GLYPH_SLASH equ {FONT_CHARS.index('/')}",
           f"GLYPH_DASH equ {FONT_CHARS.index('-')}", ""]
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


def convert_room(src, dst, label):
    """A standalone room (no building), e.g. the outdoor scene."""
    data = load_room(src)[1]
    out = [f"; Generated by tools/cpcgfx.py from {src}. Do not edit.", f"{label}:"]
    for j in range(0, len(data), 24):
        out.append("        db " + ','.join(map(str, data[j:j + 24])))
    open(dst, 'w').write('\n'.join(out) + '\n')
    print(f"{dst}: {len(data)} bytes")


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
    elif cmd == 'portrait' and len(argv) == 8:
        convert_portrait(src, dst, tuple(int(v) for v in argv[4:8]))
    elif cmd == 'room' and len(argv) > 4:
        convert_room(src, dst, argv[4])
    elif cmd == 'building' and len(argv) > 4:
        convert_building(src, dst, argv[4])
    elif cmd == 'tilemap' and len(argv) > 4:
        convert_tilemap(src, dst, argv[4])
    elif cmd == 'text' and len(argv) > 4:
        convert_text(src, dst, argv[4])
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
