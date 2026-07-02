class_name NightCGOverlay
extends CanvasLayer
# Per-night opening CG keyframe. Mounted by NightShiftGame._build_cg_overlay
# and shown at the top of every night (before _process ticks time forward).
# The player reads the story blurb + sees the cinematic, then clicks the
# "Start the night" button. The host pauses night_paused until dismiss.
#
# Wiring:
#   - Host calls start(night_index, cg_path, story_text) at _start_night.
#   - When the player clicks, dismiss() fires on_dismissed so the host
#     clears night_paused.
#   - is_active() lets the host skip gameplay updates while up.
#
# Design notes:
#   - Lives at layer 60 — above tutorial_overlay (50) so the CG occludes
#     the 3-step move/repair/survive walkthrough for the first night.
#   - Story text comes from NightShiftLevels.LEVELS (story_intro / en),
#     NOT from chapter_01_nights.json (which is event-only).
#   - One overlay instance is reused across all 10 nights.

const I18nRef := preload("res://scripts/I18n.gd")

const BUBBLE_W := 1080.0
const BUBBLE_H := 220.0

var _active: bool = false

var _dim: ColorRect
var _image: TextureRect
var _bubble: Panel
var _title_label: Label
var _body_label: Label
var _start_btn: Button

var on_dismissed: Callable = Callable()


func _ready() -> void:
	layer = 60
	_build()
	hide_overlay()


# ---------- public API ----------

func start(night_index: int, cg_path: String, story_text: String) -> void:
	_active = true
	var tex: Variant = null
	if cg_path != "":
		tex = load(cg_path)
	if tex is Texture2D:
		_image.texture = tex
		_image.visible = true
	else:
		# Fallback: missing CG shouldn't block the player from playing.
		# Show the bubble without a backdrop image.
		_image.texture = null
		_image.visible = false
	# Pass int directly — I18n.t() does `raw % args` with printf-style
	# format strings ("第 %d 夜"), so a stringified arg would crash on
	# the %d spec.
	_title_label.text = I18nRef.t("cg_night_title", [night_index + 1])
	_body_label.text = story_text if story_text != "" else ""
	show_overlay()


func dismiss() -> void:
	if not _active:
		return
	_active = false
	hide_overlay()
	if on_dismissed.is_valid():
		on_dismissed.call()


func is_active() -> bool:
	return _active


# ---------- internals ----------

func show_overlay() -> void:
	if _dim: _dim.visible = true
	if _image: _image.visible = _image.texture != null
	if _bubble: _bubble.visible = true
	if _start_btn: _start_btn.visible = true


func hide_overlay() -> void:
	if _dim: _dim.visible = false
	if _image: _image.visible = false
	if _bubble: _bubble.visible = false
	if _start_btn: _start_btn.visible = false


# ---------- UI build ----------

func _build() -> void:
	# Dim layer (deep, to make the CG frame read as cinematic)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.82)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)

	# CG image (fullscreen, keep aspect, centered)
	_image = TextureRect.new()
	_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_image.offset_left = 16.0
	_image.offset_right = -16.0
	_image.offset_top = 16.0
	_image.offset_bottom = -(BUBBLE_H + 64.0)
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_image.visible = false
	add_child(_image)

	# Bottom bubble with story text + start button
	_bubble = Panel.new()
	_bubble.size = Vector2(BUBBLE_W, BUBBLE_H)
	_bubble.position = Vector2((1280.0 - BUBBLE_W) * 0.5, 720.0 - BUBBLE_H - 24.0)
	_bubble.visible = false
	add_child(_bubble)

	_title_label = Label.new()
	_title_label.position = Vector2(28.0, 18.0)
	_title_label.size = Vector2(BUBBLE_W - 56.0, 38.0)
	_title_label.add_theme_constant_override("font_size", 26)
	_title_label.add_theme_constant_override("outline_size", 4)
	_bubble.add_child(_title_label)

	_body_label = Label.new()
	_body_label.position = Vector2(28.0, 66.0)
	_body_label.size = Vector2(BUBBLE_W - 56.0, BUBBLE_H - 110.0)
	_body_label.add_theme_constant_override("font_size", 16)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.vertical_alignment = 0  # top — Godot 4.3 VerticalAlignment enum (0 = TOP)
	_bubble.add_child(_body_label)

	_start_btn = Button.new()
	_start_btn.text = I18nRef.t("cg_start_night")
	_start_btn.position = Vector2(BUBBLE_W - 240.0, BUBBLE_H - 60.0)
	_start_btn.size = Vector2(210.0, 44.0)
	_start_btn.add_theme_constant_override("font_size", 18)
	_start_btn.pressed.connect(dismiss)
	_bubble.add_child(_start_btn)