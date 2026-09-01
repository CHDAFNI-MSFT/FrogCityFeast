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
- deterministic collision-aware tap routes around multiple building corners,
  exact reachable destinations, and clear nearest-safe fallback feedback for
  blocked or unloaded destinations;
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
- deterministic Animal Control routes around authored and generated buildings,
  active roadblocks, and loaded-district boundaries, with bounded repathing and
  stuck recovery for later ground-pursuer compatibility;
- Animal Control tongue deflection that stops direct shots and shots crossing
  the officer before another target, uses draw-only shield feedback and normal
  recovery, and stops protecting targets once the frog reaches maximum growth;
- a Security Guard pursuer for escaped valuables and building struggles, with
  760-unit wall-aware line-of-sight detection, slower last-seen-position
  navigation, valuables-only tongue protection, a dodgeable 0.65-second
  draw-only flashlight strike, 1.1-second crowd escape, flight-based detection
  loss, one non-damaging five-second motion-beacon deployment, no physical
  roadblock stacking, and maximum-growth Belly capture;
- a Watchdog pursuer for escaped living targets, with 860-unit wall-ignoring
  ground scent, faster 22-unit-radius navigation, living-target-only
  protection, a wall-stopped and dodgeable 0.45-second physical lunge,
  0.8-second crowd escape, 1.4-second flight scent loss, one non-damaging
  four-second sticky-patch deployment, no physical roadblock stacking, and
  maximum-growth Belly capture;
- a deterministic Animal Control net attack with a 0.8-second warning, one
  wall-aware draw-only projectile, a dodge window, and a three-second six-tap
  escape;
- net failure that reuses the existing 25-point capped loss and knockback,
  while flight and maximum growth prevent capture;
- one deterministic physical Animal Control roadblock per pursuit, deployed
  after three eligible seconds at the nearest safe authored road anchor as
  either a straight segment or a two-segment staggered chicane, breakable with
  three tongue hits, self-expiring after ten seconds, and cleared immediately
  when pursuit ends;
- a minimum 104-unit authored opening through every staggered chicane so the
  maximum-growth frog retains a clear escape route, while flight passes over
  either layout;
- one deterministic draw-only Animal Control sidewalk snare per pursuit,
  deployed after six eligible seconds with a 0.75-second arming warning,
  harmless to flight and maximum growth, self-expiring after twelve seconds,
  applying one 15-point capped knockback when an eligible frog triggers it,
  and cancelling an overlapping net before it can create a capture loop;
- one deterministic draw-only Security motion beacon per pursuit, deployed
  after five eligible seconds with a 0.5-second calibration warning, clearing
  partial crowd cover and revealing an eligible frog for exactly two seconds
  without damage or immobilization;
- one deterministic draw-only Watchdog sticky patch per pursuit, deployed
  after four eligible seconds with a one-second settling warning, applying 1.2
  seconds of tongue recovery without stopping movement or changing score;
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
- an authored central district retained as the starting district, surrounded
  by deterministic generated districts as the frog approaches city edges;
- six generated archetypes: downtown, apartment neighborhoods, industrial,
  waterfront, shopping, and parks-and-gardens;
- seamless matching through streets, collision-safe open areas, environmental
  obstacles, enterable street-level building shells, four loose targets, and
  staged building destruction in every generated district;
- a dedicated per-district random-number generator derived from a session seed,
  without consuming the existing gameplay random-number stream;
- bounded streaming with at most nine generated districts, nine generated
  buildings, and 72 generated targets loaded around the active district;
- deterministic regeneration of untouched districts plus compact session-only
  deltas for removed or moved targets, relocated spat-out items, removed
  building parts, and consumed or restored buildings;
- cross-district Belly restocking, Field Guide discovery categories, camera
  follow, pursuit handoff, and unchanged authored connected-room scoping;
- rare-target replenishment on a randomized 90–180 second schedule;
- a rare golden cake that grants one minute of flight;
- a lightweight day and night cycle that changes the world tint, pedestrian
  crowd, secondary traffic, and streetlight glow;
- deterministic Oddities Shop hours that raise its intact removable shutter
  from late evening through early morning, defer daytime closure while the shop
  or doorway is occupied, and preserve permanent access after the shutter is
  eaten;
- deterministic daytime Moonlight Market hours that open its intact removable
  door from clock 0.30 to 0.58, defer rain-boundary closure while the hall,
  doorway, any pursuer, or connected rooftop is occupied, and preserve
  permanent access after the door is eaten;
