# Playable Prototype

The repository contains a playable first prototype of the frog city game. The
working title shown in the menu is **Frog City Feast**; it is not the confirmed
final title.

The complete game vision remains in
[`game-design.md`](game-design.md). This document describes only what is
currently implemented.

## Current gameplay

The prototype includes:

- a landscape, touch-first 4:3 presentation intended for iPad;
- a third-person 2D camera composition with the frog in the lower part of the
  view;
- tap-to-move controls;
- double-tap tongue aiming at the exact touched location;
- two-finger camera rotation;
- equivalent mouse controls for desktop testing;
- fixed tongue range, wall obstruction, miss recovery, and center-hit accuracy;
- presentation-only tongue extension, hold, and retraction that preserves the
  result and accuracy of the original touch;
- ordinary, moving, resistant, rare, living, object, and vehicle targets;
- rapid-tap struggles against resistant targets;
- draw-only target pulses and stronger tongue feedback for each struggle tap;
- an unlimited belly containing lightweight records rather than hidden world
  objects;
- individual Digest and Spit Out actions;
- scoring based on size, rarity, accuracy, danger, and pursuit;
- an immediate points-and-growth reward shown inside the belly after digestion;
- three discrete frog growth tiers;
- larger frog and tongue presentation at each tier;
- a collision-safe frog growth pulse and expanding growth rings;
- traffic that is dangerous while the frog is small and edible at maximum
  growth;
- Animal Control pursuit after an escaped target calls for help;
- knockback and score loss that never reduces the score below zero;
- short, deterministic, eight-pixel-or-less camera shake for damage and whole
  building captures, suppressed during camera gestures and struggles;
- pursuit escape after sufficient time or distance;
- the ability to swallow Animal Control at maximum growth;
- harmless return of digested living targets at collision-safe locations,
  with indoor residents returning inside their building;
- target restocking so a score session can continue;
- collision-aware target restocking that separates simultaneous replacements;
- rare-target replenishment on a randomized 90–180 second schedule;
- a rare golden cake that grants one minute of flight;
- a lightweight day and night tint cycle;
- capped, draw-only swallow and damage bursts that add no physics bodies,
  targets, particle-system nodes, or shared random-number use;
- a first-time tutorial stored independently for each local player profile:
  - move to a marked location;
  - double-tap and swallow the Street Donut;
  - digest it from the belly;
  - rotate the camera;
  - catch, struggle with, and digest the Runaway Hot Dog;
  - eat and digest the Moonlight Market sign;
  - wait for the resulting growth tier to apply; and
  - pull off the Moonlight Market door;
- tutorial guidance that highlights the current target, restricts unrelated
  actions, safely resets failed guided struggles, and returns to the city after
  required belly actions;
- a Skip action that marks the tutorial complete and restores normal play;
- a persistent, per-profile Frog Field Guide covering all 19 target IDs in the
  prototype, including Golden Cake, both destructible-building sequences, and
  Animal Control;
- first-swallow discovery credit that never adds score or growth, cannot be
  farmed by returning and re-eating a target, and is saved immediately;
- useful hints for unknown Field Guide entries, including the unusual
  full-growth Animal Control discovery path;
- a touch-friendly, scrollable Guide overlay with discovery progress, Return
  to City, and End Game controls;
- a dedicated first-discovery banner that does not replace tutorial,
  accuracy, or building-weakness messages;
- Field Guide progress on the player-selection menu;
- three fixed, session-only challenges for accurate swallows, rapid-tap
  struggle wins, and eating distinct target types;
- a passive challenge panel that allows touches through to the city, begins
  only after the tutorial is completed or skipped, and gives no score, growth,
  power, or persistent reward;
- four enterable building shells with collision walls and doorway openings;
- furnished Leap Café and Canal Apartments interiors with collision-safe,
  wall-hugging counters, booths, lockers, stairs, and lobby seating;
- a Loose Phone positioned behind the Leap Café bar so the player must move
  into the café to get a clear tongue shot;
