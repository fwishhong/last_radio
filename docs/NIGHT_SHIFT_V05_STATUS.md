# NightShiftGame v0.5 Status

Date: 2026-06-07

## Direction

The active direction is `NightShiftGame` / `旧体育馆守夜`: a direct room-hotspot night-watch survival game set in the old stadium shelter.

The older radio dispatch, `BaseScreen`, `DefenseGame`, and v2 prototypes remain in the project and are regression-tested. They are not the current main direction, but they should not be deleted or broken.

## Integrated Final Art

Formal art is loaded from `assets/final/night_shift/`.

Current v0.5 coverage includes:

- Back door state set: intact, warning, assault, braced, broken.
- Medbay state set: idle, warning, treating, critical.
- Storage state set: idle, shortage, repairing, empty.
- Day upgrade event art for all current upgrade choices.
- Day upgrade cards display the matching formal `event_*.png` art in the white-day choice UI.
- Formal player, Nora, and Elias token art loaded from `assets/final/night_shift/`.
- Formal threat overlays for front door, back door, left window, and right window.
- Ending art for success and failure reports is loaded from `ending_stadium_dawn.png` and `ending_breach_night.png`.

Night play uses clean re-encoded runtime copies of the formal stadium/top-down/report backgrounds. Physical map hotspots render as compact state-art icons placed on the matching objects in that map. Door, window, generator, radio, antenna, medbay, and storage hotspots all use their formal generated state art without covering the underlying room art.

`NightShiftArt.hotspot_texture_key()` maps support hotspots to `medbay_treating` and `storage_repairing` while the player is assigned to those active hotspots.

## Current Gameplay Changes

- A cover screen now opens the campaign before the first day panel.
- Each night now has a dedicated story intro, three timed night-log story beats, and unique success/failure report text.
- Victor Hale is now the external radio/supply-line character who carries the mid-game thread and sacrifices his station in the final night while Nora and Elias remain playable helpers.
- NightShiftGame now creates procedural ambience and short SFX for warnings, impacts, radio calls, support trouble, blackout, restore, story beats, and reports.
- Optional phase music is loaded from `assets/final/night_shift/audio/` using `music_cover`, `music_day`, `music_night`, `music_night_late`, `music_night_final`, `music_success`, `music_failure`, `music_report`, and `music_final`.
- Loaded music and external night ambience streams are duplicated and forced to loop at runtime.
- External night ambience is loaded from `ambience_night`, `ambience_night_late`, and `ambience_night_final`, with procedural ambience as a fallback.
- Current night music mapping uses `music_night_early` for nights 1-5 and `music_night_final` for nights 6-10.
- Full-screen danger and blackout effects are now drawn procedurally instead of loading overlay PNGs, avoiding polluted overlay assets in the main view.
- The player character now uses three processed full-body source images, `actor_player_front.png`, `actor_player_side.png`, and `actor_player_back.png`, generated from the latest download batch by `tools/process_player_actor_sources.py`.
- The player actor picks front/back/side facing by movement direction, mirrors side art for left movement, and draws overlapped source-image pieces with small walk/work rotations. Nora and Elias still use the procedural segmented rig until matching source images are generated.
- Characters are drawn as grounded actor rigs with floor shadows, foot-anchored placement, and small labels for readability.
- Night characters now use grounded actor rendering: no circular portrait frame, foot-anchored placement, floor shadow, Y-depth ordering, short route waypoints, and helper target cooldowns to reduce back-and-forth jitter.
- Door and window attacks now use the four processed zombie silhouette PNGs from the download batch, with code-driven creep/lunge/hand-reach motion and red breach pulse. Procedural silhouettes remain only as a missing-asset fallback.
- The right-side night HUD is now a compact panel focused on time, current prompt, emergency plank, 1x/2x speed toggle, and recent log lines instead of a full status list.
- The night timer displays as an eight-hour countdown. Night 1 now lasts 90 real seconds; later nights keep their current durations, and the 2x toggle makes a 180-second night resolve in 90 real seconds.
- Night 4+ adds a second radio call, and Night 9+ adds a third radio call.
- Director pressure starts earlier and can allow more simultaneous crises on later nights.
- Night play now has a five-second rhythm tick plus guaranteed late-night and final-pressure waves. Each tick adds either a warning, a light maintenance pressure, a near-future cue, or a short breathing log, so the player keeps judging the room without every beat becoming a forced click.
- Hotspot unlock pacing is now staged: Night 1 uses only front door, left window, and generator; then right window, radio, antenna, back door, medbay, and storage are introduced one at a time.
- Helper targeting is less twitchy: Nora/Elias no longer chase nearly repaired targets, and barriers settle after being fully braced.

