extends SceneTree

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	if DisplayServer.get_name() != "headless":
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var host := Control.new()
	host.size = Vector2(1280, 720)
	viewport.add_child(host)

	var scene: PackedScene = load("res://scenes/BaseScreen.tscn") as PackedScene
	var screen := scene.instantiate()
	host.add_child(screen)
	if screen is Control:
		(screen as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	if screen.has_method("_dismiss_intro_briefing"):
		screen.call("_dismiss_intro_briefing")
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var texture := viewport.get_texture()
	if texture == null:
		push_error("V2 GUI capture needs a rendering backend; SubViewport texture is null.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("V2 GUI capture needs a rendering backend; SubViewport image is null.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("user://last_radio_v2_gui.png")
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save GUI capture: %s" % error_string(err))
		quit(1)
		return
	print(path)
	quit(0)
