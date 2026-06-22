# Changelog

All notable changes to Last Radio v2 will be documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- feat(steam): wire 8 achievement triggers (first_night, first_contact, recruit_nora, recruit_elias, all_three_allies, reach_victor, clear_all_nights, no_breach); drop hard_clear and ng_plus_one (out of chapter-1 scope)
- test: tools/achievement_trigger_test.gd
- M9: `export_presets.cfg` with Windows / macOS / Linux desktop targets
- M9: `tools/build_release.ps1` + `tools/build_release.sh` (run tests → stamp
  version → export → verify → checksums)
- Cover screen "继续游戏" overlay (loads most recent save slot)
- UI member-glyph swap: BaseScreen member panel + DispatchPanel member
  cards / slot previews now show a colored letter badge (initial of the
  member's name + role-keyword color) instead of portrait textures
  (`_resolve_member_glyph` / `_build_glyph_badge` on BaseScreen and
  DispatchPanel). Old `portrait_{player,nora,elias}.png` references
  removed from UI loaders; assets remain on disk pending archival call
  by orchestrator. New proof shots in
  `screenshots/art_audit/glyph_{base,dispatch}.png`.
- feat(audio): ship success / failure / report sting + report bed + footstep /
  wood-plank nail SFX samples generated via Matrix MCP (5 mp3, mirrored to
  both `assets/audio/` and `assets/final/night_shift/audio/`). `NightShiftGame
  ._load_audio()` extended to register the new tracks; `_play_music(track,
  looped)` now honours the per-call `looped` flag so success/failure stings
  play one-shot and the report bed loops. `_process` watches
  `music_player.playing` and swaps to the looping report bed once the sting
  ends (flag-based polling via `_pending_report_music`, robust against
  player mid-sting retry / advance). `NightShiftSfx` SFX module still ships
  procedural fallbacks for `footstep` / `wood_plank_nail` — the matrix samples
  are full music-length clips pending an ffmpeg-based trim pipeline; wire-up
  to the runtime will land once a trim step is available.
- test: `tools/night_shift_audio_test.gd` — 19 assertions covering audio
  loader population, `_play_music` loop flag, success/failure sting
  routing, breach path → night_report, `_show_night_report` no-longer-plays
  "final" regression, and the `_process` sting→report swap transition.
- test: `tools/achievement_trigger_test.gd`, `tools/ampersand_lint_test.gd`
  (defensive CI gate — fails if any `.gd` under `res://scripts/` or
  `res://tools/` contains the `&&` operator; project style is the `and`
  keyword). Baseline: zero hits.
- feat(fx): round 2 player repair-action pose (`PlayerRepairFx` swap +
  hammer sprite during barrier repair tick). Round 1 world-layer parallax
  + outside-zombie sprites (`FxLayerNode`).
- fix(art): wire actor portraits + day-card icons + BaseScreen member
  portraits into runtime; hide stale hotspot buttons on
  report/final screens.
- fix(layout): day picker overflow with 4 cards shrinks card_w to fit
  screen.
- refactor(steam): `Steamworks` migrated from `extends Node` stub to a
  `class_name Steamworks extends RefCounted` module; adds
  `is_achievement_unlocked` / `get_unlocked_achievements` introspection,
  cloud save stubs (`cloud_write` / `cloud_read`), and Rich Presence
  state tracking.

### Fixed
- `night_shift_full_flow_test` step 16 (`_show_cover_with_continue`) — added
  the missing `_show_cover_with_continue()` + `_on_continue_pressed()` to
  NightShiftGame, all 18 test suites pass (593 assertions).
- `tools/night_shift_audio_test.gd` breach-path assertions: phase 4 now
  calls `_show_night()` to rebuild hotspot state cleanly (the previous
  hand-set phase="night" path left `breach_timer` polluted from phase 3
  success_unlocks); phase 5 resets `breach_timer` back to -1 before
  `_show_night_report(true)` so phase 6's `_process` swap isn't masked
  by a re-triggered `_end_night(false)`. 19/19 audio assertions pass.

## [0.5.0] - 2026-06-19

### Added
- M1 i18n: `I18n` module + zh/en chrome strings (~200 keys), Settings locale
  switch persisted to user settings
- M2 settings: audio volume, fullscreen toggle, pause overlay, quit confirm
- M3 tutorial: 3-step first-night guide (move → repair → radio)
- M4 save slots: 3-slot save system, v3 schema (adds tutorial_done,
  difficulty, ng_plus_count), legacy v2 migration
- M5 art: full formal night_shift asset set — hotspot state art (door,
  window, antenna, generator, medbay, storage, radio), day event
  illustrations, player/nora/elias 4-direction 12-frame walk anims,
  player 3-view actor art, threat overlays, ending art, BGM + ambience
- M6 Steamworks: stub backend with achievement scaffolding + Rich Presence
  hooks (GodotSteam integration deferred — see M6 follow-up)
- M7 legal: LICENSE (MIT), EULA.md, PRIVACY.md, THIRD_PARTY.md
- M8 app shell: 256/512 icon set, splash image, window mode + resolution
- NightShiftData: data-driven loader for resources / day_cards / nights /
  signals (replaces hardcoded constants)
- NightShiftActors / HotspotDot / HotspotIndicator (visual + interaction
  polish for hotspot dots and grounded actor rendering)
- NightShiftDayEffects: daytime card → nighttime parameter aggregator
- NightShiftSfx: procedural SFX (warning / assault / breach / radio call /
  blackout / restore / report), BGM phase switcher

### Changed
- Main loop rewritten as a state machine (cover → day → night →
  night_report → final), data-driven thin controller
- Art pipeline switched to AI-generated formal assets in
  `assets/final/night_shift/` with procedural fallback in
  `assets/fallback/`
- Save schema bumped to v3; v2 saves auto-migrate to slot 1 on first read

### Fixed
- Encoding corruption in 150+ Chinese strings (PowerShell `Get-Content`
  re-encoding was destroying source files; switched to UTF-8-safe Read
  tool for all future edits)
- Player animation seam (replaced full-body source art cutting with
  direction-specific cut + overlap composition)
- Helper targeting jitter (Nora/Elias no longer chase nearly repaired
  targets; barriers settle after bracing completes)

## [0.5.0] - 2026-06-19

M9 build pipeline + M1-M8 batch

## [0.5.0] - 2026-06-19

M9 build pipeline + M1-M8 batch

## [0.5.0] - 2026-06-19

M9 build pipeline

## [0.5.0] - 2026-06-19

M9 build pipeline
