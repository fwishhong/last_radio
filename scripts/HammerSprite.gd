class_name HammerSprite
extends Node2D
# Procedural hammer sprite, drawn next to the player during repair ticks.
# The player_token itself stays perfectly still (no tilt / bob) -- only
# this hammer sprite rotates so the swing reads visually without warping
# the player silhouette.
#
# Geometry: short handle (brown rect) + heavier head (gray rect). Drawn
# around the node's local origin so NightShiftGame can position the
# sprite at the player's hand offset and drive rotation from the same
# PlayerRepairFx REPAIR_CYCLE_SEC phase that the FX layer uses.
#
# polish spec §4.5 / round-2 visual fix -- replaces the previous
# player_repair_*.png overlay (alpha=0 pixels carried RGB 255/30/82
# for start/mid/end, producing a visible colored halo).

const HEAD_COLOR := Color(0.62, 0.62, 0.66)
const HEAD_EDGE := Color(0.34, 0.34, 0.38)
# round-2.1: handle color brightened + saturated for a more obvious
# tool silhouette. Previous (0.42, 0.28, 0.18) was muddy dark-walnut
# that read as "shadow strip" against the dark room. New (0.68, 0.40,
# 0.18) is a clear warm-cedar / varnished-oak that pops against the
# player silhouette and matches the brown palette of the radio
# cabinet / medbay crate props.
const HANDLE_COLOR := Color(0.68, 0.40, 0.18)
const HANDLE_EDGE := Color(0.36, 0.20, 0.08)

# Local-space geometry (hammer points "up" at rotation = 0).
# The hand grips the bottom of the handle, head is at the top.
# Sized so the hammer reads at 1280x720 (the production viewport).
# At 1.0 scale that's ~7px wide for the handle and ~28x14 for the
# head -- clearly visible as a hammer silhouette without dwarfing
# the player_token (128x160).
const HANDLE_W := 7.0
const HANDLE_H := 38.0
const HEAD_W := 28.0
const HEAD_H := 14.0


func _draw() -> void:
	# Handle: vertical brown rect, bottom at y=0 (the grip), top at y=-HANDLE_H.
	var handle_rect := Rect2(
		-HANDLE_W * 0.5, -HANDLE_H,
		HANDLE_W, HANDLE_H
	)
	draw_rect(handle_rect, HANDLE_COLOR, true)
	draw_rect(handle_rect, HANDLE_EDGE, false, 1.0)
	# Head: horizontal gray rect, centered on the top of the handle.
	var head_rect := Rect2(
		-HEAD_W * 0.5, -HANDLE_H - HEAD_H,
		HEAD_W, HEAD_H
	)
	draw_rect(head_rect, HEAD_COLOR, true)
	draw_rect(head_rect, HEAD_EDGE, false, 1.0)
	# Subtle highlight stripe on the head (top edge) to give it depth.
	draw_line(
		Vector2(-HEAD_W * 0.5 + 1.0, -HANDLE_H - HEAD_H + 1.5),
		Vector2(HEAD_W * 0.5 - 1.0, -HANDLE_H - HEAD_H + 1.5),
		Color(1.0, 1.0, 1.0, 0.35), 1.0
	)
