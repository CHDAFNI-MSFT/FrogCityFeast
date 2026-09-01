# iOS Build and App Store Setup

SamuelIcecream uses Windows for normal development and a GitHub-hosted macOS
runner only for Apple-specific Godot export, Xcode compilation, signing, and
submission.

## Production distribution decision

The September 1, 2026 production decision selects a **normal public App Store
release**. TestFlight is unavailable to the target device because its Apple
Account is under 13. Do not falsify the account age, bypass the restriction, or
use the existing internal TestFlight path as the target-device installation
plan.

The repository must add a separate protected App Store workflow and export
options that omit `testFlightInternalTestingOnly`. The existing TestFlight
workflow and internal group are retained only as historical protected
infrastructure until a separately reviewed cleanup decision; they are not the
selected distribution route.

No signing, upload, App Store submission, publication, release, or tag is
authorized by this decision. Public distribution remains blocked until the
production pass, metadata, privacy disclosures, age-rating inputs, target-iPad
measurements, and release checklist are complete and the repository owner gives
explicit release authorization.

## Unsigned pipeline verification

The credential-free pipeline is verified through
[`iOS unsigned smoke build`](https://github.com/CHDAFNI-MSFT/SamuelIcecream/actions/workflows/ios-smoke.yml).
Manual run
[`33327784555`](https://github.com/CHDAFNI-MSFT/SamuelIcecream/actions/runs/33327784555)
completed successfully on August 30, 2026 for audio commit
`73cfb5ef1cbc8d3d5e9eb71dbec44a4455d8fd76`:

- the pinned Godot 4.7.2 editor and export templates installed on `macos-26`;
- the Xcode 26.6 and iOS 26.5 preflight passed;
- Godot generated `SamuelIcecream.xcodeproj` with the `SamuelIcecream` scheme;
- Xcode compiled the Release configuration for a generic arm64 iOS device with
  signing disabled; and
- no certificate, provisioning profile, App Store credential, or build artifact
  was used or uploaded.

The normal Windows/Linux project check also runs
`tests/ios_pipeline_smoke.gd`. This deterministic regression check verifies the
manual-only trigger, read-only permissions, pinned action commits and
toolchain, absence of secrets, generated project-only arm64 preset, temporary
`export_presets.cfg` cleanup, and the explicit Xcode signing overrides. It does
not replace the macOS integration run.

Godot CI run
[`33327743256`](https://github.com/CHDAFNI-MSFT/SamuelIcecream/actions/runs/33327743256)
also passed on that exact commit. The successful unsigned run includes the
generated-project validator, iPad-only target, explicit icon, privacy
declarations, warning sanitation, original audio files,
`default_bus_layout.tres`, and the audio autoload.

The cited runs cover the audio commit only. Later gameplay commits require
their own Godot CI result, and remain outside the unsigned iOS integration run
until that manual workflow is separately authorized. Do not approve a signed
release until both checks pass on the intended release commit.

The successful build retains non-fatal Godot/Xcode warnings for a legacy boot
splash property, empty camera/photo-library/microphone purpose strings emitted
by the generated project, a generated header pragma, and skipped App Intents
metadata. The shared export script now removes only the three empty, unused
purpose-string keys and fails if any of them becomes non-empty. It also
validates the generated AppIcon catalog, bundle/version build settings,
encryption declaration, and Godot privacy manifest before either iOS workflow
continues.

The remaining warnings require no repository workaround:

| Warning | Release disposition |
|---|---|
| `application/boot_splash/fullsize` property not found | Godot 4.7.2's iOS exporter still queries this legacy property. The project does not define it; adding an obsolete setting would hide rather than fix the exporter warning. |
| Empty camera, microphone, and photo-library purpose strings | Removed from the generated project because the game uses none of these capabilities. Do not add inaccurate purpose text. |
| `dummy.h` has `#pragma once` in the main file | Generated Godot template warning with no effect on the compiled application. Do not patch generated engine files. |
| App Intents metadata extraction skipped | Expected because the game does not link `AppIntents.framework` or provide App Intents. |

Godot 4.7.2 generates and embeds `PrivacyInfo.xcprivacy`. The export preset
declares file timestamp access only inside the app container, system boot time
only for on-device elapsed-time measurement, and disk-space access only for
writing or deleting files. Tracking and data collection are disabled. The
generated-project validator fails if those declarations drift.

## Workflow design

| Workflow | Trigger | Credentials | Purpose |
|---|---|---|---|
| `Godot CI` | Push, pull request, manual | None | Import, start, and run deterministic project checks on Linux |
| `iOS unsigned smoke build` | Manual | None | Export through Godot and compile an unsigned generic iOS device target |
| `iOS TestFlight release` | Manual from `main` or a `v*` tag | Protected `testflight` environment | Archive, sign, and submit to App Store Connect |

The smoke workflow uses the synthetic Team ID `0000000000` only because Godot
requires a non-empty Team ID before generating an Xcode project. Xcode signing
is explicitly disabled, so this value never identifies or accesses an Apple
account.

Both iOS workflows use the stable `macos-26` arm64 runner, Xcode 26.6, and the
iOS 26.5 SDK recorded in `tools/toolchain.json`. They download the Godot macOS
editor and export templates from the official Godot release, then verify the
SHA-512 checksums before use.

The iOS preset explicitly targets iPad only, matching the documented product
scope and 4:3 presentation. Supporting iPhone later requires a separately
reviewed layout, device-testing, and export-preset change.

## Apple account prerequisites

The selected release identity is:

| Field | Selected value |
|---|---|
| Bundle identifier | `com.chdafni.frogcityfeast` |
| App Store Connect name | `Frog City Feast` |
| SKU | `FROGCITYFEAST-IOS-001` |
| Primary language | English (U.S.) |
| Apple Developer Team ID | `CV7JQ487YU` |
| Selected distribution | Normal public App Store release |
| Non-exempt encryption | No; `ITSAppUsesNonExemptEncryption` is `false` |

The bundle identifier uses reverse-DNS syntax but does not require ownership of
a matching internet domain. Treat it as permanent after creating the App Store
Connect record. The Godot project and generated iPad application display name
are also **Frog City Feast**.

Current prerequisite status:

| Prerequisite | Status |
|---|---|
| Explicit App ID | Created for `com.chdafni.frogcityfeast`. Apple automatically enables the immutable In-App Purchase feature for this Universal App ID; the game has no StoreKit integration, products, or purchase UI. No optional capability was requested. |
| App Store Connect app record | Created for **Frog City Feast** with primary locale `en-US`, bundle ID `com.chdafni.frogcityfeast`, and SKU `FROGCITYFEAST-IOS-001`. |
| Apple Distribution certificate | Created and valid through August 30, 2027. Its private key and randomly generated `.p12` password exist only in the protected GitHub environment secret set. |
| App Store provisioning profile | Created for the exact App ID and certificate, validated, and valid through August 30, 2027. |
| App Store Connect API key | A Developer-role team key is configured in the protected GitHub environment and passed authenticated app and TestFlight operations. The previous Admin key was confirmed revoked and its local file was deleted. |
| Internal TestFlight group | **Frog City Feast Internal** exists as an internal group with the sole App Store Connect user added. Automatic access to all builds is disabled and no public link is enabled. The tester remains `NOT_INVITED` until a build is assigned. |
| Apple agreements | The account holder confirmed that MFA and current legal agreements are complete. App Store listing privacy, rating, contact, and marketing metadata remain later release work rather than blockers for internal-only TestFlight. |

No remaining portal configuration blocks the first internal-only upload.
Complete the app-specific privacy, age-rating, contact, category, and marketing
metadata before external TestFlight testing or App Store submission. The
Developer-role API key can upload builds and manage the internal group, but
Apple rejected API creation of the optional beta-app localization with this
role. That localization is not required for internal-only testing.

The provisioning profile must use the same Team ID and exact bundle identifier
configured in GitHub. The workflow rejects development, Ad Hoc, enterprise,
expired, wildcard, or mismatched profiles before importing the signing
certificate. It also verifies that the profile includes the supplied,
unexpired Apple Distribution certificate and that the certificate Team ID is
`CV7JQ487YU`.

## GitHub environment

Create an environment named `testflight` under **Settings > Environments**.
Configure its deployment branch and tag policy to allow only:

- Branch `main`
- Tags matching `v*`

The environment is configured with `CHDAFNI-MSFT` as its required reviewer and
self-review prevention disabled. A manual dispatch or `v*` tag can start the
job, but the signing secrets remain unavailable until that environment approval
is granted. Keep this gate in place while the repository has only one release
operator.

Add these environment variables:

| Variable | Value |
|---|---|
| `APPLE_TEAM_ID` | `CV7JQ487YU` |
| `IOS_BUNDLE_ID` | `com.chdafni.frogcityfeast` |

Both variables are configured. Add the following values only through the
`testflight` environment's **Environment secrets** controls; never use
repository-level secrets for this workflow.

All six required environment secret names contain configured values. The
Developer-role App Store Connect team Key ID, Issuer ID, and private key passed
an authenticated app lookup. The Apple Distribution `.p12`, its password, and
the matching App Store provisioning profile were validated before being
written directly to the protected environment. No local copy of the
certificate private key, `.p12`, password, CSR, certificate, or profile was
retained.

The previous Admin API key is no longer stored in GitHub, was confirmed revoked
by Apple, and its local `.p8` file was deleted.

Add these environment secrets:

| Secret | Content |
|---|---|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store `.mobileprovision` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API Issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | Base64-encoded App Store Connect `.p8` |

On macOS, encode each binary or key file without adding line wrapping:

```bash
base64 -i Distribution.p12 | pbcopy
base64 -i SamuelIcecream.mobileprovision | pbcopy
base64 -i AuthKey_KEYID.p8 | pbcopy
```

On Windows PowerShell:

```powershell
[Convert]::ToBase64String(
    [IO.File]::ReadAllBytes("Distribution.p12")
) | Set-Clipboard
```

Repeat the PowerShell command for the provisioning profile and API private key.
Keep all source files outside the repository, enter the encoded values directly
in GitHub, clear the clipboard, and delete local copies when they are no longer
needed. Never place certificate, profile, private-key, or password files inside
the repository.

## Release sequence

1. Run `Godot CI` successfully on the intended commit.
2. After the intended changes are committed, run `iOS unsigned smoke build` on
   that exact commit. Do not proceed until the new generated-project validation
   and unsigned Xcode compile both pass.
3. Confirm the `testflight` environment approval gate is still enabled.
4. Manually run `iOS TestFlight release` from `main` with a numeric version such
   as `0.1.0`.
5. After the first successful submission, prefer annotated release tags such as
   `v0.1.1`. The tag supplies the marketing version.
6. Confirm processing, export-compliance status, and internal testing in App
   Store Connect before promoting a build.

The workflow combines `github.run_number` and `github.run_attempt` for
`CFBundleVersion`, so a new run or rerun does not reuse a submitted build
number. Do not rename or recreate the workflow without first checking the last
uploaded App Store Connect build number because GitHub's workflow run number
would restart.

### First internal TestFlight install

The TestFlight path does not require registering an iPad UDID or adding the
device to the provisioning profile.

1. Commit the intended repository state and push that commit to `main`.
2. In GitHub **Actions**, open **iOS unsigned smoke build**, choose **Run
   workflow**, select `main`, and wait for the exact commit to pass.
3. Open **iOS TestFlight release**, choose **Run workflow**, select `main`, and
   enter a numeric marketing version such as `0.1.0`.
4. Approve the protected `testflight` environment deployment. This approval is
   the point after which the job can access signing and upload credentials.
5. Wait for the workflow to finish and for Apple to process the uploaded build.
   Resolve **Missing Compliance** if App Store Connect requests confirmation;
   the app declares that it does not use non-exempt encryption.
6. In App Store Connect, open **Frog City Feast > TestFlight > Internal
   Testing > Frog City Feast Internal**, choose **Add Builds**, select the
   processed build, and enter concise **What to Test** notes. Automatic
   distribution remains disabled intentionally.
7. On the iPad, install Apple's **TestFlight** app from the App Store and sign
   in with the Apple Account belonging to the configured App Store Connect
   internal tester.
8. Accept the invitation email or open the available build in TestFlight, then
   choose **Install**. Internal builds remain available for 90 days.

The exported application is iPad-only and marked **TestFlight Internal Only**.
It cannot be promoted to external testing or App Store review.

## Signing and cleanup behavior

The release job:

1. Decodes signing files only into `$RUNNER_TEMP`.
2. Validates the provisioning profile Team ID and application identifier.
3. Rejects expired or non-App-Store profiles and verifies that the supplied
   Apple Distribution certificate belongs to both the Team ID and profile.
4. Creates a random-password temporary keychain.
5. Imports only the Apple Distribution identity.
6. Installs the profile into both current and legacy Xcode profile locations.
7. Exports and validates the Godot-generated Xcode project.
8. Archives with manual signing and no permission to create or update signing
   assets in the Apple portal.
9. Uploads through `xcodebuild -exportArchive` using the App Store Connect API
   key and marks the build as **TestFlight Internal Only**.
10. Deletes the temporary keychain, profile copies, private key, archive, and
    DerivedData, export output, and build logs even when an earlier step fails.

No signed IPA, Xcode archive, provisioning profile, or signing key is uploaded
as a GitHub artifact. Workflows have read-only repository permissions and
checkout does not persist Git credentials. An internal-only build cannot later
be promoted to external testing or App Store review; deliberately remove the
`testFlightInternalTestingOnly` export option in a separately reviewed change
when external distribution is approved.

## Maintenance

The runner label, Xcode version, Xcode developer directory, and iOS SDK are
pinned because GitHub runner defaults change over time. Before updating them:

1. Confirm the target image is stable rather than preview.
2. Verify the Xcode and SDK versions in the official runner image manifest.
3. Update `tools/toolchain.json`, both iOS workflows, and this document in one
   change.
4. Run the unsigned smoke workflow before allowing a TestFlight release.

The macOS release path cannot be fully exercised from Windows. Local validation
covers project import and startup plus deterministic workflow, manifest,
preset, secret, and signing-override checks. The manual smoke workflow is the
authoritative integration test for Godot export and Xcode compilation. Run it
again after committing changes that affect project resources, scenes, scripts,
icons, or export configuration.
