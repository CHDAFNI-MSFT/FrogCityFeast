# Public App Store Release Checklist

This checklist prepares a normal public App Store release. It does not authorize
upload, submission, approval, publication, a Git tag, a GitHub release, or use
of signing secrets.

## Current reversible preparation

- [x] Godot 4.7.2 and the pinned Apple toolchain are documented.
- [x] The credential-free iOS export and generic-device compile path exists.
- [x] The public workflow is manual-only, main-only, and uses the dedicated
  `app-store` environment.
- [x] The public export omits `testFlightInternalTestingOnly`.
- [x] The workflow uploads no signed IPA, archive, certificate, profile, or key
  as a GitHub artifact.
- [x] Metadata copy, category recommendations, privacy answers, age-rating
  inputs, App Review notes, screenshot plan, support copy, and privacy policy
  templates are versioned.
- [x] TestFlight is documented as unavailable for the target under-13 Apple
  Account and is not the selected installation path.

## Required owner-supplied listing fields

- [ ] Replace every `REQUIRED_BEFORE_SUBMISSION` value in
  `tools/app-store-metadata.json`, `docs/privacy-policy.md`, and
  `docs/app-support.md`.
- [ ] Provide a maintained HTTPS support URL with reachable contact
  information.
- [ ] Provide a maintained HTTPS privacy policy URL.
- [ ] Confirm copyright owner and year.
- [ ] Choose free or paid-upfront pricing. Do not add in-app purchases without
  a separately reviewed product and privacy change.
- [ ] Select public storefronts. Exclude China mainland unless the required
  game approval and publishing information are complete.
- [ ] Complete any applicable EU Digital Services Act trader-status
  declaration and other regional compliance fields.

## Final build and device acceptance

- [ ] Complete Windows validation on the exact release commit.
- [ ] Complete Godot CI on the exact release commit.
- [ ] Manually run the unsigned iOS smoke build on the exact release commit.
- [ ] Physical A16 iPad acceptance: signed Release build sustains at least
  58 FPS over 30 seconds, targets 60 FPS, and meets the documented frame,
  process, physics, memory, draw, object, and primitive budgets.
- [ ] Capture GPU frame time and thermal behavior with Xcode/Metal tools.
- [ ] Perform the deferred final visual review on the publication build.
- [ ] Perform target-device audio mix, haptics, safe-area, touch-target,
  readability, Reduce Motion, and larger-controls checks.
- [ ] Confirm cold launch, background/foreground, interruption recovery,
  low-storage save warning, reinstall, and local-data deletion behavior.

## App Store Connect listing

- [ ] Copy the validated `en-US` fields from
  `tools/app-store-metadata.json`.
- [ ] Set Games > Casual with Adventure as the secondary Games subcategory.
- [ ] Confirm content rights using the repository asset provenance ledgers.
- [ ] Answer App Privacy with **No, we do not collect data from this app**.
- [ ] Enter the live privacy policy URL.
- [ ] Complete the current age-rating questionnaire with the inputs in
  `docs/app-store-metadata.md`, including **Frequent** cartoon or fantasy
  violence.
- [ ] Accept Apple's calculated regional rating. Do not lower answers or bypass
  restrictions if the under-13 Apple Account cannot install it.
- [ ] Confirm non-exempt encryption is **No**.
- [ ] Confirm no ads, tracking, account, Game Center, cloud save, StoreKit
  products, subscriptions, or purchases are declared.
- [ ] Enter current App Review contact information in international format
  where required.
- [ ] Add the App Review notes from `docs/app-store-metadata.md`.
- [ ] Upload 1 to 10 final iPad landscape screenshots without debug overlays
  or placeholders and verify their dimensions in App Store Connect.
- [ ] Choose **Manually release this version** so approval cannot publish the
  app automatically.

## Protected GitHub environment

- [ ] Confirm the `app-store` environment still allows only branch `main`.
- [ ] Confirm `CHDAFNI-MSFT` remains the required reviewer.
- [ ] Confirm the environment variables are the reviewed Team ID and bundle
  ID.
- [ ] Only after Explicit upload authorization, configure or copy the six
  signing and App Store Connect secrets into the `app-store` environment.
- [ ] Confirm no signing value exists at repository scope or in a workflow,
  log, artifact, issue, pull request, commit, or local repository file.

## Separate authorization gates

- [ ] **Explicit upload authorization:** authorize one exact commit, version,
  and workflow run to upload a normal App Store candidate to App Store Connect.
- [ ] Approve the protected `app-store` environment deployment and set the
  workflow's `confirm_upload` input.
- [ ] Confirm the workflow completed cleanup and produced no downloadable
  signed artifact.
- [ ] Wait for Apple processing and inspect export compliance, symbols, icon,
  privacy manifest, supported devices, and build metadata.
- [ ] **Explicit submission authorization:** authorize selection of the
  processed build and submission to App Review. Upload authorization alone is
  not submission authorization.
- [ ] Resolve only accurate App Review questions; do not change age, privacy,
  content, or account answers to evade a restriction.
- [ ] **Explicit release authorization:** after approval, authorize manual
  public release. Submission authorization alone is not release authorization.
- [ ] Create a Git tag or GitHub release only under separate explicit
  authorization.

## Post-release

- [ ] Confirm the public product page, screenshots, privacy label, age rating,
  support link, and privacy link are correct.
- [ ] Confirm installation on an eligible iPad through the normal App Store.
- [ ] Verify the target under-13 Apple Account only if Apple's assigned rating
  and Family settings permit installation; do not bypass Apple restrictions.
- [ ] Record the released commit, version, build number, App Store URL, release
  date, and any approved storefront exclusions.
- [ ] Monitor support and crash information available through Apple without
  adding in-app analytics or tracking.

