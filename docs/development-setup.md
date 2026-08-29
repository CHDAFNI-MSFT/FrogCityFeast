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
```

For a development workstation, also install and verify Krita and Audacity:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-windows.ps1 -IncludeGuiEditors
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify-windows.ps1 -RequireGuiEditors
```

Open a new terminal after installation so application aliases and `PATH`
updates are available.

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

## Copilot CLI on another host

Copilot CLI automatically reads `.github/copilot-instructions.md`. A new
session should:

1. Read `tools/toolchain.json`.
2. Run the setup script for its operating system.
3. Run the matching verification script.
4. Keep normal game work on Windows or Linux.
5. Use macOS only for Apple-specific build and release steps.

This allows a new session to reproduce the tool set without relying on previous
conversation history.

## Local-first validation policy

The planned validation split is:

| Trigger | Environment | Work |
|---|---|---|
| During development | Local Windows | Editor, gameplay, assets, GDScript checks |
| Pull request | Linux runner | Headless import, script checks, and automated tests |
| Manual release or release tag | macOS runner | iOS export, Xcode archive, signing, and TestFlight |

Do not configure macOS jobs to run for every push or pull request. The iOS job
will be added after the Godot project and Apple bundle identifiers exist.

## iOS release prerequisites

The later macOS release workflow will require:

- Godot export templates matching version 4.7.2.
- A Godot iOS export preset.
- An Apple Developer Program membership.
- An App Store Connect application and API key.
- An Apple distribution certificate and provisioning configuration.
- GitHub Actions secrets for private signing material.

The export-template filename and checksum are already recorded in
`tools/toolchain.json`, but templates are not installed on ordinary Windows or
Linux development hosts.

## Toolchain upgrades

Upgrade deliberately rather than following `latest` automatically:

1. Confirm that the new Godot stable release supports the project and iOS
   export requirements.
2. Update the version, release tag, download filenames, and checksums in
   `tools/toolchain.json`.
3. Update WinGet package versions for the supporting tools.
4. Run both setup and verification on a clean host.
5. Update this document and the GitHub Actions workflows in the same change.

Pinning the engine prevents one host or CI job from silently rewriting project
files with a different Godot format.
