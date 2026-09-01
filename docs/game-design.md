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

The fixed prototype uses a safe-area-aware 1280×960 reference layout. Important
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

Both controls are available from player selection and during play. Older
version 1 saves that do not contain accessibility data use both choices as off.

Each profile also stores three audio controls:

- **Master volume**, defaulting to 80%;
- **Music & ambience**, defaulting to 45%; and
- **Effects volume**, defaulting to 80%.

The first audio direction is soft, playful arcade-like synthesis with gentle
city texture. It is non-vocal, unobtrusive, and original to the project. Music
and ambience share one control while gameplay and interface effects remain
independently adjustable. A zero setting mutes its bus. Reduce Motion remains
independent and never changes audio volume.

### Performance requirements

The fixed 1280×960 prototype targets 60 FPS on an A16 iPad. Performance
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
rooms, 1 pursuer, 1 temporary physical roadblock, 1 draw-only pursuit snare, 20
draw-only city actors, 84 draw-only rain streaks, 10 draw-only festival
lanterns, 1 draw-only Animal Control net projectile, 24 capped world effects,
3 touch cues, and 6 fixed audio players including 4 reusable effect voices.
Baseline and separate-room states permit up to 369 game-subtree nodes, 41
collision objects, and 111 collision shapes; ordinary pursuit and net attack
permit 371 nodes, 42 collision objects, and 112 collision shapes; a snare
pursuit permits 372 nodes with the same physics structure; a roadblock pursuit
permits 373 nodes, 43 collision objects, and 113 collision shapes; the
reachable roadblock-and-snare gameplay peak permits 374 nodes with the same 43
collision objects and 113 shapes. The performance Belly scenario renders 64
item rows within 625 nodes without changing the belly's unlimited gameplay
semantics. The populated Field Guide contains exactly 49 rows.

The generated-city stress state holds a maximum 3x3 ring of 9 generated
districts, with 9 generated buildings and 72 generated targets. Its measured
structural ceiling is 579 game-subtree nodes, 100 collision objects, and 172
collision shapes, including the always-resident authored core. Untouched
district definitions are regenerated instead of retained after unloading;
only compact state for changed districts remains in session memory.

Ground navigation uses a deterministic, world-aligned `AStarGrid2D` query
window over the active room or loaded district bounds. Requests are fail-closed
at 160 obstacle rectangles, 70,000 total coarse/fine query cells, and 512
smoothed route points. A 16-pixel cardinal grid handles ordinary routes; a
bounded 4-pixel refinement is used only for nearby physically valid narrow
passages. Navigation state adds no scene nodes or physics bodies.

Repeated fixed-seed August 31, 2026 rendered Windows stress runs included
deliberate multi-corner queries in both peak states. The authored gameplay peak
held 31 active obstacle rectangles and reached 6,480 query cells, 4 smoothed
points, and 2,872 microseconds for its largest observed request. The maximum
generated ring held 61 obstacles and reached 6,408 cells, 4 points, and 2,986
microseconds. Both states completed every request without fallback, failure, or
budget rejection.

Reproducible stress coverage includes the maximum generated-district ring, all
ten connected exploration rooms, the night
bazaar, busy daytime city activity, peak rain, pursuit, active crowd cover,
roadblock and snare pursuit, a net in flight, maximum growth, a finite
simultaneous presentation burst, a 64-item Belly, the fully populated Field
Guide, both accessibility settings, and a reachable gameplay peak. Desktop
measurements are advisory; the target iPad release build is authoritative. The
exact commands and current local measurement notes are recorded in
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

## Growth and powers

Growth is a central form of progression within play.

- Digesting normal targets gradually fills a growth meter.
- Rare targets can provide large growth boosts.
- The frog becomes visibly larger.
- The tongue becomes longer.
- Larger targets become swallowable.
- People and vehicles react more strongly as the frog grows.
- New areas become reachable at larger sizes.

One confirmed temporary power allows the frog to fly around the city for one
minute. Other temporary powers have not yet been defined.

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
building parts, and consumed or restored buildings. This generated world state
is deliberately not written to profile saves while the new-game/resume
decision remains unresolved.

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
- Secret fantasy district

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
  maximum-growth whole-building capture. Generated separate rooms and upper
  levels remain future work.
- The current prototype has staged destruction for all four authored
  buildings. Each requires three removable parts and maximum growth before the
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
- Leap Café also has the prototype's first separate room: a marked rear door
  leads through a short fade to a compact stockroom with solid shelving, a
  centered room camera, a return door, and a Stockroom Coffee Tin target.
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
  maximum growth, and contains a room-scoped Balcony Laundry Basket. Returning
  through the upper hall restores the original city camera. Consuming the
  apartments disables the whole chain until the building is restored.
