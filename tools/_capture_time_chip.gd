extends SceneTree
# Capture the new time chip at 4 progress points (start / 1/4 / 3/4 /
# end) so the reviewer can verify the clock-face mapping
# (22:00 → 06:00) and the countdown + progress bar all match.
# Polish M12.
#
# Run with: godot_console.exe --path . --script res://tools/_capture_time_chip.gd
# Output:  screenshots/_audit_m12/time_chip_{start,quarter,three_quarter,end}.png

const SCENE := "res://scenes/NightShiftGame.tscn"
const OUT_DIR := "C:/Users/Administrator/Desktop/codex/last_radio v2/screenshots/_audit_m12"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	_run.call_deferred()


func _save(vp: SubViewport, name: String) -> void:
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("FAIL: no texture for %s" % name)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("FAIL: no image for %s" % name)
		return
	var out := "%s/%s.png" % [OUT_DIR, name]
	img.save_png(out)
	print("saved %s" % out)


func _setup() -> SubViewport:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: PackedScene = load(SCENE) as PackedScene
	var game = scene.instantiate()
	vp.add_child(game)
	# Let _ready run
	await process_frame
	await process_frame
	game.call("_show_night")
	await process_frame
	if game.night_cg_overlay:
		game.night_cg_overlay.dismiss()
	if game.tutorial_overlay:
		game.tutorial_overlay.skip()
	await process_frame
	return vp


func _set_progress(game: Node, frac: float) -> void:
	# Night 3+ is 180s; setting elapsed proportionally gives a clean
	# full 8h shift to map onto. Bypasses the night tick so the chip
	# doesn't immediately jump back to 0.
	game.night_elapsed = game.night_duration * clamp(frac, 0.0, 1.0)
	game.call("_update_status_label")
	await process_frame
	await process_frame


func _run() -> void:
	var vp: SubViewport = await _setup()
	# Game is the direct child of the viewport. The scene also nests a
	# CanvasLayer (hud_layer) inside it, so vp.get_child(0).get_child(0)
	# would land on a CanvasLayer, not the Game node.
	var game: Node = vp.get_child(0)

	await _set_progress(game, 0.0)
	await _save(vp, "time_chip_start")
	await _set_progress(game, 0.25)
	await _save(vp, "time_chip_quarter")
	await _set_progress(game, 0.75)
	await _save(vp, "time_chip_three_quarter")
	await _set_progress(game, 1.0)
	await _save(vp, "time_chip_end")

	print("done")
	quit(0)
