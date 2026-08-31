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
- a deterministic Animal Control net attack with a 0.8-second warning, one
  wall-aware draw-only projectile, a dodge window, and a three-second six-tap
  escape;
- net failure that reuses the existing 25-point capped loss and knockback,
  while flight and maximum growth prevent capture;
- one deterministic physical Animal Control roadblock per pursuit, deployed
  after three eligible seconds at the nearest safe authored road anchor,
  breakable with three tongue hits, self-expiring after ten seconds, and
  cleared immediately when pursuit ends;
- knockback and score loss that never reduces the score below zero;
- short, deterministic, eight-pixel-or-less camera shake for damage and whole
  building captures, suppressed during camera gestures and struggles;
- pursuit escape after sufficient time or distance;
- a deterministic River Park meetup where five draw-only visitors provide
  marked crowd cover and a 1.75-second Animal Control escape for an eligible
  small or medium frog;
- the ability to swallow Animal Control at maximum growth;
- harmless return of digested living targets at collision-safe locations,
  with indoor residents returning inside their building;
- target restocking so a score session can continue;
- collision-aware target restocking that separates simultaneous replacements;
- rare-target replenishment on a randomized 90–180 second schedule;
- a rare golden cake that grants one minute of flight;
- a lightweight day and night cycle that changes the world tint, pedestrian
  crowd, secondary traffic, and streetlight glow;
- one deterministic 36-second daytime rain shower per 180-second cycle, with
  smooth fades, wet-road sheen, puddle highlights, and 84 capped draw-only rain
  streaks;
- peak rain that reduces ambient activity from 10 pedestrians and 5 secondary
  vehicles to 4 pedestrians and 3 vehicles without changing gameplay targets,
  collision, scoring, saves, the Field Guide, or the day/night audio;
- one deterministic 68-second daytime River Park meetup per cycle, with a
  50-second steady interval, five capped draw-only visitors, and no overlap
  with the rain shower;
- crowd-cover progress that resets when the frog leaves and is unavailable
  during flight, maximum growth, knockback, netting, tongue pulls, or target
  struggles;
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
- a persistent, per-profile Frog Field Guide covering all 28 target IDs in the
  prototype, including Golden Cake, all four destructible-building sequences,
  and Animal Control;
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
- a marked Leap Café stockroom door with a short fade, centered room camera,
  solid room walls and shelving, a return door, and a Stockroom Coffee Tin
  that remains scoped to the room when spat out or restocked;
- stockroom hiding that ends active Animal Control pursuit, blocks remote
  pursuer spawning, switches to an immediate cut with Reduce motion, and
  becomes inaccessible while Leap Café is consumed;
- marked Canal Apartments lobby stairs leading through the same bounded
  transition to a solid upper hall, fixed room camera, return-to-lobby marker,
  and tier-one Hallway Vacuum that remains scoped to the room when spat out or
  restocked;
- upper-hall hiding that ends active pursuit, blocks remote pursuer spawning,
  uses an immediate cut with Reduce motion, and becomes inaccessible while
  Canal Apartments is consumed;
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
- an ordered destructible-building sequence for Leap Café:
  - eat its Sidewalk Menu Board from outside;
  - grow once, enter the still-open café, and win a struggle with the Rear
    Espresso Counter;
  - remove the Front Awning without changing doorway collision;
  - reach maximum growth and win a struggle against the weakened café; and
  - digest the whole structure or restore it in a clear footprint with all
    three parts still absent and the Loose Phone bar unchanged;
- an ordered destructible-building sequence for Canal Apartments:
  - eat its Address Plaque from outside;
  - grow once, enter the still-open lobby, and win a struggle with the Lobby
    Bench;
  - remove the Entry Canopy without changing doorway collision;
  - reach maximum growth and win a struggle against the weakened apartments;
    and
  - digest the whole structure or restore it in a clear footprint with all
    three parts still absent and the Tenant's Cat and Lobby Lamp paths intact;
- an always-available End Game action, including from the belly screen; and
- local player profiles with independent high scores and a device-wide best
  score. Ending the game before finishing or skipping the tutorial does not
  mark that profile's tutorial complete;
- per-profile **Reduce motion** and **Larger text & controls** choices available
  before starting and from the in-game Options panel;
- per-profile **Master**, **Music & ambience**, and **Effects** volume controls,
  with 80%, 45%, and 80% defaults for older version 1 profiles;
- an original, reproducibly generated soft arcade-like audio slice with
  restrained menu and gameplay music, day and night city ambience, and
  semantic feedback for interface actions, tongue outcomes, struggles,
  swallowing, digestion, spitting, growth, damage, discoveries, and challenge
  completion;
