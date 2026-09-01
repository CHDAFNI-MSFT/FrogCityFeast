# Frog City Feast asset provenance

This ledger is the source of truth for authored visual and audio assets in
**Frog City Feast**. Every production asset must identify its source,
authorship, license, and reproduction method before it is used by the game.

Godot-generated `.import` files are derived metadata for the adjacent source
asset. They are not separate creative assets and inherit the source asset's
provenance.

## Current visual assets

| Asset | Source and authorship | License | Reproduction |
|---|---|---|---|
| `icon.svg` | Original SVG authored for this repository by the repository owner in August 2026. It does not contain third-party artwork or trademarks. | Project-specific copyright belongs to the repository owner. The repository has no general open-source license; reuse outside the project requires permission. | The committed SVG is the editable source. Import it with Godot 4.7.2 to regenerate `icon.svg.import` and platform icon derivatives. |
| `art/characters/*.svg` | Original Copilot-assisted character art authored for this repository in September 2026. | Project-specific copyright belongs to the repository owner; external reuse requires permission. | The committed SVGs are editable runtime sources. See `art/README.md`. |
| `art/targets/*.svg` | Original Copilot-assisted tintable target-category art authored for this repository in September 2026. | Project-specific copyright belongs to the repository owner; external reuse requires permission. | The committed SVGs are editable runtime sources. See `art/README.md`. |
| `src/tutorial_card_art.gd` and `src/score_epilogue.gd` | Original Copilot-assisted procedural onboarding and ending illustrations authored for this repository in September 2026. | Project-specific copyright belongs to the repository owner; external reuse requires permission. | Godot 4.7.2 redraws the committed GDScript compositions from project-local colors and SVG textures. See `art/README.md`. |

## Current audio assets

The following original WAV files are generated from
`scripts/generate-audio.ps1`:

- `ui_feedback.wav`
- `tongue_launch.wav`
- `tongue_hit.wav`
- `tongue_miss.wav`
- `struggle_tap.wav`
- `swallow.wav`
- `digest.wav`
- `spit.wav`
- `growth.wav`
- `growth_major.wav`
- `damage.wav`
- `discovery.wav`
- `clue_found.wav`
- `achievement.wav`
- `challenge_complete.wav`
- `power_activate.wav`
- `shield_pop.wav`
- `pursuit_alert.wav`
- `pursuit_escape.wav`
- `net_warning.wav`
- `flashlight_warning.wav`
- `watchdog_lunge.wav`
- `trap_deploy.wav`
- `trap_trigger.wav`
- `roadblock_deploy.wav`
- `roadblock_hit.wav`
- `roadblock_break.wav`
- `room_travel.wav`
- `destruction.wav`
- `epilogue_open.wav`
- `epilogue_return.wav`
- `city_day.wav`
- `city_night.wav`
- `menu_music.wav`
- `gameplay_day.wav`
- `gameplay_night.wav`
- `pursuit_music.wav`
- `epilogue_music.wav`

Their waveform source, authorship, license, generation date, technical format,
and deterministic reproduction command are recorded in
[`audio/README.md`](audio/README.md). No external samples, commercial music,
named melodies, or third-party sound libraries are used.

## Production asset rules

- Store editable original SVG sources under `assets/art/` and any reproducible
  generators under `scripts/`.
- Prefer layered SVG parts for character and environment animation so the
  source remains reviewable and efficient on the target iPad.
- Give each production asset family its own README or manifest entry listing
  every source file and any generated runtime derivatives.
- Do not add downloaded stock art, copyrighted characters, commercial asset
  packs, third-party fonts, sample libraries, or music.
- Record any tool-only transformation, including ImageMagick or FFmpeg
  commands, so a clean checkout can reproduce the runtime asset.
- Keep temporary editor files and generated exports out of Git. Use Git LFS
  only after the repository owner approves a demonstrated storage need.
