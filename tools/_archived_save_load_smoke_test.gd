extends SceneTree
# ARCHIVED — referenced NightShiftSave.save() and has_save(arg) which no
# longer exist. Replaced by tools/save_test.gd (the current round-trip test).

func _initialize() -> void:
	print("SKIP: _archived_save_load_smoke_test.gd — superseded by save_test.gd")
	quit(0)