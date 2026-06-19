extends SceneTree
# Smoke test: verifies the capture pipeline produces valid PNG files.
# Runs WITHOUT --headless (requires rendering backend). Skips on headless.
# Asserts: at least N PNGs in user://last_radio_screens/, each file size > 1KB.

const OUTPUT_DIR := "user://last_radio_screens"
const MIN_BYTES := 1024


var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture_smoke requires a display driver")
		quit(0)
		return
	_run.call_deferred()


func _run() -> void:
	# Use the same SubViewport recipe as the real capture script.
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game := scene.instantiate()
	vp.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)

	var abs_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	# Take 3 deterministic shots to verify the pipeline.
	var filenames := ["smoke_00.png", "smoke_01.png", "smoke_02.png"]
	for fn in filenames:
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var tex := vp.get_texture()
		_assert(tex != null, "%s: viewport texture is non-null" % fn)
		if tex == null:
			continue
		var img := tex.get_image()
		_assert(img != null, "%s: image is non-null" % fn)
		if img == null:
			continue
		_assert(img.get_width() == 1280 and img.get_height() == 720, "%s: image is 1280x720" % fn)
		var out_path: String = OUTPUT_DIR + "/" + fn
		var abs_out: String = ProjectSettings.globalize_path(out_path)
		var err := img.save_png(abs_out)
		_assert(err == OK, "%s: save_png returns OK" % fn)
		var file := FileAccess.open(out_path, FileAccess.READ)
		if file != null:
			var bytes := file.get_length()
			file.close()
			_assert(bytes >= MIN_BYTES, "%s: file has at least %d bytes (got %d)" % [fn, MIN_BYTES, bytes])

	print("Capture smoke: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	quit(0 if failed == 0 else 1)


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1