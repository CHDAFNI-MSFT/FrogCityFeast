# Automated App Store screenshot package

The normal public App Store listing uses one deterministic seven-image
13-inch iPad landscape package. The authored source is
[`tools/app_store_screenshot_states.gd`](../tools/app_store_screenshot_states.gd),
the capture harness is
[`tools/app_store_screenshot_harness.gd`](../tools/app_store_screenshot_harness.gd),
and the machine-readable sequence is
[`tools/app-store-screenshot-manifest.json`](../tools/app-store-screenshot-manifest.json).

## Reproduce on Windows

From the repository root, with the pinned tools installed:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\generate-app-store-screenshots.ps1
```

The script uses the Godot 4.7.2 console executable and GL Compatibility
renderer from `tools/toolchain.json`. It opens a rendered Godot window, authors
each state with the fixed session seed `20260901` and safe local profile name
`Sam`, captures the game framebuffer, converts it to RGB, and writes:

```text
build/app-store/screenshots/
├── .gdignore
├── ipad-13-inch/
│   ├── 01-city-overview.png
│   ├── 02-tongue-catch.png
│   ├── 03-enormous-pursuit.png
│   ├── 04-weather-festival.png
│   ├── 05-belly.png
│   ├── 06-guide-journal.png
│   └── 07-accessibility-options.png
└── release-package.json
```

Each PNG is exactly 2752 x 2064, opaque RGB, and contains only the rendered
game. ImageMagick verifies dimensions, channel/opacity state, and a minimum
color count; `release-package.json` records the exact clean Git source commit
and SHA-256 of each validated output. The generated `.gdignore` prevents Godot
from importing release derivatives or adding `.import` sidecars. Generation
fails for a dirty tracked worktree or a lower-resolution capture rather than
creating an ambiguous release package.

## Authored sequence

1. Storybook city overview with landmarks, targets, city activity, frog, and
   release HUD.
2. Accurate tongue catch with percentage, text, progress, target chevrons,
   and a ring so feedback does not depend on color alone.
3. Enormous frog reversing an Animal Control pursuit with its trap and
   barricade.
4. River Park during the bright Canal Kite Festival, demonstrating changing
   city activity.
5. Belly inventory with separate digest and safe-return actions.
6. Guide & Journal story-postcard page with complete, stamped progress.
7. Accessibility Options with Reduce Motion, larger text and controls,
   Relaxed timing, camera auto-alignment and sensitivity, haptics, and the
   left-handed HUD.

## Release and provenance policy

- The harness is not referenced by the production main scene. Authored state
  manipulation also rejects calls without its dedicated command-line invocation
  flag, so it runs only when the dedicated script is invoked and adds no cheat
  or debug UI to normal builds.
- The images are deterministic release derivatives, not editable source
  assets. They remain under the ignored `build/` directory and are not
  committed. The GDScript states, manifest, and this reproduction record are
  committed instead.
- The screenshots are original renderings of repository-owned game code and
  art. They inherit the source asset provenance in `assets/README.md`.
- No Git LFS storage is needed for ignored, reproducible release output.
- The protected App Store submission-preparation workflow checks out the exact
  uploaded candidate source, regenerates this package on a Windows runner,
  verifies every SHA-256 value, uploads directly to Apple, and removes all
  generated images without creating a GitHub artifact.
- Do not run with `--perf-overlay`, substitute private profile data, or add
  signing/build information. Re-run from the exact publication build, perform
  the deferred visual review once, and upload only after separate owner
  authorization.
