# Build Dangerous — Technical Plan (Amstrad CPC, 64K)

## Target & Constraints

- **Machine:** Amstrad CPC 464/664/6128-class, 64K RAM, Z80 @ 4MHz.
- **Video mode:** Mode 1 — 320×200 visible, 4 colours (2 bits/pixel), firmware palette of 4 inks selected from the 27-colour hardware set.
- **Screen RAM:** fixed 16K (0xC000–0xFFFF) regardless of mode (CPC screen addressing is bit-packed, not linear-by-pixel). This is non-negotiable overhead; budget the rest of the plan around **~48K for code + data + sound + stack**.
- **Sprites:**
  - **Characters** (Thanos, building owner, crowd extras): **16×16 pixels.**
  - **Hazard "tell" objects / triggers** (frayed wire, loose grille, wet patch, crooked sign, chemical drum, switch, vent cover, etc.): **8×8 pixels.** These are the things the player visually scans rooms for — keeping them small keeps the per-room object budget and the art budget both low, and matches how fine-grained the "spot the difference" tell needs to be against an 8×8 background tile grid.
  - All backgrounds are built from **8×8 tiles**, so 8×8 hazard objects drop directly onto the tile grid with no sub-tile alignment work; 16×16 character sprites occupy a 2×2 tile footprint and need the usual background-restore handling.

## Memory Budget (approximate)

| Region | Size | Contents |
|---|---|---|
| Screen RAM | 16,384 B | Mode 1 framebuffer |
| Firmware/system reserved | ~1–2K (if firmware kept resident) or 0 if disabled | jump blocks, low memory vectors |
| Code (Z80 ASM) | ~10–14K | engine, game logic, state machines |
| Tile graphics (8×8, 4-colour) | ~3–6K | shared across all 5 buildings, re-palette rather than re-draw where possible |
| Character sprites (16×16) | ~2–3K | Thanos (4–6 frames ×4 directions), owner, 2–3 crowd variants |
| Hazard sprites (8×8) | ~1–2K | ~12 tell-objects × 2–3 frames each (idle tell + triggered flash) |
| Trap vignette animation frames | ~4–6K | short 3–5 frame comic-hit sequences, reusing 16×16 Thanos sprite sheet with overlays |
| Level/room data (compact) | ~2–4K | tile maps + hazard placement tables for ~5 buildings × ~6 rooms each |
| Sound data (AY PSG) | ~1–2K | SFX table + 1 short jingle |
| Text / string tables (EN + GR) + custom font | ~2–3K | all captions, menus, and dialogue duplicated per language; custom 8×8 font needed for Greek glyphs (see Localization) |
| Stack + variables + buffers | ~2K | |
| **Total** | **~48–53K** | tight against the ~48K non-screen budget — localization is the main thing to watch; trim caption count/length first if over |

Keeping both sprite classes small (8×8 and 16×16 only, no 32×32 anywhere) is what makes this budget work — it's the single biggest lever against running out of RAM on this hardware.

## Screen Layout (in-building gameplay)

- **Play area:** full 320×200 Mode 1 framebuffer, no separate HUD strip reserved — HUD is drawn as a thin overlay band (e.g. top 16 rows: energy icons + room clock) composited over the tile background, since a dedicated status panel would eat too much of the already-small visible area on this resolution.
- **View:** side-view cross-section of the building. Floors are horizontal slabs, ladders/stairwells join floors; Thanos walks left/right, climbs with up/down, and falls when nothing is under his feet. Suits the vertical gags (falling fixtures, catapulted through the roof, rising water).
- **Room size:** one screen = one room (40×25 tiles of 8×8 = 320×200; the top 2 tile rows are the HUD band, so room data is 40×23). No scrolling engine required — rooms are connected via doorways/stairs that cut to the adjacent room's static screen. This avoids writing/debugging a smooth-scroll engine on top of everything else, which is the right tradeoff for a 64K one-dev-team scope.
- **Outdoor ribbon-cutting scene:** a separate, simpler static screen template (owner + stage + crowd + countdown dial), reused across all 5 buildings with swapped owner sprite/name and dialogue string only.

