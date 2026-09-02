# FrogCityFeast repository instructions

## Technology

- Use Godot 4.7.2 with GDScript for the 2D game.
- Do not add the .NET/Mono edition, C#, Unity, Flutter, or native Swift game
  code unless the documented stack decision changes.
- Treat `tools/toolchain.json` as the source of truth for the Godot version and
  the supported development tools.

## Environment setup

- When recreating this environment for a separate game repository, follow
  `docs/environment-rebuild-runbook.md` as the authoritative clean-room
  procedure.
- On Windows, run `scripts/setup-windows.ps1` when required tools are missing.
- On Windows, use `scripts/check-project-windows.ps1` for blocking headless
  import and startup checks; do not rely on the GUI Godot executable preserving
  `$LASTEXITCODE`.
- On Linux or macOS, run `scripts/setup-unix.sh`.
- Run the matching verification script after setup.
- Keep generated downloads and installations under `.tools/` when the setup
  script uses repository-local tooling. Never commit `.tools/`.
- Do not configure Godot, Krita, Audacity, ImageMagick, FFmpeg, or Git LFS to
  run automatically at sign-in or computer startup.

## Development workflow

- Perform editing, asset processing, gameplay testing, and routine validation
  locally on Windows whenever possible.
- Prefer GDScript and text-based Godot resources that are reviewable in Git.
- Do not commit the generated `.godot/` directory or build/export output.
- Use Git LFS only after confirming that the repository needs it. Public Git
  LFS storage and bandwidth can incur charges.

## CI and iOS

- Use Linux GitHub-hosted runners for headless checks that cannot run locally.
- Do not run macOS jobs for ordinary pushes or pull requests.
- Trigger macOS jobs manually, for approved releases, or for release tags.
- Restrict macOS work to Godot iOS export, Xcode archive/testing, Apple code
  signing, and TestFlight upload.
- Never commit Apple `.p8` keys, `.p12` files, signing passwords, provisioning
  profiles, deployment tokens, or authenticated URLs.
- Do not expose repository secrets to workflows triggered by untrusted pull
  requests.

## Documentation

- Record durable game requirements and design decisions in the repository so
  later Copilot sessions do not depend on conversation history.
- Update `docs/development-setup.md` and `tools/toolchain.json` together when
  changing the supported toolchain.
