extends SceneTree
# M13 narrative-hooks — Cover monologue capture (Hook A).
# Windowed (drop --headless): renders the cover screen with the 3-line
# narrator monologue, saves PNG to screenshots/m13_cover_monologue.png.

const OUTPUT_DIR := "user://screenshots"
const OUTPUT_FILE := "m13_cover_monologue.png"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture_cover_monologue requires a display driver")
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
	var game := scene.instantiate()
	vp.add_child(game)
	await process_frame
	await process_frame

	# Skip _ready's cover screen rebuild noise and trigger fresh monologue.
	# Wait 1.5s so the fade-in tween is mid-way (visible to the eye).
	await create_timer(1.5).timeout

	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

	var tex := vp.get_texture()
	if tex == null:
		print("FAIL: viewport texture is null")
		quit(1)
		return
	var img := tex.get_image()
	if img == null:
		print("FAIL: image is null")
		quit(1)
		return
	var out_path: String = OUTPUT_DIR + "/" + OUTPUT_FILE
	var abs_out: String = ProjectSettings.globalize_path(out_path)
	var err := img.save_png(abs_out)
	if err != OK:
		print("FAIL: save_png returned %d" % err)
		quit(1)
		return
	var file := FileAccess.open(out_path, FileAccess.READ)
	if file == null:
		print("FAIL: cannot reopen saved file")
		quit(1)
		return
	var bytes: int = file.get_length()
	file.close()
	print("Cover monologue capture: wrote %s (%d bytes)" % [out_path, bytes])
	quit(0)