extends SceneTree
# M16 polish closeout — capture NPC idle sprite (Nora + Elias).
# Windowed (drop --headless): mounts NightShiftGame, drives the game to
# night 2/3 so both NPCs are unlocked + on-field, forces them to a
# resting (idle) state, saves PNG to user://screenshots/m16_npc_idle.png.
# Goal: visual confirmation that the new NpcSpriteLayer actually draws
# Nora/Elias portraits on the night-battlefield.

const I18n := preload("res://scripts/I18n.gd")
const OUTPUT_DIR := "user://screenshots"
const OUTPUT_FILE := "m16_npc_idle.png"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture_npc_sprite_idle requires a display driver")
		quit(0)
		return
	I18n.load_locale("zh")
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

	# Force the game into a state where both nora and elias are in the
	# rotation and at rest. We bypass the day card picker and inject
	# `allies` / `npc_state` directly so the capture is deterministic.
	game.set("allies", {
		"nora": true,
		"elias": true,
		"victor": true,
		"lily": false,
		"daniel": false,
		"tom": false,
	})
	# Match NPC_INIT_POS — nora at (800, 360), elias at (480, 360).
	game.set("npc_state", {
		"nora": {
			"pos": Vector2(800.0, 360.0),
			"target": "",
			"commit_timer": 0.0,
			"walk_timer": 0.0,
			"eval_timer": 0.2,
			"speed": 180.0,
		},
		"elias": {
			"pos": Vector2(480.0, 360.0),
			"target": "",
			"commit_timer": 0.0,
			"walk_timer": 0.0,
			"eval_timer": 0.2,
			"speed": 180.0,
		},
	})

	# Drive the game into night phase so the night bg renders and the
	# status bar / NPC layer are visible. _show_night flips phase to
	# "night" and resets timers without needing the day picker.
	game.call("_show_night")
	await process_frame

	# Materialise the sprites via the layer's add_ally API (mirrors what
	# the unlock site does at line ~3722 of NightShiftGame.gd).
	var layer: Node = game.get("npc_sprite_layer")
	if layer == null:
		print("FAIL: npc_sprite_layer is null after _show_night")
		quit(1)
		return
	layer.call("add_ally", "nora", Vector2(800.0, 360.0))
	layer.call("add_ally", "elias", Vector2(480.0, 360.0))

	# One more refresh cycle so the layer locks to idle texture.
	layer.call("refresh", game.get("npc_state"), 0.1)
	await process_frame
	await process_frame

	# Make sure the night-battlefield bg is up. _show_night already sets
	# `bg.texture = art["night"]`, but we explicitly re-apply in case
	# capture ordering races.
	var bg: TextureRect = game.get("bg")
	if bg != null and game.get("art") != null and (game.get("art") as Dictionary).has("night"):
		bg.texture = (game.get("art") as Dictionary)["night"]

	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	# Freeze updates before snapping so the capture reflects the locked
	# idle pose, not whatever the next tick happens to compute.
	game.set_process(false)
	game.set_physics_process(false)
	if layer != null:
		layer.set_process(false)
		layer.set_physics_process(false)
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
	print("NPC idle capture: wrote %s (%d bytes)" % [out_path, bytes])
	if bytes < 50 * 1024:
		print("WARN: PNG under 50 KB threshold; check that sprites actually drew")
	quit(0)