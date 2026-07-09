extends Node2D
class_name NpcSpriteLayer
# NPC field sprite layer — polish spec §4.3 + §5.2.
#
# Owns the in-scene rendering of joined NPCs (Nora / Elias currently, with
# hooks for future Lily / Tom). Sits between `enemy_layer` (procedural
# zombie circles) and `zombie_outside_layer` (window / door breach sprites)
# in the canvas z-order so NPC figures draw OVER enemy dots but UNDER the
# outside-window zombies. Per-frame behaviour:
#
#   * if previous_pos == current_pos (delta < 1.5 px) -> idle texture,
#     walking = false, walk_timer halts.
#   * else -> walking = true, dominant-axis facing pick from delta, walk
#     frame cycles every 0.15 s.
#
# Owner = NightShiftGame. The owner calls `refresh(npc_state, delta)` after
# each `_tick_npcs` write (line 3060 in NightShiftGame.gd). The owner also
# calls `add_ally(id, pos)` from the night-success unlock loop and
# `remove_ally(id)` from the day-card npc_remove path.

const ASSET_PATH := "res://assets/final/night_shift/"

# Idle textures keyed by npc_id. Resolved in _ready via load().
# Falls back to a tint placeholder if the .png isn't on disk (Lily / Tom
# haven't shipped yet — that path will use a tint fallback until M15+).
var idle_textures: Dictionary = {}

# Walk frames keyed by npc_id then direction. Each direction is an Array
# of 12 Texture2D frames. Resolved in _ready from the per-NPC .png files.
# Mirrors the `_build_walk_frames()` pattern at NightShiftGame.gd:621 so
# the player side and the NPC side stay parallel and decoupled.
var walk_frames_by_npc: Dictionary = {}

# Per-NPC runtime bookkeeping.
var sprites: Dictionary = {}         # npc_id -> Sprite2D (added to self)
var walking: Dictionary = {}         # npc_id -> bool
var facing: Dictionary = {}          # npc_id -> "up"|"down"|"left"|"right"
var walk_frame_idx: Dictionary = {}  # npc_id -> int (0..11)
var walk_timer: Dictionary = {}      # npc_id -> float accumulator (seconds)

# Idle vs walk threshold: a sub-1.5 px delta within a tick is treated as
# stationary so the layer doesn't flicker on tiny motion.
const MOVE_EPSILON := 1.5
# 0.15 s per walk frame ≈ 6.7 fps walk cycle. Matches the player side
# PLAYER_WALK_FPS cadence so NPC and player walk visually in step.
const WALK_FRAME_PERIOD := 0.15

# Default scale applied to the character_<id>.png idle art. The source
# PNG is 512x512 (verified via texture-load probe). 0.28 brings the
# body to ~143 px wide / ~143 px tall, matching the walk-frame
# footprint below so idle and walk read at the same visual scale.
const IDLE_SCALE := 0.28
# Walk frames are authored at 128x160 (verified). Scale 1.0 keeps the
# sprite at native size — the in-scene characters are meant to be
# small, readable shapes against the 1280x720 battlefield bg.
const WALK_SCALE := 1.0


func _init() -> void:
	# Asset loading happens in _init (not _ready) so the layer is usable
	# the instant it's constructed — the test harness adds the layer to
	# root then immediately exercises add_ally / refresh, with no frame
	# between to let _ready fire. The game path (NightShiftGame._ready
	# → add_child to canvas) also benefits since add_ally can be called
	# from _tick_npcs the very first frame.
	_load_idle_textures()
	_load_walk_frames()


# Build a Sprite2D for an NPC at start_pos, idle texture, add to self.
# Idempotent: calling twice is a no-op (we reuse the existing sprite).
# Returns the Sprite2D so the caller can pre-position it; the refresh()
# loop drives the texture swap and position from npc_state from here on.
func add_ally(npc_id: String, start_pos: Vector2) -> void:
	if sprites.has(npc_id):
		# Already added — keep the existing sprite, just snap position.
		var existing: Sprite2D = sprites[npc_id]
		existing.position = start_pos
		return
	var s := Sprite2D.new()
	s.name = "NpcSprite_%s" % npc_id
	s.centered = true
	s.position = start_pos
	# Initial texture: idle portrait, then the refresh loop swaps to walk
	# frames the first time the NPC starts moving.
	var idle: Texture2D = idle_textures.get(npc_id, null)
	s.texture = idle
	s.scale = Vector2(IDLE_SCALE, IDLE_SCALE)
	add_child(s)
	sprites[npc_id] = s
	walking[npc_id] = false
	facing[npc_id] = "down"
	walk_frame_idx[npc_id] = 0
	walk_timer[npc_id] = 0.0


