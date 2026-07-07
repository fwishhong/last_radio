extends SceneTree
# M15 polish backlog B2 — runtime hooks test suite.
#
# Scope (runtime layer only, after B1 data layer):
#   * NightShiftDayEffects adds 4 new effect IDs (radio_response /
#     night_pressure_tag / npc_keep / npc_remove) plus 4 getters and
#     a 4-case summarize() branch.
#   * NightShiftGame.allies default grows to 6 keys; was_ever_with_us
#     tracks the monotonic "ever-present" set (B2 polish).
#   * _format_narrative_allies_diff prefers per-NPC i18n keys
#     (log_ally_join_<id> / log_ally_left_<id> / log_ally_lost_<id> /
#     log_victor_lost) with a lost branch fallback.
#   * Survivor briefs (survivor_<id>_brief) render in the night report
#     (NightShiftGame + NightReport mirror).
#   * tom_memorial requires_unlocked gate respects was_ever_with_us,
#     so the day-card stays pickable even after night 8's tom_death
#     npc_loss event flips allies["tom"] false.
#   * night 9 injects a synthetic victor_lost event that respects
#     day_effects.get_npc_keep("victor") (victor_stay pin) and emits
#     log_victor_lost when unpinned.
#   * Save schema bumped v5 → v6 with was_ever_with_us and allies-key
#     backfill at the read site.
#
# 10 TC groups, ~80 assertions, runtime-only (GDScript + I18n loader).

const Game := preload("res://scripts/NightShiftGame.gd")
const NightReport := preload("res://scripts/NightReport.gd")
const NightShiftDayEffects := preload("res://scripts/NightShiftDayEffects.gd")
const Data := preload("res://scripts/NightShiftData.gd")
const Save := preload("res://scripts/NightShiftSave.gd")
const I18n := preload("res://scripts/I18n.gd")

const ZH_PATH := "res://data/i18n/zh.json"
const EN_PATH := "res://data/i18n/en.json"
const DAY_CARDS_PATH := "res://data/night_shift/day_cards.json"

const NEW_EFFECT_IDS := [
	"radio_response",
	"night_pressure_tag",
	"npc_keep",
	"npc_remove",
]
const NEW_JOIN_KEYS := [
	"log_ally_join_nora",
	"log_ally_join_elias",
	"log_ally_join_lily",
	"log_ally_join_tom",
]
const NEW_LEFT_KEYS := [
	"log_ally_left_daniel",
]
const NEW_LOST_KEYS := [
	"log_ally_lost_tom",
	"log_victor_lost",
]
const NEW_SURVIVOR_KEYS := [
	"survivor_nora_brief",
	"survivor_elias_brief",
	"survivor_lily_brief",
	"survivor_tom_brief",
	"survivor_daniel_brief",
	"survivor_victor_brief",
]

var passed: int = 0
var failed: int = 0
var game: Node
# NightShiftData extends RefCounted (singleton-style API), so we
# hold the type as Variant to avoid an unnecessary `Node` cast.
var data: RefCounted


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


func _load_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw: Variant = JSON.parse_string(f.get_as_text())
	if not (raw is Dictionary):
		return {}
	return raw as Dictionary


func _spawn_game() -> void:
	if game and is_instance_valid(game):
		game.queue_free()
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	# Awaiting a single frame lets the script's _ready run, which
	# instantiates the data singleton + nodes the test cases poke at.
	await process_frame


# ============================================================================
# TC1: SUPPORTED_IDS contains the 4 new B2 effect IDs.
# ============================================================================
func _tc_supported_ids() -> void:
	print("TC1 SUPPORTED_IDS extension")
	var eff := NightShiftDayEffects.new()
	for eff_id in NEW_EFFECT_IDS:
		_assert(eff.SUPPORTED_IDS.has(eff_id),
			"SUPPORTED_IDS contains '%s'" % eff_id)
	_assert(eff.entries is Array,
		"entries is an Array")
	_assert(eff.entries.is_empty(),
		"fresh NightShiftDayEffects has empty entries")


