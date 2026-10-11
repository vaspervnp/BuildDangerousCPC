# Build Dangerous

A comedy hazard-inspection game for the Amstrad CPC (64K, Mode 1 — 320×200, 4 colours).

Inspector Thanos — immortal, deadpan, running out of contract renewals — has to sweep every room of a building before the owner cuts the ribbon and the crowd walks in. Disarming a trap means setting it off: he gets bitten, electrocuted, drowned, flattened, or otherwise comically wrecked. He always gets back up. The real mistake is a **Miss** — marking a room safe while a trap is still live in it — which costs far more Reputation Energy than any slapstick hit.

Bilingual: **English (default) and Greek**, toggled with **L** from the main menu.

- [scenario.md](scenario.md) — story, characters, the 12 trap types, the 5-building campaign, win/lose conditions, tone.
- [plan.md](plan.md) — technical plan: memory budget, sprite specs (16×16 characters, 8×8 hazard "tells"), room/level data format, game systems, content pipeline, build milestones.

## Status

**Milestone 3 (mark-safe / Miss / exit gate) done — the core loop is complete.** Thanos walks a side-view building, sets off live hazards with Fire to disarm them (vignette, typed caption in English or Greek, one hard hat of energy), signs rooms off with M / Fire 2, and can only leave through the exit door once every room is signed off. Signing off a room that still has a live hazard is a Miss: two hard hats, an orange border flash, and a mark on the tally. One hazard type and one room so far, placeholder art. Next up: milestone 4, the remaining 11 hazard types.

| Area | Status |
|---|---|
| Scenario / narrative | Drafted |
| Technical plan | Drafted |
| Engine (Z80 ASM) | Milestones 1–3 done: boot, video, tiles, masked 16×16 and 8×8 sprites, input, room RLE, movement, hazards, vignettes, building/rooms, sign-off, exit |
| Hazards | 1 of 12 types (electrocution); generic vignette player, so the rest are mostly data |
| Mark-safe / Miss / exit gate | Done: per-room signed-off bits, Miss tally, exit door gate |
| Tile/sprite art | Placeholder: 17 tiles, 4 Thanos frames (+4 mirrored), 3 vignette frames, 2 hazard sprites |
| Level data (5 buildings) | One test building: one room, 3 live and 3 safe sockets, an exit door |
| HUD | Energy hats, current-room checkbox, typed caption line; clock/score/miss-tally display not started |
| Font / localization (EN/GR) | 56-glyph capitals font (Latin + Greek), EN/GR string tables, language flag; L key waits for the title menu |
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

Runs the game headless on an emulated Z80 (`tools/cpcrun.py`) once per script in `tests/`: holds keys for a number of game-loop iterations, checks variables (position, energy, hazard states), saves screenshots to `build/shots/`, and reports the worst per-frame CPU use. Currently 65 checks across 4 scripts, all passing; worst frame ~34% of the 50Hz budget.

## Controls

| Action | Keyboard | Joystick |
|---|---|---|
| Move / climb | Cursor keys or Q A O P | Stick |
| Trigger hazard | Space | Fire 1 |
| Sign off the current room | M | Fire 2 |
| Leave the building (at the exit door) | Up | Up |
| Toggle language (menu) | L | — |

## Layout

| Path | Contents |
|---|---|
| `src/` | Z80 source (rasm). `main.asm` includes everything else. |
| `assets/gfx/` | `.aseprite` sources (edit these) and their `.png` exports (what the build reads). |
| `assets/rooms/` | Room layouts as 40×23 text grids plus `hazard <type> <x> <row>` lines; legend in `tools/cpcgfx.py`. |
| `assets/text/strings.txt` | Every in-game string, `ID \| English \| Greek`. |
| `tools/cpcgfx.py` | PNG → CPC Mode 1 tiles / masked sprites, room text → RLE + hazard list, strings → `build/strings.asm`. |
| `tools/cpcrun.py` | Headless CPC test harness. |
| `tools/art/gen_placeholder_art.lua` | Aseprite script that created the placeholder art. Set `ONLY = { name = true }` to regenerate a single asset; re-running an asset overwrites hand edits to it. |
| `tests/` | Harness scripts. |

