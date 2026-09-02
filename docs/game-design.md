# Game Design Requirements

This document records the durable gameplay decisions from the design interview.
It describes the intended player experience rather than implementation details.
The selected release title is **Frog City Feast**.

## Product and presentation

- Target device: iPad with an A16 chip, running the latest supported iOS.
- Orientation: landscape.
- Format: single-player, touch-first, third-person game.
- Camera: positioned behind the frog.
- Primary goal: explore freely and achieve a high score.
- The game has no timer, lives-based ending, or forced round ending. The player
  chooses an always-visible End Game control to finish and return to the main
  menu.

The repository's technical requirement remains a 2D game built with Godot
4.7.2 and GDScript. The behind-the-frog view must therefore be presented using
the project's 2D visual style rather than changing the documented technology
stack.

The game uses a safe-area-aware 1280×960 reference layout. Important
HUD controls stay inside device-safe edges without resizing or repositioning the
game world. Interface text and controls use high-contrast original vector
presentation, explicit text labels, and touch actions that are at least 56
pixels high in normal presentation.

Accessibility choices are stored independently for each local player profile:

- **Reduce motion** removes camera shake, scale and wobble pulses, tongue
  travel, tutorial-marker pulsing, struggle-width pulses, and decorative city
  movement while retaining informational text, color flashes, the tongue line,
  city density changes, and streetlight state.
- **Larger text & controls** modestly increases interface text and raises touch
  actions to at least 64 pixels without changing world scale, collision,
  targeting, or score behavior.
- **Input timing** offers Standard, Relaxed, and Hold Assist modes. Relaxed
  mode accepts a wider double-tap window and reduces repeated-tap demand; Hold
  Assist lets a player hold a target to use the tongue and hold during escape
  struggles for bounded repeat input.
- **Camera assistance** provides 50%-150% manual sensitivity, optional
  movement auto-alignment after a 1.8-second manual-input grace period, and an
  explicit camera reset.
- **Haptics** are independently optional, safely no-op outside iOS and Android,
  and do not depend on audio or Reduce Motion.
- **Left-handed HUD** mirrors the action-first top bar and bottom instruction
  card while preserving the same safe-area and touch-target requirements.

All controls are available from player selection and during play. Tutorial
targets, rare targets, resistant targets, and dangerous targets use shape or
glyph cues in addition to color. Completed profiles can replay the tutorial
without clearing the saved completion flag, score, Field Guide, achievements,
clues, powers, or secret unlocks. Older saves use behavior-safe defaults.

Each profile also stores three audio controls:

- **Master volume**, defaulting to 80%;
- **Music & ambience**, defaulting to 45%; and
- **Effects volume**, defaulting to 80%.

The production audio direction is soft chamber-synth with marimba-like plucks,
warm pads, toy percussion, playful city motifs, and gentle day/night texture.
It is non-vocal, unobtrusive, and original to the project. Menu, daytime,
nighttime, pursuit, and epilogue contexts have distinct music while music and
ambience share one control. Gameplay and interface effects remain independently
adjustable. A zero setting mutes its bus. Reduce Motion remains independent and
never changes audio volume.

### Performance requirements

The fixed 1280×960 presentation targets 60 FPS on an A16 iPad. Performance
instrumentation is a developer-only local tool: it is off by default,
input-transparent when enabled, writes no reports or save data, and performs no
remote analytics, player tracking, or network telemetry.

Hardware-dependent acceptance budgets for an A16 iPad release build are:

- at least 58 sustained FPS over a 30-second sample, targeting 60 FPS;
- frame-time p95 at or below 18 ms, against a 16.67 ms frame target;
- main-thread process-time p95 at or below 8 ms;
- physics-process-time p95 at or below 2 ms;
- static memory at or below 192 MiB;
- video memory at or below 256 MiB; and
- no more than 450 draw calls, 1,800 rendered objects, and 50,000 rendered
  primitives in the documented stress states.

These measurements must not become CI pass/fail gates because frame scheduling,
render-driver behavior, and GPU performance vary by host. Godot's runtime
performance monitors do not provide GPU frame time, so final GPU acceptance
requires Xcode's Metal profiling tools on the target iPad. The unsigned
Godot-to-Xcode export and generic-device compile are verified; installing a
profiling build on the device remains separate signed-device work.

Deterministic structural budgets are enforced independently of hardware. The
authored core permits 36 gameplay targets, 4 buildings, 10 separate exploration
rooms, 1 pursuer, 1 temporary physical roadblock, 1 profile-driven draw-only
pursuit trap, 1 scheduled physical city detour, 20 draw-only city actors, 84
batched draw-only rain streaks, 40 batched draw-only wind ribbons, 10 draw-only
night-bazaar lanterns, 8 draw-only
kite-festival decorations, 1 draw-only Animal Control net projectile, 24 capped
world effects, 3 touch cues, and 6 fixed audio players including 4 reusable
effect voices. Baseline and separate-room states permit up to 331 game-subtree
nodes, 41 collision objects, and 111 collision shapes; ordinary pursuit, net
attack, and the scheduled city detour permit 333 nodes. Any pursuit-trap
profile permits 334 nodes; a straight-roadblock pursuit permits 335 nodes; a
staggered-roadblock pursuit permits 336 nodes; and the reachable
staggered-roadblock-and-snare gameplay peak permits 337 nodes. Physics ceilings
remain 42 collision objects and 112 shapes for ordinary pursuit or a trap, 43
objects and 113 shapes for a straight roadblock or detour-plus-trap state, and
43 objects and 114 shapes for the staggered roadblock and gameplay peak. The
performance Belly scenario renders 64 item rows within 587 nodes without
changing the Belly's unlimited gameplay semantics. A recoverable save warning
adds exactly two temporary UI nodes, including while Options is open. The score
epilogue adds 15 temporary UI nodes, for a maximum 348-node ending state when a
save warning is also retained. The Guide catalog contains 49 Field Guide
entries, but bounded journal pagination renders one text row at a time, with at
most 7 Field Guide entries on a page.

The generated-city stress state holds a maximum 3x3 ring of 9 generated
districts, with 9 generated buildings and 72 generated targets. Its measured
structural ceiling is 541 game-subtree nodes, 100 collision objects, and 172
collision shapes, including the always-resident authored core. Untouched
district definitions are regenerated instead of retained after unloading;
only compact state for changed districts remains in session memory.
The secret-district variant retains the same district, building, and target
caps; its worst-case obstacle composition permits 556 nodes, 104 collision
objects, and 183 collision shapes.

