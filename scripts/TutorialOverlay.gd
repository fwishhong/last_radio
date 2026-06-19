class_name TutorialOverlay
extends CanvasLayer
# First-night tutorial. A 3-step overlay that walks the player through
# Move / Repair / Survive before they go into their first full night.
#
# State:
#   _step     0 = move, 1 = repair, 2 = survive, 3 = done
#   _active   true while the overlay is up
#
# Wiring:
#   - The host scene calls start() at the beginning of Night 0
#   - The host calls notify_player_moved() / notify_hotspot_clicked() /
#     notify_night_succeeded() when those events happen; we auto-advance
#   - The "Got it" button advances manually; "Skip" hides everything
#   - On finish (or skip), on_tutorial_finished fires so the host can
#     persist `tutorial_done: true` to the save
#
# Skipping is permanent for the current save. Restarting the save (or
# clearing user://) brings the tutorial back.

const I18nRef := preload("res://scripts/I18n.gd")

const BUBBLE_W := 720
const BUBBLE_H := 200

var _step: int = 0
var _active: bool = false

# Controls
var _dim: ColorRect
var _bubble: Panel
var _title_label: Label
var _step_label: Label
var _body_label: Label
var _next_btn: Button
var _skip_btn: Button

# Callbacks
var on_tutorial_finished: Callable = Callable()


func _ready() -> void:
	layer = 50
	_build()
	hide_overlay()


# ---------- public API ----------

func start() -> void:
	_step = 0
	_active = true
	_refresh_text()
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
	if not _active or _step != 0:
		return
	_advance()


# Called when the player clicks any hotspot.
func notify_hotspot_clicked() -> void:
	if not _active or _step != 1:
		return
	_advance()


# Called when a night ends successfully (we treat "you got to dawn" as
# the tutorial gate, not a per-night end).
func notify_night_succeeded() -> void:
	if not _active or _step != 2:
		return
	_advance()


func is_active() -> bool:
	return _active


func current_step() -> int:
	return _step


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


func _refresh_text() -> void:
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
	_step_label.text = I18nRef.t("tutorial_step_indicator", [_step + 1])


func show_overlay() -> void:
	if _dim:
		_dim.visible = true
	if _bubble:
		_bubble.visible = true
	if _skip_btn:
		_skip_btn.visible = true


func hide_overlay() -> void:
	if _dim:
		_dim.visible = false
	if _bubble:
		_bubble.visible = false
	if _skip_btn:
		_skip_btn.visible = false


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

	# Bubble at the bottom center
	_bubble = Panel.new()
	_bubble.size = Vector2(BUBBLE_W, BUBBLE_H)
	_bubble.position = Vector2((1280.0 - BUBBLE_W) * 0.5, 720.0 - BUBBLE_H - 32.0)
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
	_title_label.add_theme_constant_override("font_size", 24)
	_title_label.add_theme_constant_override("outline_size", 3)
	_bubble.add_child(_title_label)

	# Body
	_body_label = Label.new()
	_body_label.position = Vector2(20, 84)
	_body_label.size = Vector2(BUBBLE_W - 40, 70)
	_body_label.add_theme_constant_override("font_size", 16)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.add_child(_body_label)

	# "Got it" button (bottom-right of bubble)
	_next_btn = Button.new()
	_next_btn.text = I18nRef.t("tutorial_next")
	_next_btn.position = Vector2(BUBBLE_W - 160, BUBBLE_H - 50)
	_next_btn.size = Vector2(140, 36)
	_next_btn.pressed.connect(_on_next_pressed)
	_bubble.add_child(_next_btn)


func _on_next_pressed() -> void:
	# Manual advance: skip the gate for the current step.
	_advance()