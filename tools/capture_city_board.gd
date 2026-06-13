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

	var clear := ColorRect.new()
	clear.color = Color(0.010, 0.018, 0.018, 1.0)
	clear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(clear)

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
	var day_signals: Array = screen.get("day_signals")
	if not day_signals.is_empty():
		var first_signal: Dictionary = day_signals[0]
		var signal_id := str(first_signal.get("id", ""))
		screen.call("_lock_signal", signal_id)
		screen.call("_mark_signal", signal_id, "trusted")
	var resources: Dictionary = screen.get("resources")
	resources["influence"] = 1
	screen.call("_apply_city_action", "north_bridge", "warn")
	screen.call("_show_step", 1)
	await process_frame
	await process_frame
	await process_frame

	var texture := viewport.get_texture()
	if texture == null:
		push_error("City board capture failed: viewport texture unavailable.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("City board capture failed: viewport image unavailable.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("user://last_radio_city_board.png")
	image.save_png(path)
	print(path)
	quit(0)
