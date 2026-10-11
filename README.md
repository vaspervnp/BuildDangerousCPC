# Build Dangerous

A comedy hazard-inspection game for the Amstrad CPC (64K, Mode 1 — 320×200, 4 colours).

Inspector Thanos — immortal, deadpan, running out of contract renewals — has to sweep every room of a building before the owner cuts the ribbon and the crowd walks in. Disarming a trap means setting it off: he gets bitten, electrocuted, drowned, flattened, or otherwise comically wrecked. He always gets back up. The real mistake is a **Miss** — marking a room safe while a trap is still live in it — which costs far more Reputation Energy than any slapstick hit.

Bilingual: **English (default) and Greek**, toggled with **L** from the main menu.

- [scenario.md](scenario.md) — story, characters, the 12 trap types, the 5-building campaign, win/lose conditions, tone.
- [plan.md](plan.md) — technical plan: memory budget, sprite specs (16×16 characters, 8×8 hazard "tells"), room/level data format, game systems, content pipeline, build milestones.

## Status

**Engine and campaign done — a full game loop from title screen to ending, with one of the five buildings.** The title screen offers English or Greek (L). Outside, the owner of Sunny Vale Apartments gives his speech in front of the crowd and Thanos walks in. Inside: four flip-screen rooms (two wings, six floors) joined at their edges and by ladders through ceilings and floors, with 8 traps. Thanos sets off live hazards with Fire to disarm them (vignette, typed caption in English or Greek, half a hard hat of energy), signs rooms off with M / Fire 2, and can only leave through the lobby's exit door once every room is signed off. Signing off a room that still has a live hazard is a Miss: two hard hats, an orange border flash, and a mark on the tally. The crowd's patience runs down on a clock; the building ends in a win (graded by Misses), a soft fail (time up with half the rooms signed off), or a fail (time up with less, or energy gone). Each ending plays out outside — ribbon cut and cheering, an embarrassed postponement, the crowd filing in anyway, or Thanos thrown out of his own inspection — before the results panel. After the results, the campaign moves on to the next building, or ends: "terminated", or the good ending (worded differently if Thanos found the owner's insurance papers). All 12 trap types exist, with placeholder art. Next up: the remaining four buildings (Big Box Mall, Grand Hotel, Mega Hospital, the Skyscraper with the papers).

| Area | Status |
|---|---|
| Scenario / narrative | Drafted |
| Technical plan | Drafted |
| Engine (Z80 ASM) | Milestones 1–5 done: boot, video, tiles, masked 16×16 and 8×8 sprites, input, room RLE, movement, hazards, vignettes, multi-room buildings with edge/ladder transitions, sign-off, exit |
| Hazards | All 12 types, each with its tell, disarmed look, vignette and EN/GR caption |
| Mark-safe / Miss / exit gate | Done: per-room signed-off bits, Miss tally, exit door gate |
| Tile/sprite art | Placeholder: 32 tiles, 10 outdoor people frames, 4 Thanos frames (+4 mirrored), 36 vignette frames, 24 hazard sprites |
| Level data (5 buildings) | 1 of 5: Sunny Vale Apartments (4 rooms, 8 traps). Plus test buildings `test` and `gallery` (which also holds the evidence). |
| HUD | Energy (8 hats, half-hat steps), current-room checkbox, rooms signed off, Miss tally, clock dial + seconds, 6-digit score, typed caption line |
| Outcomes | Win (clean / a few misses / barely), soft fail, two fails; results panel with bonuses; Fire restarts the building (campaign comes in milestone 8) |
| Outdoor scene | Shared ribbon-cutting scene with per-building sign and welcome; scripted intro and one outro per ending; Fire skips |
| Campaign | Title screen (L: English/Greek), building progression with energy refill, game over, good ending (two versions), evidence pickup, session hi-score |
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

Runs the game headless on an emulated Z80 (`tools/cpcrun.py`) once per script in `tests/`: holds keys for a number of game-loop iterations, checks variables (position, energy, hazard states), saves screenshots to `build/shots/`, and reports the worst per-frame CPU use. Currently 261 checks across 7 scripts, all passing; worst gameplay frame ~39% of the 50Hz budget (room switches and the results panel take several frames, behind a blanked or static screen). `tests/gallery.txt` sets off every trap type and saves a mid-gag screenshot of each; `tests/sunnyvale.txt` plays Sunny Vale from start to exit.

## Controls

| Action | Keyboard | Joystick |
|---|---|---|
| Move / climb | Cursor keys or Q A O P | Stick |
| Trigger hazard | Space | Fire 1 |
| Sign off the current room | M | Fire 2 |
| Leave the building (at the exit door) | Up | Up |
| Toggle language (title screen) | L | — |
| Start / skip a scene / continue | Space | Fire 1 |

## Layout

| Path | Contents |
|---|---|
| `src/` | Z80 source (rasm). `main.asm` includes everything else. |
| `assets/gfx/` | `.aseprite` sources (edit these) and their `.png` exports (what the build reads). |
| `assets/buildings/` | Buildings: which rooms, how they connect (`left=`/`right=`/`up=`/`down=`), start position. The converter checks that neighbours' edges and ladders line up. |
| `assets/rooms/` | Room layouts as 40×23 text grids plus `hazard <type> <x> <row>` lines; legend in `tools/cpcgfx.py`. |
| `assets/text/strings.txt` | Every in-game string, `ID \| English \| Greek`. |
| `tools/cpcgfx.py` | PNG → CPC Mode 1 tiles / masked sprites, building + room text → `build/bld_*.asm`, strings → `build/strings.asm`. |
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
- **Vignettes are full 16×16 frames** (128 bytes each) rather than FX overlays on the walk frames: 36 frames for all 12 traps, 4.6K. The cheap "big" effects come from recolouring the background pen for a step (flood, gas, fire, ice, impact) and from moving the frame up through the floors, not from extra art.
- **Tests choose the campaign** by poking `boot_campaign` before the first frame (`pokew boot_campaign campaign_gallery`); the game's own is `campaign_main`.
- **Energy carries over between buildings**, plus a 3-hat refill; a soft fail still moves on, a fail is game over. Milestone order was swapped: the campaign came before the remaining buildings so each new building drops into a working game.
- **Energy is 16 units shown as 8 hard hats**: a trap costs half a hat, a Miss two hats. With whole-hat steps the 8-trap tutorial would have emptied the bar on a perfect run.
- **Flip-screen rooms.** Walking off a side edge or climbing a ladder off the top/bottom of the screen enters the neighbouring room; the screen is blanked (all inks black) while the new room draws, about a quarter of a second. Speeding up the full-room redraw is the first optimisation candidate if that feels slow on real hardware.
- **Scoring:** +50 per trap disarmed, +100 per clean sign-off, −200 per Miss; winning adds seconds left ×10, energy ×25 and +500 for no Misses. Score, clock, tallies are BCD so they print without division.
- **The opening is in the evening.** Mode 1's 4 inks keep pen 0 black (it is everyone's outline), so the outdoor scene is a night-time grand opening with the building's name lit up, rather than a raster colour split for a blue sky.
- **Fire skips scenes**, the intro and every outro alike.
- **Soft fail threshold is half the rooms** signed off when the clock runs out; below that the ribbon is cut with the building unchecked.
- **Room data is generated per building** into one assembly file with the room records (data pointer + left/right/up/down neighbours) and the rooms' data, so hazard states live in RAM per building.

