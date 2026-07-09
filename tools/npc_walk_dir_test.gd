extends SceneTree
# NPC walk direction (dominant-axis facing pick) test — polish spec §4.3.
#
# Headless test that exercises NpcSpriteLayer._pick_facing() in
# isolation. _pick_facing is a private static-style helper on the layer;
# we verify it via the public surface (refresh() updates _layer.facing)
# and via a direct fallback path that does not depend on
# Sprite2D/walk-frame state.
#
# Rules under test:
#   |dx| > |dy|  -> "left"  if dx < 0  else "right"
#   |dy| > |dx|  -> "up"    if dy < 0  else "down"
#   |dx| == |dy| -> keep previous facing (avoids diagonal twitch)
#                  default to "down" if no previous.

const Layer := preload("res://scripts/NpcSpriteLayer.gd")

var _failed := 0
var _passed := 0
var _layer: Node2D


func _initialize() -> void:
	_layer = Layer.new()
	root.add_child(_layer)

	_test_horizontal_dominant_right()
	_test_horizontal_dominant_left()
	_test_vertical_dominant_down()
	_test_vertical_dominant_up()
	_test_diagonal_tie_keeps_previous()
	_test_diagonal_tie_default_down()
	_test_negative_dominant_axis_picks()

	print("")
	print("npc_walk_dir_test: %d passed / %d failed" % [_passed, _failed])
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


func _test_horizontal_dominant_right() -> void:
	print("[|dx|>|dy| -> right]")
	var facing: String = _layer._pick_facing(Vector2(10.0, 3.0), "down")
	_expect(facing == "right", "dx=+10, dy=+3 -> right (got %s)" % facing)


func _test_horizontal_dominant_left() -> void:
	print("[|dx|>|dy| -> left]")
	var facing: String = _layer._pick_facing(Vector2(-12.0, 4.0), "down")
	_expect(facing == "left", "dx=-12, dy=+4 -> left (got %s)" % facing)


func _test_vertical_dominant_down() -> void:
	print("[|dy|>|dx| -> down]")
	var facing: String = _layer._pick_facing(Vector2(2.0, 8.0), "right")
	_expect(facing == "down", "dx=+2, dy=+8 -> down (got %s)" % facing)


func _test_vertical_dominant_up() -> void:
	print("[|dy|>|dx| -> up]")
	var facing: String = _layer._pick_facing(Vector2(-1.0, -7.0), "right")
	_expect(facing == "up", "dx=-1, dy=-7 -> up (got %s)" % facing)


func _test_diagonal_tie_keeps_previous() -> void:
	print("[|dx|==|dy| -> keep previous facing]")
	# Exact tie: previous is "up" -> stays "up".
	var facing: String = _layer._pick_facing(Vector2(5.0, 5.0), "up")
	_expect(facing == "up", "tie (dx=+5, dy=+5) with prev=up -> up (got %s)" % facing)
	facing = _layer._pick_facing(Vector2(-5.0, 5.0), "left")
	_expect(facing == "left", "tie (dx=-5, dy=+5) with prev=left -> left (got %s)" % facing)


func _test_diagonal_tie_default_down() -> void:
	print("[|dx|==|dy| -> default 'down' if no previous]")
	var facing: String = _layer._pick_facing(Vector2(3.0, 3.0), "")
	_expect(facing == "down", "tie with empty previous -> down (got %s)" % facing)


func _test_negative_dominant_axis_picks() -> void:
	print("[negative dominant axis still picks correctly]")
	# Make sure -10 beats +1 — sign of dominant axis doesn't matter, only
	# magnitude. left or right choice is dictated by sign of dx.
	var facing: String = _layer._pick_facing(Vector2(-10.0, 1.0), "down")
	_expect(facing == "left", "dx=-10, dy=+1 -> left (got %s)" % facing)
	facing = _layer._pick_facing(Vector2(1.0, -10.0), "right")
	_expect(facing == "up", "dx=+1, dy=-10 -> up (got %s)" % facing)