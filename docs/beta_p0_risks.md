# Beta Known Risks (P0 / P1 / "Not In Scope")

> Audience: closed-beta players (T-7 friends-only keys, ~5-10 testers).
> Purpose: tell you what's already fixed, what we know is shaky but ships
> anyway, and what was deliberately cut so you don't expect it.
> Version scope: `feature/m15-character-art` @ `fc7ecdb`
> (GodotSteam 4.20 + Steamworks 1.64 real API, Godot 4.7-stable, 21/21
> headless suites green).

---

## How to file a beta bug

1. Repro steps + which night / which screen.
2. `user://logs/last_radio.log` tail (if any) — or just describe what
   you saw.
3. Save slot id (top-right of cover screen says `slot_1/2/3`).
4. Send to the Steam thread or Discord DM. Discord link in the beta
   key email.

We triage P0 (game blocks / crashes / save-loss) within 24h. P1 (visual
glitch / wording) within the week. P2 (polish) goes into the Day-1
patch backlog.

---

## ✅ Fixed in this build (you should NOT be seeing these)

| Area | What it was | Fix commit |
|---|---|---|
| Engine | Was Godot 4.3; some 4.4-4.7 APIs and rendering quirks differed | `b67be72` (engine → 4.7-stable) |
| Steamworks | Stub backend — no real achievements / cloud / Rich Presence | `fc7ecdb` (GodotSteam 4.20 real) |
| Tests | 5 headless suites had phase-transition race conditions | `19f258d` (await async transitions) |
| Hammer sprite | Procedural draw looked flat, didn't pop | M13 `2c006ca` (art-based sprite, 1024×1024 AI) |
| Player repair sprite | v0.5 had a magenta halo from RGBA corruption | M13.1 (png_to_rgba v6, restores true alpha) |
| Day card bodies | Read like feature lists | M14 (rewritten as first-person narrator monologue) |
| Hammer swing over-arm | -60° → +73° → -67° arc; thrust 1.4 → 1.8 rad | Round 2.1 `3b1b7e3` |
| Late-night pacing | Night 5+ cadence now 4-7s (was uniform 6-10s) | Round 2.1 |
| Day-card order | Day 1-3 had visual desync | `c6e44d6` (M10.5) |
| Cover screen | Slot cards grey, title lost in bright photos | M10.5 (scrim + warm-orange borders + centered title) |
| UI leaks | Radio contact buttons / tutorial skip button bled into non-night screens | M10.5 UI leak sweep |
| Day picker overflow | 4 cards could overflow at 1280×720 | `c6e44d6` (card_w shrinks to fit) |
| `&&` operator in scripts | Would have broken GDScript parser silently | `ampersand_lint_test` CI gate (0 hits) |
| Encoding corruption | PowerShell `Get-Content \| Set-Content` was nuking CJK | 0.5.0 → switched to UTF-8 Read tool |

---

## ⚠️ Known shaky / by-design limits (you MIGHT see these)

### Audio
- **Default launch is muted** (`Settings.DEFAULT_AUDIO_MUTED = true`).
  Toggle in Settings ▸ Audio. CLI flags `--no-mute` / `--mute` /
  `--silent` / `--quiet` / `--audio` / `--sound` override per-session.
  Reason: first-launch / dev-debug runs no longer bleed music + sfx
  into the room.
- AI-generated BGM may sound "programmatic" rather than "cinematic" on
  some tracks. Procedural SFX fallback always works. If a track is
  genuinely painful, file it — we may swap it for Day-1 patch.

### Steam Cloud
- Cloud save is real Steam `ISteamRemoteStorage` now, but if you play
  the same slot on two machines **without** exiting Steam cleanly, the
  second-machine write wins. Standard Steam Cloud behaviour. We're not
  implementing conflict resolution for chapter-one.
- If you launch the game **without** Steam running, achievements /
  cloud / Rich Presence gracefully no-op (no crash, no popup spam). The
  game still plays end-to-end locally.

