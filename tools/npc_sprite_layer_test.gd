extends SceneTree
# NpcSpriteLayer unit test — polish spec §4.3 + §5.2.
#
# Headless test that drives the layer in isolation. We instantiate
# NpcSpriteLayer as a SceneTree child so the Sprite2D nodes it builds
# can run their _ready and texture swaps without a viewport.
#
# Coverage:
#   1. add_ally creates a Sprite2D under self with idle texture + position
#   2. add_ally is idempotent (re-add reuses the sprite)
#   3. refresh with movement > MOVE_EPSILON flips walking=true and swaps
#      the texture to a walk frame
#   4. refresh with no movement sets walking=false and restores the idle
#      texture
#   5. remove_ally tears down the Sprite2D and clears all dicts
#   6. self-bootstrap: refresh() with an npc_state that has an unknown
#      NPC id still adds the sprite (so direct npc_state writes work too)

const Layer := preload("res://scripts/NpcSpriteLayer.gd")

var _failed := 0
var _passed := 0
var _layer: Node2D


func _initialize() -> void:
	_layer = Layer.new()
	root.add_child(_layer)

	_test_add_ally_creates_sprite()
	_test_add_ally_idempotent()
	_test_refresh_movement_flips_walking()
	_test_refresh_no_movement_returns_idle()
	_test_remove_ally_teardown()
	_test_refresh_self_bootstraps_unknown_npc()
	_test_walk_frame_cycle_advances()

	print("")
	print("npc_sprite_layer_test: %d passed / %d failed" % [_passed, _failed])
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


func _test_add_ally_creates_sprite() -> void:
	print("[add_ally creates Sprite2D]")
	_layer.add_ally("nora", Vector2(800.0, 360.0))
	_expect(_layer.sprites.has("nora"), "sprites dict has 'nora' after add_ally")
	var s: Sprite2D = _layer.sprites["nora"]
	_expect(s != null, "sprite node is non-null")
	_expect(s.get_parent() == _layer, "sprite parented to the layer")
	_expect(s.position == Vector2(800.0, 360.0), "sprite placed at start_pos")
	_expect(s.texture == _layer.idle_textures.get("nora", null), "initial texture is idle portrait")
	_expect(s.texture != null, "idle texture loaded (character_nora.png on disk)")
	_expect(_layer.walking["nora"] == false, "walking flag starts false")
	_expect(_layer.facing["nora"] == "down", "default facing is down")


func _test_add_ally_idempotent() -> void:
	print("[add_ally idempotent]")
	# Re-add the same NPC at a new position. The existing sprite must be
	# reused (not duplicated) and its position updated.
	var prev_sprite: Sprite2D = _layer.sprites["nora"]
	_layer.add_ally("nora", Vector2(640.0, 240.0))
	_expect(_layer.sprites.has("nora"), "still one sprite for nora")
	_expect(_layer.sprites["nora"] == prev_sprite, "same sprite reused")
	_expect(prev_sprite.position == Vector2(640.0, 240.0), "position snapped to new start_pos")


func _test_refresh_movement_flips_walking() -> void:
	print("[refresh with movement flips walking + swaps frame]")
	# Seed npc_state at the sprite's current position so the first refresh
	# is the no-movement baseline.
	var baseline_pos: Vector2 = _layer.sprites["nora"].position
	var npc_state := {
		"nora": {
			"pos": baseline_pos,
			"target": "left_window",
			"walk_timer": 0.0,
		},
	}
	_layer.refresh(npc_state, 0.1)
	var idle_tex: Texture2D = _layer.idle_textures.get("nora", null)
	_expect(_layer.sprites["nora"].texture == idle_tex, "baseline tick: idle texture retained")
	_expect(_layer.walking["nora"] == false, "baseline tick: walking=false")
	# Now move npc_state 30 px to the right — well above MOVE_EPSILON.
	npc_state["nora"]["pos"] = baseline_pos + Vector2(30.0, 0.0)
	_layer.refresh(npc_state, 0.1)
	_expect(_layer.walking["nora"] == true, "movement tick: walking=true")
	_expect(_layer.sprites["nora"].texture != idle_tex, "movement tick: texture swapped off idle")
	_expect(_layer.sprites["nora"].position == baseline_pos + Vector2(30.0, 0.0), "sprite position syncs to npc_state")
	_expect(_layer.facing["nora"] == "right", "facing right for +dx dominant")


