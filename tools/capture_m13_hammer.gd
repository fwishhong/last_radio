extends SceneTree
# Capture M13 art-based hammer sprites at 9 swing phases.
# Same boot sequence as capture_round2_1_fixes.gd (clear save, slot
# new, difficulty normal, start, day-card skip) so we land in a
# clean night 1 with the player pinned on left_window.
#
# Outputs (user://last_radio_v2_m13_capture/):
#   01_idle (no repair)            -- idle pose, hammer hidden
#   02_swing_t0.00 (start)         -- hammer up over shoulder
#   03_swing_t0.10 (lifting)       -- early forward arc
#   04_swing_t0.20 (top of arc)    -- hammer near horizontal
#   05_swing_t0.30 (over-arm)      -- committed forward thrust
#   06_swing_t0.45 (PEAK)          -- -PI/6 + 1.8 rad, hammer deep across body
#   07_swing_t0.55 (recovery)      -- hammer returning
#   08_swing_t0.70 (almost back)   -- near start position
#   09_swing_t0.85 (recovered)     -- nearly start pose
# + 3 crops centered on player at (270, 250).

const Save := preload("res://scripts/NightShiftSave.gd")
const OUTPUT_DIR := "user://last_radio_v2_m13_capture"

var _phases := [
	{"t": 0.00, "label": "02_swing_t0.00 (start, hammer up)"},
	{"t": 0.10, "label": "03_swing_t0.10 (lifting)"},
	{"t": 0.20, "label": "04_swing_t0.20 (top of arc)"},
	{"t": 0.30, "label": "05_swing_t0.30 (over-arm thrust 1.8 rad)"},
	{"t": 0.45, "label": "06_swing_t0.45 (PEAK -PI/6+1.8 rad ~73deg)"},
	{"t": 0.55, "label": "07_swing_t0.55 (recovery start)"},
	{"t": 0.70, "label": "08_swing_t0.70 (returning)"},
	{"t": 0.85, "label": "09_swing_t0.85 (almost back)"},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game: Node = scene.instantiate()
	root.add_child(game)
	for i in 4:
		await process_frame

	Save.clear_save()
	game._on_slot_new_pressed(1)
	await process_frame
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	await process_frame
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	for i in 3:
		await process_frame

	game.event_queue.clear()
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		h["value"] = h["max_value"]
		h["pressure"] = 0.0
		h["assault"] = false
		h["warning"] = false
		h["breach_timer"] = -1.0
		game.hotspots[id] = h
	game.player_pos = game.hotspots["left_window"]["pos"]
	game.set_process(false)

	# Shot 1: idle, no repair
	_set_player_state(game, "down", false, 0, false, 0.0)
	for i in 2:
		await process_frame
	_take_shot("01_idle")

	# Shots 2-9: each swing phase
	for phase_data in _phases:
		var t: float = phase_data["t"]
		var label: String = phase_data["label"]
		_set_player_state(game, "down", false, 0, true, t * 0.36)
		for i in 2:
			await process_frame
		print("  %s: hammer rot=%.3f rad (%.1f deg)" % [
			label, game.hammer_sprite.rotation, rad_to_deg(game.hammer_sprite.rotation)
		])
		var fname: String = label.split(" ")[0]
		_take_shot(fname)

	# Crops: center on player at (270, 250)
	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	for fname in ["01_idle", "05_swing_t0.30", "06_swing_t0.45"]:
		var p: String = abs_path + "/" + fname + ".png"
		var src: Image = Image.load_from_file(p)
		if src != null:
			var crop_w: int = 400
			var crop_h: int = 300
			var cx: int = max(0, 270 - crop_w / 2)
			var cy: int = max(0, 250 - crop_h / 2)
			var cropped: Image = src.get_region(Rect2i(cx, cy, crop_w, crop_h))
			cropped.save_png(abs_path + "/" + fname + "_crop.png")
			print("[cropped] " + fname + "_crop.png")

	print("M13 capture done: %s" % abs_path)
	quit(0)


func _set_player_state(game: Node, facing: String, moving: bool, walk_frame: int, repair: bool, repair_timer: float) -> void:
	game.player_facing = facing
	game.player_is_moving = moving
	game.player_walk_frame = walk_frame
	game.player_repair_active = repair
	game.player_repair_timer = repair_timer
	game._draw_player()


func _take_shot(name: String) -> void:
	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
	var img: Image = root.get_viewport().get_texture().get_image()
	if img == null:
		print("  %s: image null" % name)
		return
	var path := "%s/%s.png" % [abs_path, name]
	var err := img.save_png(path)
	if err == OK:
		print("  %s: %s" % [name, path])
	else:
		print("  %s: save_png error %d" % [name, err])