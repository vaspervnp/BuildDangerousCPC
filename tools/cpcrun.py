#!/usr/bin/env python3
"""Headless Amstrad CPC harness for Build Dangerous.

Runs the game binary on a bare Z80 (no firmware/ROM), emulating only the hardware the
game touches: Gate Array (inks, mode), CRTC registers, PPI + PSG keyboard matrix and the
VSYNC bit. Drives it from a script and saves Mode 1 screenshots / checks variables.

  cpcrun.py build/bd.bin --sym build/bd.sym --script tests/smoke.txt --out build/shots

Script lines (';' starts a comment):
  run <frames> [key+key...]     hold keys (or none) for N frames
  shot <name>                   save <out>/<name>.png
  expect <addr> <value>         assert byte at addr == value (decimal or #hex)
  poke <addr> <value>           write a byte

<addr> is SYMBOL, SYMBOL+N, or *SYMBOL+N (N bytes past the pointer stored at SYMBOL).

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
        self.busy = []          # (loop no, T-states of work from vsync start to next wait_vbl)
        self.frame_no = 0
        self.at_wait = False
        self.wait_vbl = syms.get('WAIT_VBL')
        self.vsync_start_t = None
        self.last_vsync_read = 1
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
                if v and not self.last_vsync_read:      # the rising edge wait_vbl waits for
                    self.vsync_start_t = self.t
                self.last_vsync_read = v
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
        """Run n game-loop iterations: stop when the game enters wait_vbl for the n-th time,
        so every frame's work is complete when a script inspects memory. Without a
        wait_vbl symbol, falls back to n * FRAME_T T-states."""
        target = self.t + n * FRAME_T
        loops = 0
        while (loops < n) if self.wait_vbl is not None else (self.t < target):
            if self.m.pc == self.wait_vbl and self.at_wait:
                self.m.clear_breakpoint(self.wait_vbl)      # step past the breakpoint
                self.m.ticks_to_stop = 1
                self.m.run()
                self.t += 4
                self.m.set_breakpoint(self.wait_vbl)
                self.at_wait = False
            self.m.ticks_to_stop = SLICE_T
            events = self.m.run()
            self.t += SLICE_T - self.m.ticks_to_stop
            pc = self.m.pc
            if pc == self.wait_vbl and events & z80.Z80Machine._BREAKPOINT_HIT:
                self.at_wait = True
                loops += 1
                if self.vsync_start_t is not None:
                    self.busy.append((self.frame_no, self.t - self.vsync_start_t))
                    self.vsync_start_t = None
                self.frame_no += 1
            if not (self.org <= pc < self.end or pc in (0x38, 0x39)):
                raise RuntimeError(f"PC escaped the program: #{pc:04X}")

    def peek(self, addr):
        return self.m.memory[addr]

    def poke(self, addr, value):
        self.m.memory[addr] = value

    def resolve(self, expr, syms):
        deref = expr.startswith('*')
        name, _, off = expr.lstrip('*').partition('+')
        addr = syms[name.upper()]
        if deref:
            addr = self.peek(addr) | (self.peek(addr + 1) << 8)
        return addr + (int(off) if off else 0)

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
        elif cmd in ('expect', 'poke'):
            value = int(st[2][1:], 16) if st[2].startswith('#') else int(st[2])
            addr = cpc.resolve(st[1], syms)
            if cmd == 'poke':
                cpc.poke(addr, value)
                continue
            got = cpc.peek(addr)
            ok = got == value
            failures += not ok
            print(f"{'ok  ' if ok else 'FAIL'} {st[1]} = {got} (expected {value})")
        else:
            sys.exit(f"unknown script command: {cmd}")

    if cpc.busy:
        frame, worst = max(cpc.busy, key=lambda b: b[1])
        over = [f for f, t in cpc.busy if t > FRAME_T]
        print(f"frames: {len(cpc.busy)}, worst per-frame work: {worst} T in loop {frame} "
              f"({100 * worst / FRAME_T:.0f}% of a 50Hz frame, before wait states)"
              + (f"; over budget in loops {over}" if over else ""))
    if failures:
        sys.exit(f"{failures} expectation(s) failed")


if __name__ == '__main__':
    main()
