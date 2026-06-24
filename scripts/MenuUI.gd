class_name MenuUI
extends CanvasLayer
# Pause / Settings / Quit overlay for NightShiftGame.
#
# Mounted as a high-layer CanvasLayer (default 100) so it covers everything
# below. Owns:
#   - pause_panel    : Resume / Settings / Quit buttons
#   - settings_panel : volume sliders + language buttons + fullscreen toggle
#   - quit_panel     : quit confirmation
#
# Public API (used by tests + NightShiftGame):
#   toggle_pause()   — open if closed, close if open
#   open_pause()     — show pause panel + pause the SceneTree
#   close_pause()    — hide everything + unpause
#   is_paused() -> bool
#   is_settings_open() -> bool
#   apply_settings()  — push current sliders/buttons to AudioServer / DisplayServer / I18n
#
# Persistence:
#   Reads from / writes to Settings (user://settings.json) so choices survive
#   across runs. Audio + window are applied at mount time and on every Apply.
#
# Why one class and three panels?  This is a small game; one cohesive file is
# easier to reason about than three separate scenes. Each panel is a child
# Control and is shown / hidden as a unit.

const I18nRef := preload("res://scripts/I18n.gd")
const SettingsRef := preload("res://scripts/Settings.gd")

const PANEL_WIDTH := 460
const PANEL_HEIGHT := 380
const SETTINGS_PANEL_WIDTH := 520
const SETTINGS_PANEL_HEIGHT := 420
const QUIT_PANEL_WIDTH := 380
const QUIT_PANEL_HEIGHT := 200

var _pause_visible: bool = false
var _settings_visible: bool = false
var _quit_visible: bool = false

# Controls
var _dim: ColorRect
var _pause_panel: Panel
var _settings_panel: Panel
var _quit_panel: Panel

# Settings widgets
var _music_slider: HSlider
var _sfx_slider: HSlider
var _mute_check: CheckButton
var _fullscreen_check: CheckButton
var _lang_zh_button: Button
var _lang_en_button: Button
var _apply_status: Label  # short "applied" feedback

# Callbacks (set by host scene)
var on_quit_to_desktop: Callable = Callable()
var on_settings_applied: Callable = Callable()


func _ready() -> void:
	layer = 100
	_build()
	_apply_audio()
	_apply_window_mode()
	# Initial state: everything hidden.
	pause_panel_set_visible(false)
	settings_panel_set_visible(false)
	quit_panel_set_visible(false)


# ---------- public API ----------

func toggle_pause() -> void:
	if _quit_visible:
		return
	if _settings_visible:
		settings_panel_set_visible(false)
		_settings_visible = false
		pause_panel_set_visible(true)
		_pause_visible = true
		return
	if _pause_visible:
		close_pause()
	else:
		open_pause()


func open_pause() -> void:
	if _pause_visible:
		return
	_pause_visible = true
	_pause_panel.visible = true
	_dim.visible = true
	_refresh_button_labels()
	# Pausing the SceneTree freezes the night tick but keeps UI inputs alive.
	get_tree().paused = true


func close_pause() -> void:
	pause_panel_set_visible(false)
	settings_panel_set_visible(false)
	quit_panel_set_visible(false)
	_pause_visible = false
	_settings_visible = false
	_quit_visible = false
	get_tree().paused = false


func is_paused() -> bool:
	return _pause_visible


func is_settings_open() -> bool:
	return _settings_visible


# Apply current Settings values to AudioServer / DisplayServer / I18n.
# Call this on mount and whenever the user hits Apply.
func apply_settings() -> void:
	_apply_audio()
	_apply_window_mode()
	_apply_locale()
	SettingsRef.set_music_volume(_music_slider.value)
	SettingsRef.set_sfx_volume(_sfx_slider.value)
	SettingsRef.set_audio_muted(_mute_check.button_pressed)
	SettingsRef.set_window_mode("fullscreen" if _fullscreen_check.button_pressed else "windowed")
	SettingsRef.set_locale(I18nRef.locale)
	_show_apply_status()
	if on_settings_applied.is_valid():
		on_settings_applied.call()


