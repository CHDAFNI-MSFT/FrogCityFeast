# Playable Prototype

The repository contains a playable first prototype of **Frog City Feast**. The
Godot project, on-device display name, bundle identifier, and App Store Connect
record use this selected release title.

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
- brief, draw-only move, tongue, and camera touch cues that confirm accepted
  controls without changing input coordinates, targeting, physics, or scoring;
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
- a lightweight day and night cycle that changes the world tint, pedestrian
  crowd, secondary traffic, and streetlight glow;
- deterministic, draw-only pedestrians on fixed sidewalk routes, with a
  smaller night crowd and no collision, targeting, scoring, or Field Guide
  behavior;
- deterministic, draw-only background traffic on the secondary road, kept
  visually separate from the labeled, edible Delivery Van;
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
  mark that profile's tutorial complete;
- per-profile **Reduce motion** and **Larger text & controls** choices available
  before starting and from an in-game Accessibility panel;
- immediate reduced-motion behavior that removes camera shake, scale and
  wobble pulses, tongue travel, tutorial-marker pulsing, struggle-width pulses,
  and decorative city movement while retaining informational text, color
  flashes, the tongue line, density changes, and streetlight state;
- readable high-contrast panels and controls with clear pressed, focus, and
  enabled states, minimum 56-pixel normal touch actions, and minimum 64-pixel
  actions when the larger-interface option is enabled;
- safe-area-aware HUD edges and modal layouts that preserve the 1280×960 4:3
  world composition;
- opt-in, local-only developer performance instrumentation plus deterministic
  structural budgets and repeatable stress scenarios; and
- a restrained original vector city-and-canal menu backdrop and compact
  two-column player/accessibility layout.

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
| Change accessibility | Tap **Options** |
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

The smoke tests check the core belly, scoring, growth, touch-camera, gameplay
traffic, deterministic city-activity levels and routes, pursuit, flight,
profile persistence, Field Guide catalog and overlay behavior, legacy discovery
saves, per-profile accessibility persistence and legacy defaults, touch-target
sizing, safe-area layout, touch feedback, reduced-motion transitions,
deterministic session challenges, performance structure and stress budgets,
the credential-free iOS pipeline configuration, tutorial sequence, action
restrictions, guided struggle recovery, Skip behavior, and tutorial completion
persistence.

## Performance instrumentation and budgets

Performance instrumentation is developer-only and disabled by default. It
does not write files, send network requests, identify players, change saves, or
collect remote analytics. Ordinary play pays only a one-time command-line flag
check when the game scene starts.

To show the local performance overlay, launch the project with the user
argument after Godot's `--` separator:

```powershell
godot-console --path . -- --perf-overlay
```

The overlay is input-transparent and continues updating while the Belly, Field
Guide, or Options overlay pauses gameplay. It reports rolling frame time and
FPS, coarse Godot process and physics time, static memory, global node/resource
counts, 2D physics activity, and game-specific nodes, canvas items, collision
objects, targets, buildings, pursuit, city actors, effects, and overlay data.
Live render-server counters are deliberately omitted because polling them can
disturb the frame being observed.

The prototype uses these **target-device acceptance budgets** for an A16 iPad
release build at the 1280×960 reference presentation:

| Metric | Budget |
|---|---:|
| Sustained frame rate | 60 FPS target; at least 58 FPS over a 30-second sample |
| Frame time | 16.67 ms target; p95 no more than 18 ms |
| Main-thread process time | p95 no more than 8 ms |
| Physics process time | p95 no more than 2 ms |
| Static memory | no more than 192 MiB |
| Video memory | no more than 256 MiB |
| Render activity | no more than 450 draw calls, 1,800 objects, and 50,000 primitives |

Frame, process, physics, memory, and render budgets are hardware- and
build-dependent. They are advisory on development computers and must be
accepted on the target iPad using a release build and the Godot/Xcode profilers.
Godot's runtime `Performance` monitors do not expose GPU frame time; measure GPU
time with Xcode's Metal tools on the device. CI never fails on FPS, frame time,
GPU time, or render-server values.

The deterministic structural budgets are enforced in CI:

