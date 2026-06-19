extends SceneTree
# Save/load test — round-trips a game state through NightShiftSave.

const Save := preload("res://scripts/NightShiftSave.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run()


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _run() -> void:
	print("=== Save/load test ===")
	# Clean before
	Save.clear_save()
	_assert(not Save.has_save(), "no save before write")

	var state := {
		"night_index": 4,
		"resources": {"planks": 3, "parts": 2, "battery": 1, "medicine": 0, "exposure": 1, "trust": 2},
		"upgrades": {"start": true, "door_reinforce": true, "window_brace": true, "antenna_anchor": true},
		"allies": {"nora": true, "elias": true, "victor": true},
		"unlocked_hotspots": ["front_door", "left_window", "right_window", "generator", "radio", "antenna"],
		"radio_available": true,
		"radio_completed": false,
		"blackout": false,
		"radio_contact_goal": 2,
		"radio_window_left": 12.5,
	}
	var ok: bool = Save.write(state)
	_assert(ok, "write returns true")
	_assert(Save.has_save(), "save file exists after write")

	var doc: Dictionary = Save.read()
	_assert(not doc.is_empty(), "read returns dict")
	_assert(int(doc.get("night_index", -1)) == 4, "night_index roundtrips")
	_assert(int(doc.get("resources", {}).get("planks", -1)) == 3, "planks roundtrips")
	_assert(int(doc.get("resources", {}).get("exposure", -1)) == 1, "exposure roundtrips")
	_assert(bool(doc.get("upgrades", {}).get("door_reinforce", false)), "door_reinforce upgrade persists")
	_assert(int(doc.get("upgrades", {}).get("window_brace", 0)) == 1, "window_brace upgrade persists")
	_assert(bool(doc.get("allies", {}).get("nora", false)), "nora ally persists")
	_assert(bool(doc.get("allies", {}).get("elias", false)), "elias ally persists")
	_assert((doc.get("unlocked_hotspots", []) as Array).size() == 6, "6 hotspots persisted")
	_assert(int(doc.get("radio_contact_goal", 0)) == 2, "radio_contact_goal persists")
	_assert(is_equal_approx(float(doc.get("radio_window_left", 0.0)), 12.5), "radio_window_left persists")
	_assert(int(doc.get("version", 0)) == Save.SAVE_VERSION, "version matches")

	# Mutate and rewrite
	state["night_index"] = 7
	state["resources"]["planks"] = 9
	Save.write(state)
	var doc2: Dictionary = Save.read()
	_assert(int(doc2.get("night_index", -1)) == 7, "rewritten night_index = 7")
	_assert(int(doc2.get("resources", {}).get("planks", -1)) == 9, "rewritten planks = 9")

	# Clear
	Save.clear_save()
	_assert(not Save.has_save(), "save cleared")

	print("Save/load test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	quit(0 if failed == 0 else 1)
