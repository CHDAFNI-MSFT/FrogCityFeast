# iOS Ad Hoc Registered-Device Testing

This guide prepares an official Apple Ad Hoc build for the three approved
iPads without using TestFlight. It does not change the selected normal public
App Store distribution route.

TestFlight remains unavailable to the intended under-13 Apple Account. Ad Hoc
testing does not alter the account age and does not bypass TestFlight; Apple
signs the app for a specific registered device through an Ad Hoc provisioning
profile.

## Current prepared state

The repository contains a separate manual
[`iOS Ad Hoc registered-device validation`](../.github/workflows/ios-ad-hoc.yml)
workflow. It:

- runs only from `main` for version `0.1.0`;
- requires an `ad-hoc` authorization followed by the existing protected
  `testflight` signing-credential approval;
- uses the pinned Godot 4.7.2, Xcode 26.6, and iOS 26.5 toolchain;
- uses the retained Admin Team API key only to query or register the three
  protected devices and create or reuse the exact Ad Hoc profile;
- resolves the existing App ID and protected Apple Distribution certificate
  without creating, modifying, revoking, disabling, or deleting them;
- validates that the profile matches Team ID `CV7JQ487YU`, bundle ID
  `com.chdafni.frogcityfeast`, the Apple Distribution certificate, and the
  three protected iPad UDIDs;
- archives and exports with Xcode's `release-testing` method;
- verifies the signed app, embedded profile, application identifier, and
  registered-device membership; and
- deletes the IPA, archive, profile, certificate copy, keychain, and export
  directory after validation.

The GitHub `ad-hoc` authorization environment is configured for branch `main`,
requires reviewer `CHDAFNI-MSFT`, permits no administrator bypass, and contains
no variables or secrets. Signing values remain isolated in the separately
approved historical `testflight` environment. Three independently masked
device-identifier secrets and the separate provisioning-only Admin key are
configured there; their values are not recorded in the repository. The owner
requested that this Admin key remain retained for future protected
provisioning. It must not replace or rename the App Manager metadata key.

No signed IPA is retained, uploaded as a GitHub artifact, or published. The
workflow is a provisioning and build validator until a separately approved
private delivery path exists.

## Protected inputs

The historical `testflight` environment has these provisioning inputs
configured:

| Secret | Required value | Status |
|---|---|---|
| `IOS_AD_HOC_DEVICE_UDID_1` | First approved iPad UDID | Configured |
| `IOS_AD_HOC_DEVICE_UDID_2` | Second approved iPad UDID | Configured |
| `IOS_AD_HOC_DEVICE_UDID_3` | Third approved iPad UDID | Configured |
| `APPLE_PROVISIONING_KEY_ID` | Key ID for the retained provisioning-only Admin Team API key | Configured |
| `APPLE_PROVISIONING_PRIVATE_KEY_BASE64` | Base64 of that Admin Team API private key | Configured |
| `APP_STORE_CONNECT_ISSUER_ID` | Existing Team API issuer shared with the metadata key | Configured |

The existing `APPLE_CERTIFICATE_BASE64` and
`APPLE_CERTIFICATE_PASSWORD` secrets provide the certificate identity. The
App Store profile and App Manager key secrets remain separate and are not
overwritten, renamed, or used for device/profile mutation.

Treat every UDID as a protected device identifier. Do not place one in a
workflow input, issue, commit, log, or documentation file. Separate GitHub
secrets allow each complete identifier to be masked independently.

## Device registration behavior

Obtain each approved iPad identifier outside the repository through Apple's
current trusted-device tooling. Confirm only that each value uses Apple's
supported modern or legacy format, then store it directly in its numbered
GitHub secret. Do not record the value or a personal device name in Git.

The protected workflow automatically queries each UDID before any write. It
accepts only one exact enabled IOS/IPAD record. A disabled, ambiguous,
wrong-platform, or wrong-device-class match is terminal. When no record exists,
it creates one generic non-personal name such as `Frog City Feast Test iPad 1`.
It never patches, deletes, disables, or re-enables a device. A conflict or
network-ambiguous create is handled only by bounded exact re-reads; the workflow
never blindly creates the device again.

Device slots are limited by product family and membership year. Disabling or
removing a device may not restore the slot until the membership reset window,
so the protected values must be verified before the run.

## Automatic profile reconciliation

No manual profile download or Ad Hoc profile secret is needed. The workflow:

1. resolves exactly one iOS or Universal bundle ID matching the protected
   product identifier and never modifies it;
2. compares the protected `.p12` certificate fingerprint and serial against
   the active, sufficiently unexpired `DISTRIBUTION` API certificate;
3. derives a deterministic profile name from committed product identity,
   generation token, and hashes of the sorted device set, bundle, and
   certificate, without embedding a raw UDID;
4. reuses only one exact active, sufficiently unexpired `IOS_APP_ADHOC`
   profile with exact one-bundle, one-certificate, and three-device
   relationships; or
5. creates that exact profile once and reconciles conflicts or ambiguous
   completion through bounded reads without deleting or blindly recreating it.

The downloaded API `profileContent` exists only under `RUNNER_TEMP`. Before
signing, the workflow decodes its CMS plist and checks API UUID agreement,
expiration, iOS platform, exact application identifier, disabled debugging,
non-enterprise status, exact three-device membership, and inclusion of the
selected certificate. The signing preparation and exported-IPA checks repeat
the critical validations as defense in depth.

The workflow rejects development, App Store, enterprise, expired, wildcard,
wrong-team, wrong-app, wrong-certificate, missing-device, duplicate-device,
and extra-device profiles.

## Protected workflow sequence

After the protected inputs are confirmed:

1. Run `iOS Ad Hoc registered-device validation` from `main`.
2. Enter version `0.1.0` and enable `confirm_build`.
3. Approve the `ad-hoc` authorization job.
4. Separately approve the protected `testflight` credential job.
5. Confirm signing, archive, `release-testing` export, embedded-profile
   validation, and cleanup all succeed.

The workflow intentionally produces no downloadable artifact. A successful run
proves that Apple signing and the registered-device profile work, but it does
not install the app.

## Private delivery remains blocked

Installing without a Mac requires a private HTTPS OTA route containing:

- the signed Ad Hoc IPA;
- an HTTPS manifest referencing that IPA;
- an `itms-services` installation link; and
- access controls that prevent unrestricted signed-artifact distribution.

Do not use public GitHub Pages or a public workflow artifact for the IPA. Do
not log or commit a signed URL. Creating paid storage, a private delivery
service, or other cloud infrastructure requires explicit approval before any
resource is provisioned.

Once private delivery is approved, extend the protected workflow so the
plaintext IPA exists only on the ephemeral runner and approved private host,
the installation URL is short-lived and protected, and cleanup still runs on
every outcome.

## Physical acceptance after installation

Use the installed Ad Hoc build for the release checklist's A16 iPad acceptance:

- sustained performance and thermal measurements under every stress scenario;
- touch, safe-area, orientation, interruption, and background/foreground tests;
- audio mix, mute behavior, and haptics;
- Reduce Motion, larger text and controls, timing assistance, contrast, and
  readable status feedback;
- save errors, low storage, reinstall, and local-data deletion; and
- the deferred final icon, screenshot, and in-game visual review.

Ad Hoc acceptance does not submit or release the App Store version. The normal
candidate, App Review submission, and manual public release remain separately
authorized operations.
