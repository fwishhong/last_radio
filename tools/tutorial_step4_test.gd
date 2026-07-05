extends SceneTree
# M13 narrative-hooks — Tutorial step 4 (Hook B) test.
# Verifies the step 4 mini-game: panel visibility, slider frequency
# detection (on-frequency / near-miss / way-off), Victor fade-in,
# completion, and save persistence.

const TutorialOverlay := preload("res://scripts/TutorialOverlay.gd")
const NightShiftSave := preload("res://scripts/NightShiftSave.gd")
const I18n := preload("res://scripts/I18n.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	NightShiftSave.clear_save()
	I18n.load_all()
	I18n.locale = "zh"
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
	print("=== Tutorial step 4 test ===")

	# 1) Mount overlay + drive step 4 only mode
	var overlay = TutorialOverlay.new()
	root.add_child(overlay)
	await process_frame

	var finished_calls: Array = []
	overlay.on_step4_finished = func(): finished_calls.append("done")

	overlay.start_step4_only()
	_assert(overlay.is_active(), "active after start_step4_only")
	_assert(overlay._step4_panel.visible, "step 4 panel visible")
	_assert(not overlay._bubble.visible, "main bubble hidden in step 4 mode")
	_assert(overlay._step4_slider != null, "step 4 slider mounted")
	_assert(overlay._step4_title.text == I18n.t("tut_step4_title"), "step 4 title localized (zh)")
	_assert(overlay._step4_body.text == I18n.t("tut_step4_desc"), "step 4 body localized (zh)")

	# 2) Way-off frequency (7.000): full static noise
	overlay._step4_slider.value = 7.000
	overlay._on_step4_slider_changed(overlay._step4_slider.value)
	_assert(overlay._step4_noise_label.text == I18n.t("tut_step4_static_noise"),
		"way-off shows static noise label")
	_assert(overlay._step4_noise_label.modulate.a >= 0.9,
		"way-off noise at full alpha (got %0.2f)" % overlay._step4_noise_label.modulate.a)

	# 3) Near-miss (7.075): half-strength noise
	overlay._step4_slider.value = 7.075
	overlay._on_step4_slider_changed(overlay._step4_slider.value)
	_assert(overlay._step4_noise_label.text == I18n.t("tut_step4_static_noise"),
		"near-miss shows static noise label")
	_assert(overlay._step4_noise_label.modulate.a > 0.3 and overlay._step4_noise_label.modulate.a < 0.8,
		"near-miss noise at half alpha (got %0.2f)" % overlay._step4_noise_label.modulate.a)

	# 4) On-frequency (7.085): static noise cleared, Victor fade-in starts
	overlay._step4_slider.value = 7.085
	overlay._on_step4_slider_changed(overlay._step4_slider.value)
	_assert(overlay._step4_noise_label.text == "", "on-frequency clears static noise")
	_assert(overlay._step4_noise_label.modulate.a == 0.0, "on-frequency noise alpha = 0")
	_assert(overlay._step4_victor_label.text == I18n.t("tut_step4_victor_line"),
		"on-frequency shows Victor line")
	_assert(overlay._step4_victor_alpha == 0.0, "Victor fade-in starts at alpha 0")

	# 5) On-frequency within tolerance (7.083) also counts
	overlay._step4_slider.value = 7.083
	overlay._on_step4_slider_changed(overlay._step4_slider.value)
	_assert(overlay._step4_noise_label.text == "", "7.083 within tolerance is on-frequency")

	# 6) Force-finish (bypass the 3s fade wait) and verify completion + callback
	overlay._finish_step4()
	_assert(overlay.step4_completed(), "step4_completed() returns true after _finish_step4")
	_assert(finished_calls.size() == 1, "on_step4_finished fired once")
	_assert(not overlay.is_active(), "overlay inactive after finish")

	# 7) Locale switch: re-mount, verify text re-localizes to en.
	#     Avoid a second `await process_frame` here — adding a second overlay
	#     in the same SceneTree process hangs the headless test (see the
	#     comment in tutorial_test.gd).
	I18n.locale = "en"
	var overlay2 = TutorialOverlay.new()
	root.add_child(overlay2)
	overlay2.start_step4_only()
	_assert(overlay2._step4_title.text == I18n.t("tut_step4_title"), "step 4 title localized (en)")
	_assert(overlay2._step4_body.text == I18n.t("tut_step4_desc"), "step 4 body localized (en)")

	# 8) Save persistence: tutorial_done_step4 round-trips through save.
	NightShiftSave.clear_save()
	_assert(not bool(NightShiftSave.read().get("tutorial_done_step4", false)),
		"fresh save: tutorial_done_step4 is false")
	var doc: Dictionary = NightShiftSave.read()
	doc["tutorial_done_step4"] = true
	NightShiftSave.write(doc)
	_assert(bool(NightShiftSave.read().get("tutorial_done_step4", false)),
		"save persists tutorial_done_step4 = true")

	# 9) Old saves without the field default safely.
	#     SAVE_VERSION bump to 5 + migrate_v4_to_v5 should populate the
	#     default for pre-M13 saves.
	var overlay3 = TutorialOverlay.new()
	# Reach into save via migration path: call migrate_v4_to_v5 directly.
	var migrated: Dictionary = NightShiftSave.migrate_v4_to_v5({
		"version": 4,
		"saved_at": 0.0,
		"night_index": 0,
		"resources": {},
		"upgrades": {},
		"allies": {},
		"unlocked_hotspots": [],
	})
	_assert("tutorial_done_step4" in migrated,
		"v4 migration adds tutorial_done_step4 key")
	_assert(bool(migrated.get("tutorial_done_step4", false)) == false,
		"v4 migration defaults tutorial_done_step4 to false")

	print("Tutorial step 4 test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])