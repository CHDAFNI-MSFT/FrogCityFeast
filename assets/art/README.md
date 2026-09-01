# Production art assets

These SVG files form the first production art family for **Frog City Feast**.
They use the selected layered storybook cut-paper direction, confectionery city
palette, teal environmental accents, dark ink outlines, and clean silhouettes.

## Provenance

All files in this directory are original project assets created for
`CHDAFNI-MSFT/SamuelIcecream` with GitHub Copilot assistance on September 1,
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
| `targets/food.svg` | Tintable food-category silhouette. |
| `targets/living.svg` | Tintable harmless living-target silhouette. |
| `targets/object.svg` | Tintable loose-object and whole-building token silhouette. |
| `targets/vehicle.svg` | Tintable vehicle-category silhouette. |
| `targets/building_part.svg` | Tintable removable sign, door, awning, and fixture silhouette. |

## Reproduction

The committed SVG files are the editable sources and runtime inputs. Open them
with any standards-compliant SVG editor or Krita 5.3.3. Godot 4.7.2 imports the
SVGs directly and regenerates the adjacent `.import` metadata during the normal
project import.

The assets intentionally contain no linked images, external stylesheets,
scripts, embedded fonts, or remote references. Runtime tinting and cutout
animation are implemented in `src/production_art.gd`, `src/frog.gd`, and
`src/edible.gd`.
