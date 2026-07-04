extends SceneTree
# M13 narrative-hooks — Night report 3-line body (Hook C) capture.
# Windowed (drop --headless): forces the game through a night → end_night
# → night_report flow for nights 1, 5, 9, and 10. Saves each as
# screenshots/m13_report_{1,5,9,10}.png.

const Game := preload("res://scripts/NightShiftGame.gd")
const I18n := preload("res://scripts/I18n.gd")
const NightShiftSave := preload("res://scripts/NightShiftSave.gd")
const OUTPUT_DIR := "user://screenshots"

var passed: int = 0
var failed: int = 0
var game: Node


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture_night_report_log requires a display driver")
		quit(0)
		return
	I18n.load_all()
	NightShiftSave.clear_save()
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	vp.add_child(game)
	await process_frame
	await process_frame

	# Bypass slot+difficulty pickers — jump straight to night 0.
	game._on_slot_new_pressed(1)
	game._on_difficulty_chosen(NightShiftSave.DIFFICULTY_NORMAL)
	await process_frame

	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	# Force-render nights 1, 5, 9, 10.
	for night_idx in [0, 4, 8, 9]:
		game.night_index = night_idx
		# Set up some allies diff so the narrative line isn't trivial.
		game.allies = {"nora": night_idx >= 0, "elias": night_idx >= 2, "victor": true}
		game.previous_allies = game.allies.duplicate(true)
		game.call("_show_night_report", true, "第 %d 夜的成功。城市西边又传来回响。" % (night_idx + 1))
		await process_frame
		await process_frame

		game.set_process(false)
		game.set_physics_process(false)
		await RenderingServer.frame_post_draw

		var out_file: String = "m13_report_%d.png" % (night_idx + 1)
		var tex := vp.get_texture()
		if tex == null:
			print("FAIL: viewport texture null for %s" % out_file)
			failed += 1
			continue
		var img := tex.get_image()
		if img == null:
			print("FAIL: image null for %s" % out_file)
			failed += 1
			continue
		var out_path: String = OUTPUT_DIR + "/" + out_file
		var abs_out: String = ProjectSettings.globalize_path(out_path)
		var err := img.save_png(abs_out)
		if err != OK:
			print("FAIL: save_png returned %d for %s" % [err, out_file])
			failed += 1
			continue
		var file := FileAccess.open(out_path, FileAccess.READ)
		if file == null:
			print("FAIL: cannot reopen %s" % out_file)
			failed += 1
			continue
		var bytes: int = file.get_length()
		file.close()
		print("  ok: %s (%d bytes)" % [out_file, bytes])
		passed += 1
		game.set_process(true)
		game.set_physics_process(true)

	print("Night report capture: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	quit(0 if failed == 0 else 1)