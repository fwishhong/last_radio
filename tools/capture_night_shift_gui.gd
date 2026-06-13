extends SceneTree

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	if DisplayServer.get_name() != "headless":
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game := scene.instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)

	await _capture(viewport, "user://night_shift_00_cover.png")
	game.call("_debug_start_campaign")
	await process_frame
	await _capture(viewport, "user://night_shift_01_start.png")

	game.call("_debug_set_seed", 101)
	game.call("_debug_choose_day", "start")
	game.set("night_elapsed", 89.9)
	_force_hotspot(game, "front_door", {"value": 100.0, "pressure": 0.0, "active": true, "breach_timer": -1.0})
	_force_hotspot(game, "left_window", {"value": 100.0, "pressure": 0.0, "active": true, "breach_timer": -1.0})
	_force_hotspot(game, "generator", {"value": 100.0, "pressure": 0.0, "active": true})
	game.call("_debug_step", 0.2)
	game.call("_debug_continue_report")
	await process_frame
	await _capture(viewport, "user://night_shift_13_day_upgrade_choices.png")
	game.call("_debug_set_seed", 202)
	game.call("_debug_choose_day", "window_brace")
	game.set("night_elapsed", _schedule_time(game, "right_window_warning", 24.0) - 0.1)
	game.call("_debug_step", 0.3)
	await process_frame
	await _capture(viewport, "user://night_shift_02_warning.png")

	game.set("night_elapsed", _schedule_time(game, "right_window", 30.0) - 0.1)
	game.call("_debug_step", 0.3)
	game.call("_debug_click_hotspot", "left_window")
	game.call("_debug_step", 0.2)
	await process_frame
	await _capture(viewport, "user://night_shift_03_double_window.png")

	game.call("_debug_use_plank")
	game.call("_debug_step", 0.1)
	await process_frame
	await _capture(viewport, "user://night_shift_04_plank.png")

	game.set("night_elapsed", 114.9)
	_force_hotspot(game, "front_door", {"value": 100.0, "pressure": 0.0, "active": true, "breach_timer": -1.0})
	_force_hotspot(game, "left_window", {"value": 115.0, "pressure": 0.0, "active": true, "breach_timer": -1.0})
	_force_hotspot(game, "right_window", {"value": 115.0, "pressure": 0.0, "active": true, "breach_timer": -1.0})
	_force_hotspot(game, "generator", {"value": 100.0, "pressure": 0.0, "active": true})
	game.call("_debug_step", 0.3)
	await process_frame
	await _capture(viewport, "user://night_shift_05_result.png")

	game.call("_debug_continue_report")
	game.call("_debug_set_seed", 303)
	game.call("_debug_choose_day", "radio_booster")
	var allies := game.get("allies") as Dictionary
	allies["elias"] = true
	game.set("allies", allies)
	game.set("night_elapsed", 124.9)
	_force_safe_level_3(game)
	game.call("_debug_step", 0.3)
	game.call("_debug_continue_report")
	game.call("_debug_set_seed", 505)
	game.call("_debug_choose_day", "antenna_anchor")
	game.set("night_elapsed", _schedule_time(game, "antenna_drop", 25.0) - 0.1)
	_force_hotspot(game, "antenna", {"value": 62.0, "active": false, "warning": false, "pressure": 0.0})
	game.call("_debug_step", 0.3)
	await process_frame
	await _capture(viewport, "user://night_shift_06_antenna.png")

	game.set("night_elapsed", 134.9)
	_force_safe_level_4(game)
	game.call("_debug_step", 0.3)
	game.call("_debug_continue_report")
	game.call("_debug_set_seed", 606)
	game.call("_debug_choose_day", "command_routine")
	game.set("night_elapsed", 144.9)
	_force_safe_level_4(game)
	game.call("_debug_step", 0.3)
	game.call("_debug_continue_report")
	game.call("_debug_set_seed", 707)
	game.call("_debug_choose_day", "back_door_bar")
	game.set("night_elapsed", _schedule_time(game, "back_door", 42.0) - 0.1)
	_force_hotspot(game, "back_door", {"value": 68.0, "active": true, "warning": false, "assault": false, "pressure": 0.0})
	game.call("_debug_step", 0.3)
	await process_frame
	await _capture(viewport, "user://night_shift_07_back_door.png")

	game.set("night_elapsed", 149.9)
	_force_safe_level(game)
	game.call("_debug_step", 0.3)
	game.call("_debug_continue_report")
	await process_frame
	await _capture(viewport, "user://night_shift_14_day_medbay_choices.png")
	game.call("_debug_set_seed", 808)
	game.call("_debug_choose_day", "medbay_lamp")
	game.set("first_door_hint_done", true)
	_force_hotspot(game, "medbay", {"value": 48.0, "active": true, "warning": true, "pressure": 0.0})
	game.call("_debug_click_hotspot", "medbay")
	game.call("_debug_step", 0.2)
	await process_frame
	await _capture(viewport, "user://night_shift_11_medbay_treating.png")
	game.set("player_target_id", "")
	game.set("night_elapsed", 154.9)
	_force_safe_level(game)
	game.call("_debug_step", 0.3)
	game.call("_debug_continue_report")
	await process_frame
	await _capture(viewport, "user://night_shift_15_day_storage_choices.png")
	game.call("_debug_set_seed", 909)
	game.call("_debug_choose_day", "salvage_planks")
	game.set("first_door_hint_done", true)
	_force_hotspot(game, "storage", {"value": 44.0, "active": true, "warning": true, "pressure": 0.0})
	game.call("_debug_click_hotspot", "storage")
	game.call("_debug_step", 0.2)
	await process_frame
	await _capture(viewport, "user://night_shift_12_storage_repairing.png")
	game.set("player_target_id", "")
	game.set("night_elapsed", 159.9)
	_force_safe_level(game)
	game.call("_debug_step", 0.3)
	game.call("_debug_continue_report")
	await process_frame
	await _capture(viewport, "user://night_shift_16_day_signal_choices.png")
	game.call("_debug_set_seed", 1001)
	game.call("_debug_choose_day", "signal_battery")
	game.set("night_elapsed", 164.9)
	_force_safe_level(game)
	game.call("_debug_step", 0.3)
	game.call("_debug_continue_report")
	game.call("_debug_set_seed", 1111)
	game.call("_debug_choose_day", "all_hands")
	game.set("night_elapsed", _schedule_time(game, "final_wave", 124.0) - 0.1)
	_force_safe_level(game)
	game.call("_debug_step", 0.3)
	await process_frame
	await _capture(viewport, "user://night_shift_08_final_wave.png")

	game.set("night_elapsed", 179.9)
	_force_safe_level(game)
	game.call("_debug_step", 0.3)
	await process_frame
	await _capture(viewport, "user://night_shift_09_success.png")
	game.call("_debug_continue_report")
	await process_frame
	await _capture(viewport, "user://night_shift_17_final.png")

	game.queue_free()
	await process_frame

	var failure_game := scene.instantiate()
	viewport.add_child(failure_game)
	await process_frame
	await process_frame
	failure_game.set_process(false)
	failure_game.call("_debug_start_campaign")
	failure_game.call("_debug_set_seed", 404)
	failure_game.call("_debug_choose_day", "start")
	_force_hotspot(failure_game, "front_door", {"value": 0.0, "active": true, "pressure": 0.0, "breach_timer": 0.0})
	failure_game.call("_debug_step", 10.3)
	await process_frame
	await _capture(viewport, "user://night_shift_10_failure.png")

	print("Night shift captures written to user://night_shift_00_cover.png ... night_shift_17_final.png")
	quit(0)