# ============================================================================
# TC2: get_radio_response_delta sums int values from radio_response entries.
# ============================================================================
func _tc_radio_response_delta() -> void:
	print("TC2 get_radio_response_delta")
	var eff := NightShiftDayEffects.new()
	_assert(eff.get_radio_response_delta() == 0,
		"empty delta starts at 0")
	# victor_go_find has effects: [{radio_response, value=2}]
	eff.add_from_card(data.get_card("victor_go_find"))
	_assert(eff.get_radio_response_delta() == 2,
		"after victor_go_find, radio_response_delta is 2")
	# victor_silent has effects: [{radio_response, value=-1}]
	eff.add_from_card(data.get_card("victor_silent"))
	_assert(eff.get_radio_response_delta() == 1,
		"after victor_silent too, summed (2 + -1) = 1")


# ============================================================================
# TC3: get_night_pressure_tags collects unique tag strings.
# ============================================================================
func _tc_night_pressure_tags() -> void:
	print("TC3 get_night_pressure_tags")
	var eff := NightShiftDayEffects.new()
	var tags0: Array[String] = eff.get_night_pressure_tags()
	_assert(tags0.is_empty(),
		"empty tags list starts empty")
	eff.add_from_card(data.get_card("victor_go_find"))
	var tags1: Array[String] = eff.get_night_pressure_tags()
	_assert(tags1.size() == 1 and tags1[0] == "noise",
		"after victor_go_find, tags=['noise'] (got %s)" % str(tags1))
	# Adding the same card twice still keeps the tag set deduplicated.
	eff.add_from_card(data.get_card("victor_go_find"))
	var tags2: Array[String] = eff.get_night_pressure_tags()
	_assert(tags2.size() == 1,
		"duplicate inserts are deduped (got %d)" % tags2.size())


# ============================================================================
# TC4: get_npc_keep(<id>) returns true after a card with npc_keep target=<id>.
# ============================================================================
func _tc_npc_keep() -> void:
	print("TC4 get_npc_keep")
	var eff := NightShiftDayEffects.new()
	_assert(not eff.get_npc_keep("victor"),
		"empty: not pinned")
	eff.add_from_card(data.get_card("victor_stay"))
	_assert(eff.get_npc_keep("victor"),
		"after victor_stay, npc_keep('victor') is true")
	_assert(not eff.get_npc_keep("daniel"),
		"npc_keep('daniel') still false (only victor is targeted)")
	# let_daniel_stay also emits npc_keep target=daniel
	eff.add_from_card(data.get_card("let_daniel_stay"))
	_assert(eff.get_npc_keep("daniel"),
		"after let_daniel_stay, npc_keep('daniel') is true")


# ============================================================================
# TC5: get_npc_remove(<id>) mirrors get_npc_keep for the npc_remove id.
# ============================================================================
func _tc_npc_remove() -> void:
	print("TC5 get_npc_remove")
	var eff := NightShiftDayEffects.new()
	_assert(not eff.get_npc_remove("daniel"),
		"empty: not removed")
	eff.add_from_card(data.get_card("let_daniel_go"))
	_assert(eff.get_npc_remove("daniel"),
		"after let_daniel_go, npc_remove('daniel') is true")
	_assert(not eff.get_npc_remove("victor"),
		"npc_remove('victor') still false (only daniel is targeted)")
	# Both npc_remove for daniel and npc_keep for daniel coexist on
	# different cards (go vs stay); make sure each is queryable.
	_assert(eff.get_npc_keep("victor") == false,
		"victor_stay wasn't added, npc_keep('victor') false")


