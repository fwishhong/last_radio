# Unused Art Inventory — Last Radio

> Filed after the R2 hotspot-art audit (2026-06-20). All assets below are
> shipped in `assets/final/night_shift/` but the runtime never references
> them. Either they need to be wired up, or they should be marked
> "for next chapter" / deleted to keep the repo lean.

## Quick stats

- 47 PNG files in `assets/final/night_shift/` (≈3 MB) not consumed at runtime.
- `NightShiftArt.load_upgrade_icon_textures()` loads 27 icons into
  `art["icons"]`, but `_update_visual_feedback()` / upgrade cards /
  event cards never read from that dict.
- `art["hotspots"]` had the same issue until R2 hot-fix; all 36
  hotspot textures are now consumed via `NightShiftArt.hotspot_texture_key()`.

## Group 1 — Upgrade / event icons (35 files)

The `art["icons"]` and `art["events"]` buckets are loaded at startup
but no consumer ever reads `art["icons"][key]` or `art["events"][key]`.
Upgrade card render in `BaseScreen.gd` and the day-card picker use
hard-coded TextLabels instead.

### Icon bucket — 27 keys, 8 unique source PNGs

`scripts/NightShiftArt.gd:45` maps keys like `door_reinforce`,
`window_brace`, `battery_buffer` etc. to a small pool of base icons.
The 27 entries all funnel into 8 source files:

| Key (consumer-facing) | Source PNG |
|---|---|
| `door_reinforce`, `back_door_bar`, `final_barricade` | `icon_door_reinforce.png` |
| `window_brace`, `second_plank`, `double_brace` | `icon_window_brace.png` |
| `battery_buffer`, `floodlights`, `signal_battery` | `icon_battery_buffer.png` |
| `generator_tune`, `generator_cage` | `icon_generator_tune.png` |
| `radio_booster`, `antenna_anchor`, `quiet_hours`, `cable_route`, `radio_beacon` | `icon_radio_booster.png` |
| `workbench`, `command_routine`, `runner_path`, `elias_tools`, `all_hands` | `icon_workbench.png` |
| `storage`, `salvage_planks`, `victor_cache` | `icon_storage.png` |
| `medbay`, `medbay_lamp`, `nora_kit` | `icon_medbay.png` |

### Event art — 27 unique files

`scripts/NightShiftArt.gd:76` loads `event_*.png` per key. Same
situation: the day-card picker in `_show_day` does not draw these.

The full list: `event_all_hands.png`, `event_antenna_anchor.png`,
`event_back_door_bar.png`, `event_battery_cache.png`,
`event_cable_route.png`, `event_command_routine.png`,
`event_door_reinforce.png`, `event_double_brace.png`,
`event_elias_tools.png`, `event_final_barricade.png`,
`event_find_planks.png`, `event_floodlights.png`,
`event_generator_cage.png`, `event_generator_tune.png`,
`event_medbay.png`, `event_medbay_lamp.png`,
`event_nora_kit.png`, `event_quiet_hours.png`,
`event_radio_antenna.png`, `event_radio_beacon.png`,
`event_runner_path.png`, `event_salvage_planks.png`,
`event_second_plank.png`, `event_signal_battery.png`,
`event_storage.png`, `event_victor_cache.png`,
`event_window_brace.png`, `event_workbench.png`.

**To fix:** wire `_show_day` and `BaseScreen._show_upgrade_card` to
read from `art["icons"][key]` and `art["events"][key]` (or refactor to
inline the lookup in `NightShiftArt.upgrade_icon_key()`).

## Group 2 — HUD / overlay / waveform (5 files)

The HUD panel and FX overlays are drawn procedurally with `draw_rect`
in `scripts/NightShiftGame.gd` instead of using the art assets.