- a deterministic Moonlight Market night bazaar with ten fixed draw-only
  lanterns that fade in during late evening, remain active through midnight,
  fade out before the daytime meetup, and freeze their sway with Reduce motion;
- a distinct deterministic 18-second Canal Kite Festival that starts when the
  wind squall ends, uses eight fixed draw-only kites and one static label,
  overlaps daytime routes and the River Park meetup, and freezes kite sway with
  Reduce motion;
- one deterministic 36-second daytime rain shower per 180-second cycle, with
  smooth fades, wet-road sheen, puddle highlights, and 84 capped draw-only rain
  streaks;
- peak rain presentation that reduces ambient activity from 10 pedestrians and
  5 secondary vehicles to 4 pedestrians and 3 vehicles without itself changing
  gameplay targets, collision, scoring, saves, the Field Guide, or the
  day/night audio;
- one deterministic rain-window water-main repair from clock 0.62 to 0.74,
  using one physical segment selected from three authored fallback anchors,
  one-second blocked-site retries, and no shared gameplay RNG;
- a safe detour that ground movement and pursuers route around, flight crosses,
  maximum growth can bypass, and room travel or generated-district departure
  clears; it can coexist with one draw-only trap but never a pursuit roadblock;
- one deterministic 29-second daytime wind squall per cycle, with 7.2-second
  fades around a 14.4-second steady interval, a subtle tint, and 40 fixed
  directional ribbons submitted as one batched draw-only mark set;
- peak wind that overlaps all 20 daytime city actors without adding forces,
  collision, targeting, damage, score, growth, Belly items, saves, discoveries,
  challenges, Field Guide entries, or gameplay random-number use;
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
- a persistent, per-profile Frog Field Guide covering all 36 gameplay target
  IDs plus Animal Control, Security Guard, and Watchdog, including Golden Cake and all four
  destructible-building sequences;
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
- a growth-gated fire door from the upper hall to a larger Canal Apartments
  fire escape, providing the first two-stage room chain, paired authored
  landings, bounded follow-camera movement, safe maximum-growth space, and a
  room-scoped Balcony Laundry Basket;
- fire-escape traversal that keeps the original city return and camera state
  across both rooms, blocks remote pursuit, rejects cross-room Belly returns,
  uses immediate cuts with Reduce motion, and is disabled with its apartment
  building until restoration;
- a marked River Park sewer hatch leading to a navigable Sewer Junction and
  then an Old Subway Service Tunnel, with authored two-way landings, safe
  maximum-growth routes, and restored River Park camera state on final exit;
- room-scoped Sewer Valve Wheel and resistant Abandoned Signal Lamp targets
  whose Belly returns and restocking remain in their original sewer sections;
- an initially invisible Sewer Junction maintenance hatch revealed by the
  existing Sewer Valve Wheel discovery state, leading to a compact Hidden
  Sewer Maintenance Pocket with safe two-way landings, a fixed camera,
  maximum-growth central space, and a dangerous resistant Maintenance Pump
  Handle;
- hidden-pocket traversal that cannot be bypassed with direct transition
  calls, remains unlocked through persistent Field Guide state, pauses
  generated-district unloading, blocks remote pursuit, rejects cross-space
  Belly returns, restocks its target in place, and supports Reduce motion;
- a marked River Park pond boardwalk leading to a larger navigable Lily Pond
  space with maximum-growth-safe central routes and a room-scoped Lily Pad
  Planter;
- a growth-gated northwest construction lift leading to a large Construction
  Crane High Deck with authored safe landings, maximum-growth central space, a
  bounded follow camera, limited rotation, and a room-scoped resistant Crane
  Operator Toolbox whose dangerous-location bonus survives valid deck returns
  and restocking;
- crane-deck traversal that ends active pursuit, blocks remote pursuit
  spawning, rejects cross-space Belly returns, restocks its target on the
  deck, uses an immediate cut with Reduce motion, and restores the original
  city camera and lift position;
- a marked Moonlight Market rooftop ladder that requires one growth tier,
  leads through the same bounded transition to a solid rooftop garden, uses a
  fixed room camera, and provides a return-to-market marker;
- rooftop hiding that ends active pursuit, blocks remote pursuer spawning,
  uses an immediate cut with Reduce motion, and becomes inaccessible while
  Moonlight Market is consumed;
