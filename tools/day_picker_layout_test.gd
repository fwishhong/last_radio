extends SceneTree
# Regression test for the day-picker layout overflow bug.
#
# Before this fix, _show_day() hard-coded card_w=320 and gap=18. With 4 cards
# (night 2: door_reinforce / window_brace / battery_buffer + skip), the row
# width was 4*320 + 3*18 = 1334, but SCREEN_SIZE.x is 1280, so:
#   start_x = (1280 - 1334) * 0.5 = -27
# The first card panel rendered at x=-27 and the body/title/icon were clipped
# off the left edge of the screen.
#
# This fix shrinks card_w when the row would otherwise overflow, so that
# n cards always fit between side_margin cushions regardless of card count.
#
# The test boots into night 2 (4 cards), then asserts:
#   - every Panel under card_layer has position.x >= 0
#   - every Panel's right edge <= SCREEN_SIZE.x
#   - card_w was actually shrunk (not still 320)
#   - the panels don't overlap each other horizontally

const Save := preload("res://scripts/NightShiftSave.gd")
const Levels := preload("res://scripts/NightShiftLevels.gd")

var game: Node
var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _run() -> void:
	print("=== Day picker layout regression test ===")
	Save.clear_save()

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	for i in range(4): await process_frame

	# Walk through cover -> difficulty -> day 1 -> night 1 -> report -> day 2.
	game._on_slot_new_pressed(1)
	await process_frame
	game._on_difficulty_chosen(Save.DIFFICULTY_NORMAL)
	await process_frame
	game.call("_on_start_pressed")
	await process_frame
	_assert(game.phase == "day", "start pressed -> day phase")
	_assert(game.night_index == 0, "fresh campaign at night 1 (index 0)")

	# Skip day 1 card picker (only the skip card is offered)
	game.call("_on_day_card_pressed", "start")
	await process_frame
	_assert(game.phase == "night", "after skip -> night phase")

	# Force the night 1 report -> day 2 transition.
	for id in game.hotspots:
		var h: Dictionary = game.hotspots[id]
		h["value"] = h["max_value"]
		h["breach_timer"] = -1.0
		h["assault"] = false
		game.hotspots[id] = h
	game.radio_available = false
	game.radio_completed = true
	game.night_elapsed = game.night_duration - 0.05
	for i in range(6):
		game.call("_update_night", 0.05)
	_assert(game.phase == "night_report", "night 1 -> report")
	game.call("_on_report_continue", true)
	await process_frame
	_assert(game.phase == "day", "report continue -> day phase")
	_assert(game.night_index == 1, "advanced to night 2 (index 1)")

	# 1) Verify night 2 actually offers the 4-card case (3 upgrades + skip).
	# If data drifts to fewer cards, the overflow assertion below still passes
	# trivially — that's intentional, the bug only manifests at n >= 4.
	var panels: Array = _day_panels()
	_assert(panels.size() >= 4, "night 2 day picker has >= 4 panels (got %d)" % panels.size())

	# 2) Invariant: every panel position.x >= 0 (the bug's smoking gun).
	var any_clipped_left: bool = false
	for p in panels:
		if p.position.x < 0.0:
			any_clipped_left = true
			break
	_assert(not any_clipped_left, "no panel is clipped on the left edge")

	# 3) Invariant: every panel's right edge <= SCREEN_SIZE.x.
	var screen_w: float = float(game.SCREEN_SIZE.x)
	var any_clipped_right: bool = false
	var max_right: float = 0.0
	for p in panels:
		var right: float = p.position.x + p.size.x
		if right > max_right:
			max_right = right
		if right > screen_w + 0.5:  # 0.5px slack for float rounding
			any_clipped_right = true
	_assert(not any_clipped_right, "no panel overflows the right edge (max_right=%.1f, screen_w=%.1f)" % [
		max_right, screen_w
	])

	# 4) Invariant: at n=4, the layout actually had to shrink. Re-derive the
	#    expected card_w and confirm the panels reflect that.
	var n: int = panels.size()
	if n >= 4:
		var gap: float = 18.0
		var side_margin: float = 24.0
		var max_total_w: float = screen_w - side_margin * 2.0
		var expected_card_w: float = min(320.0, (max_total_w - (n - 1) * gap) / float(n))
		# Panel size.x == card_w in the implementation
		var sample_w: float = float(panels[0].size.x)
		_assert(abs(sample_w - expected_card_w) < 0.5,
			"card_w shrunk to fit (expected=%.1f, got=%.1f, n=%d)" % [
				expected_card_w, sample_w, n
			])
		_assert(sample_w < 320.0, "card_w strictly smaller than 320 when n>=4 (got %.1f)" % sample_w)
	else:
		print("  (skip card_w shrink check: n=%d < 4)" % n)

	# 5) Invariant: panels don't overlap horizontally.
	var sorted_x: Array = panels.duplicate()
	sorted_x.sort_custom(func(a, b): return a.position.x < b.position.x)
	var overlap_found: bool = false
	for i in range(sorted_x.size() - 1):
		var a: Panel = sorted_x[i]
		var b: Panel = sorted_x[i + 1]
		var a_right: float = a.position.x + a.size.x
		if a_right > b.position.x + 0.5:
			overlap_found = true
			break
	_assert(not overlap_found, "no two day panels overlap horizontally")

	# 6) Sanity: sub-element widths inside each panel scale with card_w, so
	#    title/body/effects labels are wider than zero and narrower than the
	#    panel itself.
	var sample_panel: Panel = panels[0]
	var label_widths: Array = []
	for child in sample_panel.get_children():
		if child is Label and child.size.x > 0.0:
			label_widths.append(child.size.x)
	_assert(label_widths.size() > 0, "day panel has at least one sized label")
	if label_widths.size() > 0:
		var max_label_w: float = 0.0
		for w in label_widths:
			if w > max_label_w:
				max_label_w = w
		_assert(max_label_w < sample_panel.size.x,
			"max label width < panel width (%.1f < %.1f)" % [max_label_w, sample_panel.size.x])

	print("Day picker layout test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	quit(0 if failed == 0 else 1)


func _day_panels() -> Array:
	var out: Array = []
	for c in game.card_layer.get_children():
		if c is Panel:
			out.append(c)
	return out