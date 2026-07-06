extends SceneTree
# Narrative ally-diff integration test — M15 polish B4b.
#
# Headless test that exercises NightShiftGame._format_narrative_allies_diff
# directly. Verifies:
#   1. Per-NPC join keys (log_ally_join_<id>) take priority over the generic
#      `log_ally_join` template when present
#   2. Per-NPC left keys (log_ally_left_<id>) take priority over "{name} 离开"
#   3. Per-NPC lost keys (log_ally_lost_<id>) are routed to the lost bucket,
#      not the left bucket
#   4. Unknown NPC ids fall back to the generic templates cleanly
#   5. zh and en both resolve correctly (locale switch works)
#   6. Survivor brief keys exist for all 6 NPCs (parity guard for §7.7)
#   7. log_victor_lost key exists and resolves
#   8. NightReport._format_narrative_allies_diff_local mirrors the same
#      per-NPC preference (it's a duplicate copy in the BaseScreen world
#      so it can't drift)

const I18n := preload("res://scripts/I18n.gd")

var _failed := 0
var _passed := 0


func _initialize() -> void:
	I18n.load_locale("zh")
	I18n.set_locale("zh")

	_test_per_npc_join_preferred()
	_test_per_npc_left_preferred()
	_test_per_npc_lost_routed_to_lost_bucket()
	_test_unknown_npc_falls_back_to_generic()
	_test_en_locale_per_npc_join()
	_test_survivor_brief_keys_present_for_all_6_npcs()
	_test_victor_lost_key_present()
	_test_night_report_mirror_per_npc_join()

	print("")
	print("narrative_diff_test: %d passed / %d failed" % [_passed, _failed])
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


# We exercise the private functions by instantiating a minimal NightShiftGame
# surface. Easier: replicate the function logic in this test by calling the
# helpers we ship — but that's brittle. Instead, we instantiate the scene,
# drive `_format_narrative_allies_diff` directly.
func _game() -> Node:
	var Packed := load("res://scenes/NightShiftGame.tscn") as PackedScene
	if Packed == null:
		return null
	var game: Node = Packed.instantiate()
	root.add_child(game)
	return game


# --- tests ---


func _test_per_npc_join_preferred() -> void:
	print("[per-NPC join preferred]")
	var game: Node = _game()
	if game == null:
		_expect(false, "scene loads")
		return
	# Snapshot prev = empty allies. cur = nora joined.
	var prev := {"nora": false, "elias": false, "victor": false}
	var cur := {"nora": true, "elias": false, "victor": false}
	var line: String = game.call("_format_narrative_allies_diff", prev, cur)
	_expect(line.contains("Nora 从城市废墟里赶来"), "zh per-NPC join line contains full sentence (got: %s)" % line)
	_expect(line.contains("加入"), "zh line still has 加入 label prefix (got: %s)" % line)
	game.queue_free()


func _test_per_npc_left_preferred() -> void:
	print("[per-NPC left preferred]")
	var game: Node = _game()
	if game == null:
		_expect(false, "scene loads")
		return
	# Daniel leaves (per-NPC log_ally_left_daniel exists).
	var prev := {"nora": true, "daniel": true}
	var cur := {"nora": true, "daniel": false}
	var line: String = game.call("_format_narrative_allies_diff", prev, cur)
	_expect(line.contains("Daniel 走了"), "zh per-NPC left line uses Daniel 走了 (got: %s)" % line)
	game.queue_free()


func _test_per_npc_lost_routed_to_lost_bucket() -> void:
	print("[per-NPC lost routed to lost bucket]")
	var game: Node = _game()
	if game == null:
		_expect(false, "scene loads")
		return
	# Tom lost — log_ally_lost_tom should route to lost bucket, prefixed with 牺牲.
	var prev := {"tom": true}
	var cur := {"tom": false}
	var line: String = game.call("_format_narrative_allies_diff", prev, cur)
	_expect(line.contains("Tom 没回来"), "zh per-NPC lost line uses Tom 没回来 (got: %s)" % line)
	_expect(line.contains("牺牲"), "zh lost line uses 牺牲 label prefix (got: %s)" % line)
	game.queue_free()


func _test_unknown_npc_falls_back_to_generic() -> void:
	print("[unknown npc falls back to generic]")
	var game: Node = _game()
	if game == null:
		_expect(false, "scene loads")
		return
	# 'mystery' is not in the per-NPC key set — should fall back to generic.
	var prev := {"mystery": false}
	var cur := {"mystery": true}
	var line: String = game.call("_format_narrative_allies_diff", prev, cur)
	_expect(line.contains("mystery 加入"), "unknown npc falls back to generic {name} 加入 (got: %s)" % line)
	game.queue_free()


func _test_en_locale_per_npc_join() -> void:
	print("[en locale: per-NPC join resolves]")
	I18n.set_locale("en")
	var game: Node = _game()
	if game == null:
		_expect(false, "scene loads")
		I18n.set_locale("zh")
		return
	var prev := {"nora": false}
	var cur := {"nora": true}
	var line: String = game.call("_format_narrative_allies_diff", prev, cur)
	_expect(line.contains("Nora arrived from the city ruins"), "en per-NPC join line uses full sentence (got: %s)" % line)
	game.queue_free()
	I18n.set_locale("zh")


func _test_survivor_brief_keys_present_for_all_6_npcs() -> void:
	print("[survivor_brief keys present for all 6 NPCs]")
	# §7.7 contract: survivor_<id>_brief for nora, elias, lily, tom, daniel, victor.
	for npc_id in ["nora", "elias", "lily", "tom", "daniel", "victor"]:
		var k := "survivor_%s_brief" % npc_id
		var zh: String = I18n.t(k)
		var en: String = I18n.t(k) if I18n.locale == "en" else ""
		_expect(zh != k, "zh has survivor_%s_brief (got: %s)" % [npc_id, zh])
	I18n.set_locale("en")
	for npc_id in ["nora", "elias", "lily", "tom", "daniel", "victor"]:
		var k := "survivor_%s_brief" % npc_id
		var en: String = I18n.t(k)
		_expect(en != k, "en has survivor_%s_brief (got: %s)" % [npc_id, en])
	I18n.set_locale("zh")


func _test_victor_lost_key_present() -> void:
	print("[log_victor_lost key present]")
	# §7.6 contract: log_victor_lost for the synthetic event in night 9.
	I18n.set_locale("zh")
	var zh: String = I18n.t("log_victor_lost")
	_expect(zh != "log_victor_lost" and zh.contains("Victor"), "zh log_victor_lost resolves (got: %s)" % zh)
	I18n.set_locale("en")
	var en: String = I18n.t("log_victor_lost")
	_expect(en != "log_victor_lost" and en.contains("Victor"), "en log_victor_lost resolves (got: %s)" % en)
	I18n.set_locale("zh")


func _test_night_report_mirror_per_npc_join() -> void:
	print("[NightReport mirror uses per-NPC join]")
	# NightReport._format_narrative_allies_diff_local is a duplicate copy
	# living in BaseScreen's world — verify it doesn't drift from the
	# NightShiftGame version.
	I18n.set_locale("zh")
	var report_script: Script = load("res://scripts/NightReport.gd") as Script
	if report_script == null:
		_expect(false, "NightReport script loads")
		return
	var report = report_script.new()
	var prev := {"nora": false}
	var cur := {"nora": true}
	var line: String = report.call("_format_narrative_allies_diff_local", prev, cur)
	_expect(line.contains("Nora 从城市废墟里赶来"), "NightReport mirror uses per-NPC join (got: %s)" % line)