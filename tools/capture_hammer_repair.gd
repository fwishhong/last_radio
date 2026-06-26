extends SceneTree
# Polish M10.5 fix capture -- hammer / repair sprite.
# Walks the player to the generator hotspot and triggers a repair tick so
# the hammer sprite is visible. Used to compare the "before" (hammer
# overlapping the player) and "after" (hammer moved outside the hotspot
# circle) framings of the polish spec §4.5 fix.

const OUTPUT_DIR := "user://last_radio_v2_hammer_fix_capture"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture_hammer requires a display driver")
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

	# Let the game fully initialize.
	for i in range(8):
		await process_frame
	# Stop the game tree entirely so _show_night / _process can't override
	# the values we set below (the SubViewport's root keeps ticking, which
	# would otherwise reset player_pos on the next night-show call).
	game.process_mode = Node.PROCESS_MODE_DISABLED

	# Force into a night so hotspots are built.
	if game.has_method("_show_night"):
		game.call("_show_night")
	for i in range(3):
		await process_frame

	# Pin the player to the front_door hotspot (barrier kind = only one
	# that triggers the hammer sprite per PlayerRepairFx.is_repairable_hotspot)
	# and set it as the active target so the hammer sprite lights up.
	var player_pos_value: Vector2 = game.get("player_pos")
	var hotspots_value: Dictionary = game.get("hotspots")
	var target_pos: Vector2 = hotspots_value["front_door"]["pos"]
	# Stand a bit below the door so the player is inside the attack circle
	# (HOTSPOT_REACH = 70) and the hammer can sit on the player-side edge.
	game.set("player_pos", target_pos + Vector2(0.0, 60.0))
	game.set("player_target_id", "front_door")
	game.set("player_at_target", true)
	# Force the repair flag on so the hammer sprite is visible on the next draw.
	game.set("player_repair_active", true)
	# Pin the timer so the swing is mid-arc (phase ~ 0.25 -> mid-swing).
	game.set("player_repair_timer", 0.18)

	for i in range(4):
		await process_frame
	# Force a redraw of the player so the new position / hammer sprite
	# are committed before we capture.
	if game.has_method("_draw_player"):
		game.call("_draw_player")
	await RenderingServer.frame_post_draw

	var tex := vp.get_texture()
	var img := tex.get_image()
	var out_path: String = OUTPUT_DIR + "/hammer_repair.png"
	var abs_out: String = ProjectSettings.globalize_path(out_path)
	var err := img.save_png(abs_out)
	print("hammer_repair.png -> %s (%d bytes, player_pos=%s hotspot=%s)" % [
		"OK" if err == OK else "ERR",
		img.get_width() * img.get_height() * 4,
		str(player_pos_value),
		str(target_pos)
	])
	quit(0)