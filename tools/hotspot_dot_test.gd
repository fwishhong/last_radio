extends SceneTree

# Test: HotspotDot state machine — drive the dot through green/yellow/red/breach/locked.

var passed: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var dot = HotspotDot.new()
	root.add_child(dot)
	await process_frame

	# Default: green (integrity 1.0)
	dot.set_state(1.0, false, false, false, false, false, 0.0)
	_expect(dot._color_for_state() == Color(0.29, 0.87, 0.50), "integrity=1.0 -> green")

	# integrity 0.7 still green
	dot.set_state(0.7, false, false, false, false, false, 0.0)
	_expect(dot._color_for_state() == Color(0.29, 0.87, 0.50), "integrity=0.7 -> green (just above threshold)")

	# integrity 0.5 -> yellow
	dot.set_state(0.5, false, false, false, false, false, 0.0)
	_expect(dot._color_for_state() == Color(0.98, 0.80, 0.08), "integrity=0.5 -> yellow")

	# integrity 0.3 still yellow (just at threshold)
	dot.set_state(0.3, false, false, false, false, false, 0.0)
	_expect(dot._color_for_state() == Color(0.98, 0.80, 0.08), "integrity=0.3 -> yellow (at threshold)")

	# integrity 0.1 -> orange
	dot.set_state(0.1, false, false, false, false, false, 0.0)
	_expect(dot._color_for_state() == Color(0.98, 0.45, 0.09), "integrity=0.1 -> orange (danger)")

	# breach overrides everything
	dot.set_state(1.0, true, false, false, false, false, 0.5)
	_expect(dot._color_for_state() == Color(0.94, 0.27, 0.27), "breached -> red regardless of integrity")

	# locked overrides everything
	dot.set_state(1.0, false, false, true, false, false, 0.0)
	_expect(dot._color_for_state() == Color(0.42, 0.45, 0.50), "locked -> gray regardless of state")

	# Verify integration: real game with hotspots uses dot.set_state correctly
	var game = load("res://scenes/NightShiftGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.call("_show_night")
	await process_frame
	var dots_found: int = 0
	for child in game.get("hotspot_layer").get_children():
		if not child.has_meta("hotspot_id"):
			continue
		var d: HotspotDot = child.get_node_or_null("Dot") as HotspotDot
		if d:
			dots_found += 1
			# Each dot has correct _integrity from game state
			var h: Dictionary = (game.get("hotspots") as Dictionary)[child.get_meta("hotspot_id")]
			var expected: float = float(h["value"]) / float(h["max_value"])
			_expect(abs(d._integrity - expected) < 0.001, "hotspot %s dot integrity = %.2f" % [child.get_meta("hotspot_id"), expected])
	_expect(dots_found == 3, "3 hotspot dots created in night 1 (got %d)" % dots_found)

	game.queue_free()
	dot.queue_free()
	await process_frame

	print("---")
	if failed == 0:
		print("hotspot dot test: PASS (passed=%d)" % passed)
		quit(0)
	else:
		print("hotspot dot test: FAIL (passed=%d, failed=%d)" % [passed, failed])
		quit(1)


func _expect(cond: bool, label: String) -> void:
	if cond:
		passed += 1
		print("  ok: %s" % label)
	else:
		failed += 1
		print("  FAIL: %s" % label)