- River Park now has a marked sewer hatch leading to a larger Sewer Junction,
  which continues into an Old Subway Service Tunnel and returns through the
  same two-stage route. Both sections use bounded follow cameras, authored
  maximum-size-safe landings, central navigation space, and room-scoped
  targets: the Sewer Valve Wheel and resistant Abandoned Signal Lamp. Entering
  the chain ends pursuit, blocks remote pursuit spawning, pauses generated
  district streaming, and restores the River Park position and city camera on
  exit. Reduce motion converts every leg to an immediate cut.
- Discovering the existing Sewer Valve Wheel reveals an otherwise invisible
  maintenance hatch in the Sewer Junction. The hatch branches into a compact
  Hidden Sewer Maintenance Pocket without adding a new story dependency. Its
  fixed camera, paired safe landings, and central floor support maximum growth;
  its dangerous, resistant Maintenance Pump Handle remains scoped to the
  pocket for Belly returns and restocking. The persistent Field Guide
  discovery keeps the hatch revealed, direct transition calls cannot bypass
  the hidden gate, remote pursuit remains blocked, district unloading stays
  paused throughout the branch, and Reduce motion uses immediate cuts.
- The River Park pond now has a marked boardwalk entrance leading to a larger
  Lily Pond Boardwalk with a bounded follow camera, authored safe arrival and
  return positions, open maximum-growth navigation space, and a room-scoped
  Lily Pad Planter. Entering ends pursuit and blocks remote pursuit spawning;
  leaving restores the River Park camera and exact safe return position.
- The northwest construction site now has a marked lift that unlocks after the
  first growth tier and reaches a large Construction Crane High Deck. Its
  bounded follow camera permits limited rotation without exposing neighboring
  authored rooms, while the widened deck, authored lift landings, and central
  route remain safe at maximum growth. Entering ends pursuit, blocks remote
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

The fixed-city prototype now implements five small deterministic dynamic-city
slices. The day and night cycle changes the visible pedestrian crowd, secondary
traffic level, streetlight glow, and restrained synthesized ambience. Once per
180-second cycle, a 36-second daytime rain shower fades in, reaches a steady
peak, and fades out. Peak rain adds fixed draw-only streaks, wet-road sheen,
puddle highlights, and a cooler tint while reducing ambient activity from 10
pedestrians and 5 vehicles to 4 pedestrians and 3 vehicles. Reduce motion keeps
the wet presentation and lower density but freezes the streaks with the other
decorative movement. Rain adds no audio asset, physics, targeting, scoring,
save data, random-number use, or Field Guide entry.

Earlier in the same cycle, five draw-only visitors gather for a 68-second River
Park meetup, including a 50-second steady interval, then disperse before rain
begins. During pursuit, the marked 145-unit meetup area becomes crowd cover. A
small or medium ground frog that remains free inside it for 1.75 seconds loses
Animal Control. Leaving the area resets progress; flight, maximum growth,
knockback, netting, tongue pulls, and target struggles cannot build cover.
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

Moonlight Market hosts the first festival event. Ten fixed draw-only lanterns
fade in around the market during the late-evening boundary, remain lit through
midnight, and fade out before the daytime River Park meetup begins. Their
motion uses the existing absolute city-activity clock, and Reduce motion keeps
them lit while freezing their gentle sway. The bazaar adds no scene nodes,
collision, targeting, scoring, saves, audio assets, gameplay random-number use,
or Field Guide entries.

Ambient pedestrians and vehicles use authored routes and are decorative rather
than targets, hazards, or persistent world state. The labeled Delivery Van
remains the prototype's interactive traffic target.

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

The prototype's Animal Control pursuer now implements the first bounded net
attack. A small or medium ground frog within the authored range receives a
clear 0.8-second aim warning before one draw-only net travels along the locked
path. The net sweeps its full radius against building collision, so walls and
corners stop it, and moving out of the telegraphed line dodges it. A hit
interrupts an active tongue struggle, roots the frog for a three-second escape,
and reuses the existing rapid-tap panel. Six taps tear through the net without
changing score or progression; timing out applies the existing 25-point capped
loss and knockback. Flight and maximum growth are immune. Reduce motion removes
the telegraph and escape scale pulses while preserving the gameplay timing and
static net information. The attack is deterministic, uses no gameplay random
numbers, adds no collision or scene nodes, and reuses existing audio.

Animal Control also explicitly deflects tongue shots from a small or medium
frog. A direct shot at the officer, or a shot whose path crosses the officer
before reaching another target, stops at the officer with a short draw-only
shield flash and the normal tongue recovery. The intended target, score,
growth, challenges, and Field Guide remain unchanged. At maximum growth the
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
instead of a net. Remaining in the locked beam applies one 12-point capped
knockback; stepping out of the beam, moving behind a wall, flying, or reaching
maximum growth prevents the strike. Crowd cover loses the sight-based guard in
1.1 seconds. The guard deploys neither Animal Control roadblocks nor snares, so
the one-pursuer cap cannot create stacked damage or obstruction loops. At
maximum growth it can be swallowed into the Belly and discovered in the Field
Guide like Animal Control. Reduce motion freezes beam decoration while
preserving its warning and hit timing.

