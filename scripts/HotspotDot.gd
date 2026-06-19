class_name HotspotDot
extends Node2D

# A circular hotspot indicator drawn with _draw().
# Outer ring + inner color fill + breach glow, all sized for a 72x72 button.
# Button is responsible for positioning; this node draws relative to (0,0).
# We use the center of the button (36, 36) as the dot center for visual clarity.

const RADIUS := 26.0
const RING_WIDTH := 4.0
const INNER_RADIUS := 22.0
const CENTER := Vector2(36, 36)

var _integrity: float = 1.0
var _breached: bool = false
var _is_current_target: bool = false
var _is_locked: bool = false
var _is_active: bool = false
var _warning: bool = false
var _pulse: float = 0.0  # 0..1, externally set per frame

func set_state(integrity: float, breached: bool, is_current_target: bool, is_locked: bool, is_active: bool, warning: bool, pulse: float) -> void:
	_integrity = integrity
	_breached = breached
	_is_current_target = is_current_target
	_is_locked = is_locked
	_is_active = is_active
	_warning = warning
	_pulse = pulse
	queue_redraw()

func _color_for_state() -> Color:
	if _is_locked:
		return Color(0.42, 0.45, 0.50)
	if _breached:
		return Color(0.94, 0.27, 0.27)
	if _integrity >= 0.7:
		return Color(0.29, 0.87, 0.50)
	if _integrity >= 0.3:
		return Color(0.98, 0.80, 0.08)
	return Color(0.98, 0.45, 0.09)

func _draw() -> void:
	var color: Color = _color_for_state()
	var pulse_alpha: float = 1.0
	if _breached:
		pulse_alpha = 0.55 + 0.45 * _pulse

	# Breach glow halo (drawn first, soft red ring)
	if _breached:
		var glow_a: float = (0.3 + 0.4 * _pulse) * 0.6
		draw_circle(CENTER, RADIUS + 5, Color(0.94, 0.27, 0.27, glow_a))

	# Locked: just a gray hollow ring + dark center dot
	if _is_locked:
		draw_arc(CENTER, RADIUS, 0, TAU, 32, Color(0.45, 0.45, 0.5, 0.85), RING_WIDTH)
		draw_circle(CENTER, 5.0, Color(0.1, 0.1, 0.12, 0.85))
		# Current-target highlight still applies
		if _is_current_target:
			draw_arc(CENTER, RADIUS + 3, 0, TAU, 48, Color(1.0, 0.95, 0.7, 0.9), 2.0)
		return

	# Faint background ring (the "track" — visible hollow under the progress arc)
	draw_arc(CENTER, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.18), RING_WIDTH)

	# Progress arc: 0 to integrity*TAU, state color, starts at top (12 o'clock)
	var end_angle: float = TAU * clamp(_integrity, 0.0, 1.0)
	if _integrity > 0.001:
		draw_arc(CENTER, RADIUS, -PI * 0.5, -PI * 0.5 + end_angle, 48,
				Color(color.r, color.g, color.b, 0.95 * pulse_alpha), RING_WIDTH + 1)

	# Breached: red solid center + red ring on top of the arcs
	if _breached:
		draw_circle(CENTER, RADIUS - 2, Color(0.94, 0.27, 0.27, 0.7))
		draw_arc(CENTER, RADIUS, 0, TAU, 48, Color(0.94, 0.27, 0.27, 0.95), RING_WIDTH)

	# Current target: bright cream outer accent ring
	if _is_current_target:
		draw_arc(CENTER, RADIUS + 3, 0, TAU, 48, Color(1.0, 0.95, 0.7, 0.95), 2.0)

	# Warning: pulsing orange inner ring (just inside the main ring)
	if _warning and not _breached:
		var a: float = 0.4 + 0.5 * _pulse
		draw_arc(CENTER, RADIUS - 5, 0, TAU, 32, Color(0.98, 0.45, 0.09, a), 2.0)

	# Active equipment: subtle cyan tick on the outer edge
	if _is_active and not _breached:
		draw_arc(CENTER, RADIUS + 1, 0, TAU, 24, Color(0.4, 0.85, 1.0, 0.5), 1.5)
