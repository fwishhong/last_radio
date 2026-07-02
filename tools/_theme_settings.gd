extends SceneTree
# Capture settings screen (MenuUI) with new theme.

const OUTPUT_PATH := "C:/Users/Administrator/Desktop/codex/last_radio v2/screenshots/_audit_v2/03_settings_v3_theme.png"

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
	# Polish M11: call open_pause (which sets up dim + pause panel) then
	# click the "settings" button programmatically to show the settings
	# panel.
	if game.menu_ui:
		var mu = game.menu_ui
		if mu.has_method("open_pause"):
			mu.open_pause()
		elif mu.has_method("settings_panel_set_visible"):
			mu.settings_panel_set_visible(true)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("FAIL: no texture")
		quit(1)
		return
	var img: Image = tex.get_image()
	img.save_png(OUTPUT_PATH)
	print("saved %s" % OUTPUT_PATH)
	quit(0)