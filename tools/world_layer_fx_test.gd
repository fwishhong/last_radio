extends SceneTree
# Smoke + behaviour tests for scripts/WorldLayerFx.gd.
#
# Verifies:
#   1. zombie_phase_from_telegraph maps time_left → phase correctly:
#        - left > total * 0.3  → APPROACH, alpha ramps up
#        - left in (0, total*0.3] → IMMINENT, alpha >= 0.7
#        - left == 0.0          → BREACH
#   2. sway_acc["sway_phase"] advances monotonically across calls.
#   3. zombie_phase_persisting keeps alpha pinned at 0.45.
#   4. zombie_phase_hidden zeros alpha + resets sway phase.
#   5. parallax_offset is bounded and grows with depth.
#   6. zombie_anchor_offset returns correct direction for doors vs windows.

const WorldFx := preload("res://scripts/WorldLayerFx.gd")

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
	print("=== WorldLayerFx module test ===")

	# ---- 1) APPROACH phase (ratio > 0.3) --------------------------------
	var acc: Dictionary = {"sway_phase": 0.0}
	var t: Dictionary = {"hotspot_id": "front_door", "time_left": 1.5, "total_time": 2.0}
	var s: Dictionary = WorldFx.zombie_phase_from_telegraph(t, 0.016, acc)
	_assert(int(s["phase"]) == WorldFx.ZOMBIE_PHASE_APPROACH, "ratio=0.75 → APPROACH")
	_assert(float(s["alpha"]) < 1.0 and float(s["alpha"]) > 0.0, "APPROACH alpha in (0,1) (got %s)" % str(s["alpha"]))
	_assert(float(s["scale"]) == 1.0, "APPROACH scale = 1.0 (got %s)" % str(s["scale"]))

	# ---- 2) IMMINENT phase (0 < ratio <= 0.3) ---------------------------
	t["time_left"] = 0.4  # 0.4 / 2.0 = 0.2 ratio
	s = WorldFx.zombie_phase_from_telegraph(t, 0.016, acc)
	_assert(int(s["phase"]) == WorldFx.ZOMBIE_PHASE_IMMINENT, "ratio=0.2 → IMMINENT")
	_assert(float(s["alpha"]) >= 0.7, "IMMINENT alpha >= 0.7 (got %s)" % str(s["alpha"]))
	_assert(float(s["scale"]) > 1.0, "IMMINENT scale > 1.0 (got %s)" % str(s["scale"]))

	# ---- 3) BREACH phase (time_left <= 0) -------------------------------
	t["time_left"] = 0.0
	s = WorldFx.zombie_phase_from_telegraph(t, 0.016, acc)
	_assert(int(s["phase"]) == WorldFx.ZOMBIE_PHASE_BREACH, "left=0 → BREACH")
	_assert(float(s["alpha"]) == 1.0, "BREACH alpha = 1.0 (got %s)" % str(s["alpha"]))

	# ---- 4) Sway phase accumulates --------------------------------------
	var p1: float = float(acc["sway_phase"])
	for i in 10:
		t["time_left"] = 1.5
		WorldFx.zombie_phase_from_telegraph(t, 0.05, acc)
	var p2: float = float(acc["sway_phase"])
	_assert(p2 > p1, "sway_phase accumulates across calls (%s → %s)" % [p1, p2])
	# Advance should match (10 * 0.05 = 0.5s) within rounding
	var expected: float = p1 + 0.5
	_assert(abs(p2 - expected) < 0.01, "sway_phase advances by ~dt each call (got delta %s)" % str(p2 - expected))

	# ---- 5) Persisting state (assault on but no telegraph) --------------
	acc = {"sway_phase": 0.0}
	s = WorldFx.zombie_phase_persisting(acc, 0.016)
	_assert(int(s["phase"]) == WorldFx.ZOMBIE_PHASE_APPROACH, "persisting → APPROACH")
	_assert(abs(float(s["alpha"]) - 0.45) < 0.01, "persisting alpha = 0.45 (got %s)" % str(s["alpha"]))
	WorldFx.zombie_phase_persisting(acc, 0.1)
	_assert(float(acc["sway_phase"]) > 0.0, "persisting advances sway")

	# ---- 6) Hidden state resets sway ------------------------------------
	acc = {"sway_phase": 5.0}
	s = WorldFx.zombie_phase_hidden(acc)
	_assert(int(s["phase"]) == WorldFx.ZOMBIE_PHASE_HIDDEN, "hidden → HIDDEN")
	_assert(float(s["alpha"]) == 0.0, "hidden alpha = 0 (got %s)" % str(s["alpha"]))
	_assert(float(acc["sway_phase"]) == 0.0, "hidden resets sway_phase")

	# ---- 7) Parallax offset is bounded + grows with depth ---------------
	for depth in [0, 1, 2]:
		var far_off: Vector2 = WorldFx.parallax_offset(0.0, depth, 8.0)
		var late_off: Vector2 = WorldFx.parallax_offset(1.0, depth, 8.0)
		_assert(
			far_off.length() < 5.0,
			"depth=%d parallax near origin is small (got %s)" % [depth, str(far_off)]
		)
		_assert(
			late_off.length() < 30.0,
			"depth=%d parallax stays bounded (got %s)" % [depth, str(late_off)]
		)
	# Depth 0 should drift less than depth 2 over the same phase range.
	var max_drift_d0: float = 0.0
	var max_drift_d2: float = 0.0
	for i in 60:
		var ph: float = float(i) * 0.1
		max_drift_d0 = max(max_drift_d0, WorldFx.parallax_offset(ph, 0, 8.0).length())
		max_drift_d2 = max(max_drift_d2, WorldFx.parallax_offset(ph, 2, 8.0).length())
	_assert(max_drift_d2 > max_drift_d0, "deeper parallax drifts more (d0=%.2f d2=%.2f)" % [max_drift_d0, max_drift_d2])

	# ---- 8) Anchor offsets match hotspot type ---------------------------
	var front: Vector2 = WorldFx.zombie_anchor_offset("front_door")
	var back: Vector2 = WorldFx.zombie_anchor_offset("back_door")
	var lw: Vector2 = WorldFx.zombie_anchor_offset("left_window")
	var rw: Vector2 = WorldFx.zombie_anchor_offset("right_window")
	_assert(front.y < 0.0 and abs(front.x) < 0.01, "front_door anchor goes UP (got %s)" % str(front))
	_assert(back.y < 0.0 and abs(back.x) < 0.01, "back_door anchor goes UP (got %s)" % str(back))
	_assert(lw.x < 0.0, "left_window anchor goes LEFT (got %s)" % str(lw))
	_assert(rw.x > 0.0, "right_window anchor goes RIGHT (got %s)" % str(rw))

	print("WorldLayerFx module test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
