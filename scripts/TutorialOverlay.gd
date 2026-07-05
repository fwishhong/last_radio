class_name TutorialOverlay
extends CanvasLayer
# First-night tutorial. Two independent flows:
#
#   1. The original 3-step overlay (move / repair / survive) shown at
#      the start of Night 0. Lives in the top-center bubble. When the
#      player survives Night 0, on_tutorial_finished fires.
#
#   2. Step 4 (M13 narrative-hooks) — a small radio dial mini-game in
#      the bottom-left corner. Player drags an HSlider to 7.085 MHz and
#      the panel fades in Victor's "撑住。我看到你的信号了。" line.
#      Triggered AFTER the 3-step tutorial completes on Night 0, but
#      ONLY if the save's `tutorial_done_step4` flag is false.
#      on_step4_finished fires when the player lands on 7.085 MHz.
#
# State:
#   _step     0/1/2 = move/repair/survive (3-step bubble mode)
#             3 = done (3-step bubble mode finished, fires callback)
#   _step4_only_mode when true, the 3-step bubble is hidden and the
#             bottom-left step-4 panel is shown instead
#
# Wiring:
#   - The host scene calls start() at the beginning of Night 0
#   - The host calls notify_player_moved() / notify_hotspot_clicked() /
#     notify_night_succeeded() when those events happen; we auto-advance
#   - After on_tutorial_finished fires, the host checks
#     `tutorial_done_step4` and calls start_step4_only() if needed
#   - The "Got it" button advances manually; "Skip" hides everything
#   - On finish (or skip), on_tutorial_finished fires so the host can
#     persist `tutorial_done: true` to the save
#   - on_step4_finished fires when step 4 completes so the host can
#     persist `tutorial_done_step4: true` to the save
#
# Skipping is permanent for the current save. Restarting the save (or
# clearing user://) brings the tutorial back.

const I18nRef := preload("res://scripts/I18n.gd")

const BUBBLE_W := 720
const BUBBLE_H := 200

# Step 4 mini-game tuning target. 7.085 MHz is the canonical HAM
# shortwave frequency in the polish spec.
const STEP4_TARGET_FREQ := 7.085
const STEP4_FREQ_TOLERANCE := 0.005
const STEP4_FREQ_NEAR_TOLERANCE := 0.02
const STEP4_FREQ_MIN := 7.000
const STEP4_FREQ_MAX := 7.200

# Step 4 panel size — sits in the bottom-left of the screen, separate
# from the main bubble layout.
const STEP4_PANEL_W := 320
const STEP4_PANEL_H := 180
const STEP4_PANEL_MARGIN := 16

# Total tutorial step count for the 3-step overlay's "Step N / TOTAL"
# indicator. Step 4 (mini-game) is opt-in and lives outside this count.
const TOTAL_STEPS := 3

var _step: int = 0
var _active: bool = false
var _step4_completed: bool = false
var _step4_only_mode: bool = false
var _step4_victor_alpha: float = 0.0
var _step4_noise_phase: float = 0.0

# Controls — 3-step overlay (top-center bubble)
var _dim: ColorRect
var _bubble: Panel
var _title_label: Label
var _step_label: Label
var _body_label: Label
var _next_btn: Button
var _skip_btn: Button

# Controls — step 4 mini-game (bottom-left panel)
var _step4_panel: Panel
var _step4_title: Label
var _step4_body: Label
var _step4_slider: HSlider
var _step4_freq_label: Label
var _step4_victor_label: Label
var _step4_noise_label: Label

# Callbacks
var on_tutorial_finished: Callable = Callable()
# Fires when step 4 (the radio dial mini-game) completes successfully.
# Host persists `tutorial_done_step4: true` on this signal.
var on_step4_finished: Callable = Callable()


func _ready() -> void:
	layer = 50
	_build()
	hide_overlay()


