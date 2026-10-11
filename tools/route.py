#!/usr/bin/env python3
"""Route planner for Build Dangerous buildings.

Simulates Thanos's movement rules (src/player.asm) on a building's rooms, then plans a
complete clean run: walk to every hazard and set it off, sign off each room once its
hazards are gone, and leave by the exit door. Writes the run as a tools/cpcrun.py script,
so `make test` proves every building can be finished, and prints how long it takes.

  route.py assets/buildings/mall.txt tests/route_mall.txt

The plan is greedy (always the nearest hazard next), so it is a decent run, not the best.
"""
import heapq
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cpcgfx import HAZARD_TYPES, HUD_ROWS, parse_building  # noqa: E402

MAP_W, MAP_H = 40, 25
SOLID, CLIMB = '=#', '[]'
EXIT_DOOR = 'x'

# Costs in frames (game-loop iterations): a step is STEP_DELAY+1, a fall row FALL_DELAY+1.
STEP, FALL = 5, 2
VIGNETTE = 160              # rough length of a trap vignette, for the time estimate only

KEYS = ('up', 'down', 'left', 'right')


class Building:
    def __init__(self, src):
        b = parse_building(src)
        self.src = src
        self.label = 'bld_' + os.path.splitext(os.path.basename(src))[0]
        self.names = b['rooms']
        self.grids = [b['loaded'][r][0] for r in self.names]
        self.data = [b['loaded'][r][1] for r in self.names]
        self.exits = [{d: self.names.index(t) for d, t in b['links'][r].items()} for r in self.names]
        name, x, y = b['start']
        self.start = (self.names.index(name), x, y)
        self.clock = b['clock']
        # hazards[room] = [(x, screen row, type name)], in list order (the order Fire tries them)
        self.hazards = [self._hazards(d) for d in self.data]

    @staticmethod
    def _hazards(data):
        i = 0
        while data[i]:          # RLE runs (count, tile) end with a 0 count
            i += 2
        i += 1
        count = data[i]
        out = []
        for j in range(count):
            x, row, t, _ = data[i + 1 + 4 * j:i + 5 + 4 * j]
            out.append((x, row, HAZARD_TYPES[t]))
        return out

    def hazard_state_offset(self, room, j):
        """Offset of hazard j's state byte in the room's data."""
        return len(self.data[room]) - 4 * len(self.hazards[room]) + 4 * j + 3

    def cell(self, r, x, y):
        if not (HUD_ROWS <= y < MAP_H and 0 <= x < MAP_W):
            return '#'
        return self.grids[r][y - HUD_ROWS][x]

    def solid(self, r, x, y):
        return self.cell(r, x, y) in SOLID

    def climb(self, r, x, y):
        return self.cell(r, x, y) in CLIMB

    # ---- player.asm, cell by cell
    def on_ladder(self, s):
        r, x, y = s
        return self.climb(r, x, y + 1) and self.climb(r, x + 1, y + 1)

    def supported(self, s):
        r, x, y = s
        return (self.on_ladder(s) or (self.climb(r, x, y + 2) and self.climb(r, x + 1, y + 2))
                or self.solid(r, x, y + 2) or self.solid(r, x + 1, y + 2))

    def move(self, s, key):
        """One step with key held. Returns (new state, frames) or None if blocked."""
        r, x, y = s
        ex = self.exits[r]
        if key == 'up':
            if not self.on_ladder(s):
                return None
            if y == HUD_ROWS:
                return ((ex['up'], x, MAP_H - 2), True) if 'up' in ex else None
            if self.solid(r, x, y - 1) or self.solid(r, x + 1, y - 1):
                return None
            return (r, x, y - 1), False
        if key == 'down':
            if y == MAP_H - 2:
                return ((ex['down'], x, HUD_ROWS), True) if self.on_ladder(s) and 'down' in ex else None
            if not (self.climb(r, x, y + 2) and self.climb(r, x + 1, y + 2)):
                return None
            return (r, x, y + 1), False
        if key == 'left':
            if x == 0:
                return ((ex['left'], MAP_W - 2, y), True) if 'left' in ex else None
            if self.solid(r, x - 1, y) or self.solid(r, x - 1, y + 1):
                return None
            return (r, x - 1, y), False
        if x == MAP_W - 2:
            return ((ex['right'], 0, y), True) if 'right' in ex else None
        if self.solid(r, x + 2, y) or self.solid(r, x + 2, y + 1):
            return None
        return (r, x + 1, y), False

    def settle(self, s):
        """Fall until supported. Returns (state, frames)."""
        frames = 0
        r, x, y = s
        while not self.supported((r, x, y)):
            y += 1
            frames += FALL
        return (r, x, y), frames

    def neighbours(self, s):
        for key in KEYS:
            m = self.move(s, key)
            if m:
                t, changed_room = m
                t, fall = self.settle(t)
                yield key, t, STEP + fall + (13 if changed_room else 0)

    def path_to(self, s, goal):
        """Dijkstra from s to the nearest state where goal(state) holds.
        Returns (state, [(key, state)...], frames) or None."""
        dist = {s: 0}
        prev = {}
        heap = [(0, s)]
        while heap:
            d, u = heapq.heappop(heap)
            if d > dist[u]:
                continue
            if goal(u):
                end, path = u, []
                while u != s:
                    key, p = prev[u]
                    path.append((key, u))
                    u = p
                return end, path[::-1], d
            for key, v, c in self.neighbours(u):
                if d + c < dist.get(v, 1 << 30):
                    dist[v] = d + c
                    prev[v] = (key, u)
                    heapq.heappush(heap, (d + c, v))
        return None

    @staticmethod
    def in_reach(s, hx, hrow):
        """try_trigger's reach test, with its 8-bit wrap."""
        _, x, y = s
        return (hx - ((x - 1) & 255)) & 255 < 4 and (hrow - ((y - 4) & 255)) & 255 < 6


