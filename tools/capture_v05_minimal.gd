extends SceneTree

# v0.5 rewrite minimal capture - drives the basic phase machine and writes
# user://night_shift_v05_*.png for visual review.
# Unlike tools/capture_night_shift_gui.gd, this only exercises the parts
# implemented in the rewrite (cover/day/night/night_report/final).

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game := scene.instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	# Drive _process manually for visual frames so we don't depend on the engine loop.
	game.set_physics_process(false)

	# 1) Cover
	await _capture(viewport, "user://night_shift_v05_00_cover.png")
	print("  saved: cover")

	# 2) Day panel (1st night)
	game.call("_on_start_pressed")
	await process_frame
	await process_frame
	await _capture(viewport, "user://night_shift_v05_01_day.png")
	print("  saved: day panel")

	# 3) Night start
	game.call("_show_night")
	await process_frame
	await process_frame
	await _capture(viewport, "user://night_shift_v05_02_night_start.png")
	print("  saved: night start")

	# 4) Mid-night: simulate 20s of time, force a warning event visible
	game.set("night_elapsed", 18.0)
	game.set("player_pos", Vector2(640, 400))
	game.set("player_target_id", "")
	# Force front_door to warning state
	var h: Dictionary = game.get("hotspots")["front_door"]
	h["warning"] = true
	game.get("hotspots")["front_door"] = h
	# Trigger a manual visual update by calling _update_visual_feedback
	game.call("_update_visual_feedback")
	await process_frame
	await _capture(viewport, "user://night_shift_v05_03_night_warning.png")
	print("  saved: night mid warning")

	# 5) Player at hotspot repairing
	game.set("player_pos", Vector2(640, 612))
	game.set("player_target_id", "front_door")
	game.call("_update_player_target_reached")
	game.call("_update_night", 2.0)
	await process_frame
	await _capture(viewport, "user://night_shift_v05_04_night_repair.png")
	print("  saved: night repair")

	# 6) End night (success) -> report
	game.set("night_elapsed", 999.0)
	game.call("_update_night", 0.0)
	await process_frame
	await _capture(viewport, "user://night_shift_v05_05_night_report.png")
	print("  saved: night report (success)")

	# 7) Continue -> day 2
	game.call("_on_report_continue", true)
	await process_frame
	await process_frame
	await _capture(viewport, "user://night_shift_v05_06_day2.png")
	print("  saved: day 2")

	# Done
	game.queue_free()
	await process_frame
	quit(0)


func _capture(viewport: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	if img == null:
		print("  capture failed: %s (null image)" % path)
		return
	var err := img.save_png(path)
	if err != OK:
		print("  capture failed: %s (err=%d)" % [path, err])
