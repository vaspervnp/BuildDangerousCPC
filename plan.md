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
| Stack + variables + buffers | ~2K | |
| **Total** | **~45–50K** | fits inside the ~48K non-screen budget with headroom |

Keeping both sprite classes small (8×8 and 16×16 only, no 32×32 anywhere) is what makes this budget work — it's the single biggest lever against running out of RAM on this hardware.

## Screen Layout (in-building gameplay)

- **Play area:** full 320×200 Mode 1 framebuffer, no separate HUD strip reserved — HUD is drawn as a thin overlay band (e.g. top 16 rows: energy icons + room clock) composited over the tile background, since a dedicated status panel would eat too much of the already-small visible area on this resolution.
- **Room size:** one screen = one room (40×25 tiles of 8×8 = 320×200). No scrolling engine required — rooms are connected via doorways/stairs that cut to the adjacent room's static screen. This avoids writing/debugging a smooth-scroll engine on top of everything else, which is the right tradeoff for a 64K one-dev-team scope.
- **Outdoor ribbon-cutting scene:** a separate, simpler static screen template (owner + stage + crowd + countdown dial), reused across all 5 buildings with swapped owner sprite/name and dialogue string only.

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
    state               ; armed / disarmed / triggered
  }
  exits[4]          ; N/S/E/W -> room_id or 0xFF (none), matches stairwell/door tile position
}
```

- Tile maps are RLE-compressed (buildings reuse a handful of tile types: floor, wall, door, stairs, carpet, pipe-run, etc.) and decompressed into a small working tile-index buffer on room entry, not held fully expanded for every room simultaneously.
- Hazard placement tables are authored per room (hand-placed for puzzle fairness) rather than randomly generated — this is a "spot the difference" game, so hand-tuned tells matter more than procedural variety.

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

### 3. Player State Machine

```
States: IDLE_WALK, INSPECTING, TRIGGERED(trap_id), DISARM_SUCCESS, TRANSITION(room)
```

- **IDLE_WALK:** 4-direction movement at tile-aligned steps (moves in 8px increments matching the tile grid — simplifies both collision and background-restore, since the 16×16 sprite is always tile-aligned).
- **INSPECTING:** triggered by holding Fire while adjacent to/overlapping a hazard tile within a short reaction window (tunable per building's difficulty); success disarms (state → disarmed, award points/energy), failure or holding too long/short triggers the trap.
- **TRIGGERED:** plays the matching vignette (input locked, ~0.5–1s), deducts energy, shows caption, returns to IDLE_WALK at a safe adjacent tile.
- **TRANSITION:** on reaching a door/stair tile, swap room data + redraw screen.

### 4. Energy, Scoring, and the Outside Clock

- **Energy:** 8-segment bar (8×8 icon strip in HUD band). Each triggered trap = −1 segment (configurable per difficulty); collectible "hard hat" pickups (rare, 8×8, placed like hazards but safe) restore +1.
- **Outside clock:** a frame counter started on building entry, decremented every N frames (tuned per building — tighter in later buildings), rendered as a shrinking dial in the HUD band using the same 8×8 tile trick (8-9 tile states = a clean "pie" animation with no need for rotation routines).
- **Pass threshold:** each building defines a minimum hazards-disarmed count (e.g. 70%) to count as a full win versus a soft partial-fail — stored as one byte per building in the campaign table, not hardcoded per level.
- **Scoring:** running score in a 3-byte BCD or packed-decimal counter (simplifies HUD printing via firmware-style digit lookup rather than division routines), updated on disarm (+), trigger (−), and building-complete bonus (time remaining + energy remaining).

### 5. Rendering / Sprite Engine

- **Background-save-and-restore** sprite drawing (not full double-buffering — no spare 16K to spare for a second screen buffer): before drawing a moving 16×16 sprite, save the 2×2 tile area it will cover into a small scratch buffer, draw, then restore-and-redraw on the next frame's old position before drawing the new one. Standard CPC sprite technique, cheap in code size.
- **8×8 hazard/tell objects** are mostly static (part of the room's drawn background) except during their own trigger animation, where the same save/restore trick applies but over a smaller 1×1 tile area — cheaper than the character case.
- **Masked blit** for both sprite sizes (sprite data + 1-bit-per-pixel mask pre-expanded to the mode's 2-bit packing) so sprites composite over tile backgrounds without a visible bounding box.
- Target **50Hz frame budget**: with tile-aligned movement (redraw only on actual grid-step, not sub-pixel), the per-frame cost is small enough that this is comfortably achievable in Z80 ASM without needing contended-memory tricks beyond the standard "do heavy work off-screen / during VBlank" discipline.

### 6. Audio

- AY-3-8912 PSG via firmware sound manager (simplest, smallest code path) rather than a hand-rolled player — budget is tiny (~1–2K of SFX data), not worth a custom player for one jingle and ~6 SFX cues (step, inspect-success chime, 12 trap-hit stings sharing a handful of underlying waveforms/pitch-shifted rather than 12 fully unique cues).

## Content Pipeline

1. **Tiles & sprites:** authored in Aseprite (or similar) at native 8×8 / 16×16, exported as indexed 4-colour PNGs, converted to CPC-packed binary via a small conversion script (Python) that also pre-generates the 1-bit masks for sprite blitting.
2. **Rooms:** authored in a simple tile-map editor (or a spreadsheet/CSV → packer script, given the small per-building room count) producing the RLE-packed room data + hazard tables described above.
3. **Assembly:** Z80 source built with a modern cross-assembler (e.g. sjasmplus or rasm), targeting a .dsk image for emulator testing (CPCEC / Caprice32 / Arnold) before any real-hardware pass.
4. **Strings/captions:** single text table, since the whole game is deadpan one-liners rather than branching dialogue — keeps text data and the string-printing routine both minimal.

## Build Order / Milestones

1. **Engine skeleton:** boot, Mode 1 init, tile renderer, tile-aligned movement, one test room — prove the 8×8 tile + 16×16 sprite pipeline end to end.
2. **Hazard loop:** inspect/trigger state machine, one hazard type fully working (tell → inspect → disarm or trigger → vignette → caption → energy deduction).
3. **Remaining 11 hazard types:** mostly data + small FX-overlay sprites once the vignette playback system from #2 is generic.
4. **Room transitions + one full building (Sunny Vale Apartments):** multi-room traversal, exits, first full playable slice.
5. **HUD systems:** energy bar, outside clock dial, score, pass-threshold check, building win/soft-fail/fail outcomes.
6. **Outdoor ribbon-cutting template:** reusable bookend scene, wired to the per-building clock and win/fail state.
7. **Remaining 4 buildings:** content-only work once the engine is proven — room data, hazard placement, owner sprite/name swaps.
8. **Campaign glue:** title screen, building select/progression, twist/evidence pickup in building 5, good/bad ending screens.
9. **Audio pass, difficulty tuning (clock speeds, pass thresholds), polish, real-hardware test pass.**

## Key Risks & Mitigations

- **RAM pressure from 12 distinct vignettes:** mitigated by sharing the base Thanos 16×16 sheet across all vignettes and differentiating via small FX overlays + palette swaps rather than fully unique animations per trap.
- **Screen-RAM/mode tradeoff:** Mode 1's fixed 16K cost is unavoidable; deliberately avoided scrolling and double-buffering (both common RAM sinks) in favour of static per-room screens and save/restore sprite drawing.
- **Content volume (5 buildings × ~6 rooms × up to 6 hazards):** kept authorable by hand (not procedural) because the core loop depends on hand-tuned, fair "tells" — but this means level-data authoring time, not engine complexity, is the long pole; budget schedule accordingly.
