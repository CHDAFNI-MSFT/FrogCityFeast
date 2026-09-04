# iOS Build and App Store Setup

FrogCityFeast uses Windows for normal development and a GitHub-hosted macOS
runner only for Apple-specific Godot export, Xcode compilation, signing, and
submission.

For the reusable setup order, failure modes, API-role requirements, and lessons
to apply before creating another app, read
[`apple-app-publishing-runbook.md`](apple-app-publishing-runbook.md).

## Production distribution decision

The September 1, 2026 production decision selects a **normal public App Store
release**. TestFlight is unavailable to the target device because its Apple
Account is under 13. Do not falsify the account age, bypass the restriction, or
use the existing internal TestFlight path as the target-device installation
plan.

The repository includes a separate manual
[`iOS App Store candidate upload`](../.github/workflows/ios-app-store.yml)
workflow. It uses the protected `app-store` environment and an export mode that
omits `testFlightInternalTestingOnly`. A second protected approval lets the
signing job consume the existing credentials from the `testflight` environment
without copying or revealing them. The existing TestFlight workflow and
internal group remain historical infrastructure; they are not the selected
distribution route.

The manual
[`App Store candidate inspection`](../.github/workflows/app-store-candidate-inspection.yml)
workflow uses the same two approvals and API credentials for read-only
inspection after upload. It waits for the exact build to finish processing and
reports build validity, export-compliance state, selected-build status,
13-inch iPad screenshot completeness, and App Review contact completeness
without printing contact values or selecting, submitting, or releasing a
build.

The separately authorized
[`App Store submission preparation`](../.github/workflows/app-store-submission-prep.yml)
workflow runs on Windows, checks out the exact uploaded candidate source,
regenerates and validates the approved seven-image package, uploads screenshots
directly to Apple, creates or updates the App Review detail from protected
contact secrets, and selects only the exact processed build. Generated images
remain runner-local and are always removed. The workflow cannot create a
review submission or release request.

The separately authorized
[`App Store review submission`](../.github/workflows/app-store-review-submission.yml)
workflow rechecks the exact version, selected build, screenshots, review
details, processing state, export compliance, and manual release type. It
creates or safely resumes one iOS review submission, adds only version `0.1.0`,
and submits it to App Review. It cannot request release, create a tag, publish
a GitHub release, or change the version from manual release.

No signing, upload, App Store submission, publication, release, or tag is
authorized by this decision. Public distribution remains blocked until the
production pass, metadata, privacy disclosures, age-rating inputs, target-iPad
measurements, and release checklist are complete and the repository owner gives
explicit release authorization.

## Unsigned pipeline verification

The credential-free pipeline is verified through
[`iOS unsigned smoke build`](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/workflows/ios-smoke.yml).
Manual run
[`33327784555`](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33327784555)
completed successfully on August 30, 2026 for audio commit
`73cfb5ef1cbc8d3d5e9eb71dbec44a4455d8fd76`:

- the pinned Godot 4.7.2 editor and export templates installed on `macos-26`;
- the Xcode 26.6 and iOS 26.5 preflight passed;
- Godot generated `FrogCityFeast.xcodeproj` with the `FrogCityFeast` scheme;
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
[`33327743256`](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33327743256)
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
| `iOS Ad Hoc registered-device validation` | Manual from `main` with explicit confirmation | Protected `ad-hoc` authorization followed by protected `testflight` certificate, three device secrets, and provisioning-only Admin API key | Automatically reconcile the exact devices/profile, then sign and validate without retaining or publishing the IPA |
| `iOS App Store candidate upload` | Manual from `main` with explicit confirmation | Protected `app-store` authorization followed by protected `testflight` signing credentials | Archive, sign, and upload a normal App Store candidate without submitting it for review |
| `iOS TestFlight release` | Manual from `main` or a `v*` tag | Protected `testflight` environment | Historical internal-only upload path; not usable by the target under-13 account |

The smoke workflow uses the synthetic Team ID `0000000000` only because Godot
requires a non-empty Team ID before generating an Xcode project. Xcode signing
is explicitly disabled, so this value never identifies or accesses an Apple
account.