### Save schema
- Schema is v3. v2 saves auto-migrate to slot 1 on first read (no data
  loss). v1 saves from the very early prototype are NOT supported —
  you'd have lost them in 0.4.x anyway.
- 3 slots. No more, no fewer — the slot picker is the source of truth.
  Re-arranging files in `user://saves/` by hand will confuse the slot
  picker; reload from cover.

### Platforms
- **Windows is the primary tested target** (Godot 4.7-stable console,
  Steamworks 1.64, all 21 headless suites pass on it).
- macOS / Linux builds ship via `tools/build_release.sh` and
  `export_presets.cfg`, but **only Windows is exhaustively QA'd in
  headless**. If you find a Mac / Linux crash, it's a P0 — file
  immediately with `~/.config/godot/app_userdata/Last Radio/logs/`
  on Linux or `~/Library/Application Support/Godot/app_userdata/...`
  on macOS.

### AI art consistency
- 6 character portraits (player / nora / elias / lily / tom / daniel)
  and 3 wide-framing portraits. Style was normalised across passes, but
  if any single portrait feels off vs. the others, please flag it —
  we'll either re-generate or accept the inconsistency.

### Late-game pressure
- Night 5+ background-warning cadence is now 4-7s (was 6-10s
  everywhere). It's deliberately harder. If it feels unfair after
  2-3 nights of playing, that's a tuning conversation, not a bug.

---

## 🚫 Deliberately NOT in chapter-one (manage your expectations)

Per the roadmap's Scope cut. We will not add these for chapter-one no
matter how many people ask:

- ❌ Voice acting / dubbing — 18 RMB can't carry voice budget.
- ❌ NG+ / Hard Mode / Endless — one-shot short.
- ❌ Modding / Workshop — no user base yet.
- ❌ Switch / mobile ports — no distribution there.
- ❌ Custom controller remapping — only basic Xbox / PS button maps.
- ❌ DLC framework — chapter two planned but starts only after
  chapter-one sells.
- ❌ Speedrun / leaderboards — short game doesn't need them.
- ❌ Multiplayer — wrong scope.
- ❌ Chapter selector / new-game-plus from cover — chapter-one only.

Steam Achievements also intentionally **dropped** `hard_clear` and
`ng_plus_one` from this build (out of chapter-1 scope). The 8 shipped
are: `first_night`, `first_contact`, `recruit_nora`, `recruit_elias`,
`all_three_allies`, `reach_victor`, `clear_all_nights`, `no_breach`.

---

## 🟡 Polish backlog (may or may not land before Day-1 patch)

These are on the polish spec but not all shipped yet:

| Item | Status |
|---|---|
| M12 NPC sprite + 顶部状态条 | 🔜 Not yet wired — NPC state shows via alerts only |
| M15 章节延展（角色来去 + Victor 失联） | 🟡 Lily / Daniel / Tom art + unlocks data shipped; the in-game "Victor 失联" arc is NOT yet scripted |
| Long-tail city-map / 情报整理 / 排班 modules | Backlog — explicitly NOT in chapter-one |
| 第二章 | Planned, not started |

If your beta feedback mentions any of these, we will acknowledge but
probably won't ship it in chapter-one.

---

## What's NOT a bug (please don't file)

- "Game is hard on night 5+" → by design. Play through, learn pacing.
- "I lost because I ran out of medicine" → resource scarcity is core.
- "AI BGM doesn't match a track I imagined" → AI generation is
  intentionally varied; swap your mental model.
- "There's no NG+" → scope cut.
- "I expected voice acting" → scope cut.
- "Achievement X isn't on my list" → only 8 ship; the doc above lists them.

---

## TL;DR for beta testers

- **P0** (crash / save-loss / blocks) → 24h fix, Day-1 patch.
- **P1** (visual glitch / wording) → weekly, Day-1 patch or Day-7.
- **P2** (polish / new feature) → backlog.
- **Scope cut** → won't fix; this doc explains why.

Thanks for playing. Honest reports > polite ones.