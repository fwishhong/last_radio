# Unused Art Inventory — Last Radio

> Re-graded after R2 round (2026-06-20). The original flat inventory
> disguised the fact that some assets were wired-up work and others
> were concept art that may not ship. This doc splits them into four
> tiers by what would actually happen if you touched them.

## Tier summary

| Tier | Count | Action | When |
|---|---|---|---|
| 🔴 Regression | 3 actor_*.png | Restore v0.5 wiring | Done this PR |
| 🟡 Wiring | 11 icons + 3 portraits | Wire into existing UI | Done this PR |
| 🟡 Wiring | 2 hud/upgrade_frame | Replace procedural StyleBox | Later |
| 🟢 Decide | 4 threat + 1 vignette + 4 radio | Needs design call | After playtesting |
| ⚫ Drop | 7 overlays/waveform/shadows | Probably drop | Polish pass |

Total: 33 art files (was 47 — accounting error in the old doc).

---

## 🔴 Tier 1 — Regression recovery (done this PR)

### `actor_player_{front,back,side}.png` — 768×1024 each

**Was**: Loaded into `NightShiftGame.actor_textures` but never consumed;
`_draw_player` always rendered walk-frame 0 when idle.
**v0.5 status doc said** the actor system was working. **Now**: idle
facing shows actor_front (down), actor_back (up), or actor_side with
`flip_h` for left movement. Walk sprite takes over during translation.
Side mirroring preserved per v0.5 spec.

Regression test: `tools/actor_regression_test.gd` — 8 assertions
covering all 4 facings + repair-hide + missing-art fallback.

---

## 🟡 Tier 2 — Wire existing UI (done this PR)

### Icon bucket — 8 unique PNGs

**Was**: `art["icons"][card_id]` loaded by
`NightShiftArt.load_upgrade_icon_textures()` into 27 keyed slots, but
day-card picker used only labels.
**Now**: each day card shows a 64×64 TextureRect with
`art["icons"][card_id]` in the top-left corner; title shifts right by
72px, body / cost / effects labels shift down by 40px to clear the
badge. Skip card (`id="start"`) correctly has no icon.

Visual proof: `screenshots/art_audit/day_with_icons.png` shows 4 cards
on Night 2 with door / window / battery icons rendered.

### `portrait_{player,nora,elias}.png` — 384×384 each

**Was**: `BaseScreen` member panel loaded `member["portrait"]` from
`data/v2_members.json` which references `res://assets/new/named/
survivor_*.png` files that **don't exist in the repo**. Portraits were
blank.
**Now**: `BaseScreen._resolve_closeup_portrait()` falls back to
`portrait_{nora,elias,player}.png` based on name keyword matching.
Mapping:
- `nora` / `a_qing` / `pathfinder` / `mechanic` → `portrait_nora.png`
- `elias` / `shen_luo` / `radio technician` → `portrait_elias.png`
- Default (Mara Vale, Victor Hale, anything else) → `portrait_player.png`

Regression test: `tools/portrait_swap_test.gd` — 8 assertions covering
each member, fallback chain, and tree walk verifying the 4 member
panel TextureRects have non-null textures.

### HUD panel + upgrade card frame — 2 PNGs

**Was**: Top status bar uses ColorRect panels; day-card picker uses
StyleBoxFlat. Replacement art exists but is purely cosmetic.
**Recommended action**: defer to a future "polish pass" — the
procedural versions are functional and visually consistent. If the
art replaces them later, no test changes needed (just swap the
texture load in `_build_ui`).

---

## 🟢 Tier 3 — Needs design call (defer)

### `threat_*.png` (4 files: front_door, back_door, left_window, right_window)

Directional threat-callout arrows. **No implementation path exists** —
would need a new UI element distinct from the HotspotDot rings. Worth
asking: do we want directional arrows on top of the stadium topdown,
or is the current red/amber ring + telegraph dot system enough?
Chapter 2 might want this; chapter 1 doesn't.

### `atmosphere_vignette.png` (1 file, 41 KB)

Edge-darkening overlay for night tension. **No compositing pass
exists** — would need a CanvasLayer + TextureRect overlay modulating
alpha with `night_elapsed`. Implementation is ~30 lines if you want
it; otherwise it can sit unused forever.

