# Public App Store Release Checklist

This checklist prepares a normal public App Store release. It does not authorize
upload, submission, approval, publication, a Git tag, a GitHub release, or use
of signing secrets.

## Current reversible preparation

- [x] Godot 4.7.2 and the pinned Apple toolchain are documented.
- [x] The credential-free iOS export and generic-device compile path exists.
- [x] The public workflow is manual-only and main-only, with separate
  `app-store` authorization and `testflight` signing approvals.
- [x] The public export omits `testFlightInternalTestingOnly`.
- [x] The workflow uploads no signed IPA, archive, certificate, profile, or key
  as a GitHub artifact.
- [x] Metadata copy, category recommendations, privacy answers, age-rating
  inputs, App Review notes, screenshot plan, support copy, and privacy policy
  templates are versioned.
- [x] A deterministic seven-image 13-inch iPad screenshot harness, manifest,
  Windows generator, and opaque-image validation are versioned.
- [x] TestFlight is documented as unavailable for the target under-13 Apple
  Account and is not the selected installation path.
- [x] A separate Ad Hoc validation path is prepared for the three registered
  iPads. Its default mode publishes no signed artifact.
- [x] Create the separately authorized private Azure OTA path with a
  resource-only governance exclusion, private container, revocable upload and
  read policies, explicit workflow confirmation, anonymous-access rejection,
  incomplete-upload rollback, and no GitHub artifact publication.
- [x] Store the three supplied iPad identifiers as separate masked secrets in
  the protected signing environment without recording their values in Git.
- [x] Configure the separate Admin Team API key for protected provisioning
  only, retain it for future provisioning per owner request, and keep the App
  Manager metadata secrets unchanged.
- [x] Automate exact device/profile reconciliation so no manually downloaded
  Ad Hoc profile or profile secret is required.

## Uploaded candidate record

- Version: `0.1.0`
- Build: `33576432175.1`
- Source commit: `646011df800dc35aaed98d1ba8e8f775430341d8`
- Workflow run:
  [iOS App Store candidate upload 33576432175](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33576432175)
- Upload completed: September 1, 2026 at 20:46 EDT
- App Store Connect status at workflow completion: package uploaded and
  processing.
- Signing material cleanup completed and verified.
- The build was not selected for a version, submitted for App Review, or
  released.
- This candidate is superseded by later gameplay and release-preparation
  changes and must not be submitted.

## Required owner-supplied listing fields

- [x] Replace every `REQUIRED_BEFORE_SUBMISSION` value in
  `tools/app-store-metadata.json`, `docs/privacy-policy.md`, and
  `docs/app-support.md`.
- [x] Verify the renamed HTTPS support URL and public GitHub Issue contact
  form at `FrogCityFeast`.
- [x] Verify the renamed HTTPS privacy policy URL and public privacy-question
  form at `FrogCityFeast`.
- [x] Confirm copyright owner and year: `2026 Chase Dafnis`.
- [x] Choose free pricing with no in-app purchases. Do not add in-app
  purchases without
  a separately reviewed product and privacy change.
- [x] Select all available storefronts except China mainland.
- [x] Record the owner-selected EU Digital Services Act status as non-trader.
  App Store Connect may still require the Account Holder to complete or
  confirm the declaration.

## Final build and device acceptance

- [x] Complete Windows validation on source commit
  `2e4f60160db67f6715844aac234d6a47e4e40843`.
- [x] Complete Godot CI on that source commit: run `33662838762`.
- [x] Manually run the unsigned iOS smoke build on that source commit: run
  `33664214769`.
- [x] Let the protected Ad Hoc workflow register only missing exact iPad
  records and create or reuse one matching profile containing exactly the
  three configured devices as documented in `docs/ios-ad-hoc-testing.md`.
  Run `33703681354` reused all three device records and the exact profile.
- [x] Run the protected Ad Hoc validation workflow without retaining a signed
  IPA. Run `33703681354`, build `33703681354.1`, completed signing, export,
  embedded-profile validation, and verified cleanup.
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

- [x] Run the protected `App Store metadata sync` workflow for the exact
  reviewed commit and confirm the API-supported product-page, category,
  manual-release, copyright, and age-rating values. Run
  [33661855538](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33661855538)
  completed successfully from commit `6202d2833a69a60cfe15d19cf000bc5b30b18d6c`.
- [x] Replace the protected Developer-role App Store Connect API key with an
  App Manager-equivalent key before retrying metadata synchronization. Run
  [33616496541](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33616496541)
  completed authenticated read-only preflight but Apple denied the first
  category write with `403 FORBIDDEN_ERROR`; no metadata was changed.
- [x] Complete a protected metadata rerun after the first-release `whatsNew`
  payload fix. Runs
  [33648261223](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33648261223)
  and
  [33653860478](https://github.com/CHDAFNI-MSFT/FrogCityFeast/actions/runs/33653860478)
  applied the Games categories, app-information localization, and editable
  version `0.1.0`; run `33661855538` then completed version-localization and
  age-rating updates.
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
- [ ] Re-run the approved automated final iPad landscape screenshot set from
  the exact publication build using
  `scripts\generate-app-store-screenshots.ps1`, perform the deferred visual
  review, upload its seven images without debug overlays or placeholders, and
  verify their dimensions in App Store Connect.
- [ ] Choose **Manually release this version** so approval cannot publish the
  app automatically.

## Protected GitHub environment

- [ ] Confirm the `app-store` environment still allows only branch `main`.
- [x] Confirm the `ad-hoc` environment allows only branch `main`, requires
  `CHDAFNI-MSFT`, permits no administrator bypass, and contains no secrets.
- [ ] Confirm `CHDAFNI-MSFT` remains the required reviewer.
- [ ] Confirm administrators cannot bypass the `app-store` or `testflight`
  protection rules.
- [ ] Confirm the environment variables are the reviewed Team ID and bundle
  ID.
- [ ] Confirm the protected `testflight` environment retains the six validated
  signing and App Store Connect secrets and requires its own approval.
- [ ] Confirm the three device secrets and separate
  `APPLE_PROVISIONING_KEY_ID` /
  `APPLE_PROVISIONING_PRIVATE_KEY_BASE64` Admin credentials remain configured,
  are used only by the provisioning step, and require the same protected
  approval.
- [ ] Confirm the public workflow consumes those secrets in place and that the
  `app-store` environment contains no signing secrets.
- [ ] Confirm no signing value exists at repository scope or in a workflow,
  log, artifact, issue, pull request, commit, or local repository file.

## Separate authorization gates

- [x] **Explicit upload authorization:** version `0.1.0` from exact source
  commit `2e4f60160db67f6715844aac234d6a47e4e40843` was authorized for candidate
  workflow run `33664620876`.
- [ ] Set the workflow's `confirm_upload` input, approve the protected
  `app-store` authorization job, and separately approve the protected
  `testflight` signing job. Run `33664620876` remains at its first protected
  approval and has not uploaded a replacement candidate.
- [ ] Confirm the replacement workflow completed cleanup and produced no
  downloadable signed artifact.
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
