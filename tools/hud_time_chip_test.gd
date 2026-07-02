extends SceneTree
# HUD time chip test — verifies the night-HUD clock-face + countdown
# mapping introduced in M12. The night HUD dropped the 7-chip resource
# bar and now only tells the player "how long until dawn", mapping
# each level's real duration (60s / 120s / 180s) onto the canonical
# 22:00 → 06:00 shift.
#
# compute_night_time() is a pure static helper, so this test exercises
# it without spinning up a full scene tree.

const Game := preload("res://scripts/NightShiftGame.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run()
	if failed > 0:
		print("FAIL: hud_time_chip_test  %d passed / %d failed" % [passed, failed])
		quit(1)
	else:
		print("OK:   hud_time_chip_test  %d passed / %d failed" % [passed, failed])
		quit(0)


func _expect(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _check(night_elapsed: float, night_duration: float, exp_clock: String, exp_remaining: String, exp_progress: float) -> void:
	var t: Dictionary = Game.compute_night_time(night_elapsed, night_duration)
	_expect(str(t.get("clock", "")) == exp_clock,
		"clock(elapsed=%.2f, dur=%.2f) == %s (got %s)" % [night_elapsed, night_duration, exp_clock, t.get("clock", "")])
	_expect(str(t.get("remaining", "")) == exp_remaining,
		"remaining(elapsed=%.2f, dur=%.2f) == %s (got %s)" % [night_elapsed, night_duration, exp_remaining, t.get("remaining", "")])
	_expect(abs(float(t.get("progress", -1.0)) - exp_progress) < 0.001,
		"progress(elapsed=%.2f, dur=%.2f) ~= %.3f (got %.3f)" % [night_elapsed, night_duration, exp_progress, t.get("progress", -1.0)])


func _run() -> void:
	print("=== HUD time chip test ===")

	# 1) Boundaries of a 180s level (the canonical night 3+ length).
	#    progress=0 -> clock 22:00, remaining 08:00
	#    progress=1 -> clock 06:00, remaining 00:00
	_check(0.0, 180.0, "22:00", "08:00", 0.0)
	_check(180.0, 180.0, "06:00", "00:00", 1.0)
	#    Halfway: 4 narrative hours elapsed -> 22:00 + 4h = 02:00, remaining 04:00
	_check(90.0, 180.0, "02:00", "04:00", 0.5)
	#    Quarter: 2 narrative hours elapsed -> 22:00 + 2h = 00:00 (midnight),
	#    remaining 06:00. (Counter-intuitive at first read but correct: an
	#    8h shift from 22:00 lands midnight at the 25% mark, not 23:00.)
	_check(45.0, 180.0, "00:00", "06:00", 0.25)
	#    3/4: 6 narrative hours elapsed -> 22:00 + 6h = 04:00, remaining 02:00
	_check(135.0, 180.0, "04:00", "02:00", 0.75)

	# 2) Level length independence — same elapsed real time as above
	#    but in a 60s level (night 1) should still map to the same
	#    narrative clock face. At 30s/60s we are halfway through the
	#    shift regardless of how long the level actually is.
	_check(30.0, 60.0, "02:00", "04:00", 0.5)
	_check(0.0, 60.0, "22:00", "08:00", 0.0)
	_check(60.0, 60.0, "06:00", "00:00", 1.0)

	# 3) 120s level (night 2) at midpoint
	_check(60.0, 120.0, "02:00", "04:00", 0.5)

	# 4) Clamp behavior — elapsed beyond duration shouldn't break the
	#    clock. The chip's progress bar would be at 100% and the
	#    remaining clock must read 00:00, not wrap to a negative.
	_check(999.0, 180.0, "06:00", "00:00", 1.0)
	#    Negative elapsed (defensive — shouldn't happen, but if a save
	#    loads with night_elapsed=-1 the chip shouldn't show garbage).
	_check(-1.0, 180.0, "22:00", "08:00", 0.0)

	# 5) Zero-duration safety — should not divide by zero. Returns the
	#    start-of-shift state (progress 0 → 22:00, 08:00).
	_check(0.0, 0.0, "22:00", "08:00", 0.0)
	_check(50.0, 0.0, "06:00", "00:00", 1.0)

	# 6) Exact wrap-point check: progress=1.0 should land on 06:00
	#    (22 + 8 = 30, % 24 = 6) — not 30:00. This is the regression
	#    the static method is here to prevent.
	var t_full: Dictionary = Game.compute_night_time(180.0, 180.0)
	_expect(str(t_full.get("clock", "")) == "06:00",
		"full-shift clock wraps to 06:00 (not 30:00)")

	# 7) Minute granularity: at progress that lands on a non-zero
	#    minute, the minute field should render correctly. 10% of
	#    180s = 18s real, but 10% of 8h = 48 min narrative -> 22:48
	#    with remaining 07:12.
	_check(18.0, 180.0, "22:48", "07:12", 0.1)

	print("=== %d passed / %d failed ===" % [passed, failed])
