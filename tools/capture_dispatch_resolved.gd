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

	var day_signals: Array = screen.get("day_signals")
	var first_signal: Dictionary = day_signals[0]
	screen.call("_lock_signal", str(first_signal.get("id", "")))
	screen.call("_confirm_signal", str(first_signal.get("id", "")))
	screen.call("_show_step", 2)
	await process_frame
	var members: Array[String] = ["a_qing"]
	var items: Array[String] = ["radio"]
	screen.call("_launch_dispatch", members, items, "route_warning", "safe")
	if not (screen.get("pending_dispatch_context") as Dictionary).is_empty():
		screen.call("_resolve_pending_dispatch", "secure_exit")
	await process_frame

	var dispatch_slot: Control = screen.get("dispatch_slot")
	if dispatch_slot != null and dispatch_slot.get_child_count() > 0:
		var panel := dispatch_slot.get_child(0)
		for _tick in range(14):
			panel.call("_advance_transmission")
	await process_frame
	await process_frame
	await process_frame

	var texture := viewport.get_texture()
	if texture == null:
		push_error("Dispatch resolved capture failed: viewport texture unavailable.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("Dispatch resolved capture failed: viewport image unavailable.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("user://last_radio_dispatch_resolved.png")
	image.save_png(path)
	print(path)
	quit(0)
