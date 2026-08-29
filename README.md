# SamuelIcecream

Native iOS game.

## Development planning

- [Game stack decision guide](docs/game-stack-decision-guide.md)
- [Development toolchain setup](docs/development-setup.md)

## Quick start on Windows

Install the pinned Godot toolchain and the optional graphical asset editors:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -IncludeGuiEditors
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1 -RequireGuiEditors
```

Godot is pinned in [`tools/toolchain.json`](tools/toolchain.json). Routine game
development stays on Windows; macOS is reserved for iOS export, signing, and
TestFlight release work.