Ground navigation uses a deterministic, world-aligned `AStarGrid2D` query
window over the active room or loaded district bounds. Requests are fail-closed
at 160 obstacle rectangles, 70,000 total coarse/fine query cells, and 512
smoothed route points. A 16-pixel cardinal grid handles ordinary routes; a
bounded 4-pixel refinement is used only for nearby physically valid narrow
passages. Navigation state adds no scene nodes or physics bodies.

The final fixed-seed September 1, 2026 rendered Windows stress run included
deliberate multi-corner queries in both peak states. The authored gameplay peak
held 31 active obstacle rectangles and reached 6,480 query cells, 4 smoothed
points, and 2,794 microseconds for its largest observed request. The maximum
generated ring held 61 obstacles and reached 6,408 cells, 4 points, and 4,063
microseconds. Both states completed every request without fallback, failure, or
budget rejection.

Reproducible stress coverage includes the maximum generated-district ring, all
ten connected exploration rooms, both scheduled shops, the night bazaar,
busy daytime city activity, peak rain, all three pursuer-and-trap profiles at
the zero-event clock boundary, the wind squall and Canal Kite Festival alone
and with every pursuer-and-trap profile, pursuit, active crowd cover, both
roadblock layouts, the staggered-roadblock-and-snare peak, the rain-window city
detour alone and with every pursuer-and-trap profile, a net in flight, maximum
growth, a finite simultaneous presentation burst, a 64-item Belly, the longest
fully populated Guide page, both accessibility settings, and a reachable gameplay
peak. The same snapshots assert that Moonlight Market remains open throughout
wind and kite states, Oddities Shop overlaps the night bazaar, and both shops
are closed during the repair. Boundary tests cover the exact handoffs at
clocks 0.46, 0.56, 0.58, 0.62, 0.74, and 0.78. Desktop measurements are
advisory; the target iPad release build is authoritative. The exact commands
and current local measurement notes are recorded in
[`playable-prototype.md`](playable-prototype.md).

## Player character and touch controls

The player controls a frog.

- Tap a location on the ground to make the frog run there.
- Ground movement preserves the exact tapped destination when it is reachable,
  routes around successive collision obstacles, and visibly redirects to the
  nearest safe reachable point when the requested location is blocked or
  outside loaded city space.
- Double-tap a target to shoot the frog's tongue at it.
- Use a second finger to rotate the camera.
- Brief draw-only cues confirm accepted movement, tongue attempts, and camera
  rotation without participating in hit testing or changing the touched point.
- The tongue has a fixed maximum range.
- The tongue aims at the exact screen location touched by the player.
- A hit anywhere on a valid target can succeed, but a hit nearer its center
  earns an accuracy bonus.
- A miss causes a short tongue recovery and may give the target enough time to
  escape. A normal miss does not directly remove a life or time.
- Distant targets appear smaller.

## Core eating mechanic

The frog can attempt to swallow anything that is not secured strongly enough,
including ordinary food, loose objects, vehicles, living characters, removable
building parts, and eventually weakened buildings.

- The frog begins small and can only swallow targets appropriate to its current
  size.
- If a target is too large or too secure, the attached tongue pulls the frog
  toward the target instead of moving the target.
- Targets that resist initiate a struggle. The player rapidly taps anywhere on
  the screen to pull the target in.
- If the player loses a struggle, the target escapes.
- Small or successfully captured targets are swallowed immediately into the
  frog's belly.
- Living characters are handled as harmless cartoon targets. When digested,
  they become points and reappear elsewhere unharmed.

### Buildings

Buildings are eaten in stages rather than swallowed immediately:

1. The frog eats removable parts such as signs, doors, furniture, and sections
   of wall.
2. Removing parts weakens the building.
3. Once the frog is large enough and the building is weak enough, the remaining
   structure can be swallowed.

## Belly, digestion, and spitting

The player can open a view inside the frog's belly and manage swallowed
contents.

- The belly has unlimited magical capacity.
- Swallowing does not immediately award points.
- The player chooses which swallowed targets to digest.
- Points are awarded when a target is digested.
- The player may instead spit a target out, restoring it safely to the nearby
  world without awarding points.

The scoring value associated with a swallowed target must retain relevant
capture information until digestion, including the accuracy of the tongue hit
and whether the target was captured under dangerous conditions.

## Scoring

The score cannot fall below zero.

An item's value may increase based on:

- its size;
- its rarity;
- how close the tongue hit was to its center;
- whether it was found in a dangerous location; and
- whether it was captured while the frog was being chased.

Rare targets are worth many points, appear only in unusual places, and may
grant temporary powers.

The game records:

- the best score ever achieved on the iPad; and
- a separate best score for each local player profile.

### Save data ownership and migration

Save version 3 uses one local `ConfigFile` and stores no account, advertising,
analytics, social, contact, or other personal information. Every persistent
field has one explicit ownership scope:

| Section and key | Scope | Meaning and default |
|---|---|---|
| `meta.version` | Device | Save schema version; `3`. |
| `profiles.<profile_id>` | Profile | Local display name, normalized to at most 24 characters. |
| `scores.<profile_id>` | Profile | Best completed or in-progress score observed for that profile; `0`. |
| `device.best_score` | Device | Highest score observed across local profiles; `0`. |
| `tutorial.<profile_id>` | Profile | Whether the first-time tutorial was completed or skipped; `false`. |
| `discoveries.<profile_id>` | Profile | Sorted unique known Field Guide target IDs; empty. |
| `accessibility.<profile_id>` | Profile | Reduce Motion and Larger Text & Controls (`false`); input assistance (`standard`); camera sensitivity (`1.0`); camera auto-align, haptics, and left-handed HUD (`false`). |
| `audio.<profile_id>` | Profile | Sanitized master, music/ambience, and effects levels; `0.80`, `0.45`, and `0.80`. |
| `profile_achievements.<profile_id>` | Profile | Sorted unique known one-time achievement IDs; empty. |
| `story_clues.<profile_id>` | Profile | Sorted unique known story-clue IDs; empty. |
| `power_discoveries.<profile_id>` | Profile | Sorted unique temporary-power IDs encountered by that profile; empty. |
| `secret_unlocks.<profile_id>` | Profile | Sorted unique stable secret-content unlock IDs; empty. |
| `device_achievements.unlocked` | Device | Sorted unique known one-time device milestone IDs; empty. |

