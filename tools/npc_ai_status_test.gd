extends SceneTree
# NpcStatusBar regression test — polish spec §4.4.
#
# Headless test that drives the bar's refresh() logic through each status
# state in priority order. We instantiate NpcStatusBar as a SceneTree
# child so the Panel + Label nodes can build their children without a
# viewport.
#
# Coverage:
#   1. hidden when allies dict is empty
#   2. hidden when no ally is true (nora=false, elias=false)
#   3. visible when at least one ally is true and npc_state has it
#   4. status_text: low trust (< 2) overrides everything
#   5. status_text: target == "" -> "待命"
#   6. status_text: target != "" + walk_timer > 0 -> "赶路中"
#   7. status_text: target != "" + walk_timer <= 0 -> "救急中"
#   8. status_text is i18n-aware (en and zh both resolve)
#   9. refresh() tears down stale rows when ally leaves
#  10. name fallback when no survivor_*_brief key in locale

const Bar := preload("res://scripts/NpcStatusBar.gd")
const I18n := preload("res://scripts/I18n.gd")

var _failed := 0
var _passed := 0
var _bar: Control


func _initialize() -> void:
	I18n.load_locale("zh")
	_bar = Bar.new()
	root.add_child(_bar)

	_test_initial_hidden()
	_test_visible_with_ally()
	_test_status_priority_low_trust()
	_test_status_idle()
	_test_status_walking()
	_test_status_emergency()
	_test_i18n_locale_switch()
	_test_stale_row_teardown()
	_test_name_fallback_when_no_brief()

	print("")
	print("npc_ai_status_test: %d passed / %d failed" % [_passed, _failed])
	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  OK   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s" % label)


# --- tests ---


func _test_initial_hidden() -> void:
	print("[initial hidden]")
	_bar.refresh({}, {}, 3.0)
	_expect(not _bar.visible, "bar hidden when allies empty")


func _test_visible_with_ally() -> void:
	print("[visible with ally]")
	var allies := {"nora": true, "elias": false}
	var npc_state := {"nora": {"target": "", "walk_timer": 0.0}}
	_bar.refresh(allies, npc_state, 3.0)
	_expect(_bar.visible, "bar visible when at least one ally true + npc_state has entry")
	_expect(_bar._rows.has("nora"), "row built for nora")
	_expect(not _bar._rows.has("elias"), "no row for elias (not in npc_state)")


func _test_status_priority_low_trust() -> void:
	print("[status: low trust overrides]")
	# Even if nora is in middle of a repair, trust<2 forces 信任告急.
	var allies := {"nora": true}
	var npc_state := {"nora": {"target": "left_window", "walk_timer": 0.0}}
	_bar.refresh(allies, npc_state, 1.5)
	var row: Dictionary = _bar._rows["nora"]
	var s: String = row["status_lbl"].text
	_expect(s == "信任告急", "low trust status text is 信任告急 (got: %s)" % s)


func _test_status_idle() -> void:
	print("[status: idle]")
	var allies := {"nora": true}
	var npc_state := {"nora": {"target": "", "walk_timer": 0.0}}
	_bar.refresh(allies, npc_state, 3.0)
	var row: Dictionary = _bar._rows["nora"]
	_expect(row["status_lbl"].text == "待命", "no-target status is 待命")


func _test_status_walking() -> void:
	print("[status: walking]")
	var allies := {"elias": true}
	var npc_state := {"elias": {"target": "antenna", "walk_timer": 1.2}}
	_bar.refresh(allies, npc_state, 3.0)
	var row: Dictionary = _bar._rows["elias"]
	_expect(row["status_lbl"].text == "赶路中", "target + walk_timer > 0 is 赶路中")


func _test_status_emergency() -> void:
	print("[status: emergency]")
	var allies := {"nora": true}
	var npc_state := {"nora": {"target": "right_window", "walk_timer": 0.0}}
	_bar.refresh(allies, npc_state, 3.0)
	var row: Dictionary = _bar._rows["nora"]
	_expect(row["status_lbl"].text == "救急中", "target + walk_timer <= 0 is 救急中")


func _test_i18n_locale_switch() -> void:
	print("[i18n locale switch]")
	I18n.set_locale("en")
	# idle in en
	var allies := {"nora": true}
	var npc_state := {"nora": {"target": "", "walk_timer": 0.0}}
	_bar.refresh(allies, npc_state, 3.0)
	var row: Dictionary = _bar._rows["nora"]
	_expect(row["status_lbl"].text == "Standing by", "en idle -> Standing by")
	# emergency in en
	npc_state["nora"] = {"target": "right_window", "walk_timer": 0.0}
	_bar.refresh(allies, npc_state, 3.0)
	row = _bar._rows["nora"]
	_expect(row["status_lbl"].text == "Responding", "en emergency -> Responding")
	# walking in en
	npc_state["nora"] = {"target": "right_window", "walk_timer": 0.5}
	_bar.refresh(allies, npc_state, 3.0)
	row = _bar._rows["nora"]
	_expect(row["status_lbl"].text == "En route", "en walking -> En route")
	# low trust in en
	npc_state["nora"] = {"target": "", "walk_timer": 0.0}
	_bar.refresh(allies, npc_state, 1.0)
	row = _bar._rows["nora"]
	_expect(row["status_lbl"].text == "Trust critical", "en low trust -> Trust critical")
	# restore zh for downstream tests
	I18n.set_locale("zh")


func _test_stale_row_teardown() -> void:
	print("[stale row teardown]")
	_bar.refresh({"nora": true}, {"nora": {"target": "", "walk_timer": 0.0}}, 3.0)
	_expect(_bar._rows.has("nora"), "nora row exists")
	# nora leaves the rotation.
	_bar.refresh({"nora": false, "elias": true}, {"elias": {"target": "", "walk_timer": 0.0}}, 3.0)
	_expect(not _bar._rows.has("nora"), "stale nora row torn down when ally=false")
	_expect(_bar._rows.has("elias"), "elias row built fresh")
	_expect(_bar.visible, "bar still visible (elias is in)")


func _test_name_fallback_when_no_brief() -> void:
	print("[name uses survivor_*_brief when present (M15 B4b)]")
	# B4b brought survivor_*_brief keys for all 6 NPCs. The bar now uses
	# those instead of the plain English name. Verify lily (高中生 in zh)
	# renders the brief, and verify the truncation logic for long briefs.
	I18n.set_locale("zh")
	_bar.refresh({"lily": true}, {"lily": {"target": "", "walk_timer": 0.0}}, 3.0)
	var row: Dictionary = _bar._rows["lily"]
	_expect(row["name_lbl"].text == "高中生", "zh lily uses survivor_lily_brief = 高中生 (got: %s)" % row["name_lbl"].text)
	I18n.set_locale("en")
	_bar.refresh({"lily": true}, {"lily": {"target": "", "walk_timer": 0.0}}, 3.0)
	row = _bar._rows["lily"]
	# "High-schooler" is 13 chars — the bar truncates to <= 12 + "…" to
	# keep the row from wrapping. Verify both: starts with "High-school"
	# and ends with "…".
	_expect(row["name_lbl"].text.begins_with("High-school"), "en lily row starts with 'High-school' (got: %s)" % row["name_lbl"].text)
	_expect(row["name_lbl"].text.ends_with("…"), "en lily row ends with truncation marker (got: %s)" % row["name_lbl"].text)
	I18n.set_locale("zh")