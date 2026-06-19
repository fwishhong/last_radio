# Screenshots

This directory holds visual regression captures from
`tools/capture_night_shift_screens.gd`.

**What goes here:**
- `night_shift_v05_*.png` — 16 reference shots of the v0.5 visual state
- `02_night_*.png`, `03_night_*.png` — manual captures from earlier sessions
- Any one-off debug captures

**What's NOT here:**
- End-user data (save files, settings) — those live in `user://`
  (Windows: `%APPDATA%\Godot\app_userdata\Last Radio v2\`)

**Capture command:**
```powershell
& "C:\Users\Administrator\godot_console.exe" --path . --script res://tools/capture_night_shift_screens.gd
```

Note: capture needs the rendering backend — do **not** pass `--headless`.

**Tracked vs ignored:**
PNGs are git-ignored (see `.gitignore`). This file is the only thing
checked in, just to keep the directory present in fresh clones.
