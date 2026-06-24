class_name PlayerRepairFx
extends RefCounted
# Player repair-action animation, shown while the player is actively
# repairing a barrier hotspot (door or window). 3-frame hammer cycle:
#
#   REPAIR_FRAME_START  hammer raised high above head
#   REPAIR_FRAME_MID    hammer coming down on plank
#   REPAIR_FRAME_END    hammer impacted plank (wood chips / sparks)
#
# Module is a static utility -- NightShiftGame owns the Sprite2D node
# (so it has proper z_index + position) and passes the active timer
# in. Mirrors the WorldLayerFx / NightShiftFx pattern.

# Frame constants
const REPAIR_FRAME_START := 0
const REPAIR_FRAME_MID := 1
const REPAIR_FRAME_END := 2
const REPAIR_FRAME_COUNT := 3

# Cycle period for one full swing (start -> mid -> end -> start).
# Tuned so it reads as a fast, urgent hammering rhythm; the existing
# REPAIR_RATE in NightShiftGame gives ~1s per +0.05 value bar, so a
# 0.36s cycle means ~3 swings per repair bar.
const REPAIR_CYCLE_SEC := 0.36

# How much the body should bob / lean during the swing, in pixels.
# Subtle so it reads as animation rather than as separate sprites
# overlapping.
const REPAIR_BOB_AMPLITUDE := 6.0


# Map an accumulating timer to the current frame index.
# `timer` should advance each frame the player is repairing; on
# wraparound (player walks away) it should be reset to 0 so the
# next repair starts cleanly from REPAIR_FRAME_START.
static func repair_frame_for(timer: float) -> int:
	var t: float = max(0.0, timer)
	var phase: float = fmod(t, REPAIR_CYCLE_SEC) / REPAIR_CYCLE_SEC
	# 0..1/3 START, 1/3..2/3 MID, 2/3..1 END
	if phase < 1.0 / 3.0:
		return REPAIR_FRAME_START
	if phase < 2.0 / 3.0:
		return REPAIR_FRAME_MID
	return REPAIR_FRAME_END


# Per-frame cosmetic offset (relative to player_pos).
# The body dips slightly at MID and bottoms out at END, then springs
# back to the START pose. Returns Vector2 in pixels.
static func repair_bob_for(timer: float) -> Vector2:
	var t: float = max(0.0, timer)
	var phase: float = fmod(t, REPAIR_CYCLE_SEC) / REPAIR_CYCLE_SEC
	# Single sin curve driven by phase; negative on the down-swing.
	var wave: float = sin(phase * TAU)
	return Vector2(0.0, -wave * REPAIR_BOB_AMPLITUDE * 0.5)


# Per-frame scale tweak. The character "leans in" during the down-swing.
# Returns Vector2 multipliers (1.0 = baseline).
static func repair_scale_for(timer: float) -> Vector2:
	var t: float = max(0.0, timer)
	var phase: float = fmod(t, REPAIR_CYCLE_SEC) / REPAIR_CYCLE_SEC
	var wave: float = sin(phase * TAU)
	# Slight forward squash on impact: y squashes a touch, x widens
	var sx: float = 1.0 + wave * 0.03
	var sy: float = 1.0 - wave * 0.02
	return Vector2(sx, sy)


# Helper: is a hotspot the kind that triggers repair animation?
# Only "barrier" (door / window) hotspots take player repair ticks.
# Radio and medbay have their own interaction flows.
static func is_repairable_hotspot(kind: String) -> bool:
	return kind == "barrier"