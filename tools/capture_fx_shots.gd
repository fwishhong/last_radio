extends SceneTree
# Quick capture: drives the game into a few moments of night play and
# captures one screenshot each, so we can see the FX stack actually firing.

const Fx := preload("res://scripts/NightShiftFx.gd")
const Save := preload("res://scripts/NightShiftSave.gd")
const OUTPUT_DIR := "user://last_radio_v2_fx_shots"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: needs display driver")
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
	for i in 4:
		await process_frame

	# Start a fresh run on slot 1.
	Save.clear_save()
	game._on_slot_new_pressed(1)
	await process_frame
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	await process_frame
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	for i in 3:
		await process_frame

	# Frame 1: clean night (no FX yet)
	_take_shot(vp, game, "01_clean")

	# Frame 2: trigger a warning telegraph on front_door
	game.fx_telegraphs.clear()
	Fx.telegraph_schedule(game.fx_telegraphs, "front_door", 2.0, "assault")
	for i in 4:
		await process_frame
	_take_shot(vp, game, "02_telegraph")

	# Frame 3: spawn a breach (force value=0 and force the breach explosion)
	game.fx_particles.clear()
	game.fx_telegraphs.clear()
	var fd: Dictionary = game.hotspots["front_door"]
	fd["assault"] = true
	game.hotspots["front_door"] = fd
	Fx.burst_breach(game.fx_particles, game.hotspots["front_door"]["pos"], 1.5)
	Fx.shake_trigger(game.fx_shake, 12.0, 4.0, 22.0)
	for i in 4:
		await process_frame
	_take_shot(vp, game, "03_breach")

	# Frame 4: critical-overlay on (drop a hotspot to 10%) + threat arrows
	game.fx_particles.clear()
	game.fx_telegraphs.clear()
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		h["value"] = h["max_value"] * 0.15
		h["assault"] = (id == "back_door" or id == "left_window")
		game.hotspots[id] = h
	game.player_pos = Vector2(640, 400)
	for i in 6:
		await process_frame
	_take_shot(vp, game, "04_critical_threat")

	# Frame 5: radio static (tune to static channel)
	game.fx_particles.clear()
	game.fx_telegraphs.clear()
	game.radio_available = true
	game.radio_completed = false
	game.radio_tuned_channel = "static"
	game.radio_window_left = 30.0
	for i in 10:
		await process_frame
	_take_shot(vp, game, "05_radio_static")

	# Frame 6: dawn fade (simulate end-of-night success)
	game.fx_particles.clear()
	game.fx_telegraphs.clear()
	game.fx_dawn_target = 1.0
	for i in 90:
		await process_frame
	_take_shot(vp, game, "06_dawn_fade")

	print("FX capture complete: %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _take_shot(vp: SubViewport, game: Node, name: String) -> void:
	var abs_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
	await RenderingServer.frame_post_draw
	var tex := vp.get_texture()
	if tex == null:
		print("  %s: texture null" % name)
		return
	var img := tex.get_image()
	if img == null:
		print("  %s: image null" % name)
		return
	var path := "%s/%s.png" % [abs_path, name]
	var err := img.save_png(path)
	if err == OK:
		print("  %s: %s" % [name, path])
	else:
		print("  %s: save_png error %d" % [name, err])