func _process(delta: float) -> void:
	# Step 4 only: fade in the Victor line over 3s once the slider
	# lands on the target frequency. Auto-finish fires once alpha hits 1.
	if not (_step4_only_mode and _active):
		return
	# Static noise jitter — cheap sin-wave alpha modulation so the
	# "off frequency" state feels alive.
	_step4_noise_phase += delta * 10.0
	if not _is_step4_on_frequency(_step4_slider.value):
		var jitter: float = 0.5 + 0.5 * sin(_step4_noise_phase)
		if _is_step4_near_miss(_step4_slider.value):
			_step4_noise_label.modulate.a = 0.45 + 0.25 * jitter
		else:
			_step4_noise_label.modulate.a = 0.55 + 0.45 * jitter
	if _is_step4_on_frequency(_step4_slider.value):
		_step4_victor_alpha = min(1.0, _step4_victor_alpha + delta / 3.0)
		_step4_victor_label.modulate.a = _step4_victor_alpha
		if _step4_victor_alpha >= 1.0 and not _step4_completed:
			_finish_step4()


# ---------- public API ----------

func start() -> void:
	# Original 3-step tutorial (move / repair / survive).
	_step4_only_mode = false
	_step = 0
	_active = true
	_step4_completed = false
	_step4_victor_alpha = 0.0
	_refresh_text()
	show_overlay()


func start_step4_only() -> void:
	# Step 4 mini-game — bottom-left panel, no top bubble. Shown after
	# the 3-step tutorial completes on Night 0 if tutorial_done_step4
	# is false.
	_step4_only_mode = true
	_step = 3
	_active = true
	_step4_completed = false
	_step4_victor_alpha = 0.0
	_step4_noise_phase = 0.0
	_show_step4_panel()
	show_overlay()


func skip() -> void:
	if not _active:
		return
	_active = false
	hide_overlay()
	if on_tutorial_finished.is_valid():
		on_tutorial_finished.call()


# Called by the host when the player has actually moved (used to detect
# "they got the idea"). Idempotent — repeated calls during the move step
# are fine; calls during other steps are no-ops.
func notify_player_moved() -> void:
	if not _active or _step4_only_mode or _step != 0:
		return
	_advance()


# Called when the player clicks any hotspot.
func notify_hotspot_clicked() -> void:
	if not _active or _step4_only_mode or _step != 1:
		return
	_advance()


# Called when a night ends successfully (we treat "you got to dawn" as
# the tutorial gate, not a per-night end).
func notify_night_succeeded() -> void:
	if not _active or _step4_only_mode:
		return
	if _step == 2:
		_advance()


func is_active() -> bool:
	return _active


func current_step() -> int:
	return _step


# True iff step 4 (the radio dial mini-game) has been completed this
# session. Survives skip() — it's a one-shot flag for the save layer.
func step4_completed() -> bool:
	return _step4_completed


# ---------- internals ----------

func _advance() -> void:
	_step += 1
	if _step > 2:
		_active = false
		hide_overlay()
		if on_tutorial_finished.is_valid():
			on_tutorial_finished.call()
	else:
		_refresh_text()


func _finish_step4() -> void:
	if not _step4_only_mode or _step4_completed:
		return
	_step4_completed = true
	if on_step4_finished.is_valid():
		on_step4_finished.call()
	_active = false
	hide_overlay()


func _refresh_text() -> void:
	# 3-step overlay (top bubble).
	var titles: Array = [
		I18nRef.t("tutorial_move_title"),
		I18nRef.t("tutorial_repair_title"),
		I18nRef.t("tutorial_survive_title"),
	]
	var bodies: Array = [
		I18nRef.t("tutorial_move_body"),
		I18nRef.t("tutorial_repair_body"),
		I18nRef.t("tutorial_survive_body"),
	]
	_title_label.text = titles[_step]
	_body_label.text = bodies[_step]
	_step_label.text = I18nRef.t("tutorial_step_indicator", [_step + 1, TOTAL_STEPS])
	# Hide step 4 panel — it lives in its own bottom-left slot.
	_step4_panel.visible = false


