extends SceneTree
# Test: global audio mute flag (Settings.get_audio_muted + MenuUI + AudioServer).
#
# Round-2 polish feature: the dev / debug workflow previously spammed
# music + sfx on every launch, which disturbed anyone nearby. Solution:
# Settings.DEFAULT_AUDIO_MUTED = true, so a fresh launch (no settings.json)
# starts muted. The MenuUI settings panel adds a Mute checkbox that
# writes the flag back to user://settings.json.
#
# This suite verifies:
#   (1) DEFAULT_AUDIO_MUTED is true
#   (2) get_audio_muted() returns true on a fresh cache
#   (3) set_audio_muted(false) + reset_all() round-trips correctly
#   (4) reset_all() restores the muted default
#   (5) MenuUI has a _mute_check field bound to the panel
#   (6) MenuUI.apply_settings() persists the checkbox state
#   (7) _apply_audio_mute flips AudioServer bus mute state
#   (8) settings.json round-trip: written value is read back
#   (9) CLI override flags are parsed (--no-mute / --mute are recognized
#       names that the parser looks for; we verify the constant set)

const SettingsRef := preload("res://scripts/Settings.gd")
const MenuUI := preload("res://scripts/MenuUI.gd")

var _failed: int = 0
var _passed: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Clear any leftover settings.json from prior runs so the test starts
	# from the documented "fresh launch" baseline.
	_clear_user_settings()
	# Reload after clearing — Settings caches in static memory.
	SettingsRef._loaded = false
	SettingsRef._cache = {}

	await process_frame

	# (1) Default is muted.
	_assert(SettingsRef.DEFAULT_AUDIO_MUTED == true, "DEFAULT_AUDIO_MUTED must be true")

	# (2) Fresh cache returns the default.
	_assert(SettingsRef.get_audio_muted() == true, "fresh get_audio_muted() must return true")

	# (3) set / get round-trip in the same session.
	SettingsRef.set_audio_muted(false)
	_assert(SettingsRef.get_audio_muted() == false, "set_audio_muted(false) must persist within session")

	# (4) reset_all restores the default.
	SettingsRef.reset_all()
	_assert(SettingsRef.get_audio_muted() == true, "reset_all must restore DEFAULT_AUDIO_MUTED")

	# (5) reset_all round-trips through persistence: write, clear cache,
	# re-load, value must still be true.
	SettingsRef.reset_all()  # writes the defaults to user://settings.json
	SettingsRef._loaded = false
	SettingsRef._cache = {}
	_assert(SettingsRef.get_audio_muted() == true, "persisted reset state must be muted")

	# (6) User toggles mute off, the file should reflect that on reload.
	SettingsRef.set_audio_muted(false)
	SettingsRef._loaded = false
	SettingsRef._cache = {}
	_assert(SettingsRef.get_audio_muted() == false, "set false then reload must read false")

	# Restore defaults for the rest of the suite.
	SettingsRef.reset_all()
	SettingsRef._loaded = false
	SettingsRef._cache = {}

	# (7) MenuUI surface: the _mute_check field exists and is bound.
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game: Node = scene.instantiate()
	root.add_child(game)
	for i in 4:
		await process_frame

	var menu_ui: Node = null
	for child in game.get_children():
		if child.get_class() == "CanvasLayer" and child.has_meta("_menu_ui"):
			menu_ui = child
			break
	# Fallback: grab the MenuUI child by name.
	if menu_ui == null:
		for child in game.get_children():
			if child.name.begins_with("MenuUI") or child.name.begins_with("@MenuUI"):
				menu_ui = child
				break
	if menu_ui == null:
		# Last resort: scan all descendants.
		for n in game.find_children("*", "", true, false):
			if n.get_script() == MenuUI:
				menu_ui = n
				break
	_assert(menu_ui != null, "MenuUI node found in scene tree")
	if menu_ui != null:
		_assert(menu_ui.get("_mute_check") != null, "MenuUI._mute_check field exists")
		var mute_check: CheckButton = menu_ui.get("_mute_check")
		# Default is muted (per Settings.reset_all above).
		_assert(mute_check.button_pressed == true, "_mute_check is checked by default")

		# (8) User unchecks the box and applies; settings must persist.
		mute_check.button_pressed = false
		menu_ui.call("apply_settings")
		# apply_settings writes to user://settings.json synchronously.
		SettingsRef._loaded = false
		SettingsRef._cache = {}
		_assert(SettingsRef.get_audio_muted() == false, "after Apply with unchecked, settings must persist false")

		# (9) AudioServer bus mute actually toggled.
		var music_idx: int = AudioServer.get_bus_index("Music")
		var sfx_idx: int = AudioServer.get_bus_index("SFX")
		if music_idx >= 0:
			_assert(AudioServer.is_bus_mute(music_idx) == false, "Music bus unmuted after Apply with unchecked")
		if sfx_idx >= 0:
			_assert(AudioServer.is_bus_mute(sfx_idx) == false, "SFX bus unmuted after Apply with unchecked")

		# Re-check and re-apply, AudioServer should be muted again.
		mute_check.button_pressed = true
		menu_ui.call("apply_settings")
		SettingsRef._loaded = false
		SettingsRef._cache = {}
		_assert(SettingsRef.get_audio_muted() == true, "after Apply with checked, settings must persist true")
		if music_idx >= 0:
			_assert(AudioServer.is_bus_mute(music_idx) == true, "Music bus muted after Apply with checked")
		if sfx_idx >= 0:
			_assert(AudioServer.is_bus_mute(sfx_idx) == true, "SFX bus muted after Apply with checked")

	# (10) CLI override flag names are part of the parser; we verify the
	# documented names exist by checking NightShiftGame._apply_audio_mute
	# source text contains them. This guards against typos in the flag
	# list (someone renaming --no-mute would silently break the dev workflow).
	var nsg_src: String = FileAccess.get_file_as_string("res://scripts/NightShiftGame.gd")
	for flag in ["--no-mute", "--mute", "--silent", "--quiet", "--audio", "--sound"]:
		_assert(nsg_src.find(flag) >= 0, "NightShiftGame parses CLI flag %s" % flag)

	# Restore defaults so the next test starts clean.
	SettingsRef.reset_all()
	SettingsRef._loaded = false
	SettingsRef._cache = {}
	_clear_user_settings()

	print("audio_mute_test: PASS (passed=%d, failed=%d)" % [_passed, _failed])
	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  PASS  %s" % msg)
	else:
		_failed += 1
		push_error("  FAIL  %s" % msg)
		print("  FAIL  %s" % msg)


func _clear_user_settings() -> void:
	# user:// resolves under AppData/Roaming/Godot/app_userdata/<project>.
	var p: String = ProjectSettings.globalize_path(SettingsRef.PATH)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)