- a resistant tier-one Rooftop Beehive that remains scoped to the garden when
  spat out or restocked;
- a marked Oddities Shop cellar trapdoor that unlocks only after the Curio
  Shelf is removed, then leads through the same bounded transition to a solid
  cellar with a fixed room camera and return-to-shop marker;
- cellar hiding that ends active pursuit, blocks remote pursuer spawning,
  defers the shop's daytime shutter closure, uses an immediate cut with Reduce
  motion, and becomes inaccessible while Oddities Shop is consumed;
- a resistant tier-one Cursed Music Box that remains scoped to the cellar when
  spat out or restocked;
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
  - optionally use the revealed trapdoor to explore the Curio Cellar;
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
traffic, deterministic city-activity levels and routes, Oddities Shop hours and
safe deferred closure through connected-cellar travel, growth- and
destruction-gated room transitions, Moonlight Market daytime hours and safe
deferred closure through connected-rooftop travel, the bounded night-bazaar schedule,
the bounded kite-festival schedule and fixed decoration count,
frame-step-independent festival motion, the bounded rain schedule and density
change, the bounded wind-squall schedule and density,
frame-step-independent weather marks, static reduced-motion weather and
festivals, room and district event-layer stability, water-main deployment
retries, exact expiry, ground blocking, maximum-growth routing, flight passage,
navigation invalidation, roadblock mutual exclusion, pursuit, net windup
and wall clearance, dodging, tongue interruption and deflection, Security
Guard sight loss, valuables-only protection, flashlight dodging and damage,
Watchdog scent, living-target protection, lunge wall stopping and dodging,
straight and staggered roadblock selection, multi-segment collision and
navigation, maximum-growth chicane passage, roadblock retries, breakage,
expiry, transition and district-unload cleanup, profile-driven trap selection,
exact arming and expiry boundaries, harmless reveal and tongue-delay effects,
simultaneous attack windows, maximum-size deflection immunity, rapid-tap escape
and timeout damage, flight and growth immunity,
profile persistence, Field Guide catalog and overlay behavior,
legacy discovery saves, per-profile accessibility persistence and legacy
defaults, touch-target sizing, safe-area layout, touch feedback, reduced-motion
transitions, deterministic session challenges,
original audio resources and provenance, audio buses and semantic event wiring,
bounded player/cooldown behavior, per-profile audio persistence and legacy
defaults, loop lifecycle, gameplay RNG isolation, performance structure and
stress budgets, deterministic multi-corner navigation, exact and nearest-safe
destinations, dynamic route invalidation, pursuer routing, deterministic
district generation, live-physics clearance,
boundary loading, distant unloading, revisit restoration, compact delta state,
cross-district restocking, pursuit cleanup, and the credential-free iOS pipeline
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
objects, targets, buildings, loaded/generated/changed district counts,
generated target and building counts, pursuit, city actors, effects, and
overlay data.
Live render-server counters are deliberately omitted because polling them can
disturb the frame being observed.
The overlay also reports navigation topology revision, active obstacle and
route-point counts, request/fallback/failure totals, and peak bounded query
cells and request time. The gameplay-peak and generated-streaming harness
states each issue a deterministic multi-corner query so these values are
measured under obstacle-routing load rather than only direct movement.

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
| Baseline, night shop, any separate room, busy daytime, peak wind, maximum growth, Field Guide, or options | 369 game-subtree nodes, 41 collision objects, 111 collision shapes, 36 targets, 4 buildings, 10 separate rooms |
| Day-open Moonlight Market | Structural counts remain at the 369-node baseline ceiling; one existing removable door collision is disabled and navigation uses one fewer obstacle |
| Ordinary Animal Control pursuit | 371 nodes, 42 collision objects, 112 collision shapes, 1 pursuer |
| Security Guard pursuit or flashlight warning | 371 nodes, 42 collision objects, 112 collision shapes, 1 pursuer; the flashlight is draw-only |
| Watchdog pursuit or lunge | 371 nodes, 42 collision objects, 112 collision shapes, 1 pursuer; the lunge reuses that body |
| Animal Control tongue deflection | Pursuit structure remains at 371 nodes, 42 collision objects, and 112 collision shapes; feedback is draw-only |
| Pursuit in active crowd cover | Pursuit structure remains at 371 nodes, 42 collision objects, and 112 collision shapes; 5 meetup visitors bring draw-only city activity to 20 actors |
| Animal Control net attack | 1 draw-only projectile; pursuit structure remains at 371 nodes, 42 collision objects, and 112 collision shapes |
| Any pursuer-specific trap | 372 nodes, 42 collision objects, 112 collision shapes, 1 pursuer, 1 draw-only snare, motion beacon, or sticky patch |
| Straight-roadblock pursuit | 373 nodes, 43 collision objects, 113 collision shapes, 1 pursuer, 1 roadblock segment |
| Staggered-roadblock pursuit | 374 nodes, 43 collision objects, 114 collision shapes, 1 pursuer, 2 roadblock segments |
| Reachable gameplay peak | 375 nodes, 43 collision objects, 114 collision shapes, 1 pursuer, 1 two-segment roadblock, 1 draw-only snare |
| Maximum generated ring | 9 generated districts, 9 generated buildings, 72 generated targets; 579 nodes, 100 collision objects, and 172 collision shapes including the authored core |
| Navigation query | At most 160 active obstacle rectangles, 70,000 total coarse/fine grid cells, and 512 smoothed route points per request |
| Populated Belly sample | 64 items and rows, 625 nodes; this is a stress sample, not a gameplay capacity limit |
| Busy daytime activity | 10 routed pedestrians, 5 meetup visitors, and 5 secondary vehicles, all draw-only |
| Moonlight Market night bazaar | 10 fixed draw-only lanterns; structural counts remain at the baseline ceiling |
| Canal Kite Festival | 8 fixed draw-only kites over daytime activity; structural counts remain at the baseline ceiling |
| Kite festival with Security or Watchdog | One pursuer-specific draw-only trap, 20 city actors, 8 kites, and 24 presentation effects; 372 nodes, 42 collision objects, and 112 collision shapes |
| Kite festival gameplay peak | Animal Control, one draw-only snare, the two-segment staggered roadblock, 20 city actors, 8 kites, and 24 presentation effects; 375 nodes, 43 collision objects, and 114 collision shapes |
| Peak rainy daytime with water-main repair | 4 pedestrians, 3 secondary vehicles, 84 batched draw-only rain streaks, and 1 physical detour segment; 371 nodes, 42 collision objects, and 112 collision shapes |
| Water-main repair with any pursuer profile | One pursuer, one profile-specific draw-only trap, one physical detour segment, and no roadblock; 374 nodes, 43 collision objects, and 113 collision shapes |
| Peak wind squall | 10 pedestrians, 5 meetup visitors, 5 secondary vehicles, and 40 batched draw-only directional ribbons; structural counts remain at the baseline ceiling |
| Wind with Security or Watchdog | One pursuer-specific draw-only trap, 20 city actors, 40 wind ribbons, and 24 presentation effects; 372 nodes, 42 collision objects, and 112 collision shapes |
| Simultaneous presentation | 24 world effects and 3 touch cues; neither adds physics objects |
| Audio | 6 fixed players: 1 music, 1 ambience, and 4 reusable effect voices |
| Populated Field Guide | 49 rows, matching the fixed authored and generated-type catalog |

