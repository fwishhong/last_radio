extends SceneTree

# NightShiftGame v0.5 rewrite - basic smoke test
# Validates: cover -> day -> night -> night_report -> next_night minimum loop.
# The legacy tools/night_shift_smoke_test.gd validates the full v0.5 feature set
# (director events, time-scale toggle, story timeline, ...) and stays as the
# target for future v0.5 expansion. This test only asserts the parts implemented
# in the current rewrite.

var failed: bool = false
var passed: int = 0

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	_expect(scene != null, "NightShiftGame scene loads")
	if scene == null:
		quit(1)
		return

	var game: Node = scene.instantiate()
	root.add_child(game)
	# Wait one frame so _ready runs
	await process_frame

	# 1) Cover phase
	_expect(str(game.get("phase")) == "cover", "starts in cover phase")

	# 2) Data loaded
	var data_node = game.get("data")
	_expect(data_node != null, "NightShiftData loaded")
	if data_node != null:
		_expect(int(game.get("night_count")) == 10, "10 nights loaded from chapter_01_nights.json")

	# 3) Hotspot data is set up
	_expect(game.has_method("_show_cover"), "main script exposes phase methods")

	# 4) Trigger start
	game.call("_on_start_pressed")
	await process_frame
	_expect(str(game.get("phase")) == "day", "cover -> day after start")

	# 5) Force into night 1 (bypassing day card selection)
	game.call("_show_night")
	await process_frame
	_expect(str(game.get("phase")) == "night", "day -> night")
	var hotspots: Dictionary = game.get("hotspots")
	_expect(hotspots.has("front_door"), "night 1 unlocks front_door")
	_expect(hotspots.has("left_window"), "night 1 unlocks left_window")
	_expect(hotspots.has("generator"), "night 1 unlocks generator")
	_expect(not hotspots.has("right_window"), "right_window locked on night 1")
	_expect(not hotspots.has("radio"), "radio locked on night 1")

	# 6) Night duration comes from JSON
	var dur: float = float(game.get("night_duration"))
	_expect(dur > 0.0 and dur <= 120.0, "night 1 duration in expected range (got %s)" % dur)

	# 7) Simulate time advance + ensure update is safe
	game.set("night_elapsed", 0.0)
	game.call("_update_night", 1.0)
	_expect(float(game.get("night_elapsed")) >= 1.0, "night_elapsed advances by dt")

	# 8) End night successfully
	game.set("night_elapsed", 999.0)
	game.call("_update_night", 0.0)
	_expect(str(game.get("phase")) == "night_report", "night -> night_report when time runs out")
	_expect(bool(game.get("survived")) == true, "night 1 success flag set")

	# 9) Continue to night 2
	game.call("_on_report_continue", true)
	await process_frame
	_expect(int(game.get("night_index")) == 1, "night_index advances to 1")
	_expect(str(game.get("phase")) == "day", "back to day for night 2")

	# 10) Hotspot click target update
	game.call("_show_night")
	await process_frame
	# Set player right next to front_door (uses real hotspot position from HOTSPOT_POSITIONS).
	var front_door_pos: Vector2 = (game.get("HOTSPOT_POSITIONS") as Dictionary)["front_door"]
	game.set("player_pos", front_door_pos)
	game.set("player_target_id", "front_door")
	game.call("_update_player_target_reached")
	_expect(bool(game.get("player_at_target")) == true, "player_at_target true when on hotspot")

	# 11) Repair effect
	var h: Dictionary = game.get("hotspots")["front_door"]
	h["value"] = 50.0
	game.get("hotspots")["front_door"] = h
	game.call("_update_night", 1.0)
	var after_value: float = float(game.get("hotspots")["front_door"]["value"])
	_expect(after_value > 50.0, "repair increases hotspot value (50 -> %s)" % after_value)

	# 12) Logs accumulate
	var logs: Array = game.get("logs")
	_expect(logs.size() > 0, "logs array non-empty after simulation")

	# 13) Failure path: force a hotspot to 0
	var h2: Dictionary = game.get("hotspots")["front_door"]
	h2["value"] = 0.0
	h2["breach_timer"] = 0.0
	game.get("hotspots")["front_door"] = h2
	# Walk past grace period
	game.call("_update_night", 2.0)
	_expect(str(game.get("phase")) == "night_report", "breach -> night_report")
	_expect(bool(game.get("survived")) == false, "failure flag set after breach")

	# Done
	game.queue_free()
	await process_frame
	if failed:
		print("NightShiftGame basic smoke test: FAIL (passed=%d)" % passed)
		quit(1)
	else:
		print("NightShiftGame basic smoke test: PASS (passed=%d)" % passed)
		quit(0)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  ok: %s" % msg)
	else:
		failed = true
		print("  FAIL: %s" % msg)
