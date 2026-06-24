class_name FxLayerNode
extends Node2D
# Draw-only Node2D that renders the procedural FX stack owned by
# NightShiftGame (particles, telegraph warning rings, shake offset,
# off-screen threat arrows).
#
# References are injected at build time so this script never reaches back
# into NightShiftGame. The owning game calls _fx_set_refs(...) once after
# adding this node to the scene.

# Preload the FX helper instead of relying on its class_name (which would
# require a project-wide editor re-scan to populate global_script_class_cache).
const Fx := preload("res://scripts/NightShiftFx.gd")
const SCREEN_SIZE := Vector2(1280, 720)

var _particles: Array = []
var _telegraphs: Array = []
var _shake_state: Dictionary = {"amount": 0.0, "decay": 6.0, "freq": 28.0, "phase": 0.0}
var _hotspot_positions: Dictionary = {}  # id -> Vector2
var _threat_arrows: Array = []
var _threat_phase: float = 0.0
var _static_alpha: float = 0.0
var _dawn_alpha: float = 0.0


func _fx_set_refs(particles: Array, telegraphs: Array, shake_state: Dictionary, hotspot_positions: Dictionary) -> void:
	_particles = particles
	_telegraphs = telegraphs
	_shake_state = shake_state
	_hotspot_positions = hotspot_positions


func _fx_set_threat_arrows(arrows: Array, phase: float) -> void:
	_threat_arrows = arrows
	_threat_phase = phase


func _fx_set_overlays(static_alpha: float, dawn_alpha: float) -> void:
	_static_alpha = static_alpha
	_dawn_alpha = dawn_alpha


# Called by the game whenever positions / counts change. Avoids stale cache.
func _fx_mark_dirty() -> void:
	queue_redraw()


func _draw() -> void:
	# Apply shake offset to the entire FX layer so particles drift with the
	# camera-like jiggle. We don't translate the parent (which would move the
	# hotspot buttons too); the FX are decoupled.
	var offset: Vector2 = Fx.shake_offset(_shake_state)
	# Particles
	Fx.draw_particles(self, _particles)
	# Telegraph warning rings — pulsing concentric circles around the
	# target hotspot, fading as the timer runs out. These render BEFORE
	# the particles so the ring sits underneath the burst.
	for t in _telegraphs:
		var id: String = str(t.get("hotspot_id", ""))
		if not _hotspot_positions.has(id):
			continue
		var pos: Vector2 = (_hotspot_positions[id] as Vector2) + offset
		var ratio: float = clamp(
			float(t.get("time_left", 0.0)) / max(0.001, float(t.get("total_time", 1.0))),
			0.0, 1.0
		)
		var alpha: float = Fx.telegraph_pulse_alpha(t)
		var base_radius: float = 30.0 + (1.0 - ratio) * 40.0
		var ring_color := Color(1.0, 0.7, 0.2, alpha * 0.85)
		draw_arc(pos, base_radius, 0.0, TAU, 32, ring_color, 3.0)
		var inner_color := Color(1.0, 0.4, 0.1, alpha * 0.35)
		draw_arc(pos, base_radius * 0.55, 0.0, TAU, 24, inner_color, 2.0)
		# "!" exclamation mark — three small rects to read at a glance.
		var bar_w: float = 4.0
		var bar_h: float = 16.0
		var cx: float = pos.x
		var cy: float = pos.y - base_radius - 16.0
		draw_rect(Rect2(cx - bar_w * 0.5, cy, bar_w, bar_h), Color(1, 0.8, 0.3, alpha))
		draw_rect(Rect2(cx - bar_w * 0.5, cy + bar_h + 4.0, bar_w, bar_w), Color(1, 0.8, 0.3, alpha))
	# Off-screen threat arrows. Drawn last so they overlay particles + rings.
	_draw_threat_arrows(offset)
	# Static noise overlay — when radio is tuned to static channel.
	_draw_static_noise(offset)
	# Dawn fade — drawn last so it overlays everything.
	_draw_dawn_fade()


