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
	if day_signals.size() >= 3:
		var noisy_signal: Dictionary = day_signals[2]
		screen.call("_refine_signal", str(noisy_signal.get("id", "")))
	await process_frame

	var tuning_slot: Control = screen.get("tuning_slot")
	if tuning_slot != null and tuning_slot.get_child_count() > 0:
		tuning_slot.get_child(0).call("_select_signal_by_ratio", 0.95)
	screen.call("_show_step", 0)
	await process_frame
	await process_frame
	await process_frame

	var texture := viewport.get_texture()
	if texture == null:
		push_error("Tuning panel capture failed: viewport texture unavailable.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("Tuning panel capture failed: viewport image unavailable.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("user://last_radio_tuning_panel.png")
	image.save_png(path)
	print(path)
	quit(0)