## Log

- 2026-10-11 — Initial scenario.md and plan.md written. Sprite sizes clarified: characters 16×16, trap "tell" objects 8×8.
- 2026-10-11 — Added bilingual EN/GR requirement: L toggles language from the main menu, English is the default. Plan updated with a custom Latin+Greek 8×8 font, parallel EN/GR string tables, and the memory-budget impact.
- 2026-10-11 — Confirmed tooling in plan.md: Aseprite (MCP) for all tile/sprite art, Blender (MCP) as an optional 3D reference aid for tricky vignette poses, rasm for assembly, iDSK for building the .dsk image.
- 2026-10-11 — Core loop reworked: triggering a hazard (Fire) always disarms it and always costs a small fixed energy hit — that's just the job, not a failure. The real mistake is a **Miss**: using the separate "mark room safe" action while a hazard is still armed in that room, which costs more energy and adds to a per-building miss tally. Rooms can be re-checked freely; the building exit only requires every room to have been marked at some point (full sweep mandatory), while the miss tally (not coverage %) now grades the ending. Replaces the earlier "pass-threshold %" and "clean inspect vs. failed inspect" framing in both scenario.md and plan.md.
- 2026-10-11 — **Milestone 1 implemented.** Engine skeleton in Z80 (rasm), asset converter, Makefile producing `build/bd.dsk`, headless test harness with a 12-check smoke test (all passing). Placeholder art authored through Aseprite. Chose a side-view cross-section layout (see Decisions). Worst frame currently uses ~17% of the 50Hz budget.
- 2026-10-11 — **Milestone 2 implemented.** Hazard list in room data (state written back into it, so rooms remember what was disarmed), 8×8 masked tell sprites, reach test on Fire, data-driven vignette player (frames, hold times, screen-flash FX), electrocution vignette, energy hats in the HUD, custom Latin+Greek font, EN/GR string tables generated from `assets/text/strings.txt`, typed caption line. Harness now counts game-loop iterations (deterministic tests), supports `poke`, and pointer-relative addresses. Fixed a frame overrun (109% → 33%) by typing captions out over several frames.
- 2026-10-11 — **Milestone 3 implemented.** Building structure (room list, entering a room by index), signed-off bitfield, M / Fire 2 to sign off, Miss detection (any armed hazard left → −2 energy, tally +1, orange border flash), exit door tile with the all-rooms-signed-off gate, HUD checkbox for the current room. Two new test scripts (Miss path and clean sweep); 65 checks pass.
- 2026-10-11 — **Milestone 4 implemented.** The other 11 traps: bitten, drowned, hit on the head, cut in half, impaled, squashed, incinerated, frozen, poisoned, sucked up, catapulted. Each has an 8×8 tell and disarmed sprite, a scripted vignette and an EN/GR caption. The vignette player gained background-recolour FX and vertical movement (the catapult throws Thanos up through the floors above). New `gallery` test room and test script; 127 checks pass. Binary is 12.8K, ~25K free below the load limit.
- 2026-10-11 — **Milestone 5 implemented.** Buildings are defined in `assets/buildings/*.txt` and converted with their rooms into `build/bld_*.asm` (layout checks: matching edges between side-by-side rooms, ladders lining up between stacked rooms). Flip-screen transitions at all four edges, room exits per room, out-of-room cells treated as solid. First real building: Sunny Vale Apartments, 4 rooms / 6 floors / 8 traps with safe-socket decoys; the game now boots into it. Energy changed to half-hat steps. New full-playthrough test; 191 checks pass.
- 2026-10-11 — **Milestone 6 implemented.** Outside clock (per-building `clock`, BCD seconds, 9-state dial), 6-digit BCD score with disarm/sign-off/Miss scoring and win bonuses, HUD for rooms signed off and the Miss tally, per-building `misses_ok` grading. Win / soft-fail / two fail outcomes with a results panel (EN/GR); Fire restarts the building with every hazard re-armed. New `tests/outcomes.txt`; 224 checks pass. Binary 16.1K.
- 2026-10-11 — **Milestone 7 implemented.** Outdoor ribbon-cutting scene: shared tile room, facade sign and owner's welcome per building (`sign` / `welcome`), owner and townsfolk sprites (Aseprite), a byte-code scene engine with 6 actors. Intro (speech, Thanos walks in) and an outro per ending, then the results panel over the scene. Harness: boot no longer counts as a game loop. 234 checks pass. Binary 19.6K.
- 2026-10-11 — **Campaign implemented** (plan milestone 9, done before the buildings). Title screen with double-size logo, L to switch English/Greek, controls and hi-score. Campaign table: wins and soft fails move on with an energy refill, fails go to a "terminated" game-over screen, winning the last building shows the ending (two versions, depending on the evidence). New `evidence` object type (+500, no energy, never a Miss). 261 checks pass. Binary 21.5K.

---

*This file is kept up to date as the project progresses — check here first for current status before diving into scenario.md/plan.md.*
