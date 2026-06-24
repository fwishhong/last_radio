extends SceneTree
# Round-2.1 capture: verifies the round-2.1 tweaks to the procedural
# hammer swing (over-arm thrust bumped 1.4 -> 1.8 rad, handle color
# brightened to (0.68, 0.40, 0.18) warm cedar) and the procedural
# pacing (night 5+ base cadence tightened from 6-10s to 4-7s).
#
# Outputs (user://last_radio_v2_round2_1_capture/):
#   01_player_idle.png           -- idle, no hammer
#   02_player_repair_mid.png     -- repair mid-swing (phase=0.20)
#   03_player_repair_end.png     -- repair recovery (phase=0.70)
#   04_player_repair_peak.png    -- peak forward thrust (phase=0.45)
#   05_player_repair_peak_v2.png -- peak thrust, second frame for
#                                   inter-frame delta verification
#   06_night2_baseline.png       -- night 2 just after entry, no white fade
#   07_night2_with_warning.png   -- night 2 after first procedural warning
#   08_night5_tight_cadence.png  -- night 5 baseline, no warning yet
#   09_night5_dense_warnings.png -- night 5 after 18s, multiple warnings
#                                   should have fired (4-7s cadence)
#   10_night5_closeup_warning.png -- tight crop on a procedural warning
#
# polish spec §4.5 / round-2.1 visual + pacing fix.

