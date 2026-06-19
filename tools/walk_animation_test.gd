extends SceneTree

# Test: walk-frame animation. Drives _update_player_movement without WASD
# by directly setting player_pos deltas through the click-target path, then
# checks player_facing / player_walk_frame / player_is_moving.

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/NightShiftGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.call("_show_night")
	await process_frame

	# Reset to known state
	game.set("player_pos", Vector2(640, 360))
	game.set("player_target_id", "")
	game.set("player_facing", "down")
	game.set("player_walk_frame", 0)
	game.set("player_walk_timer", 0.0)
	await process_frame

	# 1) Idle: no movement -> is_moving=false, frame=0, facing unchanged
	game.set("player_pos", Vector2(640, 360))
	game.call("_update_player_movement", 0.1)
	await process_frame
	_expect(bool(game.get("player_is_moving")) == false, "idle -> player_is_moving=false")
	_expect(int(game.get("player_walk_frame")) == 0, "idle -> walk_frame=0")
	_expect(String(game.get("player_facing")) == "down", "idle facing preserved")

	# 2) Rightward: click-target far on the right, then several update ticks
	game.set("hotspots", {"x": {"pos": Vector2(1100, 360), "value": 0.0}})
	game.set("player_target_id", "x")
	game.set("player_pos", Vector2(640, 360))
	for i in range(5):
		game.call("_update_player_movement", 0.05)
		await process_frame
	_expect(bool(game.get("player_is_moving")) == true, "moving right -> is_moving=true")
	_expect(String(game.get("player_facing")) == "right", "facing=right when moving right")
	_expect(int(game.get("player_walk_frame")) > 0, "walk_frame advanced after 5 ticks (got %d)" % int(game.get("player_walk_frame")))

	# 3) Downward
	game.set("hotspots", {"x": {"pos": Vector2(640, 500), "value": 0.0}})
	game.set("player_pos", Vector2(640, 360))
	game.set("player_walk_frame", 0)
	for i in range(3):
		game.call("_update_player_movement", 0.05)
		await process_frame
	_expect(String(game.get("player_facing")) == "down", "facing=down when moving down")

	# 4) Leftward
	game.set("hotspots", {"x": {"pos": Vector2(200, 360), "value": 0.0}})
	game.set("player_pos", Vector2(640, 360))
	game.set("player_walk_frame", 0)
	for i in range(3):
		game.call("_update_player_movement", 0.05)
		await process_frame
	_expect(String(game.get("player_facing")) == "left", "facing=left when moving left")

	# 5) Upward
	game.set("hotspots", {"x": {"pos": Vector2(640, 200), "value": 0.0}})
	game.set("player_pos", Vector2(640, 360))
	game.set("player_walk_frame", 0)
	for i in range(3):
		game.call("_update_player_movement", 0.05)
		await process_frame
	_expect(String(game.get("player_facing")) == "up", "facing=up when moving up")

	# 6) Frame cycle wraps at 12
	game.set("player_walk_frame", 11)
	game.set("player_walk_timer", 0.0)
	game.set("hotspots", {"x": {"pos": Vector2(1100, 360), "value": 0.0}})
	game.set("player_target_id", "x")
	game.set("player_pos", Vector2(640, 360))
	game.call("_update_player_movement", 0.2)  # long tick -> 2 frames
	await process_frame
	# With 0.2s tick and 10 fps (0.1s/frame) -> 2 advances -> 11 -> 0 -> 1
	_expect(int(game.get("player_walk_frame")) == 1, "walk_frame wraps 11->1 (got %d)" % int(game.get("player_walk_frame")))

	# 7) Token texture changes when moving
	# Reset and capture token.texture before/after
	game.set("player_pos", Vector2(640, 360))
	game.set("player_target_id", "")
	game.set("player_facing", "down")
	game.set("player_walk_frame", 0)
	game.set("player_walk_timer", 0.0)
	game.call("_draw_player")
	await process_frame
	var idle_tex = game.get("player_token").texture
	# Now move right for 2 frames
	game.set("hotspots", {"x": {"pos": Vector2(1100, 360), "value": 0.0}})
	game.set("player_target_id", "x")
	game.set("player_pos", Vector2(640, 360))
	for i in range(3):
		game.call("_update_player_movement", 0.1)
		await process_frame
	var move_tex = game.get("player_token").texture
	_expect(move_tex != null, "moving -> token has texture")
	_expect(idle_tex != null, "idle -> token has texture")
	_expect(idle_tex != move_tex, "token texture changed when moving (different frame)")

	# Cleanup
	game.queue_free()
	await process_frame

	print("---")
	if failed == 0:
		print("walk animation test: PASS (passed=%d)" % passed)
		quit(0)
	else:
		print("walk animation test: FAIL (passed=%d, failed=%d)" % [passed, failed])
		quit(1)


func _expect(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  ok: %s" % label)
	else:
		failed += 1
		print("  FAIL: %s" % label)
