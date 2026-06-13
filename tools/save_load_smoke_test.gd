extends SceneTree
const NightShiftSave = preload("res://scripts/NightShiftSave.gd")
var failed := false
func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	_expect(scene != null, "NightShiftGame scene loads")
	if scene == null:
		quit(1)
		return
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	_expect(game.call("_debug_start_campaign"), "starts campaign")
	_expect(game.call("_debug_choose_day", "start"), "starts first night")
	_expect(str(game.get("phase")) == "night", "enters night phase")
	_expect(NightShiftSave.save(game, 0), "save slot 0 succeeds")
	_expect(NightShiftSave.has_save(0), "save slot 0 exists")
	_expect(not NightShiftSave.has_save(99), "empty slot 99 not found")
	_expect(NightShiftSave.load(game, 0), "load slot 0 succeeds")
	NightShiftSave.delete_save(99)
	_expect(not NightShiftSave.has_save(99), "deleted slot verified")
	if failed:
		quit(1)
		return
	print("Last Radio save/load smoke test: PASS")
	quit(0)
func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Save/Load smoke test: FAIL - %s" % message)