| File | Size | Where the runtime draws its own version |
|---|---|---|
| `hud_status_panel.png` | 410 KB | `_draw_status_bar()` uses ColorRect panels |
| `overlay_blackout.png` | 95 KB | `_draw_blackout_overlay()` uses `draw_rect` with alpha |
| `overlay_danger_pulse.png` | 77 KB | `_draw_danger_overlay()` uses `draw_rect` |
| `radio_waveform_strip.png` | 82 KB | `RadioTuningPanel.gd` uses `Line2D` shapes |
| `upgrade_card_frame.png` | 164 KB | `BaseScreen.gd` uses `StyleBoxFlat` |

**To fix:** swap procedural rectangles for the art textures where they
improve readability, or remove the art files if procedural is preferred.

## Group 3 — Radio state art (4 files)

`radio_idle.png`, `radio_calling.png`, `radio_connected.png`,
`radio_missed.png` — loaded into `art["hotspots"]["radio_*"]` and
correctly addressed by `NightShiftArt.hotspot_texture_key()` for
`kind == "radio"`, BUT the radio hotspot is unlocked only on Night 3+.
The full-flow smoke test (`night_shift_full_flow_test`) verifies
contacts on Night 3, but no existing visual capture proves the radio
texture actually renders. Add `screenshots/art_audit/radio_states.png`
once captured.

## Group 4 — Zombie decorations (4 files)

`zombie_shadow_single.png`, `zombie_shadow_pair.png`,
`zombie_shadow_crowd.png`, `zombie_hands_reach.png` — designed as
mid-room background decoration (silhouettes against the windows / walls).
The runtime uses 4 large outside-zombie sprites only
(`zombie_outside_door_approach/breach`, `zombie_outside_window_*/`),
positioned off-screen and animated by `WorldLayerFx`.

**To fix:** add a `mid_room_decoration_layer` populated at night
start, with z-order BELOW the room background but above the world
parallax. Or remove the files if next chapter doesn't use them.

## Group 5 — Portraits (3 files)

`portrait_player.png`, `portrait_nora.png`, `portrait_elias.png` —
close-up bust versions. `BaseScreen.gd` uses the wider
`character_*.png` set for the day picker.

**To fix:** swap `BaseScreen` references to use `portrait_*` instead
of `character_*`, or delete.

## Group 6 — Actor views (3 files)

`actor_player_back.png`, `actor_player_front.png`,
`actor_player_side.png` — appear to be a top-down + 3/4 view set for
the player. `NightShiftActors.gd` exists but is not referenced from
`NightShiftGame._draw_player`. Player is rendered from the 12-frame
walk sprites in `player_walk/`.

**To fix:** wire `NightShiftActors` into `_draw_player` to switch
between walk (movement) and idle (standing still) actor art. Or
remove both `NightShiftActors.gd` and the actor PNGs.

## Group 7 — Threat indicators (4 files)

`threat_back_door.png`, `threat_front_door.png`,
`threat_left_window.png`, `threat_right_window.png` — directional
threat markers. The runtime uses red/amber rings + telegraph dots via
`NightShiftFx` and `HotspotDot` instead.

**To fix:** if Chapter 2 introduces a more visible threat-callout
system, these become the per-barrier arrows. Otherwise remove.

## Group 8 — Atmosphere vignette (1 file)

`atmosphere_vignette.png` — 41 KB, designed to darken the screen
edges at night. Currently `WorldLayerFx` only animates world-layer
parallax; no vignette compositing pass exists.

**To fix:** add a `CanvasLayer` with a `TextureRect` overlay using
this asset, modulating alpha with night-elapsed time. Or remove.

## Recommendation

1. **Group 1 (icons / events):** wire in — highest payoff. The
   `NightShiftArt` helpers are already there; this is a 1-day task.
2. **Group 3 (radio states):** add to art audit after wiring Group 1.
3. **Group 6 (actors):** decide between wiring for richer standing-
   still rendering, or deleting both script + art.
4. **Groups 2, 4, 5, 7, 8:** schedule for a future "polish pass" — none
   are blocking release.

Track as a single feature ticket:
**"Wire remaining shipped-but-unused art assets into the night-game
runtime"** — est. 1-2 days of focused work.
