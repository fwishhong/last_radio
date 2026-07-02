extends SceneTree
# Final verification capture: night HUD with CG dismissed, so all HUD
# elements (chip bar with refugees, hint label) are visible.

const OUTPUT_PATH := "C:/Users/Administrator/Desktop/codex/last_radio v2/screenshots/_audit_v2/02_night_hud_clean.png"

var _vp: SubViewport
var _game: Node

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	_run.call_deferred()

func _run() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	_game = scene.instantiate()
	_vp.add_child(_game)
	await process_frame
	await process_frame
	_game.call("_show_night")
	await process_frame
	# Dismiss the CG overlay so the HUD is visible
	if _game.night_cg_overlay:
		_game.night_cg_overlay.dismiss()
	# Skip tutorial if up
	if _game.tutorial_overlay:
		_game.tutorial_overlay.skip()
	await process_frame
	await process_frame
	await _shot()
	quit(0)

func _shot() -> void:
	for i in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	var tex := _vp.get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	img.save_png(OUTPUT_PATH)
	print("saved %s" % OUTPUT_PATH)
