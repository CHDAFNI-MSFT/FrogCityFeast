# Frog City Feast

Godot 4.7.2 touch-first iPad game. The `FrogCityFeast` repository name matches
the published game name.

## Development planning

- [Game design requirements](docs/game-design.md)
- [Implemented game status and controls](docs/playable-prototype.md)
- [Game stack decision guide](docs/game-stack-decision-guide.md)
- [Development toolchain setup](docs/development-setup.md)
- [Clean-room environment rebuild runbook](docs/environment-rebuild-runbook.md)
- [iOS build and App Store setup](docs/ios-release.md)
- [Reusable Apple app publishing runbook](docs/apple-app-publishing-runbook.md)
- [App Store metadata template](docs/app-store-metadata.md)
- [Privacy policy](docs/privacy-policy.md)
- [Support page](docs/app-support.md)
- [Public release checklist](docs/app-store-release-checklist.md)
- [Asset provenance and reproduction](assets/README.md)

## Quick start on Windows

Install the pinned Godot toolchain and the optional graphical asset editors:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -IncludeGuiEditors
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1 -RequireGuiEditors
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-project-windows.ps1
```

Godot is pinned in [`tools/toolchain.json`](tools/toolchain.json). Routine game
development stays on Windows; macOS is reserved for approved iOS export,
signing, and App Store candidate work.

## Automation

- `Godot CI` checks project import and startup on Linux for pushes and pull
  requests.
- `iOS unsigned smoke build` manually validates the Godot-to-Xcode pipeline
  without Apple credentials.
- `iOS App Store candidate upload` is a manual, protected, main-only path for
  an explicitly authorized normal App Store candidate. It requires separate
  public-upload and signing-credential environment approvals.
- `iOS TestFlight release` is retained as historical internal-only
  infrastructure but is not usable by the target under-13 Apple Account.

Signed workflows intentionally publish no IPA or Xcode archive artifacts from
this public repository. Candidate upload, App Review submission, public
release, and Git tags each require separate authorization.