## Controls

- **Joystick/directions:** 4-way movement, tile-aligned.
- **Fire:** on an armed hazard's tile, triggers that hazard — disarm + vignette + fixed energy cost (see Core Systems §2–3). Does nothing on empty floor.
- **Mark-safe action (second fire button, or a dedicated key on keyboard):** declares the current room safe. Checks for any remaining armed hazard in the room (Miss if so), sets the room's `marked` bit either way. Deliberately a different input than Fire so "disarm this hazard" and "I'm done with this room" can never be pressed by accident for each other.
- **L (keyboard, menu only):** toggles English/Greek (see Localization).

## Core Systems

### 1. Room / Level Data Format

Each room is defined by a compact structure to keep the 5-building campaign inside a few KB:

```
Room {
  tile_map_id      ; index into shared tileset bank (8x8 tiles, 40x25 = 1000 cells, RLE-packed)
  hazard_count     ; 0-6 per room
  hazards[6] {
    tile_x, tile_y     ; placement on the 8x8 grid
    hazard_type        ; 0-11, see Hazard Table
    tell_sprite_id      ; which 8x8 "tell" graphic variant to draw
    state               ; armed / disarmed
  }
  marked           ; 1 bit: has this room been declared safe yet? (see Inspection & Exit Gating)
  exits[4]          ; N/S/E/W -> room_id or 0xFF (none), matches stairwell/door tile position
}
```

- Tile maps are RLE-compressed (buildings reuse a handful of tile types: floor, wall, door, stairs, carpet, pipe-run, etc.) and decompressed into a small working tile-index buffer on room entry, not held fully expanded for every room simultaneously.
- Hazard placement tables are authored per room (hand-placed for puzzle fairness) rather than randomly generated — this is a "spot the difference" game, so hand-tuned tells matter more than procedural variety.
- The `marked` bits for every room in a building are also mirrored into one small building-wide bitfield (≤1 byte per 8 rooms) so the exit check (below) is a single cheap scan rather than walking the room table.

### 2. Hazard / Trap Table (12 types)

| ID | Trap | Tell (8×8 object) | Vignette (uses 16×16 Thanos sheet + FX) |
|---|---|---|---|
| 0 | Bitten | scratched grille tile | leg-shake, 3 frames |
| 1 | Electrocuted | bare wire behind switch | spark flash + hair-stand, 3 frames |
| 2 | Drowned | damp patch under closet door | flood splash + duck pop-up, 4 frames |
| 3 | Hit on head | zip-tie glint on fixture above | squash-and-pop, 3 frames |
| 4 | Cut in half | mistimed lift-door icon | split/rejoin, 4 frames |
| 5 | Impaled | stapled cushion seam | yelp + patch overlay, 2 frames |
| 6 | Squashed | mislabeled door icon | accordion-squash, 3 frames |
| 7 | Incinerated | gas-leak wisp near pilot light | fireball + soot palette-swap, 4 frames |
| 8 | Frozen | frost crack on freezer handle | ice-block + shatter, 4 frames |
| 9 | Poisoned | drip under "cleaning supplies" sign | green palette-swap + wobble, 3 frames |
| 10 | Sucked up | missing vent grille | stretch-into-duct, 3 frames |
| 11 | Catapulted | frayed cable glint | launch-up + fall-back, 4 frames |

- Each vignette is **short (2–4 frames, <1s at 50Hz)** and built by overlaying small FX sprites (spark, splash, soot, ice) on the existing Thanos 16×16 sheet rather than drawing full new character frames per trap — this is the main art-cost control for having 12 distinct gags.
- A one-line deadpan caption string prints in the HUD band on trigger, pulled from a small string table (shared, not per-room) to keep text data minimal.
- **Triggering a hazard is how it gets disarmed — there is no clean/silent disarm.** Pressing Fire while on/adjacent to an armed hazard's tile always plays its vignette, always costs a small fixed energy amount, and always sets that hazard's state to `disarmed` in the same action. There's no success/fail roll on the interaction itself — the "fail state" in this game is a **Miss** (see below), not a fumbled disarm.

