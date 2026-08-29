# SamuelIcecream

Native iOS game.

## Development planning

- [Game stack decision guide](docs/game-stack-decision-guide.md)
- [Development toolchain setup](docs/development-setup.md)
- [iOS build and TestFlight setup](docs/ios-release.md)

## Quick start on Windows

Install the pinned Godot toolchain and the optional graphical asset editors:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -IncludeGuiEditors
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1 -RequireGuiEditors
```

Godot is pinned in [`tools/toolchain.json`](tools/toolchain.json). Routine game
development stays on Windows; macOS is reserved for iOS export, signing, and
TestFlight release work.

## Automation

- `Godot CI` checks project import and startup on Linux for pushes and pull
  requests.
- `iOS unsigned smoke build` manually validates the Godot-to-Xcode pipeline
  without Apple credentials.
- `iOS TestFlight release` signs and submits approved builds from `main` or
  version tags after the `testflight` environment is configured.

The signed release workflow intentionally publishes no IPA or Xcode archive
artifacts from this public repository.
