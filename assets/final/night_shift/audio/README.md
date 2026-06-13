# NightShiftGame Audio

Drop optional music files in this folder. The game checks `.ogg`, `.mp3`, then `.wav`.

Loaded music and external ambience streams are duplicated and forced to loop at runtime, so each night track can be a normal exported song file.

Core tracks:

- `music_cover` - cover/title screen.
- `music_day` - white-day planning panel.
- `music_night` - nights 1-6.
- `music_night_late` - nights 7-9. Falls back to `music_night`.
- `music_night_final` - night 10. Falls back to `music_night`.
- `music_final` - final ten-night ending.

Current night music mapping:

- Nights 1-5 use `music_night_early`.
- Nights 6-10 use `music_night_final`.

Night ambience loops:

- `ambience_night` - nights 1-6.
- `ambience_night_late` - nights 7-9. Falls back to `ambience_night`.
- `ambience_night_final` - night 10. Falls back to `ambience_night_late`, then `ambience_night`.

Optional report tracks:

- `music_success` - successful night report.
- `music_failure` - failed night report.
- `music_report` - fallback for success/failure reports.

The current build also creates procedural ambience and short SFX in code, so the game remains playable without external audio files.

Current imported files:

- `Static Sanctuary.mp3` -> `music_cover.mp3`
- `day.mp3` -> `music_day.mp3`
- `final.mp3` -> `music_final.mp3`
- `night final.mp3` -> `music_night_final.mp3`
- `night final (1).mp3` -> `music_night_early.mp3`
- `night late.mp3` -> `ambience_night.mp3`
- `night late (1).mp3` -> `ambience_night_late.mp3`
- `night final (1).mp3` -> `ambience_night_final.mp3`
