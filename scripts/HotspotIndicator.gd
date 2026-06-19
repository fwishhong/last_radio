extends Node2D

var value := 100.0
var active := false
var warning := false
var assault := false
var braced := false
var blackout := false
var radio_call := false
var selected := false
var radius := 30.0


func configure(indicator_radius: float) -> void:
	radius = indicator_radius
	queue_redraw()


func set_state(data: Dictionary, is_selected: bool, is_blackout: bool, is_radio_call: bool) -> void:
	value = clamp(float(data.get("value", 100.0)), 0.0, 120.0)
	active = bool(data.get("active", false))
	warning = bool(data.get("warning", false))
	assault = bool(data.get("assault", false))
	braced = bool(data.get("braced", false)) or float(data.get("temp_seal", 0.0)) > 0.0
	selected = is_selected
	blackout = is_blackout
	radio_call = is_radio_call
	queue_redraw()


func _draw() -> void:
	var value_ratio: float = clamp(value / 100.0, 0.0, 1.0)
	var is_active: bool = active or warning or assault or value < 92.0 or radio_call or blackout
	var color := _indicator_color(value_ratio)
	var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 160.0)
	var ring_alpha: float = 0.54 if is_active else 0.25
	if warning or assault or radio_call:
		ring_alpha = 0.72 + pulse * 0.2
	if selected:
		ring_alpha = 0.95
	draw_circle(Vector2.ZERO, radius + 7.0 + pulse * 3.0, Color(color.r, color.g, color.b, 0.08 if is_active else 0.035))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(color.r, color.g, color.b, ring_alpha), 4.0, true)
	draw_arc(Vector2.ZERO, radius + 6.0, -PI / 2.0, -PI / 2.0 + TAU * value_ratio, 96, Color(0.92, 0.96, 0.88, 0.9), 3.0, true)
	if selected:
		draw_arc(Vector2.ZERO, radius + 11.0, 0.0, TAU, 96, Color(1.0, 1.0, 1.0, 0.9), 2.0, true)
	var bar_size := Vector2(92, 10)
	var bar_pos := Vector2(-bar_size.x * 0.5, radius + 13.0)
	draw_rect(Rect2(bar_pos + Vector2(1, 2), bar_size), Color(0, 0, 0, 0.46), true)
	draw_rect(Rect2(bar_pos, bar_size), Color(0.04, 0.05, 0.055, 0.84), true)
	draw_rect(Rect2(bar_pos, Vector2(bar_size.x * value_ratio, bar_size.y)), color, true)
	draw_rect(Rect2(bar_pos, bar_size), Color(0.82, 0.86, 0.78, 0.65), false, 1.5)


func _indicator_color(value_ratio: float) -> Color:
	if radio_call:
		return Color(0.30, 0.78, 1.0, 0.94)
	if blackout:
		return Color(0.55, 0.58, 0.68, 0.95)
	if assault or value_ratio < 0.35:
		return Color(1.0, 0.23, 0.16, 0.96)
	if warning or value_ratio < 0.62:
		return Color(1.0, 0.72, 0.20, 0.95)
	if braced:
		return Color(0.45, 0.78, 1.0, 0.94)
	return Color(0.42, 0.95, 0.54, 0.88)
