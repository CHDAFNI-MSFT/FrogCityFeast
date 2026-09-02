# iOS Ad Hoc Registered-Device Testing

This guide prepares an official Apple Ad Hoc build for the physical A16 iPad
without using TestFlight. It does not change the selected normal public App
Store distribution route.

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
- validates that the profile matches Team ID `CV7JQ487YU`, bundle ID
  `com.chdafni.frogcityfeast`, the Apple Distribution certificate, and the
  protected iPad UDID;
- archives and exports with Xcode's `release-testing` method;
- verifies the signed app, embedded profile, application identifier, and
  registered-device membership; and
- deletes the IPA, archive, profile, certificate copy, keychain, and export
  directory after validation.

The GitHub `ad-hoc` authorization environment is configured for branch `main`,
requires reviewer `CHDAFNI-MSFT`, permits no administrator bypass, and contains
no variables or secrets. Signing values remain isolated in the separately
approved historical `testflight` environment.

No signed IPA is retained, uploaded as a GitHub artifact, or published. The
workflow is a provisioning and build validator until a separately approved
private delivery path exists.

## Inputs still required

The workflow must not run until both values exist in the protected historical
`testflight` environment:

| Secret | Required value |
|---|---|
| `IOS_AD_HOC_DEVICE_UDID` | Exact UDID of the physical A16 iPad |
| `APPLE_AD_HOC_PROVISIONING_PROFILE_BASE64` | Base64 of an unexpired Ad Hoc `.mobileprovision` containing that UDID, the production App ID, and the protected Apple Distribution certificate |

The existing `APPLE_CERTIFICATE_BASE64` and
`APPLE_CERTIFICATE_PASSWORD` secrets provide the certificate identity. The
App Store provisioning profile remains separate and is not overwritten.

Treat the UDID as a protected device identifier. Do not place it in a workflow
input, issue, commit, log, or documentation file.

## Obtain and register the UDID

When the iPad is available:

1. Connect it to the Windows computer with a trusted USB cable.
2. Open Apple's current Apple Devices app or iTunes device summary.
3. Display and copy the device identifier rather than the serial number.
4. Confirm the value has either the modern `8-16` hexadecimal form separated
   by a hyphen or the legacy 40-hexadecimal form.
5. In the Apple Developer account, open **Certificates, Identifiers &
   Profiles > Devices**, register one iPad with that exact UDID, and use a
   descriptive non-personal device name.

Device slots are limited by product family and membership year. Disabling or
removing a device may not restore the slot until the membership reset window,
so verify the UDID before registration.

The current App Manager key can manage listing metadata but does not grant the
Certificates, Identifiers & Profiles access required for device/profile
provisioning. The Account Holder or an Admin with that developer-account
permission must complete these portal steps. Do not broaden the API key to
Admin solely for this task.

## Create the Ad Hoc provisioning profile

After registering the iPad:

1. Open **Certificates, Identifiers & Profiles > Profiles**.
2. Create an **Ad Hoc** iOS distribution profile.
3. Select the explicit App ID `com.chdafni.frogcityfeast`.
4. Select the Apple Distribution certificate whose private key is already in
   the protected GitHub environment.
5. Select only the intended registered iPad.
6. Use a name such as `Frog City Feast A16 Ad Hoc`.
7. Download the `.mobileprovision` outside the repository.
8. Provide its local path for protected Base64 transfer into
   `APPLE_AD_HOC_PROVISIONING_PROFILE_BASE64`.
9. Delete the downloaded local profile after the protected workflow validates
   it.

The workflow rejects development, App Store, enterprise, expired, wildcard,
wrong-team, wrong-app, wrong-certificate, and wrong-device profiles.

## Protected workflow sequence

After the two secrets are configured:

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