All iOS workflows use the stable `macos-26` arm64 runner, Xcode 26.6, and the
iOS 26.5 SDK recorded in `tools/toolchain.json`. They download the Godot macOS
editor and export templates from the official Godot release, then verify the
SHA-512 checksums before use.

The iOS preset explicitly targets iPad only, matching the documented product
scope and 4:3 presentation. Supporting iPhone later requires a separately
reviewed layout, device-testing, and export-preset change.

The Ad Hoc path is documented in
[`ios-ad-hoc-testing.md`](ios-ad-hoc-testing.md). Its three device secrets and
separate provisioning-only Admin key are configured. The protected workflow
now registers missing devices and creates or reuses the exact matching profile
through Apple's API; no manual profile download is needed. Its default mode
retains no signed artifact. The separately confirmed private OTA mode uploads
only after final IPA signature and embedded-profile validation, using the
private Azure storage path documented in `ios-ad-hoc-testing.md`. Protected run
[`33703681354`](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33703681354)
completed device/profile reconciliation, signing, `release-testing` export,
embedded-profile validation, and verified cleanup for build `33703681354.1`.
Protected run
[`33768105238`](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33768105238)
then completed the separately authorized private OTA upload for build
`33768105238.1`, confirmed anonymous access remained denied, retained no
GitHub artifact, and verified cleanup. This private registered-device build
does not submit, approve, or release the normal App Store version.

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
| App Store Connect API keys | An App Manager-role team key remains configured for metadata and upload work. A separate Admin Team API key is configured only for protected device/profile provisioning and is retained for future provisioning per the repository owner's request. Both use the existing issuer; their Key IDs and private-key secrets remain distinct. Neither private key is committed or retained on a GitHub runner. |
| Ad Hoc registered-device path | Validated successfully in protected run `33703681354` for the exact three configured devices and matching profile. The signed IPA was validated, not uploaded or published, and removed during verified cleanup. |
| Internal TestFlight group | **Frog City Feast Internal** exists as an internal group with the sole App Store Connect user added. Automatic access to all builds is disabled and no public link is enabled. The tester remains `NOT_INVITED` until a build is assigned. |
| Apple agreements and compliance | The account holder confirmed MFA and current legal agreements. The protected inspector confirms the live support/privacy URLs, rating, category, review notes, marketing copy, content rights, free pricing, storefront selection, screenshots, and App Review contact. Apple still reports `TRADER_STATUS_NOT_PROVIDED` and `CANNOT_SELL`; the Account Holder or Admin must complete the EU DSA declaration before submission can continue. |

The signing identity, App Store app record, and exact replacement build
`33770597608.1` exist. Protected run
[33823901657](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33823901657)
confirmed the build is valid and selected, the seven final screenshots and
App Review detail are complete, content rights and age rating match, free
pricing is active, China mainland is unavailable, and release remains manual.
App Review submission is now blocked by the account-level EU DSA trader
declaration, plus the separately tracked App Privacy publication state and
physical A16 acceptance. Complete those remaining items and the authorization
gates in
[`app-store-release-checklist.md`](app-store-release-checklist.md). Build
selection, App Review submission, and release remain separate App Store
Connect actions regardless of the API key's role.

The separate protected `App Store metadata sync` workflow can apply the
reviewed API-supported listing fields without uploading a build. Apple rejects
primary-locale and content-rights updates on the existing app record even
though those attributes remain in the current OpenAPI update schema, so those
values require direct confirmation. Run
[33616496541](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33616496541)
proved that authentication and read access do not establish metadata write
permission. The protected key was replaced with App Manager access without
broadening it to Admin. Runs
[33648261223](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33648261223)
and
[33653860478](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33653860478)
exposed and partially applied the initial-version path. Run
[33661855538](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33661855538)
then completed the metadata sync, including version localization and the age
rating. The owner directly saved content rights, free pricing, and every
storefront except China mainland. The protected inspector now verifies those
resources, screenshots, and App Review contact. App Privacy still requires
direct confirmation, and Apple will not mark the selected storefronts ready
until the Account Holder or Admin completes the EU DSA trader declaration.

