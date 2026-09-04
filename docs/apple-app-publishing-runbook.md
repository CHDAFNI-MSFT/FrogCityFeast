# Apple App Publishing Lessons and Reusable Runbook

This runbook records the reusable lessons learned while preparing **Frog City
Feast** for the App Store. Use it before creating Apple records or release
automation for another app. It supplements, rather than replaces, Apple's
current documentation; Apple can change App Store Connect fields, API schemas,
runner requirements, accepted screenshot sizes, and review rules.

The most important rule is to separate preparation, metadata changes, build
upload, App Review submission, and public release. Success at one stage never
authorizes or proves the next stage.

## Lessons that prevented or explained real failures

| Lesson | What happened | Rule for the next app |
|---|---|---|
| Authentication does not prove write permission | A Developer-role API key authenticated, read the app, and uploaded builds, but the first category write failed with `403 FORBIDDEN_ERROR`. | Confirm the key role in App Store Connect before storing it. Use App Manager-equivalent access for listing metadata; do not grant Admin solely for metadata. |
| The downloaded API schema is not the final authority | Apple's schema advertised `primaryLocale` and `contentRightsDeclaration` as update attributes, but the live service rejected both with `409 ENTITY_ERROR.ATTRIBUTE.NOT_ALLOWED`. | Treat the live API as authoritative. Remove rejected writes, record the behavior, and confirm those fields directly in App Store Connect. |
| A new app can already have an initial version | The sync searched only for `0.1.0`, found none, and attempted to create it. Apple rejected the request because the app already had its initial editable version. | Enumerate all versions for the platform before any write. Reuse and rename the single editable initial version instead of blindly creating another one. |
| `What's New` is not an initial-release field | Apple rejected a first-version localization update when the empty field was sent as `null`. | Omit `whatsNew` for any version with no released predecessor. Send it only from a separately reviewed update workflow after an earlier version is released. |
| Metadata writes can partially succeed | Categories and app-information localization were accepted before a later version operation failed. | Complete every possible read-only preflight before the first write, make writes idempotent, and report exactly which resources were applied if a later operation fails. |
| Upload is not submission or release | A signed candidate uploaded successfully but was never selected for a version, submitted, or released. Later gameplay work made it obsolete. | Record the exact source commit and treat upload, build selection, submission, and release as separate authorization gates. Never submit a superseded candidate. |
| The public App Store is not a beta channel | Apple does not provide a public App Store "beta" badge or early-access state for unfinished apps. | Use TestFlight for eligible beta testers, or a separately protected Ad Hoc path for registered devices. Submit only a complete app to the App Store. |
| Unlisted does not mean private or beta | An unlisted app still requires App Review, and anyone with its direct link can install it where available. | Choose unlisted distribution only for a finished app whose discoverability should be limited. Do not use it as access control. |
| TestFlight has an age restriction | The intended under-13 Apple Account cannot accept the TestFlight terms. | Decide the tester and account eligibility before building a TestFlight-only plan. Do not falsify age or bypass Apple restrictions. |
| Repository renames do not preserve Pages URLs | The old GitHub repository URL redirected, but the old GitHub Pages path returned `404`. | After any rename, update and verify support, privacy, marketing, Issue-form, metadata, and workflow URLs before submission. |
| Godot import and iOS icon generation are different steps | Godot imports the source icon, while the iOS export generates the platform AppIcon catalog. | Keep a committed 1024-by-1024 full-bleed source icon, validate its import, and inspect the generated AppIcon catalog during iOS export. |
| Generated screenshots must identify their source | Store screenshots can silently become stale after later release changes. | Generate them from a clean exact commit, record dimensions and hashes, and regenerate after the final publication commit. |
| An unsigned build is not device acceptance | The generic-device Xcode compile proved the export pipeline but not signing, installation, frame rate, thermals, touch behavior, or safe areas. | Require a signed physical-device acceptance pass before submission. Clearly mark measurements that still require hardware. |
| Provisioning creates have no idempotency key | A device or profile POST can complete even when the client receives a conflict or network failure. | Query first, POST at most once, then use bounded exact re-reads. Never blindly retry, patch, delete, disable, re-enable, or replace an ambiguous resource. |
| App pricing resources are sparse and partly unreadable | The live service returned embedded `appPrices` without relationships, rejected the documented related-price route with `404`, and rejected the advertised price `self` URL with `403`. The opaque Apple-issued price identity contained the schedule, territory, and price-point identity needed to use the supported v3 price-point read. | Validate the schedule linkage, decode only canonical Apple base64url price identities, bind them to the exact schedule, derive the price-point identity, and verify `customerPrice` through `/v3/appPricePoints/{id}`. Never infer free pricing from the existence of a schedule alone. |
| Availability relationships require an explicit include | Requesting `territory` as a sparse field did not populate the relationship data, so otherwise valid territory availability records failed closed. | Use `include=territory`, compare the result with the complete `/v1/territories` catalog, and reject missing, duplicate, unknown, transitional, restricted, or empty non-China content statuses. |
| Storefront selection does not complete DSA compliance | The app was configured for every current storefront except China mainland, but Apple reported `TRADER_STATUS_NOT_PROVIDED` and `CANNOT_SELL`. | The Account Holder or Admin must complete the account-level EU Digital Services Act trader declaration under **Business > Agreements > Compliance**, then confirm the app-specific selection under **App Information > App Store Regulations and Permits**. Do not guess the legal status or automate it from repository metadata. |