Current score, current growth, Belly contents, location, current powers and
their remaining time, session challenges, city clock, city seed, loaded
districts, generated definitions, and generated-city deltas are session state
and are never written by Start New Game.

Loading a version 1 save first renames the untouched source file to a timestamped
`migration-v1-to-v2` backup before migrating through version 3. Loading a
version 2 save creates a `migration-v2-to-v3` backup. Both paths preserve all
existing profile and device fields, seed the new accessibility values with
behavior-safe defaults, and set `meta.version` to `3`. Unknown future versions
and unreadable files retain the existing preservation behavior. If the
original file cannot be preserved, saving is disabled rather than overwriting
it.

Every version 3 load also performs an idempotent derived-progress repair before
the menu is shown. It backfills achievements implied by device best score,
unique Field Guide discoveries, whole-building discoveries, all power
discoveries, or all event goals;
backfills clues implied by saved discoveries or achievements; and restores the
Golden Crumb from a saved Flight discovery. It also restores the clue-threshold
achievement and secret-path unlock when six clues are present. This recovery
uses the same stable IDs and does not change score, growth, session state, or
the fresh-city rule.

## Growth and powers

Growth is a central form of progression within play.

- Digesting normal targets gradually fills a growth meter.
- Rare targets can provide large growth boosts.
- The frog becomes visibly larger.
- The tongue becomes longer.
- Larger targets become swallowable.
- People and vehicles react more strongly as the frog grows.
- New areas become reachable at larger sizes.

The implemented deterministic rebalance is centralized in
`src/gameplay_tuning.gd`. Cumulative growth uses four physical tiers:

| Tier | Growth required | Visual scale | Collision radius | Ground speed | Tongue range | City zoom | Camera lead |
|---|---:|---:|---:|---:|---:|---:|---:|
| Small | 0 | 1.00 | 28 | 330 | 380 | 0.90 | 220 |
| Growing | 100 | 1.25 | 35 | 345 | 500 | 0.86 | 230 |
| Large | 500 | 1.58 | 44 | 355 | 650 | 0.78 | 250 |
| Enormous | 1,700 | 2.35 | 66 | 320 | 900 | 0.62 | 320 |

Camera rotation is preserved when a growth tier changes; only the deterministic
zoom and forward lead change. The slower enormous ground speed offsets its
larger collision footprint and longest tongue.

Score is the authored base value multiplied by `1 + 0.35 × size tier + 0.45 ×
accuracy + 0.80 if rare + 0.30 if dangerous + 0.45 if swallowed during active
pursuit`, rounded to the nearest integer with a minimum of one. Growth reward
is the authored base value multiplied by `1.00`, `1.10`, `1.25`, or `1.35` for
target size tiers zero through three, rounded to the nearest integer, plus 45
for a rare target. The guided Market Sign fills any remaining gap to the first
100-growth threshold so the tutorial retains its guaranteed growth lesson;
the same sign uses the ordinary formula in free play.

Resistant targets use a 3.4-second struggle. Required taps are the authored tap
count minus the frog's size-tier advantage over the target, with a floor of
four taps. Equal-size struggles therefore retain their authored difficulty,
while returning to a smaller resistant target after growing is easier.

Vehicles and fully weakened whole buildings become edible at the Large tier.
Pursuers remain dangerous and protect their eligible targets through Large,
then become edible and unable to damage, net, or trap the frog at Enormous.
Enormous growth never makes roads, walls, bridges, portals, furniture, or other
fixed collision geometry edible.

Enormous growth is outdoor-only. Reaching 1,700 growth inside a connected room
stores a pending session tier and applies it at the first collision-safe
outdoor position after exit. An enormous frog cannot enter authored rooms or
the hidden-maintenance portal, but an enormous state restored inside by a test
or future migration may still use room exits. Enormous growth adds no scene
nodes and uses the existing generated-district streaming ceiling.

One confirmed temporary power allows the frog to fly around the city for one
minute. The progression milestone also adds:

- a 20-second Speed Burst that increases ground movement by 35%;
- a 30-second Long Tongue power that increases range by 40% and shortens
  recovery by 20%;
- a 20-second Camouflage power that prevents new pursuit calls and accelerates
  loss of an existing pursuer; and
- a Bubble Shield that blocks one eligible pursuit hit and otherwise expires
  after 30 seconds.

Temporary powers activate immediately when their source item is digested.
There is no separate activation button. The HUD uses full power names and
remaining seconds instead of letter abbreviations. To preserve all top-bar
actions with large text and safe-area insets, it reserves a bounded readable
timer slot and rotates through every active named power at 2.5-second
intervals, while also showing the number of other active powers. Its desktop
tooltip lists every active named timer. Persistent status guidance retains the
selected eating control while explaining that powers need no separate button.
Flight uses the normal click/tap destination control while allowing the route
to cross ground walls and obstacles.

Power durations count active play only and pause while the Belly, Field Guide,
or Options overlay or a room-transition fade pauses player control. Powers
persist through connected-room transitions. Recollecting the same power keeps
the longer of its current remaining time and the power's standard duration
rather than adding durations; different powers may coexist. Speed Burst
affects only ground movement, so it does not multiply flight speed.

The current power sources are:

| Power | Digested source | Active behavior |
|---|---|---|
| Flight | Flying Golden Cake | Ignores ground collision while remaining bounded to the active city or room; safe landing is required when time expires. |
| Speed Burst | Rooftop Beehive | Ground movement uses a 1.35 multiplier; flight retains its own fixed multiplier. |
| Long Tongue | Cursed Music Box | Tongue range uses a 1.40 multiplier and every ordinary or trap-applied tongue recovery is reduced to 80%. |
| Camouflage | Maintenance Pump Handle | New pursuer calls fail, active attacks cancel, and an existing pursuer loses the frog after 0.8 seconds. |
| Bubble Shield | Lily Pad Planter | Blocks one Animal Control net, pursuer contact, pursuer attack, or damaging pursuit trap, then ends. It does not block traffic. |

