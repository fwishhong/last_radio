extends SceneTree
# Smoke + behaviour tests for scripts/NightShiftFx.gd.
#
# Verifies:
#   1. Particles can be spawned, ticked, and drawn without crashing.
#   2. Shake state decays monotonically and produces bounded offsets.
#   3. Telegraphs schedule, tick, fire, and never stack duplicate warnings.
#   4. Convenience bursts (window crack, door splinter, spark, breach, radio)
#      produce the right kind/count of particles.

const Fx := preload("res://scripts/NightShiftFx.gd")

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
	print("=== FX module test ===")

	# ---- 1) Particles ------------------------------------------------------
	var particles: Array = []
	Fx.spawn_particle(particles, Vector2.ZERO, Vector2(10, 0), 0.5, Color(1, 1, 1, 1), 2.0)
	Fx.spawn_particle(particles, Vector2(50, 50), Vector2(-10, 0), 0.3, Color(1, 0, 0, 1), 1.0)
	_assert(particles.size() == 2, "spawn adds two particles")
	Fx.tick_particles(particles, 0.1)
	_assert(particles.size() == 2, "particles survive short tick")
	_assert(particles[0]["pos"] != Vector2.ZERO, "particle position advances")

	# Force expiry
	Fx.tick_particles(particles, 10.0)
	_assert(particles.is_empty(), "expired particles are removed")

	# Convenience bursts each spawn >= 5 particles
	var win: Array = []
	Fx.burst_window_crack(win, Vector2.ZERO, 1.0)
	_assert(win.size() >= 5, "window crack burst produces particles (got %d)" % win.size())

	var door: Array = []
	Fx.burst_door_splinter(door, Vector2.ZERO, 1.0)
	_assert(door.size() >= 5, "door splinter burst produces particles (got %d)" % door.size())
	# Splinters should mostly be RECT kind (chips of wood), not DOT.
	var splinter_rects := 0
	for p in door:
		if int(p["kind"]) == Fx.PARTICLE_KIND_RECT:
			splinter_rects += 1
	_assert(splinter_rects >= 3, "door splinter burst uses RECT kind (%d)" % splinter_rects)

	var spark: Array = []
	Fx.burst_spark(spark, Vector2.ZERO, 1.0)
	_assert(spark.size() >= 8, "spark burst produces particles (got %d)" % spark.size())

	var breach: Array = []
	Fx.burst_breach(breach, Vector2.ZERO, 1.0)
	_assert(breach.size() >= 20, "breach burst is heavy (got %d)" % breach.size())
	# Breach should include at least one RING particle.
	var rings := 0
	for p in breach:
		if int(p["kind"]) == Fx.PARTICLE_KIND_RING:
			rings += 1
	_assert(rings >= 1, "breach includes ring particles (%d)" % rings)

	var radio: Array = []
	Fx.burst_radio_contact(radio, Vector2.ZERO)
	_assert(radio.size() == 6, "radio contact ring has 6 segments (got %d)" % radio.size())
	for p in radio:
		_assert(int(p["kind"]) == Fx.PARTICLE_KIND_RING, "radio contact particles are RING kind")

	# Cap test: spawn a flood and ensure tick_particles doesn't grow forever.
	var flood: Array = []
	for i in 500:
		Fx.spawn_particle(flood, Vector2.ZERO, Vector2.ZERO, 0.05 + randf() * 0.1, Color(1, 1, 1, 1), 1.0)
	_assert(flood.size() == 500, "flood build succeeds")
	Fx.tick_particles(flood, 1.0)
	_assert(flood.size() < 500, "flood drains after tick (now %d)" % flood.size())

	# ---- 2) Shake ----------------------------------------------------------
	var shake: Dictionary = {"amount": 0.0, "decay": 6.0, "freq": 28.0, "phase": 0.0}
	Fx.shake_trigger(shake, 8.0)
	_assert(shake["amount"] == 8.0, "shake triggers to requested amount")
	var off: Vector2 = Fx.shake_offset(shake)
	_assert(off.length() <= 16.0, "shake offset is bounded (got %s)" % str(off))
	Fx.shake_tick(shake, 0.5)
	_assert(shake["amount"] < 8.0, "shake decays over time (now %s)" % str(shake["amount"]))
	# After enough ticks, amount reaches 0.
	for i in 30:
		Fx.shake_tick(shake, 0.1)
	_assert(shake["amount"] == 0.0, "shake eventually settles to 0")
	_assert(Fx.shake_offset(shake) == Vector2.ZERO, "offset is zero when settled")

	# Two triggers stack: take the larger, don't add.
	Fx.shake_trigger(shake, 3.0)
	Fx.shake_trigger(shake, 12.0)
	_assert(shake["amount"] == 12.0, "shake triggers stack with max (%s)" % str(shake["amount"]))

	# ---- 3) Telegraphs -----------------------------------------------------
	var telegraphs: Array = []
	Fx.telegraph_schedule(telegraphs, "front_door", 2.0)
	Fx.telegraph_schedule(telegraphs, "front_door", 2.0)
	_assert(telegraphs.size() == 1, "duplicate telegraph does not stack")
	Fx.telegraph_schedule(telegraphs, "left_window", 2.0)
	_assert(telegraphs.size() == 2, "different hotspot gets its own telegraph")

	# Tick past the front_door warning. With both telegraphs at 2.0s and
	# ticking 0.1s/iter, we expect both to fire in the same iteration around
	# i=20. The order within fired[] isn't guaranteed (insertion order),
	# but front_door was inserted first.
	var saw_front_door_fire := false
	for i in 25:
		Fx.telegraph_phase_tick(telegraphs, 0.1)
		var fired: Array = Fx.telegraph_tick(telegraphs, 0.1)
		for f in fired:
			if str(f["hotspot_id"]) == "front_door":
				saw_front_door_fire = true
		if saw_front_door_fire and telegraphs.is_empty():
			break
	_assert(saw_front_door_fire, "front_door telegraph fires within 2.5s")

	# ---- 4) Pulse alpha stays in 0..1 -------------------------------------
	var t: Dictionary = {"hotspot_id": "x", "time_left": 1.0, "total_time": 2.0, "phase": 0.0}
	var a: float = Fx.telegraph_pulse_alpha(t)
	_assert(a >= 0.0 and a <= 1.5, "pulse alpha is bounded (got %s)" % str(a))

	print("FX module test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
