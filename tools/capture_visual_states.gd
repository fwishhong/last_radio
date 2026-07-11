extends SceneTree
# tools/capture_visual_states.gd
#
# Renders four reference PNGs that visualize the visual-bugs-demo-pass
# acceptance bar. Run AFTER the fix branch merges; compare against the
# pre-fix equivalents the dev worker captured during development.
#
# Usage:
#   godot --path . --script res://tools/capture_visual_states.gd
#
# Output (under user://, copy to screenshots/visual_demo_pass/ for review):
#   01_slot_picker.png             cover screen, expect: no player visible
#   02_barrier_repair_mid.png      repair barrier, expect: hammer token only (no walk sprite)
#   03_generator_repair_mid.png    repair generator, expect: hammer token (was missing pre-fix)
#   04_antenna_repair_mid.png      repair antenna, expect: hammer token (was missing pre-fix)

const NightShiftGame := preload("res://scripts/NightShiftGame.gd")
const NightShiftSave := preload("res://scripts/NightShiftSave.gd")
const I18n := preload("res://scripts/I18n.gd")

const OUT_DIR := "user://visual_demo_pass/"


func _initialize() -> void:
	I18n.load_all()
	I18n.locale = "zh"
	NightShiftSave.clear_save()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	await _capture_slot_picker()
	await _capture_barrier_repair()
	await _capture_generator_repair()
	await _capture_antenna_repair()

	print("[capture_visual_states] wrote 4 PNGs to %s" % ProjectSettings.globalize_path(OUT_DIR))
	quit(0)


func _setup_viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


func _save(vp: SubViewport, name: String) -> void:
	var texture := vp.get_texture()
	if texture == null:
		push_error("viewport texture unavailable for %s" % name)
		return
	var image := texture.get_image()
	if image == null:
		push_error("viewport image unavailable for %s" % name)
		return
	var path := ProjectSettings.globalize_path(OUT_DIR + name + ".png")
	image.save_png(path)
	print("  wrote %s" % path)


func _mount_game(vp: SubViewport) -> Node:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game: Node = scene.instantiate()
	vp.add_child(game)
	await process_frame
	await process_frame
	return game


func _enter_night(game: Node) -> void:
	game.call("_on_slot_new_pressed", 1)
	await process_frame
	game.call("_on_difficulty_chosen", NightShiftSave.DIFFICULTY_NORMAL)
	await process_frame
	game.call("_show_night")
	await process_frame


func _drive_repair_tick(game: Node, hotspot_id: String) -> void:
	var pos: Vector2 = (game.get("HOTSPOT_POSITIONS") as Dictionary)[hotspot_id]
	game.set("player_pos", pos)
	game.set("player_target_id", hotspot_id)
	game.set("player_at_target", true)
	game.set("player_repair_active", false)
	game.set("player_repair_timer", 0.18)  # mid-swing phase
	game.call("_update_hotspots", 0.1)
	if game.has_method("_draw_player"):
		game.call("_draw_player")
	await process_frame
	await process_frame
	await process_frame


func _capture_slot_picker() -> void:
	print("[1/4] slot picker (expect: no player visible)")
	var vp := _setup_viewport()
	var game: Node = await _mount_game(vp)
	game.call("_show_slot_picker")
	await process_frame
	await process_frame
	await _save(vp, "01_slot_picker")
	vp.queue_free()


func _capture_barrier_repair() -> void:
	print("[2/4] barrier repair mid-swing (expect: hammer token, no walk sprite)")
	var vp := _setup_viewport()
	var game: Node = await _mount_game(vp)
	await _enter_night(game)
	await _drive_repair_tick(game, "front_door")
	await _save(vp, "02_barrier_repair_mid")
	vp.queue_free()


func _capture_generator_repair() -> void:
	print("[3/4] generator repair mid-swing (expect: hammer token, was missing pre-fix)")
	var vp := _setup_viewport()
	var game: Node = await _mount_game(vp)
	await _enter_night(game)
	await _drive_repair_tick(game, "generator")
	await _save(vp, "03_generator_repair_mid")
	vp.queue_free()


func _capture_antenna_repair() -> void:
	print("[4/4] antenna repair mid-swing (expect: hammer token, was missing pre-fix)")
	var vp := _setup_viewport()
	var game: Node = await _mount_game(vp)
	await _enter_night(game)
	# night 1 may not have antenna unlocked yet; force-unlock + use the
	# antenna hotspot position. Antenna's kind isn't always 'antenna' in
	# the data; verify after the dev worker's PlayerRepairFx change.
	var hotspots: Dictionary = game.get("hotspots")
	if not hotspots.has("antenna"):
		# Inject a synthetic antenna hotspot for the screenshot.
		var antenna_pos: Vector2 = (game.get("HOTSPOT_POSITIONS") as Dictionary).get("antenna", Vector2(960, 540))
		hotspots["antenna"] = {
			"pos": antenna_pos,
			"kind": "antenna",
			"value": 80.0,
			"max_value": 100.0,
			"pressure": 0.0,
			"warning": false,
			"assault": false,
			"breach_timer": -1.0,
		}
	await _drive_repair_tick(game, "antenna")
	await _save(vp, "04_antenna_repair_mid")
	vp.queue_free()