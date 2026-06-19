extends SceneTree
# Day panel + breach enemy + save flow integration test.
# Drives NightShiftGame through: cover -> start -> day card pick -> night -> assault
# -> breach enemy spawn -> save -> quit.

const Game := preload("res://scripts/NightShiftGame.gd")
const Save := preload("res://scripts/NightShiftSave.gd")
const I18n := preload("res://scripts/I18n.gd")

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
	print("=== Game flow integration test ===")
	I18n.load_all()
	# Wipe any previous save
	Save.clear_save()
	_assert(not Save.has_save(), "no save at start")

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	# Let _ready run before driving the state machine
	await process_frame

	# 1) Cover phase
	_assert(game.phase == "cover", "starts at cover")
	var cover_btns: Array = game.card_layer.get_children()
	_assert(cover_btns.size() >= 1, "cover has start button")

	# 2) Pick slot 1, then normal difficulty, which both clears and starts a new run
	game._on_slot_new_pressed(1)
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	_assert(game.phase == "day", "moved to day")
	_assert(game.night_index == 0, "night_index = 0")
	# Drain queue_free from the pickers synchronously by waiting 100ms.
	OS.delay_msec(100)

	# 3) Day panel shows 1 card (skip) for night 1
	var day_panels: Array = []
	for c in game.card_layer.get_children():
		if c is Panel:
			day_panels.append(c)
	_assert(day_panels.size() == 1, "night 1 day shows 1 card (skip)")

	# 4) Pick "start" -> moves to night
	game.call("_on_day_card_pressed", "start")
	_assert(game.phase == "night", "moved to night")
	_assert(game.hotspots.has("front_door"), "front_door hotspot exists")
	_assert(game.hotspots.has("left_window"), "left_window hotspot exists")
	_assert(game.hotspots.has("generator"), "generator hotspot exists")
	_assert(game.hotspots.size() == 3, "3 hotspots for night 1")

	# 5) Trigger an assault event manually, verify enemy spawns
	var front: Dictionary = game.hotspots["front_door"]
	front["assault"] = true
	game.call("_update_enemies", 0.1)
	_assert(game.enemy_tokens.has("front_door"), "enemy swarm spawned on front_door assault")
	var enemies: Array = game.enemy_tokens.get("front_door", [])
	_assert(enemies.size() >= 2, "at least 2 enemies (got %d)" % enemies.size())

	# 6) Update enemies; they should move toward hotspot
	var start_pos: Vector2 = enemies[0]["pos"]
	game.call("_update_enemies", 0.5)
	var list_after: Array = game.enemy_tokens.get("front_door", [])
	if list_after.size() > 0:
		var new_pos: Vector2 = list_after[0]["pos"]
		var moved: float = start_pos.distance_to(new_pos)
		_assert(moved > 1.0, "enemies moved toward hotspot (moved=%.1f)" % moved)

	# 7) Dismiss enemies
	front["assault"] = false
	game.call("_update_enemies", 0.1)
	_assert(game.enemy_tokens.has("front_door"), "enemies still on field, will despawn over time")

	# 8) Force-end the night (success) and check progress
	game.call("_end_night", true)
	_assert(game.phase == "night_report", "in night_report")
	_assert(game.survived, "marked survived")
	_assert(Save.has_save(), "save written after night end")

	# 9) Read save and verify state
	var doc: Dictionary = Save.read()
	_assert(int(doc.get("night_index", -1)) == 1, "save advanced to night 2 (index 1)")
	_assert(bool(doc.get("allies", {}).get("nora", false)), "save has nora")
	_assert((doc.get("unlocked_hotspots", []) as Array).has("right_window"), "save has right_window unlocked")

	# 10) Press continue -> goes to day
	game.call("_on_report_continue", true)
	_assert(game.phase == "day", "back to day for night 2")

	# 11) Day 2: verify multiple cards
	var panels2: Array = []
	for c in game.card_layer.get_children():
		if c is Panel:
			panels2.append(c)
	# Debug: list pickable ids
	var dbg_level: Dictionary = (load("res://scripts/NightShiftLevels.gd") as Script).LEVELS[1]
	var dbg_choices: Array = dbg_level.get("choices", [])
	var dbg_ids := []
	for c in dbg_choices:
		dbg_ids.append(str(c.get("id", "")))
	_assert(panels2.size() >= 3, "day 2 shows multiple cards (got %d, level choices=%s)" % [panels2.size(), str(dbg_ids)])

	# 12) Verify _save_progress writes correctly mid-flow
	game.current_slot = 1
	game.call("_save_progress")
	_assert(Save.has_save(), "manual save works")

	# 13) Cover screen shows slot cards when save present
	game.call("_show_slot_picker")
	# Buttons live inside the per-slot Panel cards, not directly under
	# card_layer. Recurse to find them.
	var all_btns: Array = []
	_collect_buttons(game.card_layer, all_btns)
	var has_continue := false
	var has_new := false
	for c in all_btns:
		if c.text == I18n.t("slot_play"):
			has_continue = true
		elif c.text == I18n.t("slot_new"):
			has_new = true
	_assert(has_continue, "slot card has 'Continue' button (slot_play=" + I18n.t("slot_play") + ")")
	_assert(has_new, "empty slot has 'New Game' button (slot_new=" + I18n.t("slot_new") + ")")


func _collect_buttons(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_collect_buttons(c, out)

	print("Game flow integration: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