| Reachable state | Structural ceiling |
|---|---|
| Baseline, busy daytime, maximum growth, Field Guide, or accessibility options | 216 game-subtree nodes, 30 collision objects and shapes, 18 targets, 4 buildings |
| Pursuit or gameplay peak | 218 nodes, 31 collision objects and shapes, 1 pursuer |
| Populated Belly sample | 64 items and rows, 472 nodes; this is a stress sample, not a gameplay capacity limit |
| Busy daytime activity | 10 pedestrians plus 5 secondary vehicles, all draw-only |
| Simultaneous presentation | 24 world effects and 3 touch cues; neither adds physics objects |
| Populated Field Guide | 19 rows, matching the fixed catalog |

Run the rendered Windows measurements without writing a benchmark report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\measure-performance-windows.ps1
```

The harness uses fixed random seeds and covers baseline play, busy daytime,
pursuit, maximum growth, a finite maximum presentation burst, a 64-item Belly,
the populated Field Guide, both accessibility options, and a reachable gameplay
peak combining daytime activity, pursuit, growth, and presentation effects. It
prints median FPS, frame-time percentiles, memory, and a post-sample render
snapshot. The command-driven Windows run can show isolated scheduling/window
stalls, so p95 is more useful than its maximum or arithmetic-mean FPS.

An August 2026 local GL Compatibility measurement at 1280×960 on an NVIDIA RTX
4050 laptop used about 40–46 MiB static memory and 17–22 MiB video memory.
Ordinary and populated-overlay scenarios were comfortably below the structural
and render-count ceilings. One representative run measured 15.09 ms frame-time
p95 for the finite presentation burst and 20.13 ms for the combined gameplay
peak; the latter is marked for review against the 18 ms target. The same
command-driven run produced isolated roughly half-second maximum-frame outliers
and delayed process-time snapshots, so those values are not treated as
acceptance evidence. Both peaks require explicit profiling on the A16 iPad. The
unsigned Godot-to-Xcode pipeline is now verified, but installing and profiling
on the target device still requires a separately authorized, developer-signed
device build.

## Unsigned iOS export verification

The manual `iOS unsigned smoke build` workflow is verified on the pinned
`macos-26` arm64 runner. Run
[`33314224588`](https://github.com/CHDAFNI-MSFT/SamuelIcecream/actions/runs/33314224588)
successfully installed Godot 4.7.2 and its export templates, passed the Xcode
26.6/iOS 26.5 preflight, generated the Xcode project, and compiled a Release
build for a generic iOS device with code signing disabled.

The workflow is manual-only, read-only, uses a synthetic Team ID and example
bundle identifier, references no GitHub secrets, persists no checkout
credentials, and uploads no application artifact. `export_presets.cfg` is
generated only for the export and removed on exit.

The normal project check includes a deterministic unsigned-pipeline regression
test. Windows and Linux can verify workflow wiring, toolchain pins, the arm64
project-only preset, secret absence, and signing overrides, but cannot perform
the Apple export or Xcode build. The macOS workflow remains authoritative.

The successful remote run built committed state through `fa5523f`. The later
gameplay, accessibility, performance, and release-pipeline changes in the
current repository state require another manual smoke run after this state is
pushed. Known non-fatal generated-project warnings are recorded in
[`ios-release.md`](ios-release.md).

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
- final art, authored animation, sound, music, and any accessibility work beyond
  the implemented motion, interface-size, contrast, touch-feedback, and
  safe-area controls; and
- the first signed TestFlight upload, A16 iPad validation, and App Store
  release.

Each player can change **Reduce motion** and **Larger text & controls** from the
main menu or the in-game **Options** panel. The settings are stored in the
existing version 1 profile save without changing score, tutorial, or Field
Guide semantics; older saves deterministically use both options as off. The
`frog_city/reduced_motion` Godot project setting remains a fallback for direct
scene runs that are not configured through a player profile.

An Apple Developer Program membership is not required for local gameplay
development or the repository's unsigned checks. It becomes necessary before
signed TestFlight or App Store distribution.

## Next implementation priorities

Continue the prototype one reviewed priority at a time:

1. Push the combined prototype and release-preparation commit, then run the
   credential-free `iOS unsigned smoke build` against that exact commit.
2. After the smoke build passes and the release is explicitly approved, run
   the first internal-only TestFlight workflow and install it on the target
   A16 iPad.
3. Validate touch controls, safe-area presentation, both accessibility modes,
   gameplay regressions, and the documented hardware performance budgets on
   the device. Fix every material issue before expanding the prototype.
4. After device validation, the next candidate feature priority is original or
   clearly licensed sound effects, ambience, and restrained music.

The broader unimplemented feature list above defines the remaining prototype
boundaries. `docs/game-design.md` remains the source of truth for the intended
full-game experience.