All five power IDs are recorded once per profile when first activated. Repeated
digestion can refresh gameplay time but cannot repeat discovery progress.

## Infinite city

The game takes place in an endless city. New districts continue to generate as
the frog explores. Damage and destruction remain in previously visited places
during the current game rather than being automatically repaired.

The implemented foundation keeps the authored city as district `(0,0)` and
places generated districts on a deterministic 3520×2720 world grid. Each game
creates a session seed without using the existing gameplay random-number
stream. A district's coordinate and that session seed reproduce its archetype,
streets, building, entrances, obstacles, open restock points, targets, and
pursuit anchors.

Generated neighbors stream in before the frog reaches a district edge. Outside
the core, the active district and its surrounding 3x3 ring are loaded, capped
at nine generated districts. Distant generated nodes are removed from the
scene tree. Untouched districts are regenerated on demand, while compact
session-local deltas retain removed targets, moved or spat-out targets, removed
building parts, and consumed or restored buildings.

After six profile clues reveal the secret path, a star portal appears in the
Hidden Sewer Maintenance Pocket. It leads to **Starfall Quarter**, a special
fantasy archetype placed four to six districts from the core at a coordinate
derived from the current session seed. The district uses the same one-building,
four-target, 3x3 streaming, collision, navigation, destruction, and compact
delta limits as ordinary generated districts. A marked return star leads back
to Hidden Maintenance without replacing the original River Park return.

The chosen coordinate is reserved from session start with stable
`secret_district_<x>_<y>` instance IDs, even while it still presents an
ordinary archetype before unlock. Revealing Starfall Quarter replaces only the
definition and preserves removed or moved targets, building damage, swallowed
building references, and other session deltas already recorded there.

The secret unlock persists, but its coordinate, layout details, target state,
and destruction state do not. Start New Game derives a fresh placement and
fresh district state from the new city seed. First entry grants one profile
achievement and one device milestone; revisits cannot farm either.

**Start New Game always creates a fresh city.** Score, growth, Belly contents,
location, city seed, destruction, moved targets, and generated-district deltas
reset. Per-profile Field Guide entries, achievements, story clues, power
discoveries, secret unlocks, preferences, and tutorial state persist, along
with device-wide best score and device milestones. Generated world deltas are
therefore session state and are not written to the profile save.

The city contains a large variety of shops, apartments, restaurants, and other
enterable locations. A rare discovery is a large open plot containing many
things to eat.

### District types

- Downtown skyscrapers (implemented foundation archetype)
- Apartment neighborhoods (implemented foundation archetype)
- Restaurant district
- Shopping district (implemented foundation archetype)
- Outdoor market
- Suburbs and backyards
- Industrial area (implemented foundation archetype)
- Parks and gardens (implemented foundation archetype)
- Waterfront and canals (implemented foundation archetype)
- Construction sites
- Entertainment district
- Secret fantasy district (implemented as the clue-gated Starfall Quarter)

### Buildings and interiors

- Every building can be entered.
- Entering an interior uses a short transition or fade.
- Ordinary interiors are compact, with a few important rooms rather than a
  complete simulation of every room and floor.
- Additional potential exploration spaces include upper floors, rooftops, fire
  escapes, balconies, sewers, subway tunnels, parks, ponds, construction
  cranes, and secret underground areas.
- The navigation system marks buildings the player has discovered.
- Generated districts currently contain one enterable street-level building
  shell with a collision-safe doorway, three removable parts, and a
  large-growth whole-building capture. Generated separate rooms and upper
  levels remain future work.
- The current game has staged destruction for all four authored
  buildings. Each requires three removable parts and Large growth before the
  whole weakened building can be swallowed.
- Leap Café stays enterable throughout its ordered sequence: remove the
  Sidewalk Menu Board, grow once and win an interior struggle with the Rear
  Espresso Counter, then strip the Front Awning. Its left bar remains in place
  so the Loose Phone still requires entering the café for a clear tongue shot.
- Canal Apartments also stays enterable throughout its ordered sequence:
  remove the Address Plaque, grow once and win an interior struggle with the
  Lobby Bench, then strip the Entry Canopy. The remaining wall-side furniture
  keeps the Tenant's Cat and Lobby Lamp exploration paths intact.
- Leap Café and Canal Apartments use wall-hugging solid furniture with
  collision-aware routes through their central aisles. Their interior targets
  require the frog to enter, remain
  associated with their rooms when restocked, and reward exploring the space.
- Leap Café also has the game's first separate room: a marked rear door
  leads through a short fade to a compact stockroom with solid shelving, a
  centered room camera, a return door, and a Stockroom Coffee Tin target. The
  normal End Game HUD action becomes Exit Room while any connected room is
  active, routes to that room's marked return door, and changes back after
  returning outdoors. A short post-exit grace period prevents repeated exit
  taps from immediately ending the score run. The stockroom entry point stays
  outside the return marker's hit radius so the player's first movement tap
  cannot accidentally leave. Belly, Guide, and Options use Back to Game rather
  than claiming that closing an overlay returns to the city.
  Entering hides the frog from active Animal Control pursuit. Reduce motion
  replaces the fade with an immediate cut, and consuming the café disables the
  stockroom entrance until the building is restored.
- Canal Apartments has the second connected room: marked lobby stairs lead to
  a compact upper hall with solid wall-side furnishings, the same centered
  room camera, a return-to-lobby marker, and a tier-one Hallway Vacuum target.
  The target remains scoped to the upper hall when spat out or restocked.
  Entering also ends active pursuit, Reduce motion uses an immediate cut, and
  consuming the apartments disables the stairs until the building is restored.
- The Canal Apartments upper hall now continues through a growth-gated fire
  door to a larger authored fire escape. This first multi-stage room chain uses
  paired safe landings instead of returning every room directly to the city.
  The fire escape uses a bounded follow camera, retains open central space for
  Large growth, and contains a room-scoped Balcony Laundry Basket. Returning
  through the upper hall restores the original city camera. Consuming the
  apartments disables the whole chain until the building is restored.
- River Park now has a marked sewer hatch leading to a larger Sewer Junction,
  which continues into an Old Subway Service Tunnel and returns through the
  same two-stage route. Both sections use bounded follow cameras, authored
  Large-size-safe landings, central navigation space, and room-scoped
  targets: the Sewer Valve Wheel and resistant Abandoned Signal Lamp. Entering
  the chain ends pursuit, blocks remote pursuit spawning, pauses generated
  district streaming, and restores the River Park position and city camera on
  exit. Reduce motion converts every leg to an immediate cut.
