# Radio Design — Last Radio Night Shift

> Single source of truth for the radio contact mini-game and its reward hooks.
> Read this before changing `scripts/NightShiftGame.gd`, `scripts/NightShiftData.gd`,
> `data/night_shift/signals.json`, or any per-night radio fields in
> `data/night_shift/chapter_01_nights.json`.

## Player-facing summary

The radio is a **dial-and-hold** mini-game that fires when an event of type
`radio` triggers during a night. While the radio is active:

1. A 30-second window opens (modified by `radio_window` day-card effects).
2. The player must walk to the **radio** hotspot and stand on it.
3. Inside the radio panel (visible only while standing at the hotspot) are
   three channel buttons. The player picks one to "tune" to.
4. If the tuned channel matches the **target channel for that night**, the
   contact progress bar fills over 3 seconds. A contact is scored.
5. If the tuned channel is wrong, the progress bar does not fill. Some
   "wrong" channels (e.g. `static`) charge +0.5 exposure the first time
   they are tuned to in a night.
6. When all contacts are made (goal is 1 by default, +1 per
   `radio_booster` day card), the radio is **completed**.
7. If the window expires before all contacts are made, the radio is
   **missed** and exposure goes up.

Each night that has a radio event can declare its own channels and target.
The global catalog `data/night_shift/signals.json` defines the available
channel ids and their visual / mechanical defaults.

## Architecture

```
chapter_01_nights.json  ── per-night: radio_channels[], radio_target_channel
                            │
                            ▼
NightShiftData.load_all() ── reads signals.json
                            │
                            ▼
data.signals / signal_by_id ── get_signal(id) / get_signal_catalog()
                            │
                            ▼
NightShiftGame._show_night() builds radio_channels_catalog
                            │
                            ▼
radio_panel UI (3 channel buttons + progress bar)
                            │
                            ▼
_update_radio(delta) ─► _complete_radio_contact() (success)
                    ─► _apply_exposure_delta(1, "missed window") (timeout)
                    ─► _apply_exposure_delta(exposure_on_wrong, "wrong channel X")
                    ─► _apply_trust_delta(1, "radio contact")
```

## Data files

### `data/night_shift/signals.json`

Global catalog of channel ids. Each entry:

| Field | Type | Notes |
|---|---|---|
| `id` | string | Unique channel id (e.g. `victor`, `elias`, `static`). Used by code and data. |
| `label` | string | Display name shown on the channel button. |
| `desc` | string | One-line description shown inside the button. |
| `color` | string | Hex color (`#RRGGBB`) for the button border. |
| `exposure_on_wrong` | float | Exposure added when the player tunes here and it isn't the target. Only charged once per channel per night. |
| `voice` | string | (Optional) id of a voice acting sample. Reserved for future audio. |
| `wrong_signal` | string | (Optional) id of a "wrong signal" sting played when this channel is tuned by mistake. |

Entries missing any field default to safe values: empty label, empty desc,
`#9CD9FF` color, 0 exposure, empty voice / wrong_signal. Entries without
`id` are dropped.

### `data/night_shift/chapter_01_nights.json` — per-night fields

Each night can declare:

```json
{
  "radio_channels": [
    {"id": "victor", "label": "Victor", "desc": "...", "color": "#FFD27F"},
    {"id": "elias", "label": "Elias", "desc": "...", "color": "#9CD9FF"},
    {"id": "static", "label": "干扰", "desc": "...", "color": "#C97C7C"}
  ],
  "radio_target_channel": "elias"
}
```

- `radio_channels` overrides the global catalog for that night (3 buttons
  normally, can be 2-3).
- `radio_target_channel` is the id the player must tune to for contacts to
  score. Empty / null = no radio for that night (the radio panel will not
  appear).
- Nights without these fields still work — they get the global catalog and
  no target (player can tune but no progress will ever fill). Set
  `radio_target_channel` to `null` explicitly for nights with no radio to
  keep tests honest.

Current targets:

