extends SceneTree
# M16 polish closeout — capture zombie (procedural circles) vs NPC
# (character art) on the same frame. Verifies the §5.2 visual
# distinction: zombies are pale-green procedural dots, NPCs are full
# character portraits drawn via NpcSpriteLayer.
# Windowed (drop --headless): mounts NightShiftGame, spawns a few enemy
# tokens via _spawn_enemy_swarm, locks NPC sprites at default positions,
# saves PNG to user://screenshots/m16_zombie_vs_npc.png.

const I18n := preload("res://scripts/I18n.gd")
const OUTPUT_DIR := "user://screenshots"
const OUTPUT_FILE := "m16_zombie_vs_npc.png"


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture_zombie_vs_npc requires a display driver")
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

	# Force the game into night phase so the night bg renders and the
	# status bar / NPC layer are visible.
	game.call("_show_night")
	await process_frame

	# Place nora + elias on the field and refresh the layer so the
	# sprites draw at known positions.
	game.set("allies", {
		"nora": true,
		"elias": true,
		"victor": true,
		"lily": false,
		"daniel": false,
		"tom": false,
	})
	game.set("npc_state", {
		"nora": {
			"pos": Vector2(820.0, 360.0),
			"target": "",
			"commit_timer": 0.0,
			"walk_timer": 0.0,
			"eval_timer": 0.2,
			"speed": 180.0,
		},
		"elias": {
			"pos": Vector2(460.0, 360.0),
			"target": "",
			"commit_timer": 0.0,
			"walk_timer": 0.0,
			"eval_timer": 0.2,
			"speed": 180.0,
		},
	})

	var layer: Node = game.get("npc_sprite_layer")
	if layer == null:
		print("FAIL: npc_sprite_layer is null after _show_night")
		quit(1)
		return
	layer.call("add_ally", "nora", Vector2(820.0, 360.0))
	layer.call("add_ally", "elias", Vector2(460.0, 360.0))
	layer.call("refresh", game.get("npc_state"), 0.1)
	await process_frame

	# Seed two enemy swarms near the NPCs so the zombie procedural
	# circles (pale-green tint) overlap with the NPC art visually. The
	# NPCs sit between the swarm positions so the §5.2 contrast is
	# obvious in the snapshot. _spawn_enemy_swarm takes a hotspot dict
	# (we mock it with a single "pos" key) so the swarm center is at
	# the passed position.
	game.call("_spawn_enemy_swarm", "left_window", {"pos": Vector2(380.0, 360.0)})
	game.call("_spawn_enemy_swarm", "right_window", {"pos": Vector2(900.0, 360.0)})
	# _redraw_enemy_visuals runs the procedural circle pass (the pale-
	# green zombie dots + ±2 px jitter per polish spec §5.2).
	game.call("_redraw_enemy_visuals")
	await process_frame
	await process_frame

	# Re-apply the night bg in case anything overwrote it.
	var bg: TextureRect = game.get("bg")
	if bg != null and game.get("art") != null and (game.get("art") as Dictionary).has("night"):
		bg.texture = (game.get("art") as Dictionary)["night"]

	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	# Freeze so the capture reflects the laid-out scene, not the next
	# AI tick's repositioning.
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
	print("Zombie vs NPC capture: wrote %s (%d bytes)" % [out_path, bytes])
	if bytes < 50 * 1024:
		print("WARN: PNG under 50 KB threshold; check that NPC + zombie visuals actually drew")
	quit(0)