class_name WorldLayerFx
extends RefCounted
# World-layer parallax + outside-zombie sprites for NightShiftGame.
#
# Layer stack (back to front, lower z_index draws first):
#   1. outside_world_far    (parallax depth 0, almost static)
#   2. outside_world_mid    (parallax depth 1, drifts slowly)
#   3. room bg              (stadium_room_topdown.png)
#   4. hotspot_layer        (red value circles + integrity bars)
#   5. zombie_outside_layer (independent sprites at door/window hotspots)
#   6. fx_layer             (telegraph rings, particles, shake offset)
#   7. fx_critical_overlay  (screen border pulse)
#
# The module is a static utility — NightShiftGame owns the Sprite2D
# nodes (so they have proper z_index / parallax transforms) and passes
# state in. This mirrors the NightShiftFx pattern.

# ---- Animation phases for outside-zombie sprites -----------------------

const ZOMBIE_PHASE_HIDDEN := 0
const ZOMBIE_PHASE_APPROACH := 1   # fading in, slow vertical bob
const ZOMBIE_PHASE_IMMINENT := 2   # faster bob, slight zoom, brighter
const ZOMBIE_PHASE_BREACH := 3     # breach sprite, jitter shake


# Map a telegraph entry + per-sprite accumulator to display state.
# Call this every frame the sprite is alive; mutate `acc` in place so
# the sway phase persists across frames.
# Returns {phase, alpha, bob_y, scale}.
static func zombie_phase_from_telegraph(
	t: Dictionary, dt: float, acc: Dictionary
) -> Dictionary:
	var total: float = max(0.001, float(t.get("total_time", 1.0)))
	var left: float = float(t.get("time_left", 0.0))
	var ratio: float = clamp(left / total, 0.0, 1.0)
	# Advance sway phase every frame regardless of phase
	acc["sway_phase"] = float(acc.get("sway_phase", 0.0)) + dt
	var sp: float = float(acc["sway_phase"])
	var phase: int = ZOMBIE_PHASE_HIDDEN
	var alpha: float = 0.0
	var bob_y: float = 0.0
	var scale: float = 1.0
	if left <= 0.0:
		phase = ZOMBIE_PHASE_BREACH
		alpha = 1.0
		# High-frequency jitter so the breach frame looks like impact
		bob_y = sin(sp * 38.0) * 2.5 + sin(sp * 17.0) * 1.5
	elif ratio <= 0.3:
		phase = ZOMBIE_PHASE_IMMINENT
		# Alpha ramps up as the timer drains (0.3 → 0.0)
		alpha = clamp(1.0 - (ratio / 0.3) * 0.3, 0.7, 1.0)
		bob_y = sin(sp * 4.5) * 4.5
		scale = 1.06
	else:
		phase = ZOMBIE_PHASE_APPROACH
		# Fade in as timer drains — first telegraph frame alpha≈0,
		# moment-of-breach frame alpha=1
		alpha = clamp(1.0 - ratio, 0.0, 1.0)
		bob_y = sin(sp * 1.4) * 2.5
		scale = 1.0
	return {
		"phase": phase,
		"alpha": alpha,
		"bob_y": bob_y,
		"scale": scale,
	}


# Cosmetic state for a hotspot that is NOT telegraphing but IS being
# assaulted — show the zombie at low alpha for the "watching through
# the door" feeling even before the lead-time warning fires.
static func zombie_phase_persisting(acc: Dictionary, dt: float) -> Dictionary:
	acc["sway_phase"] = float(acc.get("sway_phase", 0.0)) + dt
	var sp: float = float(acc["sway_phase"])
	return {
		"phase": ZOMBIE_PHASE_APPROACH,
		"alpha": 0.45,
		"bob_y": sin(sp * 1.2) * 2.0,
		"scale": 1.0,
	}


# Pure hidden state. Resets the sway phase so the next appearance
# starts from the bottom of the bob cycle.
static func zombie_phase_hidden(acc: Dictionary) -> Dictionary:
	acc["sway_phase"] = 0.0
	return {
		"phase": ZOMBIE_PHASE_HIDDEN,
		"alpha": 0.0,
		"bob_y": 0.0,
		"scale": 1.0,
	}


# Parallax offset for a given depth layer. depth=0 far, 1 mid, 2 near.
# `phase` should advance each frame (use the same one for all layers so
# they drift coherently). `magnitude` caps the max pixel drift.
static func parallax_offset(phase: float, depth: int, magnitude: float = 8.0) -> Vector2:
	var s: float = float(depth + 1)
	var k: float = magnitude * 0.15 * s
	return Vector2(
		sin(phase * (0.27 + 0.08 * float(depth))) * k,
		cos(phase * (0.36 + 0.05 * float(depth))) * k * 0.7
	)


# Per-hotspot anchor offset for the zombie sprite.
# Round-4 visual fix: zombie stands on the OUTSIDE of the door/window,
# partially off-screen, so the silhouette reads as "standing outside
# the door / peering through the broken window" rather than "haunting
# inside the room". Round-1 used offsets of -260 / +/-280 which pushed
# the sprite fully off-screen (nothing to read); round-3 inverted the
# direction (+130 / +/-200) and ended up with the zombie inside the
# room — user feedback: "僵尸要在画面里,不在屋里,要在门口,及窗口".
# Round-4 keeps the round-1 OUTSIDE direction but shrinks the magnitude
# so the bottom / inner half of the body remains on screen.
#
# Zombie texture is 1434x1920 at scale 0.18 → ~258x346 px on screen
# (half-width 129, half-height 173). On-screen coverage for each anchor:
#
#   front_door  (640, 85)  + (0,   -120) → centre (640, -35)
#     body y ∈ [-208, 138]; visible [0, 138] (138px ≈ waist-down).
#   back_door   (1000, 80) + (0,   -120) → centre (1000, -40)
#     body y ∈ [-213, 133]; visible [0, 133].
#   left_window (270, 250) + (-150, 0)  → centre (120, 250)
#     body x ∈ [-9, 249]; visible [-9..129] exits on the left edge,
#     right half [120, 249] stays in.
#   right_window(1080, 200)+ (150, 0)  → centre (1230, 200)
#     body x ∈ [1101, 1359]; left half stays in, right edge exits.
static func zombie_anchor_offset(hotspot_id: String) -> Vector2:
	# Doors: zombie stands ABOVE the hotspot (outside the door, in the
	# dark beyond the top wall). Top half of the body exits the screen,
	# the bottom half hangs into view from above the door.
	if hotspot_id == "front_door":
		return Vector2(0.0, -120.0)
	if hotspot_id == "back_door":
		return Vector2(0.0, -120.0)
	# Windows: zombie stands to the OUTSIDE side of the window. Half
	# the body exits the screen on the window's outer edge, the inner
	# half remains in view (zombie leaning in / peering through the
	# broken pane).
	if hotspot_id == "left_window":
		return Vector2(-150.0, 0.0)
	if hotspot_id == "right_window":
		return Vector2(150.0, 0.0)
	# Fallback (any other barrier hotspot) — outside the door / window
	return Vector2(0.0, -120.0)
