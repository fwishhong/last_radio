extends SceneTree
# Capture the player repair-action overlay at each of the 3 frames so we
# can visually verify the sprite is properly sized + transparent after the
# fit-to-PLAYER_TARGET_SIZE fix.
#
# Drives a real repair tick by parking the player on a barrier hotspot
# and setting player_target_id + player_at_target, so the game's own
# _update_hotspots flags the overlay and advances the timer.

const Save := preload("res://scripts/NightShiftSave.gd")
const PlayerRepairFx := preload("res://scripts/PlayerRepairFx.gd")
const OUTPUT_DIR := "user://last_radio_v2_fx_shots"

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

	Save.clear_save()
	game._on_slot_new_pressed(1)
	await process_frame
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	await process_frame
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	for i in 3:
		await process_frame

	# Pick a barrier hotspot and park the player on it so a real repair
	# tick fires each frame. _update_hotspots then sets player_repair_active
	# and advances player_repair_timer.
	var target_id: String = ""
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		if PlayerRepairFx.is_repairable_hotspot(str(h.get("kind", ""))):
			target_id = id
			break
	if target_id == "":
		print("FAIL: no barrier hotspot")
		quit(1); return
	game.player_target_id = target_id
	game.player_at_target = true
	game.player_pos = (game.hotspots[target_id] as Dictionary)["pos"] as Vector2

	# Pin the timer to a known phase each frame by snapping it AFTER
	# _update_hotspots runs (which is what advances it). We can't pause
	# _process, so just snapshot at three distinct phases spaced apart so
	# each capture grabs a different frame index from the cycle.
	var snap_phases := [
		[0.15, "repair_frame_start"],
		[0.50, "repair_frame_mid"],
		[0.85, "repair_frame_end"],
	]
	for entry in snap_phases:
		var phase: float = entry[0]
		var out_name: String = entry[1]
		# Set timer so that fmod(t, CYCLE) / CYCLE lands on `phase`.
		# Timer accumulates naturally from deltas — we'll snap it each
		# tick by overwriting after _process has run.
		for i in 30:
			game.player_repair_timer = phase * PlayerRepairFx.REPAIR_CYCLE_SEC
			await process_frame

		# Now read back the actual values to confirm.
		var tex: Texture2D = game.player_repair_token.texture
		var sc: Vector2 = game.player_repair_token.scale
		var on_w: float = float(tex.get_width()) * sc.x
		var on_h: float = float(tex.get_height()) * sc.y
		print("phase=%.2f  tex=%dx%d  scale=%.3fx%.3f  on-screen=%.0fx%.0f  alpha=%.2f  walk_alpha=%.2f" % [
			phase, tex.get_width(), tex.get_height(), sc.x, sc.y, on_w, on_h,
			game.player_repair_token.modulate.a, game.player_token.modulate.a
		])
		await _take_shot(vp, out_name)

	# Stop repairing so we exit cleanly.
	game.player_target_id = ""
	game.player_at_target = false
	print("done")
	quit(0)


func _take_shot(vp: SubViewport, name: String) -> void:
	var abs_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("  %s: texture null" % name); return
	var img := tex.get_image()
	if img == null:
		print("  %s: image null" % name); return
	var path := "%s/%s.png" % [abs_path, name]
	var err := img.save_png(path)
	if err == OK:
		print("  %s: %s" % [name, path])
	else:
		print("  %s: save_png error %d" % [name, err])