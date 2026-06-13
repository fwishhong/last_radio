extends SceneTree

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var host := Control.new()
	host.size = Vector2(1280, 720)
	viewport.add_child(host)

	var scene: PackedScene = load("res://scenes/BaseScreen.tscn") as PackedScene
	var screen: Node = scene.instantiate()
	host.add_child(screen)
	if screen is Control:
		(screen as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	if screen.has_method("_dismiss_intro_briefing"):
		screen.call("_dismiss_intro_briefing")
	await process_frame

	for target_day in [1, 2, 3]:
		var day_signals: Array = screen.get("day_signals")
		var first_signal: Dictionary = day_signals[0]
		screen.call("_lock_signal", str(first_signal.get("id", "")))
		if target_day == 1:
			screen.call("_confirm_signal", str(first_signal.get("id", "")))
		var location_id := str(first_signal.get("location", ""))
		if location_id == "base":
			location_id = "garage"
		screen.call("_select_location", location_id)
		var members: Array[String] = ["a_qing"]
		var items: Array[String] = ["radio"]
		screen.call("_launch_dispatch", members, items, "route_warning", "safe")
		if not (screen.get("pending_dispatch_context") as Dictionary).is_empty():
			screen.call("_resolve_pending_dispatch", "secure_exit")
		screen.call("_night_lines")
		if target_day < 3:
			screen.call("_start_day", target_day + 1)

	screen.set("final_report", screen.call("_build_final_report"))
	screen.call("_show_final_report")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var image := viewport.get_texture().get_image()
	var path := ProjectSettings.globalize_path("user://last_radio_final_report.png")
	image.save_png(path)
	print(path)
	quit(0)