func _draw_threat_arrows(offset: Vector2) -> void:
	if _threat_arrows.is_empty():
		return
	var margin: float = 64.0
	var pulse: float = 0.5 + 0.5 * sin(_threat_phase * 5.0)
	for a in _threat_arrows:
		var target_pos: Vector2 = (a["target_pos"] as Vector2) + offset
		var player_pos: Vector2 = a["player_pos"] as Vector2
		var to_target: Vector2 = target_pos - player_pos
		if to_target.length() < 1.0:
			continue
		var dir: Vector2 = to_target.normalized()
		# Find the edge of the screen where the arrow should sit. Clamp to
		# the inside-margin rectangle so it never overlaps the HUD chrome.
		var edge_x: float = margin
		var edge_y: float = margin
		if dir.x > 0.0:
			edge_x = SCREEN_SIZE.x - margin
		if dir.y > 0.0:
			edge_y = SCREEN_SIZE.y - margin
		# Solve for intersection with the edge rectangle. Parametric line:
		#   p = player_pos + t * dir
		#   hits x = edge_x or y = edge_y, whichever is closer.
		var t_x: float = INF
		var t_y: float = INF
		if abs(dir.x) > 0.001:
			t_x = (edge_x - player_pos.x) / dir.x
		if abs(dir.y) > 0.001:
			t_y = (edge_y - player_pos.y) / dir.y
		var t: float = min(t_x, t_y)
		if t <= 0.0:
			continue
		var pos: Vector2 = player_pos + dir * t
		# Clamp to inside the safe area (in case of corner cases).
		pos.x = clamp(pos.x, margin, SCREEN_SIZE.x - margin)
		pos.y = clamp(pos.y, margin, SCREEN_SIZE.y - margin)

		var strength: float = float(a.get("strength", 0.5))
		var color := Color(1.0, 0.35, 0.2, 0.65 + 0.35 * pulse)
		color.a *= strength
		# Triangle arrow, ~22px tall, pointing in dir.
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var tip: Vector2 = pos + dir * 14.0
		var base_a: Vector2 = pos - dir * 8.0 + perp * 9.0
		var base_b: Vector2 = pos - dir * 8.0 - perp * 9.0
		var pts := PackedVector2Array([tip, base_a, base_b])
		draw_colored_polygon(pts, color)
		# Soft halo behind for legibility on any background.
		var halo := Color(0.0, 0.0, 0.0, 0.4 * strength)
		draw_colored_polygon(PackedVector2Array([tip + dir * 2.0, base_a + perp * 2.0, base_b - perp * 2.0]), halo)


func _draw_static_noise(offset: Vector2) -> void:
	if _static_alpha <= 0.01:
		return
	# Procedural static — horizontal scanlines with random brightness. Two
	# color tones (cool blue / warm white) sampled per band give a noisy
	# feeling without needing a noise texture asset.
	var bands: int = 36
	var band_h: float = SCREEN_SIZE.y / float(bands)
	for i in bands:
		var y: float = float(i) * band_h
		# Pseudo-random brightness seeded by band index + frame phase so it
		# shifts subtly without flickering too fast.
		var seed: float = float(i) * 7.31 + _threat_phase * 1.7
		var brightness: float = 0.5 + 0.5 * sin(seed) * 0.5 + 0.5 * cos(seed * 1.7 + 1.3) * 0.5
		var tone: float = fmod(seed * 0.317, 1.0)
		var color := Color(
			0.55 + 0.25 * tone,
			0.55 + 0.25 * (1.0 - tone),
			0.7 + 0.15 * brightness,
			_static_alpha * (0.35 + 0.45 * brightness)
		)
		draw_rect(Rect2(0.0, y, SCREEN_SIZE.x, band_h), color)
	# Scanline darken — horizontal stripes every 4px to evoke CRT.
	var stripe_h: float = 4.0
	var n_stripes: int = int(SCREEN_SIZE.y / stripe_h)
	for j in n_stripes:
		if j % 2 == 0:
			continue
		draw_rect(
			Rect2(0.0, float(j) * stripe_h, SCREEN_SIZE.x, stripe_h),
			Color(0.0, 0.0, 0.0, _static_alpha * 0.25)
		)


func _draw_dawn_fade() -> void:
	if _dawn_alpha <= 0.001:
		return
	# A warm dawn gradient — bottom-heavy yellow / amber that fades to
	# transparent at the top, conveying sunrise creeping in.
	var bands: int = 18
	var band_h: float = SCREEN_SIZE.y / float(bands)
	for i in bands:
		var y: float = float(i) * band_h
		# Fade out toward the top so the dawn is anchored to the bottom of
		# the screen. Band 0 = bottom, band bands-1 = top.
		var t: float = float(bands - 1 - i) / float(bands - 1)
		var alpha_factor: float = pow(t, 1.4)
		var color := Color(
			0.95,
			0.78 + 0.18 * t,
			0.5 + 0.4 * t,
			_dawn_alpha * alpha_factor * 0.85
		)
		draw_rect(Rect2(0.0, y, SCREEN_SIZE.x, band_h), color)
	# White flash overlay (the moment of sunrise)
	if _dawn_alpha > 0.5:
		var flash_alpha: float = (_dawn_alpha - 0.5) * 0.6
		draw_rect(Rect2(0.0, 0.0, SCREEN_SIZE.x, SCREEN_SIZE.y), Color(1.0, 0.95, 0.85, flash_alpha))
