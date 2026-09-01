# Frog City Feast audio assets

All audio in this directory is original, non-vocal synthesis created for
**Frog City Feast**. No recordings, sample libraries, commercial music,
named-song melodies, or third-party sound assets were used.

The source is the committed `scripts/generate-audio.ps1` waveform and note
definitions. The production set was Copilot-assisted and authored for the
repository owner in September 2026. Copyright belongs to the repository owner.
The repository has no general open-source license, so reuse outside this
project requires the owner's permission.

## Reproduction

From the repository root on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-audio.ps1
```

The generator uses only PowerShell, .NET math functions, and the standard WAV
container writer. It deterministically recreates 22,050 Hz, 16-bit, mono WAV
files. Running Godot's normal import afterward creates the adjacent `.import`
metadata; runtime code sets the music and ambience loop boundaries explicitly.
The five music loops and two ambience loops are four seconds each. The complete
38-file source set is 1,834,910 bytes and remains below the 2 MiB repository
budget without Git LFS.

## Asset set

- Interface and session: `ui_feedback.wav`, `room_travel.wav`,
  `epilogue_open.wav`, and `epilogue_return.wav`.
- Tongue and belly loop: `tongue_launch.wav`, `tongue_hit.wav`,
  `tongue_miss.wav`, `struggle_tap.wav`, `swallow.wav`, `digest.wav`, and
  `spit.wav`.
- Frog and progression: `growth.wav`, `growth_major.wav`, `damage.wav`,
  `power_activate.wav`, `shield_pop.wav`, `discovery.wav`, `clue_found.wav`,
  `achievement.wav`, and `challenge_complete.wav`.
- Pursuit: `pursuit_alert.wav`, `pursuit_escape.wav`, `net_warning.wav`,
  `flashlight_warning.wav`, and `watchdog_lunge.wav`.
- Obstacles and destruction: `trap_deploy.wav`, `trap_trigger.wav`,
  `roadblock_deploy.wav`, `roadblock_hit.wav`, `roadblock_break.wav`, and
  `destruction.wav`.
- Music: `menu_music.wav`, `gameplay_day.wav`, `gameplay_night.wav`,
  `pursuit_music.wav`, and `epilogue_music.wav`.
- Ambience: `city_day.wav` and `city_night.wav`.

## Provenance and licensing

Every listed WAV inherits the source, authorship, license, generation date, and
reproduction process documented above. Music uses original warm-pad,
marimba-like pluck, toy-percussion, and chamber-synth note sequences. Effects
use original deterministic chirps and seeded noise. No file contains
third-party material requiring attribution.

At runtime, `src/audio_director.gd` uses one music player, one ambience player,
and four reusable effect voices. Per-event cooldowns and a fixed pitch cycle
bound density without consuming the gameplay random-number stream. Master,
Music & ambience, and Effects remain independently adjustable.
