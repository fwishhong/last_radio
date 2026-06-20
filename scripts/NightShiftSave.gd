class_name NightShiftSave
extends RefCounted

# I18n is only used for preset_label() — slot covers and the difficulty
# picker show the preset name, and we want it localized. Preload rather
# than class_name to avoid relying on the global script cache.
const I18nRef := preload("res://scripts/I18n.gd")

# Multi-slot save/load. 3 slots, each is a separate file:
#   user://saves/slot_1.json
#   user://saves/slot_2.json
#   user://saves/slot_3.json
# Each file contains: night_index, resources, upgrades, allies, unlocked_hotspots,
#                     radio_available, radio_completed, radio_missed, blackout,
#                     radio_contact_goal, radio_window_left, radio_tuned_channel,
#                     radio_contacts_made, tutorial_done, difficulty, ng_plus_count.
# Plus a version + timestamp.
# v3: adds tutorial_done, difficulty, ng_plus_count. v2 saves (single-slot
#     under last_radio_chapter_01.json) are auto-migrated to slot 1 on first
#     read via `migrate_legacy_if_needed()`.

const SAVE_DIR := "user://saves"
const LEGACY_SAVE_PATH := SAVE_DIR + "/last_radio_chapter_01.json"  # v2 single-slot
const SLOT_COUNT := 3
# v4: adds current_difficulty (String) + difficulty_modifiers (Dictionary).
#     The integer DIFFICULTY_NORMAL/HARD field is kept for legacy v3 saves
#     (read-only); writes always use the new shape.
const SAVE_VERSION := 4

# Difficulty presets and per-axis modifiers.
#
# The legacy binary "normal / hard" choice is kept for back-compat with
# existing saves (slot files written before the slider UI shipped still
# load), but new slots use the preset-name string + modifier dict shape:
#
#   current_difficulty: String = "casual" | "standard" | "hard" | "custom"
#   difficulty_modifiers: Dictionary = {
#     "enemy_count":   float 0.5..2.0,   default 1.0
#     "drain_rate":    float 0.5..1.5,   default 1.0
#     "player_speed":  float 0.85..1.20, default 1.0
#     "telegraph":     float 1.0..3.0,   default 2.0  (seconds lead time)
#     "breach_grace":  float 1.0..3.0,   default 1.5  (seconds before fail)
#   }
#
# When a player picks a preset the modifier dict is set to that preset's
# canonical values. When they move a slider by hand, current_difficulty
# switches to "custom" so the UI can show "Custom" as the active preset.
const DIFFICULTY_NORMAL := 0
const DIFFICULTY_HARD := 1

const DIFFICULTY_PRESETS := {
	"casual": {
		"enemy_count": 0.7,
		"drain_rate": 0.75,
		"player_speed": 1.10,
		"telegraph": 2.6,
		"breach_grace": 2.2,
	},
	"standard": {
		"enemy_count": 1.0,
		"drain_rate": 1.0,
		"player_speed": 1.0,
		"telegraph": 2.0,
		"breach_grace": 1.5,
	},
	"hard": {
		"enemy_count": 1.5,
		"drain_rate": 1.25,
		"player_speed": 0.92,
		"telegraph": 1.4,
		"breach_grace": 1.0,
	},
}

# Hard bounds for the sliders. Both UI clamp and validation read from this.
const DIFFICULTY_BOUNDS := {
	"enemy_count":  {"min": 0.5,  "max": 2.0,  "step": 0.05},
	"drain_rate":   {"min": 0.5,  "max": 1.5,  "step": 0.05},
	"player_speed": {"min": 0.85, "max": 1.20, "step": 0.01},
	"telegraph":    {"min": 1.0,  "max": 3.0,  "step": 0.1},
	"breach_grace": {"min": 1.0,  "max": 3.0,  "step": 0.1},
}

const MODIFIER_KEYS := ["enemy_count", "drain_rate", "player_speed", "telegraph", "breach_grace"]


# Return the modifier dict for a preset name (or "standard" if unknown).
static func modifiers_for_preset(preset: String) -> Dictionary:
	if DIFFICULTY_PRESETS.has(preset):
		return (DIFFICULTY_PRESETS[preset] as Dictionary).duplicate(true)
	return (DIFFICULTY_PRESETS["standard"] as Dictionary).duplicate(true)


