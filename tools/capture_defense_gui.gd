extends SceneTree

func _initialize() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	if DisplayServer.get_name() != "headless":
		viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene: PackedScene = load("res://scenes/DefenseGame.tscn") as PackedScene
	var game := scene.instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame

	game.call("_select_signal", "garage_battery")
	game.call("_build_facility", "north_turret", "turret")
	game.call("_build_facility", "north_barricade", "barricade")
	game.call("_build_facility", "south_turret", "relay")
	game.call("_start_night")
	game.call("_tune_route", "south_gate")
	game.call("_use_radio_action", "jam")
	for i in range(120):
		game.call("_debug_step", 0.1)
		await process_frame
	for i in range(8):
		await process_frame
	if DisplayServer.get_name() != "headless":
		for i in range(4):
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			await process_frame
			await RenderingServer.frame_post_draw

	var texture := viewport.get_texture()
	if texture == null:
		push_error("Defense GUI capture needs a rendering backend; SubViewport texture is null.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("Defense GUI capture needs a rendering backend; SubViewport image is null.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("user://last_radio_defense_v04_gui.png")
	var err := image.save_png(path)
	if err != OK:
		push_error("Failed to save defense GUI capture: %s" % error_string(err))
		quit(1)
		return
	print(path)
	quit(0)
