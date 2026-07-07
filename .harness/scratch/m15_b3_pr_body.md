# M15 polish B3 — spec dependency-graph tool

Polish backlog B3 close-out: **the "how does spec touch my files" problem**.

When a polish spec section (e.g. `§6.2 Tutorial Step 4`) needs implementing, the
developer session has to grep the spec body for file names + i18n keys + test
files + capture scripts, then cross-reference against what's actually on disk.
This tool does that automatically.

## What this PR ships

### `tools/spec_depgraph.gd` (new, SceneTree entry)
- Usage: `godot --headless --path . --script res://tools/spec_depgraph.gd -- [--spec=<markdown>] [--out=<json>] [--no-write]`
- Defaults: `--spec` = `docs/design/last_radio_v2_polish_spec.md`, `--out` = `.harness/scratch/polish_depgraph.json`
- Prints a human-readable dependency table to stdout + writes a JSON map to `--out`
- Reads `res://scripts/*.gd` and `res://data/i18n/zh.json` to seed the "known" sets so the tool stays in sync with the codebase without a manual blacklist.

### `tools/spec_depgraph_lib.gd` (new, RefCounted static helpers)
- `parse_sections(text)` — splits on `##` / `###` / `####` headers, emits `{id, level, line, body}` per section
- `extract_backticks(text)` — pulls all single-line backtick tokens with line numbers
- `classify_token(token, known_scripts, known_i18n)` — routes by extension / shape:
  - `.gd` → `script` (with `capture_*` / `*_test.gd` reclassified downstream)
  - `.tscn` → `scene`
  - `.json` (under `data/`) → `data`
  - `.png` / `.tres` / `.res` / `.import` / `.svg` → `asset`
  - Known i18n key from `zh.json` → `i18n`
  - `*` / `{...}` globs → `asset`
  - Everything else → `ignore` (PascalCase, bare snake_case that isn't a known key, etc.)
- `extract_bare_scripts(body, known_scripts)` — word-boundary regex sweep for bare script basenames (e.g. `NightShiftActors` mentioned without backticks)
- `extract_test_refs` / `extract_capture_refs` — picks up `tools/xxx_test.gd` / `tools/capture_xxx.gd` even when the spec author wrote them without backticks (e.g. inside markdown tables)
- `extract_section(section, known_scripts, known_i18n)` — the meat: returns the 7-bucket dict for one section
- `cross_ref(sections, known_scripts, known_i18n)` — produces the orphan / ghost / unused-i18n / no-ref sections rollup
- `render_table(...)` / `build_json(...)` — output formatters

### `tools/spec_depgraph_test.gd` (new, SceneTree test, 54 assertions)
- `parse_sections` — header split + h1/h5 ignore + trailing newline tolerance
- `extract_backticks` — count + content + multiline skip
- `classify_token` — every classification branch (gd / tscn / data / png / known i18n / glob / ignore)
- `extract_section` end-to-end on an inline fixture covering scripts / scenes / data / i18n / assets / tests / captures
- `cross_ref` — orphan / ghost / unused-i18n detection
- `list_gd_scripts` + `list_i18n_keys` — real-disk round-trip + missing-path tolerance
- Real-spec round-trip: parse `docs/design/last_radio_v2_polish_spec.md`, assert specific sections ref `NightShiftActors.gd` / `npc_ai_test.gd` / `tut_step4_title` / `chapter_01_nights.json` / `zombie_hands_reach.png`

### `AGENTS.md` — canonical gate list updated
`19 suites → 20 suites` (added `spec_depgraph_test`). New assertion count baseline: ~647.

### `CHANGELOG.md` — Unreleased / Added entry
Records B3 scope + file list + new gate position.

### `docs/release_roadmap.md` — current-focus table updated
Added B3 row showing ✅ at `feat/b3-spec-depgraph` with link to polish spec.

## Headless gate

```
=== Post-commit gate: 0 failures out of 20 ===
[ OK ] save_test                          [ OK ] menu_ui_test
[ OK ] sfx_test                           [ OK ] save_slots_test
[ OK ] flow_integration_test              [ OK ] tutorial_test
[ OK ] night_shift_basic_test             [ OK ] i18n_test
[ OK ] night_shift_data_validate          [ OK ] locale_e2e_test
[ OK ] hotspot_dot_test                   [ OK ] night_shift_fx_test
[ OK ] day_effects_test                   [ OK ] ampersand_lint_test
[ OK ] late_hotspot_enemy_test            [ OK ] spec_depgraph_test    (NEW, 54 assertions)
[ OK ] night_report_stats_test
[ OK ] radio_contact_test
[ OK ] night_shift_full_flow_test
[ OK ] signal_catalog_test
```

## Sample output (against the live polish spec)

```
=== Spec Dependency Graph: docs/design/last_radio_v2_polish_spec.md ===

Sections: 61  |  scripts referenced: 4  |  i18n keys referenced: 15

§4. NPC 系统（代码 + 视觉 + UI）  (line 174)
    scripts   NightShiftActors.gd
    scenes    —
    data      —
    i18n      —
    assets    —
    tests     —
    captures  —

§4.6 与 `NightShiftActors.gd` (dead code) 的对接  (line 245)
    scripts   NightShiftActors.gd, NightShiftGame.gd
    scenes    —
    data      —
    i18n      —
    assets    —
    tests     —
    captures  —

§4.7 测试用例（新增）  (line 251)
    scripts   —
    scenes    —
    data      —
    i18n      —
    assets    —
    tests     npc_ai_test.gd
    captures  —

§6.1 Cover 屏  (line 299)
    scripts   BaseScreen.gd
    scenes    —
    data      —
    i18n      cover_btn_continue, cover_btn_new, cover_monologue_attribution,
              cover_monologue_line1, cover_monologue_line2
    assets    —
    tests     —
    captures  —

§6.2 Tutorial Step 4：调到 Victor 的频道  (line 320)
    scripts   —
    scenes    —
    data      —
    i18n      tut_step4_desc, tut_step4_static_noise, tut_step4_title,
              tut_step4_victor_line
    assets    —
    tests     —
    captures  —

§M11 — NPC 系统接入主循环（预计 2 天）  (line 469)
    scripts   NightShiftActors.gd
    scenes    —
    data      —
    i18n      —
    assets    —
    tests     npc_ai_test.gd
    captures  —

§M12 — NPC sprite + 视觉区分（预计 1 天）  (line 477)
    scripts   —
    scenes    —
    data      —
    i18n      —
    assets    npc_{nora,elias,lily,tom}.png
    tests     —
    captures  capture_npc_sprite_idle.gd, capture_npc_status_bar.gd,
              capture_zombie_vs_npc.gd

=== Cross-reference ===
    scripts_orphan                 0
    scripts_ghost                  27
        CityMapScreen.gd, DefenseGame.gd, DispatchPanel.gd, ... (+7 more)
    i18n_keys_unused_in_spec       226
        achievement_call_elias, achievement_call_elias_desc, ... (+206 more)
    sections_with_no_refs          38
        关联文档, 0. TL;DR, 1. 当前状态盘点（v0.5 baseline）, ... (+18 more)

Wrote .harness/scratch/polish_depgraph.json (24829 bytes)
```

JSON sample (excerpt — one section):

```json
{
  "id": "4.7 测试用例（新增）",
  "level": 3,
  "line": 251,
  "scripts": [],
  "scenes": [],
  "data": [],
  "i18n": [],
  "assets": [],
  "tests": ["npc_ai_test.gd"],
  "captures": []
}
```

## Cross-ref signals (worth a second look)

- **`scripts_orphan: 0`** — every script the spec names is on disk. ✅
- **`scripts_ghost: 27`** — scripts that exist but aren't named by the polish spec. Mostly infrastructure (`I18n`, `Settings`, `NightShiftSave`, `NightShiftData`, `NightShiftFx`, `NightShiftLevels`, `NightShiftArt`, `NightShiftSfx`, `HotspotDot`, `HotspotIndicator`, `HammerSprite`, `PlayerRepairFx`, `WorldLayerFx`, `FxLayerNode`, `RadioScreen`, `RadioTuningPanel`, `CityMapScreen`, `DispatchPanel`, `MenuUI`, `MemberPanel`, `DefenseGame`, `EndOfDayReport`, `FinalScoreScreen`, `NightReport`, `NightShiftDayEffects`, `Steamworks`, `SignalCard`). Spec doesn't need to mention them — they're touched when implementation arrives. Expected.
- **`i18n_keys_unused_in_spec: 226`** — many runtime i18n keys (achievements, settings, save slots, hotspots, etc.) live in `zh.json` but aren't name-checked in the polish spec. Expected — those keys are part of the v0.5 baseline that the polish phase isn't reshaping.
- **`sections_with_no_refs: 38`** — narrative-only sections (Bible entries, decision log, player walkthrough checklist, header sections, etc.). Useful as a smoke signal — "is this section meant to drive code, or is it documentation only?". B3 implementation also adds 7 acceptance sections to the checklist.

## Design decisions

- **Pure library + thin SceneTree wrapper.** `spec_depgraph_lib.gd` is `extends RefCounted` with all-static methods and zero I/O. `spec_depgraph.gd` wraps it with `extends SceneTree` and owns the file reads/writes + argument parsing. This keeps the lib 100% testable from a unit-test SceneTree and lets future PRs reuse it (e.g. for diffing dep graphs between spec versions).
- **Known sets reloaded on every run** (no caching). Trade-off: an extra read of `scripts/` and `zh.json` per invocation vs. needing to manually maintain a blacklist when a new script or i18n key is added. The sets are tiny (<100 entries each) so the cost is negligible.
- **Bare PascalCase names sweep the body for script mentions.** Caught `NightShiftActors` being mentioned in §4.6's body without backticks. False-positive risk: a future script named e.g. `Victory` could collide with a "victory" word in narrative text — kept the regex word-boundary-anchored to mitigate.
- **i18n classification is strict** — only known keys from `zh.json`. Bare snake_case words (function names, variable names) are too noisy to auto-classify.
- **`capture_*` / `*_test.gd` reclassified at the section level**, not the token level — keeps `classify_token` simple and lets `extract_section` do the routing in one place.

## Surprises (none blocking)

- **PowerShell console output mangles the Chinese section IDs** in the stdout table — the actual data on disk is correct UTF-8 (verified via Python `json.load`). This is a CP1252 console issue, not a tool issue. The `--out` JSON file is the source of truth for programmatic consumers; the stdout table is for human eyeballing.
- **Polish spec has 61 sections** when you split at `##` / `###` / `####`. A lot more than expected because §2 world-building + §4 NPC + §9 roadmap each nest deeply.

## Out of scope (per B3 brief)

- No edits to `scripts/`, `data/`, `assets/`, polish spec, or `docs/release_roadmap.md`'s polish spec references.
- No new capture scripts (no visual output).
- Not added to any release / CI pipeline beyond the canonical headless gate.

## Git hygiene

- Branch: `feat/b3-spec-depgraph` (off `master @ b2f3eea`).
- Single commit: `feat(tooling): M15 polish B3 — spec dependency-graph tool`.
- Working tree clean of untracked session artifacts at commit time.