# Clamp + normalize a modifier dict to the allowed bounds. Used both when
# reading a save (in case bounds changed between versions) and when writing.
static func normalize_modifiers(mods: Variant) -> Dictionary:
	var out := modifiers_for_preset("standard")
	if not (mods is Dictionary):
		return out
	var src: Dictionary = mods
	for k in MODIFIER_KEYS:
		if src.has(k):
			var bounds: Dictionary = DIFFICULTY_BOUNDS[k]
			out[k] = clamp(float(src[k]), float(bounds["min"]), float(bounds["max"]))
	return out


# True if `mods` matches a named preset exactly (so the UI can show the
# preset name instead of "Custom"). Used by the difficulty picker.
static func matches_preset(mods: Dictionary) -> String:
	for preset_name in DIFFICULTY_PRESETS:
		var p: Dictionary = DIFFICULTY_PRESETS[preset_name]
		var ok := true
		for k in MODIFIER_KEYS:
			if abs(float(mods.get(k, 0.0)) - float(p[k])) > 0.001:
				ok = false
				break
		if ok:
			return preset_name
	return "custom"


# Localized label for a preset name. Falls back to the raw name if the
# I18n key is missing.
static func preset_label(preset: String) -> String:
	if not I18nRef or I18nRef.dicts.is_empty():
		return preset.capitalize()
	var key: String = "difficulty_preset_%s" % preset
	var raw: String = I18nRef.t(key)
	if raw == key:
		return preset.capitalize()
	return raw


# ---------- per-slot paths ----------

static func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


# ---------- public API ----------

static func has_save() -> bool:
	# Used by old code. Now means "any slot has data". Prefer has_slot for new code.
	return has_any_slot()


static func has_any_slot() -> bool:
	for s in range(1, SLOT_COUNT + 1):
		if _slot_exists(s):
			return true
	return false


static func has_slot(slot: int) -> bool:
	return _slot_exists(slot)


static func write(state: Dictionary, slot: int = 1) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		push_error("NightShiftSave: invalid slot %d" % slot)
		return false
	_ensure_save_dir()
	var path := slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("NightShiftSave cannot open for write: %s" % path)
		return false
	var body := _build_body(state)
	file.store_string(JSON.stringify(body, "  "))
	file.close()
	return true


static func read(slot: int = 1) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {}
	if not _slot_exists(slot):
		return {}
	var path := slot_path(slot)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {}
	var doc: Dictionary = parsed
	if int(doc.get("version", 0)) != SAVE_VERSION:
		push_warning("NightShiftSave: save version mismatch in slot %d (have %s, want %s)" % [slot, doc.get("version", 0), SAVE_VERSION])
		return {}
	return doc


static func clear_save() -> void:
	# Used by old code. Now clears all slots.
	clear_all_slots()


static func clear_slot(slot: int) -> void:
	if slot < 1 or slot > SLOT_COUNT:
		return
	var path := slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func clear_all_slots() -> void:
	for s in range(1, SLOT_COUNT + 1):
		clear_slot(s)


# Quick summary of a slot for the cover screen (no full read needed).
# Returns:
#   {exists: bool, night_index: int, saved_at: int,
#    difficulty: int (legacy 0/1, kept for slot card back-compat),
#    current_difficulty: String ("casual"/"standard"/"hard"/"custom"),
#    difficulty_modifiers: Dictionary,
#    ng_plus: int}
static func slot_summary(slot: int) -> Dictionary:
	var empty := {
		"exists": false, "night_index": -1, "saved_at": 0,
		"difficulty": DIFFICULTY_NORMAL,
		"current_difficulty": "standard",
		"difficulty_modifiers": modifiers_for_preset("standard"),
		"ng_plus": 0,
	}
	if not _slot_exists(slot):
		return empty
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return empty
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return empty
	var legacy_diff: int = int((parsed as Dictionary).get("difficulty", DIFFICULTY_NORMAL))
	var preset_name: String = str((parsed as Dictionary).get("current_difficulty", ""))
	var modifiers: Dictionary = normalize_modifiers((parsed as Dictionary).get("difficulty_modifiers", {}))
	if preset_name == "":
		preset_name = "standard" if legacy_diff == DIFFICULTY_NORMAL else "hard"
		modifiers = modifiers_for_preset(preset_name)
	return {
		"exists": true,
		"night_index": int((parsed as Dictionary).get("night_index", 0)),
		"saved_at": int((parsed as Dictionary).get("saved_at", 0)),
		"difficulty": legacy_diff,
		"current_difficulty": preset_name,
		"difficulty_modifiers": modifiers,
		"ng_plus": int((parsed as Dictionary).get("ng_plus_count", 0)),
	}