Every provisioning profile must use the same Team ID and exact bundle
identifier configured in GitHub. The normal App Store path rejects development,
Ad Hoc, enterprise, expired, wildcard, or mismatched profiles. The separate Ad
Hoc path requires `IOS_APP_ADHOC`, exactly three protected devices, and no
enterprise/debug entitlement. Both verify that the profile includes the
supplied, unexpired Apple Distribution certificate and that the certificate
Team ID is `CV7JQ487YU`.

## Protected GitHub environments

The selected public workflow first enters a dedicated authorization environment
named `app-store`. It allows only branch `main`, requires `CHDAFNI-MSFT` as
reviewer, and keeps self-review prevention disabled while the repository has
only one release operator. Administrator bypass is disabled. The workflow is
manual-only and requires its `confirm_upload` input.

After that approval succeeds, the signing job enters the protected
`testflight` environment and requires its separate approval before credentials
become available. This consumes the existing validated secrets in place rather
than copying or exposing them. The job repeats the `main` and confirmation
conditions, administrator bypass is disabled for this environment too, and the
job still selects the normal `app-store` export mode. The historical TestFlight
workflow remains unavailable to the target under-13 account.

The registered-device workflow uses the same two-stage boundary. Its `ad-hoc`
authorization environment allows only `main`, requires `CHDAFNI-MSFT`, has
administrator bypass disabled, and stores no variables or secrets. Only after
that approval does the job enter `testflight` for the certificate, three
protected UDIDs, and provisioning-only Admin key. The Admin credentials are
passed only to the automatic device/profile provisioning step and are not
available to signing, archiving, OTA upload, or metadata mutation steps. The
OTA step receives only its dedicated revocable Azure policies when the manual
`publish_private_ota` input is enabled and `confirm_private_ota` exactly equals
`UPLOAD_PRIVATE_OTA`.

Add these environment variables:

| Variable | Value |
|---|---|
| `APPLE_TEAM_ID` | `CV7JQ487YU` |
| `IOS_BUNDLE_ID` | `com.chdafni.frogcityfeast` |
| `AZURE_OTA_STORAGE_ACCOUNT` | `stmobileota2041340e8c` |
| `AZURE_OTA_CONTAINER` | `ios-delivery` |

Configure `APPLE_TEAM_ID` and `IOS_BUNDLE_ID` in `app-store` as reviewable
identifiers and keep the same values in `testflight`. Configure the two
`AZURE_OTA_*` variables only in `testflight`, where the opt-in private upload
step reads them. Never use repository-level variables or secrets for these
workflows.

The normal App Store signing and App Manager values remain in the protected
historical `testflight` environment and passed certificate, profile, and
authenticated App Store Connect validation. The approved route leaves them
there and keeps `app-store` free of signing secrets. The separate Admin Team
key is retained only for future protected provisioning as requested by the
owner. No local copy of the certificate private key, `.p12`, password, CSR,
certificate, profile, or API private key is retained by the repository or
workflow runner.

The signed job reads these existing `testflight` environment secrets:

| Secret | Content |
|---|---|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded Apple Distribution `.p12` |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Base64-encoded App Store `.mobileprovision` |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API Key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect API Issuer ID |
| `APP_STORE_CONNECT_PRIVATE_KEY_BASE64` | Base64-encoded App Store Connect `.p8` |

Registered-device testing uses these configured separate secrets without
replacing the App Store profile or App Manager credentials:

| Secret | Content |
|---|---|
| `IOS_AD_HOC_DEVICE_UDID_1` through `_3` | Three independently masked protected iPad UDIDs |
| `APPLE_PROVISIONING_KEY_ID` | Key ID for the provisioning-only Admin Team API key |
| `APPLE_PROVISIONING_PRIVATE_KEY_BASE64` | Base64-encoded private key for that provisioning-only Admin key |
| `AZURE_OTA_UPLOAD_SAS` | Revocable HTTPS-only `workflow-upload` stored-policy SAS |
| `AZURE_OTA_INSTALL_SAS` | Revocable HTTPS-only read-only `device-install` stored-policy SAS |

The existing `APP_STORE_CONNECT_ISSUER_ID`, distribution certificate, and
certificate password are reused by the provisioning step. The device and Admin
key secrets are configured. No Ad Hoc profile secret is required: the workflow
registers only missing exact devices, creates or reuses the deterministic
exact-membership profile, validates its API content, and hands its protected
`RUNNER_TEMP` path to signing.