# Tear down the Sprite2D and clear bookkeeping for one NPC. Idempotent.
func remove_ally(npc_id: String) -> void:
	if sprites.has(npc_id):
		var s: Sprite2D = sprites[npc_id]
		if s.get_parent() != null:
			s.get_parent().remove_child(s)
		s.queue_free()
	sprites.erase(npc_id)
	walking.erase(npc_id)
	facing.erase(npc_id)
	walk_frame_idx.erase(npc_id)
	walk_timer.erase(npc_id)


# Public refresh entry. Called from NightShiftGame._tick_npcs after the
# state write. For each NPC currently in npc_state, sync position, pick
# idle/walk texture based on the movement delta since the previous tick,
# and (if walking) advance the walk frame counter.
#
# npc_state : Dictionary npc_id -> {pos: Vector2, ...} — the same dict
#             NightShiftGame writes to from _tick_npcs.
# delta     : float seconds since last tick — drives walk frame advance.
func refresh(npc_state: Dictionary, delta: float) -> void:
	# Tear down sprites for NPCs no longer in npc_state (e.g. an npc_remove
	# effect that cleared npc_state[u] but the sprite stayed in the layer).
	# This is defensive — add_ally/remove_ally handle the normal path; this
	# covers any future code that prunes npc_state directly.
	var stale: Array = []
	for npc_id in sprites.keys():
		if not npc_state.has(npc_id):
			stale.append(npc_id)
	for npc_id in stale:
		remove_ally(npc_id)

	for npc_id in npc_state.keys():
		var st: Dictionary = npc_state[npc_id]
		var pos: Vector2 = st.get("pos", Vector2.ZERO)
		# First-time add for this NPC — caller (NightShiftGame) usually
		# calls add_ally() at unlock time, but if refresh is called before
		# the unlock-site path runs we self-bootstrap.
		if not sprites.has(npc_id):
			add_ally(npc_id, pos)
		var s: Sprite2D = sprites[npc_id]
		# Movement delta: compare against last-known position from prior
		# tick. Use the sprite's own position as the "previous" since the
		# state machine doesn't store it.
		var prev_pos: Vector2 = s.position
		var delta_v: Vector2 = pos - prev_pos
		s.position = pos
		if delta_v.length() < MOVE_EPSILON:
			# Idle — lock the texture to the portrait and reset the frame
			# cycle so a fresh walk starts on frame 0 next time.
			walking[npc_id] = false
			walk_timer[npc_id] = 0.0
			walk_frame_idx[npc_id] = 0
			if s.texture != idle_textures.get(npc_id, null):
				s.texture = idle_textures.get(npc_id, null)
				s.scale = Vector2(IDLE_SCALE, IDLE_SCALE)
		else:
			walking[npc_id] = true
			# Dominant-axis facing pick (see _pick_facing for rules).
			var new_facing: String = _pick_facing(delta_v, facing.get(npc_id, "down"))
			if new_facing != facing.get(npc_id, ""):
				facing[npc_id] = new_facing
				# Reset walk timer when direction changes so a new direction
				# starts on frame 0 instead of mid-stride.
				walk_timer[npc_id] = 0.0
				walk_frame_idx[npc_id] = 0
			walk_timer[npc_id] = float(walk_timer.get(npc_id, 0.0)) + delta
			while float(walk_timer[npc_id]) >= WALK_FRAME_PERIOD:
				walk_timer[npc_id] = float(walk_timer[npc_id]) - WALK_FRAME_PERIOD
				walk_frame_idx[npc_id] = (int(walk_frame_idx.get(npc_id, 0)) + 1) % 12
			# Swap texture to the current walk frame.
			var tex: Texture2D = _walk_frame(npc_id, facing[npc_id], int(walk_frame_idx[npc_id]))
			if tex != null:
				s.texture = tex
				s.scale = Vector2(WALK_SCALE, WALK_SCALE)


