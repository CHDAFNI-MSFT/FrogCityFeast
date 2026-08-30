# Frog City Feast audio assets

All audio in this directory is original, non-vocal synthesis created for
**Frog City Feast**. No recordings, sample libraries, commercial music,
named-song melodies, or third-party sound assets were used.

## Reproduction

From the repository root on Windows:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-audio.ps1
```

The generator uses only PowerShell, .NET math functions, and the standard WAV
container writer. It deterministically recreates 22,050 Hz, 16-bit, mono WAV
files. Running Godot's normal import afterward creates the adjacent `.import`
metadata; runtime code sets the music and ambience loop boundaries explicitly.

## Asset set

- `ui_feedback.wav`: compact menu and option confirmation.
- `tongue_launch.wav`, `tongue_hit.wav`, `tongue_miss.wav`: tongue feedback.
- `struggle_tap.wav`: bounded rapid-tap struggle feedback.
- `swallow.wav`, `digest.wav`, `spit.wav`: belly-loop feedback.
- `growth.wav`, `damage.wav`, `discovery.wav`,
  `challenge_complete.wav`: important progression and state feedback.
- `city_day.wav`, `city_night.wav`: gentle synthesized city textures.
- `menu_music.wav`, `gameplay_music.wav`: restrained original synth loops.

## Provenance and licensing

The waveforms and note sequences are defined entirely in
`scripts/generate-audio.ps1`. The files were generated for this repository in
August 2026 and contain no third-party material requiring attribution.

Copyright in these project-specific audio files and their generator belongs to
the repository owner. The repository currently has no general open-source
license, so reuse outside this project requires the owner's permission.
