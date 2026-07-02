extends SceneTree
# Theme verification: night HUD with chip bar + hint label.

const OUTPUT_PATH := "C:/Users/Administrator/Desktop/codex/last_radio v2/screenshots/_audit_v2/02_night_hud_v3_theme.png"

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
	game.call("_show_night")
	await process_frame
	if game.night_cg_overlay:
		game.night_cg_overlay.dismiss()
	if game.tutorial_overlay:
		game.tutorial_overlay.skip()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("FAIL: no texture")
		quit(1)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("FAIL: no image")
		quit(1)
		return
	img.save_png(OUTPUT_PATH)
	print("saved %s" % OUTPUT_PATH)
	quit(0)
