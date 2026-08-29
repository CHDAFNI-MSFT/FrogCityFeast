# Game Stack Decision Guide

This guide selects a game-development stack based on the type of game,
development workflow, and platform requirements. It is intended to be reused
for SamuelIcecream and future personal game projects.

## Current priorities

- Produce a polished, high-quality game.
- Perform normal development and testing on Windows.
- Use cloud-hosted macOS only when Apple tooling is required.
- Target iOS without depending on revenue from the game.
- Prefer free tools without royalties, subscriptions, or license activation.

## Default recommendation

Use **Godot 4 with GDScript** for both common 2D categories:

1. Scene-based, point-and-click, puzzle, or narrative games.
2. Action, platformer, arcade, or physics-based games.

The recommended engine and language are the same for both categories. The
project architecture and Godot features differ, but the development toolchain
does not.

### Scene-based 2D games

Emphasize:

- `Node2D` and `Control` scene composition.
- AnimationPlayer-driven transitions and interactions.
- Data-driven dialogue, inventory, puzzles, and scene state.
- Resolution-independent UI and multiple iPhone/iPad aspect ratios.
- Audio mixing, ambience, and scripted events.

### Action-oriented 2D games

Emphasize:

- `CharacterBody2D`, collision layers, and deterministic movement.
- Input buffering and configurable touch controls.
- Tile maps, animation state machines, particles, and shaders.
- Frame-time profiling, object reuse, and mobile performance budgets.
- Repeatable gameplay tests for movement, scoring, and progression.

## Why Godot is the 2D default

- The complete editor and gameplay debugger run locally on Windows.
- Its 2D renderer, scene system, animation tools, physics, audio, particles,
  shaders, and UI system can support production-quality 2D games.
- GDScript has a fast edit-test cycle and integrates directly with the engine.
- Godot is open source under the MIT license, with no royalties, revenue cap,
  subscription, or CI license activation.
- Projects are relatively small and Git-friendly compared with heavier engines.
- iOS-specific work can be isolated to export, signing, device testing, and
  TestFlight distribution.

Quality will depend more on art direction, animation, sound, controls, frame
pacing, testing, and polish than on choosing between capable 2D engines.

## Decision tree

```text
Is the project primarily a game?
|
+-- No; it is mostly app screens with small minigames
|   `-- Consider Flutter + Flame
|
`-- Yes
    |
    +-- Is it primarily 2D?
    |   `-- Use Godot 4 + GDScript
    |
    `-- Is it substantially 3D?
        |
        +-- Does it require a large asset/plugin ecosystem,
        |   advanced commercial tooling, or Unity-specific assets?
        |   `-- Use Unity + C#
        |
        `-- Is a lightweight open-source stack more important?
            `-- Prototype in Godot 4 and validate performance first

Does the game require unusually deep Apple-only integration?
|
+-- No
|   `-- Keep the engine selected above
|
`-- Yes; Apple-native UI and platform APIs dominate the project
    `-- Consider Swift + SpriteKit/SwiftUI
```

## Alternatives

### Unity with C#

Choose Unity when a project is substantially 3D or depends on its mature asset
store, plugins, profiling tools, or established production workflows.

Advantages:

- Mature 2D and 3D tooling.
- Large asset, plugin, learning, and hiring ecosystem.
- Full Windows editor and C# development workflow.

Tradeoffs:

- Larger editor, project, build, and CI footprint.
- Proprietary licensing and eligibility terms.
- Automated builds require license activation and management.
- iOS export generates an Xcode project that must then be built on macOS.

### Flutter with Flame

Choose Flutter and Flame when the product is mainly an application with menus,
forms, content, and small 2D game elements.

Advantages:

- Free and open source.
- Excellent app-style UI and rapid iteration.
- Most Dart development and testing can run on Windows.

Tradeoffs:

- Smaller game-specific ecosystem and visual tooling.
- More manual work for complex levels, animation, physics, and effects.
- Less suitable as the default for a quality-first, game-heavy project.

### Swift with SpriteKit and SwiftUI

Choose the native Apple stack when platform integration is more important than
minimizing macOS usage.

Advantages:

- Direct access to Apple frameworks and platform features.
- Native performance, accessibility, UI, haptics, Game Center, and StoreKit.
- No third-party engine runtime.

Tradeoffs:

- Xcode, Apple simulators, and native visual tooling require macOS.
- Meaningful local development and debugging cannot remain primarily on
  Windows.
- It creates the highest dependency on cloud-hosted or physical Mac hardware.

## Local and cloud build policy

Use the least expensive runner that can perform each job:

| Work | Preferred environment |
|---|---|
| Game editing and local playtesting | Local Windows machine |
| Asset processing and content validation | Local Windows machine |
| Script checks and engine headless validation | Local Windows or GitHub Linux runner |
| Pull-request validation | GitHub Linux runner where possible |
| iOS export and Xcode archive | GitHub-hosted macOS runner |
| Apple code signing | GitHub-hosted macOS runner |
| iOS simulator or device-specific tests | macOS runner or TestFlight device |
| TestFlight upload | GitHub-hosted macOS runner |

The macOS workflow should not run on every commit. Trigger it manually with
`workflow_dispatch`, for release tags, or after an explicit release approval.
Routine checks should use local Windows resources or Linux CI.

## iOS signing and public-repository rules

- Never commit App Store Connect `.p8` private keys.
- Never commit signing `.p12` files or their passwords.
- Do not commit deployment tokens or authenticated service URLs.
- Avoid committing provisioning profiles because they can contain device and
  account identifiers.
- Store signing material in GitHub Actions secrets or retrieve short-lived
  signing assets during the release workflow.
- Do not expose secret values in workflow commands, logs, artifacts, or test
  output.
- Do not provide repository secrets to untrusted pull-request workflows.

An Apple Developer Program membership is required for TestFlight and App Store
distribution. The game engine itself does not add a required fee when Godot,
Flutter/Flame, or the Apple-native stack is used.

## When to revisit the decision

Re-evaluate the selected stack before substantial development if:

- The game changes from 2D to advanced 3D.
- A required SDK or platform feature does not support the selected engine.
- Performance cannot meet the target devices after a representative prototype.
- The project becomes primarily an app rather than a game.
- Apple-exclusive features become the central product requirement.

For an uncertain project, build a small vertical slice containing representative
gameplay, animation, audio, touch controls, save data, and one iOS export before
committing to the full production plan.
