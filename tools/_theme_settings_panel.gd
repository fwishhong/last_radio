extends SceneTree
# Capture the actual settings panel (with sliders + checkboxes).

const OUTPUT_PATH := "C:/Users/Administrator/Desktop/codex/last_radio v2/screenshots/_audit_v2/03b_settings_panel_v3.png"

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	_run.call_deferred()

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game = scene.instantiate()
	vp.add_child(game)
	await process_frame
	await process_frame
	if game.menu_ui:
		var mu = game.menu_ui
		# Open settings panel directly without the pause middle step.
		if mu.has_method("_build"):
			mu._build()
		if mu.has_method("settings_panel_set_visible"):
			mu.settings_panel_set_visible(true)
		# Also force dim visible so the panel reads.
		if "_dim" in mu and mu._dim:
			mu._dim.visible = true
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	var img: Image = tex.get_image()
	img.save_png(OUTPUT_PATH)
	print("saved %s" % OUTPUT_PATH)
	quit(0)