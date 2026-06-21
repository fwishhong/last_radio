extends SceneTree
# Focused capture of the day-2 card picker (the 4-card overflow case).
# Verifies the layout fix: all four panels (3 upgrades + skip) now fit
# inside the 1280px viewport with side_margin cushions.
#
# Run without --headless (rendering backend required):
#   godot_console.exe --path . --script res://tools/capture_day_picker_fix.gd
# Output: screenshots/art_audit/day_picker_layout_fixed.png

const OUTPUT_PATH := "res://screenshots/art_audit/day_picker_layout_fixed.png"
const VIEWPORT_SIZE := Vector2i(1280, 720)

var _vp: SubViewport
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var abs_dir := ProjectSettings.globalize_path("res://screenshots/art_audit")
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)

	_vp = SubViewport.new()
	_vp.size = VIEWPORT_SIZE
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	_game = scene.instantiate()
	_vp.add_child(_game)
	await process_frame
	await process_frame

	# Jump straight to night-2 day picker (4-card case).
	_game.night_index = 1
	_game.unlocked_hotspots = ["front_door", "left_window", "right_window", "generator"]
	_game.call("_show_day")
	_game.set_process(false)
	_game.set_physics_process(false)
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw

	var tex := _vp.get_texture()
	var img := tex.get_image()
	var err := img.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if err != OK:
		push_error("save_png failed (%d)" % err)
		quit(1)
		return

	# Print layout facts for the test record.
	var panels: Array = []
	for c in _game.card_layer.get_children():
		if c is Panel:
			panels.append(c)
	print("=== Day-2 picker layout ===")
	print("  panels: %d" % panels.size())
	for i in range(panels.size()):
		var p: Panel = panels[i]
		print("  card[%d] x=%.1f w=%.1f right=%.1f" % [
			i, p.position.x, p.size.x, p.position.x + p.size.x
		])
	print("  screen_w: %.1f" % float(_game.SCREEN_SIZE.x))
	print("  saved: %s" % OUTPUT_PATH)
	quit(0)