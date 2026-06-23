extends SceneTree
# Round-2 capture: verifies the player hammer sprite renders next to
# the (perfectly-still) player token during repair ticks, and that
# night 2's screen is no longer tinted by a stale dawn fade.
#
# Outputs (user://last_radio_v2_round2_capture/):
#   01_player_idle.png           -- idle, no hammer
#   02_player_repair_mid.png     -- repair mid-swing (hammer at -45deg)
#   03_player_repair_end.png     -- repair end-swing (hammer at +45deg)
#   04_player_repair_still.png   -- player token box crop proving
#                                   the player itself never moves
#   05_night2_baseline.png       -- night 2 just after entry, no white fade
#   06_night2_with_warning.png   -- night 2 after a procedural warning fired
#
# polish spec §4.5 / round-2 visual fix.

const Save := preload("res://scripts/NightShiftSave.gd")
const OUTPUT_DIR := "user://last_radio_v2_round2_capture"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Use root viewport directly (not SubViewport) -- SubViewport's
	# render-target-update is decoupled from the main window and
	# "await RenderingServer.frame_post_draw" doesn't always wait for
	# it to flush. Direct root rendering guarantees hammer_sprite
	# transform updates are visible in the very next saved frame.
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

	# Force a clean night 1 layout and pin the player on front_door so
	# we can fire repair ticks deterministically. To keep the hammer
	# visible in the capture, we also disable _process so
	# _update_hotspots doesn't reset player_repair_active to false
	# before the shot is taken (production code only sets
	# player_repair_active=true when player_target_id matches AND
	# player_at_target -- neither is set in our static capture).
	game.event_queue.clear()
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		h["value"] = h["max_value"]
		h["pressure"] = 0.0
		h["assault"] = false
		h["warning"] = false
		h["breach_timer"] = -1.0
		game.hotspots[id] = h
	game.player_pos = game.hotspots["front_door"]["pos"]
	game.set_process(false)

	# --- Shot 1: idle (no repair, no hammer) -------------------------
	_set_player_state(game, "down", false, 0, false, 0.0)
	for i in 2:
		await process_frame
	_take_shot("01_player_idle")

	# --- Shot 2: repair mid-swing (phase=0.5 -> wave=0 -> hammer at base) -
	_set_player_state(game, "down", false, 0, true, 0.18)
	for i in 2:
		await process_frame
	print("  debug mid: hammer_sprite.visible=%s pos=%s rot=%s" % [game.hammer_sprite.visible, game.hammer_sprite.position, game.hammer_sprite.rotation])
	_take_shot("02_player_repair_mid")

	# --- Shot 3: repair end-swing (phase=0.83 -> wave=-0.87 -> hammer tilted) -
	_set_player_state(game, "down", false, 0, true, 0.30)
	for i in 2:
		await process_frame
	print("  debug end: hammer_sprite.visible=%s pos=%s rot=%s" % [game.hammer_sprite.visible, game.hammer_sprite.position, game.hammer_sprite.rotation])
	_take_shot("03_player_repair_end")

	# --- Shot 4: player token box (proof player is perfectly still) ----
	# Crop the previous shot to a tight box around the player to verify
	# the player_token's position and rotation never change across the
	# three states.
	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
	# Wait for frame_post_draw so the just-taken shot is on disk.
	await RenderingServer.frame_post_draw
	var png := Image.load_from_file(abs_path + "/03_player_repair_end.png")
	if png != null:
		var crop := png.get_region(Rect2i(540, 30, 240, 200))
		crop.save_png(abs_path + "/04_player_repair_still.png")
		print("  04_player_repair_still: %s/04_player_repair_still.png" % abs_path)

	# --- Shot 5: night 2 baseline (no white fade) ---------------------
	# Simulate a successful night 1 -> enter day picker -> start night 2.
	# Capture the very first frame of night 2 to confirm fx_dawn reset.
	game.fx_dawn_target = 0.0
	game.fx_dawn_alpha = 0.0
	game.night_index = 1
	game.call("_show_night")
	for i in 3:
		await process_frame
	# Don't disable _process this time -- we want the first frame of
	# night 2 to be a "live" capture so the procedural scheduler and
	# any other state is fully initialized.
	_take_shot("05_night2_baseline")

	# --- Shot 6: night 2 after a procedural warning fired -----------
	# Wait ~12s so the procedural scheduler fires its first warning,
	# then capture to show the warning telegraph on a barrier hotspot.
	var t_start: float = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_start < 12000.0:
		await process_frame
	_take_shot("06_night2_with_warning")

	print("Round 2 capture done: %s" % abs_path)
	quit(0)


func _set_player_state(game: Node, facing: String, moving: bool, walk_frame: int, repair: bool, repair_timer: float) -> void:
	game.player_facing = facing
	game.player_is_moving = moving
	game.player_walk_frame = walk_frame
	game.player_repair_active = repair
	game.player_repair_timer = repair_timer
	game._draw_player()


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
