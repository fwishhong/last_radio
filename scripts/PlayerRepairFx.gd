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
# Tuned for a deliberate, weighty hammer rhythm: a 0.7s cycle yields
# ~1.4 swings per repair bar (REPAIR_RATE in NightShiftGame gives ~1s
# per +0.05 value bar). Round-5 visual fix per user feedback: the
# round-4 0.36s cycle read as frantic / jittery; slowing to 0.7s
# makes each strike land with a clear beat and the recovery arc
# becomes visible instead of blurring into the next swing.
const REPAIR_CYCLE_SEC := 0.7

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
# Round-3 visual fix: also include "generator" so the player sees a
# hammer swing when restoring power. Radio and medbay have their own
# interaction flows (radio tuning / heal animations, not hammer).
static func is_repairable_hotspot(kind: String) -> bool:
	return kind == "barrier" or kind == "generator"