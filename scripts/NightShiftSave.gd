extends RefCounted
class_name NightShiftSave

const SAVE_FILE_PREFIX := "user://night_shift_save_"

static func save(game: Node, slot: int = 0) -> bool:
	var data := _collect_state(game)
	var path := "%s%03d.json" % [SAVE_FILE_PREFIX, slot]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var json_text := JSON.stringify(data, "\t", false)
	file.store_string(json_text)
	file.close()
	return true

static func load(game: Node, slot: int = 0) -> bool:
	var path := "%s%03d.json" % [SAVE_FILE_PREFIX, slot]
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		return false
	var data: Dictionary = json.data
	return _restore_state(game, data)

static func has_save(slot: int) -> bool:
	var path := "%s%03d.json" % [SAVE_FILE_PREFIX, slot]
	return FileAccess.file_exists(path)

static func delete_save(slot: int) -> void:
	var path := "%s%03d.json" % [SAVE_FILE_PREFIX, slot]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

static func list_saves() -> Array[int]:
	var result: Array[int] = []
	var dir := DirAccess.open("user://")
	if dir == null:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("night_shift_save_"):
			var suffix := file_name.trim_prefix("night_shift_save_").trim_suffix(".json")
			if suffix.is_valid_int():
				result.append(int(suffix))
		file_name = dir.get_next()
	dir.list_dir_end()
	result.sort()
	return result

static func _collect_state(game: Node) -> Dictionary:
	return {
		"version": 1,
		"phase": game.get("phase"),
		"current_level_index": game.get("current_level_index"),
		"night_elapsed": game.get("night_elapsed"),
		"blackout": game.get("blackout"),
		"radio_available": game.get("radio_available"),
		"radio_missed": game.get("radio_missed"),
		"radio_completed": game.get("radio_completed"),
		"radio_call_started_at": game.get("radio_call_started_at"),
		"radio_contacts_done": game.get("radio_contacts_done"),
		"game_over": game.get("game_over"),
		"outcome": game.get("outcome"),
		"last_night_success": game.get("last_night_success"),
		"first_door_hint_done": game.get("first_door_hint_done"),
		"plank_cooldown": game.get("plank_cooldown"),
		"director_event_count": game.get("director_event_count"),
		"night_seed": game.get("night_seed"),
		"allies": game.get("allies").duplicate(),
		"upgrades": game.get("upgrades").duplicate(),
		"events_done": game.get("events_done").duplicate(),
		"player_pos": {"x": game.get("player_pos").x, "y": game.get("player_pos").y},
		"player_target_id": game.get("player_target_id"),
		"nora_pos": {"x": game.get("nora_pos").x, "y": game.get("nora_pos").y},
		"nora_target_id": game.get("nora_target_id"),
		"elias_pos": {"x": game.get("elias_pos").x, "y": game.get("elias_pos").y},
		"elias_target_id": game.get("elias_target_id"),
		"hotspots": _collect_hotspots(game),
		"logs": game.get("logs").duplicate()
	}

static func _collect_hotspots(game: Node) -> Dictionary:
	var raw: Dictionary = game.get("hotspots", {})
	var result := {}
	for key in raw.keys():
		var h: Dictionary = raw[key]
		result[key] = {
			"value": h.get("value", 100.0),
			"pressure": h.get("pressure", 0.0),
			"active": h.get("active", false),
			"assault": h.get("assault", false),
			"warning": h.get("warning", false),
			"braced": h.get("braced", false),
			"temp_seal": h.get("temp_seal", 0.0),
			"breach_timer": h.get("breach_timer", -1.0)
		}
	return result

static func _restore_state(game: Node, data: Dictionary) -> bool:
	if int(data.get("version", 0)) < 1:
		return false
	game.set("phase", data.get("phase", "day"))
	game.set("current_level_index", data.get("current_level_index", 0))
	game.set("night_elapsed", data.get("night_elapsed", 0.0))
	game.set("blackout", data.get("blackout", false))
	game.set("radio_available", data.get("radio_available", false))
	game.set("radio_missed", data.get("radio_missed", false))
	game.set("radio_completed", data.get("radio_completed", false))
	game.set("radio_call_started_at", data.get("radio_call_started_at", -1.0))
	game.set("radio_contacts_done", data.get("radio_contacts_done", 0))
	game.set("game_over", data.get("game_over", false))
	game.set("outcome", data.get("outcome", ""))
	game.set("last_night_success", data.get("last_night_success", false))
	game.set("first_door_hint_done", data.get("first_door_hint_done", false))
	game.set("plank_cooldown", data.get("plank_cooldown", 0.0))
	game.set("director_event_count", data.get("director_event_count", 0))
	game.set("night_seed", data.get("night_seed", 0))
	game.set("player_pos", Vector2(data.get("player_pos", {}).get("x", 0.0), data.get("player_pos", {}).get("y", 0.0)))
	game.set("player_target_id", data.get("player_target_id", ""))
	game.set("nora_pos", Vector2(data.get("nora_pos", {}).get("x", 0.0), data.get("nora_pos", {}).get("y", 0.0)))
	game.set("nora_target_id", data.get("nora_target_id", ""))
	game.set("elias_pos", Vector2(data.get("elias_pos", {}).get("x", 0.0), data.get("elias_pos", {}).get("y", 0.0)))
	game.set("elias_target_id", data.get("elias_target_id", ""))
	game.set("upgrades", data.get("upgrades", {}).duplicate())
	game.set("events_done", data.get("events_done", {}).duplicate())
	game.set("logs", data.get("logs", []).duplicate())
	_restore_hotspots(game, data.get("hotspots", {}))
	var allies_data: Dictionary = data.get("allies", {})
	game.set("allies", allies_data.duplicate())
	return true

static func _restore_hotspots(game: Node, hotspot_data: Dictionary) -> void:
	var hotspots: Dictionary = game.get("hotspots", {})
	for key in hotspot_data.keys():
		if not hotspots.has(key):
			continue
		var saved: Dictionary = hotspot_data[key]
		var current: Dictionary = hotspots[key]
		current["value"] = saved.get("value", current.get("value", 100.0))
		current["pressure"] = saved.get("pressure", current.get("pressure", 0.0))
		current["active"] = saved.get("active", current.get("active", false))
		current["assault"] = saved.get("assault", current.get("assault", false))
		current["warning"] = saved.get("warning", current.get("warning", false))
		current["braced"] = saved.get("braced", current.get("braced", false))
		current["temp_seal"] = saved.get("temp_seal", current.get("temp_seal", 0.0))
		current["breach_timer"] = saved.get("breach_timer", current.get("breach_timer", -1.0))
		hotspots[key] = current
	game.set("hotspots", hotspots)
