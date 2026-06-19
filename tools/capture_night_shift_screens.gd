extends SceneTree
# Captures all key night_shift screens for visual regression.
# Run with NO --headless flag (rendering backend required for screenshots):
#   godot_console.exe --path . --script res://tools/capture_night_shift_screens.gd
# Output: <project_root>/screenshots/*.png  (1280x720 each)
# Why project root and not user://?  For solo dev iteration we want
# screenshots sitting next to the code so we can diff them, commit them
# (gated), and not dig into %APPDATA% every time.

const OUTPUT_DIR := "res://screenshots"
const VIEWPORT_SIZE := Vector2i(1280, 720)

var _captures: Array = []
var _vp: SubViewport
var _game: Node


func _initialize() -> void:
	_ensure_dir()
	_run.call_deferred()


func _ensure_dir() -> void:
	var abs_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)


func _run() -> void:
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

	# 0. Cover (fresh, no save)
	_game.set_process(false)
	_game.set_physics_process(false)
	await _shot("00_cover.png")

	# 1. Day panel — night 1 (skip only)
	_game.call("_on_new_game_pressed")
	_game.call("_show_day")
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await _shot("01_day_n01.png")

	# 2. Start night 1
	_game.call("_on_day_card_pressed", "start")
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await _shot("02_night_n01_start.png")

	# 3. Force a front_door assault with enemies
	_force_assault("front_door", 0.55)
	_game.call("_update_enemies", 0.1)
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await process_frame
	await _shot("03_night_n01_assault.png")

	# 4. Force a back_door assault — only available after night 6, so we simulate
	#    loading the data of a later night directly.
	_unlock_and_show_night(5, ["back_door"])
	_force_assault("back_door", 0.45)
	_game.call("_update_enemies", 0.1)
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await process_frame
	await _shot("04_night_n06_back_door_assault.png")

	# 5. Medbay assault — night 7 (support hotspot: use active/warning, not assault)
	_unlock_and_show_night(6, ["medbay"])
	_force_active("medbay", 0.40)
	_game.call("_update_enemies", 0.1)
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await process_frame
	await _shot("05_night_n07_medbay.png")

	# 6. Storage assault — night 8
	_unlock_and_show_night(7, ["storage"])
	_force_active("storage", 0.40)
	_game.call("_update_enemies", 0.1)
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await process_frame
	await _shot("06_night_n08_storage.png")

	# 6b. Medbay with simulated assault — verify enemies actually spawn for support
	#     hotspots too (force assault flag briefly so the spawner fires).
	_unlock_and_show_night(6, ["medbay"])
	_force_assault("medbay", 0.40)
	_game.call("_update_enemies", 0.1)
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await process_frame
	await _shot("06b_night_n07_medbay_assault.png")

	# 7. Day panel — night 2 (multiple cards)
	_game.night_index = 1
	_game.unlocked_hotspots = ["front_door", "left_window", "right_window", "generator"]
	_game.call("_show_day")
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await _shot("07_day_n02_cards.png")

	# 7b. Radio interaction panel — force the radio active and walk to it.
	_unlock_and_show_night(2, ["front_door", "left_window", "right_window", "generator", "radio"])
	_game.radio_available = true
	_game.radio_completed = false
	_game.radio_window_left = 30.0
	_game.radio_contact_goal = 1
	_game.radio_contacts_made = 0
	_game.radio_contact_progress = 1.4
	_game.radio_tuned_channel = ""  # not tuned yet
	_game.player_target_id = "radio"
	_game.player_at_target = true
	_game.player_pos = Vector2(440, 540)
	_game.call("_update_radio_panel")
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await _shot("07b_radio_interaction.png")

	# 7c. Radio panel — tuned to the correct channel with progress filling.
	_game.radio_tuned_channel = str(_game.radio_target_channel)
	_game.radio_contact_progress = 1.6  # ~half of RADIO_CONTACT_SECONDS (3.0)
	_game.call("_update_radio_panel")
	await process_frame
	await _shot("07c_radio_tuned_correct.png")

	# 7d. Radio panel — tuned to a wrong channel ("static").
	_game.radio_tuned_channel = "static"
	_game.radio_contact_progress = 0.0
	_game.call("_update_radio_panel")
	await process_frame
	await _shot("07d_radio_tuned_wrong.png")

	# 8. Success night report
	_game.night_index = 0
	_game.unlocked_hotspots = ["front_door", "left_window", "generator"]
	_game.call("_show_night")
	_force_safe_level_1()
	_game.call("_end_night", true)
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await _shot("08_night_report_success.png")

	# 9. Failure night report
	_force_assault_full_breach()
	_game.call("_end_night", false)
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await _shot("09_night_report_failure.png")

	# 10. Cover with continue
	_game.call("_show_cover_with_continue")
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await _shot("10_cover_with_continue.png")

	# 11. Final screen
	_game.night_index = 9
	_game.call("_show_final")
	_game.set_process(false)
	_game.set_physics_process(false)
	await process_frame
	await _shot("11_final.png")

	# Print summary
	print("=== Captured %d screenshots ===" % _captures.size())
	for path in _captures:
		print("  %s" % path)
	var abs := ProjectSettings.globalize_path(OUTPUT_DIR)
	print("Output dir: %s" % abs)
	quit(0)


