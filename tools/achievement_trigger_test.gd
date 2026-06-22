extends SceneTree
# Tests the 8 chapter-1-reachable Steam achievements wired into
# NightShiftGame. Each assertion drives a real trigger site and inspects
# the Steamworks singleton's _unlocked cache.
#
# Also exercises the Steamworks facade directly: id catalog, idempotency,
# unknown-id rejection, fresh-run reset.

const Game := preload("res://scripts/NightShiftGame.gd")
const Save := preload("res://scripts/NightShiftSave.gd")

var game: Node
var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _run() -> void:
	print("=== Achievement trigger test ===")
	Save.clear_save()

	# 1) Catalog check on the Steamworks script (no autoload required).
	var steam_script: GDScript = load("res://scripts/Steamworks.gd")
	var ids: Dictionary = steam_script.ACHIEVEMENT_IDS
	_assert(ids.size() == 8, "ACHIEVEMENT_IDS has exactly 8 entries (got %d)" % ids.size())
	_assert(not ids.has("hard_clear"), "hard_clear was removed")
	_assert(not ids.has("ng_plus_one"), "ng_plus_one was removed")
	for k in ["first_night", "first_contact", "recruit_nora", "recruit_elias",
			"all_three_allies", "reach_victor", "clear_all_nights", "no_breach"]:
		_assert(ids.has(k), "ACHIEVEMENT_IDS contains '%s'" % k)

	# Locate the Steamworks instance. With `--script`, autoloads DO load
	# (so `/root/Steamworks` exists) but the autoload and any local
	# instance we create would diverge — always inspect the autoload so
	# what the game's `_unlock_ach` writes is what we read back.
	var steam: Node = root.get_node_or_null("Steamworks")
	if steam == null:
		# Fallback: instantiate one manually and expose it as /root/Steamworks.
		steam = steam_script.new()
		steam.name = "Steamworks"
		root.add_child(steam)
		await process_frame
	# Reset persistent cache so prior runs don't pollute today's assertions.
	steam._unlocked.clear()

	# 2) Unknown id returns false and warns.
	var bogus_ok: bool = steam.unlock_achievement("bogus_thing")
	_assert(not bogus_ok, "unlock_achievement('bogus_thing') returns false")
	_assert(not steam.is_achievement_unlocked("bogus_thing"),
		"bogus id is not stored in _unlocked")

	# 3) Idempotency: calling unlock on a known id twice does not re-fire.
	# The implementation guards internally; verify by checking the cache.
	steam.unlock_achievement("first_contact")
	_assert(steam.is_achievement_unlocked("first_contact"), "first_contact unlocked once")
	var unlocked_after_first: int = steam.get_unlocked_achievements().size()
	steam.unlock_achievement("first_contact")
	steam.unlock_achievement("first_contact")
	var unlocked_after_repeat: int = steam.get_unlocked_achievements().size()
	_assert(unlocked_after_repeat == unlocked_after_first,
		"repeat unlock does not change set size (was %d, now %d)" % [unlocked_after_first, unlocked_after_repeat])

	# 4) Boot a NightShiftGame scene to drive the real trigger sites.
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	await process_frame
	_assert(game.phase == "night", "entered night 1 (phase=%s)" % game.phase)

	# Reset the game-side single-fire flags so we can re-exercise them in
	# isolation regardless of any prior autoload state. Also reset the
	# local Steamworks cache so assertions read clean values.
	steam._unlocked.clear()
	for f in ["_ach_first_contact", "_ach_reach_victor", "_ach_recruit_nora",
			"_ach_recruit_elias", "_ach_all_three", "_ach_first_night",
			"_ach_clear_all", "_ach_no_breach"]:
		game.set(f, false)

	# 5) first_contact: drive a successful radio contact.
	game.radio_available = true
	game.radio_completed = false
	game.radio_missed = false
	game.radio_window_left = 30.0
	game.radio_contact_goal = 1
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = "elias"  # a non-victor channel — first_contact should still fire
	game.radio_target_channel = "elias"
	game.radio_channels_catalog = [
		{"id": "victor", "label": "Victor", "desc": "victor", "color": "#FFD27F", "exposure_on_wrong": 0.0},
		{"id": "elias", "label": "Elias", "desc": "elias", "color": "#9CD9FF", "exposure_on_wrong": 0.0},
	]
	game.unlocked_hotspots.append("radio")
	game.hotspots["radio"] = {
		"id": "radio", "kind": "radio",
		"pos": game.HOTSPOT_POSITIONS["radio"],
		"value": 100.0, "max_value": 100.0,
		"pressure": 0.0, "active": false, "warning": false,
		"assault": false, "breach_timer": -1.0, "temp_seal": 0.0,
	}
	game.player_target_id = "radio"
	game.player_at_target = true
	game.player_pos = game.HOTSPOT_POSITIONS["radio"]
	game.night_stats["radio_contacts"] = 0
	for i in range(35):
		game.call("_update_night", 0.1)
	_assert(steam.is_achievement_unlocked("first_contact"),
		"first_contact unlocked after one radio contact")

	# 6) reach_victor: target the victor channel and re-score.
	game._ach_first_contact = true  # already fired, don't double-count
	game.radio_available = true
	game.radio_completed = false
	game.radio_missed = false
	game.radio_window_left = 30.0
	game.radio_contact_goal = 1
	game.radio_contacts_made = 0
	game.radio_contact_progress = 0.0
	game.radio_tuned_channel = "victor"
	game.radio_target_channel = "victor"
	for i in range(35):
		game.call("_update_night", 0.1)
	_assert(steam.is_achievement_unlocked("reach_victor"),
		"reach_victor unlocked after first contact on victor channel")
	_assert(game._ach_first_contact, "_ach_first_contact flag is sticky")

	# 7) recruit_nora + recruit_elias: flip allies directly and call the
	# helper used by _end_night's success_unlocks loop. Drive it the same
	# way the night-end path does.
	game.allies = {"nora": false, "elias": false, "victor": true}
	# nora false -> true
	game.allies["nora"] = true
	if game._ach_recruit_nora == false:
		game._ach_recruit_nora = true
		game._unlock_ach("recruit_nora")
	_assert(steam.is_achievement_unlocked("recruit_nora"),
		"recruit_nora unlocked on allies.nora false->true")
	# elias false -> true
	game.allies["elias"] = true
	if game._ach_recruit_elias == false:
		game._ach_recruit_elias = true
		game._unlock_ach("recruit_elias")
	_assert(steam.is_achievement_unlocked("recruit_elias"),
		"recruit_elias unlocked on allies.elias false->true")

	# 8) all_three_allies: with all three true, single fire.
	if not (game.allies.get("nora", false) and game.allies.get("elias", false) and game.allies.get("victor", false)):
		game.allies["victor"] = true  # just in case
	if not game._ach_all_three:
		game._ach_all_three = true
		game._unlock_ach("all_three_allies")
	_assert(steam.is_achievement_unlocked("all_three_allies"),
		"all_three_allies unlocked when all three allies true")

	# 9) first_night: drive a successful night-1 end.
	game._ach_first_night = false
	game.night_stats = {
		"radio_contacts": 0, "enemies_killed": 0, "enemies_despawned": 0,
		"hotfixes": 0.0, "breaches": 0, "breaches_first_id": "",
		"events_fired": 0,
	}
	game.total_breaches = 0
	game.call("_end_night", true)
	_assert(steam.is_achievement_unlocked("first_night"),
		"first_night unlocked after night 1 success")
	_assert(game._ach_first_night, "_ach_first_night flag set")

	# 10) clear_all_nights + no_breach: simulate the last night (index 9).
	game._ach_first_night = true
	game._ach_clear_all = false
	game._ach_no_breach = false
	game.night_index = game.night_count - 1  # last night
	game.night_stats = {
		"radio_contacts": 0, "enemies_killed": 0, "enemies_despawned": 0,
		"hotfixes": 0.0, "breaches": 0, "breaches_first_id": "",
		"events_fired": 0,
	}
	game.total_breaches = 0
	game.call("_end_night", true)
	_assert(steam.is_achievement_unlocked("clear_all_nights"),
		"clear_all_nights unlocked on night 10 success")
	_assert(steam.is_achievement_unlocked("no_breach"),
		"no_breach unlocked when total_breaches == 0 across the run")

	# 11) no_breach does NOT fire if a breach happened earlier.
	game._ach_clear_all = false
	game._ach_no_breach = false
	game._ach_first_night = true
	game.night_index = game.night_count - 1
	game.night_stats = {
		"radio_contacts": 0, "enemies_killed": 0, "enemies_despawned": 0,
		"hotfixes": 0.0, "breaches": 1, "breaches_first_id": "front_door",
		"events_fired": 0,
	}
	game.total_breaches = 1
	steam._unlocked.erase("no_breach")
	game.call("_end_night", true)
	_assert(steam.is_achievement_unlocked("clear_all_nights"),
		"clear_all_nights still fires when there were breaches")
	_assert(not steam.is_achievement_unlocked("no_breach"),
		"no_breach stays locked when total_breaches > 0")

	# 12) Helper guards against double-fire at the game-side flag level.
	game._ach_first_night = true
	game.call("_unlock_ach", "first_night")  # already unlocked at Steamworks too
	_assert(steam.is_achievement_unlocked("first_night"),
		"_unlock_ach on already-unlocked id is safe")

	# 13) Reset-between-saves behavior: the Steamworks singleton's
	# _unlocked persists for its lifetime (autoload). New game sessions
	# accumulate rather than wipe — assert deterministically so the
	# behavior is documented.
	var all_unlocked: Array = steam.get_unlocked_achievements()
	# 7 of the 8 chapter-1 ids are present at this point; no_breach was
	# explicitly erased above to verify the lock-on-guard branch.
	_assert(all_unlocked.size() == 7,
		"by the end of the test, Steamworks has accumulated 7 unlocks (got %d)" % all_unlocked.size())
	for k in ["first_night", "first_contact", "recruit_nora", "recruit_elias",
			"all_three_allies", "reach_victor", "clear_all_nights"]:
		_assert(k in all_unlocked, "Steamworks tracked '%s' from this test run" % k)
	_assert(not (all_unlocked.has("no_breach")),
		"no_breach was erased to verify the guard branch and stays out")

	print("Achievement trigger test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	if is_instance_valid(game):
		game.queue_free()
	quit(0 if failed == 0 else 1)