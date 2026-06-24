class_name HammerSprite
extends Sprite2D
# Art-based hammer sprite, drawn next to the player during repair ticks.
# The player_token itself stays perfectly still (no tilt / bob) -- only
# this hammer sprite rotates so the swing reads visually without warping
# the player silhouette.
#
# polish spec §4.5 / round-2 visual fix -- the round-2 baseline used a
# procedural hammer (Node2D + _draw rects); round-2.1 (commit 3b1b7e3)
# brightened the procedural handle color to warm-cedar and bumped the
# over-arm thrust to 1.8 rad. M13 ships the AI-generated art-based
# replacement: a 1024x1024 hammer PNG with hand-grip pivot offset so
# rotation happens at the handle bottom (matches procedural behavior).
#
# Falls back gracefully if the PNG is missing -- the Sprite2D stays
# invisible (texture = null) rather than crashing, so future asset
# pipeline mishaps don't break the night-shift gameplay loop.

# Path to the AI-generated art hammer (matrix MCP, 1024x1024 RGBA,
# generated 2026-06-24 -- see CHANGELOG M13).
const ART_PATH := "res://assets/final/night_shift/player_hammer_art.png"

# Pivot offset so rotation happens at the handle grip, not the texture
# center. The art PNG (1024x1024) has its handle grip at (209.1, 855.0);
# texture center is (512, 512). Offset = grip - center, which means
# rotation pivots around the bottom of the handle, matching where the
# player's hand grips it.
const PIVOT_OFFSET := Vector2(-302.9, 343.0)

# Art hammer is 1024x1024; at 1.0 scale that dwarfs the 128x160
# player_token. Scale 1/16 -> ~64px wide hammer, comparable in visual
# weight to the round-2.1 procedural hammer (28px head + 38px handle).
const ART_SCALE := 1.0 / 16.0


func _ready() -> void:
	centered = true
	offset = PIVOT_OFFSET
	scale = Vector2(ART_SCALE, ART_SCALE)
	if ResourceLoader.exists(ART_PATH):
		var tex: Resource = load(ART_PATH)
		if tex is Texture2D:
			texture = tex
		else:
			push_warning("HammerSprite: %s loaded but is not a Texture2D" % ART_PATH)
	else:
		push_warning("HammerSprite: art PNG not found at %s, sprite will be invisible" % ART_PATH)