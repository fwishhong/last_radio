extends SceneTree
# DayEffects test — verifies aggregated effects apply to night params
# across all 10 nights.

const DayEffects := preload("res://scripts/NightShiftDayEffects.gd")
const Data := preload("res://scripts/NightShiftData.gd")

var data: Data
var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run()


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _run() -> void:
	print("=== DayEffects test ===")
	data = Data.new()
	data.load_all()

	# 1) Empty effects have no impact
	var e := DayEffects.new()
	_assert(e.get_drain_multiplier("front_door", "barrier_assault") == 1.0, "empty drain mult = 1.0")
	_assert(e.get_cap_bonus("front_door") == 0.0, "empty cap bonus = 0.0")
	_assert(e.get_repair_bonus("front_door") == 0.0, "empty repair bonus = 0.0")
	_assert(e.get_player_speed_bonus() == 0.0, "empty speed bonus = 0.0")
	_assert(e.get_radio_goal_delta() == 0, "empty radio goal = 0")

	# 2) door_reinforce affects front_door
	var card: Dictionary = data.get_card("door_reinforce")
	e.add_from_card(card)
	_assert(e.get_drain_multiplier("front_door", "barrier_assault") < 1.0, "door_reinforce lowers drain on front_door")
	_assert(e.get_cap_bonus("front_door") > 0.0, "door_reinforce adds cap to front_door")
	_assert(e.get_drain_multiplier("left_window", "barrier_assault") == 1.0, "door_reinforce does not affect left_window")

	# 3) generator_drain global
	var e2 := DayEffects.new()
	var card_g: Dictionary = data.get_card("battery_buffer")
	e2.add_from_card(card_g)
	var m: float = e2.get_drain_multiplier("generator", "generator")
	_assert(m < 1.0, "battery_buffer lowers generator drain")
	_assert(e2.get_drain_multiplier("front_door", "barrier_assault") == 1.0, "battery_buffer doesn't touch barriers")

	# 4) player_speed
	var e3 := DayEffects.new()
	var card_r: Dictionary = data.get_card("runner_path")
	e3.add_from_card(card_r)
	_assert(e3.get_player_speed_bonus() > 0.0, "runner_path adds player speed")

	# 5) repair_rate
	var e4 := DayEffects.new()
	var card_w: Dictionary = data.get_card("workbench")
	e4.add_from_card(card_w)
	_assert(e4.get_repair_bonus("front_door") > 0.0, "workbench adds repair bonus")

	# 6) cap bonus targets "all_barriers" (data layer; the kind filter
	# is applied in _show_night — barriers get the cap, support does not)
	var e5 := DayEffects.new()
	var card_f: Dictionary = data.get_card("final_barricade")
	e5.add_from_card(card_f)
	_assert(e5.get_cap_bonus("front_door") > 0.0, "final_barricade adds to front_door cap")
	_assert(e5.get_cap_bonus("left_window") > 0.0, "final_barricade adds to left_window cap")

	# 7) radio_window + radio_contact_goal
	var e6 := DayEffects.new()
	var card_b: Dictionary = data.get_card("radio_booster")
	e6.add_from_card(card_b)
	_assert(e6.get_radio_goal_delta() > 0, "radio_booster adds radio goal")

	# 8) Compound: 2 cards together sum bonuses
	var e7 := DayEffects.new()
	e7.add_from_card(data.get_card("door_reinforce"))
	e7.add_from_card(data.get_card("workbench"))
	_assert(e7.get_cap_bonus("front_door") > 0.0, "compound cap > 0")
	_assert(e7.get_repair_bonus("front_door") > 0.0, "compound repair > 0")

	# 9) Summarize returns lines for the panel
	var s: Array = e7.summarize()
	_assert(s.size() >= 2, "summarize lists multiple effects")

	# 10) Clear empties
	e7.clear()
	_assert(e7.count() == 0, "clear empties effects")

	print("DayEffects test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	quit(0 if failed == 0 else 1)
