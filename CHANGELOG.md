# Changelog

All notable changes to Last Radio v2 will be documented in this file.

The format is loosely based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- M9: `export_presets.cfg` with Windows / macOS / Linux desktop targets
- M9: `tools/build_release.ps1` + `tools/build_release.sh` (run tests → stamp
  version → export → verify → checksums)
- Cover screen "继续游戏" overlay (loads most recent save slot)

### Fixed
- `night_shift_full_flow_test` step 16 (`_show_cover_with_continue`) — added
  the missing `_show_cover_with_continue()` + `_on_continue_pressed()` to
  NightShiftGame, all 18 test suites pass (593 assertions).

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
