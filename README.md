# Build Dangerous

A comedy hazard-inspection game for the Amstrad CPC (64K, Mode 1 — 320×200, 4 colours).

Inspector Thanos — immortal, deadpan, running out of contract renewals — has to sweep every room of a building before the owner cuts the ribbon and the crowd walks in. Disarming a trap means setting it off: he gets bitten, electrocuted, drowned, flattened, or otherwise comically wrecked. He always gets back up. The real mistake is a **Miss** — marking a room safe while a trap is still live in it — which costs far more Reputation Energy than any slapstick hit.

Bilingual: **English (default) and Greek**, toggled with **L** from the main menu.

- [scenario.md](scenario.md) — story, characters, the 12 trap types, the 5-building campaign, win/lose conditions, tone.
- [plan.md](plan.md) — technical plan: memory budget, sprite specs (16×16 characters, 8×8 hazard "tells"), room/level data format, game systems, content pipeline, build milestones.

## Status

**Milestone 1 (engine skeleton) done.** Boots on a bare machine (firmware and ROMs off), Mode 1 with a 4-ink palette, renders a tile-based test room, and Thanos walks, climbs ladders and falls with gravity. Uses placeholder art. Next up: milestone 2, the hazard-trigger loop.

| Area | Status |
|---|---|
| Scenario / narrative | Drafted |
| Technical plan | Drafted |
| Engine (Z80 ASM) | Milestone 1 done: boot, video, tiles, masked 16×16 sprites, input, room RLE, movement |
| Tile/sprite art | Placeholder: 10 tiles, 4 Thanos frames (+4 mirrored) |
| Hazards / mark-safe / exit gate | Not started (milestones 2–3) |
| Level data (5 buildings) | One test room |
| HUD / font / localization (EN/GR) | Not started |
| Audio | Not started |

## Building

Requirements: `rasm`, `iDSK`, `make`, Python 3 with Pillow, and the `z80` package (`pip install z80`) for the test harness.

```bash
make
```

Produces `build/bd.dsk`. In an emulator (CPCEC, Caprice32, Arnold, WinAPE…) or on real hardware, insert the disk and type `RUN"BD`.

```bash
make test
```

Runs the game headless on an emulated Z80 (`tools/cpcrun.py`), plays the scripted walk in `tests/smoke.txt`, checks Thanos's position at each step, saves screenshots to `build/shots/`, and reports the worst per-frame CPU use.

## Controls

| Action | Keyboard | Joystick |
|---|---|---|
| Move / climb | Cursor keys or Q A O P | Stick |
| Trigger hazard (milestone 2) | Space | Fire 1 |
| Mark room safe (milestone 3) | M | Fire 2 |
| Toggle language (menu) | L | — |

## Layout

| Path | Contents |
|---|---|
| `src/` | Z80 source (rasm). `main.asm` includes everything else. |
| `assets/gfx/` | `.aseprite` sources (edit these) and their `.png` exports (what the build reads). |
| `assets/rooms/` | Room layouts as 40×23 text grids; legend in `tools/cpcgfx.py`. |
| `tools/cpcgfx.py` | PNG → CPC Mode 1 tiles / masked sprites, room text → RLE. |
| `tools/cpcrun.py` | Headless CPC test harness. |
| `tools/art/gen_placeholder_art.lua` | One-shot Aseprite script that created the placeholder art. Re-running it overwrites hand edits. |
| `tests/` | Harness scripts. |

## Decisions

- **Side-view building cross-section.** Each room is one screen showing a slice of the building: floors are horizontal slabs, ladders join floors, Thanos walks left/right, climbs up/down and falls if nothing is under him. Picked over top-down because most gags are vertical (falling chandeliers, being catapulted through the roof, rising flood water) and it matches the "multistory building" opening scene.
- **Load address #1000**, firmware discarded after load; stack at #C000 down.

## Log

- 2026-10-11 — Initial scenario.md and plan.md written. Sprite sizes clarified: characters 16×16, trap "tell" objects 8×8.
- 2026-10-11 — Added bilingual EN/GR requirement: L toggles language from the main menu, English is the default. Plan updated with a custom Latin+Greek 8×8 font, parallel EN/GR string tables, and the memory-budget impact.
- 2026-10-11 — Confirmed tooling in plan.md: Aseprite (MCP) for all tile/sprite art, Blender (MCP) as an optional 3D reference aid for tricky vignette poses, rasm for assembly, iDSK for building the .dsk image.
- 2026-10-11 — Core loop reworked: triggering a hazard (Fire) always disarms it and always costs a small fixed energy hit — that's just the job, not a failure. The real mistake is a **Miss**: using the separate "mark room safe" action while a hazard is still armed in that room, which costs more energy and adds to a per-building miss tally. Rooms can be re-checked freely; the building exit only requires every room to have been marked at some point (full sweep mandatory), while the miss tally (not coverage %) now grades the ending. Replaces the earlier "pass-threshold %" and "clean inspect vs. failed inspect" framing in both scenario.md and plan.md.
- 2026-10-11 — **Milestone 1 implemented.** Engine skeleton in Z80 (rasm), asset converter, Makefile producing `build/bd.dsk`, headless test harness with a 12-check smoke test (all passing). Placeholder art authored through Aseprite. Chose a side-view cross-section layout (see Decisions). Worst frame currently uses ~17% of the 50Hz budget.

---

*This file is kept up to date as the project progresses — check here first for current status before diving into scenario.md/plan.md.*