- Discovering the existing Sewer Valve Wheel reveals an otherwise invisible
  maintenance hatch in the Sewer Junction. The hatch branches into a compact
  Hidden Sewer Maintenance Pocket without adding a new story dependency. Its
  fixed camera, paired safe landings, and central floor support Large growth;
  its dangerous, resistant Maintenance Pump Handle remains scoped to the
  pocket for Belly returns and restocking. The persistent Field Guide
  discovery keeps the hatch revealed, direct transition calls cannot bypass
  the hidden gate, remote pursuit remains blocked, district unloading stays
  paused throughout the branch, and Reduce motion uses immediate cuts.
- The River Park pond now has a marked boardwalk entrance leading to a larger
  Lily Pond Boardwalk with a bounded follow camera, authored safe arrival and
  return positions, open Large-growth navigation space, and a room-scoped
  Lily Pad Planter. Entering ends pursuit and blocks remote pursuit spawning;
  leaving restores the River Park camera and exact safe return position.
- The northwest construction site now has a marked lift that unlocks after the
  first growth tier and reaches a large Construction Crane High Deck. Its
  bounded follow camera permits limited rotation without exposing neighboring
  authored rooms, while the widened deck, authored lift landings, and central
  route remain safe at Large growth. Entering ends pursuit, blocks remote
  pursuit spawning, and preserves a room-scoped dangerous, resistant Crane
  Operator Toolbox for Belly returns and restocking. Reduce motion uses an
  immediate lift cut and restores the city camera on return.
- Moonlight Market has the first progression-gated rooftop: after growing once,
  the frog can use the marked interior ladder to reach a compact rooftop garden
  with solid wall-side planters, a centered room camera, a return-to-market
  marker, and a resistant tier-one Rooftop Beehive. The target remains scoped
  to the garden when spat out or restocked. Entering ends active pursuit,
  remote pursuit spawning remains blocked, Reduce motion uses an immediate
  cut, and consuming the market disables the ladder until restoration.
- Oddities Shop has the first destruction-gated connected room. Removing the
  Curio Shelf reveals a marked trapdoor to a compact cellar with solid
  wall-side storage, a centered room camera, a return-to-shop marker, and a
  resistant tier-one Cursed Music Box. The target remains scoped to the cellar
  when spat out or restocked. Entering ends active pursuit, remote pursuit
  spawning remains blocked, Reduce motion uses an immediate cut, and consuming
  the shop disables the trapdoor until restoration. The removed shelf and
  cellar access remain unlocked after the shop is restored.

### Dynamic city events

The city can change through:

- a day and night cycle;
- storms;
- changing crowd sizes;
- changing traffic levels;
- shops opening and closing;
- special festivals;
- random emergencies; and
- fantasy events.

The fixed city implements nine small deterministic dynamic-city
slices. The day and night cycle changes the visible pedestrian crowd, secondary
traffic level, streetlight glow, and restrained synthesized ambience. Once per
180-second cycle, a 36-second daytime rain shower fades in, reaches a steady
peak, and fades out. Peak rain adds fixed draw-only streaks, wet-road sheen,
puddle highlights, and a cooler tint while reducing ambient activity from 10
pedestrians and 5 vehicles to 4 pedestrians and 3 vehicles. The 84 streaks are
submitted as one batched draw-only mark set. Reduce motion keeps
the wet presentation and lower density but freezes the streaks with the other
decorative movement. Rain adds no audio asset, physics, targeting, scoring,
save data, random-number use, or Field Guide entry.

Earlier in the daytime window, a separate 29-second wind squall fades in for
7.2 seconds, holds for 14.4 seconds, and fades out for 7.2 seconds while the
River Park meetup and all authored pedestrian and traffic routes remain active.
Forty mathematically positioned directional ribbons are submitted as one
batched draw-only mark set across the city, with a subtle cool-grey tint.
Reduce motion freezes their translation while the deterministic schedule,
intensity, direction, and fixed visible count remain readable. The squall adds
no nodes, actors, collision, forces, targeting, damage, score, growth, Belly
items, saves, discoveries, challenges, gameplay random-number use, or Field
Guide entries. Connected-room travel and generated-district streaming retain
the same single global presentation layer rather than duplicating weather.

Earlier in the same cycle, five draw-only visitors gather for a 68-second River
Park meetup, including a 50-second steady interval, then disperse before rain
begins. During pursuit, the marked 145-unit meetup area becomes crowd cover. A
small or medium ground frog that remains free inside it for 1.75 seconds loses
Animal Control. Leaving the area resets progress; flight, Large or Enormous
growth, knockback, netting, tongue pulls, and target struggles cannot build cover.
Reduce motion freezes the visitors while preserving event and hiding timing.
The meetup adds no collision, target, save, audio, or gameplay-random behavior.

Oddities Shop implements the first scheduled business. Its intact removable
shutter raises from the late-evening boundary through early morning, revealing
the existing entrance without weakening the building. During the day it lowers
and becomes the same edible shutter used by the destruction sequence. Closure waits while the frog or Animal Control occupies the shop or doorway,
or while the frog explores the connected cellar, preventing a character from
being trapped or overlapped. Eating the shutter permanently opens the entrance
for the rest of that city session. The schedule is deterministic, adds no
nodes, targets, saves, audio, animation, or random-number use, and has
identical timing with Reduce motion.

Moonlight Market implements a separate daytime business schedule. Its intact
removable door opens from clock 0.30 through the instant before 0.58, spanning
50.4 seconds of each 180-second cycle and closing as the rain window begins.
Closure waits while the frog or any pursuer occupies the market or doorway, or
while the frog explores the connected rooftop, so the schedule cannot trap or
overlap a character. Eating the door permanently opens the entrance for the
rest of the city session, and consuming the building cannot re-enable its
collision. The outdoor Moonlight Market night bazaar remains a separate event
after the indoor market closes. The schedule uses no random numbers, new
nodes, saves, score, growth, Belly changes, discoveries, challenges, audio, or
Field Guide progress, and Reduce motion does not alter its timing.

