extends SceneTree
# Polish M10.5 visual capture. Renders the 4 main screens with the new
# title block + ally strip + resource chips + radio-panel-hide fix and
# saves 5 PNGs under user://last_radio_v2_m10_5_capture/. Re-run via
#   godot --path . --script res://tools/capture_v2_m10_5.gd
# (requires rendering backend — drop --headless).

const OUTPUT_DIR := "user://last_radio_v2_m10_5_capture"
const SHOTS := [
	{"fn": "01_cover_empty.png",      "wait_frames": 4,  "force_phase": ""},
	{"fn": "02_day_picker.png",       "wait_frames": 3,  "force_phase": "day"},
	{"fn": "03_night_running.png",    "wait_frames": 3,  "force_phase": "night"},
	{"fn": "04_night_report.png",     "wait_frames": 3,  "force_phase": "night_report"},
	{"fn": "05_final.png",            "wait_frames": 3,  "force_phase": "final"},
]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture_v2_m10_5 requires a display driver")
		quit(0)
		return
	_run.call_deferred()


func _run() -> void:
	var abs_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game: Node = scene.instantiate()
	vp.add_child(game)

	# Let the game fully initialize (load data, audio, walk frames, etc).
	for i in range(8):
		await process_frame
	game.set_process(false)
	game.set_physics_process(false)

	for shot in SHOTS:
		# Switch into the requested phase by calling the relevant entry
		# point on the game script. Cover is the default after _ready.
		match str(shot.get("force_phase", "")):
			"day":
				if game.has_method("_show_day"):
					game.call("_show_day")
			"night":
				if game.has_method("_show_night"):
					game.call("_show_night")
			"night_report":
				if game.has_method("_show_night_report"):
					game.call("_show_night_report", true, "第 1 夜 守住了。")
			"final":
				if game.has_method("_show_final"):
					game.call("_show_final")
		for i in range(int(shot.get("wait_frames", 3))):
			await process_frame
		await RenderingServer.frame_post_draw
		var tex := vp.get_texture()
		if tex == null:
			print("WARN: viewport texture null for %s" % shot.fn)
			continue
		var img := tex.get_image()
		if img == null:
			print("WARN: image null for %s" % shot.fn)
			continue
		var out_path: String = OUTPUT_DIR + "/" + str(shot.fn)
		var abs_out: String = ProjectSettings.globalize_path(out_path)
		var err := img.save_png(abs_out)
		print("  %s -> %s (%d bytes)" % [shot.fn, "OK" if err == OK else "ERR", (img.get_width() * img.get_height() * 4)])
	# Reset cover for sanity (so any test that runs after this starts fresh).
	if game.has_method("_show_slot_picker"):
		game.call("_show_slot_picker")
	quit(0)
