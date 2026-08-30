# Environment Rebuild Runbook for a New Game Repository

This document is the clean-room, agent-oriented procedure for reproducing the
SamuelIcecream development and iOS build environment in a separate repository.
It is intentionally explicit so a developer or AI agent can perform the work
without access to the conversation that originally created this repository.

Use a separate repository for an independently released game. Do not maintain a
second game on a permanent branch of SamuelIcecream. A branch is appropriate
for temporary work that will merge back into the same product; it is not an
isolation boundary for another product, release history, or App Store record.

## 1. Desired outcome

After completing this runbook, the new repository should have:

1. A Windows-first Godot 2D development environment.
2. Pinned, reproducible versions of Godot and supporting asset tools.
3. Krita and Audacity available for manual 2D art and audio work when requested.
4. No game-development application configured to run automatically at sign-in
   or computer startup.
5. Linux GitHub Actions validation for ordinary pushes and pull requests.
6. A credential-free macOS workflow that exports the Godot project and compiles
   an unsigned generic iOS device target with Xcode.
7. A separate, protected GitHub environment for an eventual signed TestFlight
   release.
8. No Apple signing material, generated build output, tool downloads, or local
   editor state committed to Git.
9. No Azure dependency. Azure, Azure Key Vault, and Azure OIDC are not part of
   this design.

The unsigned iOS smoke build is the boundary of what can be reproduced without
an Apple Developer account. A signed TestFlight upload additionally requires
app-specific Apple records and private credentials.

## 2. Execution contract for an AI agent

An agent following this runbook must use these rules:

1. Read this document, `tools/toolchain.json`,
   `.github/copilot-instructions.md`, and `docs/ios-release.md` before changing
   the new repository.
2. Treat `tools/toolchain.json` as the source of truth for tool versions,
   official download assets, checksums, runner image, Xcode version, and iOS SDK.
3. Use the scripts copied into the new repository rather than reconstructing
   install commands from memory.
4. Never substitute an unpinned `latest` version because a pinned package is
   temporarily inconvenient.
5. Never commit, print, upload as an artifact, or place in command-line history
   any Apple private key, certificate password, provisioning profile, or
   decoded signing file.
6. Do not install startup agents, login items, scheduled tasks, background
   services, or automatic application launchers for Godot, Krita, Audacity,
   ImageMagick, FFmpeg, or Git LFS.
7. Do not disable unrelated startup entries. If an installer unexpectedly adds
   one, remove only the exact entry attributable to the installed tool.
8. Do not run the signed TestFlight workflow until the new app has its own
   explicit bundle identifier, provisioning profile, App Store Connect record,
   and protected GitHub environment.
9. Use Windows or Linux for routine development and CI. Use macOS only where
   Apple tooling is technically required.
10. Stop and report a precise blocker instead of inventing Apple identifiers,
    credentials, package versions, checksums, or signing values.
11. Preserve unrelated user changes in a non-clean worktree.
12. Record the commands run, versions observed, CI URLs, and any deliberate
    deviation from this procedure in the final handoff.

## 3. Information required before starting

Collect these values. Values marked "later" are not required for the initial
Windows or unsigned iOS setup.

| Input | Example | When required |
|---|---|---|
| GitHub owner | `CHDAFNI-MSFT` | Before creating or cloning the repository |
| Repository name | `AnotherGame` | Before creating or cloning the repository |
| Local workspace | `C:\Users\<user>\OneDrive\GitHub` | Before cloning |
| Godot display name | `Another Game` | Before editing `project.godot` |
| File-safe product name | `AnotherGame` | Before adapting iOS scripts |
| Lowercase temporary slug | `anothergame` | Before adapting temporary paths |
| Unsigned smoke bundle ID | `com.example.anothergame` | Before running iOS smoke |
| Production bundle ID | `com.owner.anothergame` | Later, before Apple setup |
| Apple Team ID | Ten alphanumeric characters | Later, before signed release |
| Initial marketing version | `0.1.0` | Before signed release |
| GUI editors wanted | Normally yes on a development workstation | Before local setup |

The production bundle identifier is permanent App Store identity, not merely a
filename. Confirm it with the repository owner before creating Apple records.
Do not copy `com.example.samuelicecream` or the SamuelIcecream provisioning
profile into another app.