- a Lobby Lamp and resistant Tenant's Cat that require entering Canal
  Apartments and restock safely inside the lobby;
- a complete destructible-building vertical slice for Moonlight Market:
  - eat its exterior sign;
  - grow large enough to pull off its blocking door;
  - enter the market and eat its counter;
  - reach maximum growth and win a struggle against the weakened building;
  - swallow and digest the whole structure, or spit it back into a clear
    footprint with the removed parts still absent;
- a second complete destructible-building sequence for the Oddities Shop:
  - remove its shutter at any size;
  - grow once, enter the shop, and win a struggle with its Curio Shelf;
  - remove its exterior banner;
  - reach maximum growth and win a struggle against the weakened shop; and
  - digest the whole structure or restore it with all three parts still gone;
- an always-available End Game action, including from the belly screen; and
- local player profiles with independent high scores and a device-wide best
  score. Ending the game before finishing or skipping the tutorial does not
  mark that profile's tutorial complete.

## Controls

### iPad

| Action | Control |
|---|---|
| Move | Tap an open ground location |
| Aim tongue | Double-tap a target |
| Rotate camera | Hold one touch and drag a second finger horizontally |
| Win a struggle | Tap rapidly until the struggle bar fills |
| Manage swallowed targets | Tap **Belly** |
| View discoveries | Tap **Guide** |
| Finish the score session | Tap **End Game** |

### Windows development

| Action | Control |
|---|---|
| Move | Left-click open ground |
| Aim tongue | Double-click a target |
| Rotate camera | Drag with the right mouse button |
| Win a struggle | Click rapidly |

## Running and checking

Open the project with the Godot version pinned in
[`tools/toolchain.json`](../tools/toolchain.json), then run the main scene.

On Windows, the blocking project command imports the project, starts the main
scene headlessly, and runs the gameplay and tutorial smoke tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-project-windows.ps1
```

On Linux or macOS:

```bash
bash scripts/check-project.sh
```

The smoke tests check the core belly, scoring, growth, touch-camera, traffic,
pursuit, flight, profile persistence, Field Guide catalog and overlay behavior,
legacy discovery saves, deterministic session challenges, tutorial sequence,
action restrictions, guided struggle recovery, Skip behavior, and tutorial
completion persistence.

## Prototype boundaries

This is a mechanics prototype, not a finished game. It deliberately uses
simple vector graphics and a fixed city area so the eating and growth loop can
be evaluated before larger production work.

The following parts of the full design are not implemented yet:

- procedural endless city generation and additional districts;
- authored multi-room interiors with separate transitions;
- staged removal and swallowing for the remaining ordinary buildings;
- pathfinding around complex city geometry;
- several pursuer types, nets, traps, and roadblocks;
- rain, storms, festivals, shops with schedules, and random emergencies;
- achievements, story clues, and secrets beyond the Field Guide;
- additional temporary powers;
- final art, authored animation, sound, music, and an in-game accessibility
  settings screen; and
- signed installation, TestFlight distribution, or App Store release.

Motion-heavy feedback can already be disabled through the
`frog_city/reduced_motion` Godot project setting. This keeps informational
flashes, reward text, and the tongue line while removing camera shake, frog
scale movement, target wobble, and tongue extension movement. A player-facing
toggle is deferred to the accessibility priority.

An Apple Developer Program membership is not required for local gameplay
development or the repository's unsigned checks. It becomes necessary before
signed TestFlight or App Store distribution.

## Next implementation priorities

Continue the prototype one reviewed priority at a time:

1. Add more city activity.
2. Add accessibility controls and iPad presentation polish.
3. Add performance instrumentation and budgets.
4. Verify the unsigned iOS export pipeline.
5. If time remains, add original or clearly licensed sound effects, ambience,
   and restrained music.

The broader unimplemented feature list above defines the remaining prototype
boundaries. `docs/game-design.md` remains the source of truth for the intended
full-game experience.