# Migration: if a v2 single-slot save exists and all v3 slots are empty,
# move the v2 save into slot 1.
static func migrate_legacy_if_needed() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	# Only migrate if slot 1 is empty
	if _slot_exists(1):
		return
	# Read the v2 save
	var file := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var doc: Dictionary = parsed
	if int(doc.get("version", 0)) != 2:
		return
	# v2 has the same shape as v3 minus tutorial_done / difficulty / ng_plus_count.
	# Default those to 0/false.
	doc["version"] = SAVE_VERSION
	doc["tutorial_done"] = bool(doc.get("tutorial_done", false))
	doc["difficulty"] = int(doc.get("difficulty", DIFFICULTY_NORMAL))
	doc["ng_plus_count"] = int(doc.get("ng_plus_count", 0))
	# Write to slot 1
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var d := DirAccess.open(SAVE_DIR)
		if d == null:
			d = DirAccess.open("user://")
		if d != null:
			d.make_dir_recursive("saves")
	var out := FileAccess.open(slot_path(1), FileAccess.WRITE)
	if out != null:
		out.store_string(JSON.stringify(doc, "  "))
		out.close()
		# Remove the legacy file
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SAVE_PATH))


# ---------- internals ----------

static func _build_body(state: Dictionary) -> Dictionary:
	# Difficulty is stored both as the v3 integer (for back-compat reads)
	# AND as the v4 preset name + modifier dict (writes always use v4).
	var difficulty: int = int(state.get("difficulty", DIFFICULTY_NORMAL))
	var difficulty_name: String = str(state.get("current_difficulty", ""))
	var difficulty_modifiers: Dictionary = normalize_modifiers(state.get("difficulty_modifiers", {}))
	if difficulty_name == "":
		# Infer preset name from legacy integer.
		difficulty_name = "standard" if difficulty == DIFFICULTY_NORMAL else "hard"
	if not DIFFICULTY_PRESETS.has(difficulty_name) or difficulty_name == "custom":
		# Custom / unknown: keep the supplied modifiers, fall back to legacy
		# enum if no modifiers given.
		if difficulty_modifiers.is_empty():
			difficulty_modifiers = modifiers_for_preset(
				"standard" if difficulty == DIFFICULTY_NORMAL else "hard"
			)
	return {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"night_index": int(state.get("night_index", 0)),
		"resources": state.get("resources", {}),
		"upgrades": state.get("upgrades", {}),
		"allies": state.get("allies", {}),
		"unlocked_hotspots": state.get("unlocked_hotspots", []),
		"radio_available": bool(state.get("radio_available", false)),
		"radio_completed": bool(state.get("radio_completed", false)),
		"radio_missed": bool(state.get("radio_missed", false)),
		"blackout": bool(state.get("blackout", false)),
		"radio_contact_goal": int(state.get("radio_contact_goal", 1)),
		"radio_window_left": float(state.get("radio_window_left", 0.0)),
		"radio_tuned_channel": str(state.get("radio_tuned_channel", "")),
		"radio_contacts_made": int(state.get("radio_contacts_made", 0)),
		"tutorial_done": bool(state.get("tutorial_done", false)),
		"difficulty": difficulty,
		"current_difficulty": difficulty_name,
		"difficulty_modifiers": difficulty_modifiers,
		"chapter_id": str(state.get("chapter_id", "chapter_01")),
		"ng_plus_count": int(state.get("ng_plus_count", 0)),
	}


static func _slot_exists(slot: int) -> bool:
	if slot < 1 or slot > SLOT_COUNT:
		return false
	if not FileAccess.file_exists(slot_path(slot)):
		return false
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	return txt.strip_edges() != ""


static func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var d := DirAccess.open(SAVE_DIR)
		if d == null:
			d = DirAccess.open("user://")
		if d != null:
			d.make_dir_recursive("saves")
