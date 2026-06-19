extends SceneTree
# Tests for the I18n + Settings modules.

const I18n := preload("res://scripts/I18n.gd")
const Settings := preload("res://scripts/Settings.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
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
	print("=== I18n + Settings test ===")

	# 1) Load both locales
	I18n.load_all()
	_assert(I18n.dicts.has("zh"), "zh locale loaded")
	_assert(I18n.dicts.has("en"), "en locale loaded")
	_assert(I18n.t("cover_btn_start") == "开始第一章", "zh: cover button is '开始第一章'")
	I18n.locale = "en"
	_assert(I18n.t("cover_btn_start") == "Start Chapter 1", "en: cover button is 'Start Chapter 1'")

	# 2) Fallback chain — unknown key returns the key itself
	_assert(I18n.t("nonexistent_key_xyz") == "nonexistent_key_xyz",
		"unknown key returns key itself as ultimate fallback")

	# 3) printf-style substitution
	I18n.locale = "zh"
	_assert(I18n.t("assault", ["正门"]) == "正门 遭到冲击。",
		"printf-style args work (zh)")
	I18n.locale = "en"
	_assert(I18n.t("assault", ["Front Door"]) == "Front Door is being assaulted.",
		"printf-style args work (en)")
	_assert(I18n.t("effect_barrier_pressure", [0.72, "Front Door"]) == "Barrier drain x0.72 (Front Door)",
		"float + string printf args work (en)")

	# 4) t_field — reads name_en / title_en / etc. with fallback
	var dict: Dictionary = {
		"title": "测试夜",
		"title_en": "Test Night",
		"body": "正文",
	}
	I18n.locale = "en"
	_assert(I18n.t_field(dict, "title") == "Test Night", "t_field uses title_en when locale=en")
	I18n.locale = "zh"
	_assert(I18n.t_field(dict, "title") == "测试夜", "t_field falls back to title when locale=zh")

	# 5) set_locale validates
	_assert(I18n.set_locale("zh"), "set_locale('zh') ok")
	_assert(I18n.locale == "zh", "locale is zh")
	_assert(I18n.set_locale("en"), "set_locale('en') ok")
	_assert(I18n.locale == "en", "locale is en")

	# 6) Settings — defaults before any file is written
	# Make sure no leftover user://settings.json from a previous run.
	if FileAccess.file_exists(Settings.PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	Settings._loaded = false
	Settings._cache = {}
	_assert(Settings.get_locale() == "", "no locale set yet (empty)")
	_assert(Settings.get_music_volume() == 0.8, "default music volume = 0.8")
	_assert(Settings.get_sfx_volume() == 1.0, "default sfx volume = 1.0")
	_assert(Settings.get_window_mode() == "windowed", "default window mode = windowed")
	_assert(Settings.get_resolution() == "1280x720", "default resolution = 1280x720")

	# 7) Settings — set + read back from disk
	Settings.set_locale("en")
	Settings.set_music_volume(0.42)
	Settings.set_sfx_volume(0.7)
	Settings.set_window_mode("fullscreen")
	Settings.set_resolution("1920x1080")
	# Force reload from disk
	Settings._loaded = false
	Settings._cache = {}
	_assert(Settings.get_locale() == "en", "locale persisted as en")
	_assert(abs(Settings.get_music_volume() - 0.42) < 0.001, "music volume persisted")
	_assert(abs(Settings.get_sfx_volume() - 0.7) < 0.001, "sfx volume persisted")
	_assert(Settings.get_window_mode() == "fullscreen", "window mode persisted")
	_assert(Settings.get_resolution() == "1920x1080", "resolution persisted")

	# 8) Settings — reset_all clears everything
	Settings.reset_all()
	Settings._loaded = false
	Settings._cache = {}
	_assert(Settings.get_locale() == "", "reset_all clears locale")
	_assert(Settings.get_music_volume() == 0.8, "reset_all restores music default")
	_assert(Settings.get_sfx_volume() == 1.0, "reset_all restores sfx default")

	# 9) Cover body paragraph renders in both languages (regression on long string)
	I18n.locale = "zh"
	_assert(I18n.t("cover_body").length() > 20, "zh cover body has substance")
	I18n.locale = "en"
	_assert(I18n.t("cover_body").length() > 20, "en cover body has substance")
	_assert(I18n.t("cover_body").find("stadium") >= 0, "en cover body mentions stadium")

	# 10) Achievement strings translated
	I18n.locale = "en"
	_assert(I18n.t("achievement_first_night") == "First Night",
		"achievement 'first night' localized")
	_assert(I18n.t("achievement_call_elias_desc").find("Elias") >= 0,
		"achievement desc localized")

	print("I18n + Settings test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])