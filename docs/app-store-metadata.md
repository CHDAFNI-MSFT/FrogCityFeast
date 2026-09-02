# App Store Metadata Template

This template is for the normal public App Store release of **Frog City
Feast**. The machine-readable copy is in
[`tools/app-store-metadata.json`](../tools/app-store-metadata.json), and the
project check enforces Apple's current name, subtitle, promotional text,
description, and keyword limits.

Do not enter or publish this metadata until the release owner has supplied the
fields marked `REQUIRED_BEFORE_SUBMISSION` and explicitly authorized App Store
work.

## App identity

| Field | Value |
|---|---|
| App name | Frog City Feast |
| Bundle ID | `com.chdafni.frogcityfeast` |
| SKU | `FROGCITYFEAST-IOS-001` |
| Primary language | English (U.S.), `en-US` |
| Platform | iPadOS/iOS, iPad only |
| Distribution | Normal public App Store |
| Version | `0.1.0` |
| Copyright | `2026 Chase Dafnis` |
| Pricing | Free; no in-app purchases |
| Support URL | `https://chdafni-msft.github.io/SamuelIcecream/support/` |
| Privacy policy URL | `https://chdafni-msft.github.io/SamuelIcecream/privacy/` |
| Marketing URL | Optional; leave blank unless a maintained HTTPS page exists |

## Product-page copy

**Subtitle**

> Eat, grow, explore forever

**Promotional text**

> A mischievous frog, a storybook city, and an endless appetite. Explore
> changing districts, grow enormous, and uncover Starfall Quarter.

**Description**

> Leap into a layered storybook city where everything looks tempting.
>
> Guide a mischievous frog through streets, shops, rooftops, sewers, parks,
> and an ever-growing ring of new districts. Use a quick tongue to catch
> treats, objects, vehicles, building pieces, and cartoon pursuers. Digest
> your haul to score points and grow from a small snack hunter into an
> enormous landmark-munching frog.
>
> EXPLORE YOUR WAY
>
> - Tap to move, aim your tongue, rotate the camera, and choose when to end
>   each score run.
> - Discover enterable buildings, hidden rooms, changing weather, festivals,
>   and Starfall Quarter.
> - Fill a 49-entry Field Guide, collect story postcards, complete goals, and
>   unlock playful powers.
> - Manage swallowed finds in the Belly: digest them for points or spit them
>   safely back into the city.
> - Continue each run in a deterministic city that expands as you explore.
>
> PLAY YOUR WAY
>
> - Adjustable Master, music & ambience, and effects volume.
> - Reduce Motion and Larger Text & Controls.
> - Standard, Relaxed, and Hold Assist input timing.
> - Camera sensitivity, auto-alignment, reset, optional haptics, and a
>   left-handed HUD.
> - Replayable illustrated onboarding with color-safe cues.
>
> Frog City Feast is a single-player, offline game. It has no ads, no in-app
> purchases, no account requirement, and no data collection.

**Keywords**

> casual,adventure,eating,exploration,growth,storybook,offline,city,animals

`What's New` is not shown for the first App Store version. Write version-
specific release notes for later updates rather than adding placeholder text
to version 1.0.

## Category recommendation

- Primary category: **Games**
- Primary Games subcategory: **Casual**
- Secondary Games subcategory: **Adventure**
- Do not select the Kids category. The game is approachable and has no online
  features, but its central loop contains frequent cartoon eating, pursuit,
  damage, and destruction. The ordinary age-rating questionnaire is the
  accurate route.

## App Privacy response

Select **No, we do not collect data from this app**, producing the **No Data
Collected** product-page label.

This answer is accurate for the reviewed build:

- no account, login, backend, network request, analytics, advertising,
  tracking, third-party SDK, or in-app purchase code;
- no camera, microphone, photo library, contacts, location, Bluetooth, or push
  notification use;
- player-entered local profile names, progress, scores, audio settings, and
  accessibility settings remain in the app sandbox and are not transmitted;
- Godot's required-reason declarations cover app-container file timestamps,
  elapsed-time measurement, and disk-space checks; they do not collect data;
  and
- `privacy/tracking_enabled=false` remains pinned in the iOS export preset.

The privacy policy URL is still required even when the App Privacy answer is
No Data Collected. Publish
[`privacy-policy.md`](privacy-policy.md) only after its contact and effective-
date placeholders are complete.

Official reference:
[Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy).

## Age-rating questionnaire inputs

Apple's current system uses 4+, 9+, 13+, 16+, and 18+ ratings and calculates a
regional result from the submitted questionnaire. Enter the following answers
truthfully; do not lower an answer to make an under-13 Apple Account eligible.

