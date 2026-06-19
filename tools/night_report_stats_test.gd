extends SceneTree
# Verifies that the night_report screen shows stats for both success and failure.
# Failure should expose: 坚持时间 / 修复时长 / 失守次数 / 首失 / 事件触发 /
# 敌人撤离 / 电台接通 / 资源. Success should show the same plus 解锁 list.

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
	print("=== Night-report stats test ===")
	Save.clear_save()

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame

	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	_assert(game.phase == "night", "entered night 1")

	# --- Failure path ---------------------------------------------------
	# Force a front_door breach so we can verify stats display.
	var front: Dictionary = game.hotspots["front_door"]
	front["assault"] = true
	front["value"] = 0.0
	game.hotspots["front_door"] = front
	game.night_elapsed = 7.5
	# Step the night loop past the breach grace (1.5s) to reach night_report.
	for i in range(20):
		if game.phase == "night_report":
			break
		game.call("_update_night", 0.1)
	_assert(game.phase == "night_report", "failure path reaches night_report via breach grace")

	var fail_log: String = game.log_label.text
	_assert(fail_log.find("数据") >= 0, "failure report has stats header")
	_assert(fail_log.find("坚持时间") >= 0, "failure report shows elapsed time")
	_assert(fail_log.find("修复时长") >= 0, "failure report shows repair duration")
	_assert(fail_log.find("失守次数") >= 0, "failure report shows breach count")
	_assert(fail_log.find("正门") >= 0, "failure report names front_door as first breach")
	_assert(fail_log.find("事件触发") >= 0, "failure report shows event count")
	_assert(fail_log.find("电台接通") >= 0, "failure report shows radio contacts")
	_assert(fail_log.find("资源") >= 0, "failure report shows resource snapshot")
	# Resource entries should include the baseline set.
	for token in ["木板", "零件", "电池", "药品", "暴露度", "信任"]:
		_assert(fail_log.find(token) >= 0, "failure report includes resource: %s" % token)
	# Failure should NOT include "解锁" since nothing was unlocked.
	_assert(fail_log.find("解锁") < 0, "failure report omits unlocks")

	# Confirm the breaches counter actually incremented.
	_assert(int(game.night_stats.get("breaches", 0)) >= 1, "night_stats.breaches counted")
	_assert(str(game.night_stats.get("breaches_first_id", "")) == "front_door", "breaches_first_id recorded")

	# --- Success path ---------------------------------------------------
	game.call("_on_report_continue", false)  # retry same night
	_assert(game.phase == "night", "retry puts us back into night")
	# Reset stats and patch a safe state.
	game.night_stats = {
		"radio_contacts": 2, "enemies_despawned": 3, "hotfixes": 12.4,
		"breaches": 0, "breaches_first_id": "", "events_fired": 5,
	}
	game.night_elapsed = game.night_duration - 0.1
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		h["value"] = h["max_value"]
		h["breach_timer"] = -1.0
		h["assault"] = false
		h["warning"] = false
		game.hotspots[id] = h
	game.call("_end_night", true)
	_assert(game.phase == "night_report", "success path reaches night_report")

	var ok_log: String = game.log_label.text
	_assert(ok_log.find("数据") >= 0, "success report has stats header")
	_assert(ok_log.find("电台接通") >= 0, "success report shows radio contacts")
	_assert(ok_log.find("失守次数") >= 0, "success report shows breach count (zero OK)")
	_assert(ok_log.find("解锁") >= 0, "success report shows unlocks list")
	# night 1's success_unlocks: ["nora", "right_window"]
	_assert(ok_log.find("Nora") >= 0, "success report names Nora joining")
	_assert(ok_log.find("右窗") >= 0, "success report names right_window unlocking")

	print("Night-report stats test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])