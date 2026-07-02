extends SceneTree
# Round-3 visual verification capture.
# Renders the night-shift room with the player standing at a barrier
# hotspot AND the generator hotspot so the hammer cycle is visible in
# both contexts. Cover UI is force-cleared so the screenshot isn't
# muddied by the slot-picker overlay.

const OUTPUT_DIR := "user://last_radio_v2_round3_hammer_capture"
const SCREEN_SIZE := Vector2(1280, 720)


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture requires a display driver")
		quit(0)
		return
	_run.call_deferred()


func _run() -> void:
	var abs_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game: Node = scene.instantiate()
	vp.add_child(game)

	# Let the game initialize.
	for i in range(8):
		await process_frame

	# Stop the game tree FIRST so _process / _update_night / _redraw_enemy_visuals
	# can't override our pinned values. This must happen before any
	# _show_night / set() calls -- otherwise one tick of _process
	# resets player_pos to its default and the hammer doesn't show
	# at the pinned position.
	game.process_mode = Node.PROCESS_MODE_DISABLED

	# Force into a night. _show_night clears card_layer + sets phase="night".
	if game.has_method("_show_night"):
		game.call("_show_night")
	# Capture-time cleanup: queue_free'd cover widgets don't actually free
	# while game.process_mode is DISABLED (no idle frame runs), so hide
	# card_layer entirely + remove children synchronously.
	if game.has_node("CardLayer") or game.card_layer != null:
		for child in game.card_layer.get_children():
			game.card_layer.remove_child(child)
			child.queue_free()
		game.card_layer.visible = false
	# Dismiss any CG overlay / night-pause overlays so they don't cover
	# the room view in the capture.
	if "night_cg_overlay" in game and game.night_cg_overlay != null:
		game.night_cg_overlay.visible = false
		game.night_cg_overlay.queue_free()
	if "night_paused" in game:
		game.set("night_paused", false)
	for i in range(3):
		await process_frame

	# Capture the front_door + generator hammer simultaneously.
	# 1) front_door -- player standing just below it, repair active.
	var front_pos: Vector2 = game.hotspots["front_door"]["pos"]
	game.set("player_pos", front_pos + Vector2(0.0, 60.0))
	game.set("player_target_id", "front_door")
	game.set("player_at_target", true)
	game.set("player_repair_active", true)
	# Pin the timer so the swing is at the down-stroke peak
	# (phase ~ 0.45 -> hammer is mid-arc, max forward thrust).
	game.set("player_repair_timer", 0.16)

	if game.has_method("_draw_player"):
		game.call("_draw_player")
	for i in range(3):
		await process_frame

	var tex := vp.get_texture()
	var img := tex.get_image()
	var out_path: String = OUTPUT_DIR + "/hammer_front_door.png"
	var abs_out: String = ProjectSettings.globalize_path(out_path)
	img.save_png(abs_out)
	print("hammer_front_door.png -> %s" % abs_out)

	# 2) generator -- same setup, force-target the generator hotspot.
	#    This proves the round-3 "generator also gets hammer" fix.
	var gen_pos: Vector2 = game.hotspots["generator"]["pos"]
	game.set("player_pos", gen_pos + Vector2(0.0, -60.0))
	game.set("player_target_id", "generator")
	game.set("player_repair_timer", 0.10)
	if game.has_method("_draw_player"):
		game.call("_draw_player")
	for i in range(3):
		await process_frame
	img = vp.get_texture().get_image()
	out_path = OUTPUT_DIR + "/hammer_generator.png"
	abs_out = ProjectSettings.globalize_path(out_path)
	img.save_png(abs_out)
	print("hammer_generator.png -> %s" % abs_out)

	# 3) door telegraph / zombie. Force a telegraph on front_door so the
	#    outside-zombie sprite shows up -- this lets us verify the new
	#    zombie_anchor_offset (round-4: outside the door, partially
	#    off-screen). Reset the player out of the way first so the
	#    hammer sprite doesn't muddy the silhouette.
	game.set("player_repair_active", false)
	game.set("player_repair_timer", 0.0)
	game.set("player_target_id", "")
	game.set("player_at_target", false)
	game.set("player_pos", Vector2(640.0, 500.0))
	game.set("player_facing", "down")
	game.set("player_is_moving", false)
	if game.has_method("_draw_player"):
		game.call("_draw_player")
	for i in range(2):
		await process_frame
	var tele: Dictionary = {
		"hotspot_id": "front_door",
		"kind": "assault",
		"time_left": 0.5,
		"total_time": 2.0,
		"phase": 0.0,
	}
	game.fx_telegraphs.append(tele)
	if game.has_method("_world_tick"):
		game.call("_world_tick", 0.1)
	for i in range(3):
		await process_frame
	img = vp.get_texture().get_image()
	out_path = OUTPUT_DIR + "/zombie_front_door.png"
	abs_out = ProjectSettings.globalize_path(out_path)
	img.save_png(abs_out)
	print("zombie_front_door.png -> %s" % abs_out)
	game.fx_telegraphs.clear()

	# 4) window telegraph / zombie -- left_window to verify the new
	#    anchor places the zombie on the OUTSIDE edge of the room.
	tele["hotspot_id"] = "left_window"
	game.fx_telegraphs.append(tele)
	if game.has_method("_world_tick"):
		game.call("_world_tick", 0.1)
	for i in range(3):
		await process_frame
	img = vp.get_texture().get_image()
	out_path = OUTPUT_DIR + "/zombie_left_window.png"
	abs_out = ProjectSettings.globalize_path(out_path)
	img.save_png(abs_out)
	print("zombie_left_window.png -> %s" % abs_out)
	game.fx_telegraphs.clear()

	# 5) Bonus: right_window to verify mirror placement on the right side.
	tele["hotspot_id"] = "right_window"
	game.fx_telegraphs.append(tele)
	if game.has_method("_world_tick"):
		game.call("_world_tick", 0.1)
	for i in range(3):
		await process_frame
	img = vp.get_texture().get_image()
	out_path = OUTPUT_DIR + "/zombie_right_window.png"
	abs_out = ProjectSettings.globalize_path(out_path)
	img.save_png(abs_out)
	print("zombie_right_window.png -> %s" % abs_out)
	game.fx_telegraphs.clear()

	# 6) back_door to verify the back_door hotspot also uses the
	#    outside-up anchor (top-right of the room).
	tele["hotspot_id"] = "back_door"
	game.fx_telegraphs.append(tele)
	if game.has_method("_world_tick"):
		game.call("_world_tick", 0.1)
	for i in range(3):
		await process_frame
	img = vp.get_texture().get_image()
	out_path = OUTPUT_DIR + "/zombie_back_door.png"
	abs_out = ProjectSettings.globalize_path(out_path)
	img.save_png(abs_out)
	print("zombie_back_door.png -> %s" % abs_out)
	game.fx_telegraphs.clear()

	quit(0)