Moonlight Market hosts the first festival event. Ten fixed draw-only lanterns
fade in around the market during the late-evening boundary, remain lit through
midnight, and fade out before the daytime River Park meetup begins. Their
motion uses the existing absolute city-activity clock, and Reduce motion keeps
them lit while freezing their gentle sway. The bazaar adds no scene nodes,
collision, targeting, scoring, saves, audio assets, gameplay random-number use,
or Field Guide entries.

The Canal Kite Festival is a separate daytime event. It begins exactly when the
wind squall ends, fades in for 3.6 seconds, holds for 10.8 seconds, and fades
out for 3.6 seconds before the rain window. Eight fixed kites sway above River
Park while the nearby meetup and routed daytime activity remain available.
Their outlines and tails are grouped into two batched draw calls with one
static event label; Reduce motion freezes the gentle sway without hiding the
kites, label, intensity, or schedule. The festival adds no actors, collision,
forces, targets, saves, score, growth, Belly items, discoveries, challenges,
gameplay random-number use, audio assets, or Field Guide entries. Pursuit,
crowd escape, traps, roadblocks, room travel, and district streaming continue
to use their existing rules.

During the steady rain window, one bounded water-main repair creates a temporary
detour from clock 0.62 through the instant before 0.74. It tries three authored
core-city anchors in fixed order and retries once per second if live collision,
targets, buildings, entrances, portals, or safe navigation margins block every
site. The repair uses one `StaticBody2D`, one collision shape, a fixed label,
and no animation or gameplay randomness. Ground movement and pursuers route
around it, flight crosses it, and Enormous growth retains a verified safe route.
It may coexist with one draw-only pursuer trap, but it never overlaps a
pursuit roadblock: an existing roadblock finishes first, while new roadblocks
wait until the repair window ends. The detour expires at the schedule boundary,
clears on connected-room travel or leaving the authored core, retries on a safe
return during the same window, and updates navigation on every deployment and
cleanup. It changes no score, growth, Belly state, saves, discoveries,
challenges, targets, audio, gameplay random-number state, or Field Guide
progress.

Ambient pedestrians and vehicles use authored routes and are decorative rather
than targets, hazards, or persistent world state. The labeled Delivery Van
remains the game's interactive traffic target.

### Target locations

Targets may be found in:

- restaurants and shops;
- outdoor markets;
- gardens and open lots;
- the possession of people;
- food-delivery vehicles; and
- strange or fantasy locations.

## Threats and pursuit

Larger people, dogs, security, and animal-control characters can threaten a
small frog. Traffic is dangerous while the frog is small, but vehicles become
edible after sufficient growth.

There is no automatic city-wide alert meter. A target that escapes or observes
the right event can call for help.

Pursuers are summoned only when the frog loses a resistant-target struggle.
Successful swallows do not create a pursuit. A failed struggle against an
object, vehicle, removable building part, or whole building calls Security; a
failed living-target struggle calls the Watchdog; and another failed resistant
target calls Animal Control. Ordinary eating and non-resistant targets never
summon Security.

Pursuers may:

- chase the frog;
- block roads and doors;
- interrupt or deflect the tongue;
- protect valuable targets; and
- set traps.

Ground pursuers use the same deterministic collision topology as player
movement, with their own radius, bounded repath cadence, and stuck recovery.
They cannot route through active building or room collision, roadblocks, or
district space that is not loaded. Their net sweeps and tongue-deflection
checks remain direct physics queries rather than navigation decisions.

The game's Animal Control pursuer implements the first bounded net
attack. A small or medium ground frog within the authored range receives a
clear 0.8-second aim warning before one draw-only net travels along the locked
path. The net sweeps its full radius against building collision, so walls and
corners stop it, and moving out of the telegraphed line dodges it. A hit
interrupts an active tongue struggle, roots the frog for a three-second escape,
and reuses the existing rapid-tap panel. The panel explicitly states that only
the net temporarily locks movement and directs desktop players to left-click
rapidly or touch players to tap rapidly anywhere; Hold Assist accepts a
continuous press. Six inputs tear through the net without
changing score or progression; timing out applies a 22-point capped loss and
knockback. Flight and Enormous growth are immune. Reduce motion removes
the telegraph and escape scale pulses while preserving the gameplay timing and
static net information. The attack is deterministic, uses no gameplay random
numbers, adds no collision or scene nodes, and has a distinct warning sound.

Animal Control also explicitly deflects tongue shots from a small or medium
frog. A direct shot at the officer, or a shot whose path crosses the officer
before reaching another target, stops at the officer with a short draw-only
shield flash and the normal tongue recovery. The intended target, score,
growth, challenges, and Field Guide remain unchanged. At Enormous growth the
officer can no longer protect targets: shots pass through the block, while a
direct hit can swallow Animal Control through the existing discovery path.
Reduce motion keeps the static flash while suppressing its expansion. The
deflection adds no scene nodes, collision, saves, or gameplay random-number
use.

Security Guard is the second bounded pursuer archetype. Secured objects,
vehicles, building parts, and whole-building struggles can call one guard
instead of Animal Control. The guard is slower and searches the last visible
frog position using the same deterministic generated-district navigation, but
solid city geometry breaks its 760-unit line of sight and three uninterrupted
seconds without detection ends the chase. It protects only nearby valuables,
not food or living targets, and uses a 0.65-second draw-only flashlight warning
instead of a net. Remaining in the locked beam applies one 10-point capped
knockback; stepping out of the beam, moving behind a wall, flying, or reaching
Enormous growth prevents the strike. Crowd cover loses the sight-based guard in
1.1 seconds. The guard deploys no physical roadblock, but after five eligible
seconds it can place one draw-only motion beacon with a 0.5-second calibration
warning. An armed beacon reveals a ground frog through geometry for two seconds
and clears partial crowd-hide progress without damage or immobilization. At
Enormous growth it can be swallowed into the Belly and discovered in the Field
Guide like Animal Control. Reduce motion freezes beam decoration while
preserving its warning and hit timing.