# ============================================================================
# TC6: _format_narrative_allies_diff per-NPC key preference + lost branch.
# ============================================================================
func _tc_narrative_diff() -> void:
	print("TC6 _format_narrative_allies_diff per-NPC + lost")
	await _spawn_game()
	# Joined case — should prefer log_ally_join_lily over the generic
	# log_ally_join template.
	var diff_lily: String = game.call("_format_narrative_allies_diff",
		{"lily": false}, {"lily": true})
	_assert(diff_lily.find("Lily") >= 0 and diff_lily.find("加入") >= 0,
		"lily join: per-NPC key used (got '%s')" % diff_lily)
	# Left case with the per-NPC key (only daniel has one today).
	var diff_daniel: String = game.call("_format_narrative_allies_diff",
		{"daniel": true}, {"daniel": false})
	_assert(diff_daniel.find("Daniel") >= 0 and diff_daniel.find(I18n.t("report_survivors_left", [])) >= 0,
		"daniel left: per-NPC log_ally_left_daniel preferred (got '%s')" % diff_daniel)
	# Lost case — no per-NPC key for tom-emulation yet; the function
	# should still produce a meaningful line (uses report_survivors_lost
	# label fallback when no per-NPC key exists — which today DOES
	# exist for tom, so it should pick log_ally_lost_tom).
	var diff_tom: String = game.call("_format_narrative_allies_diff",
		{"tom": true}, {"tom": false})
	_assert(diff_tom.find("Tom") >= 0,
		"tom lost: name appears in diff (got '%s')" % diff_tom)
	# No-change case.
	var diff_none: String = game.call("_format_narrative_allies_diff",
		{"nora": false}, {"nora": false})
	_assert(diff_none.find("—") >= 0,
		"no-change diff uses em-dash placeholder (got '%s')" % diff_none)


# ============================================================================
# TC7: NightReport panel mount with per-NPC diff + survivor briefs renders.
# ============================================================================
func _tc_night_report_panel() -> void:
	print("TC7 NightReport panel mount")
	await _spawn_game()
	# Drive into night_report phase.
	game.night_index = 0
	game.previous_allies = {"nora": false, "elias": false, "victor": true,
		"lily": false, "daniel": false, "tom": false}
	game.allies = {"nora": true, "elias": true, "victor": true,
		"lily": false, "daniel": false, "tom": false}
	game.was_ever_with_us = {"nora": true, "elias": true, "victor": true}
	game.call("_end_night", true)
	_assert(game.phase == "night_report",
		"_end_night(true) reaches night_report")
	var body_text: String = game.log_label.text
	# Line 2 — _format_narrative_allies_diff — should include the per-NPC
	# joined keys ("Nora 加入" / "Elias 加入") once player passes through
	# the success_unlocks loop in _end_night. The night_report log also
	# pulls per-NPC keys when present (B2 polish).
	_assert(body_text.find(I18n.t("log_ally_join_nora", [])) >= 0,
		"night report body uses log_ally_join_nora (got '%s'…)" % body_text.substr(0, 80))
	_assert(body_text.find(I18n.t("log_ally_join_elias", [])) >= 0,
		"night report body uses log_ally_join_elias")
	# Survivor briefs — Nora + Elias + Victor should appear as brief
	# lines because their allies[id] are true on this snapshot.
	_assert(body_text.find(I18n.t("survivor_nora_brief", [])) >= 0,
		"night report body renders survivor_nora_brief")
	_assert(body_text.find(I18n.t("survivor_elias_brief", [])) >= 0,
		"night report body renders survivor_elias_brief")
	_assert(body_text.find(I18n.t("survivor_victor_brief", [])) >= 0,
		"night report body renders survivor_victor_brief")
	# Night Report Panel — render via setup() and confirm the panel
	# tree contains both the per-NPC diff and survivor briefs.
	var panel = NightReport.new()
	root.add_child(panel)
	panel.setup(2, [], false,
		[{"title": "T", "body": "B", "facility": "base", "severity": "neutral"}],
		{},
		{"nora": false, "elias": false},
		{"nora": true, "elias": true},
	)
	var found_per_npc := false
	var found_brief := false
	for c in panel.event_list.get_children():
		if c is VBoxContainer:
			for child_label in c.get_children():
				if child_label is Label:
					var ltxt: String = (child_label as Label).text
					if ltxt.find("Nora") >= 0 and ltxt.find(I18n.t("log_ally_join_nora", [])) >= 0:
						found_per_npc = true
					# Briefs render as indented sublines with the format
					# "  · <Name>——<brief>".
					if ltxt.find(I18n.t("survivor_nora_brief", [])) >= 0:
						found_brief = true
	_assert(found_per_npc,
		"NightReport panel renders per-NPC log_ally_join_nora key")
	_assert(found_brief,
		"NightReport panel renders survivor_nora_brief")