## 4. Reference architecture

The environment deliberately separates work by operating system:

| Environment | Responsibilities | Must not be used for |
|---|---|---|
| Local Windows workstation | Godot editor, GDScript, gameplay testing, 2D assets, audio editing, routine import checks | Xcode archive, Apple signing, TestFlight upload |
| GitHub Linux runner | Headless Godot import, startup, script checks, future automated tests | Apple signing or iOS compilation |
| GitHub macOS runner | Godot iOS export, Xcode compilation, signed archive, TestFlight upload | Routine push/PR checks |
| Apple Developer and App Store Connect | Bundle ID, app record, certificate, profile, API key, release processing | Source control or ordinary development |

No persistent Mac is required for the current design. Each macOS job starts on
a fresh GitHub-hosted runner, installs the pinned Godot editor and matching
export templates, selects the pinned Xcode installation, performs its task, and
is discarded.

## 5. Authoritative files in SamuelIcecream

Use `CHDAFNI-MSFT/SamuelIcecream` as a known-good reference implementation.
These files have different responsibilities:

| File or directory | Responsibility | Reuse in a new repository |
|---|---|---|
| `tools/toolchain.json` | Tool and Apple runner version pins plus Godot archive checksums | Copy, then update only through a deliberate toolchain upgrade |
| `scripts/setup-windows.ps1` | Idempotent WinGet-based Windows installation | Copy |
| `scripts/verify-windows.ps1` | Windows command and package verification | Copy |
| `scripts/check-project-windows.ps1` | Blocking Windows Godot import and startup checks using the console executable | Copy |
| `scripts/setup-unix.sh` | Linux/macOS dependencies, verified Godot download, export-template installation | Copy |
| `scripts/verify-unix.sh` | Linux/macOS version verification | Copy |
| `scripts/check-project.sh` | Headless Godot import and startup checks | Copy |
| `tools/export-presets.ios.cfg.template` | Generated, non-secret iOS export configuration | Copy and rename product paths |
| `scripts/render-export-presets.py` | Strict replacement and validation of export values | Copy |
| `scripts/ios-preflight.sh` | Godot, template, Xcode, SDK, and identifier validation | Copy |
| `scripts/export-ios.sh` | Godot export-only operation and Xcode project discovery | Copy and rename product paths |
| `scripts/build-ios-unsigned.sh` | Generic arm64 iOS device compilation with signing disabled | Copy |
| `scripts/prepare-ios-signing.sh` | Temporary keychain and provisioning-profile setup | Copy and rename temporary files |
| `scripts/create-export-options.py` | Xcode export options for manual signing | Copy |
| `scripts/archive-and-upload-ios.sh` | Signed Xcode archive and direct App Store Connect upload | Copy and rename archive path |
| `scripts/cleanup-ios-signing.sh` | Always-run cleanup of decoded signing material | Copy and rename temporary files |
| `.github/workflows/godot-ci.yml` | Routine Linux CI | Copy |
| `.github/workflows/ios-smoke.yml` | Manual credential-free iOS integration test | Copy and change smoke bundle ID |
| `.github/workflows/ios-testflight.yml` | Protected signed release | Copy |
| `.gitignore` | Excludes editor state, tools, builds, generated presets, and signing files | Copy or merge carefully |
| `.github/copilot-instructions.md` | Durable repository rules for future agents | Copy and replace the product name |
| `README.md` | Human entry point for setup and automation | Copy and rebrand, or reproduce all runbook links |
| `docs/environment-rebuild-runbook.md` | This clean-room procedure | Copy and preserve as the agent authority |
| `docs/development-setup.md` | Day-to-day workstation setup | Copy and rebrand |
| `docs/game-stack-decision-guide.md` | Reusable engine-selection rationale | Copy if the same product constraints apply |
| `docs/ios-release.md` | Apple and GitHub release configuration | Copy and replace examples |

Do not copy game-specific scenes, scripts, artwork, audio, branding, or narrative
content merely to obtain the toolchain. The placeholder `project.godot`,
`scenes/main.tscn`, `src/main.gd`, and `assets/icon.svg` can be used as a
temporary bootstrap only if they are intentionally rebranded or replaced.

## 6. Create and clone the new repository

The new game should be a sibling of SamuelIcecream, not a nested Git repository.
For example:

```text
C:\Users\<user>\OneDrive\GitHub\
|-- SamuelIcecream\
`-- AnotherGame\
```

If the public repository already exists:

```powershell
Set-Location "C:\Users\<user>\OneDrive\GitHub"
gh repo clone CHDAFNI-MSFT/AnotherGame
Set-Location .\AnotherGame
git remote -v
git status --short --branch
```

If it does not exist, create it through the GitHub UI or an approved `gh repo
create` command before cloning. Confirm the intended visibility. Do not assume a
new game is public merely because SamuelIcecream is public.

Before copying files, inspect both repositories for uncommitted work. Never
overwrite a file in the new repository without reading and reconciling its
contents.

## 7. Transfer the reusable baseline

Copy the reusable files listed in section 5 from SamuelIcecream into the new
repository. Preserve executable permissions on `scripts/setup-unix.sh` and
`scripts/verify-unix.sh`. They are the two shell files invoked directly with
`./`; workflow-only shell scripts are intentionally invoked with `bash` and do
not require an executable bit.

Filesystem copies on Windows may lose Git's executable metadata. After staging
the copied scripts, restore the two required modes explicitly:

```powershell
git update-index --chmod=+x `
  scripts/setup-unix.sh `
  scripts/verify-unix.sh
```

Verify the resulting index:

```powershell
git ls-files --stage scripts
```

`setup-unix.sh` and `verify-unix.sh` should show mode `100755`. The other shell
scripts may show `100644` because workflows call them through `bash`.
Documentation, JSON, PowerShell, Python, Godot, and workflow files normally
show `100644`.

After copying, run this mandatory search from the new repository root. The
`--untracked` option is required because newly copied files may not be staged
yet:

```powershell
git grep --untracked -In -i -E "samuel ?icecream"
```

`git grep` is used because it is included with Git and is not an additional
workstation dependency. The expression catches `SamuelIcecream`,
`samuelicecream`, and the spaced display form `Samuel Icecream`. Review every
result. At minimum, adapt the following:

| Location | Required adaptation |
|---|---|
| `project.godot` | Change `config/name`; retain the Godot compatibility settings |
| `.github/copilot-instructions.md` | Change the heading and game name |
| `.github/workflows/ios-smoke.yml` | Change the synthetic smoke bundle ID suffix |
| `tools/export-presets.ios.cfg.template` | Change `export_path` product component |
| `scripts/export-ios.sh` | Change `export_target` and `xcode_project` names |
| `scripts/archive-and-upload-ios.sh` | Change the `.xcarchive` name |
| `scripts/prepare-ios-signing.sh` | Change product-specific temporary filenames |
| `scripts/cleanup-ios-signing.sh` | Make the same temporary-filename changes |
| `docs/*.md` and `README.md` | Change product-specific prose and examples |

Do not blindly replace case-sensitive text without reviewing the resulting
paths. Maintain three deliberate forms:

```text
Display name:          Another Game
File-safe product:     AnotherGame
Lowercase temp prefix: anothergame
```

The filenames used by `prepare-ios-signing.sh` and
`cleanup-ios-signing.sh` must remain identical. A mismatch could leave decoded
signing material on the ephemeral runner until the runner is destroyed.

Keep the export preset name exactly `iOS` unless both the preset template and
the `--export-release "iOS"` argument in `scripts/export-ios.sh` are changed
together. Keep the file-safe product name identical in:

- `tools/export-presets.ios.cfg.template` export path.
- `scripts/export-ios.sh` export target and Xcode project path.
- `scripts/archive-and-upload-ios.sh` archive path.

After replacement, rerun the search. Product-specific SamuelIcecream references
should be absent. A reference to this runbook or the reference repository may
remain when it is clearly explanatory rather than executable configuration.

## 8. Minimum Godot project requirements

The new repository must contain a valid `project.godot` and main scene before CI
can pass. Keep these settings unless the renderer decision is deliberately
changed and revalidated on iOS:

```ini
config_version=5

[application]

config/name="Another Game"
config/version="0.1.0"
config/icon="res://assets/icon.svg"
run/main_scene="res://scenes/main.tscn"
config/features=PackedStringArray("4.7", "GL Compatibility")

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/vram_compression/import_etc2_astc=true
```

Important constraints:

- `run/main_scene` must point to a committed, loadable Godot scene.
- `config/icon` must point to a committed image. The iOS exporter requires a
  source icon and generates its required icon sizes from it.
- Use a square, high-resolution, fully covered icon source. A 1024 by 1024 SVG
  or PNG is a practical bootstrap format.
- Commit the generated source-side `.import` metadata when Godot creates it,
  but do not commit the `.godot/` directory.
- ETC2/ASTC import support must be enabled for the iOS export configuration.
- Both desktop and mobile currently use the compatibility renderer.
- The project uses standard GDScript Godot, not the .NET/Mono build.
- A `[display]` section is optional during initial bootstrap and can be added
  when the new game's target viewport and stretch behavior are selected.

Run Godot once after creating or replacing the icon so its `.import` metadata
exists and can be reviewed.

## 9. Install the Windows development workstation

### 9.1 Prerequisites

The Windows script expects:

- x64 Windows 10 or Windows 11 with WinGet from Microsoft App Installer.
- Git and GitHub CLI already available for repository access.
- Network access to the configured WinGet source.
- Permission to install the selected packages.

Before installing anything, capture a startup-registration baseline using the
queries in section 9.4. A before/after comparison distinguishes an
installer-created entry from unrelated software that was already present.

The script installs:

- Godot standard edition.
- Git LFS.
- ImageMagick.
- FFmpeg.
- Krita when `-IncludeGuiEditors` is passed.
- Audacity when `-IncludeGuiEditors` is passed.

It does not install .NET, Mono, Unity, Flutter, Xcode, an iOS simulator, or
Azure tooling.

Windows x86 and ARM64 are not part of the currently validated workstation
matrix. In particular, the pinned Krita portable fallback is x64. The setup
script checks the native Windows architecture before installing anything and
fails with an explicit message on an unsupported host. Do not rely on ARM64 x64
emulation without separately validating and recording that configuration.

The script also creates user-local `godot` and `godot-console` command shims
when WinGet does not provide a stable command alias. The console shim points to
the pinned WinGet package's architecture-specific
`Godot_v<version>-stable_*_console.exe`; this ensures PowerShell waits for
headless checks and receives a meaningful exit code. Setup rejects a
pre-existing `godot` command when it resolves to another version. Adding a
command directory to `PATH` is not a startup application.

### 9.2 Install and verify

From the new repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\setup-windows.ps1 `
  -IncludeGuiEditors
```

Open a new terminal after installation so user and machine `PATH` changes are
visible. Then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\verify-windows.ps1 `
  -RequireGuiEditors
```

The verification command must finish with:

```text
Toolchain verification passed.
```

The exact expected versions come from `tools/toolchain.json`; do not duplicate
or override them in an ad hoc install command.

Finally, run the blocking local project check:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\check-project-windows.ps1
```

It must finish with `Godot project checks passed.` This script deliberately
uses the console executable instead of relying on the GUI-subsystem Godot
binary to block PowerShell.

### 9.3 Installer failure policy

If WinGet reports that the requested version is unavailable:

1. Refresh the WinGet source and retry.
2. Confirm the package ID and version still match `tools/toolchain.json`.
3. Do not silently install `latest`.
4. If the pinned version has genuinely disappeared, treat that as a toolchain
   maintenance task: validate a replacement version, update the manifest and
   documentation, and retest CI together.

If a graphical installer requests elevation that cannot be approved:

1. Allow `scripts/setup-windows.ps1` to use the official portable fallback
   recorded for that package in `tools/toolchain.json`.
2. The current known-good fallback is Krita 5.3.3 from KDE's official archive,
   installed under `.tools\krita-5.3.3\`.
3. The setup script verifies the archive's pinned SHA-256 checksum before
   extraction and adds only the executable directory to the user `PATH`.
4. `scripts/verify-windows.ps1 -RequireGuiEditors` accepts either the exact
   WinGet registration or the configured, version-checked portable path.
5. Do not configure startup, file watchers, update agents, shell background
   services, or login launch.
6. Record the selected install mode in the handoff.

Do not invent portable metadata for another package. Add an official URL,
published checksum, deterministic ignored install directory, relative
executable path, and command version to the manifest before automating another
fallback.

Do not obtain executables from mirrors or third-party download sites.

### 9.4 Confirm that nothing was added to startup

Installation success alone is insufficient. Run the following common Windows
auto-start queries before setup and retain their output as the baseline. Run
the same queries after setup and compare the results:

```powershell
$toolPattern = 'Godot|Krita|Audacity|ImageMagick|FFmpeg|git-lfs'

Get-CimInstance Win32_StartupCommand |
  Where-Object {
    $_.Name -match $toolPattern -or $_.Command -match $toolPattern
  } |
  Select-Object Name, Command, Location, User

Get-ScheduledTask |
  Where-Object {
    $_.TaskName -match $toolPattern -or
    (($_.Actions.Execute + " " + $_.Actions.Arguments) -match $toolPattern)
  } |
  Select-Object TaskName, TaskPath, State

Get-CimInstance Win32_Service |
  Where-Object {
    $_.Name -match $toolPattern -or
    $_.DisplayName -match $toolPattern -or
    $_.PathName -match $toolPattern
  } |
  Select-Object Name, DisplayName, StartMode, State, PathName
```

Expected result: no entries attributable to these development applications.
Empty output both before and after is success. If the baseline is not empty,
the post-install result must contain no new relevant entry. A running
application process is not itself proof of a startup registration; inspect the
registration mechanisms shown above.

If a new entry is found, identify the exact installer-created entry and disable
or remove only that entry. Re-run the audit and document what changed. Never
bulk disable startup items or services. If setup already occurred before a
baseline was captured, do not attribute a pre-existing entry to this setup
without evidence from its executable path or installer record.

## 10. Validate the local Godot project

On Windows, verify the engine can import and start the project with the
repository script:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
  -File .\scripts\check-project-windows.ps1
```

Do not replace this with consecutive calls to the GUI-subsystem `godot.exe`.
PowerShell may not wait for that executable, which can preserve a stale
`$LASTEXITCODE` and allow import and startup to race. The check script resolves
the console executable, waits for each process, records logs under
`build\logs\`, checks the actual exit code, and scans for script errors.

Expected observations:

- Godot reports the pinned stable version.
- Import exits with code zero.
- Startup exits with code zero.
- No `SCRIPT ERROR`, `Parse Error`, or missing-resource error is emitted.
- The main scene reaches its normal initialization output, if it has any.

Inspect repository state afterward:

```powershell
git status --short
```

Commit intended source-side `.import` files. Do not commit `.godot/`, `.tools/`,
`build/`, `exports/`, or `export_presets.cfg`.

## 11. Linux and macOS setup behavior

The Unix script supports apt-based Linux on x86-64 or ARM64 and macOS with
Homebrew:

```bash
chmod +x scripts/setup-unix.sh scripts/verify-unix.sh
./scripts/setup-unix.sh
export PATH="$PWD/.tools/bin:$PATH"
./scripts/verify-unix.sh
```

For a local Unix art/audio workstation:

```bash
./scripts/setup-unix.sh --include-gui-editors
export PATH="$PWD/.tools/bin:$PATH"
./scripts/verify-unix.sh --require-gui-editors
```

For a host that must export with Godot:

```bash
./scripts/setup-unix.sh --install-export-templates
export PATH="$PWD/.tools/bin:$PATH"
```

GitHub-hosted runners already contain the required system packages. Workflows
therefore use:

```bash
./scripts/setup-unix.sh --skip-system-tools --install-export-templates
```

Do not use `--skip-system-tools` on an unprepared personal machine. The option
means "trust the current runner image," not "ignore missing dependencies."

On an interactive Unix workstation, also compare auto-start registrations
before and after installation. The applicable read-only checks are:

```bash
# macOS
grep -RilE 'Godot|Krita|Audacity|ImageMagick|FFmpeg|git-lfs' \
  "$HOME/Library/LaunchAgents" \
  /Library/LaunchAgents \
  /Library/LaunchDaemons 2>/dev/null || true
brew services list 2>/dev/null | \
  grep -Ei 'Godot|Krita|Audacity|ImageMagick|FFmpeg|git-lfs' || true

# Linux
systemctl --user list-unit-files 2>/dev/null | \
  grep -Ei 'Godot|Krita|Audacity|ImageMagick|FFmpeg|git-lfs' || true
grep -RilE 'Godot|Krita|Audacity|ImageMagick|FFmpeg|git-lfs' \
  "$HOME/.config/autostart" \
  /etc/xdg/autostart 2>/dev/null || true
```

No new registration attributable to the installed tools is expected.

## 12. Recreate GitHub Actions

### 12.1 Routine Linux CI

Copy `.github/workflows/godot-ci.yml`. It should:

- Trigger on pushes and pull requests to `main`, plus manual dispatch.
- Use `ubuntu-24.04`.
- Grant only `contents: read`.
- Check out without persisting credentials.
- Cache only the pinned Godot download.
- Install Godot through `scripts/setup-unix.sh --skip-system-tools`.
- Run `scripts/check-project.sh`.

Workflow dispatch is available only after the workflow exists on the default
branch. Commit and push the workflow files to `main`, then use a push run or
manual dispatch and require a green result before treating the new repository
as bootstrapped.

### 12.2 Credential-free iOS smoke build

Copy `.github/workflows/ios-smoke.yml` and change only app-specific values such
as the temporary bundle ID. The smoke workflow must:

- Be manually triggered.
- Use the runner, Xcode path, and SDK pinned in `tools/toolchain.json`.
- Use synthetic Team ID `0000000000` only to satisfy Godot project generation.
- Use a non-production placeholder bundle ID for unsigned compilation.
- Install the exact matching Godot export templates.
- Run `scripts/ios-preflight.sh smoke`.
- Export the Xcode project.
- Compile `generic/platform=iOS` with signing disabled.
- Publish no app, archive, certificate, or profile artifact.

The runner label, Xcode path, Godot archive names, and cache keys are committed
as workflow literals as well as being described by `tools/toolchain.json`.
Whenever these pins change, update the manifest, both iOS workflows, Linux
workflow cache path/key, and documentation in the same commit.

The smoke build exercises the iOS arm64 device compilation path. It does not
sign an app, install on a device, contact an Apple account, or prove that
production signing credentials are valid.

### 12.3 iOS exporter requirements discovered during implementation

Preserve all of these details when adapting the workflow:

1. Godot 4.7.2 produces an Xcode project directory and game support files under
   `build/ios`; it does not produce the ZIP shape implied by some generic Godot
   command-line examples.
2. The export preset must contain
   `application/export_project_only=true`. Otherwise Godot may attempt its own
   archive/signing operation before the dedicated Xcode steps.
3. `project.godot` must contain
   `textures/vram_compression/import_etc2_astc=true`.
4. `application/config/icon` must resolve to a valid committed image.
5. The synthetic Team ID is acceptable only in the unsigned smoke workflow.
6. Xcode signing must be explicitly disabled for the smoke compilation.
7. Compile a generic iOS device target, not only a simulator target.
8. `export_presets.cfg` is generated at runtime from the committed template and
   deleted afterward. Do not commit account-specific export settings.

## 13. Configure the app-specific TestFlight boundary

GitHub environments are repository settings and are not copied by copying
workflow files. Create a fresh `testflight` environment in the new repository.
Restrict deployment to:

- Branch `main`.
- Tags matching `v*`.

Environment protection availability depends on repository visibility and the
GitHub plan. Confirm the new repository supports the required deployment
branch/tag policy before storing release credentials. If it does not, do not
silently weaken the boundary: keep the release workflow disabled until the
repository is public, the plan supports the controls, or the owner explicitly
accepts and documents a different release boundary.

First check whether the environment already exists:

```powershell
$repository = 'CHDAFNI-MSFT/AnotherGame'
gh api "repos/$repository/environments/testflight"
```

The following GitHub CLI sequence creates the environment and policy when it
does not already exist. Replace the owner and repository first:

```powershell
$repository = 'CHDAFNI-MSFT/AnotherGame'
$body = @{
  deployment_branch_policy = @{
    protected_branches = $false
    custom_branch_policies = $true
  }
} | ConvertTo-Json -Compress

$body | gh api --method PUT `
  "repos/$repository/environments/testflight" `
  --input -

gh api --method POST `
  "repos/$repository/environments/testflight/deployment-branch-policies" `
  -f name=main `
  -f type=branch

gh api --method POST `
  "repos/$repository/environments/testflight/deployment-branch-policies" `
  -f 'name=v*' `
  -f type=tag
```

Do not rerun the `PUT` blindly after reviewers or other protection rules have
been configured, because replacing environment configuration without carrying
forward all existing fields can remove those settings. Inspect the current
environment and send the complete desired configuration for later updates.

Confirm the policies through the GitHub UI or REST API. Add a trusted required
reviewer when a second appropriate account is available. Do not enable
self-review prevention if it would make a single-owner repository impossible
to release.

Each new app requires:

- Its own explicit production bundle identifier.
- Its own App Store Connect app record.
- Its own provisioning profile matching that exact bundle identifier.
- GitHub environment variables `APPLE_TEAM_ID` and `IOS_BUNDLE_ID`.
- The six environment secrets documented in `docs/ios-release.md`.

An Apple Distribution certificate can sign more than one app when Apple permits
it, and an App Store Connect API key can cover more than one app depending on
its role and access. Reuse them only when intentionally authorized. The
provisioning profile and bundle identifier remain app-specific.

Never copy GitHub secrets out of SamuelIcecream. GitHub does not reveal stored
secret values, and an agent must not attempt to recover them. Obtain approved
credentials from the repository owner and enter them directly into the new
repository's protected environment.

## 14. Signed-release design that must remain intact

The TestFlight workflow and signing scripts are designed so that:

1. Decoded files exist only under the ephemeral runner's temporary directory.
2. The provisioning profile UUID, Team ID, and exact application identifier are
   checked before certificate import.
3. A temporary keychain uses a random password.
4. Only an Apple Distribution identity is accepted.
5. Manual signing is used consistently during archive and export.
6. Upload uses App Store Connect API-key authentication.
7. No signed IPA or Xcode archive is uploaded to the repository.
8. Cleanup runs with `if: always()` and removes the keychain, profile copies,
   private key, decoded certificate, archive, and export output.

Godot 4.7.2 has a release provisioning-profile environment-variable quirk. The
current signing setup exports both the debug and release UUID overrides while
the release profile specifier still uses the release value. Preserve that
workaround until a deliberate Godot upgrade confirms it is no longer needed.

SamuelIcecream now has its app-specific Apple records and protected GitHub
credentials configured, but it has not yet completed a real TestFlight
submission. Those account resources and secrets do not transfer when this
runbook is used for another repository. The successful unsigned smoke build
validates Godot export and Xcode compilation only. Treat each new repository's
first signed run as the integration test for certificate import, provisioning,
archive export, API authentication, and App Store Connect processing.

## 15. Items that cannot be copied from SamuelIcecream

Do not expect source files to recreate:

- Apple Developer Program membership.
- Apple Team ID authorization.
- A unique registered bundle ID.
- App Store Connect app metadata.
- Distribution certificate private key.
- Certificate export password.
- App-specific provisioning profile.
- App Store Connect API private key.
- GitHub environment variables or secrets.
- GitHub environment reviewers and branch/tag policies.
- GitHub Actions caches.
- Local `.tools/` downloads.
- Generated `.godot/` import cache.
- Physical-device testing.

These must be created, configured, or regenerated for the new repository as
appropriate.

## 16. Failure diagnosis

Use the narrowest applicable response:

| Failure | Likely cause | Required response |
|---|---|---|
| `godot` not found after setup | Current terminal has stale `PATH` or setup did not create the user-local shim | Open a new terminal, rerun setup, and inspect `.local\bin`; do not create a machine-wide startup launcher |
| Setup reports a conflicting `godot` command | Another installation appears earlier on `PATH` | Remove or reorder only the conflicting command, rerun setup, and confirm both `godot` and `godot-console` report the pinned version |
| Wrong Godot version or channel | Existing installation differs from the manifest or is a prerelease/custom build | Install the pinned stable version; do not let another editor rewrite project files |
| Unsupported Windows architecture | Host is not the x64 architecture pinned in the manifest | Stop before installation and create a separately validated architecture-specific toolchain |
| ImageMagick command missing | Package path or application alias is absent | Resolve the exact pinned installation path, then rerun verification |
| Krita installer requires unavailable elevation | Installer mode conflicts with host policy | Use the official checksum-verified portable build at a user-local path |
| Godot iOS preflight rejects textures | ETC2/ASTC import is disabled | Set `textures/vram_compression/import_etc2_astc=true` |
| Godot iOS export reports an invalid icon | `config/icon` is absent or invalid | Add and import a valid square app icon |
| Godot exports but expected ZIP is absent | Script assumes the wrong iOS output shape | Expect the generated `.xcodeproj` directory under `build/ios` |
| Godot attempts to sign/archive directly | Export-only mode is missing | Set `application/export_project_only=true` |
| Smoke build asks for signing | Xcode signing was not fully disabled | Restore all `CODE_SIGNING_*` and team overrides in `build-ios-unsigned.sh` |
| Release profile mismatch | Bundle ID, Team ID, or profile is for another app | Replace the app-specific profile or correct the approved identifiers |
| Xcode/SDK preflight mismatch | GitHub runner image changed or pins disagree | Validate a supported stable image, then update manifest, workflows, and docs together |
| Workflow cannot access secrets | Environment is missing, restricted, or secrets were stored at the wrong scope | Configure the repository's `testflight` environment and policy |

Do not bypass preflight validation to make a job appear green. Resolve the
underlying mismatch.

## 17. Definition of done

The environment is recreated only when all applicable items are true:

### Local workstation

- [ ] The new repository is separate and not nested inside SamuelIcecream.
- [ ] `tools/toolchain.json` exists and remains internally consistent.
- [ ] Windows setup completed using the repository script.
- [ ] Windows verification reports the pinned versions.
- [ ] Godot imports the new project successfully.
- [ ] Godot starts the main scene headlessly without script errors.
- [ ] Krita and Audacity are available when GUI editors were requested.
- [ ] ImageMagick and FFmpeg commands are available.
- [ ] Git LFS is installed, but no file patterns are tracked unless explicitly
      chosen for this game.
- [ ] No relevant startup command, scheduled task, service, or login launcher
      was added.
- [ ] Generated directories and signing file patterns are ignored.
- [ ] `git grep --untracked -In -i -E "samuel ?icecream"` returns no unintended
      product-specific reference.

### Repository automation

- [ ] The Linux `Godot CI` workflow passes in the new repository.
- [ ] The manual unsigned iOS smoke workflow passes on the pinned macOS runner.
- [ ] The smoke build compiles a generic arm64 iOS device target.
- [ ] No signed or credential-bearing artifact is published.
- [ ] Actions use full commit SHA pins and minimal repository permissions.

### Signed release, when requested

- [ ] The new app has a unique explicit production bundle identifier.
- [ ] The App Store Connect app record exists.
- [ ] The provisioning profile matches the bundle ID and Team ID.
- [ ] The repository has its own protected `testflight` environment.
- [ ] Environment policies permit only `main` and `v*`.
- [ ] Required variables and secrets are configured without logging them.
- [ ] A signed workflow completes and App Store Connect begins processing the
      uploaded build.

The initial environment build is still complete for development when the final
signed-release checklist is pending private Apple account setup. State that
boundary explicitly rather than reporting the entire release path as complete.

## 18. Evidence to include in an agent handoff

An agent's final handoff should identify:

```text
Repository:
Local path:
Current commit:
Godot version:
Git LFS version:
ImageMagick version:
FFmpeg version:
Krita version and install mode:
Audacity version and install mode:
Startup audit result:
Linux CI run URL:
iOS smoke run URL:
TestFlight environment status:
Signed release status:
Known blockers or deviations:
```

Do not include secret values, certificate contents, profile contents, personal
paths that are unnecessary for the recipient, or authenticated URLs.

## 19. Prompt for a future agent

The repository owner can use this prompt after creating the next repository:

```text
Use docs/environment-rebuild-runbook.md from
CHDAFNI-MSFT/SamuelIcecream as the authoritative clean-room procedure.
Prepare this new game repository and this computer for Windows-first Godot 2D
and audio development. Reuse the pinned toolchain and CI architecture, replace
all SamuelIcecream-specific identifiers, do not configure any application to
run at startup, do not use Azure, and stop before signed TestFlight work if
app-specific Apple credentials are unavailable. Verify every applicable
definition-of-done item and provide the evidence listed in the runbook.
```

That prompt is intentionally short because this document contains the detailed
requirements, constraints, commands, and acceptance criteria.