func _show_step4_panel() -> void:
	# Top bubble stays hidden during step 4 only mode.
	_bubble.visible = false
	_dim.visible = true
	_skip_btn.visible = true
	_step4_panel.visible = true
	_step4_title.text = I18nRef.t("tut_step4_title")
	_step4_body.text = I18nRef.t("tut_step4_desc")
	_step4_victor_label.text = I18nRef.t("tut_step4_victor_line")
	_step4_victor_label.modulate.a = 0.0
	_step4_noise_label.text = ""
	_step4_noise_label.modulate.a = 0.0
	_step4_slider.value = 7.100
	_on_step4_slider_changed(_step4_slider.value)


func show_overlay() -> void:
	if _step4_only_mode:
		_dim.visible = true
		_skip_btn.visible = true
		_step4_panel.visible = true
		_bubble.visible = false
		return
	if _dim:
		_dim.visible = true
	if _bubble:
		_bubble.visible = true
	if _skip_btn:
		_skip_btn.visible = true
	if _step4_panel:
		_step4_panel.visible = false


func hide_overlay() -> void:
	if _dim:
		_dim.visible = false
	if _bubble:
		_bubble.visible = false
	if _skip_btn:
		_skip_btn.visible = false
	if _step4_panel:
		_step4_panel.visible = false


# ---------- UI build ----------

func _build() -> void:
	# Dim background — light dim, the player should still see the stadium.
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.35)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)

	# Skip button (top-right corner)
	_skip_btn = Button.new()
	_skip_btn.text = I18nRef.t("tutorial_skip")
	_skip_btn.position = Vector2(1280.0 - 180.0, 16.0)
	_skip_btn.size = Vector2(160, 36)
	_skip_btn.visible = false
	_skip_btn.pressed.connect(skip)
	add_child(_skip_btn)

	# ---- 3-step overlay bubble (top-center) ----
	_bubble = Panel.new()
	_bubble.size = Vector2(BUBBLE_W, BUBBLE_H)
	_bubble.position = Vector2((1280.0 - BUBBLE_W) * 0.5, 28.0)
	_bubble.visible = false
	add_child(_bubble)

	# Step indicator (small, top of bubble)
	_step_label = Label.new()
	_step_label.position = Vector2(20, 12)
	_step_label.size = Vector2(BUBBLE_W - 40, 24)
	_step_label.add_theme_constant_override("font_size", 14)
	_step_label.modulate = Color(0.7, 0.85, 1, 1)
	_bubble.add_child(_step_label)

	# Title
	_title_label = Label.new()
	_title_label.position = Vector2(20, 40)
	_title_label.size = Vector2(BUBBLE_W - 40, 36)
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_constant_override("outline_size", 3)
	_bubble.add_child(_title_label)

	# Body
	_body_label = Label.new()
	_body_label.position = Vector2(20, 84)
	_body_label.size = Vector2(BUBBLE_W - 40, 70)
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.add_child(_body_label)

	# "Got it" button (bottom-right of bubble)
	_next_btn = Button.new()
	_next_btn.text = I18nRef.t("tutorial_next")
	_next_btn.position = Vector2(BUBBLE_W - 160, BUBBLE_H - 50)
	_next_btn.size = Vector2(140, 36)
	_next_btn.pressed.connect(_on_next_pressed)
	_bubble.add_child(_next_btn)

	# ---- Step 4 mini-game panel (bottom-left) ----
	# Sits OUTSIDE the bubble layout per polish spec §6.2. The bottom-
	# left corner is intentionally the "player HUD" area so it doesn't
	# compete with the top bubble.
	_step4_panel = Panel.new()
	_step4_panel.size = Vector2(STEP4_PANEL_W, STEP4_PANEL_H)
	_step4_panel.position = Vector2(
		STEP4_PANEL_MARGIN,
		720.0 - STEP4_PANEL_H - STEP4_PANEL_MARGIN
	)
	_step4_panel.visible = false
	add_child(_step4_panel)

	_step4_title = Label.new()
	_step4_title.position = Vector2(12, 8)
	_step4_title.size = Vector2(STEP4_PANEL_W - 24, 28)
	_step4_title.add_theme_font_size_override("font_size", 17)
	_step4_title.modulate = Color(1.0, 0.85, 0.55)
	_step4_panel.add_child(_step4_title)

	_step4_body = Label.new()
	_step4_body.position = Vector2(12, 36)
	_step4_body.size = Vector2(STEP4_PANEL_W - 24, 24)
	_step4_body.add_theme_font_size_override("font_size", 13)
	_step4_body.modulate = Color(0.85, 0.85, 0.85)
	_step4_panel.add_child(_step4_body)

	_step4_slider = HSlider.new()
	_step4_slider.min_value = STEP4_FREQ_MIN
	_step4_slider.max_value = STEP4_FREQ_MAX
	_step4_slider.step = 0.001
	_step4_slider.value = 7.100
	_step4_slider.position = Vector2(16, 68)
	_step4_slider.size = Vector2(STEP4_PANEL_W - 32, 20)
	_step4_slider.value_changed.connect(_on_step4_slider_changed)
	_step4_panel.add_child(_step4_slider)

	_step4_freq_label = Label.new()
	_step4_freq_label.position = Vector2(16, 92)
	_step4_freq_label.size = Vector2(STEP4_PANEL_W - 32, 22)
	_step4_freq_label.add_theme_font_size_override("font_size", 16)
	_step4_freq_label.modulate = Color(0.95, 0.85, 0.55)
	_step4_panel.add_child(_step4_freq_label)

	_step4_noise_label = Label.new()
	_step4_noise_label.position = Vector2(12, 118)
	_step4_noise_label.size = Vector2(STEP4_PANEL_W - 24, 22)
	_step4_noise_label.add_theme_font_size_override("font_size", 13)
	_step4_noise_label.modulate = Color(0.7, 0.7, 0.7)
	_step4_panel.add_child(_step4_noise_label)

	_step4_victor_label = Label.new()
	_step4_victor_label.position = Vector2(12, 144)
	_step4_victor_label.size = Vector2(STEP4_PANEL_W - 24, 28)
	_step4_victor_label.add_theme_font_size_override("font_size", 14)
	_step4_victor_label.modulate = Color(0.65, 0.95, 0.75)
	_step4_victor_label.modulate.a = 0.0
	_step4_panel.add_child(_step4_victor_label)