Watchdog is the third bounded pursuer archetype. Resistant living targets can
call one dog instead of Animal Control. Its 860-unit scent detection ignores
walls while the frog remains on the ground, and its 22-unit navigation radius,
320-unit speed, and shorter repath cadence let it use narrower generated-city
routes than either person. It protects only nearby living targets and attacks
with a 0.45-second warning followed by one 220-unit physical lunge using its
existing collision body. Walls stop the lunge, moving out of its locked path
dodges it, and a hit applies one 14-point capped knockback. Flight breaks scent
and ends the chase after 1.4 seconds; crowd cover takes 0.8 seconds; the total
chase is capped at 22 seconds. The dog deploys no physical roadblock, but after
four eligible seconds it can leave one draw-only sticky scent patch with a
one-second settling warning. An armed patch applies 1.2 seconds of ordinary
tongue recovery without stopping movement, changing score, or dealing damage.
The dog uses no projectile or gameplay random numbers and remains edible at
Enormous growth with its own Belly and Field Guide record. Reduce motion
suppresses decorative lunge pulses and trails without changing warning,
movement, collision, or hit timing.

The River Park meetup implements the first crowd-based pursuit escape. While
the daytime meetup is active, pursuit changes its marked area to `HIDE HERE`
and a static progress ring fills as an eligible frog stays within the crowd.
Completing the short hold dismisses Animal Control without awarding score,
growth, challenge progress, or Field Guide credit.

Animal Control can deploy one temporary physical roadblock per chase. After
three unpaused, movement-enabled pursuit seconds, the nearest safe authored road
anchor 260–850 units from the frog selects its fixed layout; if no anchor is
currently valid, deployment waits and retries without consuming the allowance.
Straight anchors use one solid segment. Staggered anchors use two offset
segments with an authored opening of at least 148 units, preserving a route for
the 132-unit-diameter Enormous frog while still creating a visible
chicane. Both layouts are represented by one capped roadblock body, with at
most two collision shapes and two navigation rectangles.

Every segment is checked against live collision, building footprints, targets,
loaded navigation bounds, and 90-unit Enormous edge clearance before deployment.
The roadblock blocks ground movement, pursuer movement, net sweeps, and tongue
rays; flight passes over it. Three tongue hits anywhere on its body break the
entire layout, while an untouched roadblock expires after ten seconds.
Breaking or expiry never
deploys a replacement during the same pursuit. Pursuit end, connected-room
travel, and generated-district changes clear it immediately and rebuild
navigation topology. Placement is deterministic, uses no gameplay random
numbers, and changes no score, growth, target, save, challenge, or Field Guide
state.

Each pursuer can deploy one profile-driven draw-only sidewalk trap per chase at
the nearest safe authored anchor 180–700 units from the frog. If no anchor is
safe, deployment retries without consuming the allowance. Animal Control waits
six eligible seconds, then places a 46-unit snare with a 0.75-second arming
warning and twelve-second lifetime. Eligible contact applies the existing
capped damage and knockback flow for 12 points; active damage recovery prevents
the snare from stacking with another hit, and triggering it cancels an
overlapping net so knockback cannot become an immediate capture loop. Security
waits five seconds, then places a 54-unit motion beacon with a 0.5-second
warning and ten-second lifetime. It deals no damage, clears partial crowd
cover, and grants exactly two seconds of forced sight before wall-aware
detection resumes. Watchdog waits four seconds, then leaves a 42-unit sticky
patch with a one-second warning and
fourteen-second lifetime. It deals no damage or immobilization and applies 1.2
seconds of tongue recovery while movement and pursuit escape remain available.

Flight, Enormous growth, knockback, movement-disabled states, net escape, tongue
pulls, and target struggles prevent every trap profile from triggering.
Triggered or expired traps never redeploy in the same pursuit. Pursuit end,
connected-room travel, and generated-district changes clear them immediately.
Reduce motion freezes decorative pulses while retaining labels, arming changes,
and all gameplay timing. Placement uses no gameplay random numbers, changes no
navigation topology, and adds no collision, target, save, score, growth,
challenge, or Field Guide state beyond Animal Control's explicitly documented
12-point damage.

If a pursuer catches the frog:

- the frog is knocked backward; and
- points are lost, but the score never drops below zero. Contact costs 20
  points for Animal Control, 16 for Security, and 12 for the Watchdog.

Ordinary pursuit never disables movement. The frog can escape by clicking or
tapping ground to outrun pursuers, hiding inside buildings, losing them in
crowds, or using temporary powers. Animal Control only roots the frog after a
net hit, and movement returns after either breaking the net or taking its
bounded timeout penalty. Once sufficiently large, the frog can also eat its
pursuers.

## Additional goals

Discovering every target type is now a confirmed secondary goal. The game
implements this through a persistent per-player Frog Field Guide.
Each unique target is recorded on its first successful swallow, without
awarding extra score or growth.

Short challenges are also a confirmed session goal. Each normal session shows
three fixed tasks: make three swallows at 90% accuracy or better, win two
rapid-tap struggles, and swallow four distinct target types. Challenge progress
starts after the tutorial is completed or skipped, resets with each game, and
awards presentation-only completion feedback so it cannot distort score,
growth, or permanent Field Guide progress. Returning and re-eating a target can
count as another accurate swallow, while the distinct-target task only counts
each target ID once per session.

The progression milestone confirms all remaining optional goal categories:

- non-farmable achievements with visibly separate session, profile, and
  device-wide progress;
- an enormous-growth tier beyond the current maximum, with explicit collision,
  camera, navigation, room, target-eligibility, and performance behavior;
- the four additional temporary powers defined above;
- eight to ten optional, persistent story clues outside the Field Guide;
- one bounded secret-fantasy district path unlocked through those clues; and
- one-time goals tied to existing deterministic city events.

The story remains a light environmental mystery. Clues use short,
child-friendly captions in a separate journal section, imply rather than fully
explain the mystery, and do not require cutscenes, dialogue trees, accounts, or
personal information. Collecting enough clues reveals the secret-district
path, but reading story text is never required for score-focused free play.

The Guide & Journal now presents progression under explicit ownership
headings:

- **Session goals** are the three existing challenges and reset on every Start
  New Game. They never grant score, growth, powers, or permanent rewards.
- **Profile achievements** are stable one-time IDs. They cover first growth,
  twelve unique Field Guide entries, a whole weakened building, all five
  unique power discoveries, six unique clues, all four event goals, and the
  future secret-district and enormous-growth milestones.
- **Device milestones** are separate stable one-time IDs for a 2,500 device
  best score and the future first secret-district and enormous-growth events.

