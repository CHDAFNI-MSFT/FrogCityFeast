# iOS Build and TestFlight Setup

SamuelIcecream exports from Godot on Windows during normal development and uses
a GitHub-hosted macOS runner only for Apple-specific compilation, signing, and
submission.

## Workflow design

| Workflow | Trigger | Credentials | Purpose |
|---|---|---|---|
| `Godot CI` | Push, pull request, manual | None | Import and start the project on Linux |
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

## Apple account prerequisites

Complete these steps in the Apple Developer and App Store Connect portals:

1. Enroll the publishing account in the Apple Developer Program.
2. Register a unique explicit bundle identifier.
3. Create the matching App Store Connect app record.
4. Create an Apple Distribution certificate and export it as a password-
   protected `.p12`.
5. Create an App Store distribution provisioning profile for the exact bundle
   identifier and download the `.mobileprovision` file.
6. Create an App Store Connect API key with the minimum role and app access
   required to upload builds. Save its Key ID, Issuer ID, and one-time `.p8`
   download.
7. Complete agreements, export-compliance answers, privacy details, age rating,
   and TestFlight tester configuration before expecting a submitted build to
   become testable.

The provisioning profile must use the same Team ID and exact bundle identifier
configured in GitHub. The workflow rejects wildcard or mismatched profiles
before importing the signing certificate.

## GitHub environment

Create an environment named `testflight` under **Settings > Environments**.
Configure its deployment branch and tag policy to allow only:

- Branch `main`
- Tags matching `v*`

Require a trusted reviewer when another account is available to approve
releases. Do not enable self-review prevention if it would make releases
impossible for a single-owner personal repository.

Add these environment variables:

| Variable | Value |
|---|---|
| `APPLE_TEAM_ID` | The 10-character Apple Developer Team ID |
| `IOS_BUNDLE_ID` | The explicit App ID, such as `com.example.samuelicecream` |

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
Delete unencrypted local copies when they are no longer needed. Never place
certificate, profile, private-key, or password files inside the repository.

## Release sequence

1. Run `Godot CI` successfully on the intended commit.
2. Run `iOS unsigned smoke build` and resolve all Godot export or Xcode compile
   failures.
3. Configure the `testflight` environment, variables, secrets, and deployment
   policies.
4. Manually run `iOS TestFlight release` from `main` with a numeric version such
   as `0.1.0`.
5. After the first successful submission, prefer annotated release tags such as
   `v0.1.1`. The tag supplies the marketing version.
6. Confirm processing, export-compliance status, and internal testing in App
   Store Connect before promoting a build.

The workflow combines `github.run_number` and `github.run_attempt` for
`CFBundleVersion`, so a new run or rerun does not reuse a submitted build
number.

## Signing and cleanup behavior

The release job:

1. Decodes signing files only into `$RUNNER_TEMP`.
2. Validates the provisioning profile Team ID and application identifier.
3. Creates a random-password temporary keychain.
4. Imports only the Apple Distribution identity.
5. Installs the profile into both current and legacy Xcode profile locations.
6. exports the Godot project using manual profile overrides;
7. archives with manual signing;
8. uploads through `xcodebuild -exportArchive` using the App Store Connect API
   key; and
9. deletes the temporary keychain, profile copies, private key, archive, and
   export output even when an earlier step fails.

No signed IPA, Xcode archive, provisioning profile, or signing key is uploaded
as a GitHub artifact. Workflows have read-only repository permissions and
checkout does not persist Git credentials.

## Maintenance

The runner label, Xcode version, Xcode developer directory, and iOS SDK are
pinned because GitHub runner defaults change over time. Before updating them:

1. Confirm the target image is stable rather than preview.
2. Verify the Xcode and SDK versions in the official runner image manifest.
3. Update `tools/toolchain.json`, both iOS workflows, and this document in one
   change.
4. Run the unsigned smoke workflow before allowing a TestFlight release.

The macOS release path cannot be fully exercised from Windows. Local validation
covers project import and startup, preset rendering, manifest structure, and
script syntax; the manual smoke workflow is the authoritative integration test
for Godot export and Xcode compilation.
