extends SceneTree
# M13 narrative-hooks — Night report 3-line body (Hook C) test.
# Verifies:
# 1. NightShiftGame._show_day snapshots previous_allies.
# 2. NightShiftGame._format_narrative_allies_diff formats joined/left
#    correctly given prev + cur allies dicts.
# 3. _show_night_report's log_label includes the 3 narrative lines
#    (当夜事件 / 幸存者状态 / Victor 破碎广播).
# 4. NightReport scene's 3-line body block renders when allies_before +
#    current_allies are passed in via setup().

const Game := preload("res://scripts/NightShiftGame.gd")
const NightReport := preload("res://scripts/NightReport.gd")
const Save := preload("res://scripts/NightShiftSave.gd")
const I18n := preload("res://scripts/I18n.gd")

var passed: int = 0
var failed: int = 0
var game: Node


func _initialize() -> void:
	I18n.load_all()
	I18n.locale = "zh"
	Save.clear_save()
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
	print("=== Night report log test ===")

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame

	# ----- 1. Snapshot behavior -----
	# After _ready the cover screen runs and snapshots at the start of the
	# first _show_day. Drive the game into day phase and verify the snapshot
	# was taken.
	game._on_slot_new_pressed(1)
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	_assert(game.phase == "day", "moved to day after slot+difficulty")
	_assert(game.previous_allies != null and not game.previous_allies.is_empty(),
		"previous_allies snapshot taken at start of _show_day")
	# snapshot should equal current allies at that moment
	var snap0: Dictionary = game.previous_allies.duplicate(true)
	_assert(snap0.has("nora") and snap0.has("elias") and snap0.has("victor"),
		"snapshot contains base allies keys")

	# Mutate allies and re-snapshot to verify duplication (not by-ref)
	game.allies["nora"] = true
	game.call("_show_day")
	var snap1: Dictionary = game.previous_allies
	_assert(snap1.get("nora", false) == true,
		"snapshot reflects current allies (nora joined)")

	# ----- 2. _format_narrative_allies_diff formatting -----
	# Joined case
	var diff_join: String = game.call("_format_narrative_allies_diff",
		{"nora": false, "elias": false}, {"nora": true, "elias": false})
	_assert(diff_join.find("Nora") >= 0 and diff_join.find(I18n.t("report_survivors_joined", [])) >= 0,
		"joined diff mentions Nora + joined label: '%s'" % diff_join)

	# Left case
	var diff_left: String = game.call("_format_narrative_allies_diff",
		{"nora": true, "elias": false}, {"nora": false, "elias": false})
	_assert(diff_left.find("Nora") >= 0 and diff_left.find(I18n.t("report_survivors_left", [])) >= 0,
		"left diff mentions Nora + left label: '%s'" % diff_left)

	# No change case
	var diff_none: String = game.call("_format_narrative_allies_diff",
		{"nora": false}, {"nora": false})
	_assert(diff_none.find("—") >= 0,
		"no-change diff uses em-dash placeholder: '%s'" % diff_none)

	# Mixed join + left
	var diff_mixed: String = game.call("_format_narrative_allies_diff",
		{"nora": true, "elias": false, "daniel": true},
		{"nora": true, "elias": true, "daniel": false})
	_assert(diff_mixed.find("Elias") >= 0 and diff_mixed.find("Daniel") >= 0,
		"mixed diff mentions both Elias (join) and Daniel (left): '%s'" % diff_mixed)
	_assert(diff_mixed.find(I18n.t("report_survivors_joined", [])) >= 0,
		"mixed diff has joined label")
	_assert(diff_mixed.find(I18n.t("report_survivors_left", [])) >= 0,
		"mixed diff has left label")

	# ----- 3. _show_night_report renders 3-line body -----
	game.night_index = 0
	game.allies = {"nora": false, "elias": false, "victor": true}
	game.previous_allies = {"nora": false, "elias": false, "victor": true}
	game.call("_end_night", true)
	_assert(game.phase == "night_report", "moved to night_report phase")
	var body_text: String = game.log_label.text
	# Line 1 starts with · (the bullet marker)
	_assert(body_text.find("· ") >= 0, "log_label starts with bullet marker")
	# Line 3 contains the night-1 victor log (since night_index was 0 → N=1)
	var n1_log: String = I18n.t("report_victor_log_1")
	_assert(body_text.find(n1_log) >= 0,
		"log_label includes report_victor_log_1 (got: '%s' | expected: '%s')" % [
			body_text.substr(0, 80), n1_log
		])

	# ----- 4. NightReport scene 3-line body block -----
	# Mount a fresh NightReport panel and feed it allies data so it renders
	# the narrative body block (the BaseScreen code path).
	# Avoid `await process_frame` after `_end_night` — the scene-tree exit
	# triggered by `_make_button`'s tween cleanup hangs headless awaits.
	var report_panel = NightReport.new()
	root.add_child(report_panel)
	report_panel.setup(2, [], false,
		[{"title": "测试", "body": "测试事件", "facility": "base", "severity": "neutral"}],
		{},
		{"nora": true, "elias": false},   # allies_before
		{"nora": true, "elias": true},    # current_allies — Elias joined
	)
	var has_narrative := false
	for c in report_panel.event_list.get_children():
		# The narrative block is a VBoxContainer of Labels.
		if c is VBoxContainer:
			for child_label in c.get_children():
				if child_label is Label:
					var ltxt: String = (child_label as Label).text
					if ltxt.find("Elias") >= 0 and ltxt.find(I18n.t("report_survivors_joined", [])) >= 0:
						has_narrative = true
					if ltxt.find(I18n.t("report_victor_log_2", [])) >= 0:
						has_narrative = true
	_assert(has_narrative, "NightReport panel renders 3-line body when allies passed")

	# Verify fallback: when allies_before is empty, the panel renders event cards
	# instead of the narrative body.
	var report_panel2 = NightReport.new()
	root.add_child(report_panel2)
	report_panel2.setup(2, ["测试行"], false,
		[{"title": "T", "body": "B", "facility": "base", "severity": "neutral"}],
		{},
		{},
		{},
	)
	var has_event_card := false
	for c in report_panel2.event_list.get_children():
		if c is PanelContainer:
			has_event_card = true
			break
	_assert(has_event_card, "NightReport panel falls back to event cards when allies data empty")

	print("Night report log test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])