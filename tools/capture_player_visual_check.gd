extends SceneTree
# Round-2 repair-action visual check. Captures the player token in three
# states -- idle / walking / repair -- so we can confirm:
#   (a) all three use the same walk-frame art (no actor<->walk swap)
#   (b) all three use the same scale (no 116px / 97px / 128px jump)
#   (c) repair no longer layers the broken player_repair_*.png overlay
#       (no colored halo around the player)
# polish spec §4.5 / round-2 fix.
#
# Output: user://last_radio_v2_player_visual_check/{01_idle,02_walking,
# 03_repair_mid,04_repair_end}.png

const Save := preload("res://scripts/NightShiftSave.gd")
const OUTPUT_DIR := "user://last_radio_v2_player_visual_check"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game := scene.instantiate()
	vp.add_child(game)
	for i in 4:
		await process_frame

	# Boot a fresh run on slot 1.
	Save.clear_save()
	game._on_slot_new_pressed(1)
	await process_frame
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	await process_frame
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	for i in 3:
		await process_frame

	# Force a clean night 1 layout and pin the player on front_door.
	game.event_queue.clear()
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		h["value"] = h["max_value"]
		h["pressure"] = 0.0
		h["assault"] = false
		h["warning"] = false
		h["breach_timer"] = -1.0
		game.hotspots[id] = h
	# Snap player onto front_door so repair-action can fire.
	game.player_pos = game.hotspots["front_door"]["pos"]

	# Disable _process so the player_state vars we set in each shot are
	# NOT overwritten by _update_player_movement / _update_hotspots.
	# Without this, every var we set is reset on the next process frame.
	game.set_process(false)

	# --- Shot 1: idle (no movement, no repair) --------------------------
	_set_player_state(game, "down", false, 0, false, 0.0)
	for i in 2:
		await process_frame
	_take_shot(vp, "01_idle")

	# --- Shot 2: walking (left, mid-cycle) ------------------------------
	_set_player_state(game, "left", true, 5, false, 0.0)
	for i in 2:
		await process_frame
	_take_shot(vp, "02_walking")

	# --- Shot 3: repair mid-swing (hammer down) -------------------------
	_set_player_state(game, "down", false, 0, true, 0.18)
	for i in 2:
		await process_frame
	_take_shot(vp, "03_repair_mid")

	# --- Shot 4: repair end (hammer impact) ----------------------------
	_set_player_state(game, "down", false, 0, true, 0.30)
	for i in 2:
		await process_frame
	_take_shot(vp, "04_repair_end")

	print("Player visual check done: %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _set_player_state(game: Node, facing: String, moving: bool, walk_frame: int, repair: bool, repair_timer: float) -> void:
	game.player_facing = facing
	game.player_is_moving = moving
	game.player_walk_frame = walk_frame
	game.player_repair_active = repair
	game.player_repair_timer = repair_timer
	# Manually refresh the sprite so the new state lands in the render.
	game._draw_player()
	# Debug: confirm the var stuck.
	print("  _set_player_state: facing=%s moving=%s walk_frame=%d repair=%s timer=%.3f pos=%s rot=%.3f token_tex_set=%s token_pos=%s token_scale=%s" % [
		game.player_facing, game.player_is_moving, game.player_walk_frame,
		game.player_repair_active, game.player_repair_timer,
		game.player_token.position, game.player_token.rotation,
		game.player_token.texture != null, game.player_token.position, game.player_token.scale,
	])


func _take_shot(vp: SubViewport, name: String) -> void:
	var abs_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("  %s: texture null" % name)
		return
	var img := tex.get_image()
	if img == null:
		print("  %s: image null" % name)
		return
	var path := "%s/%s.png" % [abs_path, name]
	var err := img.save_png(path)
	if err == OK:
		print("  %s: %s" % [name, path])
	else:
		print("  %s: save_png error %d" % [name, err])
