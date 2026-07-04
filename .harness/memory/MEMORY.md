# Team Memory — Last Radio v2

Shared, durable notes for the whole team. **Reins write here only when the
fact is reusable across agents and the project**, not for task-scoped
working notes (those stay in the branch session's scratchpad).

## Project shape

- Godot 4.3-stable GDScript project (verified); `project.godot` declares
  `features=4.6` but the API surface used is 4.3-compatible.
- Default branch is `master` (not `main`) — do not propose `main`-based
  workflows.
- Solo-dev release target: Steam (zh/en, 18 RMB, single chapter).
- M1–M10 milestones all shipped (see `docs/release_roadmap.md`).
  Current focus: 可玩性 / 视觉 / 特效 深化 (playability, visual, FX polish).
- Save schema is currently **v5** (bumped from v4 in M13). Compat
  v1/v2/v3/v4 via migration branches in `scripts/NightShiftSave.gd`.
- **22** headless test suites in `tools/` are the regression gate
  (18 base + 3 from M13: cover_monologue / tutorial_step4 /
  night_report_log — ~646 assertions). Canonical loop is in
  `AGENTS.md` → Setup commands.

### Night-report has two render paths (M13 decision, 2026-07-04)
Type: design-decision
A "night report" screen can be rendered by two code paths:
`NightShiftGame._show_night_report(...)` (inline, used in the
10-night main flow) and `NightReport.gd` scene via `setup(...)`
(BaseScreen round flow). Polish-spec §6 hooks that touch the night
report (e.g. Hook C "3-line body") MUST be wired into **both**
paths — wiring only one leaves the hook missing in the other mode.
Hook C implementation: inline path consumes the
`previous_allies = allies.duplicate(true)` snapshot taken at the
start of `_show_day()`; scene path accepts optional
`allies_before` / `current_allies` in `setup()` and renders the
same 3-line block when both non-empty. Pinned by harness.

## Hard rules (apply to every rein)

- **No hardcoded zh/en text** in `scripts/` or `scenes/`. Use `tr("key")`
  via the `I18n` module. Every new key goes in **both**
  `data/i18n/zh.json` and `data/i18n/en.json` in the same PR.
- **No `Get-Content | Set-Content` on Windows** for file edits — it
  silently corrupts CJK on PowerShell 5.1. Use the Read/Write/Edit
  tools. There is a real prior incident (see `CHANGELOG.md` 0.5.0 →
  Fixed → "Encoding corruption in 150+ Chinese strings").
- **No Steam credentials** in the repo. The Steamworks stub stays
  credential-free; cloud-save sync is deferred.
- **No telemetry** is collected client-side. The `godot_ai` MCP
  plugin is local-only (`127.0.0.1:8000`); do not expose it to the
  network.
- **No reviving archived scripts**. `tools/_archived_*.gd` reference
  removed `_debug_*` APIs; add a new test using the current API
  instead.

## Conventions (link, don't inline)

- Setup / build / test / release commands: `AGENTS.md` → Setup commands.
- Project layout, code style, i18n rules, PR conventions, security:
  `AGENTS.md`.
- Design overview and night-by-night pacing:
  `docs/LAST_RADIO_V2_DESIGN.md`,
  `docs/design/game_design_spec_zh.md`,
  `docs/design/chapter_01_night_plan_zh.md`.
- Radio minigame mechanics: `docs/radio_design.md`.
- Milestone tracker: `docs/release_roadmap.md`.

## How to add an entry

Append under a topic heading. Keep entries tight (a few lines). Cite
the source file when the rule is already documented there — the goal is
to make the rule discoverable, not to duplicate `docs/`.

```
### <topic> (<YYYY-MM-DD>)
Type: convention | gotcha | reference
<one-paragraph fact>
WHY: <why this matters later>
```