def plan(b):
    """Returns (script lines, estimated frames)."""
    armed = [[True] * len(h) for h in b.hazards]
    marked = [False] * len(b.names)
    s = b.start
    lines, frames, shot = [], 0, {s[0]}

    def reachable_armed(u):
        return [j for j, (hx, hrow, _) in enumerate(b.hazards[u[0]])
                if armed[u[0]][j] and b.in_reach(u, hx, hrow)]

    def goal(u):
        r = u[0]
        return bool(reachable_armed(u)) or (not marked[r] and not any(armed[r]))

    def walk(path):
        """Hold each key for its run of steps."""
        i = 0
        while i < len(path):
            key = path[i][0]
            while i + 1 < len(path) and path[i + 1][0] == key:
                i += 1
            r, x, y = path[i][1]
            lines.append(f"goto {r} {x} {y} {key}")
            if r not in shot:
                shot.add(r)
                lines.append(f"shot route_{b.label[4:]}_{b.names[r]}")
            i += 1

    lines.append(f"shot route_{b.label[4:]}_{b.names[s[0]]}")
    while not all(marked):
        found = b.path_to(s, goal)
        if not found:
            unreached = [(b.names[r], h) for r in range(len(b.names))
                         for j, h in enumerate(b.hazards[r]) if armed[r][j]]
            sys.exit(f"{b.src}: can't reach {unreached or 'every room'} from {b.names[s[0]]} {s[1:]}")
        s, path, cost = found
        walk(path)
        frames += cost
        # Fire sets off the first armed hazard in reach, in list order: one press each.
        for j in reachable_armed(s):
            hx, hrow, t = b.hazards[s[0]][j]
            lines.append(f"run 1 fire                      ; {t} at {hx},{hrow}")
            lines.append("until pl_state 0 -")
            armed[s[0]][j] = False
            frames += VIGNETTE
        if not any(armed[s[0]]) and not marked[s[0]]:
            lines.append(f"run 1 mark                      ; sign off {b.names[s[0]]}")
            marked[s[0]] = True
    def at_exit(u):             # building.asm at_exit: the door's bottom under either foot
        r, x, y = u
        return EXIT_DOOR in (b.cell(r, x, y + 1), b.cell(r, x + 1, y + 1))

    found = b.path_to(s, at_exit)
    if not found:
        sys.exit(f"{b.src}: can't get back to the exit")
    s, path, cost = found
    walk(path)
    frames += cost
    return lines, frames


def main(argv):
    if len(argv) != 3:
        sys.exit(__doc__)
    src, dst = argv[1], argv[2]
    b = Building(src)
    body, frames = plan(b)
    n_haz = sum(len(h) for h in b.hazards)
    evidence = any(t == 'evidence' for h in b.hazards for _, _, t in h)
    out = [f"; Generated by tools/route.py from {src}. Do not edit.",
           f"; A clean run: every hazard set off, every room signed off, out through the exit.",
           f"; {len(b.names)} rooms, {n_haz} hazards; estimated {frames} frames "
           f"({frames / 50:.0f} s of a {b.clock} s clock).",
           f"pokew campaign_single+1 {b.label}",
           "pokew boot_campaign campaign_single",
           "run 5",
           "run 1 fire                      ; title: start",
           "run 3",
           "run 1 fire                      ; skip the outdoor intro",
           "until game_state 0 -"]
    out += body
    out += ["run 1",
            "run 1 up                        ; out through the door",
            "expect pl_state 2",
            "until game_state 1 - 3000      ; outro, then the results",
            "print clock_hi 2",
            "print score 3",
            "expect outcome 0",
            "expect miss_tally 0",
            "expect energy 16",
            f"expect evidence {12 if evidence else 0}"]
    for r in range(len(b.names)):
        for j in range(len(b.hazards[r])):
            out.append(f"expect {b.label}_{r}+{b.hazard_state_offset(r, j)} 1")
    out.append(f"shot route_{b.label[4:]}_results")
    open(dst, 'w').write('\n'.join(out) + '\n')
    print(f"{dst}: {len(body)} steps, estimated {frames / 50:.0f} s (clock {b.clock} s)")


if __name__ == '__main__':
    main(sys.argv)
