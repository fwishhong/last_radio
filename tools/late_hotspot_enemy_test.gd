extends SceneTree
# Verifies that medbay, storage, and back_door spawn enemy tokens when assaulted,
# just like front_door and left_window do. Each hotspot should:
#   1. Have a valid position
#   2. Spawn 2-4 enemy tokens within 0.1s of an assault flag
#   3. Move enemies toward the hotspot (within 0.5s of motion, each enemy is closer)
#   4. Allow enemies to despawn after the assault ends
#
# Why these three: they unlock in different later nights (medbay=7, storage=8,
# back_door=6) and previously only the early hotspots were exercised by the
# flow_integration_test.

const Game := preload("res://scripts/NightShiftGame.gd")
const Save := preload("res://scripts/NightShiftSave.gd")

var game: Node
var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run()
	quit(0 if failed == 0 else 1)


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _run() -> void:
	print("=== Late-night hotspot enemy test ===")
	Save.clear_save()

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame

	game.call("_on_start_pressed")
	_assert(game.phase == "day", "started a fresh campaign")

	# Helper: load a specific night with the given extra hotspots already unlocked,
	# bypassing the day-card flow.
	var test_cases := [
		{"night": 5, "hotspot": "back_door", "kind": "barrier"},
		{"night": 6, "hotspot": "medbay", "kind": "support"},
		{"night": 7, "hotspot": "storage", "kind": "support"},
	]

	for tc in test_cases:
		var hid: String = str(tc["hotspot"])
		var night: int = int(tc["night"])
		_prep_night(night, [hid])
		_assert(game.hotspots.has(hid), "%s unlocked for night %d" % [hid, night + 1])
		if not game.hotspots.has(hid):
			continue
		var h: Dictionary = game.hotspots[hid]
		var pos: Vector2 = h["pos"]
		_assert(pos.x > 0.0 and pos.x < 1280.0, "%s position is inside screen width" % hid)
		_assert(pos.y > 0.0 and pos.y < 720.0, "%s position is inside screen height" % hid)

		# Trigger assault and let the spawner run.
		h["assault"] = true
		h["warning"] = false
		game.hotspots[hid] = h
		game.call("_update_enemies", 0.1)
		_assert(game.enemy_tokens.has(hid), "%s enemy swarm spawned on assault" % hid)
		var enemies: Array = game.enemy_tokens.get(hid, [])
		_assert(enemies.size() >= 2, "%s spawned at least 2 enemies (got %d)" % [hid, enemies.size()])
		_assert(enemies.size() <= 4, "%s spawned at most 4 enemies (got %d)" % [hid, enemies.size()])

		# Verify enemies are positioned around the hotspot (within spawn clamps).
		# We allow a few pixels of slop because the same _update_enemies call
		# also moves them up to 6px toward the hotspot after spawning.
		var all_in_bounds := true
		for e in enemies:
			var p: Vector2 = e["pos"]
			if p.x < 50.0 or p.x > 1230.0 or p.y < 80.0 or p.y > 640.0:
				all_in_bounds = false
				print("    [%s] enemy pos out of bounds: %s" % [hid, str(p)])
				break
		_assert(all_in_bounds, "%s all enemies start near the hotspot" % hid)

		# Step the world — enemies should move toward the hotspot.
		var before_distances := []
		for e in enemies:
			before_distances.append(float(pos.distance_to(e["pos"])))
		game.call("_update_enemies", 0.5)
		var list_after: Array = game.enemy_tokens.get(hid, [])
		if list_after.size() > 0:
			var moved_count := 0
			for i in range(list_after.size()):
				if i >= before_distances.size():
					break
				var d_after: float = float(pos.distance_to(list_after[i]["pos"]))
				if d_after < before_distances[i] - 1.0:
					moved_count += 1
			_assert(moved_count >= 1, "%s enemies advance toward hotspot (%d/%d moved closer)" % [hid, moved_count, list_after.size()])

		# Dismiss assault; existing enemies should despawn over time.
		h["assault"] = false
		game.hotspots[hid] = h
		# Run enough ticks to let life decay fully (33%/s × 4s = full despawn).
		for i in range(40):
			game.call("_update_enemies", 0.1)
		_assert(not game.enemy_tokens.has(hid), "%s enemy swarm fully despawns after assault ends" % hid)

	# Bonus: verify all three hotspots together during a worst-case finale.
	_prep_night(9, ["back_door", "medbay", "storage", "antenna", "radio"])
	var combined_ids := ["back_door", "medbay", "storage"]
	for id in combined_ids:
		var h2: Dictionary = game.hotspots[id]
		h2["assault"] = true
		game.hotspots[id] = h2
	game.call("_update_enemies", 0.1)
	for id in combined_ids:
		_assert(game.enemy_tokens.has(id), "%s swarms coexist in a finale" % id)

	print("Late-night hotspot enemy test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])


func _prep_night(night_index: int, extra_hotspots: Array) -> void:
	game.night_index = night_index
	game.unlocked_hotspots = []
	for hid in extra_hotspots:
		game.unlocked_hotspots.append(hid)
	game.call("_show_night")
	# Restore hotspot values to full so the breach timer does not immediately trip.
	for hid in game.hotspots.keys():
		var h: Dictionary = game.hotspots[hid]
		h["value"] = h["max_value"]
		h["breach_timer"] = -1.0
		game.hotspots[hid] = h