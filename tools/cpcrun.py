#!/usr/bin/env python3
"""Headless Amstrad CPC harness for Build Dangerous.

Runs the game binary on a bare Z80 (no firmware/ROM), emulating only the hardware the
game touches: Gate Array (inks, mode), CRTC registers, PPI + PSG keyboard matrix and the
VSYNC bit. Drives it from a script and saves Mode 1 screenshots / checks variables.

  cpcrun.py build/bd.bin --sym build/bd.sym --script tests/smoke.txt --out build/shots

Script lines (';' starts a comment):
  run <frames> [key+key...]     hold keys (or none) for N frames
  shot <name>                   save <out>/<name>.png
  expect <symbol> <value>       assert byte at symbol == value (decimal or #hex)

Keys: up down left right fire mark lang (keyboard) and jup jdown jleft jright jfire1 jfire2.
"""
import argparse
import os
import sys

import z80
from PIL import Image

FRAME_T = 79872         # 19968 us/frame at 4 T-states/us (ignores CPC wait-state stretching)
VSYNC_T = 2048          # 8 scanlines
SLICE_T = 64

KEYS = {
    'up': (0, 0), 'right': (0, 1), 'down': (0, 2), 'left': (1, 0),
    'fire': (5, 7), 'mark': (4, 6), 'lang': (4, 4),
    'jup': (9, 0), 'jdown': (9, 1), 'jleft': (9, 2), 'jright': (9, 3),
    'jfire2': (9, 4), 'jfire1': (9, 5),
}

# Gate array hardware colour (0-31) -> RGB
HW_RGB = [
    (128, 128, 128), (128, 128, 128), (0, 255, 128), (255, 255, 128),
    (0, 0, 128), (255, 0, 128), (0, 128, 128), (255, 128, 128),
    (255, 0, 128), (255, 255, 128), (255, 255, 0), (255, 255, 255),
    (255, 0, 0), (255, 0, 255), (255, 128, 0), (255, 128, 255),
    (0, 0, 128), (0, 255, 128), (0, 255, 0), (0, 255, 255),
    (0, 0, 0), (0, 0, 255), (0, 128, 0), (0, 128, 255),
    (128, 0, 128), (128, 255, 128), (128, 255, 0), (128, 255, 255),
    (128, 0, 0), (128, 0, 255), (128, 128, 0), (128, 128, 255),
]


def load_symbols(path):
    syms = {}
    if path:
        for line in open(path):
            parts = line.split()
            if len(parts) >= 2 and parts[1].startswith('#'):
                syms[parts[0].upper()] = int(parts[1][1:], 16)
    return syms