func _shot(filename: String) -> void:
	# Pump frames so SubViewport actually rasterizes; then await frame_post_draw.
	for i in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	var tex := _vp.get_texture()
	if tex == null:
		push_error("[capture] viewport texture is null for %s" % filename)
		return
	var img := tex.get_image()
	if img == null:
		push_error("[capture] image is null for %s" % filename)
		return
	var out := OUTPUT_DIR + "/" + filename
	var err := img.save_png(ProjectSettings.globalize_path(out))
	if err != OK:
		push_error("[capture] save_png failed (%d) for %s" % [err, filename])
		return
	_captures.append(out)
	print("saved %s" % out)


func _force_assault(id: String, value_ratio: float) -> void:
	if not _game.hotspots.has(id):
		return
	var h: Dictionary = _game.hotspots[id]
	h["assault"] = true
	h["warning"] = false
	h["value"] = h["max_value"] * value_ratio
	_game.hotspots[id] = h


func _force_active(id: String, value_ratio: float) -> void:
	if not _game.hotspots.has(id):
		return
	var h: Dictionary = _game.hotspots[id]
	h["active"] = true
	h["warning"] = true
	h["value"] = h["max_value"] * value_ratio
	_game.hotspots[id] = h


func _force_safe_level_1() -> void:
	for id in ["front_door", "left_window", "generator"]:
		if not _game.hotspots.has(id):
			_game.hotspots[id] = {
				"id": id,
				"max_value": 100.0,
				"value": 100.0,
				"pressure": 0.0,
				"active": true,
				"warning": false,
				"assault": false,
				"breach_timer": -1.0,
			}
		else:
			var h: Dictionary = _game.hotspots[id]
			h["value"] = h["max_value"]
			h["pressure"] = 0.0
			h["active"] = true
			h["warning"] = false
			h["assault"] = false
			h["breach_timer"] = -1.0
			_game.hotspots[id] = h


func _force_assault_full_breach() -> void:
	for id in ["front_door", "left_window", "generator"]:
		if not _game.hotspots.has(id):
			_game.hotspots[id] = {
				"id": id,
				"max_value": 100.0,
				"value": 0.0,
				"pressure": 1.0,
				"warning": false,
				"assault": true,
				"breach_timer": 1.5,
			}
		else:
			var h: Dictionary = _game.hotspots[id]
			h["value"] = 0.0
			h["pressure"] = 1.0
			h["warning"] = false
			h["assault"] = true
			h["breach_timer"] = 1.5
			_game.hotspots[id] = h


func _unlock_and_show_night(night_index: int, extra_hotspots: Array) -> void:
	_game.night_index = night_index
	var unlocked: Array = []
	for hid in extra_hotspots:
		unlocked.append(hid)
	_game.unlocked_hotspots = unlocked
	_game.call("_show_night")
	# Force-initialize the unlocked hotspots with full value
	for hid in unlocked:
		if _game.hotspots.has(hid):
			var h: Dictionary = _game.hotspots[hid]
			h["value"] = h["max_value"]
			h["pressure"] = 0.0
			_game.hotspots[hid] = h