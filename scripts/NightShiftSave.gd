class_name NightShiftSave
extends RefCounted
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
const SAVE_VERSION := 3

# Difficulty: 0 = normal, 1 = hard. Stored per-slot.
const DIFFICULTY_NORMAL := 0
const DIFFICULTY_HARD := 1


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
static func slot_summary(slot: int) -> Dictionary:
	# Returns:
	#   {exists: bool, night_index: int, saved_at: int, difficulty: int, ng_plus: int}
	if not _slot_exists(slot):
		return {"exists": false, "night_index": -1, "saved_at": 0, "difficulty": DIFFICULTY_NORMAL, "ng_plus": 0}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {"exists": false, "night_index": -1, "saved_at": 0, "difficulty": DIFFICULTY_NORMAL, "ng_plus": 0}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"exists": false, "night_index": -1, "saved_at": 0, "difficulty": DIFFICULTY_NORMAL, "ng_plus": 0}
	return {
		"exists": true,
		"night_index": int((parsed as Dictionary).get("night_index", 0)),
		"saved_at": int((parsed as Dictionary).get("saved_at", 0)),
		"difficulty": int((parsed as Dictionary).get("difficulty", DIFFICULTY_NORMAL)),
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
		"difficulty": int(state.get("difficulty", DIFFICULTY_NORMAL)),
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
