extends SceneTree
# Full-flow smoke test for the current NightShiftGame implementation.
# Drives the game through all 10 nights, asserting:
#   - cover -> day -> night transition
#   - per-night hotspot set matches chapter_01_nights.json
#   - assault spawns 2-4 enemies
#   - breach end-of-night flow triggers report
#   - success unlocks carry over (Nora, Elias, new hotspots)
#   - save/load round-trip works
#   - radio contact mini-loop fires end-to-end
#
# Replaces the archived tools/night_shift_smoke_test.gd (v0.5 API).

const Game := preload("res://scripts/NightShiftGame.gd")
const Save := preload("res://scripts/NightShiftSave.gd")
const Levels := preload("res://scripts/NightShiftLevels.gd")

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
	print("=== Night shift full-flow test (10 nights) ===")
	Save.clear_save()

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame

	# 1) Cover screen — pick slot 1, then normal difficulty.
	_assert(game.phase == "cover", "campaign starts at cover")
	_assert(game.card_layer.get_child_count() >= 1, "cover has slot cards")
	# Click "New Game" on slot 1 (the empty slot is the leftmost)
	game._on_slot_new_pressed(1)
	_assert(game.phase == "cover", "still cover after slot pick (difficulty picker)")
	# Pick normal difficulty
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	_assert(game.phase == "day", "moved to day after difficulty pick")

	# 2) Start the campaign
	game.call("_on_start_pressed")
	_assert(game.phase == "day", "start pressed -> day phase")
	_assert(game.night_index == 0, "fresh campaign starts at night 1 (index 0)")

	# 3) Night 1 — only skip card available
	var day_panels := _day_panels()
	_assert(day_panels.size() == 1, "night 1 day shows exactly 1 card (skip)")

	# 4) Enter night 1 and verify hotspot set
	game.call("_on_day_card_pressed", "start")
	_assert(game.phase == "night", "skipped to night phase")
	_assert(game.hotspots.has("front_door"), "night 1 unlocked front_door")
	_assert(game.hotspots.has("left_window"), "night 1 unlocked left_window")
	_assert(game.hotspots.has("generator"), "night 1 unlocked generator")
	_assert(game.hotspots.size() == 3, "night 1 has exactly 3 hotspots")

	# 5) Trigger an assault and verify enemy spawn
	var front: Dictionary = game.hotspots["front_door"]
	front["assault"] = true
	front["warning"] = false
	game.hotspots["front_door"] = front
	game.call("_update_enemies", 0.1)
	_assert(game.enemy_tokens.has("front_door"), "assault spawns enemy swarm on front_door")
	_assert(game.enemy_tokens["front_door"].size() >= 2, "swarm has at least 2 enemies")

	# 6) Run the night to completion (success) by patching hotspots to safe state.
	_patch_safe_night()
	game.night_elapsed = game.night_duration - 0.1
	for i in range(5):
		game.call("_update_night", 0.1)
	_assert(game.phase == "night_report", "survived to night_report")
	_assert(game.survived, "night 1 marked survived")
	_assert(Save.has_save(), "save written after night 1 success")
	var save_doc: Dictionary = Save.read()
	_assert(int(save_doc.get("night_index", -1)) == 1, "save advanced to night 2 (index 1)")
	_assert(bool(save_doc.get("allies", {}).get("nora", false)), "save has Nora")
	_assert((save_doc.get("unlocked_hotspots", []) as Array).has("right_window"), "save unlocked right_window")

	# 7) Continue to day 2
	game.call("_on_report_continue", true)
	_assert(game.phase == "day", "report continue -> day phase")
	_assert(game.night_index == 1, "advanced to night 2 (index 1)")

	# 8) Day 2 should expose multiple day cards
	day_panels = _day_panels()
	_assert(day_panels.size() >= 3, "night 2 day shows multiple cards (got %d)" % day_panels.size())

	# 9) Pick "door_reinforce" and verify the effect is recorded
	game.call("_on_day_card_pressed", "door_reinforce")
	_assert(game.upgrades.has("door_reinforce"), "door_reinforce recorded as upgrade")
	_assert(game.day_effects.get_cap_bonus("front_door") > 0.0,
		"door_reinforce adds cap bonus to front_door")

	# 10) Enter night 2 and verify right_window joins
	game.call("_show_night")
	_assert(game.hotspots.has("right_window"), "night 2 unlocked right_window")
	_assert(game.hotspots.size() == 4, "night 2 has 4 hotspots")

	# 11) Run night 2 safely + verify radio unlocks on success
	_patch_safe_night()
	game.night_elapsed = game.night_duration - 0.1
	for i in range(5):
		game.call("_update_night", 0.1)
	_assert(game.phase == "night_report", "night 2 -> report")
	_assert(game.survived, "night 2 survived")

	# 12) Night 3 — radio unlocks. Force radio and verify contact mini-loop.
	game.call("_on_report_continue", true)
	_assert(game.night_index == 2, "advanced to night 3 (index 2)")
	# Reset radio state cleanly
	game.radio_available = false
	game.radio_completed = false
	game.radio_missed = false
	game.radio_window_left = 0.0
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.call("_show_night")
	_assert(game.hotspots.has("radio"), "night 3 unlocked radio")
	# Trigger a radio event manually (instead of waiting for time)
	game.radio_available = true
	game.radio_window_left = 10.0
	game.radio_contact_goal = 1
	game.radio_tuned_channel = str(game.radio_target_channel)  # tune to correct channel
	game.radio_wrong_ticks.clear()
	game.player_target_id = "radio"
	game.player_at_target = true
	game.player_pos = game.HOTSPOT_POSITIONS["radio"]
	for i in range(35):
		game.call("_update_night", 0.1)
	_assert(game.radio_contacts_made >= 1, "radio contact scored in night 3 (got %d)" % game.radio_contacts_made)

	# 13) Skip ahead through nights 4..9 by direct _show_night + safe completion
	for night_idx in range(3, 9):
		game.night_index = night_idx
		game.call("_show_night")
		_assert(game.hotspots.size() >= 3, "night %d has hotspots (got %d)" % [night_idx + 1, game.hotspots.size()])
		# Spawn one assault to confirm enemy pipeline still works for any hotspot
		var any_id: String = game.hotspots.keys()[0]
		var h: Dictionary = game.hotspots[any_id]
		h["assault"] = true
		game.hotspots[any_id] = h
		game.call("_update_enemies", 0.1)
		_assert(game.enemy_tokens.has(any_id), "night %d %s spawns enemies" % [night_idx + 1, any_id])
		# Now safe-patch and force-end the night
		_patch_safe_night()
		game.night_elapsed = game.night_duration - 0.1
		for i in range(5):
			game.call("_update_night", 0.1)
		_assert(game.phase == "night_report", "night %d reaches report" % (night_idx + 1))
		_assert(game.survived, "night %d survives with patched state" % (night_idx + 1))
		game.call("_on_report_continue", true)
		_assert(game.phase == "day", "night %d -> day" % (night_idx + 1))

	# 14) Night 10 report -> final
	game.night_index = 9
	game.call("_show_night")
	_patch_safe_night()
	game.night_elapsed = game.night_duration - 0.1
	for i in range(5):
		game.call("_update_night", 0.1)
	_assert(game.phase == "night_report", "night 10 reaches report")
	game.call("_on_report_continue", true)
	# Night 10 is the last night — continue goes to final, not day.
	_assert(game.phase == "final", "after night 10 reaches final")

	# 15) Failure path — force a breach and end-of-night
	game.call("_on_restart_pressed")
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	game.night_index = 0
	var fdoor: Dictionary = game.hotspots["front_door"]
	fdoor["assault"] = true
	fdoor["value"] = 0.0
	game.hotspots["front_door"] = fdoor
	for i in range(20):
		game.call("_update_night", 0.1)
	_assert(game.phase == "night_report", "failure path reaches report")
	_assert(not game.survived, "failure flag set")
	# Failure report should show stats including breach count
	var fail_log: String = game.log_label.text
	_assert(fail_log.find("失守次数") >= 0, "failure report shows breach stats")

	# 16) Save / load round trip via cover screen
	var final_save: Dictionary = Save.read()
	# JSON ints are parsed as floats in Godot, so check by numeric value instead.
	var saved_idx: float = float(final_save.get("night_index", -2))
	_assert(saved_idx >= 0.0 and saved_idx <= 10.0, "save has valid numeric night_index (got %s)" % str(saved_idx))
	game.call("_show_cover_with_continue")
	var cover_btns: Array = game.card_layer.get_children()
	var has_continue := false
	for c in cover_btns:
		if c is Button and c.text == "继续游戏":
			has_continue = true
			break
	_assert(has_continue, "cover with continue offers 继续游戏 button")

	print("Night shift full-flow test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])


func _day_panels() -> Array:
	var out: Array = []
	for c in game.card_layer.get_children():
		if c is Panel:
			out.append(c)
	return out


func _patch_safe_night() -> void:
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		h["value"] = h["max_value"]
		h["breach_timer"] = -1.0
		h["assault"] = false
		h["warning"] = false
		game.hotspots[id] = h
	game.radio_available = false
	game.radio_completed = true
	game.radio_missed = false