## 1. Decide distribution before creating workflows

Record one primary route before creating signing profiles or release
automation:

| Route | Appropriate use | Important limitation |
|---|---|---|
| TestFlight | Beta testing by eligible internal or external testers | TestFlight users must satisfy Apple's minimum-age terms. A TestFlight build is not a public App Store release. |
| Ad Hoc | Private testing on a small set of registered device UDIDs | Requires an Ad Hoc profile and device registration. Apple limits registered devices by product family and membership year. Removing a device does not necessarily restore the annual slot. |
| Normal public App Store | A complete app intended to be searchable and publicly available | Requires complete metadata, App Review, accurate privacy and rating answers, and an explicit release decision. |
| Unlisted App Store | A complete reviewed app distributed by direct link rather than App Store discovery | Anyone with the link can share or install it where available. It is not private, access-controlled, or a beta channel. |
| Custom App | Private organizational distribution through Apple Business Manager or Apple School Manager | Intended for specific organizations, not ordinary family or consumer testing. |

For a child tester, verify both TestFlight eligibility and the likely App Store
age rating at the start. An ordinary App Store installation may still be
restricted by Apple's calculated rating and Family settings. Never change
truthful content answers to make an account eligible.

If Ad Hoc over-the-air installation would require a paid host or new cloud
infrastructure, obtain explicit approval before creating or deploying it.