func _on_next_pressed() -> void:
	# Manual advance: skip the gate for the current step.
	if _step4_only_mode:
		# Step 4 has no "Got it" button — the slider is the only path
		# to completion. Treat as a no-op.
		return
	_advance()


func _on_step4_slider_changed(value: float) -> void:
	if not is_instance_valid(_step4_freq_label):
		return
	_step4_freq_label.text = "%0.3f MHz" % value
	if _is_step4_on_frequency(value):
		# On frequency — clear static noise and start the Victor fade-in
		# (handled in _process). Don't auto-finish until the line is
		# fully visible (3s).
		_step4_noise_label.text = ""
		_step4_noise_label.modulate.a = 0.0
	elif _is_step4_near_miss(value):
		# Near-miss — half-strength static noise.
		_step4_noise_label.text = I18nRef.t("tut_step4_static_noise")
		_step4_noise_label.modulate.a = 0.55
		_step4_victor_label.modulate.a = 0.0
		_step4_victor_alpha = 0.0
	else:
		# Way off — full-strength static noise. Jitter runs in _process.
		_step4_noise_label.text = I18nRef.t("tut_step4_static_noise")
		_step4_noise_label.modulate.a = 1.0
		_step4_victor_label.modulate.a = 0.0
		_step4_victor_alpha = 0.0


func _is_step4_on_frequency(value: float) -> bool:
	return abs(value - STEP4_TARGET_FREQ) <= STEP4_FREQ_TOLERANCE


func _is_step4_near_miss(value: float) -> bool:
	var delta: float = abs(value - STEP4_TARGET_FREQ)
	return delta > STEP4_FREQ_TOLERANCE and delta <= STEP4_FREQ_NEAR_TOLERANCE