Achievement triggers use unique or monotonic state. Re-eating a restocked
target, repeating a completed event action, recollecting a known power, or
swallowing another building cannot add duplicate permanent progress. The four
event achievements require any successful swallow during the deterministic
Moonlight Market bazaar, Canal Kite Festival, active water-main repair, or
wind-squall windows, including an eligible pursuer swallow. Completing all four
unlocks Event Explorer.

The nine persistent clues are Golden Crumb from digesting Golden Cake, Sewer
Stamp from the hidden pump handle, Moonlit Receipt from the bazaar goal,
Silver Kite Thread from the kite goal, Folded Blueprint from the repair goal,
Oddities Label from the cellar music box, Crane Operator's Map from the crane
toolbox, District Glyph from finding all six normal generated archetypes, and
Giant Shadow from swallowing a whole weakened building. Six unique clues
permanently reveal the secret-fantasy path for that profile. The path unlock
persists, while its generated city placement and contents remain fresh session
state.

## Progression milestone decisions

The September 1, 2026 progression decision checkpoint resolved the remaining
product questions:

- **New games:** Start New Game creates a fresh generated city and gameplay
  session while retaining only profile and device meta-progress.
- **Pursuit calls:** only a lost resistant struggle summons the target's
  documented pursuer archetype; successful eating does not alert Security.
- **Goals:** achievements, enormous growth, additional powers, story clues,
  secret districts, and deterministic event goals are all included.
- **Attachment boundary:** only explicit edible targets and staged removable
  sign, door or awning, counter, and other separately authored target parts can
  be removed. Roads, walls, bridges, portals, and fixed structural geometry
  remain permanent until an eligible whole building is swallowed. Enormous
  growth does not turn arbitrary collision geometry into targets.
- **Powers:** Speed Burst, Long Tongue, Camouflage, and Bubble Shield join the
  existing one-minute Flight power under the timing and replacement rules
  above.
- **Tuning:** a full gameplay rebalance is approved for point values, growth
  thresholds, tongue range and recovery, struggle difficulty, and pursuit
  penalties. Exact values must remain deterministic, documented, and covered
  by focused tests.
- **Story:** use the light environmental mystery described above, with eight
  to ten concise persistent clues and an implied secret-district reveal.

Every new persistent field must be documented with its ownership scope and
default. Existing saves must migrate forward without losing profiles, scores,
tutorial completion, Field Guide discoveries, accessibility settings, or audio
settings.

## Production direction

The September 1, 2026 production checkpoint resolves the remaining publication
direction. Visual review remains intentionally deferred until publication; the
production pass must follow this direction without requesting iterative visual
approval.

### Art and tone

- Use a hybrid original-asset system built from reviewable SVG source files,
  with restrained shaders or draw overlays only where they improve weather,
  lighting, interaction feedback, or transitions.
- Use a layered storybook cut-paper style with rounded silhouettes and a tone
  of whimsical, gentle mischief.
- Use warm confectionery city colors, teal canals and parks, and violet-and-
  amber nights. Informational states must remain contrast-safe and readable
  without relying on color alone.
- Use medium selective detail: keep navigation silhouettes clean while giving
  interactive targets, characters, landmarks, and story clues richer detail.
- Keep every asset original to the project. Record source, authorship, license,
  and reproduction instructions in the repository asset ledger.

### Animation

Use snappy cutout-style animation with readable anticipation, squash and
stretch, clear impacts, and subtle ambient loops. Movement, tongue use,
swallowing, struggles, growth, damage, pursuit, weather, destruction, and
transitions each require distinct feedback. Reduce Motion must retain the
state change, label, silhouette, and timing while removing continuous travel,
camera shake, pulsing, and decorative motion.

### Music and sound

- Expand the original score into a soft chamber-synth palette using marimba-
  like tones, plucked voices, toy percussion, warm pads, and playful city
  motifs.
- Adapt music for the menu, day, night, pursuit, major growth, and end-game
  summary without making music necessary for gameplay.
- Use layered original synthesized or reproducibly authored cartoon foley,
  creature sounds, and city ambience without spoken dialogue.
- Preserve independent Master, Music & ambience, and Effects controls, bounded
  reusable effect voices, deterministic variation, and gameplay-randomness
  isolation.
- The production implementation uses five compact four-second music loops, two
  four-second ambience loops, 31 semantic effects, and exactly six persistent
  players: one music, one ambience, and four reusable effect voices. Pursuit
  temporarily overrides day/night music and restores the current time-of-day
  cue when the chase ends; the score postcard uses the epilogue context.

### Menu, onboarding, and ending

Use an illustrated title scene, skippable contextual onboarding cards,
journal-style clue postcards, and a score-summary end-game epilogue. Story
presentation remains concise, child-friendly, optional for score-focused play,
and free of required reading, cutscenes, or dialogue trees.

The production implementation uses an original draw-only city-and-canal title
backdrop, illustrated tutorial cue cards, numbered clue postcards inside the
Guide & Journal, a paused score postcard before returning to the title, and
short input-blocking screen fades. Reduce Motion converts screen fades and
decorative card movement to immediate/static presentation. Save read, backup,
and write failures are surfaced as persistent player-facing warnings while
technical error details remain in the Godot log.

### Accessibility additions

In addition to the existing scalable text, contrast, Reduce Motion, touch
targets, safe-area layout, independent audio, and readable status feedback,
the production pass includes:

- color-vision-safe icons, patterns, labels, and non-color state cues;
- adjustable double-tap, rapid-tap struggle, and hold timing assistance;
- camera sensitivity, auto-align assistance, and a one-touch camera reset;
- independently controlled haptic feedback;
- replayable onboarding and contextual help; and
- left- or right-handed HUD action placement.

All additions are stored per profile with documented defaults and migration
behavior. Accessibility assistance must not change score formulas, target
eligibility, world geometry, or progression ownership.

### Distribution

Prepare a normal public App Store release path. TestFlight is unavailable to
the target device because its Apple Account is under 13; do not falsify age or
attempt to bypass Apple's restriction. The App Store export path must not set
`testFlightInternalTestingOnly`.

Preparation does not authorize signing, uploading, submission, publication,
release creation, or tag creation. Those operations require separate explicit
approval after the production pass, metadata, device measurements, and release
checklists are complete.
