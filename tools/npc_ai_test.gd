extends SceneTree

# npc_ai_test
# Polish spec §4.7 — covers the 4 behavioural rules in
# NightShiftActors.decide_target and the surrounding state-machine
# assumptions. Headless, mirrors the style of tools/night_shift_basic_test.gd.

const Actors := preload("res://scripts/NightShiftActors.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run_rule1_emergency_only()
	_run_rule2_soft_commit_2s()
	_run_rule3_defer_to_player()
	_run_rule4_npc_id_branches()
	print("NPC AI test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	quit(0 if failed == 0 else 1)


func _assert(cond: bool, name: String) -> void:
	if cond:
		passed += 1
		print("  ok: %s" % name)
	else:
		failed += 1
		print("  FAIL: %s" % name)


# A simple RefCounted stub for the `unlocked` callable parameter. Tests
# opt in to which hotspot ids are "available" this run. We expose a real
# `is_unlocked(id)` method because GDScript forbids overriding Object's
# builtin `call(...)` on inner classes — that's treated as a parse error.
class StubUnlocked extends RefCounted:
	var allowed: Array = []
	func _init(allowed_ids: Array = []) -> void:
		allowed = allowed_ids
	func is_unlocked(id: String) -> bool:
		return allowed.has(id)


func _hotspot(id: String, value: float, breach_timer: float = -1.0, kind: String = "window") -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"value": value,
		"max_value": 100.0,
		"breach_timer": breach_timer,
		"active": value < 100.0,
	}


# Rule 1: emergency only — NPC only acts on a hotspot when breach_timer >= 0
# (already counting down to fail) OR value < 35% (濒危). Below those
# thresholds, decide_target should return "" (idle).
func _run_rule1_emergency_only() -> void:
	print("=== Rule 1: emergency only ===")
	var hotspots: Dictionary = {
		"left_window": _hotspot("left_window", 80.0),  # safe
		"right_window": _hotspot("right_window", 30.0),  # 濒危
	}
	var unlocked := StubUnlocked.new(["left_window", "right_window"])
	var unlocked_cb := Callable(unlocked, "is_unlocked")
	var state: Dictionary = {"nora": {"target": "", "commit_timer": 0.0}}
	var t: String = Actors.decide_target("nora", hotspots, unlocked_cb, "", state)
	_assert(t == "right_window", "Rule 1: Nora picks the 30%-value window")
	hotspots["right_window"]["value"] = 80.0  # both safe now
	t = Actors.decide_target("nora", hotspots, unlocked_cb, "", state)
	_assert(t == "", "Rule 1: idle when no hotspot is in emergency")
	# Breach-in-progress takes priority even at high value.
	hotspots["left_window"]["breach_timer"] = 0.3
	hotspots["left_window"]["value"] = 90.0
	t = Actors.decide_target("nora", hotspots, unlocked_cb, "", state)
	_assert(t == "left_window", "Rule 1: breach-in-progress takes priority over value")


# Rule 2: soft-commit 2s — once an NPC has chosen a target, decide_target
# should keep returning that target for the next 2 seconds even if a new
# hotspot becomes more urgent.
func _run_rule2_soft_commit_2s() -> void:
	print("=== Rule 2: soft-commit 2s ===")
	var hotspots: Dictionary = {
		"left_window": _hotspot("left_window", 30.0),
		"right_window": _hotspot("right_window", 80.0),
	}
	var unlocked := StubUnlocked.new(["left_window", "right_window"])
	var unlocked_cb := Callable(unlocked, "is_unlocked")
	var state: Dictionary = {
		"nora": {"target": "left_window", "commit_timer": 1.5}
	}
	var t: String = Actors.decide_target("nora", hotspots, unlocked_cb, "", state)
	_assert(t == "left_window", "Rule 2: holds target during 2s commit window")
	# Force the commit to expire.
	state["nora"]["commit_timer"] = 0.0
	t = Actors.decide_target("nora", hotspots, unlocked_cb, "", state)
	_assert(t == "left_window", "Rule 2: still picks same hotspot after expiry")


# Rule 3: defer to player — if the player is currently heading toward the
# hotspot the NPC would pick, the NPC should yield and return "".
func _run_rule3_defer_to_player() -> void:
	print("=== Rule 3: defer to player ===")
	var hotspots: Dictionary = {
		"right_window": _hotspot("right_window", 30.0),
	}
	var unlocked := StubUnlocked.new(["right_window"])
	var unlocked_cb := Callable(unlocked, "is_unlocked")
	var state: Dictionary = {
		"nora": {"target": "", "commit_timer": 0.0}
	}
	# Player is heading to right_window — Nora yields.
	var t: String = Actors.decide_target("nora", hotspots, unlocked_cb, "right_window", state)
	_assert(t == "", "Rule 3: NPC defers to player when player targets the same hotspot")
	# Player elsewhere — Nora picks it.
	t = Actors.decide_target("nora", hotspots, unlocked_cb, "front_door", state)
	_assert(t == "right_window", "Rule 3: NPC picks hotspot when player is elsewhere")


# Rule 4: per-NPC selector — Nora handles windows, Elias handles antenna +
# radio. decide_target dispatches to the right helper by npc_id.
func _run_rule4_npc_id_branches() -> void:
	print("=== Rule 4: per-NPC branches ===")
	var hotspots: Dictionary = {
		"right_window": _hotspot("right_window", 30.0, -1.0, "window"),
		"antenna": _hotspot("antenna", 30.0, -1.0, "antenna"),
		"radio": _hotspot("radio", 90.0, -1.0, "support"),
	}
	var unlocked := StubUnlocked.new(["right_window", "antenna", "radio"])
	var unlocked_cb := Callable(unlocked, "is_unlocked")
	var state: Dictionary = {"nora": {"target": "", "commit_timer": 0.0}}
	# Nora with a window in trouble — picks window.
	var t: String = Actors.decide_target("nora", hotspots, unlocked_cb, "", state)
	_assert(t == "right_window", "Rule 4: Nora picks window over antenna")
	# Elias with antenna in trouble + radio safe — picks antenna.
	state["elias"] = {"target": "", "commit_timer": 0.0}
	t = Actors.decide_target("elias", hotspots, unlocked_cb, "", state, true, false, false, false, {})
	_assert(t == "antenna", "Rule 4: Elias picks antenna first")
	# Unknown NPC id returns "" (no helper dispatched).
	state["lily"] = {"target": "", "commit_timer": 0.0}
	t = Actors.decide_target("lily", hotspots, unlocked_cb, "", state)
	_assert(t == "", "Rule 4: unknown npc_id returns empty (no helper)")