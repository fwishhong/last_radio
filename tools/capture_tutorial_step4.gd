extends SceneTree
# M13 narrative-hooks — Tutorial step 4 (Hook B) capture.
# Windowed (drop --headless): mounts TutorialOverlay, drives step 4 with
# slider at 7.085 (Victor visible), saves PNG to
# screenshots/m13_tutorial_step4.png.

const TutorialOverlay := preload("res://scripts/TutorialOverlay.gd")
const I18n := preload("res://scripts/I18n.gd")
const OUTPUT_DIR := "user://screenshots"
const OUTPUT_FILE := "m13_tutorial_step4.png"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture_tutorial_step4 requires a display driver")
		quit(0)
		return
	I18n.load_all()
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	# Mount a real game scene so the background is non-trivial; then layer
	# the tutorial overlay on top. This makes the capture PNG > 50KB.
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game := scene.instantiate()
	vp.add_child(game)
	await process_frame
	await process_frame

	var overlay = TutorialOverlay.new()
	vp.add_child(overlay)
	overlay.start_step4_only()
	overlay._step4_slider.value = 7.085
	overlay._on_step4_slider_changed(overlay._step4_slider.value)
	# Wait long enough for the Victor fade-in tween (3s) to complete.
	await create_timer(3.5).timeout

	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	game.set_process(false)
	game.set_physics_process(false)
	overlay.set_process(false)
	overlay.set_physics_process(false)
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
	print("Tutorial step 4 capture: wrote %s (%d bytes)" % [out_path, bytes])
	quit(0)