func _capture(viewport: SubViewport, path: String) -> void:
	if DisplayServer.get_name() != "headless":
		for i in range(3):
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			await RenderingServer.frame_post_draw
	var texture := viewport.get_texture()
	if texture == null:
		push_error("Night shift GUI capture needs a rendering backend; SubViewport texture is null.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("Night shift GUI capture needs a rendering backend; SubViewport image is null.")
		quit(1)
		return
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("Failed to save night shift GUI capture: %s" % error_string(err))
		quit(1)

func _force_hotspot(game: Node, id: String, patch: Dictionary) -> void:
	var hotspots := game.get("hotspots") as Dictionary
	var data := hotspots[id] as Dictionary
	for key in patch.keys():
		data[key] = patch[key]
	hotspots[id] = data
	game.set("hotspots", hotspots)

func _force_safe_level_3(game: Node) -> void:
	_force_hotspot(game, "front_door", {"value": 120.0, "pressure": 0.0, "active": true, "breach_timer": -1.0})
	_force_hotspot(game, "left_window", {"value": 115.0, "pressure": 0.0, "active": true, "breach_timer": -1.0})
	_force_hotspot(game, "right_window", {"value": 115.0, "pressure": 0.0, "active": true, "breach_timer": -1.0})
	_force_hotspot(game, "generator", {"value": 100.0, "pressure": 0.0, "active": true})

func _force_safe_level_4(game: Node) -> void:
	_force_safe_level_3(game)
	_force_hotspot(game, "antenna", {"value": 115.0, "pressure": 0.0, "active": false, "warning": false})
	game.set("radio_available", false)
	game.set("radio_completed", true)

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

func _schedule_time(game: Node, id: String, fallback: float) -> float:
	var state := game.call("_debug_get_state") as Dictionary
	var schedule := state.get("night_schedule", {}) as Dictionary
	return float(schedule.get(id, fallback))