On macOS, encode each binary or key file without adding line wrapping:

```bash
base64 -i Distribution.p12 | pbcopy
base64 -i AuthKey_KEYID.p8 | pbcopy
```

On Windows PowerShell:

```powershell
[Convert]::ToBase64String(
    [IO.File]::ReadAllBytes("Distribution.p12")
) | Set-Clipboard
```

Repeat the PowerShell command for an API private key. Keep all source files
outside the repository, enter the encoded values directly in GitHub, clear the
clipboard, and delete local copies when they are no longer needed. The retained
provisioning key exists only as a protected secret; no manual Ad Hoc profile
download is needed. Never place certificate, profile, private-key, or password
files inside the repository.

## Authorized public release sequence

1. Complete
   [`app-store-release-checklist.md`](app-store-release-checklist.md),
   including live support/privacy URLs, accurate metadata and rating answers,
   final screenshots, exact-commit checks, and physical A16 iPad acceptance.
2. Run `Godot CI` successfully on the intended commit.
3. Run `iOS unsigned smoke build` on that exact commit. Do not proceed until
   generated-project validation and the unsigned Xcode compile both pass.
4. Obtain explicit upload authorization for one exact commit and marketing
   version. The current workflow is fail-closed to the authorized version
   `0.1.0`; changing it requires a separately reviewed commit and authorization.
5. Confirm the `app-store` and `testflight` branch restrictions, reviewers,
   non-secret variables, and existing `testflight` secret names.
6. Manually run `iOS App Store candidate upload` from `main`, enter `0.1.0`,
   and enable `confirm_upload`.
7. Approve the protected `app-store` authorization job, then separately approve
   the `testflight` signing job. Credentials become available only after the
   second approval.
8. Wait for App Store Connect processing and inspect the candidate. The
   workflow does not select the build for a version, submit it for App Review,
   or release it.
9. Obtain separate explicit submission authorization before selecting the
   processed build and submitting the complete version to App Review.
10. Select **Manually release this version** and obtain separate explicit
    release authorization before making an approved version public.

Both upload workflows combine the repository-wide `github.run_id` and
`github.run_attempt` for `CFBundleVersion`. Run IDs are unique across workflows,
and a rerun receives a new attempt component, so the retained TestFlight path
cannot collide with the public candidate path.

### Historical TestFlight path

The target under-13 Apple Account cannot use TestFlight. Do not change the
account age, route around Apple's restriction, or treat another account's
internal install as acceptance for the target player. The retained
`iOS TestFlight release` workflow explicitly selects `internal-testflight`;
its generated export options include `testFlightInternalTestingOnly`, so those
builds cannot be promoted to App Review. The public workflow selects
`app-store`, whose generated export options omit that key.

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
   key. Internal mode adds the TestFlight-only key; public mode omits it and
   creates a normal App Store candidate.
10. Deletes the temporary keychain, profile copies, private key, archive, and
    DerivedData, export output, and build logs even when an earlier step fails.

No signed IPA, Xcode archive, provisioning profile, or signing key is uploaded
as a GitHub artifact. Workflows have read-only repository permissions and
checkout does not persist Git credentials. Uploading a public candidate does
not select it for an App Store version, submit it for review, or publish it.
Those remain separately authorized manual actions.

## Maintenance

The runner label, Xcode version, Xcode developer directory, and iOS SDK are
pinned because GitHub runner defaults change over time. Before updating them:

1. Confirm the target image is stable rather than preview.
2. Verify the Xcode and SDK versions in the official runner image manifest.
3. Update `tools/toolchain.json`, all three iOS workflows, and this document in
   one change.
4. Run the unsigned smoke workflow before allowing any signed upload.

The macOS release path cannot be fully exercised from Windows. Local validation
covers project import and startup plus deterministic workflow, manifest,
preset, secret, and signing-override checks. The manual smoke workflow is the
authoritative integration test for Godot export and Xcode compilation. Run it
again after committing changes that affect project resources, scenes, scripts,
icons, or export configuration.