### 3. Player State Machine

```
States: IDLE_WALK, TRIGGERED(trap_id), MARKING_SAFE, TRANSITION(room)
```

- **IDLE_WALK:** 4-direction movement at tile-aligned steps (moves in 8px increments matching the tile grid — simplifies both collision and background-restore, since the 16×16 sprite is always tile-aligned).
- **TRIGGERED:** entered by pressing Fire on an armed hazard tile. Plays the matching vignette (input locked, ~0.5–1s), deducts the fixed hazard-trigger energy cost, sets that hazard to `disarmed`, shows the caption, returns to IDLE_WALK.
- **MARKING_SAFE:** entered by the dedicated "mark room safe" action (see Inspection & Exit Gating below) while standing in a room. Checks the room's hazard list; if any hazard is still `armed`, this is a **Miss** — bigger energy deduction, miss-tally increment, its own short caption/sting (no injury vignette; this is a professional-judgment failure, not a slapstick one). Either way (Miss or clean), the room's `marked` bit is set and control returns to IDLE_WALK — a room's outcome is locked in on its *first* successful mark, so freely re-issuing the action afterwards on an already-marked room is a no-op (prevents tally-farming or reward-farming by spamming the action).
- **TRANSITION:** on reaching a door/stair tile, swap room data + redraw screen.

### 4. Inspection & Exit Gating

- **Mark-safe action:** a dedicated control, distinct from Fire-on-hazard (see Controls) — usable anywhere inside the current room, any number of times per visit, and the player can leave and come back to a still-unmarked room with no penalty for waiting. This is the deliberate "I'm calling it" action separate from disarming individual hazards.
- **Miss:** the outcome when `mark-safe` is used while the room still has an `armed` hazard. Costs more energy than a single hazard trigger and increments a per-building **miss tally** (1 byte, capped e.g. at 99) — this is the number that actually grades the building-end result (see Scoring), since exit itself no longer depends on hazard coverage.
- **Exit gate:** the building's lobby/exit tile checks the building-wide `marked` bitfield; it only lets the player leave once every room's bit is set, regardless of whether each one was a clean mark or a Miss. This makes a full sweep of the building mandatory, while leaving the player free to trade thoroughness (find everything, pay small hazard-trigger costs) against speed (call rooms safe early, risk the bigger Miss cost) room by room.

### 5. Energy, Scoring, and the Outside Clock

- **Energy:** 8-segment bar (8×8 icon strip in HUD band). Each hazard trigger = −1 segment (small, fixed); each Miss = a larger deduction (e.g. −2 or −3 segments, tuned per building); collectible "hard hat" pickups (rare, 8×8, placed like hazards but safe) restore +1.
- **Outside clock:** a frame counter started on building entry, decremented every N frames (tuned per building — tighter in later buildings), rendered as a shrinking dial in the HUD band using the same 8×8 tile trick (8-9 tile states = a clean "pie" animation with no need for rotation routines). Running out before every room is marked forces the soft-fail/fail outcome (see scenario.md) rather than blocking play outright.
- **Miss tolerance (grading, not gating):** each building defines a miss-tally threshold (e.g. ≤2 misses = clean/good grade) used only to pick the end-of-building flavour and bonus — stored as one byte per building in the campaign table. It does **not** affect whether the player is allowed to exit; the exit gate above is unconditional once all rooms are marked.
- **Scoring:** running score in a 3-byte BCD or packed-decimal counter (simplifies HUD printing via firmware-style digit lookup rather than division routines). Small `+` per hazard actually found and disarmed, larger `−` per Miss (mirrors the energy cost), and a building-complete bonus (time remaining + energy remaining + a flat "clean sweep" bonus if miss tally is zero).

### 6. Rendering / Sprite Engine

