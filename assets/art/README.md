# Production art assets

These SVG files form the first production art family for **Frog City Feast**.
They use the selected layered storybook cut-paper direction, confectionery city
palette, teal environmental accents, dark ink outlines, and clean silhouettes.

## Provenance

All files in this directory are original project assets created for
`CHDAFNI-MSFT/FrogCityFeast` with GitHub Copilot assistance on September 1,
2026. They do not copy or derive from copyrighted characters, commercial
assets, stock illustrations, third-party fonts, or downloaded artwork.

Copyright in the project-specific SVG files belongs to the repository owner.
The repository has no general open-source license, so reuse outside this
project requires the owner's permission.

## Asset inventory

| Asset | Purpose |
|---|---|
| `characters/frog.svg` | Layered player body, face, limbs, paper shadow, and spots. |
| `characters/frog_wing.svg` | Reusable mirrored flight wing. |
| `characters/animal_control.svg` | Animal Control cutout with uniform, badge, and net case. |
| `characters/security_guard.svg` | Security Guard cutout with cap, badge, and flashlight. |
| `characters/watchdog.svg` | Watchdog cutout with collar and readable canine silhouette. |
| `targets/food.svg` | Tintable food-category silhouette. |
| `targets/living.svg` | Tintable harmless living-target silhouette. |
| `targets/object.svg` | Tintable loose-object and whole-building token silhouette. |
| `targets/vehicle.svg` | Tintable vehicle-category silhouette. |
| `targets/building_part.svg` | Tintable removable sign, door, awning, and fixture silhouette. |
| `src/tutorial_card_art.gd` | Draw-only onboarding-card compositions using the project palette and authored frog SVG. |
| `src/score_epilogue.gd` | Draw-only city, canal, frog, and postcard composition for the score epilogue. |

## Reproduction

The committed SVG files are the editable sources and runtime inputs. Open them
with any standards-compliant SVG editor or Krita 5.3.3. Godot 4.7.2 imports the
SVGs directly and regenerates the adjacent `.import` metadata during the normal
project import.

The assets intentionally contain no linked images, external stylesheets,
scripts, embedded fonts, or remote references. Runtime tinting and cutout
animation are implemented in `src/production_art.gd`, `src/frog.gd`, and
`src/edible.gd`. The onboarding and epilogue illustrations are deterministic
Godot drawing code in `src/tutorial_card_art.gd` and
`src/score_epilogue.gd`; running the corresponding scenes in Godot 4.7.2
reproduces them without downloaded images, fonts, or linked resources.