# ============================================================================
# TC8: tom_memorial day-card gate passes via was_ever_with_us, even after
#      allies["tom"] flipped false (T8 polish — pre-B2 the gate only
#      looked at unlocked_hotspots, so tom_memorial was un-pickable on
#      the day after night 8).
# ============================================================================
func _tc_tom_memorial_gate() -> void:
	print("TC8 tom_memorial was_ever_with_us gate")
	await _spawn_game()
	# Default state: tom never present, gate fails (no tom in unlocked_hotspots).
	game.was_ever_with_us.clear()
	game.allies["tom"] = false
	# Manually wire unlocked_hotspots the way the day picker expects.
	game.unlocked_hotspots = ["front_door", "left_window", "right_window",
		"back_door", "generator", "radio", "antenna", "medbay", "storage"]
	var card: Dictionary = data.get_card("tom_memorial")
	_assert(not game.call("_card_unlocked_for_now", card),
		"tom_memorial not pickable when was_ever_with_us empty + allies[tom]=false")
	# Player recovered Tom via night 6 success_unlocks → was_ever_with_us true.
	game.was_ever_with_us["tom"] = true
	_assert(game.call("_card_unlocked_for_now", card),
		"tom_memorial pickable when was_ever_with_us['tom']=true")
	# The fresh data: even though allies["tom"] flipped false (night 8
	# npc_loss tom_death), the gate STILL passes — B2 polish.
	game.allies["tom"] = false
	_assert(game.call("_card_unlocked_for_now", card),
		"tom_memorial still pickable even when allies['tom']=false, as long as was_ever_with_us['tom']=true (the whole point of the was_ever_with_us gate)")
	# Make sure allies currently present is also a passing case.
	game.allies["tom"] = true
	_assert(game.call("_card_unlocked_for_now", card),
		"tom_memorial pickable when allies['tom']=true (the trivial case)")


