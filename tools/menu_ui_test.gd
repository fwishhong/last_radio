extends SceneTree
# Tests for MenuUI: pause, settings, quit confirmation, and persistence.
# Uses `get_tree().create_timer(0).timeout` instead of `process_frame` for
# awaits after the SceneTree is paused, because the test coroutine itself
# is part of the tree and would block on a paused frame.

const MenuUI := preload("res://scripts/MenuUI.gd")
const I18n := preload("res://scripts/I18n.gd")
const Settings := preload("res://scripts/Settings.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	# Reset settings + locale to known state.
	Settings.reset_all()
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


# Wait a frame (synchronous, no coroutine needed). We use OS.delay_msec
# because a paused SceneTree also blocks coroutine resume, so an `await
# process_frame` would deadlock after we open the pause menu.
func _wait() -> void:
	OS.delay_msec(50)


func _run() -> void:
	print("=== MenuUI test ===")

	# Mount MenuUI on the root
	var menu = MenuUI.new()
	# SceneTree.root is the auto-created Window — use it for test mounts.
	# Some Godot versions require `await process_frame` before root is
	# accessible; do one frame first.
	await process_frame
	root.add_child(menu)
	# _ready fires synchronously when the node enters the tree.

	# 1) Initial state
	_assert(not menu.is_paused(), "initially not paused")
	_assert(not menu.is_settings_open(), "initially settings not open")
	_assert(not menu.get_tree().paused, "SceneTree not paused initially")

	# 2) open_pause toggles the tree's paused flag
	menu.open_pause()
	await _wait()  # tree is now paused; use timer-based wait
	_assert(menu.is_paused(), "open_pause sets is_paused = true")
	_assert(menu.get_tree().paused, "open_pause pauses SceneTree")

	# 3) close_pause clears state
	menu.close_pause()
	await _wait()
	_assert(not menu.is_paused(), "close_pause clears is_paused")
	_assert(not menu.get_tree().paused, "close_pause unpauses SceneTree")

	# 4) toggle_pause opens/closes
	menu.toggle_pause()
	await _wait()
	_assert(menu.is_paused(), "toggle_pause opens when closed")
	menu.toggle_pause()
	await _wait()
	_assert(not menu.is_paused(), "toggle_pause closes when open")

	# 5) toggle_pause from settings returns to pause (not close)
	menu.open_pause()
	menu._on_settings_open_pressed()
	await _wait()
	_assert(menu.is_settings_open(), "settings open after _on_settings_open_pressed")
	_assert(not menu.is_paused(), "pause hidden while settings open")
	menu.toggle_pause()
	await _wait()
	_assert(not menu.is_settings_open(), "settings closed by toggle from settings")
	_assert(menu.is_paused(), "toggle from settings returns to pause (not close)")

	# 6) settings panel exposes the right audio sliders
	_assert(menu._music_slider.value == Settings.get_music_volume(),
		"music slider reflects Settings")
	_assert(menu._sfx_slider.value == Settings.get_sfx_volume(),
		"sfx slider reflects Settings")

	# 7) Apply settings persists volume + window + locale
	# Slider step=0.05 quantizes 0.42 -> 0.4, so we use 0.4 for the music check.
	menu._music_slider.value = 0.4
	menu._sfx_slider.value = 0.55
	menu._fullscreen_check.button_pressed = true
	I18n.locale = "en"
	menu._on_lang_en_pressed()  # writes to Settings via _apply_locale
	menu.apply_settings()
	await _wait()
	_assert(abs(Settings.get_music_volume() - 0.4) < 0.001, "music volume persisted on Apply")
	_assert(abs(Settings.get_sfx_volume() - 0.55) < 0.001, "sfx volume persisted on Apply")
	_assert(Settings.get_window_mode() == "fullscreen", "window mode persisted on Apply")
	_assert(Settings.get_locale() == "en", "locale persisted on Apply")
	_assert(I18n.locale == "en", "I18n locale switched to en on Apply")

	# 8) Reset restores defaults
	menu._on_reset_pressed()
	await _wait()
	_assert(Settings.get_music_volume() == 0.8, "reset restores music default")
	_assert(Settings.get_sfx_volume() == 1.0, "reset restores sfx default")
	_assert(Settings.get_window_mode() == "windowed", "reset restores windowed")
	_assert(menu._music_slider.value == 0.8, "music slider reflects reset")
	_assert(menu._sfx_slider.value == 1.0, "sfx slider reflects reset")

	# 9) Quit confirm flow
	menu.open_pause()
	menu._on_quit_pressed()
	await _wait()
	_assert(menu._quit_visible, "quit panel visible after _on_quit_pressed")
	menu._on_quit_no_pressed()
	await _wait()
	_assert(not menu._quit_visible, "quit panel hidden after 'no'")
	_assert(menu.is_paused(), "pause panel visible again after 'no'")

	# 10) Volume-to-dB math
	_assert(menu._volume_to_db(1.0) == 0.0, "1.0 -> 0 dB")
	_assert(menu._volume_to_db(0.0) == -30.0, "0.0 -> -30 dB (muted)")
	_assert(menu._volume_to_db(0.5) < 0.0, "0.5 -> negative dB")
	_assert(menu._volume_to_db(0.5) > -30.0, "0.5 -> not muted")

	# 11) toggle_pause state machine
	menu.close_pause()
	await _wait()
	menu.toggle_pause()
	await _wait()
	_assert(menu.is_paused(), "toggle_pause state machine works")

	menu.queue_free()

	print("MenuUI test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])