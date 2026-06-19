extends SceneTree

# Simulate all 10 nights. Force every night to succeed (skip the breach failures
# that would end the run) and verify that all 9 hotspots eventually unlock
# and the final chapter_complete state is reached.

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/NightShiftGame.tscn").instantiate()
	root.add_child(game)
	await process_frame

	# Drive all 10 nights with repair assist to make them succeed
	for night_idx in range(10):
		game.call("_show_night")
		await process_frame
		var unlocked: Array = (game.get("hotspots") as Dictionary).keys()
		print("night %d unlocked: %s" % [night_idx + 1, str(unlocked)])
		# Verify night 1 has 3, night 4 has 6, night 8 has 9
		match night_idx + 1:
			1: _expect(unlocked.size() == 3, "night 1 has 3 hotspots (got %d)" % unlocked.size())
			2: _expect(unlocked.size() == 4, "night 2 has 4 hotspots (got %d)" % unlocked.size())
			3: _expect(unlocked.size() == 5, "night 3 has 5 hotspots (got %d)" % unlocked.size())
			4: _expect(unlocked.size() == 6, "night 4 has 6 hotspots (got %d)" % unlocked.size())
			6: _expect(unlocked.size() == 7, "night 6 has 7 hotspots (got %d)" % unlocked.size())
			7: _expect(unlocked.size() == 8, "night 7 has 8 hotspots (got %d)" % unlocked.size())
			8: _expect(unlocked.size() == 9, "night 8 has 9 hotspots (got %d)" % unlocked.size())
		# Cheat-repair all hotspots so the night succeeds without player input
		for h in (game.get("hotspots") as Dictionary).values():
			h["value"] = h["max_value"]
		# Fast-forward to end of night
		game.set("night_elapsed", game.get("night_duration") + 1.0)
		game.call("_update_night", 0.0)
		await process_frame
		# Force end with success
		game.call("_end_night", true)
		await process_frame
		# Advance to next day/night (simulate the "进入下一夜" button click)
		game.call("_on_report_continue", true)
		await process_frame

	# After 10 nights we should be in final state
	_expect(int(game.get("night_index")) == 10, "night_index reached 10 (got %d)" % int(game.get("night_index")))
	game.queue_free()
	await process_frame
	print("---")
	if failed == 0:
		print("10-night simulation: PASS (passed=%d)" % passed)
		quit(0)
	else:
		print("10-night simulation: FAIL (passed=%d, failed=%d)" % [passed, failed])
		quit(1)


func _expect(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  ok: %s" % label)
	else:
		failed += 1
		print("  FAIL: %s" % label)
