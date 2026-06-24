extends SceneTree
# Repro smoke #2 — uses actual button signal emission, mirrors the real click path.
# Catches issues that direct method calls miss (e.g. signal handler ordering,
# double-fire, etc).

const Save := preload("res://scripts/NightShiftSave.gd")
var game: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Save.clear_save()
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	print("[ready] phase=", game.phase)

	# Path 1: programmatic click on slot 1
	game._on_slot_new_pressed(1)
	await process_frame
	print("[slot_new] phase=", game.phase, " card_layer_children=", game.card_layer.get_child_count())

	# Inspect the difficulty picker UI: find the "standard" preset chip and emit pressed
	var chips: Dictionary = game.get("_dx_preset_chip_handles") as Dictionary
	print("[picker] chips=", chips.keys())
	var standard_chip: Button = chips.get("standard") as Button
	if standard_chip == null:
		print("FAIL: no standard chip")
		quit(1)
		return

	# Emit the actual pressed signal (mimics a real mouse click)
	standard_chip.pressed.emit()
	await process_frame
	print("[after preset click via signal] phase=", game.phase)
	print("[after preset click] current_difficulty=", game.current_difficulty, " mods=", game.difficulty_modifiers)

	# Find the Confirm button and emit pressed
	var confirm_btn: Button = null
	for child in game.card_layer.get_children():
		if child is Button and child.text.contains("选择"):
			confirm_btn = child
			break
	if confirm_btn == null:
		print("FAIL: no confirm button")
		quit(1)
		return
	print("[found confirm] text=", confirm_btn.text)
	confirm_btn.pressed.emit()
	await process_frame
	await process_frame
	print("[after confirm click via signal] phase=", game.phase)
	quit(0)