Watchdog is the third bounded pursuer archetype. Resistant living targets can
call one dog instead of Animal Control. Its 860-unit scent detection ignores
walls while the frog remains on the ground, and its 22-unit navigation radius,
320-unit speed, and shorter repath cadence let it use narrower generated-city
routes than either person. It protects only nearby living targets and attacks
with a 0.45-second warning followed by one 220-unit physical lunge using its
existing collision body. Walls stop the lunge, moving out of its locked path
dodges it, and a hit applies one 16-point capped knockback. Flight breaks scent
and ends the chase after 1.4 seconds; crowd cover takes 0.8 seconds; the total
chase is capped at 22 seconds. The dog deploys no Animal Control roadblock or
snare, uses no projectile or gameplay random numbers, and remains edible at
maximum growth with its own Belly and Field Guide record. Reduce motion
suppresses decorative lunge pulses and trails without changing warning,
movement, collision, or hit timing.

The River Park meetup implements the first crowd-based pursuit escape. While
the daytime meetup is active, pursuit changes its marked area to `HIDE HERE`
and a static progress ring fills as an eligible frog stays within the crowd.
Completing the short hold dismisses Animal Control without awarding score,
growth, challenge progress, or Field Guide credit.

The prototype implements the first temporary pursuit obstacle as one Animal
Control roadblock per chase. After three unpaused, movement-enabled pursuit
seconds, the nearest safe authored road anchor 260–850 units from the frog
receives a physical barricade; if no anchor is currently valid, deployment
waits and retries without consuming the chase's roadblock. The barricade blocks
ground movement, pursuer movement, net sweeps, and tongue rays. Three tongue
hits break it, while an untouched barricade expires after ten seconds. Breaking
or expiry never deploys a replacement during the same pursuit, and ending the
pursuit clears it immediately. Placement is deterministic, uses no gameplay
random numbers, and changes no score, growth, target, save, challenge, or Field
Guide state.

Animal Control also deploys one draw-only sidewalk snare per chase after six
unpaused, movement-enabled pursuit seconds. The nearest safe authored anchor
180–700 units from the frog receives a clearly labeled 0.75-second arming
warning. Once armed, contact by an eligible small or medium ground frog applies
the existing capped damage and knockback flow for 15 points and removes the
snare. Flight, maximum growth, knockback, movement-disabled states, net escape,
tongue pulls, target struggles, and active damage recovery prevent triggering.
An untouched snare expires after twelve seconds, never redeploys in the same
pursuit, and clears immediately when pursuit ends. Reduce motion freezes its
pulse while retaining the static armed-state change and all gameplay timing.
Placement and timing use no gameplay random numbers, and the snare adds no
collision, target, save, challenge, or Field Guide state.

If a pursuer catches the frog:

- the frog is knocked backward; and
- points are lost, but the score never drops below zero.

The frog can escape by outrunning pursuers, hiding inside buildings, losing
them in crowds, or using temporary powers. Once sufficiently large, the frog
can also eat its pursuers.

## Additional goals

Discovering every target type is now a confirmed secondary goal. The first
prototype implements this through a persistent per-player Frog Field Guide.
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

The following possible goals remain under consideration:

- find secret districts;
- earn achievements;
- reach enormous frog sizes;
- collect temporary powers;
- find hidden story clues; and
- trigger specific city events.

The response also selected "score and exploration are enough," so the inclusion
and priority of the remaining additional goals still require confirmation.

## Decisions still needed

These points were not fully resolved in the interview:

- Whether starting a new game from the main menu resets score, size, belly
  contents, world destruction, location, and discoveries, or resumes a saved
  city.
- Whether ordinary citizens treat most eating as normal while only certain
  protected targets call security, or whether stealing any owned target can
  trigger a response.
- Whether the remaining additional goals listed above are wanted, or whether
  the game should focus on score, free exploration, the Field Guide, and short
  session challenges.
- The exact boundary between a target that is insufficiently secured and one
  that is permanently attached to the city.
- The point values, growth thresholds, tongue range, tongue recovery duration,
  struggle difficulty, and caught-score penalty.
- The final visual art style, expanded audio direction beyond the approved
  soft arcade-like synth slice, story, and remaining menu or onboarding
  polish.
- Whether the camera needs additional automatic assistance while the player is
  using one finger to move and a second finger to rotate it.
- Which temporary powers should exist in addition to one-minute flight.