class CPC:
    def __init__(self, binary, org, syms):
        self.m = z80.Z80Machine()
        self.m.set_memory_block(org, binary)
        self.m.pc = org
        self.m.sp = 0xBFF0
        self.org, self.end = org, org + len(binary)
        self.t = 0
        self.inks = [0x14] * 17
        self.pen = 0
        self.mode = 1
        self.crtc_sel = 0
        self.crtc = [0] * 32
        self.ppi_a = 0xFF
        self.ppi_c = 0
        self.psg_reg = 0
        self.matrix = [0xFF] * 10
        self.busy = []          # T-states of work per frame (vsync start -> next wait_vbl)
        self.wait_vbl = syms.get('WAIT_VBL')
        self.vsync_start_t = None
        self.m.set_output_callback(self.on_out)
        self.m.set_input_callback(self.on_in)
        if self.wait_vbl is not None:
            self.m.set_breakpoint(self.wait_vbl)

    def vsync(self):
        return (self.t % FRAME_T) < VSYNC_T

    def on_out(self, addr, val):
        if not addr & 0x8000 and addr & 0x4000:             # Gate Array
            f = val >> 6
            if f == 0:
                self.pen = 16 if val & 0x10 else val & 0x0F
            elif f == 1:
                self.inks[self.pen] = val & 0x1F
            elif f == 2:
                self.mode = val & 3
        if not addr & 0x4000:                                # CRTC
            sub = (addr >> 8) & 3
            if sub == 0:
                self.crtc_sel = val & 31
            elif sub == 1:
                self.crtc[self.crtc_sel] = val
        if not addr & 0x0800:                                # PPI 8255
            port = (addr >> 8) & 3
            if port == 0:
                self.ppi_a = val
            elif port == 2:
                self.ppi_c = val
                if (val >> 6) == 3:
                    self.psg_reg = self.ppi_a & 0x0F

    def on_in(self, addr):
        if not addr & 0x0800:
            port = (addr >> 8) & 3
            if port == 1:
                v = 1 if self.vsync() else 0
                if v and self.vsync_start_t is None:
                    self.vsync_start_t = self.t
                return 0x1E | v
            if port == 0 and (self.ppi_c >> 6) == 1 and self.psg_reg == 14:
                line = self.ppi_c & 0x0F
                return self.matrix[line] if line < 10 else 0xFF
        return 0xFF

    def set_keys(self, names):
        self.matrix = [0xFF] * 10
        for n in names:
            line, bit = KEYS[n]
            self.matrix[line] &= ~(1 << bit) & 0xFF

    def run_frames(self, n):
        target = self.t + n * FRAME_T
        while self.t < target:
            self.m.ticks_to_stop = SLICE_T
            events = self.m.run()
            used = SLICE_T - self.m.ticks_to_stop
            self.t += used
            pc = self.m.pc
            if pc == self.wait_vbl and events & z80.Z80Machine._BREAKPOINT_HIT:
                if self.vsync_start_t is not None:
                    self.busy.append(self.t - self.vsync_start_t)
                    self.vsync_start_t = None
                self.m.clear_breakpoint(pc)
                self.m.ticks_to_stop = 1
                self.t += 4 - self.m.ticks_to_stop  # approximate
                self.m.run()
                self.m.set_breakpoint(pc)
            if not (self.org <= pc < self.end or pc in (0x38, 0x39)):
                raise RuntimeError(f"PC escaped the program: #{pc:04X}")

    def peek(self, addr):
        return self.m.memory[addr]

    def screenshot(self, path):
        base = ((self.crtc[12] & 0x30) << 10) | ((self.crtc[12] & 0x03) << 9) | (self.crtc[13] << 1)
        img = Image.new('RGB', (640, 400))
        px = img.load()
        mem = self.m.memory
        for y in range(200):
            for xb in range(80):
                addr = (base & 0xC000) | ((base + (y >> 3) * 80 + xb) & 0x7FF) | ((y & 7) << 11)
                b = mem[addr]
                for n in range(4):
                    pen = ((b >> (7 - n)) & 1) | (((b >> (3 - n)) & 1) << 1)
                    rgb = HW_RGB[self.inks[pen]]
                    x = (xb * 4 + n) * 2
                    for dy in (0, 1):
                        px[x, y * 2 + dy] = rgb
                        px[x + 1, y * 2 + dy] = rgb
        img.save(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('binary')
    ap.add_argument('--org', default='1000')
    ap.add_argument('--sym')
    ap.add_argument('--script')
    ap.add_argument('--out', default='build/shots')
    ap.add_argument('--frames', type=int, default=50, help='frames to run when no script')
    args = ap.parse_args()

    syms = load_symbols(args.sym)
    cpc = CPC(open(args.binary, 'rb').read(), int(args.org, 16), syms)
    os.makedirs(args.out, exist_ok=True)

    steps = []
    if args.script:
        for raw in open(args.script):
            line = raw.split(';', 1)[0].strip()
            if line:
                steps.append(line.split())
    else:
        steps = [['run', str(args.frames)], ['shot', 'final']]

    failures = 0
    for st in steps:
        cmd = st[0]
        if cmd == 'run':
            keys = st[2].split('+') if len(st) > 2 and st[2] != '-' else []
            cpc.set_keys(keys)
            cpc.run_frames(int(st[1]))
        elif cmd == 'shot':
            path = os.path.join(args.out, st[1] + '.png')
            cpc.screenshot(path)
            print(f"shot {path}")
        elif cmd == 'expect':
            sym, want = st[1].upper(), st[2]
            want = int(want[1:], 16) if want.startswith('#') else int(want)
            got = cpc.peek(syms[sym])
            ok = got == want
            failures += not ok
            print(f"{'ok  ' if ok else 'FAIL'} {sym} = {got} (expected {want})")
        else:
            sys.exit(f"unknown script command: {cmd}")

    if cpc.busy:
        worst = max(cpc.busy[1:] or cpc.busy)
        print(f"frames: {len(cpc.busy)}, worst per-frame work: {worst} T "
              f"({100 * worst / FRAME_T:.0f}% of a 50Hz frame, before wait states)")
    if failures:
        sys.exit(f"{failures} expectation(s) failed")


if __name__ == '__main__':
    main()
