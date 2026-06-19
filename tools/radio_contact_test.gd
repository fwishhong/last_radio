extends SceneTree
# Tests the radio contact mini-loop: when radio_available is true, walking to
# the radio hotspot and standing there for RADIO_CONTACT_SECONDS (3s) scores
# one contact. Reaching radio_contact_goal completes the radio.
#
# Also checks: window counts down, missed window shuts radio off, progress
# bleeds when the player steps away mid-contact.

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
	print("=== Radio contact test ===")
	Save.clear_save()

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	_assert(game.phase == "night", "entered night 1")

	# Night 1 doesn't have radio by default — but the data path lets us force
	# it on for this test. Force-unlock the radio hotspot first.
	var radio_h: Dictionary = {
		"id": "radio",
		"kind": "radio",
		"pos": game.HOTSPOT_POSITIONS["radio"],
		"value": 100.0,
		"max_value": 100.0,
		"pressure": 0.0,
		"active": false,
		"warning": false,
		"assault": false,
		"breach_timer": -1.0,
		"temp_seal": 0.0,
	}
	game.hotspots["radio"] = radio_h
	game.unlocked_hotspots.append("radio")

	# Build a minimal channel catalog for testing (mirrors v2_signals.json).
	game.radio_channels_catalog = [
		{"id": "victor", "label": "Victor", "desc": "victor", "color": "#FFD27F", "exposure_on_wrong": 0.0},
		{"id": "elias", "label": "Elias", "desc": "elias", "color": "#9CD9FF", "exposure_on_wrong": 0.0},
		{"id": "static", "label": "干扰", "desc": "static", "color": "#C97C7C", "exposure_on_wrong": 0.5},
	]
	game.radio_target_channel = "victor"

	# 1) Force radio_available on with a 5-second window.
	game.radio_available = true
	game.radio_completed = false
	game.radio_missed = false
	game.radio_window_left = 5.0
	game.radio_contact_goal = 1
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = ""
	game.night_stats["radio_contacts"] = 0

	# 2) Stand on the radio tuned to the correct channel; tick the night loop.
	game.player_target_id = "radio"
	game.player_at_target = true
	game.player_pos = game.HOTSPOT_POSITIONS["radio"]  # snap to radio
	game.radio_tuned_channel = "victor"  # matches target
	# 3s should be enough to score one contact.
	for i in range(35):
		game.call("_update_night", 0.1)
	_assert(game.radio_contacts_made >= 1, "standing at radio on correct channel scored >= 1 contact (got %d)" % game.radio_contacts_made)
	_assert(game.radio_completed, "single-goal radio marked completed")
	_assert(int(game.night_stats.get("radio_contacts", 0)) >= 1, "night_stats.radio_contacts counted")
	_assert(game.radio_window_left <= 5.0, "window decremented over time (left=%.2f)" % game.radio_window_left)

	# 3) Reset and verify the missed-window path shuts radio off.
	game.radio_available = true
	game.radio_completed = false
	game.radio_missed = false
	game.radio_window_left = 1.0  # tiny window
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = "victor"
	game.player_target_id = "left_window"  # standing somewhere else
	game.player_at_target = true
	for i in range(15):
		game.call("_update_night", 0.1)
	_assert(not game.radio_available, "window expiry turns off radio_available")
	_assert(game.radio_missed, "missed window flags radio_missed")
	_assert(game.radio_contacts_made == 0, "no contacts scored while idle")

	# 4) Reset and verify stepping away mid-contact bleeds progress.
	game.radio_available = true
	game.radio_completed = false
	game.radio_missed = false
	game.radio_window_left = 30.0
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = "victor"
	game.player_target_id = "radio"
	game.player_at_target = true
	game.player_pos = game.HOTSPOT_POSITIONS["radio"]
	# Spend 1.5s at radio (half the contact time).
	for i in range(15):
		game.call("_update_night", 0.1)
	_assert(game.radio_contact_progress >= 1.0, "progress accumulated while standing (got %.2f)" % game.radio_contact_progress)
	# Now step away — progress should bleed back down.
	game.player_target_id = "left_window"
	game.player_at_target = true
	var before: float = game.radio_contact_progress
	for i in range(15):
		game.call("_update_night", 0.1)
	_assert(game.radio_contact_progress < before, "progress bleeds when stepping away (was %.2f, now %.2f)" % [before, game.radio_contact_progress])
	_assert(game.radio_contacts_made == 0, "no contact scored during interrupted attempt")

	# 5) Multi-goal radio: raise goal to 2 and verify two contacts complete it.
	game.radio_available = true
	game.radio_completed = false
	game.radio_missed = false
	game.radio_window_left = 60.0
	game.radio_contact_goal = 2
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = "victor"
	game.player_target_id = "radio"
	game.player_at_target = true
	game.player_pos = game.HOTSPOT_POSITIONS["radio"]
	# 8s should be enough for two contacts.
	for i in range(80):
		game.call("_update_night", 0.1)
	_assert(game.radio_contacts_made >= 2, "multi-goal radio scored >= 2 contacts (got %d)" % game.radio_contacts_made)
	_assert(game.radio_completed, "multi-goal radio marked completed")

	# 6) Verify the radio panel becomes visible while standing at radio.
	game.radio_available = true
	game.radio_completed = false
	game.radio_window_left = 30.0
	game.radio_contact_goal = 1
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = "victor"
	game.player_target_id = "radio"
	game.player_at_target = true
	game.player_pos = game.HOTSPOT_POSITIONS["radio"]
	game.call("_update_night", 0.1)
	_assert(game.radio_panel.visible, "radio progress panel shows while standing at radio")

	# 7) Panel hides when player walks away.
	game.player_target_id = "left_window"
	game.player_at_target = true
	game.call("_update_night", 0.1)
	_assert(not game.radio_panel.visible, "radio panel hides when player walks away")

	# 8) NEW: wrong-channel does not advance progress.
	game.radio_available = true
	game.radio_completed = false
	game.radio_missed = false
	game.radio_window_left = 30.0
	game.radio_contact_goal = 1
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = "elias"  # wrong channel
	game.radio_wrong_ticks.clear()
	game.player_target_id = "radio"
	game.player_at_target = true
	game.player_pos = game.HOTSPOT_POSITIONS["radio"]
	var initial_exposure: int = int(game.resources.get("exposure", 0))
	for i in range(35):
		game.call("_update_night", 0.1)
	_assert(game.radio_contact_progress < 0.5, "wrong channel does not advance progress (got %.2f)" % game.radio_contact_progress)
	_assert(game.radio_contacts_made == 0, "wrong channel scores 0 contacts")
	# elias has exposure_on_wrong = 0, so exposure should be unchanged
	_assert(int(game.resources.get("exposure", 0)) == initial_exposure,
		"elias (no penalty) keeps exposure steady")

	# 9) NEW: wrong-channel "static" charges exposure once per session.
	game.radio_available = true
	game.radio_window_left = 30.0
	game.radio_contact_goal = 1
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = "static"  # wrong + has exposure_on_wrong
	game.radio_wrong_ticks.clear()
	game.player_target_id = "radio"
	game.player_at_target = true
	game.player_pos = game.HOTSPOT_POSITIONS["radio"]
	var exp_before: int = int(game.resources.get("exposure", 0))
	for i in range(35):
		game.call("_update_night", 0.1)
	_assert(int(game.resources.get("exposure", 0)) == exp_before + 1,
		"static channel bumps exposure by 1 (was %d, now %d)" % [exp_before, int(game.resources.get("exposure", 0))])
	# Second pass should NOT bump again (radio_wrong_ticks records once per channel)
	for i in range(35):
		game.call("_update_night", 0.1)
	_assert(int(game.resources.get("exposure", 0)) == exp_before + 1,
		"static channel does not charge exposure twice (now %d)" % int(game.resources.get("exposure", 0)))

	# 10) NEW: success contact raises trust.
	game.radio_available = true
	game.radio_window_left = 30.0
	game.radio_contact_goal = 1
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = "victor"
	game.radio_wrong_ticks.clear()
	game.player_target_id = "radio"
	game.player_at_target = true
	game.player_pos = game.HOTSPOT_POSITIONS["radio"]
	var trust_before: int = int(game.resources.get("trust", 0))
	for i in range(35):
		game.call("_update_night", 0.1)
	_assert(int(game.resources.get("trust", 0)) == trust_before + 1,
		"successful contact raises trust by 1 (was %d, now %d)" % [trust_before, int(game.resources.get("trust", 0))])

	print("Radio contact test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])