Run the rendered Windows measurements without writing a benchmark report:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\measure-performance-windows.ps1
```

The harness uses fixed random seeds and covers baseline play, the night-open
Oddities Shop, the day-open Moonlight Market, the Moonlight Market bazaar, the
active Leap Café stockroom, the
active Canal Apartments upper hall and connected fire escape, the two-section
River Park sewer and subway chain, the River Park pond boardwalk, the
discovery-gated Hidden Sewer Maintenance Pocket, the
growth-gated Construction Crane High Deck, the
progression-gated Moonlight Market rooftop garden, the fixture-gated Oddities
Shop cellar, busy daytime, peak rain, the wind squall alone and combined with
Security's motion beacon and Watchdog's sticky patch, the Canal Kite Festival
alone and combined with all three pursuer-and-trap profiles, ordinary and
crowd-cover Animal Control pursuit, the rain-window water-main repair alone and
combined with all three pursuer-and-trap profiles,
Security Guard pursuit and flashlight warning, active tongue-deflection
feedback, Watchdog pursuit and lunge, a temporary
straight roadblock, a two-segment staggered roadblock, all three
pursuer-specific draw-only traps, an Animal Control net in flight, maximum
growth, a finite maximum presentation burst, a 64-item Belly, the populated
Field Guide, both accessibility options, a maximum 3x3 generated-district ring,
and a reachable gameplay peak combining peak wind, daytime activity, pursuit,
growth, the roadblock, the snare, and presentation effects. It prints median
FPS, frame-time percentiles, memory, and
a post-sample render snapshot. The command-driven Windows run can show isolated
scheduling/window stalls, so p95 is more useful than its maximum or
arithmetic-mean FPS.

Repeated August 31, 2026 local GL Compatibility measurements at 1280×960 on an
NVIDIA RTX 4050 laptop measured the fixed-seed maximum nine-district ring at
8.46–16.88 ms frame-time p95, 48.5–48.9 MiB static memory, 21.5 MiB video
memory, 54 draw calls, 542 rendered objects, and 3,962 primitives. Its current
structural snapshot is 579 game-subtree nodes, 100 collision objects, 172
collision shapes, 108 total targets, and 13 total buildings, exactly matching
the deterministic ceilings above. Its successful deliberate multi-corner
navigation request used 61 active obstacle rectangles, 6,408 grid cells, 4
smoothed points, and at most 2,986 microseconds across the repeated runs.

Repeated fixed-seed wind-squall measurements used all 20 daytime city actors
and 40 directional ribbons submitted in one draw command. The standalone
squall measured 8.50–8.55 ms frame-time p95, 46.6 MiB static memory, 19.3 MiB
video memory, 180 draw calls, 928 rendered objects, and 10,462 primitives.
Security plus its motion beacon and maximum presentation measured
8.72–16.51 ms p95, 427–432 draws, 1,109–1,145 objects, and 25,514–25,806
primitives. Watchdog plus its sticky patch and maximum presentation measured
15.96 ms p95 in the unobstructed sample, 433 draws, 1,139 objects, and 25,876
primitives. All three exact structural snapshots remained at their existing
369-node baseline or 372-node pursuer-and-trap ceilings. One repeated Watchdog
sample contained a 516.69 ms host scheduling/window stall and is not treated as
a target-device result.

The repeated fixed-seed combined authored gameplay peak now includes the wind
squall and measured 13.16 ms frame-time p95 in the unobstructed sample,
48.2 MiB static memory, 21.6 MiB video memory, 444 draw calls, 1,216 rendered
objects, and 26,012 primitives. Its exact structural snapshot remains 375
nodes, 43 collision objects, and 114 collision shapes with the two-segment
staggered roadblock and Animal Control snare active together. One repeated
sample reported 24.41 ms p95 alongside a 520.27 ms host scheduling/window
stall. The simultaneous presentation-only peak uses capped seven-spoke damage
bursts and measured 444 draw calls, below the 450-draw-call reference ceiling.

Repeated fixed-seed Canal Kite Festival measurements held the exact 8-kite
draw-only cap. The standalone festival measured 8.53–8.66 ms frame-time p95,
46.8 MiB static memory, 17.3–19.3 MiB video memory, 185–186 draw calls,
987–991 rendered objects, and 10,688–10,778 primitives. Security plus its
motion beacon and maximum presentation measured 9.20–13.43 ms p95 in
unobstructed samples; Watchdog plus its sticky patch measured 9.39 ms. Their
render snapshots remained at 433–434 draws, 1,172–1,178 objects, and
25,856–25,926 primitives. The full Animal Control festival peak measured
14.13–17.50 ms p95, 47.2 MiB static memory, 17.6–19.7 MiB video memory, 445
draw calls, 1,249 objects, and 26,062 primitives. Its structural snapshot
remains 375 nodes, 43 collision objects, and 114 collision shapes. Other
repeated Security and Watchdog samples contained host scheduling/window stalls
and are not treated as target-device results.

The fixed-seed day-open Moonlight Market state measured 8.70 ms frame-time p95,
46.8 MiB static memory, 19.3 MiB video memory, 159 draw calls, 816 rendered
objects, and 9,380 primitives. Its exact structural snapshot remains 369
nodes, 41 collision objects, and 111 collision shapes with all 36 targets and
4 buildings retained; opening disables one existing door collision and reduces
the active navigation obstacle count from 30 to 29.

The fixed-seed water-main repair measured 8.48 ms frame-time p95, 46.9 MiB
static memory, 19.3 MiB video memory, 151 draw calls, 961 rendered objects, and
9,044 primitives. Its maximum-growth detour query used 31 active obstacles,
1,128 grid cells, 4 smoothed points, and 946 microseconds. The exact structural
snapshot is 371 nodes, 42 collision objects, and 112 collision shapes. With 24
presentation effects and one profile trap, Animal Control measured 8.49 ms p95
and 390 draws, Security measured 12.67 ms and 392 draws, and Watchdog measured
15.70 ms and 393 draws. All three combined snapshots remained at 374 nodes, 43
collision objects, and 113 collision shapes with no pursuit roadblock.

The straight-roadblock snapshot measured 8.77 ms frame-time p95, 46.6 MiB
static memory, 19.5 MiB video memory, 211 draw calls, 906 rendered objects, and
11,974 primitives. The staggered snapshot measured 8.83 ms frame-time p95 with
the same memory, 223 draw calls, 989 rendered objects, and 12,340 primitives.
Their exact structural snapshots are respectively 373 nodes and 113 collision
shapes for one segment, and 374 nodes and 114 collision shapes for two
segments; both retain one collision body and 43 total collision objects.

The bounded Security Guard pursuit measured 8.81 ms frame-time p95, 46.2 MiB
static memory, 19.5 MiB video memory, 217 draw calls, 902 rendered objects, and
12,728 primitives. Its active draw-only flashlight warning measured 8.75 ms
frame-time p95 with the same memory, 207 draw calls, 896 rendered objects, and
12,098 primitives. Both exact structural snapshots are 371 nodes, 42 collision
objects, and 112 collision shapes, with one pursuer and no roadblock, trap, or
projectile node.

The bounded Watchdog pursuit measured 8.74 ms frame-time p95, 46.4 MiB static
memory, 19.5 MiB video memory, 208 draw calls, 877 rendered objects, and 12,058
primitives. Its physical lunge scenario measured 8.80 ms frame-time p95 with
the same memory and render snapshot. Both exact structural snapshots are 371
nodes, 42 collision objects, and 112 collision shapes; the lunge reuses the
single pursuer body and adds no projectile, collision shape, roadblock, or
trap.

The three fixed-seed pursuit-trap snapshots measured 8.81 ms frame-time p95 for
Animal Control's snare, 8.74 ms for Security's motion beacon, and 8.84 ms for
Watchdog's sticky patch. Each exact snapshot is 372 nodes, 42 collision
objects, and 112 collision shapes with one pursuer and one draw-only trap. The
three profiles used 46.5 MiB static memory, 19.5 MiB video memory, 206–215 draw
calls, 804–898 rendered objects, and 11,838–12,426 primitives.

The Construction Crane High Deck measured 8.56 ms frame-time p95, 45.7–45.9
MiB static memory, 17.3 MiB video memory, 37 draw calls, 356 rendered objects,
and 2,994 primitives. The Hidden Sewer Maintenance Pocket measured 8.59 ms
frame-time p95 with the same 45.9 MiB memory and render snapshot. Both have an
exact structural snapshot of 369 nodes, 41 collision objects, 111 collision
shapes, 36 targets, 4 buildings, and 10 authored rooms. Neither peak nor either
exploration space recorded a navigation fallback, failure, or budget
rejection. Command-driven desktop measurements remain advisory and can contain
scheduling outliers; all states still require explicit profiling on the A16
iPad. The unsigned Godot-to-Xcode pipeline is verified, but installing and
profiling on the target device still requires a separately authorized,
developer-signed device build.

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
simple vector graphics and a bounded streaming window so the eating, growth,
destruction, and endless traversal loops can be evaluated before larger
production work.

The following parts of the full design are not implemented yet:

- generated multi-room interiors, upper levels, rooftops, and authored events;
- restaurant, outdoor-market, suburban, construction, entertainment, and
  secret-fantasy generator archetypes;
- generated pedestrian and traffic routes beyond the authored central
  district;
- persistence of generated district state across application launches, which
  remains intentionally deferred until the new-game/resume decision is made;
- further authored multi-room interiors and connected exploration spaces;
- further fantasy events;
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
   such as a generated connected interior, another district archetype, another
   pursuer behavior, or another dynamic city event.
3. Review, test, document, and commit that slice before beginning another
   system.

The broader unimplemented feature list above defines the remaining prototype
boundaries. `docs/game-design.md` remains the source of truth for the intended
full-game experience.