# ============================================================================
# TC9: Synthetic victor_lost event on night 9 respects day_effects.npc_keep.
# ============================================================================
func _tc_victor_lost_synthetic() -> void:
	print("TC9 victor_lost synthetic event")
	await _spawn_game()
	# Case A — _trigger_event with npc_keep set (victor_stay picked).
	game.night_index = 8  # night_09 zero-based
	game.day_effects.add_from_card(data.get_card("victor_stay"))
	game.allies = {"nora": false, "elias": false, "victor": true,
		"lily": false, "daniel": false, "tom": false}
	# Capture log_label lines emitted by _handle_npc_loss_event /
	# the victor_lost branch.
	var logs_before: int = game.logs.size()
	game.call("_trigger_event", {
		"id": "victor_lost_synthetic", "type": "victor_lost",
		"target": "victor", "time": 0.0, "pressure": 0.0,
	})
	var kept_alive: bool = bool(game.allies.get("victor", false))
	_assert(kept_alive,
		"victor_lost skipped when npc_keep pin is set")
	_assert(game.logs.size() > logs_before,
		"a log line was emitted explaining the pin (kept-alive path)")
	# Case B — without the pin (the player picked victor_go_find or
	# some other non-pin card), the synthetic event flips Victor false
	# and emits the log_victor_lost key.
	game.day_effects.clear()
	game.logs.clear()
	game.allies["victor"] = true
	game.call("_trigger_event", {
		"id": "victor_lost_synthetic", "type": "victor_lost",
		"target": "victor", "time": 0.0, "pressure": 0.0,
	})
	_assert(not bool(game.allies.get("victor", false)),
		"victor_lost flips allies['victor'] false when npc_keep is unset")
	var last_log: String = ""
	if not game.logs.is_empty():
		last_log = str(game.logs[game.logs.size() - 1])
	_assert(last_log.find(I18n.t("log_victor_lost", [])) >= 0,
		"unpin path emits log_victor_lost (got '%s')" % last_log)
	# Case C — _show_night on night_index == 8 schedules the synthetic
	# event in event_queue, with time = night_duration * 0.45.
	game.day_effects.clear()
	game.allies = {"nora": false, "elias": false, "victor": true,
		"lily": false, "daniel": false, "tom": false}
	game.night_index = 8
	game.call("_show_night")
	var found_synthetic := false
	for ev in game.event_queue:
		if str(ev.get("id", "")) == "victor_lost_synthetic":
			found_synthetic = true
			break
	_assert(found_synthetic,
		"_show_night on night_index == 8 enqueues the synthetic victor_lost event")


# ============================================================================
# TC10: zh + en i18n keys parity — all 13 B1 keys present on both sides,
#       and the broader key sets are identical (no orphans in either).
# ============================================================================
func _tc_i18n_parity() -> void:
	print("TC10 zh/en i18n key parity")
	var zh := _load_dict(ZH_PATH)
	var en := _load_dict(EN_PATH)
	_assert(not zh.is_empty() and not en.is_empty(),
		"zh.json and en.json both load")
	for k in NEW_JOIN_KEYS + NEW_LEFT_KEYS + NEW_LOST_KEYS + NEW_SURVIVOR_KEYS:
		_assert(zh.has(k) and en.has(k),
			"key '%s' present on BOTH sides" % k)
		_assert(str(zh[k]).strip_edges() != "" and str(en[k]).strip_edges() != "",
			"key '%s' has non-empty translation on both sides" % k)
	# Identical key set (broader parity — catches any future drift).
	var zh_only: Array = []
	var en_only: Array = []
	for k in zh.keys():
		if not en.has(k):
			zh_only.append(k)
	for k in en.keys():
		if not zh.has(k):
			en_only.append(k)
	_assert(zh_only.is_empty(),
		"zh.json has no keys missing in en.json (orphans=%s)" % str(zh_only))
	_assert(en_only.is_empty(),
		"en.json has no keys missing in zh.json (orphans=%s)" % str(en_only))


# ============================================================================
# Main driver — load data, spawn game once, run all TCs.
# ============================================================================
func _run() -> void:
	print("=== M15 runtime hook test (polish backlog B2) ===")
	# Spin up the data singleton once so TC2-TC9 can pull cards by id.
	var data_script := load("res://scripts/NightShiftData.gd")
	data = data_script.new()
	data.load_all()
	print("  ok: NightShiftData loaded")

	# TC1-TC5 are pure GDScript unit tests against NightShiftDayEffects +
	# data loader — no scene instantiation needed.
	_tc_supported_ids()
	_tc_radio_response_delta()
	_tc_night_pressure_tags()
	_tc_npc_keep()
	_tc_npc_remove()

	# TC6-TC9 instantiate the NightShiftGame scene; handled inside each TC.
	_tc_narrative_diff()
	_tc_night_report_panel()
	_tc_tom_memorial_gate()
	_tc_victor_lost_synthetic()

	# TC10 is a static i18n key-parity scan.
	_tc_i18n_parity()

	print("M15 runtime hook test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