- **Background-save-and-restore** sprite drawing (not full double-buffering — no spare 16K to spare for a second screen buffer): before drawing a moving 16×16 sprite, save the 2×2 tile area it will cover into a small scratch buffer, draw, then restore-and-redraw on the next frame's old position before drawing the new one. Standard CPC sprite technique, cheap in code size.
- **8×8 hazard/tell objects** are mostly static (part of the room's drawn background) except during their own trigger animation, where the same save/restore trick applies but over a smaller 1×1 tile area — cheaper than the character case.
- **Masked blit** for both sprite sizes (sprite data + 1-bit-per-pixel mask pre-expanded to the mode's 2-bit packing) so sprites composite over tile backgrounds without a visible bounding box.
- Target **50Hz frame budget**: with tile-aligned movement (redraw only on actual grid-step, not sub-pixel), the per-frame cost is small enough that this is comfortably achievable in Z80 ASM without needing contended-memory tricks beyond the standard "do heavy work off-screen / during VBlank" discipline.

### 7. Audio

- AY-3-8912 PSG via firmware sound manager (simplest, smallest code path) rather than a hand-rolled player — budget is tiny (~1–2K of SFX data), not worth a custom player for one jingle and ~6 SFX cues (step, inspect-success chime, 12 trap-hit stings sharing a handful of underlying waveforms/pitch-shifted rather than 12 fully unique cues).

### 8. Localization (English / Greek)

- **Two supported languages: English (default) and Greek.** Language is a single global flag, checked wherever a string is printed; no separate code paths otherwise.
- **Toggle:** pressing **L** from the main menu flips the current language and immediately redraws menu text in the new language. Flag persists for the rest of the session (no save/EEPROM on this hardware); game always boots to English until L is pressed.
- **Font:** the CPC firmware font has no Greek glyphs, so the game needs its **own 8×8 font bitmap** covering basic Latin + Greek letters. All text is **capitals only**, and Greek accents are dropped (all-caps Greek is normally unaccented anyway); Greek capitals that look like Latin ones share the Latin glyph, so the font is 56 glyphs. Glyphs are stored as pen-3 Mode 1 tiles (16 bytes each, ~900 bytes total) so printing in any pen is a single AND per byte. This replaces firmware text output entirely; the game never calls the firmware VDU text routines.
- **Captions** are typed into the HUD a couple of characters per frame, which keeps the frame that starts a vignette inside the 50Hz budget.
- **String tables:** every piece of in-game text (HUD trap captions, menu labels, owner dialogue lines, ending text) is stored as **two parallel tables** (EN/GR) indexed by the same string ID, so the print routine is just "look up ID in the active-language table." Caption text is kept short (the deadpan one-liners already fit this) to keep both tables small — this is the main lever if the localization row in the memory budget runs over.
- **Authoring:** strings authored in one source file/spreadsheet with EN and GR columns side by side, packed into the two tables by the same conversion script that builds tile/sprite data — avoids hand-editing two separate binary tables.

## Content Pipeline (confirmed tooling)

1. **Tiles & sprites — Aseprite (via its MCP tool).** All 8×8 tile and hazard-tell art plus 16×16 character sprites authored directly in Aseprite at native resolution, locked to a 4-colour indexed palette per Mode 1. Aseprite's own export (indexed PNG / raw pixel data) feeds a small packer step that converts to CPC-native pixel format (2 bits/pixel, left-to-right nibble packing) and pre-generates the 1-bit masks used by the masked blit. Driving Aseprite through MCP from inside this session means sprite sheets can be built and iterated on directly as part of the normal workflow, rather than as a separate manual art pass.
2. **Reference art — Blender (via its MCP tool), optional.** Not part of the runtime pipeline (this is a 2D tile/sprite game, no 3D assets ship), but useful as a posing/reference aid for the trickier trap vignettes (e.g. the mid-air "cut in half" or "catapulted" poses) — render a quick reference pose in Blender, then hand-trace it down to 16×16 pixel art in Aseprite. Used only when a pose is hard to eyeball directly at 16×16.
3. **Rooms:** authored as tile-map + hazard-placement data (spreadsheet/CSV → packer script, given the small per-building room count), producing the RLE-packed room data + hazard tables described above.
4. **Assembly — rasm.** Z80 source built with rasm, which also drives the overall build (assemble → produce binaries → hand off to iDSK). Chosen over alternatives since it's the toolchain already set up for this project.
5. **Disk image — iDSK.** Final CPC `.dsk` image assembled with iDSK from rasm's output binaries (loader + code + packed asset blobs), for loading in emulators (CPCEC / Caprice32 / Arnold) during development and on real hardware for test passes.
6. **Headless testing — `tools/cpcrun.py`.** No emulator is required for day-to-day work: the harness runs the binary on the `z80` Python package, emulating only what the game touches (Gate Array inks/mode, CRTC base address, PPI/PSG keyboard matrix, VSYNC). Scripts in `tests/` hold keys for N frames, assert variables via the rasm symbol file, save screenshots, and report per-frame CPU use. Real-emulator and real-hardware passes still happen at milestone boundaries.
7. **Strings/captions:** authored once with EN + GR columns (see Localization), packed into two parallel text tables — kept short since the whole game is deadpan one-liners rather than branching dialogue, which keeps both tables and the string-printing routine minimal.

## Build Order / Milestones

1. **Engine skeleton:** boot, Mode 1 init, tile renderer, tile-aligned movement, one test room — prove the 8×8 tile + 16×16 sprite pipeline end to end.
2. **Hazard-trigger loop:** Fire-on-hazard state machine, one hazard type fully working (tell → trigger → vignette → caption → energy deduction → hazard set `disarmed`).
3. **Mark-safe / Miss / exit-gate loop:** the second control, the room `marked` bit, Miss detection + tally, and the building-wide exit check — this is the other half of the core loop and needs to be solid before content work starts, since every building depends on it.
4. **Remaining 11 hazard types:** mostly data + small FX-overlay sprites once the vignette playback system from #2 is generic.
5. **Room transitions + one full building (Sunny Vale Apartments):** multi-room traversal, exits, first full playable slice — exercises #2 and #3 together across a real room set.
6. **HUD systems:** energy bar, outside clock dial, score, miss-tally display, building win/soft-fail/fail outcomes.
7. **Outdoor ribbon-cutting template:** reusable bookend scene, wired to the per-building clock and win/fail state.
8. **Remaining 4 buildings:** content-only work once the engine is proven — room data, hazard placement, owner sprite/name swaps.
9. **Campaign glue:** title screen (with L-to-toggle-language, default English), building select/progression, twist/evidence pickup in building 5, good/bad ending screens — all text routed through the custom font + EN/GR string tables from the start, not bolted on after.
10. **Audio pass, difficulty tuning (clock speeds, miss tolerances), polish, real-hardware test pass.**

## Key Risks & Mitigations

- **RAM pressure from 12 distinct vignettes:** mitigated by sharing the base Thanos 16×16 sheet across all vignettes and differentiating via small FX overlays + palette swaps rather than fully unique animations per trap.
- **Screen-RAM/mode tradeoff:** Mode 1's fixed 16K cost is unavoidable; deliberately avoided scrolling and double-buffering (both common RAM sinks) in favour of static per-room screens and save/restore sprite drawing.
- **Content volume (5 buildings × ~6 rooms × up to 6 hazards):** kept authorable by hand (not procedural) because the core loop depends on hand-tuned, fair "tells" — but this means level-data authoring time, not engine complexity, is the long pole; budget schedule accordingly.
- **Dual-language text doubling RAM use:** mitigated by a custom compact font (Latin + monotonic Greek, no accented glyphs), short deadpan captions, and a shared string-ID scheme so adding Greek never means adding new code paths — only data. If the combined EN+GR tables push the total budget over, shorten captions before cutting a hazard type or building.
- **Exit-gate exploitability:** since the exit only requires every room's `marked` bit set (not every hazard actually disarmed), a player could in principle rush every room and eat the Miss penalty everywhere to finish fast. Mitigated by tuning the Miss energy/score cost well above the cost of actually finding and triggering a room's hazards, so rushing is always the worse trade — this balancing (hazard-trigger cost vs. Miss cost vs. clock pressure) is a tuning pass, not a code change, and should be revisited once the first full building is playable.
