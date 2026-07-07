extends SceneTree
# tools/capture_visual_audit.gd
# Visual regression audit for the M15 polish demo pass.
#
# Asserts three visual contracts that pre-fix dev sessions silently violated:
#
#   Audit 1  Slot picker (cover screen) MUST hide player_token / hammer_sprite
#           / player_repair_token. Otherwise the walk sprite bleeds through
#           the seam between slot cards.
#
#   Audit 2  While the repair-action animation is firing (player_repair_active
#           == true) the walk sprite MUST be hidden. Otherwise the player
#           body sits inside the hammer token and the "swing" reads as a
#           duplicated sprite rather than a single committed strike.
#
#   Audit 3  PlayerRepairFx.is_repairable_hotspot MUST accept
#           barrier / generator / antenna / storage. Round 2 conservatively
#           scoped hammer to barrier only, which left generator / antenna /
#           storage looking broken (no repair feedback at all).
#
# Run:
#   godot --headless --path . --script res://tools/capture_visual_audit.gd
#
# Returns exit 0 on PASS, 1 on any FAIL. Wired into tools/build_release.ps1
# in step 2.5 so demo / release builds abort on visual regressions.

const NightShiftGame := preload("res://scripts/NightShiftGame.gd")
const NightShiftSave := preload("res://scripts/NightShiftSave.gd")
const I18n := preload("res://scripts/I18n.gd")
const PlayerRepairFx := preload("res://scripts/PlayerRepairFx.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	I18n.load_all()
	I18n.locale = "zh"
	NightShiftSave.clear_save()

	# GDScript 4 quirk: a function that awaits inner coroutines must itself
	# `await` them at every call site, otherwise the inner awaits are
	# skipped and the function returns synchronously. _initialize is the
	# SceneTree entry point but it can still `await` -- Godot keeps the
	# process alive until the coroutine resolves.
	await _audit_1_slot_picker_hides_player()
	await _audit_2_repair_action_hides_walk_sprite()
	await _audit_3_repairable_kinds_include_extended_set()

	print("")
	print("[capture_visual_audit] %d passed / %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _expect(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _new_game() -> Node:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game: Node = scene.instantiate()
	root.add_child(game)
	return game


func _settle_game() -> void:
	# Let _ready run + the cover screen build itself.
	await process_frame
	await process_frame


func _dispose_game(game: Node) -> void:
	root.remove_child(game)
	game.queue_free()
	await process_frame


func _enter_night_from_cover(game: Node) -> void:
	# Slot 1 -> standard difficulty -> straight to day. Bypasses the day
	# picker so we land in _show_night() quickly.
	game.call("_on_slot_new_pressed", 1)
	await process_frame
	game.call("_on_difficulty_chosen", NightShiftSave.DIFFICULTY_NORMAL)
	await process_frame
	game.call("_show_night")
	await process_frame


# ----------------------------------------------------------------------------
# Audit 1: slot picker must hide player / hammer / repair-token
# ----------------------------------------------------------------------------
func _audit_1_slot_picker_hides_player() -> void:
	print("")
	print("[audit 1: slot picker hides player / hammer / repair-token]")
	var game: Node = _new_game()
	await _settle_game()

	# Slot picker is the default cover screen, but be explicit so the audit
	# is robust against future _ready reordering.
	game.call("_show_slot_picker")
	await process_frame
	await process_frame

	var player_token = game.get("player_token")
	var hammer_sprite = game.get("hammer_sprite")
	var player_repair_token = game.get("player_repair_token")

	_expect(player_token != null, "player_token node exists")
	_expect(hammer_sprite != null, "hammer_sprite node exists")
	_expect(player_repair_token != null, "player_repair_token node exists")

	if player_token != null:
		_expect(
			bool(player_token.visible) == false,
			"player_token hidden on slot picker (got visible=%s)" % str(player_token.visible)
		)
	if hammer_sprite != null:
		_expect(
			bool(hammer_sprite.visible) == false,
			"hammer_sprite hidden on slot picker (got visible=%s)" % str(hammer_sprite.visible)
		)
	if player_repair_token != null:
		_expect(
			bool(player_repair_token.visible) == false,
			"player_repair_token hidden on slot picker (got visible=%s)" % str(player_repair_token.visible)
		)

	# Bonus: also exercise the _show_cover_with_continue path (same hide
	# semantics). Continue hint adds nothing to the assertion set, but
	# exercising both entry points catches "fix applied in only one place".
	game.call("_show_cover_with_continue")
	await process_frame
	if player_token != null:
		_expect(
			bool(player_token.visible) == false,
			"player_token hidden on cover_with_continue (got visible=%s)" % str(player_token.visible)
		)

	await _dispose_game(game)


# ----------------------------------------------------------------------------
# Audit 2: repair-action animation must hide the walk sprite
# ----------------------------------------------------------------------------
func _audit_2_repair_action_hides_walk_sprite() -> void:
	print("")
	print("[audit 2: repair-action animation hides walk sprite]")
	var game: Node = _new_game()
	await _settle_game()
	await _enter_night_from_cover(game)

	# Position player on top of the front_door hotspot and signal target.
	var hotspot_positions: Dictionary = game.get("HOTSPOT_POSITIONS")
	var front_door_pos: Vector2 = hotspot_positions["front_door"]
	game.set("player_pos", front_door_pos)
	game.set("player_target_id", "front_door")
	game.set("player_at_target", true)
	game.set("player_repair_active", false)
	game.set("player_repair_timer", 0.0)

	# One repair tick triggers the hammer cycle.
	game.call("_update_hotspots", 0.1)
	await process_frame
	# _draw_player runs in the next render pass; call it explicitly so the
	# assertion fires even if the test runs without a real render tick.
	if game.has_method("_draw_player"):
		game.call("_draw_player")

	var active: bool = bool(game.get("player_repair_active"))
	_expect(active == true, "player_repair_active set after repairing front_door (got %s)" % str(active))

	var player_token = game.get("player_token")
	if player_token != null:
		_expect(
			bool(player_token.visible) == false,
			"player_token hidden during repair-action (got visible=%s)" % str(player_token.visible)
		)

	# One of hammer_sprite or player_repair_token must be visible -- the
	# repair visual is non-empty.
	var hammer_sprite = game.get("hammer_sprite")
	var player_repair_token = game.get("player_repair_token")
	var hammer_visible: bool = hammer_sprite != null and bool(hammer_sprite.visible)
	var token_visible: bool = player_repair_token != null and bool(player_repair_token.visible)
	_expect(
		hammer_visible or token_visible,
		"either hammer_sprite or player_repair_token visible during repair (hammer=%s token=%s)"
			% [str(hammer_visible), str(token_visible)]
	)

	# When the player walks off the hotspot, repair must deactivate and the
	# walk sprite must return. Simulate by clearing player_at_target.
	game.set("player_at_target", false)
	game.set("player_target_id", "")
	game.call("_update_hotspots", 0.1)
	if game.has_method("_draw_player"):
		game.call("_draw_player")

	var active_after: bool = bool(game.get("player_repair_active"))
	_expect(active_after == false, "player_repair_active cleared when player leaves hotspot (got %s)" % str(active_after))
	if player_token != null:
		_expect(
			bool(player_token.visible) == true,
			"player_token visible again after repair ends (got visible=%s)" % str(player_token.visible)
		)

	await _dispose_game(game)


# ----------------------------------------------------------------------------
# Audit 3: repairable hotspot kinds must include the extended set
# ----------------------------------------------------------------------------
func _audit_3_repairable_kinds_include_extended_set() -> void:
	print("")
	print("[audit 3: repairable hotspot kinds include barrier / generator / antenna / storage]")

	# Static check: PlayerRepairFx.is_repairable_hotspot is the single source
	# of truth for which hotspot kinds get the hammer cycle. Drive it
	# directly so the audit covers all 4 kinds even on nights where some
	# hotspots aren't unlocked yet.
	var extended_kinds: Array[String] = ["barrier", "generator", "antenna", "storage"]
	for kind in extended_kinds:
		_expect(
			PlayerRepairFx.is_repairable_hotspot(kind) == true,
			"PlayerRepairFx.is_repairable_hotspot('%s') returns true" % kind
		)

	# Regression guard: radio and medbay keep their own interaction flows
	# (radio tuning dial, medbay nurse). They must NOT take the hammer cycle
	# even with the broadened allowlist.
	var excluded_kinds: Array[String] = ["radio", "medbay"]
	for kind in excluded_kinds:
		_expect(
			PlayerRepairFx.is_repairable_hotspot(kind) == false,
			"PlayerRepairFx.is_repairable_hotspot('%s') stays false (own flow)" % kind
		)

	# Real-gameplay check: land on a barrier and a generator hotspot in
	# night 1 (both are unlocked) and confirm the runtime flag flips. This
	# guards against future refactors that decouple the static helper from
	# _update_hotspots without updating both.
	var game: Node = _new_game()
	await _settle_game()
	await _enter_night_from_cover(game)
	for entry in [["front_door", "barrier"], ["generator", "generator"]]:
		var id: String = entry[0]
		var expected_kind: String = entry[1]
		var pos: Vector2 = (game.get("HOTSPOT_POSITIONS") as Dictionary)[id]
		game.set("player_pos", pos)
		game.set("player_target_id", id)
		game.set("player_at_target", true)
		game.set("player_repair_active", false)
		game.set("player_repair_timer", 0.0)
		game.call("_update_hotspots", 0.1)
		var active: bool = bool(game.get("player_repair_active"))
		_expect(
			active == true,
			"runtime player_repair_active fires for kind=%s hotspot_id=%s (got %s)"
				% [expected_kind, id, str(active)]
		)
	await _dispose_game(game)