func _test_refresh_no_movement_returns_idle() -> void:
	print("[refresh no-movement returns idle]")
	# Sprite is currently at the moved position; refresh with the same
	# npc_state pos again — delta < MOVE_EPSILON so it should idle.
	var moved_pos: Vector2 = _layer.sprites["nora"].position
	var npc_state := {
		"nora": {
			"pos": moved_pos,
			"target": "",
			"walk_timer": 0.0,
		},
	}
	_layer.refresh(npc_state, 0.1)
	var idle_tex: Texture2D = _layer.idle_textures.get("nora", null)
	_expect(_layer.walking["nora"] == false, "no movement: walking=false")
	_expect(_layer.sprites["nora"].texture == idle_tex, "no movement: texture restored to idle")


func _test_remove_ally_teardown() -> void:
	print("[remove_ally clean teardown]")
	var s: Sprite2D = _layer.sprites["nora"]
	_layer.remove_ally("nora")
	_expect(not _layer.sprites.has("nora"), "sprites dict drops nora")
	_expect(not _layer.walking.has("nora"), "walking dict drops nora")
	_expect(not _layer.facing.has("nora"), "facing dict drops nora")
	_expect(not _layer.walk_frame_idx.has("nora"), "walk_frame_idx dict drops nora")
	_expect(not _layer.walk_timer.has("nora"), "walk_timer dict drops nora")
	_expect(s.is_queued_for_deletion() or s.get_parent() == null, "sprite node either queue_free'd or detached")


func _test_refresh_self_bootstraps_unknown_npc() -> void:
	print("[refresh self-bootstraps NPCs not in sprites yet]")
	# Direct npc_state write without a prior add_ally — refresh() should
	# auto-create the sprite so the AI tick never has stale state.
	var npc_state := {
		"elias": {
			"pos": Vector2(480.0, 360.0),
			"target": "",
			"walk_timer": 0.0,
		},
	}
	_expect(not _layer.sprites.has("elias"), "elias not yet in sprites")
	_layer.refresh(npc_state, 0.1)
	_expect(_layer.sprites.has("elias"), "elias auto-added by refresh")
	_expect(_layer.sprites["elias"].position == Vector2(480.0, 360.0), "elias sprite placed at npc_state pos")


func _test_walk_frame_cycle_advances() -> void:
	print("[walk frame cycle advances with delta]")
	# Set up a moving NPC from a clean baseline.
	_layer.add_ally("nora", Vector2(100.0, 100.0))
	var npc_state := {
		"nora": {
			"pos": Vector2(100.0, 100.0),
			"target": "right_window",
			"walk_timer": 0.0,
		},
	}
	_layer.refresh(npc_state, 0.1)  # baseline (idle, sprite at 100,100)
	# First movement tick: jump 30 px right, well above MOVE_EPSILON.
	# This should flip walking=true and snap frame index to 0.
	npc_state["nora"]["pos"] = Vector2(130.0, 100.0)
	_layer.refresh(npc_state, 0.1)
	var frame_after_one: int = int(_layer.walk_frame_idx["nora"])
	_expect(_layer.walking["nora"] == true, "walking=true on first movement refresh")
	# Second movement tick: jump another 30 px right. Sprite was at 130,100
	# so delta_v = (30,0) again — still walking=true and walk_timer
	# accumulates 0.10 + 0.10 = 0.20s, which crosses WALK_FRAME_PERIOD
	# (0.15) once, so walk_frame_idx advances to 1.
	npc_state["nora"]["pos"] = Vector2(160.0, 100.0)
	_layer.refresh(npc_state, 0.1)
	var frame_after_two: int = int(_layer.walk_frame_idx["nora"])
	_expect(_layer.walking["nora"] == true, "still walking on continued movement")
	_expect(frame_after_two >= 0 and frame_after_two < 12, "frame idx stays in [0, 12) range")
	_expect(frame_after_two != frame_after_one or frame_after_two > 0, "walk_frame_idx advanced (or already past 0) after > 0.15s of movement")
	# Hold the position: refresh with no movement. NPC should drop back
	# to idle pose and walk_frame_idx should reset to 0.
	_layer.refresh(npc_state, 0.1)
	_expect(_layer.walking["nora"] == false, "back to idle when NPC stops moving")
	_expect(int(_layer.walk_frame_idx["nora"]) == 0, "frame idx resets to 0 on idle")