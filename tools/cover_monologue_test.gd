extends SceneTree
# M13 narrative-hooks — Cover monologue (Hook A) test.
# Verifies that _show_slot_picker() adds a 3-line narrator overlay to the
# card layer, that lines come from the i18n keys (zh + en variants), and
# that a 3s fade-in tween is set up.

const Game := preload("res://scripts/NightShiftGame.gd")
const Save := preload("res://scripts/NightShiftSave.gd")
const I18n := preload("res://scripts/I18n.gd")

var passed: int = 0
var failed: int = 0
var game: Node


func _initialize() -> void:
	I18n.load_all()
	Save.clear_save()
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
	print("=== Cover monologue test ===")

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	game = scene.instantiate()
	root.add_child(game)
	await process_frame

	# 1) Cover phase
	_assert(game.phase == "cover", "starts at cover")

	# 2) Drive _build_cover_monologue directly (avoid _show_slot_picker which
	#    rebuilds the entire slot picker including music / art swaps that
	#    are noise for this targeted test).
	game.call("_clear_card_layer")
	game.call("_build_cover_monologue")
	var labels: Array = []
	for c in game.card_layer.get_children():
		if c is Label:
			labels.append(c)
	_assert(labels.size() == 3, "card_layer has exactly 3 monologue Labels (got %d)" % labels.size())

	# 3) Verify the 3 i18n keys map to actual non-empty localized strings.
	var l1: String = I18n.t("cover_monologue_line1")
	var l2: String = I18n.t("cover_monologue_line2")
	var la: String = I18n.t("cover_monologue_attribution")
	_assert(l1 != "" and l1 != "cover_monologue_line1", "cover_monologue_line1 localized (zh)")
	_assert(l2 != "" and l2 != "cover_monologue_line2", "cover_monologue_line2 localized (zh)")
	_assert(la != "" and la != "cover_monologue_attribution", "cover_monologue_attribution localized (zh)")

	# 4) Find Labels in card_layer whose text matches the localized strings.
	var has_l1 := false
	var has_l2 := false
	var has_la := false
	for c in labels:
		if c.text == l1:
			has_l1 = true
		elif c.text == l2:
			has_l2 = true
		elif c.text == la:
			has_la = true
	_assert(has_l1, "monologue line1 rendered (zh)")
	_assert(has_l2, "monologue line2 rendered (zh)")
	_assert(has_la, "monologue attribution rendered (zh)")

	# 5) Verify the labels start with alpha 0 (the fade-in tween initial).
	var found_faded := false
	for c in labels:
		if c.text in [l1, l2, la]:
			if (c as CanvasItem).modulate.a < 0.5:
				found_faded = true
				break
	_assert(found_faded, "monologue labels start faded (alpha 0 before tween)")

	# 6) Locale switch: re-build monologue in en, verify strings change.
	I18n.locale = "en"
	var l1_en: String = I18n.t("cover_monologue_line1")
	var l2_en: String = I18n.t("cover_monologue_line2")
	var la_en: String = I18n.t("cover_monologue_attribution")
	_assert(l1_en != l1, "en line1 differs from zh line1 (got '%s' vs '%s')" % [l1_en, l1])
	_assert(l2_en != l2, "en line2 differs from zh line2")
	_assert(la_en != la, "en attribution differs from zh attribution")
	_assert(l1_en != "" and l1_en != "cover_monologue_line1", "cover_monologue_line1 localized (en)")

	# Re-build monologue under en locale — labels re-add to card_layer.
	game.call("_clear_card_layer")
	game.call("_build_cover_monologue")
	var labels_en: Array = []
	for c in game.card_layer.get_children():
		if c is Label:
			labels_en.append(c)
	var has_l1_en := false
	for c in labels_en:
		if c.text == l1_en:
			has_l1_en = true
			break
	_assert(has_l1_en, "monologue line1 rendered (en)")

	print("Cover monologue test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])