# Dominant-axis facing pick. Returns "left"/"right"/"up"/"down".
#   |dx| > |dy|  -> "left" or "right" depending on dx sign
#   |dy| > |dx|  -> "up"    or "down"  depending on dy sign
#   |dx| == |dy| -> keep the previous facing (avoids twitch on diagonals).
#
# delta_v    : Vector2 movement delta this tick.
# prev_facing: String last facing we used; returned unchanged on a tie.
func _pick_facing(delta_v: Vector2, prev_facing: String) -> String:
	var ax: float = absf(delta_v.x)
	var ay: float = absf(delta_v.y)
	if ax > ay:
		return "left" if delta_v.x < 0 else "right"
	if ay > ax:
		return "up" if delta_v.y < 0 else "down"
	# Tie: keep previous facing. Default to "down" if caller has no prior.
	return prev_facing if prev_facing != "" else "down"


# Look up one walk frame from the per-NPC / per-direction array.
func _walk_frame(npc_id: String, dir: String, frame_idx: int) -> Texture2D:
	if not walk_frames_by_npc.has(npc_id):
		return null
	var by_dir: Dictionary = walk_frames_by_npc[npc_id]
	if not by_dir.has(dir):
		return null
	var frames: Array = by_dir[dir]
	if frames.is_empty():
		return null
	var i: int = clamp(frame_idx, 0, frames.size() - 1)
	return frames[i]


# --- asset loading ---


# Load `character_<id>.png` for each known NPC. Missing ids are skipped
# silently — add_ally / refresh fall back to a tint placeholder when the
# texture is null (handled by the caller; see _ready safety net below).
func _load_idle_textures() -> void:
	for npc_id in ["nora", "elias", "lily", "daniel", "tom"]:
		var p: String = ASSET_PATH + "character_%s.png" % npc_id
		if ResourceLoader.exists(p):
			idle_textures[npc_id] = load(p) as Texture2D


# Walk frames: 4 directions × 12 frames per NPC. Mirrors the existing
# `_build_walk_frames()` at NightShiftGame.gd:621 but built per-NPC. We
# first try the pre-baked `nora_walk_frames.res` SpriteFrames resource —
# if that fails for any reason, fall back to loading the 48 individual
# PNGs. This keeps the module robust against a missing `.res` (the spec
# explicitly allows either path; see m16_sprite_spec.md fallback note).
func _load_walk_frames() -> void:
	for npc_id in ["nora", "elias"]:
		var by_dir: Dictionary = {}
		for dir_name in ["up", "down", "left", "right"]:
			by_dir[dir_name] = []
		# Try the .res first; document the choice in case the .res fails
		# the load — fall through to per-PNG.
		var res_path: String = ASSET_PATH + "%s_walk_frames.res" % npc_id
		if ResourceLoader.exists(res_path):
			var sf := load(res_path) as SpriteFrames
			if sf != null:
				for dir_name in ["up", "down", "left", "right"]:
					var frames: Array = []
					var anim: String = "default_%s" % dir_name
					if not sf.has_animation(anim):
						anim = dir_name
					if sf.has_animation(anim):
						for i in range(sf.get_frame_count(anim)):
							var t := sf.get_frame_texture(anim, i)
							if t != null:
								frames.append(t)
					by_dir[dir_name] = frames
		# If any direction is still empty, fall back to per-PNG load (same
		# pattern as `_build_walk_frames()`).
		var needs_fallback := false
		for dir_name in ["up", "down", "left", "right"]:
			if (by_dir[dir_name] as Array).is_empty():
				needs_fallback = true
				break
		if needs_fallback:
			# Reset and rebuild from PNGs.
			by_dir = {}
			for dir_name in ["up", "down", "left", "right"]:
				var frames: Array = []
				for i in range(12):
					var p: String = ASSET_PATH + "%s_walk/%s_%s.png" % [npc_id, dir_name, str(i).pad_zeros(2)]
					if ResourceLoader.exists(p):
						frames.append(load(p) as Texture2D)
				by_dir[dir_name] = frames
		walk_frames_by_npc[npc_id] = by_dir