Music generation prompts are documented in `docs/NIGHT_SHIFT_AUDIO_PROMPTS.md`.

## Character Animation Gap

Current player animation uses direction-specific full-body source art that is cut into overlapped pieces at draw time, avoiding the hard straight-cut seam problem while keeping the code path small. True Godot `Skeleton2D` animation should still be implemented as a separate `ActorToken` scene with `Node2D` placement, `Skeleton2D`/`Bone2D` or segmented body parts, and an `AnimationPlayer`/`AnimationTree` for idle, walk, repair, brace, radio, and hurt states. That pass can now use the same three-direction source-image workflow instead of asking AI for separated part sheets.

## Visual Captures

`tools/capture_night_shift_gui.gd` now writes:

- `night_shift_00_cover.png`
- `night_shift_07_back_door.png`
- `night_shift_08_final_wave.png`
- `night_shift_09_success.png`
- `night_shift_10_failure.png`
- `night_shift_11_medbay_treating.png`
- `night_shift_12_storage_repairing.png`
- `night_shift_13_day_upgrade_choices.png`
- `night_shift_14_day_medbay_choices.png`
- `night_shift_15_day_storage_choices.png`
- `night_shift_16_day_signal_choices.png`
- `night_shift_17_final.png`

The output directory is:

`C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\最后电台 Demo\`

The v0.5 visual pass found no HUD overlap or hotspot placement issue in the checked images.

## Art Gap Status

The 2026-06-04 download batch contained seven usable sheets. The first five were already integrated; the sixth and seventh were later recovered as formal character, portrait, and threat art.

The 2026-06-05 download batch contained usable art for thirteen upgrade events. The 21:42 reference image and the three later character alternatives are not imported as formal game assets.

The 2026-06-06 00:34 download batch completed the remaining clean formal event art:

- `event_nora_kit.png`
- `event_quiet_hours.png`
- `event_double_brace.png`
- `event_victor_cache.png`
- `event_cable_route.png`

No current `NightShiftLevels.gd` upgrade choice is missing formal event art.

`tools/process_download_night_shift_missing_events.py` is now guarded against accidental overwrite. It requires either five explicit `--source` paths or `--latest-five`, and it only writes files when `--apply` is passed.

## Validation

Current passing checks:

```powershell
& ..\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/night_shift_smoke_test.gd
& ..\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/night_shift_campaign_flow_check.gd
& ..\Godot_v4.6.3-stable_win64_console.exe --path . --script res://tools/night_shift_audio_probe.gd
& ..\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/defense_smoke_test.gd
& ..\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/v2_smoke_test.gd --verbose
& ..\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/audit_night_shift_assets.gd
& ..\Godot_v4.6.3-stable_win64_console.exe --headless --path . --quit
& ..\Godot_v4.6.3-stable_win64_console.exe --path . --script res://tools/capture_night_shift_gui.gd
```

The v2 verbose run may print Godot controller mapping warnings; those warnings did not fail the test.

`tools/night_shift_campaign_flow_check.gd` walks a deterministic ten-night campaign path and verifies that every night can reach a success report and the final campaign success state.