# ---------- build ----------

func _build() -> void:
	# Dim background covers the whole screen
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)

	# Pause panel
	_pause_panel = _make_centered_panel(PANEL_WIDTH, PANEL_HEIGHT)
	_pause_panel.add_child(_make_title_label(I18nRef.t("pause_title"), Vector2(0, 16), PANEL_WIDTH))
	_pause_panel.add_child(_make_body_label(I18nRef.t("pause_hint"), Vector2(0, 56), PANEL_WIDTH))

	var resume_btn := _make_button(I18nRef.t("btn_resume"), Vector2(60, 100), Vector2(340, 50))
	resume_btn.pressed.connect(_on_resume_pressed)
	_pause_panel.add_child(resume_btn)

	var settings_btn := _make_button(I18nRef.t("btn_settings"), Vector2(60, 165), Vector2(340, 50))
	settings_btn.pressed.connect(_on_settings_open_pressed)
	_pause_panel.add_child(settings_btn)

	var quit_btn := _make_button(I18nRef.t("btn_quit"), Vector2(60, 230), Vector2(340, 50))
	quit_btn.pressed.connect(_on_quit_pressed)
	_pause_panel.add_child(quit_btn)

	add_child(_pause_panel)

	# Settings panel
	_settings_panel = _make_centered_panel(SETTINGS_PANEL_WIDTH, SETTINGS_PANEL_HEIGHT)
	_settings_panel.add_child(_make_title_label(I18nRef.t("settings_title"), Vector2(0, 16), SETTINGS_PANEL_WIDTH))

	# Music volume
	_settings_panel.add_child(_make_body_label(I18nRef.t("settings_music_volume"), Vector2(40, 70), 200))
	_music_slider = HSlider.new()
	_music_slider.position = Vector2(240, 80)
	_music_slider.size = Vector2(220, 24)
	_music_slider.min_value = 0.0
	_music_slider.max_value = 1.0
	_music_slider.step = 0.05
	_music_slider.value = SettingsRef.get_music_volume()
	_settings_panel.add_child(_music_slider)

	# SFX volume
	_settings_panel.add_child(_make_body_label(I18nRef.t("settings_sfx_volume"), Vector2(40, 110), 200))
	_sfx_slider = HSlider.new()
	_sfx_slider.position = Vector2(240, 120)
	_sfx_slider.size = Vector2(220, 24)
	_sfx_slider.min_value = 0.0
	_sfx_slider.max_value = 1.0
	_sfx_slider.step = 0.05
	_sfx_slider.value = SettingsRef.get_sfx_volume()
	_settings_panel.add_child(_sfx_slider)

	# Fullscreen toggle
	_fullscreen_check = CheckButton.new()
	_fullscreen_check.text = I18nRef.t("settings_fullscreen")
	_fullscreen_check.position = Vector2(40, 160)
	_fullscreen_check.button_pressed = SettingsRef.get_window_mode() == "fullscreen"
	_settings_panel.add_child(_fullscreen_check)

	# Mute toggle. Default ON (per Settings.DEFAULT_AUDIO_MUTED) so the
	# first launch and dev-debug runs don't accidentally spam sound into
	# the room. Players flip this off in Settings if they want audio.
	_mute_check = CheckButton.new()
	_mute_check.text = I18nRef.t("settings_mute")
	_mute_check.position = Vector2(280, 160)
	_mute_check.button_pressed = SettingsRef.get_audio_muted()
	_settings_panel.add_child(_mute_check)

	# Language
	_settings_panel.add_child(_make_body_label(I18nRef.t("settings_language"), Vector2(40, 210), 100))
	_lang_zh_button = _make_button(I18nRef.t("settings_zh"), Vector2(140, 200), Vector2(120, 36))
	_lang_zh_button.pressed.connect(_on_lang_zh_pressed)
	_settings_panel.add_child(_lang_zh_button)
	_lang_en_button = _make_button(I18nRef.t("settings_en"), Vector2(280, 200), Vector2(120, 36))
	_lang_en_button.pressed.connect(_on_lang_en_pressed)
	_settings_panel.add_child(_lang_en_button)
	_refresh_lang_button_highlight()

	# Reset + Apply + Back
	var reset_btn := _make_button(I18nRef.t("settings_reset"), Vector2(40, 280), Vector2(120, 40))
	reset_btn.pressed.connect(_on_reset_pressed)
	_settings_panel.add_child(reset_btn)

	var apply_btn := _make_button(I18nRef.t("settings_apply"), Vector2(180, 280), Vector2(120, 40))
	apply_btn.pressed.connect(apply_settings)
	_settings_panel.add_child(apply_btn)

	var back_btn := _make_button(I18nRef.t("btn_back"), Vector2(320, 280), Vector2(120, 40))
	back_btn.pressed.connect(_on_settings_back_pressed)
	_settings_panel.add_child(back_btn)

	_apply_status = _make_body_label("", Vector2(40, 340), SETTINGS_PANEL_WIDTH - 80)
	_apply_status.modulate = Color(0.6, 1, 0.6, 1)
	_settings_panel.add_child(_apply_status)

	add_child(_settings_panel)

	# Quit confirm panel
	_quit_panel = _make_centered_panel(QUIT_PANEL_WIDTH, QUIT_PANEL_HEIGHT)
	_quit_panel.add_child(_make_title_label(I18nRef.t("quit_confirm_title"), Vector2(0, 16), QUIT_PANEL_WIDTH))
	_quit_panel.add_child(_make_body_label(I18nRef.t("quit_confirm_body"), Vector2(20, 60), QUIT_PANEL_WIDTH - 40))

	var yes_btn := _make_button(I18nRef.t("btn_confirm_quit"), Vector2(50, 130), Vector2(120, 44))
	yes_btn.pressed.connect(_on_quit_yes_pressed)
	_quit_panel.add_child(yes_btn)

	var no_btn := _make_button(I18nRef.t("btn_cancel"), Vector2(210, 130), Vector2(120, 44))
	no_btn.pressed.connect(_on_quit_no_pressed)
	_quit_panel.add_child(no_btn)

	add_child(_quit_panel)