### Radio state art (4 files: idle, calling, connected, missed)

Already loaded into `art["hotspots"]["radio_*"]` and addressed by
`NightShiftArt.hotspot_texture_key()` for `kind == "radio"`, BUT the
radio hotspot is unlocked only on Night 3+. **No existing visual
capture proves the radio textures render.** Action: capture a Night 3+
screenshot and confirm the radio hotspot art shows up. If yes, just
add the proof PNG to `screenshots/art_audit/radio_states.png`.

---

## ⚫ Tier 4 — Probably drop

### `overlay_blackout.png` + `overlay_danger_pulse.png`

Gradient overlays. The runtime draws solid-color rects via `draw_rect`
that achieve the same visual effect. Swapping in the gradient PNGs
adds nothing the player would notice. **Recommend**: leave
procedural, delete the PNGs in a future cleanup pass.

### `radio_waveform_strip.png`

Replacement for the Line2D-drawn waveform in `RadioTuningPanel.gd`.
Engineering effort is small, visual difference is minor. **Recommend**:
leave procedural unless playtesting shows the Line2D version reads
poorly.

### `zombie_shadow_{single,pair,crowd}.png` + `zombie_hands_reach.png`

Concept art for mid-room decoration (silhouettes against walls). No
implementation path exists; no design doc references them. The
runtime uses 4 large `zombie_outside_*` sprites animated by
`WorldLayerFx` instead. **Recommend**: drop unless chapter 2 wants
interior zombie silhouettes.

### `portrait_*` ↔ `character_*` confusion

The repo has both `portrait_player/nora/elias.png` (384×384 close-ups,
now wired) and `character_player/nora/elias.png` (wider framing, used
by BaseScreen for some other path). These aren't redundant — they
serve different framing needs. Keep both.

---

## Action items closed this PR

- [x] Restore actor regression in `_draw_player` (Tier 1)
- [x] Wire icon bucket into day-card picker (Tier 2)
- [x] Swap portrait_* into BaseScreen with name-keyword fallback (Tier 2)
- [x] Add `tools/actor_regression_test.gd` (8 assertions)
- [x] Add `tools/portrait_swap_test.gd` (8 assertions)
- [x] Move proof screenshots to `screenshots/art_audit/`

## Action items still open

- [ ] (Tier 3) Capture radio state art proof or delete the 4 PNGs
- [ ] (Tier 3) Decide whether threat_*.png + atmosphere_vignette ship
- [ ] (Tier 4) Eventually drop overlay/waveform/zombie_shadow PNGs

## Files consumed this PR (no longer "unused")

| File | Size | New consumer |
|---|---|---|
| `actor_player_front.png` | 1.2 MB | `NightShiftGame._draw_player` idle facing down |
| `actor_player_back.png` | 1.2 MB | `NightShiftGame._draw_player` idle facing up |
| `actor_player_side.png` | 1.2 MB | `NightShiftGame._draw_player` idle facing left/right (mirrored) |
| `icon_door_reinforce.png` | varies | day card: door_reinforce, back_door_bar, final_barricade |
| `icon_window_brace.png` | varies | day card: window_brace, second_plank, double_brace |
| `icon_battery_buffer.png` | varies | day card: battery_buffer, floodlights, signal_battery |
| `icon_generator_tune.png` | varies | day card: generator_tune, generator_cage |
| `icon_radio_booster.png` | varies | day card: radio_booster, antenna_anchor, quiet_hours, cable_route, radio_beacon |
| `icon_workbench.png` | varies | day card: workbench, command_routine, runner_path, elias_tools, all_hands |
| `icon_storage.png` | varies | day card: storage, salvage_planks, victor_cache |
| `icon_medbay.png` | varies | day card: medbay, medbay_lamp, nora_kit |
| `portrait_player.png` | varies | BaseScreen default fallback for Mara/Victor/others |
| `portrait_nora.png` | varies | BaseScreen Nora Quinn / a_qing row |
| `portrait_elias.png` | varies | BaseScreen Elias Reed / shen_luo row |
