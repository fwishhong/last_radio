extends SceneTree
# Regression test for the v0.5 actor-art regression.
#
# Before this fix, _draw_player always rendered walk-frame 0 when the
# player wasn't moving; the actor_player_{front,back,side}.png source
# art sat unused even though it was authored and process_player_actor_sources.py
# shipped it into assets/final/night_shift/.
#
# This test boots the night, walks the player for a few frames to force
# movement, then stops movement and verifies that the rendered texture
# is the actor art (size 768x1024), not a 128x160 walk sprite.

const Save := preload("res://scripts/NightShiftSave.gd")

var game: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Save.clear_save()
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	for i in 4: await process_frame

	game._on_slot_new_pressed(1)
	await process_frame
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	await process_frame
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	for i in 6: await process_frame

	# Verify actor_textures dict was populated at scene boot.
	var actor_front = game.actor_textures.get("front", null)
	var actor_back = game.actor_textures.get("back", null)
	var actor_side = game.actor_textures.get("side", null)
	if actor_front == null:
		print("FAIL: actor_textures.front is null")
		quit(1); return
	if actor_back == null:
		print("FAIL: actor_textures.back is null")
		quit(1); return
	if actor_side == null:
		print("FAIL: actor_textures.side is null")
		quit(1); return
	print("ok: actor textures loaded (front=%dx%d back=%dx%d side=%dx%d)" % [
		actor_front.get_width(), actor_front.get_height(),
		actor_back.get_width(), actor_back.get_height(),
		actor_side.get_width(), actor_side.get_height(),
	])

	# Phase 1: idle, facing down -> actor front
	game.player_is_moving = false
	game.player_facing = "down"
	var idle_down: Dictionary = _observe()
	if "actor_player_front" not in idle_down.texture_path:
		print("FAIL: idle facing down should show actor_player_front, got %s" % idle_down.texture_path)
		quit(1); return
	if abs(idle_down.scale.x - 128.0 / 768.0) > 0.001:
		print("FAIL: idle down scale.x should be 128/768, got %f" % idle_down.scale.x)
		quit(1); return
	if idle_down.flip_h:
		print("FAIL: idle down should not be flipped")
		quit(1); return
	print("ok: idle facing down -> actor_player_front, scale=128/768")

	# Phase 2: idle, facing up -> actor back
	game.player_facing = "up"
	var idle_up: Dictionary = _observe()
	if "actor_player_back" not in idle_up.texture_path:
		print("FAIL: idle up should show actor_player_back, got %s" % idle_up.texture_path)
		quit(1); return
	print("ok: idle facing up -> actor_player_back")

	# Phase 3: idle, facing left -> actor side with flip_h
	game.player_facing = "left"
	var idle_left: Dictionary = _observe()
	if "actor_player_side" not in idle_left.texture_path:
		print("FAIL: idle left should show actor_player_side, got %s" % idle_left.texture_path)
		quit(1); return
	if not idle_left.flip_h:
		print("FAIL: idle left should be flipped horizontally (side art is authored facing right)")
		quit(1); return
	print("ok: idle facing left -> actor_player_side, flip_h=true")

	# Phase 4: idle, facing right -> actor side without flip_h
	game.player_facing = "right"
	var idle_right: Dictionary = _observe()
	if "actor_player_side" not in idle_right.texture_path:
		print("FAIL: idle right should show actor_player_side, got %s" % idle_right.texture_path)
		quit(1); return
	if idle_right.flip_h:
		print("FAIL: idle right should NOT be flipped (side art is authored facing right)")
		quit(1); return
	print("ok: idle facing right -> actor_player_side, flip_h=false")

	# Phase 5: moving -> walk sprite (any of player_walk/*.png), scale 1.0
	game.player_is_moving = true
	game.player_walk_frame = 3
	game.player_facing = "down"
	var moving: Dictionary = _observe()
	if "player_walk" not in moving.texture_path:
		print("FAIL: moving should show player_walk/*.png, got %s" % moving.texture_path)
		quit(1); return
	if moving.scale.x != 1.0 or moving.scale.y != 1.0:
		print("FAIL: moving walk sprite scale should be (1,1), got %s" % str(moving.scale))
		quit(1); return
	print("ok: moving -> player_walk/down_03.png, scale=1.0")

	# Phase 6: repairing -> hidden (alpha=0)
	game.player_repair_active = true
	var repairing: Dictionary = _observe()
	if repairing.alpha > 0.001:
		print("FAIL: repairing should hide player_token (alpha=0), got %f" % repairing.alpha)
		quit(1); return
	print("ok: repairing -> player_token hidden")

	# Phase 7: facing fallback. Set actor_textures["side"] to null and ensure
	# idle facing right falls back to walk frame 0 (no crash, no broken token).
	game.player_repair_active = false
	game.player_is_moving = false
	game.player_facing = "right"
	var saved_side: Texture2D = game.actor_textures["side"]
	game.actor_textures["side"] = null
	var fallback: Dictionary = _observe()
	if "player_walk" not in fallback.texture_path:
		print("FAIL: actor fallback should show walk frame 0, got %s" % fallback.texture_path)
		game.actor_textures["side"] = saved_side
		quit(1); return
	game.actor_textures["side"] = saved_side
	print("ok: actor fallback to walk frame 0 when actor side missing")

	print("Actor regression test: PASS")
	quit(0)


# Helper: capture the player_token state after one _draw_player cycle.
func _observe() -> Dictionary:
	game._draw_player()
	return {
		"texture_path": game.player_token.texture.resource_path if game.player_token.texture else "",
		"scale": game.player_token.scale,
		"flip_h": game.player_token.flip_h,
		"alpha": game.player_token.modulate.a,
	}