| Questionnaire topic | Input | Basis |
|---|---|---|
| Parental controls or age assurance | No | The app has no gated online or social capability. |
| Unrestricted web access | No | There is no browser or external link inside the app. |
| User-generated content | No | Players cannot publish or exchange content. |
| Social media | No | There are no feeds, sharing, likes, or social discovery. |
| Messaging or chat | No | The game is offline and single-player. |
| Advertising | No | No ad network or promotional inventory is integrated. |
| In-app purchases | No | The App ID's immutable purchase capability is unused; there is no StoreKit code, product, or purchase UI. |
| Loot boxes, gambling, or contests | None | Random world generation does not award purchased or wagered items. |
| Medical or wellness topics | None | The game provides no health information or advice. |
| Profanity or crude humor | None | The authored text contains neither. |
| Alcohol, tobacco, or drug references | None | The authored content contains neither. |
| Sexual content or nudity | None | The authored content contains neither. |
| Fear or horror themes | None | Pursuit is whimsical rather than horror presentation. |
| Realistic or graphic violence | None | There is no blood, injury detail, death, or realistic violence. |
| Cartoon or fantasy violence | Frequent | Eating cartoon living targets, resisting pursuers, taking bounded damage, and destroying stylized buildings are recurring gameplay. |
| Guns or conventional weapons | None | There are no guns, blades, or realistic weapons; nets, flashlights, roadblocks, and sticky patches are non-graphic chase hazards. |
| AI assistants or chatbots | No | No generative or conversational AI runs in the app. |

Do not state a final age rating in marketing copy until App Store Connect
calculates it. The frequent cartoon/fantasy violence response may produce a
rating that prevents installation by the target under-13 Apple Account. If it
does, accept Apple's restriction; do not falsify the questionnaire or bypass
Family controls.

Official references:

- [Updated age ratings](https://developer.apple.com/news/?id=ks775ehf)
- [Age-rating values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)

## Content rights and encryption

- Content rights: **Yes, the developer owns or has the necessary rights to all
  content.** Every visual and audio asset is original and recorded in
  [`assets/README.md`](../assets/README.md).
- Non-exempt encryption: **No.**
  `ITSAppUsesNonExemptEncryption` is generated as `false`.
- Advertising identifier/tracking authorization: **Not used.**
- Sign-in, Game Center, cloud save, multiplayer, subscriptions, and in-app
  purchases: **Not used.**

## App Review notes

Use this draft after replacing bracketed release values:

> Frog City Feast is a fully offline, single-player iPad game with no login,
> account, network service, ads, analytics, or purchases. On first launch,
> enter any local profile name or use the default name, then choose Start New
> Game. The illustrated tutorial can be completed, skipped, or replayed from
> the player-selection menu. The top-bar action opens the score epilogue when
> outdoors and becomes Exit Room inside connected rooms.
>
> The frog catches and swallows stylized cartoon targets, including harmless
> living characters and pursuers, without blood, death, or injury detail.
> Player-entered profile names, progress, scores, and settings are stored only
> in the app sandbox. The App ID has Apple's immutable In-App Purchase feature,
> but this build contains no StoreKit integration, products, purchase UI, or
> paid digital content.
>
> Build version: [VERSION] ([BUILD]). Test device: iPad in landscape.

No demo account, external hardware, backend availability, or reviewer
credential is required.

## Screenshot plan

Provide 1 to 10 screenshots. The app is iPad-only and landscape-only. Capture
the current highest-resolution 13-inch iPad set at 2752 x 2064 pixels in PNG or
JPEG without transparency, then confirm the dimensions in App Store Connect
immediately before upload because Apple can revise accepted sizes.

Use final release presentation only. Do not show `--perf-overlay`, test data,
editor chrome, debug labels, signing information, or placeholder support
details.

Recommended seven-image sequence:

1. Storybook city overview with the frog, targets, landmarks, and readable HUD.
2. Tongue catch with visible accuracy and non-color feedback.
3. Large or Enormous growth during a whimsical pursuit.
4. An enterable interior or rooftop with weather or festival activity outside.
5. The Belly as its own screenshot.
6. The paginated Guide/Journal as its own screenshot.
7. Accessibility Options showing timing assistance, Reduce Motion, larger
   controls, camera assistance, haptics, and left-handed HUD support.

Visual review remains deferred until publication. Capture one final coherent
set from the authorized release build; do not create an iterative review loop.
The deterministic source, Windows command, output policy, and objective checks
are documented in
[`app-store-screenshots.md`](app-store-screenshots.md).

Official reference:
[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots).

## Availability recommendation

Select all available public storefronts except China mainland. The release
owner selected EU Digital Services Act **non-trader** status. Keep China
mainland excluded unless the release owner later obtains and verifies the
required game approval number and publishing information.