Official references:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [TestFlight terms](https://www.apple.com/legal/internet-services/itunes/testflight/)
- [Unlisted app distribution](https://developer.apple.com/support/unlisted-app-distribution/)
- [Devices overview](https://developer.apple.com/help/account/devices/devices-overview)

## 2. Freeze the app identity before Apple setup

Confirm and record all of these values:

- App Store name.
- File-safe product and Xcode scheme name.
- Production bundle identifier.
- SKU.
- Primary locale.
- Supported Apple device families and orientations.
- Initial marketing version.
- Copyright owner and year.
- Distribution route.
- Free or paid pricing and any in-app-purchase intent.

Treat the production bundle identifier and SKU as permanent identities. Do not
reuse another app's identifier, provisioning profile, metadata, or screenshots.
Keep the Godot display name, App Store record, export preset, generated Xcode
project, and workflow variables synchronized.

Apple may create an initial editable App Store version as part of app-record
setup. Record the version shown in App Store Connect instead of assuming that
no version exists.

## 3. Use clear, separate protected environments

For a new repository, prefer purpose-based names instead of reusing a
historical environment name:

| Suggested environment | Purpose |
|---|---|
| `app-store-metadata` | App Manager API credentials used only for listing metadata |
| `app-store-upload` | Approval for one exact candidate upload |
| `app-store-signing` | Distribution certificate, password, provisioning profile, and upload API credentials |
| `ad-hoc-authorization` | Approval for a registered-device validation build |
| `ad-hoc-signing` | Distribution certificate, exactly scoped device UDIDs, and a separate provisioning key when API reconciliation is approved |
| `app-store-release` | Submission and release authorization, if automated later |

Restrict each environment to the intended release branch, require an
appropriate reviewer, and disable administrator bypass. If repository plan or
visibility does not support the intended protection, keep the workflow
disabled rather than silently weakening it.

Keep these identifiers as protected environment variables:

- Apple Team ID.
- Production bundle identifier.

Keep these values only as protected environment secrets:

- Distribution certificate encoded from its `.p12`.
- Certificate export password.
- App-specific App Store provisioning profile when the normal signing path
  consumes a pre-created profile secret. An API-created Ad Hoc profile should
  remain an ephemeral runner file instead.
- Registered-device UDIDs when that route is selected.
- A separately named Admin Team API Key ID and Base64 private key only when
  automated device/profile provisioning is explicitly approved. Reuse the
  existing issuer but do not replace App Manager metadata credentials.
- App Store Connect API Key ID.
- App Store Connect API Issuer ID.
- App Store Connect API `.p8` private key encoded as Base64.

An App Store Connect `.p8` file is downloadable only once. Store it directly in
the protected environment, never print it, never pass its value on a command
line, and never commit it. Update the Key ID and private key together. Confirm
the issuer belongs to the same App Store Connect team. Revoke obsolete keys and
delete local copies after the protected replacement is verified.

Use the least role that performs the operation:

- Developer access can authenticate and may upload builds, but it did not have
  permission to update this app's listing metadata.
- App Manager access performed the accepted metadata writes.
- Admin access is unnecessary solely to enter metadata. If Certificates,
  Identifiers & Profiles automation needs Admin access, isolate that key to the
  provisioning step and retain it only when the owner explicitly requests it.

Do not infer role sufficiency from JWT creation, authentication, read-only
preflight, or a successful build upload.

Apple API 4.4.1 exposes `Certificate.attributes.activated` as an optional
response field, but Apple documents its activation semantics for Payment
Processing certificates rather than `DISTRIBUTION` certificates. Ignore the
field when resolving an Apple Distribution certificate: neither `true`,
`false`, nor omission proves profile eligibility or revocation. Continue to
require exact DER fingerprint, serial, Team ID, subject, type, and expiration
agreement. Treat successful profile creation plus independent validation of
the downloaded profile as the authoritative eligibility result.

After `security cms` decodes a provisioning profile, do not use
`plutil -convert json`: profile dates and certificate data have no direct JSON
representation and can make that conversion fail. Parse the plist with a
property-list library, normalize dates to UTC strings and data to Base64, then
perform the API UUID, expiration, certificate, bundle, and device-set checks.

## 4. Preflight the complete App Store state before writing

A metadata workflow should read and validate all required resources before its
first mutation:

1. Resolve exactly one app by production bundle identifier.
2. Resolve exactly one editable app-info record.
3. Enumerate all App Store versions for the target platform.
4. Validate the age-rating declaration exists.
5. Resolve existing localizations and category identifiers.
6. Validate requested metadata against committed approved values.
7. Refuse any request that includes build selection, submission, or release.

For an initial release, version selection must fail closed:

1. If no platform version exists, create the approved initial version.
2. If exactly one platform version exists, require:
   - resource type `appStoreVersions`;
   - a nonempty resource ID;
   - the expected platform;
   - a version string containing one to three numeric components;
   - an editable state such as `PREPARE_FOR_SUBMISSION`.
3. Reuse that single editable version. If Apple created it as `1.0` but the
   approved app and build use `0.1.0`, update its `versionString` before
   applying the remaining version fields.
4. If multiple versions exist during an initial-release workflow, stop. Do not
   guess which version is safe.
5. If the only version is noneditable, stop. Never repurpose a submitted or
   released version.

Do not query only for the desired version and conclude that a new version can
be created when the filtered result is empty.

## 5. Separate API-managed and directly confirmed metadata

The Frog City Feast runs directly confirmed that the protected API workflow
can manage:

- app name, subtitle, and privacy-policy URL localization;
- description, keywords, promotional text, support URL, and marketing URL in
  the version localization;
- Games category and subcategories;
- copyright and manual-release mode; and
- the editable App Store version string; and
- age-rating declaration answers.

For the first App Store version, validate that the committed `whats_new` value
is empty and omit `whatsNew` from the request rather than sending an empty
string or `null`. A future update workflow may add the field only after an
earlier version is released and the new release notes are nonempty.

The following remained direct-confirmation items because they were absent from
the usable API surface or rejected by the live service:

- primary locale;
- content-rights declaration;
- App Privacy questionnaire;
- price;
- storefront availability;
- EU Digital Services Act trader status;
- screenshots;
- App Review contact;
- build selection;
- App Review submission; and
- public release.

Recheck the current Apple specification for every new app, but do not assume a
documented update attribute will be accepted by the live API. When Apple
returns `ATTRIBUTE.NOT_ALLOWED`, stop retrying that write and move the field to
the directly confirmed list.

## 6. Make metadata writes recoverable

The metadata client must:

- validate all committed field values before network access;
- run read-only state preflight before writes;
- use idempotent `PATCH` operations where possible;
- create a resource only when the complete version set proves none exists;
- report every successfully applied resource if a later operation fails;
- distinguish attempted, failed, applied, and unattempted resources;
- surface Apple's status, error code, title, and detail without exposing
  credentials;
- avoid broad catches, silent defaults, or success-shaped fallbacks; and
- remain incapable of build selection, submission, and release.

After any partial failure:

1. Record the run, error, and accepted resource types.
2. Inspect current App Store state before editing the client.
3. Fix the root cause and add a regression test.
4. Confirm the accepted operations are idempotent.
5. Rerun the complete protected workflow rather than manually guessing which
   API steps remain.
6. Verify the resulting values in App Store Connect.

Useful failure interpretations:

| Response | Likely cause | Required response |
|---|---|---|
| `403 FORBIDDEN_ERROR` on the first write | API key role lacks metadata permission | Replace it with an App Manager-equivalent key; do not escalate to Admin without another need. |
| `409 ... ATTRIBUTE.NOT_ALLOWED` | Live API does not permit that advertised update | Remove the write and confirm the field directly. |
| `409 ... RELATIONSHIP.INVALID` while creating a version | Another initial or editable version already exists | Enumerate all platform versions and safely reuse the single editable initial version. |
| `409 STATE_ERROR` for `whatsNew` on the first version | The target version has no released predecessor | Omit the attribute entirely. Add it only in a separately reviewed update workflow after an earlier version is released. |
| Partial-failure report | Earlier idempotent writes succeeded | Record applied resources, fix the later operation, and rerun after full preflight. |

## 7. Prepare icon and screenshots as release inputs

For Godot iOS apps:

- Commit an original 1024-by-1024 square, full-bleed icon source.
- Keep the rendered icon fully opaque, text-free, and free of external
  references.
- Do not add rounded corners; Apple applies the platform mask.
- Run Godot import to validate source-side metadata.
- Generate and inspect the AppIcon catalog during iOS export.
- Record source, authorship, license, and reproduction steps.

For screenshots:

- Generate only from a clean exact publication commit.
- Use Apple's currently accepted dimensions, orientation, format, and opacity.
- Keep debug overlays, editor chrome, signing data, and private player data out.
- Record the source commit, image dimensions, color mode, opacity, and hashes.
- Keep reproducible release derivatives out of Git when source code can
  regenerate them deterministically.
- Review the final set once at publication rather than creating an endless
  visual-review loop.

Any later commit intended to become the publication source requires a fresh
package if exact-commit provenance is part of the release process.

## 8. Prove the build in increasing-risk stages

Use this order:

1. Run local project import, startup, tests, and production checks.
2. Run ordinary Linux CI on the exact commit.
3. Run a credential-free macOS Godot export and unsigned generic-device Xcode
   compile.
4. If TestFlight is unavailable, register the exact approved devices and
   create an exact-membership Ad Hoc profile manually or through separately
   approved fail-closed API automation, then validate a signed
   `release-testing` export without publishing it.
5. Deliver the Ad Hoc package only through a separately approved private
   route, then run the physical-device acceptance plan.
6. Obtain explicit authorization for one exact candidate upload.
7. Upload without publishing a signed IPA or archive as a GitHub artifact.
8. Wait for Apple processing and inspect symbols, icon, privacy manifest,
   encryption declaration, supported devices, version, and build number.

The physical-device pass should cover:

- sustained frame rate, frame time, GPU time, memory, thermals, and battery
  behavior under documented stress scenarios;
- landscape safe areas, touch targets, gestures, and interruption recovery;
- audio balance, independent volume controls, haptics, and mute behavior;
- text size, contrast, Reduce Motion, larger controls, and readable
  non-color-only feedback;
- cold launch, background and foreground transitions, low-storage save errors,
  reinstall behavior, and local-data deletion; and
- the deferred final visual review.

Do not treat a desktop playtest, simulator run, unsigned compile, or uploaded
candidate as a substitute for target-device acceptance.

For an Ad Hoc route, keep every UDID and downloaded profile protected, reject
profiles that do not contain the exact approved device set, and delete the IPA
after validation unless a private delivery mechanism has been explicitly
approved. API automation should resolve exactly one existing bundle and
certificate, use a deterministic profile name without raw UDIDs, create each
missing resource only once, validate CMS/plist content, and pass only a
constrained temporary profile path to signing. Public artifacts and public
GitHub Pages are not private distribution. Obtain explicit approval before
creating paid HTTPS hosting or other cloud infrastructure.

## 9. Preserve four separate authorization gates

1. **Metadata authorization** permits only the reviewed listing mutations.
2. **Upload authorization** identifies one exact commit, version, and workflow
   invocation that may upload a candidate.
3. **Submission authorization** permits selecting the processed build and
   sending the complete version to App Review.
4. **Release authorization** permits publishing an approved version.

Use manual release so App Review approval cannot publish the app automatically.
Do not infer submission or release authorization from an earlier approval.
Tags and GitHub releases also require their own authorization when the owner
has not bundled that action into the release decision.

## 10. Ordered checklist for the next app

- [ ] Decide TestFlight, Ad Hoc, public, unlisted, or Custom App distribution.
- [ ] Verify tester age/account eligibility and expected age-rating impact.
- [ ] Confirm name, bundle ID, SKU, locale, device family, orientation, and
      initial version.
- [ ] Create the explicit App ID without unnecessary capabilities.
- [ ] Create the App Store Connect app record and record its initial version.
- [ ] Complete agreements, tax/banking requirements when applicable, and MFA.
- [ ] Create purpose-specific protected GitHub environments.
- [ ] Create the least-privilege App Manager metadata key.
- [ ] Create or select the distribution certificate and app-specific profile.
- [ ] Store secrets directly in protected environments; retain no repository
      or workflow copy.
- [ ] Publish and verify support and privacy URLs.
- [ ] Prepare metadata, truthful privacy answers, age-rating inputs, review
      notes, pricing, storefronts, DSA status, and contact information.
- [ ] Implement read-only API preflight for app info, all platform versions,
      localizations, and rating resources.
- [ ] Add regression tests for zero, one editable, exact-match, noneditable,
      malformed, wrong-platform, and multiple-version responses.
- [ ] Run the protected metadata workflow and inspect partial-write reporting.
- [ ] Confirm API-excluded and live-API-rejected fields directly.
- [ ] Finalize the original opaque icon and verify exported AppIcon assets.
- [ ] Generate exact-commit screenshots and record their hashes.
- [ ] Run local checks, Linux CI, and unsigned macOS iOS build on the exact
      release commit.
- [ ] If using Ad Hoc, register the exact approved devices, create or reconcile
      the exact-membership profile, and run protected signing validation
      without publishing the IPA. Do not require a manual profile download
      when protected API provisioning is already configured.
- [ ] Obtain separate approval before creating private Ad Hoc hosting or
      retaining a signed package for delivery.
- [ ] Complete signed physical-device and final visual acceptance.
- [ ] Obtain exact upload authorization and upload one candidate.
- [ ] Inspect the processed build and complete all listing fields.
- [ ] Obtain separate App Review submission authorization.
- [ ] Resolve review questions truthfully without weakening privacy, age, or
      content declarations.
- [ ] Obtain separate manual public-release authorization.
- [ ] Record the released commit, version, build, product URL, date, and
      storefront exclusions.

## Frog City Feast evidence

These runs document the concrete failures behind this runbook:

- `33615963132`: authentication succeeded; live API rejected advertised app
  update attributes with `409`.
- `33616496541`: read-only preflight succeeded; a Developer-role key was denied
  on the first category write with `403`; no metadata changed.
- `33648261223`: an App Manager key applied categories and app-information
  localization, then version creation failed with `409` because the initial
  version already existed.
- `33653860478`: the corrected version logic reused and updated the initial
  version, then Apple rejected `whatsNew: null` for the first release.
- `33661855538`: the hardened preflight and first-release payload completed
  successfully, including version localization and age-rating answers.
- `33576432175`: candidate upload succeeded, but later changes superseded its
  source commit before submission.
- `33823901657`: the replacement candidate passed build processing, selection,
  export compliance, screenshots, App Review contact, content rights, age
  rating, free pricing, and the complete territory catalog. Submission remained
  blocked only because the Apple account had not completed its EU DSA trader
  declaration; the app remained on manual release and was not submitted.
- `33825382288`: after the Account Holder declared non-trader status, Apple no
  longer returned `TRADER_STATUS_NOT_PROVIDED`; all selected storefronts still
  returned the generic `CANNOT_SELL` status.
- `33826716016`: the exact review-submission workflow revalidated and
  regenerated the candidate package, but Apple again rejected adding version
  `0.1.0` to the review draft with generic
  `409 STATE_ERROR.ENTITY_STATE_INVALID` and no associated errors. With all
  API-visible listing prerequisites and DSA complete, confirm that the App
  Privacy answers were explicitly **published**, not only saved, before
  escalating the opaque rejection to Apple Developer Support.
- `33827587415`: after the owner confirmed the no-data App Privacy response was
  explicitly published, the exact protected submission produced the identical
  generic `409` with no associated errors. At this point, use the App Store
  Connect web UI's **Add for Review** validation to obtain the missing field or
  account prerequisite. If the UI also withholds details, contact Apple
  Developer Support with the app version, build, timestamp, and run ID. Do not
  upload a replacement build merely to work around an unexplained backend
  state.

For the current app's exact values and live release state, use
[`app-store-metadata.md`](app-store-metadata.md),
[`ios-release.md`](ios-release.md), and
[`app-store-release-checklist.md`](app-store-release-checklist.md).
