# Build Dangerous — Scenario

*An Amstrad CPC game. Mode 1 (320×200, 4 colours). 16×16 sprites.*

## Logline

Every building in town is getting a grand opening — speeches, ribbons, a crowd waiting to walk in. Every building is also a death trap, because the owners cut every corner they could find. Inspector **Thanos** has sixty seconds of dignity and one job: find every trap before the ribbon gets cut, or the crowd walks into a building that bites back.

## The Inspector

**Thanos** is immortal. He cannot actually die — he can only be *embarrassed*. Every bite, shock, drowning, and flattening is survivable, but it costs him **Reputation Energy**. He's held the Municipal Hazard Inspection contract for longer than anyone can remember, and the contract is renewed on vibes and a clean record. Zero out his energy and the contract — not his life — is what ends. He walks it off, swears, and keeps the same stony expression regardless of what just happened to him.

Personality: deadpan, weary, professionally unimpressed by physics. He's seen it all, twice, and it's always Tuesday.

## The Hook (per building)

**Outdoor scene:** the building owner is on a small stage out front, mid-speech, scissors in hand, ribbon strung across the door. A queue of excited townsfolk fidgets behind a rope. A big dial/clock ticks down — the owner's patience, and the crowd's. This is the pressure clock for the level: when it hits zero, the ribbon gets cut whether Thanos is ready or not.

**Indoor scene:** cut to Thanos stepping into the lobby. The player takes over. He has to walk every floor, spot every rigged fixture, and disable it before the clock outside runs out — all while the building actively tries to kill him.

## Core Fantasy

Thanks to a lifetime of claims adjusting, Thanos has a sixth sense: hazards *look* almost normal, but not quite — a crooked sign, a damp patch, a coil of wire that shouldn't be visible. The player is trained to read the same tells. Spotting one and holding the "Inspect" action in time disarms it cleanly (for score and energy). Walking past it, or fumbling the inspection, sets it off — and the trap plays out in a short, silly, fully-animated vignette while Thanos absorbs the hit and energy drops.

The game is equally a spot-the-difference puzzle and an action-platformer: hazards are seeded into otherwise-identical room layouts, and most of the challenge is pattern-reading under time pressure, not reflexes alone.

## The Twelve Ways to Get Got

Each is a short (1–2 second) animated gag, not a death — Thanos always gets back up, dusts off, and his expression never changes.

1. **Bitten** — a "decorative" floor grille is actually a crate of the owner's "guard ferret." Thanos yelps and shakes his leg like a cartoon dog.
2. **Electrocuted** — bare wire taped behind a light switch. He lights up like a sign, hair standing on end, and the lights in the room flicker in sympathy.
3. **Drowned** — a mop closet door hides a burst water main; opening it floods the room and Thanos bobs to the surface wearing a rubber duck he didn't bring.
4. **Hit on the head** — a chandelier/vending machine/scaffolding plank, held up by a single zip tie, lets go right on cue. He flattens like an accordion, then pops back up.
5. **Cut in half** — an elevator with doors that close a half-second too early. He steps through at the wrong moment and separates clean at the waist — top half keeps talking into his radio until the bottom half catches up.
6. **Impaled** — a "soft landing" cushion over an open shaft is actually a bed of nails with a cushion cover stapled over it.
7. **Squashed** — a trash compactor room with a door helpfully labelled "NOT A TRASH COMPACTOR."
8. **Incinerated** — a gas leak meets a pilot light; he goes up in a comic fireball and walks out of frame as a walking briquette, smoke still rising.
9. **Frozen solid** — a walk-in freezer door with a broken release handle; he's a block of ice for a beat, including a visible thought-bubble icicle, before shattering free.
10. **Poisoned (green gas)** — a leaking chemical drum under a "cleaning supplies" sign; he turns green, wobbles, and deflates like a week-old balloon.
11. **Sucked up** — an industrial vacuum/garbage chute with no grille; he gets inhaled, bounces through the ductwork (sound effect optional), and is spat out two rooms over.
12. **Catapulted through the roof** — a frayed elevator counterweight cable lets go under him; he launches straight up through the ceiling and the rooftop scenery, then falls back into frame a beat later, plaster dust and pigeon feathers included.

Each hazard has a matching "tell" — a visual detail slightly wrong in that room — that the player can learn to recognise (a floor grille with scratch marks, a wire with no conduit, a sign hung crooked over a hole, etc.).

## The Buildings (campaign order, rising difficulty)

1. **Sunny Vale Apartments** — tutorial building. Small, few floors, one or two hazard types per room, generous clock. Teaches movement, inspecting, and the energy/clock pressure.
2. **Big Box Mall** — wide floors, escalators, more hazard variety, first appearance of timed/moving hazards (e.g. the guillotine elevator doors).
3. **Grand Hotel** — tall, vertical play (stairs/lift shafts matter), introduces fire and water hazards together, tighter clock.
4. **Mega Hospital** — chemical and biohazard themed, fast hazards, crowded rooms, decoy "fake" hazards that look dangerous but are safe (bluffing the player's pattern sense).
5. **The Skyscraper** (finale) — every hazard type appears at least once, the owner is visibly impatient on the outside-scene clock, and the twist lands here (see below).

## The Twist

The owner of the Skyscraper isn't just cheap — he's deliberately under-building to fail the structure after the opening, for the insurance payout, timed to a packed lobby. Thanos finds the paperwork taped under a stairwell (a one-off "evidence" pickup, not a new mechanic) partway through the floor. The ending branches on how the inspection actually went, not on a separate confrontation scene:

- **Good ending:** enough hazards disarmed, energy held, clock beaten — Thanos walks back out, hands the owner a condemnation notice instead of letting him cut the ribbon, and the crowd cheers for the inspector instead.
- **Bad ending:** clock runs out or energy zeroes — the ribbon gets cut on schedule, the crowd files in, and the last image is Thanos's inspection contract getting stamped "TERMINATED" while chaos starts behind him. Deadpan narration, not gore — this is a comedy.

## Tone & Presentation

- Visual comedy over violence — every hazard is a slapstick beat, not gore. Think Looney Tunes physics on 8-bit hardware.
- Thanos's face never changes. The joke is that nothing fazes him; the energy bar is the only thing that visibly reacts.
- Dry, deadpan one-line text captions on each hit ("Filed under: dog bite. Again.") rather than voice or long cutscenes — keeps it readable and cheap to produce.
- Outdoor ribbon-cutting scene reused as a template across all five buildings (owner sprite/name/dialogue swapped), keeping asset cost low while giving each level a bookend.

## Win / Lose per Building

- **Win:** all hazards in the building disarmed or safely passed (the player isn't required to find 100% — see Plan for the pass threshold) before the outside clock runs out, with energy above zero.
- **Partial/soft-fail:** clock or energy runs out but enough hazards were cleared — owner is embarrassed into a delay, small reputation penalty, proceed to next building.
- **Fail:** energy hits zero, or clock runs out with too few hazards cleared — contract-ending outcome for that run (game over, or a "fired, try again" restart depending on difficulty mode).

## Scoring

- Points for each hazard correctly identified and disarmed, with a speed bonus for early finds.
- Points lost per hazard triggered (energy cost doubles as the score cost).
- End-of-building bonus tied to how much clock time remained and how much energy was left — rewards efficient, careful play over either recklessness or dawdling.