| Night | Target | Reasoning |
|---|---|---|
| 1, 2, 5, 6, 7, 8 | `null` | No radio events. |
| 3 | `elias` | First contact with Elias — the player learns to dial. |
| 4 | `victor` | Victor confirms the coordinates. |
| 9 | `victor` | Victor relays the final coordinates before pursuit. |
| 10 | `victor` | Victor broadcasts the names list — final broadcast. |

## Runtime state

Stored on `NightShiftGame`:

| Field | Type | Purpose |
|---|---|---|
| `radio_available` | bool | True while the radio window is open. |
| `radio_completed` | bool | True once `radio_contacts_made >= radio_contact_goal`. |
| `radio_missed` | bool | True if the window expired before completion. |
| `radio_contact_goal` | int | 1 + sum of `radio_contact_goal` day-card effects. |
| `radio_window_left` | float | Seconds remaining in the radio window. |
| `radio_tuned_channel` | String | Channel id the player is currently tuned to (empty = not tuned). |
| `radio_target_channel` | String | The id that scores contacts this night. |
| `radio_channels_catalog` | Array | Channel entries (id / label / desc / color / exposure_on_wrong) used to build the panel. |
| `radio_contact_progress` | float | Seconds the player has stood at the radio on the correct channel. Resets each contact. |
| `radio_contacts_made` | int | Number of successful contacts so far this night. |
| `radio_wrong_ticks` | Dictionary | `{channel_id: true}` — set when exposure has been charged for that channel this night. Prevents double-charging on long stands. |

## Reward hooks

Implemented in three small helper functions in `scripts/NightShiftGame.gd`:

| Trigger | Effect |
|---|---|
| `_complete_radio_contact()` | `_apply_trust_delta(+1, "radio contact")` |
| Window timer hits 0 | `_apply_exposure_delta(+1, "missed window")` |
| Stand at radio tuned to wrong channel | First time per channel per night: `_apply_exposure_delta(channel.exposure_on_wrong, "wrong channel X")` |

All deltas go through `data.apply_resource_delta` so values are clamped to
each resource's `min` / `max`. The `night_stats` dict on the report screen
exposes `radio_contacts` (always non-decreasing for the night) so the
report screen always reflects what happened, even on a failure.

## Save / load

`NightShiftSave` is at schema v2. It carries the radio fields:

| Field | Type | Notes |
|---|---|---|
| `radio_available` | bool | |
| `radio_completed` | bool | |
| `radio_missed` | bool | |
| `radio_contact_goal` | int | |
| `radio_window_left` | float | |
| `radio_tuned_channel` | String | Empty if not tuned. |
| `radio_contacts_made` | int | |

Loading an older v1 save is supported — missing fields default to `false /
0 / ""`.

## Adding a new radio night

1. In `chapter_01_nights.json`, add a `radio` event to `fixed_events`.
2. On the same night_def, add `radio_channels` (3 entries) and
   `radio_target_channel` (one of the channel ids).
3. (Optional) Add new channels to `signals.json` if you need a new id.
4. Run `tools/night_shift_full_flow_test.gd` — the new night is exercised
   by the night loop and the radio flow asserts the catalog loads.
5. Capture a screenshot with `tools/capture_night_shift_screens.gd` and
   inspect `user://last_radio_screens/`.

## Test coverage

| Test | What it covers |
|---|---|
| `tools/radio_contact_test.gd` | Single contact, multi-goal, missed window, progress bleed when stepping away, wrong-channel no-progress, wrong-channel exposure (once per session), success trust gain. |
| `tools/night_shift_full_flow_test.gd` | Radio fires on night 3 in the full 10-night campaign and a contact completes. |
| `tools/signal_catalog_test.gd` | (See `signal_catalog_test.gd`.) Catalog loads, missing fields are defaulted, malformed JSON falls back to hard-coded list. |

## Known limitations

- Audio voices (`voice`, `wrong_signal`) are not yet wired to actual audio
  playback. The catalog fields exist so adding audio is a content-only
  change.
- The radio panel is hidden while the player isn't on the radio hotspot,
  but the channel buttons are still keyboard-inert. A future iteration
  could allow dialing the radio from a short distance for accessibility.
- Window length (`radio_window_left`) is decremented per-frame; if the
  night has multiple radio events (none currently do) the window would
  restart — see `_trigger_event` if extending.