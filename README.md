# Build Dangerous

A comedy hazard-inspection game for the Amstrad CPC (64K, Mode 1 — 320×200, 4 colours).

Inspector Thanos — immortal, deadpan, running out of patience contract renewals — has to find every rigged trap in a building before the owner cuts the ribbon and the crowd walks in. Miss one and he gets bitten, electrocuted, drowned, flattened, or otherwise comically wrecked; he always gets back up, but his Reputation Energy doesn't.

Bilingual: **English (default) and Greek**, toggled with **L** from the main menu.

- [scenario.md](scenario.md) — story, characters, the 12 trap types, the 5-building campaign, win/lose conditions, tone.
- [plan.md](plan.md) — technical plan: memory budget, sprite specs (16×16 characters, 8×8 hazard "tells"), room/level data format, game systems, content pipeline, build milestones.

## Status

Design phase. No code or assets yet.

| Area | Status |
|---|---|
| Scenario / narrative | Drafted |
| Technical plan | Drafted |
| Localization (EN/GR) | Planned — custom font + string tables, not yet built |
| Engine (Z80 ASM) | Not started |
| Tile/sprite art | Not started |
| Level data (5 buildings) | Not started |
| Audio | Not started |

## Open Decisions

None currently outstanding.

## Log

- 2026-10-11 — Initial scenario.md and plan.md written. Sprite sizes clarified: characters 16×16, trap "tell" objects 8×8.
- 2026-10-11 — Added bilingual EN/GR requirement: L toggles language from the main menu, English is the default. Plan updated with a custom Latin+Greek 8×8 font, parallel EN/GR string tables, and the memory-budget impact.
- 2026-10-11 — Confirmed tooling in plan.md: Aseprite (MCP) for all tile/sprite art, Blender (MCP) as an optional 3D reference aid for tricky vignette poses, rasm for assembly, iDSK for building the .dsk image.

---

*This file is kept up to date as the project progresses — check here first for current status before diving into scenario.md/plan.md.*