## Decisions

- **Side-view building cross-section.** Each room is one screen showing a slice of the building: floors are horizontal slabs, ladders join floors, Thanos walks left/right, climbs up/down and falls if nothing is under him. Picked over top-down because most gags are vertical (falling chandeliers, being catapulted through the roof, rising flood water) and it matches the "multistory building" opening scene.
- **Load address #1000**, firmware discarded after load; stack at #C000 down.
- **Capitals-only font.** All text is upper case; Greek accents are dropped (all-caps Greek is normally written without them anyway). Greek letters shaped like Latin ones reuse the Latin glyph, so the whole font is 56 glyphs.
- **Captions are typed out** a couple of characters per frame rather than printed in one go: printing a full line plus starting a vignette in a single frame went over the 50Hz budget, and the typewriter delivery suits the deadpan tone.
- **Signed-off flags are one bit per room in a building-wide bitfield** (`bld_marked`), not stored in room data. A room's outcome (clean or Miss) is fixed the first time it is signed off; pressing M again only says it is already signed off.
- **Leaving = Up at the exit door**, like entering any door, so it can't happen by walking past it.
- **Vignettes are full 16×16 frames** (128 bytes each) rather than FX overlays on the walk frames, for now: three frames for electrocution. If RAM gets tight once all 12 are in, frames can be shared between hazards first.

## Log

- 2026-10-11 — Initial scenario.md and plan.md written. Sprite sizes clarified: characters 16×16, trap "tell" objects 8×8.
- 2026-10-11 — Added bilingual EN/GR requirement: L toggles language from the main menu, English is the default. Plan updated with a custom Latin+Greek 8×8 font, parallel EN/GR string tables, and the memory-budget impact.
- 2026-10-11 — Confirmed tooling in plan.md: Aseprite (MCP) for all tile/sprite art, Blender (MCP) as an optional 3D reference aid for tricky vignette poses, rasm for assembly, iDSK for building the .dsk image.
- 2026-10-11 — Core loop reworked: triggering a hazard (Fire) always disarms it and always costs a small fixed energy hit — that's just the job, not a failure. The real mistake is a **Miss**: using the separate "mark room safe" action while a hazard is still armed in that room, which costs more energy and adds to a per-building miss tally. Rooms can be re-checked freely; the building exit only requires every room to have been marked at some point (full sweep mandatory), while the miss tally (not coverage %) now grades the ending. Replaces the earlier "pass-threshold %" and "clean inspect vs. failed inspect" framing in both scenario.md and plan.md.
- 2026-10-11 — **Milestone 1 implemented.** Engine skeleton in Z80 (rasm), asset converter, Makefile producing `build/bd.dsk`, headless test harness with a 12-check smoke test (all passing). Placeholder art authored through Aseprite. Chose a side-view cross-section layout (see Decisions). Worst frame currently uses ~17% of the 50Hz budget.
- 2026-10-11 — **Milestone 2 implemented.** Hazard list in room data (state written back into it, so rooms remember what was disarmed), 8×8 masked tell sprites, reach test on Fire, data-driven vignette player (frames, hold times, screen-flash FX), electrocution vignette, energy hats in the HUD, custom Latin+Greek font, EN/GR string tables generated from `assets/text/strings.txt`, typed caption line. Harness now counts game-loop iterations (deterministic tests), supports `poke`, and pointer-relative addresses. Fixed a frame overrun (109% → 33%) by typing captions out over several frames.
- 2026-10-11 — **Milestone 3 implemented.** Building structure (room list, entering a room by index), signed-off bitfield, M / Fire 2 to sign off, Miss detection (any armed hazard left → −2 energy, tally +1, orange border flash), exit door tile with the all-rooms-signed-off gate, HUD checkbox for the current room. Two new test scripts (Miss path and clean sweep); 65 checks pass.

---

*This file is kept up to date as the project progresses — check here first for current status before diving into scenario.md/plan.md.*
