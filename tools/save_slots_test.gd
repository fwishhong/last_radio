extends SceneTree
# Tests for the multi-slot save system in NightShiftSave.

const Save := preload("res://scripts/NightShiftSave.gd")

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
	print("=== Save slots test ===")

	# 1) Start clean
	Save.clear_all_slots()
	_assert(not Save.has_any_slot(), "all slots clear at start")

	# 2) has_save() is the legacy alias of has_any_slot()
	_assert(not Save.has_save(), "has_save() mirrors has_any_slot()")

	# 3) Write to slot 1
	var ok: bool = Save.write({
		"night_index": 0,
		"resources": {"planks": 4},
		"tutorial_done": false,
		"difficulty": Save.DIFFICULTY_NORMAL,
	}, 1)
	_assert(ok, "write slot 1 returns true")
	_assert(Save.has_slot(1), "has_slot(1) is true")
	_assert(not Save.has_slot(2), "has_slot(2) is false")
	_assert(Save.has_save(), "has_save() now true")

	# 4) Read slot 1
	var doc: Dictionary = Save.read(1)
	_assert(doc.get("night_index", -1) == 0, "slot 1 night_index = 0")
	_assert(int(doc.get("resources", {}).get("planks", -1)) == 4, "slot 1 planks = 4")
	_assert(int(doc.get("difficulty", -1)) == Save.DIFFICULTY_NORMAL, "slot 1 difficulty normal")

	# 5) Slot summary
	var summary: Dictionary = Save.slot_summary(1)
	_assert(summary.exists, "slot 1 summary.exists")
	_assert(summary.night_index == 0, "slot 1 summary.night_index = 0")
	_assert(summary.difficulty == Save.DIFFICULTY_NORMAL, "slot 1 summary.difficulty normal")

	# 6) Empty slot summary
	var empty: Dictionary = Save.slot_summary(2)
	_assert(not empty.exists, "slot 2 summary doesn't exist")

	# 7) Write to slot 2 with hard difficulty
	Save.write({
		"night_index": 4,
		"tutorial_done": true,
		"difficulty": Save.DIFFICULTY_HARD,
	}, 2)
	var doc2: Dictionary = Save.read(2)
	_assert(doc2.get("tutorial_done", false), "slot 2 tutorial_done")
	_assert(int(doc2.get("difficulty", -1)) == Save.DIFFICULTY_HARD, "slot 2 hard difficulty")

	# 8) Clear single slot
	Save.clear_slot(1)
	_assert(not Save.has_slot(1), "slot 1 cleared")
	_assert(Save.has_slot(2), "slot 2 still present")
	_assert(Save.has_save(), "still has save (slot 2)")

	# 9) Reject invalid slot numbers
	_assert(not Save.has_slot(0), "has_slot(0) is false")
	_assert(not Save.has_slot(4), "has_slot(4) is false (only 3 slots)")
	_assert(not Save.write({}, 0), "write to slot 0 returns false")
	_assert(not Save.write({}, 4), "write to slot 4 returns false")

	# 10) Clear all
	Save.clear_all_slots()
	_assert(not Save.has_any_slot(), "all slots cleared at end")

	# 11) Constants
	_assert(Save.SLOT_COUNT == 3, "SLOT_COUNT is 3")
	_assert(Save.DIFFICULTY_NORMAL == 0, "DIFFICULTY_NORMAL is 0")
	_assert(Save.DIFFICULTY_HARD == 1, "DIFFICULTY_HARD is 1")

	# 12) Migration: writing a v2-shape file under LEGACY path then calling
	# migrate_legacy_if_needed moves it to slot 1
	# We need to write a v2 JSON directly. Use FileAccess to do this.
	var dir := "user://saves"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var legacy_path := dir + "/last_radio_chapter_01.json"
	var f := FileAccess.open(legacy_path, FileAccess.WRITE)
	f.store_string('{"version": 2, "night_index": 2, "resources": {"planks": 3}, "allies": {"nora": true}}')
	f.close()
	# Slot 1 should be empty at this point
	_assert(not Save.has_slot(1), "slot 1 empty before migration")
	Save.migrate_legacy_if_needed()
	_assert(Save.has_slot(1), "migration moves v2 save into slot 1")
	var migrated: Dictionary = Save.read(1)
	_assert(migrated.get("night_index", -1) == 2, "migrated night_index = 2")
	_assert(int(migrated.get("resources", {}).get("planks", -1)) == 3, "migrated planks = 3")
	_assert(migrated.get("tutorial_done", true) == false, "migrated tutorial_done = false (default)")
	_assert(int(migrated.get("difficulty", -1)) == Save.DIFFICULTY_NORMAL, "migrated difficulty = NORMAL")
	_assert(not FileAccess.file_exists(legacy_path), "legacy file removed after migration")

	# Cleanup
	Save.clear_all_slots()

	print("Save slots test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])