- centralized Music and Effects bus routing with one music player, one
  ambience player, four reusable effect voices, per-event cooldowns, and
  deterministic pitch variation that never consumes gameplay randomness;
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
| Change accessibility or audio | Tap **Options** |
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
traffic, deterministic city-activity levels and routes, the bounded rain
schedule and density change, frame-step-independent rain, static reduced-motion
weather, pursuit, net windup and wall clearance, dodging, tongue interruption,
rapid-tap escape and timeout damage, flight and growth immunity, profile
persistence, Field Guide catalog and overlay behavior, legacy discovery saves,
per-profile accessibility persistence and legacy defaults, touch-target sizing,
safe-area layout, touch feedback, reduced-motion transitions, deterministic
session challenges, original audio resources and provenance, audio buses and
semantic event wiring, bounded player/cooldown behavior, per-profile audio
persistence and legacy defaults, loop lifecycle, gameplay RNG isolation,
performance structure and stress budgets, the credential-free iOS pipeline
configuration, tutorial sequence, action restrictions, guided struggle
recovery, Skip behavior, and tutorial completion persistence.

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
| Baseline, either separate room, busy daytime, maximum growth, Field Guide, or options | 261 game-subtree nodes, 33 collision objects, 47 collision shapes, 28 targets, 4 buildings, 2 separate rooms |
| Ordinary pursuit | 263 nodes, 34 collision objects, 48 collision shapes, 1 pursuer |
| Pursuit in active crowd cover | Pursuit structure remains at 263 nodes, 34 collision objects, and 48 collision shapes; 5 meetup visitors bring draw-only city activity to 20 actors |
| Animal Control net attack | 1 draw-only projectile; pursuit structure remains at 263 nodes, 34 collision objects, and 48 collision shapes |
| Roadblock pursuit or gameplay peak | 265 nodes, 35 collision objects, 49 collision shapes, 1 pursuer, 1 roadblock |
| Populated Belly sample | 64 items and rows, 517 nodes; this is a stress sample, not a gameplay capacity limit |
| Busy daytime activity | 10 routed pedestrians, 5 meetup visitors, and 5 secondary vehicles, all draw-only |
| Peak rainy daytime | 4 pedestrians, 3 secondary vehicles, and 84 rain streaks, all draw-only; structural counts remain at the baseline ceiling |
| Simultaneous presentation | 24 world effects and 3 touch cues; neither adds physics objects |
| Audio | 6 fixed players: 1 music, 1 ambience, and 4 reusable effect voices |
| Populated Field Guide | 29 rows, matching the fixed catalog |

Run the rendered Windows measurements without writing a benchmark report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\measure-performance-windows.ps1
```

The harness uses fixed random seeds and covers baseline play, the active Leap
Café stockroom, the active Canal Apartments upper hall, busy daytime, ordinary
and crowd-cover pursuit, a temporary roadblock, an Animal Control net in
flight, maximum growth, a finite maximum presentation burst, a 64-item Belly,
the populated Field Guide, both accessibility options, and a reachable
gameplay peak combining daytime activity, pursuit, growth, the roadblock, and
presentation effects. It prints median FPS, frame-time percentiles, memory, and
a post-sample render snapshot. The command-driven Windows run can show isolated
scheduling/window stalls, so p95 is more useful than its maximum or
arithmetic-mean FPS.

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
[`33327784555`](https://github.com/CHDAFNI-MSFT/SamuelIcecream/actions/runs/33327784555)
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

The successful remote run built exact audio commit
`73cfb5ef1cbc8d3d5e9eb71dbec44a4455d8fd76`. Godot CI run
[`33327743256`](https://github.com/CHDAFNI-MSFT/SamuelIcecream/actions/runs/33327743256)
also passed on that commit. Later gameplay commits require their own Godot CI
result and remain outside the unsigned iOS integration run until that manual
workflow is separately authorized. Known non-fatal generated-project warnings
are recorded in [`ios-release.md`](ios-release.md).

## Prototype boundaries

This is a mechanics prototype, not a finished game. It deliberately uses
simple vector graphics and a fixed city area so the eating and growth loop can
be evaluated before larger production work.

The following parts of the full design are not implemented yet:

- procedural endless city generation and additional districts;
- further authored multi-room interiors and connected exploration spaces;
- pathfinding around complex city geometry;
- additional pursuer types, trap varieties, and roadblock layouts;
- storms, festivals, shops with schedules, and random emergencies;
- achievements, story clues, and secrets beyond the Field Guide;
- additional temporary powers;
- final art, authored animation, expanded audio content and target-device mix
  validation, and any accessibility work beyond the implemented motion,
  interface-size, contrast, touch-feedback, safe-area, and volume controls; and
- the first signed TestFlight upload, A16 iPad validation, and App Store
  release.

Each player can change **Reduce motion** and **Larger text & controls** from the
main menu or the in-game **Options** panel. The same panels provide **Master**,
**Music & ambience**, and **Effects** controls. These optional settings are
stored in the existing version 1 profile save without changing score, tutorial,
or Field Guide semantics. Older saves deterministically use accessibility off
and audio levels of 80%, 45%, and 80%. The `frog_city/reduced_motion` Godot
project setting remains a fallback for direct scene runs that are not
configured through a player profile; it is not a mute control.

The audio assets are generated entirely by
[`scripts/generate-audio.ps1`](../scripts/generate-audio.ps1). Provenance,
reproduction instructions, and licensing status are recorded in
[`assets/audio/README.md`](../assets/audio/README.md). No external samples or
licensed commercial music are included, and the complete asset set remains
below 2 MiB without Git LFS.

An Apple Developer Program membership is not required for local gameplay
development or the repository's unsigned checks. It becomes necessary before
signed TestFlight or App Store distribution.

## Next implementation priorities

Continue the prototype one reviewed priority at a time:

1. Keep credential-free unsigned iOS integration, signed TestFlight work, and
   A16 iPad validation as separately approved release tasks; no gameplay change
   implicitly authorizes them.
2. Select one next bounded gameplay slice from the remaining prototype backlog,
   such as another connected interior, another pursuer behavior, or another
   dynamic city event.
3. Review, test, document, and commit that slice before beginning another
   system.

The broader unimplemented feature list above defines the remaining prototype
boundaries. `docs/game-design.md` remains the source of truth for the intended
full-game experience.