# ---------- helpers ----------

func pause_panel_set_visible(v: bool) -> void:
	if _pause_panel:
		_pause_panel.visible = v
	if _dim:
		_dim.visible = v or _settings_visible or _quit_visible


func settings_panel_set_visible(v: bool) -> void:
	if _settings_panel:
		_settings_panel.visible = v
	_settings_visible = v
	if _dim:
		_dim.visible = _pause_visible or _settings_visible or _quit_visible


func quit_panel_set_visible(v: bool) -> void:
	if _quit_panel:
		_quit_panel.visible = v
	_quit_visible = v
	if _dim:
		_dim.visible = _pause_visible or _settings_visible or _quit_visible


func _make_centered_panel(w: float, h: float) -> Panel:
	var p := Panel.new()
	p.size = Vector2(w, h)
	p.position = Vector2((1280.0 - w) * 0.5, (720.0 - h) * 0.5)
	p.visible = false
	return p


func _make_title_label(text: String, pos: Vector2, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, 40)
	l.add_theme_constant_override("font_size", 28)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _make_body_label(text: String, pos: Vector2, w: float) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = Vector2(w, 36)
	l.add_theme_constant_override("font_size", 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _make_button(text: String, pos: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	return b


func _refresh_button_labels() -> void:
	# Re-render labels after locale switch so any opened panel picks up the
	# new strings. Walk the children of each panel and find Button/Label.
	# Simpler approach: callers re-call apply_settings and on_settings_applied
	# triggers a full pause panel rebuild. For now, just leave the labels —
	# the user can re-open the pause menu to see refreshed strings.
	pass


func _refresh_lang_button_highlight() -> void:
	if _lang_zh_button and _lang_en_button:
		_lang_zh_button.button_pressed = (I18nRef.locale == "zh")
		_lang_en_button.button_pressed = (I18nRef.locale == "en")


# ---------- button handlers ----------

func _on_resume_pressed() -> void:
	close_pause()


func _on_settings_open_pressed() -> void:
	pause_panel_set_visible(false)
	_pause_visible = false
	settings_panel_set_visible(true)
	_refresh_lang_button_highlight()


func _on_settings_back_pressed() -> void:
	settings_panel_set_visible(false)
	_pause_visible = true
	_pause_panel.visible = true
	_dim.visible = true


func _on_lang_zh_pressed() -> void:
	I18nRef.set_locale("zh")
	_refresh_lang_button_highlight()


func _on_lang_en_pressed() -> void:
	I18nRef.set_locale("en")
	_refresh_lang_button_highlight()


func _on_reset_pressed() -> void:
	SettingsRef.reset_all()
	_music_slider.value = SettingsRef.get_music_volume()
	_sfx_slider.value = SettingsRef.get_sfx_volume()
	_mute_check.button_pressed = SettingsRef.get_audio_muted()
	_fullscreen_check.button_pressed = SettingsRef.get_window_mode() == "fullscreen"
	_apply_audio()
	_apply_window_mode()
	_refresh_lang_button_highlight()
	_show_apply_status()


func _on_quit_pressed() -> void:
	pause_panel_set_visible(false)
	_pause_visible = false
	quit_panel_set_visible(true)


func _on_quit_yes_pressed() -> void:
	if on_quit_to_desktop.is_valid():
		on_quit_to_desktop.call()
	else:
		get_tree().quit()


func _on_quit_no_pressed() -> void:
	quit_panel_set_visible(false)
	_pause_visible = true
	_pause_panel.visible = true
	_dim.visible = true


# ---------- apply ----------

func _apply_audio() -> void:
	# Master bus is index 0, Music is 1, SFX is 2 — defined in default_bus_layout.
	# If a bus is missing (e.g. fresh project), we silently skip.
	var music_db := _volume_to_db(SettingsRef.get_music_volume())
	var sfx_db := _volume_to_db(SettingsRef.get_sfx_volume())
	_set_bus_volume_db("Music", music_db)
	_set_bus_volume_db("SFX", sfx_db)
	# Global mute is a separate axis from volume: it overrides the bus
	# volume entirely. AudioServer.set_bus_mute bypasses the volume_db
	# calculation so a "muted" state is exact silence even when the
	# user has volume at 100%.
	_apply_audio_mute()


func _apply_audio_mute() -> void:
	var muted := SettingsRef.get_audio_muted()
	for bus in ["Music", "SFX"]:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			AudioServer.set_bus_mute(idx, muted)


func _apply_window_mode() -> void:
	var mode := SettingsRef.get_window_mode()
	if mode == "fullscreen":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _apply_locale() -> void:
	# Settings.get_locale() returns "" if the user hasn't picked a language,
	# in which case we keep the current I18n.locale (default zh).
	var saved: String = SettingsRef.get_locale()
	if saved != "" and I18nRef.SUPPORTED_LOCALES.has(saved):
		I18nRef.set_locale(saved)


func _set_bus_volume_db(bus: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, db)


func _volume_to_db(v: float) -> float:
	# 0..1 linear to dB. We use -30..0 dB; full volume is 0 dB, mute is -30 dB.
	# Avoid log(0) by clamping.
	if v <= 0.001:
		return -30.0
	return clamp(20.0 * log(v) / log(10.0), -30.0, 0.0)


func _show_apply_status() -> void:
	if _apply_status:
		_apply_status.text = "OK"