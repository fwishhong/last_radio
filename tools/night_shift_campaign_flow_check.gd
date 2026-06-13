extends SceneTree

var failed := false

const CHOICES := [
	"start",
	"window_brace",
	"radio_booster",
	"antenna_anchor",
	"command_routine",
	"back_door_bar",
	"medbay_lamp",
	"salvage_planks",
	"signal_battery",
	"all_hands"
]

const DURATIONS := [90.0, 115.0, 125.0, 135.0, 145.0, 150.0, 155.0, 160.0, 165.0, 180.0]


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	_expect(scene != null, "NightShiftGame scene loads")
	if scene == null:
		quit(1)
		return

	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	_expect(game.call("_debug_start_campaign"), "cover starts campaign")

	for i in range(CHOICES.size()):
		var state := game.call("_debug_get_state") as Dictionary
		_expect(str(state.get("phase", "")) == "day", "level %d starts from day phase" % [i + 1])
		_expect(int(state.get("current_level", 0)) == i + 1, "level %d is current" % [i + 1])
		_expect(game.call("_debug_set_seed", 2000 + i), "level %d seed accepted" % [i + 1])
		_expect(game.call("_debug_choose_day", CHOICES[i]), "level %d starts with choice %s" % [i + 1, CHOICES[i]])
		state = game.call("_debug_get_state") as Dictionary
		_expect(str(state.get("phase", "")) == "night", "level %d enters night" % [i + 1])
		_expect(_expected_hotspots_unlocked(state, i + 1), "level %d has expected unlocked hotspots" % [i + 1])
		_force_safe_level(game)
		game.set("night_elapsed", float(DURATIONS[i]) - 0.1)
		game.call("_debug_step", 0.2)
		state = game.call("_debug_get_state") as Dictionary
		_expect(str(state.get("phase", "")) == "report", "level %d reaches report" % [i + 1])
		_expect(str(state.get("outcome", "")) == "success", "level %d reports success" % [i + 1])
		if i < CHOICES.size() - 1:
			_expect(game.call("_debug_continue_report"), "level %d continues to next day" % [i + 1])
		else:
			_expect(game.call("_debug_continue_report"), "level 10 continues to final")
			state = game.call("_debug_get_state") as Dictionary
			_expect(str(state.get("phase", "")) == "final", "campaign reaches final phase")
			_expect(str(state.get("outcome", "")) == "campaign_success", "campaign success outcome is recorded")

	game.queue_free()
	if failed:
		print("Last Radio night shift campaign flow check: FAIL")
		quit(1)
	else:
		print("Last Radio night shift campaign flow check: PASS")
		quit(0)


func _expected_hotspots_unlocked(state: Dictionary, level: int) -> bool:
	var unlocked := state.get("unlocked_hotspots", []) as Array
	if level >= 2 and not unlocked.has("right_window"):
		return false
	if level >= 4 and not unlocked.has("antenna"):
		return false
	if level >= 6 and not unlocked.has("back_door"):
		return false
	if level >= 7 and not unlocked.has("medbay"):
		return false
	if level >= 8 and not unlocked.has("storage"):
		return false
	return true


func _force_safe_level(game: Node) -> void:
	var state := game.call("_debug_get_state") as Dictionary
	var unlocked := state.get("unlocked_hotspots", []) as Array
	for id in unlocked:
		var id_text := str(id)
		match id_text:
			"front_door", "back_door":
				_force_hotspot(game, id_text, {"value": 120.0, "active": true, "pressure": 0.0, "breach_timer": -1.0, "assault": false, "warning": false, "temp_seal": 0.0})
			"left_window", "right_window":
				_force_hotspot(game, id_text, {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0, "assault": false, "warning": false, "temp_seal": 0.0})
			"generator":
				_force_hotspot(game, id_text, {"value": 115.0, "active": true, "pressure": 0.0})
			"antenna":
				_force_hotspot(game, id_text, {"value": 115.0, "active": false, "warning": false, "pressure": 0.0})
			"medbay", "storage":
				_force_hotspot(game, id_text, {"value": 100.0, "active": false, "warning": false, "pressure": 0.0})
	game.set("radio_available", false)
	game.set("radio_completed", true)
	game.set("blackout", false)


func _force_hotspot(game: Node, id: String, patch: Dictionary) -> void:
	var hotspots := game.get("hotspots") as Dictionary
	var data := hotspots[id] as Dictionary
	for key in patch.keys():
		data[key] = patch[key]
	hotspots[id] = data
	game.set("hotspots", hotspots)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Last Radio night shift campaign flow check: FAIL - %s" % message)
	print("Last Radio night shift campaign flow check: FAIL - %s" % message)
