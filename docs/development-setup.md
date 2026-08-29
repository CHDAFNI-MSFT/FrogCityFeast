# Development Toolchain Setup

SamuelIcecream uses a Windows-first Godot workflow. The repository pins the
Godot editor version and records the supporting asset tools in
`tools/toolchain.json`.

## Tool selection

| Tool | Purpose | Requirement |
|---|---|---|
| Godot 4.7.2 | 2D editor, GDScript runtime, debugger, and exporter | Required |
| Git LFS | Optional management of large source assets | Required tool; not enabled for file patterns yet |
| ImageMagick | Scriptable image generation, conversion, and inspection | Required |
| FFmpeg | Scriptable audio/video generation, conversion, and inspection | Required |
| Krita | Manual raster and pixel-art editing | Optional workstation tool |
| Audacity | Manual sound editing and cleanup | Optional workstation tool |

Godot uses the standard GDScript build, not the .NET/Mono build. This avoids an
unnecessary .NET dependency and keeps local and CI setup smaller.

## Windows setup

The Windows bootstrap uses WinGet and installs the versions recorded in the
toolchain manifest.

From the repository root, install the core command-line toolchain:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-project-windows.ps1
```

For a development workstation, also install and verify Krita and Audacity:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -IncludeGuiEditors
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1 -RequireGuiEditors
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-project-windows.ps1
```

Open a new terminal after installation so application aliases and `PATH`
updates are available.

If Krita's WinGet installer cannot obtain elevation, the setup script downloads
the official portable archive pinned in `tools/toolchain.json`, verifies its
SHA-256 checksum, and installs it under the ignored `.tools/` directory. The
verification script accepts either the exact WinGet package or that pinned
portable installation.

## Linux setup

The Unix bootstrap supports apt-based Linux distributions on x86-64 and ARM64.
It installs Godot into the ignored `.tools/` directory and validates the
official release archive with the SHA-512 checksum in the manifest.

```bash
chmod +x scripts/setup-unix.sh scripts/verify-unix.sh
./scripts/setup-unix.sh --include-gui-editors
export PATH="$PWD/.tools/bin:$PATH"
./scripts/verify-unix.sh --require-gui-editors
```

Omit `--include-gui-editors` and `--require-gui-editors` on a headless host.

## macOS setup

The same Unix script supports macOS with Homebrew. Godot is installed from the
pinned official universal archive rather than an unpinned Homebrew cask.

```bash
chmod +x scripts/setup-unix.sh scripts/verify-unix.sh
./scripts/setup-unix.sh
export PATH="$PWD/.tools/bin:$PATH"
./scripts/verify-unix.sh
```

Krita and Audacity are unnecessary on a macOS CI runner. Pass
`--include-gui-editors` only when configuring an interactive Mac workstation.

Install the pinned export templates when the Mac must export a project:

```bash
./scripts/setup-unix.sh --install-export-templates
export PATH="$PWD/.tools/bin:$PATH"
```

GitHub-hosted runners already contain the system tools needed by the iOS
workflows. Those workflows use the narrower setup mode:

```bash
./scripts/setup-unix.sh --skip-system-tools --install-export-templates
```

Do not use `--skip-system-tools` on an unprepared workstation.

## Copilot CLI on another host

Copilot CLI automatically reads `.github/copilot-instructions.md`. A new
session should:

1. Read the
   [clean-room environment rebuild runbook](environment-rebuild-runbook.md).
2. Read `tools/toolchain.json`.
3. Run the setup script for its operating system.
4. Run the matching verification script.
5. Keep normal game work on Windows or Linux.
6. Use macOS only for Apple-specific build and release steps.

This allows a new session to reproduce the tool set without relying on previous
conversation history.

## Local-first validation policy

The planned validation split is:

| Trigger | Environment | Work |
|---|---|---|
| During development | Local Windows | Editor, gameplay, assets, GDScript checks |
| Pull request | Linux runner | Headless import, script checks, and automated tests |
| Manual smoke or release | macOS runner | iOS export, Xcode compilation, archive, signing, and TestFlight |

Do not configure macOS jobs to run for every push or pull request. The iOS job
is manual for credential-free smoke builds and manual or tag-driven for
protected TestFlight releases.

## iOS release prerequisites

The macOS release workflow requires:

- Godot export templates matching version 4.7.2.
- A Godot iOS export preset.
- An Apple Developer Program membership.
- An App Store Connect application and API key.
- An Apple distribution certificate and provisioning configuration.
- GitHub Actions secrets for private signing material.

The export-template filename and checksum are already recorded in
`tools/toolchain.json`, but templates are not installed on ordinary Windows or
Linux development hosts. The GitHub Actions release configuration and its
required Apple account setup are documented in
[`ios-release.md`](ios-release.md).

## Toolchain upgrades

Upgrade deliberately rather than following `latest` automatically:

1. Confirm that the new Godot stable release supports the project and iOS
   export requirements.
2. Update the version, release tag, download filenames, and checksums in
   `tools/toolchain.json`.
3. Update WinGet package versions for the supporting tools.
4. Update `appleBuild` when the stable macOS runner, Xcode, or iOS SDK changes.
5. Update the literal runner, Xcode path, and cache keys in the workflows.
6. Run both setup and verification on a clean host.
7. Update this document and the GitHub Actions workflows in the same change.

Pinning the engine prevents one host or CI job from silently rewriting project
files with a different Godot format.
