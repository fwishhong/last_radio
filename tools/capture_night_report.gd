extends SceneTree

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene: PackedScene = load("res://scenes/BaseScreen.tscn") as PackedScene
	var screen: Node = scene.instantiate()
	viewport.add_child(screen)
	await process_frame
	await process_frame
	if screen.has_method("_dismiss_intro_briefing"):
		screen.call("_dismiss_intro_briefing")
	await process_frame

	var day_signals: Array = screen.get("day_signals")
	var first_signal: Dictionary = day_signals[0]
	screen.call("_lock_signal", str(first_signal.get("id", "")))
	screen.call("_confirm_signal", str(first_signal.get("id", "")))
	screen.call("_mark_signal", str(first_signal.get("id", "")), "trusted")
	var members: Array[String] = ["a_qing"]
	var items: Array[String] = ["radio"]
	screen.call("_launch_dispatch", members, items, "route_warning", "safe")
	if not (screen.get("pending_dispatch_context") as Dictionary).is_empty():
		screen.call("_resolve_pending_dispatch", "secure_exit")
	screen.call("_show_night_report")
	var overlay: Control = screen.get("overlay_layer")
	if overlay != null and overlay.get_child_count() > 0:
		var report := overlay.get_child(0)
		report.call("_advance_replay")
		report.call("_advance_replay")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var image := viewport.get_texture().get_image()
	var path := ProjectSettings.globalize_path("user://last_radio_night_report.png")
	image.save_png(path)
	print(path)
	quit(0)
