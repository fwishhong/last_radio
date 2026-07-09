extends SceneTree
# NpcSpriteLayer canvas z-order test — polish spec §5.2.
#
# Mounts the real NightShiftGame scene, walks the canvas children list,
# and asserts the NpcSpriteLayer child index is AFTER enemy_layer and
# BEFORE zombie_outside_layer. This enforces the draw-order rule:
#
#   enemy_layer (procedural zombie circles)
#     < npc_sprite_layer (NPC field sprites)
#       < zombie_outside_layer (window/door breach sprites)
#
# Why this matters: zombie procedural circles would obscure NPC figures
# if NPC drew first; zombie_outside_layer would be obscured by NPC if
# the NPC drew after it. Order must be exactly as above.

const I18n := preload("res://scripts/I18n.gd")

var _failed := 0
var _passed := 0


func _initialize() -> void:
	I18n.load_locale("zh")
	_run.call_deferred()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	if scene == null:
		print("FAIL: scene load")
		quit(1)
		return
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame

	# Layer handles must all be non-null. If any is missing, the wiring is
	# broken at a more fundamental level than the z-order question.
	var canvas: CanvasLayer = game.get("canvas")
	var enemy_layer: Node = game.get("enemy_layer")
	var npc_sprite_layer: Node = game.get("npc_sprite_layer")
	var zombie_outside_layer: Node = game.get("zombie_outside_layer")
	_expect(canvas != null, "canvas handle exists")
	_expect(enemy_layer != null, "enemy_layer handle exists")
	_expect(npc_sprite_layer != null, "npc_sprite_layer handle exists")
	_expect(zombie_outside_layer != null, "zombie_outside_layer handle exists")
	if canvas == null or enemy_layer == null or npc_sprite_layer == null or zombie_outside_layer == null:
		print("FAIL: one or more layers missing")
		quit(1)
		return

	# All three layers must be children of canvas — z-order is the canvas
	# child index, not z_index (z_index is uniform across the trio).
	var layers_in_canvas: Array = []
	for child in canvas.get_children():
		layers_in_canvas.append(child)
	var enemy_idx: int = layers_in_canvas.find(enemy_layer)
	var npc_idx: int = layers_in_canvas.find(npc_sprite_layer)
	var zombie_idx: int = layers_in_canvas.find(zombie_outside_layer)
	_expect(enemy_idx >= 0, "enemy_layer is a child of canvas (idx=%d)" % enemy_idx)
	_expect(npc_idx >= 0, "npc_sprite_layer is a child of canvas (idx=%d)" % npc_idx)
	_expect(zombie_idx >= 0, "zombie_outside_layer is a child of canvas (idx=%d)" % zombie_idx)

	# The actual z-order rule under test.
	_expect(enemy_idx < npc_idx, "enemy_layer comes BEFORE npc_sprite_layer (enemy=%d < npc=%d)" % [enemy_idx, npc_idx])
	_expect(npc_idx < zombie_idx, "npc_sprite_layer comes BEFORE zombie_outside_layer (npc=%d < zombie=%d)" % [npc_idx, zombie_idx])

	# Defensive: stable canvas child count — we don't want this test to
	# silently lose meaning if some future change drops the NPC layer out
	# of the canvas entirely.
	var canvas_child_count: int = canvas.get_child_count()
	_expect(canvas_child_count >= 3, "canvas has at least 3 children (got %d)" % canvas_child_count)

	# z_index check: enemy_layer default 0, npc_sprite_layer 2, zombie_outside_layer 3
	# (z_index doesn't control the order since all three are siblings, but
	# the polish spec assigns explicit z_index values to make the intent
	# visible in the scene tree.)
	_expect(int(npc_sprite_layer.z_index) == 2, "npc_sprite_layer.z_index == 2 (got %d)" % int(npc_sprite_layer.z_index))
	_expect(int(zombie_outside_layer.z_index) == 3, "zombie_outside_layer.z_index == 3 (got %d)" % int(zombie_outside_layer.z_index))

	print("")
	print("npc_sprite_layer_order_test: %d passed / %d failed" % [_passed, _failed])
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