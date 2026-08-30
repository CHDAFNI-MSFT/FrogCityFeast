# Game Design Requirements

This document records the durable gameplay decisions from the design interview.
It describes the intended player experience rather than implementation details.
The game's final title has not been chosen.

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

## Player character and touch controls

The player controls a frog.

- Tap a location on the ground to make the frog run there.
- Double-tap a target to shoot the frog's tongue at it.
- Use a second finger to rotate the camera.
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

The city contains a large variety of shops, apartments, restaurants, and other
enterable locations. A rare discovery is a large open plot containing many
things to eat.

### District types

- Downtown skyscrapers
- Apartment neighborhoods
- Restaurant district
- Shopping district
- Outdoor market
- Suburbs and backyards
- Industrial area
- Parks and gardens
- Waterfront and canals
- Construction sites
- Entertainment district
- Secret fantasy district

### Buildings and interiors

- Every building can be entered.
- Entering an interior uses a short transition or fade.
- Ordinary interiors are compact, with a few important rooms rather than a
  complete simulation of every room and floor.
- Potential exploration spaces include upper floors, rooftops, fire escapes,
  balconies, sewers, subway tunnels, parks, ponds, construction cranes, and
  secret underground areas.
- The navigation system marks buildings the player has discovered.
- The current prototype has staged destruction for Moonlight Market and the
  Oddities Shop. Each requires three removable parts and maximum growth before
  the whole weakened building can be swallowed.
- Leap Café and Canal Apartments use wall-hugging solid furniture with wide
  central aisles, keeping the single-world prototype navigable without
  pathfinding. Their interior targets require the frog to enter, remain
  associated with their rooms when restocked, and reward exploring the space.

### Dynamic city events

The city can change through:

- a day and night cycle;
- rain and storms;
- changing crowd sizes;
- changing traffic levels;
- shops opening and closing;
- special festivals;
- random emergencies; and
- fantasy events.

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
- use nets;
- interrupt or deflect the tongue;
- protect valuable targets; and
- set traps.

Some obstacles temporarily block the tongue, cause it to bounce away, and can
be broken after repeated hits.

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
- The game's name, visual art style, sound style, story, menus, profile setup,
  accessibility options, and first-time tutorial.
- Whether the camera needs additional automatic assistance while the player is
  using one finger to move and a second finger to rotate it.
- Which temporary powers should exist in addition to one-minute flight.