const Save := preload("res://scripts/NightShiftSave.gd")
const OUTPUT_DIR := "user://last_radio_v2_round2_1_capture"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game: Node = scene.instantiate()
	root.add_child(game)
	for i in 4:
		await process_frame

	Save.clear_save()
	game._on_slot_new_pressed(1)
	await process_frame
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	await process_frame
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	for i in 3:
		await process_frame

	# Force a clean night 1 layout and pin the player on left_window --
	# front_door is at y=85, which puts the hammer handle (y = 85 - 54 -
	# 38 = -7 to y = 85 - 54 = 31) almost entirely above the viewport.
	# left_window at (270, 250) keeps the hammer fully visible in a
	# 240x200 crop region around (170, 100).
	game.event_queue.clear()
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		h["value"] = h["max_value"]
		h["pressure"] = 0.0
		h["assault"] = false
		h["warning"] = false
		h["breach_timer"] = -1.0
		game.hotspots[id] = h
	game.player_pos = game.hotspots["left_window"]["pos"]
	game.set_process(false)

	# --- Shot 1: idle (no repair, no hammer) -------------------------
	_set_player_state(game, "down", false, 0, false, 0.0)
	for i in 2:
		await process_frame
	_take_shot("01_player_idle")

	# --- Shot 2: repair mid-swing (phase=0.20, ~44% of forward arc) ---
	# phase=0.20 / 0.45 = 0.444. New thrust (1.8) gives:
	#   swing = -PI/3 + 0.444*(PI/6 + 1.8) = -1.047 + 0.444*2.324
	#         = -1.047 + 1.032 = -0.015 rad (~ -0.9deg, near horizontal)
	# The new bigger amplitude makes the mid-frame a near-horizontal
	# hammer across the player.
	_set_player_state(game, "down", false, 0, true, 0.20 * 0.36)
	for i in 2:
		await process_frame
	print("  debug mid: hammer rot=%.3f rad (%.1f deg)" % [game.hammer_sprite.rotation, rad_to_deg(game.hammer_sprite.rotation)])
	_take_shot("02_player_repair_mid")

	# --- Shot 3: recovery swing (phase=0.70, 45% of recovery arc) ----
	# recover_t = (0.70 - 0.45) / 0.55 = 0.455
	# swing = -PI/6 + 1.8 - 0.455*(PI/3 + PI/6 + 1.8)
	#       = 1.276 - 0.455*3.371
	#       = 1.276 - 1.534 = -0.258 rad (~ -14.8 deg)
	_set_player_state(game, "down", false, 0, true, 0.70 * 0.36)
	for i in 2:
		await process_frame
	print("  debug end: hammer rot=%.3f rad (%.1f deg)" % [game.hammer_sprite.rotation, rad_to_deg(game.hammer_sprite.rotation)])
	_take_shot("03_player_repair_end")

	# --- Shot 4: peak forward thrust (phase=0.45) -------------------
	# Hammer reaches -PI/6 + 1.8 = 1.276 rad (~73 deg) -- the most
	# committed forward swing in the cycle. The head should be deep
	# across the player's body line.
	_set_player_state(game, "down", false, 0, true, 0.45 * 0.36)
	for i in 2:
		await process_frame
	print("  debug peak: hammer rot=%.3f rad (%.1f deg)" % [game.hammer_sprite.rotation, rad_to_deg(game.hammer_sprite.rotation)])
	_take_shot("04_player_repair_peak")

	# --- Shot 5: peak thrust, second frame to show swing dynamic -----
	_set_player_state(game, "down", false, 0, true, 0.50 * 0.36)
	for i in 2:
		await process_frame
	print("  debug peak+0.05: hammer rot=%.3f rad (%.1f deg)" % [game.hammer_sprite.rotation, rad_to_deg(game.hammer_sprite.rotation)])
	_take_shot("05_player_repair_peak_v2")

	# --- Night 2 baseline (no white fade) ----------------------------
	game.fx_dawn_target = 0.0
	game.fx_dawn_alpha = 0.0
	game.night_index = 1
	game.call("_show_night")
	for i in 3:
		await process_frame
	_take_shot("06_night2_baseline")

	# --- Night 2 after first procedural warning ----------------------
	var t_start: float = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_start < 12000.0:
		await process_frame
	_take_shot("07_night2_with_warning")

	# --- Night 5: tight 4-7s cadence in action -----------------------
	# Jump to night 5 (index 4) and let the scheduler run. With the
	# new 4-7s base, in 18s real time we should see 2-4 procedural
	# warnings (vs 1-2 with the old 6-10s base).
	game.night_index = 4
	game.night_duration = 120.0
	game.night_elapsed = 0.0
	game._proc_next_warning_at = -1.0
	game.event_queue.clear()
	# Reset hotspot state so the prior night 2 capture's accumulated
	# pressure doesn't bleed into night 5 and end the night before
	# we can capture the procedural scheduler in action.
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		h["value"] = h["max_value"]
		h["pressure"] = 0.0
		h["assault"] = false
		h["warning"] = false
		h["breach_timer"] = -1.0
		game.hotspots[id] = h
	game.call("_show_night")
	# Re-enable _process -- we disabled it for the player-state captures
	# above so _update_hotspots wouldn't reset player_repair_active.
	game.set_process(true)
	for i in 3:
		await process_frame
	_take_shot("08_night5_tight_cadence")
	var proc_before: int = _count_proc_warnings(game.logs)
	var t2: float = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 18000.0:
		await process_frame
	var proc_after: int = _count_proc_warnings(game.logs)
	print("  night 5: %d proc warnings in 18s (cadence is 4-7s)" % (proc_after - proc_before))
	_take_shot("09_night5_dense_warnings")

	# --- Close-up: crop a region around a warning hotspot -----------
	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
	await RenderingServer.frame_post_draw
	var png := Image.load_from_file(abs_path + "/09_night5_dense_warnings.png")
	if png != null:
		var crop := png.get_region(Rect2i(280, 60, 480, 320))
		crop.save_png(abs_path + "/10_night5_closeup_warning.png")
		print("  10_night5_closeup_warning: %s/10_night5_closeup_warning.png" % abs_path)

	print("Round 2.1 capture done: %s" % abs_path)
	quit(0)


func _set_player_state(game: Node, facing: String, moving: bool, walk_frame: int, repair: bool, repair_timer: float) -> void:
	game.player_facing = facing
	game.player_is_moving = moving
	game.player_walk_frame = walk_frame
	game.player_repair_active = repair
	game.player_repair_timer = repair_timer
	game._draw_player()


func _count_proc_warnings(logs: Array) -> int:
	var n: int = 0
	for entry in logs:
		var s: String = str(entry)
		if s.begins_with("远处传来声响") or s.begins_with("A sound"):
			n += 1
	return n


func _take_shot(name: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("  %s: image null" % name)
		return
	var path := "%s/%s.png" % [abs_path, name]
	var err := img.save_png(path)
	if err == OK:
		print("  %s: %s" % [name, path])
	else:
		print("  %s: save_png error %d" % [name, err])
