extends Node2D
# Last Radio - Night Shift Defense (v0.5 rewrite)
# Data-driven single-script state machine. Driven by:
#   - data/night_shift/{resources, day_cards, chapter_01_nights, signals}.json
#   - scripts/NightShiftLevels.gd (chapter 1 10-night plan with story text)
#   - scripts/NightShiftArt.gd (art asset mapping)
# Phases: cover -> day -> night -> night_report -> (next night) -> final
# v0.5 first iteration: focus on Night 1 (60s, 3 hotspots) end-to-end loop.

const I18n := preload("res://scripts/I18n.gd")
const Settings := preload("res://scripts/Settings.gd")
const Fx := preload("res://scripts/NightShiftFx.gd")
const FxLayer := preload("res://scripts/FxLayerNode.gd")
const WorldFx := preload("res://scripts/WorldLayerFx.gd")
const PlayerRepairFx := preload("res://scripts/PlayerRepairFx.gd")

# Effect tuning knobs. The two "lead time" / "grace" knobs are defaults —
# runtime values come from difficulty_modifiers so casual/hard/custom
# players see different telegraph + breach timings. Particles per impulse
# control how dense the bursts look at default intensity.
const FX_TELEGRAPH_LEAD_TIME := 2.0
const FX_PARTICLE_LIMIT := 400  # hard cap so an assault storm can't tank FPS

# ============================================================================
# CONSTANTS
# ============================================================================

const SCREEN_SIZE := Vector2(1280, 720)
const PLAY_RECT := Rect2(Vector2(64, 80), Vector2(1152, 560))
const PLAYER_SPEED := 220.0
const HOTSPOT_REACH := 70.0
const REPAIR_RATE := 14.0  # value restored per second when standing on hotspot
const BREACH_GRACE := 1.5  # default seconds after value hits 0 before fail; runtime uses difficulty_modifiers
const PLAYER_SIZE := 18.0

# Effective runtime values that resolve the difficulty modifiers against
# the constants above. Code that used to read BREACH_GRACE / FX_TELEGRAPH_LEAD_TIME
# directly should call these helpers so difficulty actually does something.
func _dx_breach_grace() -> float:
	return float(difficulty_modifiers.get("breach_grace", BREACH_GRACE))


func _dx_telegraph_lead() -> float:
	return float(difficulty_modifiers.get("telegraph", FX_TELEGRAPH_LEAD_TIME))

# Hard-coded map of hotspot id -> screen position (matches chapter_01_nights.json IDs).
# Coordinates reference stadium_room_topdown.png 1280x720 layout:
#   - front_door: top-center, the warm-lit entry breach with sandbags
#   - back_door: top-right, near the stairwell (Night 6+)
#   - left_window / right_window: the cool-blue windows on either side
#   - generator: bottom-center, the red equipment with cables
#   - radio: left of generator, on the workbench (Night 3+)
#   - antenna: top-left corner, the roof line (Night 4+)
#   - medbay: lower-left, the cots area
#   - storage: lower-right, the crate area (Night 8+)
const HOTSPOT_POSITIONS := {
	"front_door": Vector2(640, 85),
	"back_door": Vector2(1000, 80),
	"left_window": Vector2(270, 250),
	"right_window": Vector2(1080, 200),
	"generator": Vector2(629, 517),
	"radio": Vector2(440, 540),
	"antenna": Vector2(200, 130),
	"medbay": Vector2(200, 520),
	"storage": Vector2(1080, 520)
}

# Display footprint for hotspot illustrations. The source PNGs are
# 256x256 with most of the artwork centered; displaying at 120x120 on
# a 1280x720 screen keeps them readable without overwhelming the room.
const HOTSPOT_ART_SIZE := Vector2(120, 120)
const HOTSPOT_BTN_SIZE := Vector2(120, 138)  # art + 18 for the integrity bar

const HOTSPOT_KIND := {
	"front_door": "barrier",
	"back_door": "barrier",
	"left_window": "barrier",
	"right_window": "barrier",
	"generator": "generator",
	"radio": "radio",
	"antenna": "antenna",
	"medbay": "support",
	"storage": "support"
}

const HOTSPOT_COLOR := {
	"front_door": Color(0.85, 0.35, 0.30),
	"back_door": Color(0.35, 0.55, 0.95),
	"left_window": Color(0.95, 0.75, 0.30),
	"right_window": Color(0.40, 0.85, 0.55),
	"generator": Color(1.00, 0.85, 0.20),
	"radio": Color(0.55, 0.80, 1.00),
	"antenna": Color(0.70, 0.55, 1.00),
	"medbay": Color(1.00, 0.60, 0.75),
	"storage": Color(0.65, 0.85, 0.45)
}

const ASSET_PATH := "res://assets/final/night_shift/"
const AUDIO_PATH := "res://assets/audio/"

# ============================================================================
# STATE
# ============================================================================

var data: NightShiftData
var chapter_id: String = "chapter_01"
var chapter_title: String = ""
var night_count: int = 0

# Phase + progress
var phase: String = "cover"
var night_index: int = 0  # 0..9
var night_elapsed: float = 0.0
var night_duration: float = 0.0
var survived: bool = false

# Per-night mutable state
var hotspots: Dictionary = {}  # id -> {kind, value, pressure, active, warning, assault, breach_timer}
var radio_contact_progress: float = 0.0  # seconds spent at the radio hotspot
var radio_contacts_made: int = 0  # how many contacts achieved this night
var radio_tuned_channel: String = ""  # currently selected channel id (e.g. "victor"/"elias"/"static")
var radio_target_channel: String = ""  # the channel that scores a contact this night
var radio_channels_catalog: Array = []  # [{id, label, desc, color, exposure_on_wrong}, ...] for this night
var radio_wrong_ticks: Dictionary = {}  # channel_id -> bool (already paid exposure once for this session)
var player_pos: Vector2 = Vector2(640, 400)
var player_target_id: String = ""  # id the player is moving toward (closest hotspot clicked)
var player_at_target: bool = false
# Walk animation state
var player_facing: String = "down"  # "down"/"left"/"right"/"up" - last dominant movement axis
var player_is_moving: bool = false  # true while actually translating this frame
var player_walk_frame: int = 0  # current frame in walk cycle (0..11)
var player_walk_timer: float = 0.0  # accumulator for frame advance
const PLAYER_WALK_FPS: float = 10.0  # 10 frames/sec -> 1.2s per 12-frame cycle
const PLAYER_FRAMES_PER_DIR: int = 12
# Idle actor art (v0.5 regression recovery). Three source PNGs at 768x1024:
# front (facing camera, "down"), back (facing away, "up"), side (facing right;
# mirrored for left via flip_h). Shown when player is not moving and not
# repairing; walk sprites take over while moving.
var actor_textures: Dictionary = {"front": null, "back": null, "side": null}
# On-screen target size for the player + repair-action overlay. The
# player_walk/ frames are authored at 128x160 and rendered at scale 1.0;
# the repair-action PNGs are authored much larger (e.g. 896x1200) so the
# Sprite2D needs to be scaled DOWN to fit the same footprint.
const PLAYER_TARGET_SIZE := Vector2(128, 160)
# Repair-action animation state (hammer swing). Visible only while
# player is actively repairing a barrier hotspot.
var player_repair_token: Sprite2D
var player_repair_textures: Dictionary = {}  # {frame_id: Texture2D}
var player_repair_active: bool = false  # true while repair ticks are firing
var player_repair_timer: float = 0.0  # accumulator for frame cycle (sec)

# Campaign state
var resources: Dictionary = {}  # {planks, parts, battery, medicine, exposure, trust}
var upgrades: Dictionary = {}  # {card_id: true}
var day_effects: NightShiftDayEffects = NightShiftDayEffects.new()
var logs: Array = []  # recent log lines (max 6)
var allies: Dictionary = {"nora": false, "elias": false, "victor": true}
var radio_available: bool = false
var radio_completed: bool = false
var radio_missed: bool = false
var blackout: bool = false
var unlocked_hotspots: Array = []
var radio_contact_goal: int = 1
var radio_window_left: float = 0.0
var enemy_spawn_cooldown: float = 0.0
# NPC runtime state. Keyed by npc_id ("nora", "elias"). Empty until ally joins.
# Each entry: {pos, target, commit_timer, walk_timer, eval_timer, speed}.
# See polish spec §4.5.
var npc_state: Dictionary = {}

# Event system (loaded from chapter_01_nights.json fixed_events)
var event_queue: Array = []  # [{id, time, type, target, pressure}]
var events_done: Dictionary = {}

# Per-night stats (for the failure/success report screen)
var night_stats: Dictionary = {}  # {radio_contacts, enemies_killed, hotfixes, breaches, breaches_first_id}

# Cumulative breach count across the run (for the no_breach achievement).
# Each night bumps this in _end_night from night_stats["breaches"]; the
# no_breach achievement fires on chapter clear when this is still 0.
var total_breaches: int = 0

# Achievement single-fire flags. Each guard ensures the trigger site only
# unlocks once per run; Steamworks.unlock_achievement also guards
# internally but the local flag keeps the trigger clean.
var _ach_first_contact: bool = false
var _ach_reach_victor: bool = false
var _ach_recruit_nora: bool = false
var _ach_recruit_elias: bool = false
var _ach_all_three: bool = false
var _ach_first_night: bool = false
var _ach_clear_all: bool = false
var _ach_no_breach: bool = false

var rng := RandomNumberGenerator.new()

# ============================================================================
# NODES (built in _ready)
# ============================================================================

var canvas: CanvasLayer
var bg: TextureRect
var hud_layer: Control
var status_label: Label
var log_label: Label
var prompt_label: Label
var hotspot_layer: Node2D
var enemy_layer: Node2D
var player_token: Sprite2D
# Procedural hammer sprite that sits next to the player_token during
# repair ticks. Sits ABOVE player_token (z=1) and BELOW the FX/critical
# overlay (z=4/5). Driven by _draw_player with the same
# PlayerRepairFx REPAIR_CYCLE_SEC phase the FX layer uses. Typed as
# Node2D rather than HammerSprite to avoid a hard class_name cache
# dependency on a freshly-added script.
var hammer_sprite: Node2D
var card_layer: Control
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
# When true, _process watches music_player and swaps in the looping
# `music_report` bed once the one-shot success/failure sting finishes.
# Set by _end_night and _show_night_report; cleared once the swap happens.
var _pending_report_music: bool = false
var flash_rect: ColorRect  # blackout / danger pulse
var radio_panel: Panel  # contact progress panel (only visible at the radio)
var radio_progress_bar: ColorRect
# Polish M10.5: resource chips on the night HUD. Each chip = small icon
# (24x24) + value label, packed into a single HBox. Replaces the old
# "木板 4 · 零件 4 · 电池 2 · 药品 2 · 暴露度 0 · 信任 3" prompt_label
# string with a scannable icon row.
var _resource_bar: HBoxContainer
var _resource_chip_labels: Dictionary = {}  # resource key -> Label (value text)
var menu_ui  # MenuUI instance (CanvasLayer), see _build_menu_ui
var tutorial_overlay  # TutorialOverlay instance (CanvasLayer), see _build_tutorial_overlay
# Cached state for re-rendering after locale switch. _show_night_report is
# called with (success, body); we cache them so the menu can rebuild it.
var last_report_success: bool = true
var last_report_body: String = ""
# Currently-active save slot. Set when player picks a slot on the cover
# screen. All save/load operations go through this var.
var current_slot: int = 0
# Difficulty for the current run. The preset name drives UI labels; the
# modifier dict drives gameplay (enemy count, drain rate, etc). Both are
# persisted to the slot via NightShiftSave.
var current_difficulty: String = "standard"
var difficulty_modifiers: Dictionary = {}
# Number of completed chapter clears (used for New Game+ carry-over).
var ng_plus_count: int = 0
var radio_progress_label: Label
var radio_window_label: Label

# Active enemy tokens (per assaulted hotspot)
var enemy_tokens: Dictionary = {}  # hotspot_id -> [{pos, target_pos, walk, size}]

# Resource cache
var art: Dictionary = {}
var audio_streams: Dictionary = {}
var sfx_streams: Dictionary = {}
var walk_frames: Dictionary = {}  # {direction: [Texture2D]}

# Procedural FX state. fx_particles and fx_telegraphs are tick()'d every frame
# in _update_night; fx_layer is the Node2D that actually draws the particles
# (so _draw doesn't have to fight with the rest of the scene tree).
var fx_particles: Array = []
var fx_telegraphs: Array = []
var fx_shake: Dictionary = {"amount": 0.0, "decay": 6.0, "freq": 28.0, "phase": 0.0}
var fx_layer: Node2D
# Track each hotspot's previous damage tier so we only spawn a crack/splinter
# burst when it crosses a threshold (not every frame it drops).
var fx_last_damage_tier: Dictionary = {}  # id -> int (0..3)

# Critical-tier screen border: a thin pulsing ColorRect that appears when any
# hotspot drops below 25% integrity. Pulses faster as more hotspots enter
# the critical tier.
var fx_critical_overlay: ColorRect
var fx_critical_alpha: float = 0.0
# Repair combo: chains of consecutive repairs within COMBO_WINDOW seconds
# grant a +1 trust bonus per chain step. The combo resets if the player
# spends more than COMBO_WINDOW seconds away from any hotspot.
var fx_combo_count: int = 0
var fx_combo_time_left: float = 0.0
const COMBO_WINDOW := 3.5  # seconds between chained repairs to keep the streak
const COMBO_TRUST_BONUS := 1  # trust awarded per chain step
# Off-screen threat arrows: when an assault is happening and the player is
# far enough that the hotspot isn't visible (or barely visible), draw a
# directional arrow at the screen edge pointing at it. Drawn by fx_layer.
var fx_threat_arrows: Array = []  # [{pos, strength, color}, ...] — owned by fx_tick
# Threat arrow pulse phase, advanced each frame.
var fx_threat_phase: float = 0.0

# Radio static overlay: when the radio is active AND tuned to the static
# channel, draw a procedural noise band over the screen so the player
# feels the "wrong station" without having to read the channel label.
var fx_static_alpha: float = 0.0  # current overlay alpha (animated)
var fx_static_target: float = 0.0  # target alpha (0 or 0.55, lerp toward this)

# Dawn fade transition: triggered at the end of a successful night, fades
# the screen toward the report screen over DAWN_FADE_DURATION seconds.
var fx_dawn_alpha: float = 0.0
var fx_dawn_target: float = 0.0
const DAWN_FADE_DURATION := 1.5
# Procedural background warning scheduler -- ensures night 2+ has a
# constant drip of incoming threats so the player is never idle for
# long stretches. _show_night() resets _proc_next_warning_at to -1.0
# which forces re-initialization on the first _update_events tick.
# Per-hotspot cooldown lives on hotspot["proc_cooldown"] so the
# scheduler never piles multiple warnings on the same door/window.
# round-2 pacing fix: night 2-10 used to have only 2-3 fixed events
# per 120-180s night, leaving the player with 40-90s of dead air.
var _proc_next_warning_at: float = -1.0
# Default (night 1-4) base cadence for procedural background warnings.
# _proc_tick_background_warnings switches to a tighter 4-7s base from
# night 5 onward so the late-game pressure keeps ramping; the per-night
# ramp on top of the base still subtracts 1.5s/2.0s from min/max as
# night_elapsed approaches night_duration.
const PROC_WARNING_INTERVAL_MIN := 6.0
const PROC_WARNING_INTERVAL_MAX := 10.0
# Late-night (night 5+) tighter base cadence. Picked to keep the
# player within one teleport of needing to run for the entire late
# game; night-end ramp pushes the cadence down to ~2.5-5s.
const PROC_WARNING_LATE_MIN := 4.0
const PROC_WARNING_LATE_MAX := 7.0
# First night (0-based) where the late-game cadence kicks in.
const PROC_WARNING_LATE_NIGHT := 4
const PROC_HOTSPOT_COOLDOWN := 25.0

# Footstep dust: small puffs kicked up at the player's feet every
# FOOTSTEP_INTERVAL seconds while moving. Cheap — each puff is 2-3 short-
# life particles with downward gravity.
var fx_footstep_accum: float = 0.0
# Counts consecutive footstep puffs — used to alternate L/R phase so a
# future cadence change can map even/odd steps to different SFX variants.
var fx_footstep_phase: int = 0
const FOOTSTEP_INTERVAL := 0.28

# ============================================================================
# WORLD LAYER (parallax + outside-zombie sprites)
# ============================================================================
# Two parallax atmospheric plates sit BEHIND the room; independent zombie
# sprites sit IN FRONT of the room (so they're visible at the door/window
# hotspots) but BEHIND the FX layer (so telegraph rings + particles stay
# readable). The sprites replace the previous red-circle "threat" overlays
# with something that feels like a 2D side-scroller — you can actually see
# the zombies standing outside.
var world_layer_far: Node2D        # z=-10
var world_layer_mid: Node2D        # z=-5
var world_far_sprite: Sprite2D
var world_mid_sprite: Sprite2D
var world_parallax_phase: float = 0.0
var zombie_outside_layer: Node2D   # z=3
# Per-hotspot zombie sprite + sway accumulator. Key is hotspot id; only
# barrier hotspots get a sprite (doors + windows). Value shape:
#   {sprite: Sprite2D, sway_acc: Dictionary, last_phase: int}
var zombie_outside_sprites: Dictionary = {}
# Cached textures — loaded once in _ready, reused across all sprites.
var zombie_approach_door_tex: Texture2D
var zombie_breach_door_tex: Texture2D
var zombie_approach_window_tex: Texture2D
var zombie_breach_window_tex: Texture2D
var world_far_tex: Texture2D
var world_mid_tex: Texture2D

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	rng.randomize()
	# Load i18n first so any error / warning banners can localize.
	I18n.load_all()
	# Restore user-selected locale if a settings file exists, else default.
	var saved_locale: String = Settings.get_locale()
	if saved_locale != "" and I18n.SUPPORTED_LOCALES.has(saved_locale):
		I18n.set_locale(saved_locale)
	_load_data()
	_load_assets()
	_load_audio()
	# Apply global audio mute (CLI override > settings.json > default).
	# Runs before _build_ui() so MenuUI's first apply_settings sees the
	# same muted state the rest of the game is already using; otherwise
	# MenuUI could briefly unmute during the slot picker → settings
	# transition. See Settings.get_audio_muted() for the default.
	_apply_audio_mute()
	_build_walk_frames()
	_build_ui()
	_build_resource_bar()
	# Migrate any v2 single-slot save before deciding what to show.
	NightShiftSave.migrate_legacy_if_needed()
	# If a save exists, prompt; otherwise fresh cover.
	_show_slot_picker()


func _load_data() -> void:
	data = NightShiftData.new()
	data.load_all()
	chapter_id = data.chapter_id
	chapter_title = data.chapter_title
	night_count = data.count_nights()
	if night_count == 0:
		push_error("NightShiftGame: no nights loaded from data/night_shift/chapter_01_nights.json")
	# Pick the chapter title from the first level using the active locale.
	chapter_title = I18n.t_field(NightShiftLevels.LEVELS[0], "title")


# ============================================================================
# ASSET LOADING
# ============================================================================

func _load_assets() -> void:
	# Background plates
	var bg_keys := {
		"cover": "stadium_room_day_clean.png",
		"day": "day_planning_table_clean.png",
		"night": "stadium_room_topdown_clean.png",
		"report": "night_report_clipboard_clean.png",
		"final_good": "ending_stadium_dawn_clean.png",
		"final_bad": "ending_breach_night_clean.png"
	}
	for k in bg_keys:
		var p: String = ASSET_PATH + bg_keys[k]
		if FileAccess.file_exists(p):
			art[k] = load(p)

	# Character portraits — used by the new cover / night-report / final
	# screen overlays (M10.5 polish: "we drew 6 character sprites, now
	# actually show them in the UI"). Each entry is a Texture2D or null if
	# the PNG is missing. Only Player / Nora / Elias have a dedicated
	# portrait_*.png (384x384); Lily / Tom / Daniel / Victor fall back to
	# the wider character_*.png framing for now.
	_load_character_portraits()


func _load_character_portraits() -> void:
	var portrait_keys := {
		"player": "portrait_player.png",
		"nora": "portrait_nora.png",
		"elias": "portrait_elias.png",
	}
	for k in portrait_keys:
		var p: String = ASSET_PATH + portrait_keys[k]
		art["portrait_" + k] = _safe_load_texture(p)

	# Wider framing for the rest — used for cover/final screen, sized down
	# to match the portrait footprint.
	var character_keys := {
		"player_wide": "character_player.png",
		"nora_wide": "character_nora.png",
		"elias_wide": "character_elias.png",
		"lily_wide": "character_lily.png",
		"tom_wide": "character_tom.png",
		"daniel_wide": "character_daniel.png",
	}
	for k in character_keys:
		var p: String = ASSET_PATH + character_keys[k]
		art[k] = _safe_load_texture(p)

	# Hotspot state art — try loading, fall back to null (rendered as colored circles)
	_load_hotspot_arts()

	# World-layer parallax + outside-zombie textures. Loaded once, reused
	# across all sprites. Missing files just become null and the layer
	# quietly no-ops (so a half-imported build still runs).
	world_far_tex = _safe_load_texture(ASSET_PATH + "outside_world_far.png")
	world_mid_tex = _safe_load_texture(ASSET_PATH + "outside_world_mid.png")
	zombie_approach_door_tex = _safe_load_texture(
		ASSET_PATH + "zombie_outside_door_approach.png"
	)
	zombie_breach_door_tex = _safe_load_texture(
		ASSET_PATH + "zombie_outside_door_breach.png"
	)
	zombie_approach_window_tex = _safe_load_texture(
		ASSET_PATH + "zombie_outside_window_approach.png"
	)
	zombie_breach_window_tex = _safe_load_texture(
		ASSET_PATH + "zombie_outside_window_breach.png"
	)
	# Player repair-action frames (3-frame hammer cycle).
	player_repair_textures[PlayerRepairFx.REPAIR_FRAME_START] = _safe_load_texture(
		ASSET_PATH + "player_repair_start.png"
	)
	player_repair_textures[PlayerRepairFx.REPAIR_FRAME_MID] = _safe_load_texture(
		ASSET_PATH + "player_repair_mid.png"
	)
	player_repair_textures[PlayerRepairFx.REPAIR_FRAME_END] = _safe_load_texture(
		ASSET_PATH + "player_repair_end.png"
	)


func _safe_load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		push_warning("WorldLayerFx texture missing: %s" % path)
		return null
	var res: Resource = load(path)
	return res as Texture2D


func _load_hotspot_arts() -> void:
	var art_root := ASSET_PATH
	var fn := func(path: String) -> Texture2D:
		# Only try to load if the source PNG actually exists on disk.
		# (ResourceLoader.exists() is true as long as a .import file is there,
		# but the imported .ctex can be missing for never-imported source files.)
		if not FileAccess.file_exists(path):
			return null
		var res: Resource = load(path)
		return res as Texture2D
	art["hotspots"] = NightShiftArt.load_hotspot_state_textures(art_root, fn)
	art["icons"] = NightShiftArt.load_upgrade_icon_textures(art_root, fn)
	art["events"] = NightShiftArt.load_upgrade_event_textures(art_root, fn)
	art["alerts"] = NightShiftArt.load_alert_icon_textures(art_root, fn)
	# Log missing art once at load time so the team can see what's still pending.
	for category in ["hotspots", "icons", "events", "alerts"]:
		var bucket: Dictionary = art[category]
		for k in bucket:
			if bucket[k] == null:
				push_warning("NightShiftArt missing: %s/%s" % [category, k])


func _load_audio() -> void:
	var tracks := [
		"cover", "day", "night_early", "night_final", "final",
		"success", "failure", "report",
	]
	for t in tracks:
		var p: String = AUDIO_PATH + "music_" + t + ".mp3"
		if ResourceLoader.exists(p):
			var s := load(p) as AudioStream
			if s:
				s = s.duplicate()
				if "loop" in s:
					# Music tracks default to looping; one-shot stings (success/
					# failure) override this per-call via _play_music(track, false).
					s.set("loop", true)
				audio_streams[t] = s
	# ambient
	for t in ["night", "night_late", "night_final"]:
		var p: String = AUDIO_PATH + "ambience_" + t + ".mp3"
		if ResourceLoader.exists(p):
			var s := load(p) as AudioStream
			if s:
				s = s.duplicate()
				if "loop" in s:
					s.set("loop", true)
				audio_streams["amb_" + t] = s
	# Procedural SFX (always available)
	sfx_streams = NightShiftSfx.build_all()


func _play_music(track: String, looped: bool = true) -> void:
	if music_player == null:
		return
	music_player.stop()
	if track in audio_streams and audio_streams[track]:
		var s: AudioStream = audio_streams[track]
		# Override loop flag per-call so success/failure stings can play
		# non-looped while background tracks (cover/day/night_*) keep looping.
		if "loop" in s:
			s.set("loop", looped)
		music_player.stream = s
		music_player.play()


# Hard-coded fallback used when data/night_shift/signals.json is missing or
# malformed. Loaded by NightShiftData.load_all() normally; this list exists
# only so the radio UI still has 3 channel buttons in extreme edge cases
# (e.g. manual test override, corrupted save, fresh data folder).
func _fallback_signal_catalog() -> Array:
	return [
		{"id": "victor", "label": "Victor", "desc": "Victor 的频道", "color": "#FFD27F", "exposure_on_wrong": 0.0, "voice": "", "wrong_signal": ""},
		{"id": "elias", "label": "Elias", "desc": "Elias 的频道", "color": "#9CD9FF", "exposure_on_wrong": 0.0, "voice": "", "wrong_signal": ""},
		{"id": "static", "label": "干扰", "desc": "只有噪声", "color": "#C97C7C", "exposure_on_wrong": 0.5, "voice": "", "wrong_signal": ""},
	]


func _play_sfx(name: String) -> void:
	if sfx_player == null:
		return
	if not sfx_streams.has(name):
		return
	sfx_player.stream = sfx_streams[name]
	sfx_player.play()


# Apply the global audio mute flag to AudioServer.
#
# Priority (highest first):
#   1. CLI --no-mute / --mute / --silent / --audio overrides settings
#      for the current session without writing to user://settings.json.
#   2. settings.json audio_muted (defaults to DEFAULT_AUDIO_MUTED=true
#      on a fresh launch — first launch is silent so dev / debug runs
#      don't accidentally bleed sound into a shared room).
#   3. Hard default (true).
#
# This is called once from _ready() and again whenever MenuUI.apply_settings()
# changes the checkbox state. Both paths use the same bus-mute API so
# volume sliders and the mute checkbox are orthogonal.
func _apply_audio_mute() -> void:
	var muted: bool = Settings.get_audio_muted()
	# CLI override (per-session only — never written to settings).
	var cli_args: PackedStringArray = OS.get_cmdline_args()
	for arg in cli_args:
		# --no-mute / --audio / --sound force-unmute for this session.
		if arg == "--no-mute" or arg == "--audio" or arg == "--sound":
			muted = false
			break
		# --mute / --silent / --quiet force-mute for this session (CI /
		# capture runs that want to record audio-free screenshots).
		if arg == "--mute" or arg == "--silent" or arg == "--quiet":
			muted = true
			break
	# Also check OS.get_cmdline_user_args() in case the platform splits
	# user args from engine args (Godot 4 splits them on most platforms).
	for arg in OS.get_cmdline_user_args():
		if arg == "--no-mute" or arg == "--audio" or arg == "--sound":
			muted = false
			break
		if arg == "--mute" or arg == "--silent" or arg == "--quiet":
			muted = true
			break
	for bus in ["Music", "SFX"]:
		var idx: int = AudioServer.get_bus_index(bus)
		if idx >= 0:
			AudioServer.set_bus_mute(idx, muted)


# ============================================================================
# WALK FRAMES
# ============================================================================

func _build_walk_frames() -> void:
	# Load walk frames from existing player_walk/ dir (4 directions x 12 frames)
	for dir_name in ["down", "left", "right", "up"]:
		walk_frames[dir_name] = []
	for i in range(12):
		for dir_name in ["down", "left", "right", "up"]:
			var p: String = ASSET_PATH + "player_walk/" + dir_name + "_" + str(i).pad_zeros(2) + ".png"
			if ResourceLoader.exists(p):
				walk_frames[dir_name].append(load(p) as Texture2D)
	# Idle actor art (3 views, 768x1024 each). Player shows these when not
	# moving; walk sprite takes over during translation. side is authored
	# facing right; _draw_player flips it horizontally when facing left.
	for view_name in ["front", "back", "side"]:
		var p2: String = ASSET_PATH + "actor_player_" + view_name + ".png"
		if ResourceLoader.exists(p2):
			actor_textures[view_name] = load(p2) as Texture2D


# Pick the idle-actor texture for the player's current facing. down -> front,
# up -> back, left/right -> side (mirrored at draw time).
func _actor_for_facing(facing: String) -> Texture2D:
	if facing == "up":
		return actor_textures.get("back", null)
	if facing == "left" or facing == "right":
		return actor_textures.get("side", null)
	return actor_textures.get("front", null)


# ============================================================================
# UI
# ============================================================================

func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)

	# World-layer parallax — drawn BEHIND the room (z_index < 0). The far
	# plate is almost static; the mid plate drifts with parallax_offset().
	world_layer_far = Node2D.new()
	world_layer_far.z_index = -10
	world_layer_far.name = "WorldLayerFar"
	canvas.add_child(world_layer_far)
	world_far_sprite = Sprite2D.new()
	world_far_sprite.name = "FarBg"
	world_far_sprite.texture = world_far_tex
	world_far_sprite.centered = true
	world_far_sprite.position = SCREEN_SIZE * 0.5
	world_layer_far.add_child(world_far_sprite)

	world_layer_mid = Node2D.new()
	world_layer_mid.z_index = -5
	world_layer_mid.name = "WorldLayerMid"
	canvas.add_child(world_layer_mid)
	world_mid_sprite = Sprite2D.new()
	world_mid_sprite.name = "MidBg"
	world_mid_sprite.texture = world_mid_tex
	world_mid_sprite.centered = true
	world_mid_sprite.position = SCREEN_SIZE * 0.5
	world_layer_mid.add_child(world_mid_sprite)

	bg = TextureRect.new()
	bg.position = Vector2.ZERO
	bg.size = SCREEN_SIZE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	canvas.add_child(bg)

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	add_child(sfx_player)

	# Flash overlay (blackout, danger pulse)
	flash_rect = ColorRect.new()
	flash_rect.position = Vector2.ZERO
	flash_rect.size = SCREEN_SIZE
	flash_rect.color = Color(0, 0, 0, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.visible = false
	canvas.add_child(flash_rect)

	hud_layer = Control.new()
	hud_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud_layer)

	status_label = _make_label(Vector2(24, 16), 24, Color(1, 0.95, 0.7))
	status_label.add_theme_constant_override("outline_size", 5)
	hud_layer.add_child(status_label)

	prompt_label = _make_label(Vector2(24, 56), 16, Color(0.9, 0.9, 0.85))
	prompt_label.add_theme_constant_override("outline_size", 3)
	hud_layer.add_child(prompt_label)

	log_label = _make_label(Vector2(24, SCREEN_SIZE.y - 320), 14, Color(0.85, 0.85, 0.78))
	log_label.size = Vector2(SCREEN_SIZE.x - 48, 240)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.add_theme_constant_override("outline_size", 3)
	hud_layer.add_child(log_label)

	hotspot_layer = Node2D.new()
	canvas.add_child(hotspot_layer)

	enemy_layer = Node2D.new()
	canvas.add_child(enemy_layer)

	# Zombie-outside layer — independent sprites standing outside barrier
	# hotspots (door / window). Drawn IN FRONT of the room bg + hotspot
	# dots (so you see them through the door/window) but BEHIND the FX
	# layer (so telegraph rings + breach particles stay readable).
	zombie_outside_layer = Node2D.new()
	zombie_outside_layer.z_index = 3
	zombie_outside_layer.name = "ZombieOutsideLayer"
	canvas.add_child(zombie_outside_layer)

	# Procedural FX layer — particles + telegraph rings. Sits above the
	# enemy layer so breaches and sparks read on top of the enemy tokens.
	fx_layer = FxLayer.new()
	fx_layer.z_index = 5
	canvas.add_child(fx_layer)

	# Critical-tier screen border overlay. Invisible by default; animated
	# up/down in _fx_tick based on whether any hotspot is in tier 3.
	fx_critical_overlay = ColorRect.new()
	fx_critical_overlay.position = Vector2.ZERO
	fx_critical_overlay.size = SCREEN_SIZE
	fx_critical_overlay.color = Color(0.7, 0.15, 0.1, 0.0)
	fx_critical_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_critical_overlay.z_index = 4
	canvas.add_child(fx_critical_overlay)

	card_layer = Control.new()
	card_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_layer.visible = false
	canvas.add_child(card_layer)

	player_token = Sprite2D.new()
	player_token.position = player_pos
	player_token.scale = Vector2(1.0, 1.0)
	player_token.texture = walk_frames.get("down", [null])[0] if not walk_frames.get("down", []).is_empty() else null
	canvas.add_child(player_token)

	# Player repair-action sprite -- drawn ON TOP of player_token so the
	# hammer reads above the walk sprite. Hidden by default; _draw_player
	# toggles visible + texture while repair ticks are firing.
	player_repair_token = Sprite2D.new()
	player_repair_token.position = player_pos
	# Art frames are 896x1200 source; scale 0.12 brings the body to ~144px tall
	# which matches the walk sprite footprint (~120-160px) so the player
	# doesn't visually pop on idle->repair transitions. polish spec §4.5
	# (M13.1: replaces the v0.5 drop-overlay tint with real art frames; the
	# earlier scale=1.0 was correct only for tiny 32x32 debug squares).
	player_repair_token.scale = Vector2(0.12, 0.12)
	player_repair_token.visible = false
	player_repair_token.z_index = 1  # above walk sprite
	player_repair_token.texture = player_repair_textures.get(PlayerRepairFx.REPAIR_FRAME_START, null)
	canvas.add_child(player_repair_token)

	# Procedural hammer sprite -- the player_token itself stays perfectly
	# still (no tilt / bob) during repair; this hammer rotates next to
	# the player so the swing reads visually without warping the
	# silhouette. Permanent visible=false; _draw_player toggles it on
	# during repair ticks. polish spec §4.5 / round-2 visual fix.
	const HammerSpriteScript := preload("res://scripts/HammerSprite.gd")
	hammer_sprite = HammerSpriteScript.new()
	hammer_sprite.name = "HammerSprite"
	hammer_sprite.position = player_pos
	hammer_sprite.visible = false
	hammer_sprite.z_index = 1  # above walk sprite, same as old repair_token
	canvas.add_child(hammer_sprite)

	# Radio contact progress panel — only visible while the player is standing
	# at the radio hotspot and the radio is active.
	_build_radio_panel()
	_build_menu_ui()


func _build_menu_ui() -> void:
	# Pause / settings / quit overlay. Mounted last so it draws on top.
	const MenuUI := preload("res://scripts/MenuUI.gd")
	menu_ui = MenuUI.new()
	menu_ui.on_quit_to_desktop = _on_menu_quit_to_desktop
	menu_ui.on_settings_applied = _on_menu_settings_applied
	add_child(menu_ui)
	_build_tutorial_overlay()


func _build_tutorial_overlay() -> void:
	const TutorialOverlay := preload("res://scripts/TutorialOverlay.gd")
	tutorial_overlay = TutorialOverlay.new()
	tutorial_overlay.on_tutorial_finished = _on_tutorial_finished
	add_child(tutorial_overlay)


func _on_menu_quit_to_desktop() -> void:
	# Single-binary release: just quit. Steam distribution: this is where you
	# would post a Steam shutdown signal if needed.
	get_tree().quit()


func _on_tutorial_finished() -> void:
	# Persist the "tutorial completed" flag so we never show the intro again
	# for this save. The flag is set in the save; we re-read the file to
	# preserve any in-flight state (resources, night_index, etc).
	var doc: Dictionary = NightShiftSave.read(current_slot)
	doc["tutorial_done"] = true
	NightShiftSave.write(doc, current_slot)


func _on_menu_settings_applied() -> void:
	# Re-render the current screen so locale switch takes effect immediately.
	# We can rebuild cover / day / night / night_report / final directly.
	if phase == "cover":
		_show_cover()
	elif phase == "day":
		_show_day()
	elif phase == "night":
		_rebuild_hotspot_visuals()
		_update_status_label()
	elif phase == "night_report":
		_show_night_report(last_report_success, last_report_body)
	elif phase == "final":
		_show_final()


func _unhandled_input(event: InputEvent) -> void:
	if not menu_ui:
		return
	if event.is_action_pressed("ui_cancel"):
		menu_ui.toggle_pause()
		get_viewport().set_input_as_handled()


func _build_radio_panel() -> void:
	radio_panel = Panel.new()
	radio_panel.position = Vector2(SCREEN_SIZE.x * 0.5 - 200, SCREEN_SIZE.y - 280)
	radio_panel.size = Vector2(400, 220)
	radio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.10, 0.13, 0.18, 0.94)
	ps.border_color = Color(0.55, 0.78, 1.0, 0.95)
	for k in ["left", "right", "top", "bottom"]:
		ps.set("border_width_" + k, 2)
	for k in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		ps.set("corner_radius_" + k, 8)
	ps.content_margin_left = 14
	ps.content_margin_right = 14
	ps.content_margin_top = 10
	ps.content_margin_bottom = 10
	radio_panel.add_theme_stylebox_override("panel", ps)
	radio_panel.visible = false
	canvas.add_child(radio_panel)

	radio_progress_label = _make_label(Vector2(0, 0), 14, Color(0.78, 0.88, 1.0))
	radio_progress_label.add_theme_constant_override("outline_size", 3)
	radio_progress_label.text = "电台接通 0/1"
	radio_panel.add_child(radio_progress_label)

	radio_window_label = _make_label(Vector2(0, 20), 12, Color(0.95, 0.85, 0.55))
	radio_window_label.add_theme_constant_override("outline_size", 3)
	radio_window_label.text = "窗口剩余 30 秒"
	radio_panel.add_child(radio_window_label)

	# Progress bar (bg + fill)
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(0, 52)
	bar_bg.size = Vector2(372, 14)
	bar_bg.color = Color(0, 0, 0, 0.55)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_panel.add_child(bar_bg)
	radio_progress_bar = ColorRect.new()
	radio_progress_bar.position = Vector2(0, 52)
	radio_progress_bar.size = Vector2(0, 14)
	radio_progress_bar.color = Color(0.45, 0.78, 1.0, 0.95)
	radio_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radio_panel.add_child(radio_progress_bar)

	# Channel selector — 3 buttons in a row.
	var channels_label := _make_label(Vector2(0, 78), 12, Color(0.85, 0.85, 0.85))
	channels_label.text = "选择频道（拨到正确的那一格才能接通）："
	radio_panel.add_child(channels_label)

	# Buttons are created lazily per-night in _refresh_radio_channels().
	# Save references so we can clean them up if the catalog changes.
	radio_channel_buttons = []

	# Selected channel description line
	radio_channel_desc_label = _make_label(Vector2(0, 190), 11, Color(0.95, 0.92, 0.78))
	radio_channel_desc_label.text = "（未调谐）"
	radio_panel.add_child(radio_channel_desc_label)


# Rebuild the 3 channel buttons whenever the night catalog changes.
var radio_channel_buttons: Array = []
var radio_channel_desc_label: Label


func _refresh_radio_channels() -> void:
	if radio_panel == null:
		return
	for btn in radio_channel_buttons:
		if btn and btn.get_parent():
			btn.queue_free()
	radio_channel_buttons.clear()
	var n: int = radio_channels_catalog.size()
	if n == 0:
		return
	var btn_w: float = 116.0
	var btn_h: float = 72.0
	var gap: float = 10.0
	var total_w: float = n * btn_w + (n - 1) * gap
	var start_x: float = (radio_panel.size.x - total_w) * 0.5
	var y: float = 96.0
	for i in range(n):
		var ch: Dictionary = radio_channels_catalog[i]
		var cid: String = str(ch.get("id", ""))
		var btn := Button.new()
		btn.position = Vector2(start_x + i * (btn_w + gap), y)
		btn.size = Vector2(btn_w, btn_h)
		btn.focus_mode = Control.FOCUS_NONE
		btn.clip_text = true
		# Two-line label: name on top, desc below.
		var lbl_text: String = str(ch.get("label", cid))
		var desc_text: String = str(ch.get("desc", ""))
		btn.text = "%s\n%s" % [lbl_text, desc_text]
		btn.add_theme_font_size_override("font_size", 11)
		var color_hex: String = str(ch.get("color", "#9CD9FF"))
		var tint: Color = Color(color_hex) if color_hex.begins_with("#") else Color(0.6, 0.85, 1.0)
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.15, 0.18, 0.25, 0.95)
		s.border_color = tint
		s.border_width_left = 2
		s.border_width_right = 2
		s.border_width_top = 2
		s.border_width_bottom = 2
		s.corner_radius_top_left = 4
		s.corner_radius_top_right = 4
		s.corner_radius_bottom_left = 4
		s.corner_radius_bottom_right = 4
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", s)
		var sh := s.duplicate()
		sh.bg_color = Color(0.22, 0.30, 0.42, 0.95)
		btn.add_theme_stylebox_override("hover", sh)
		var sp := s.duplicate()
		sp.bg_color = Color(0.30, 0.42, 0.58, 0.95)
		btn.add_theme_stylebox_override("pressed", sp)
		btn.pressed.connect(_on_radio_channel_pressed.bind(cid))
		radio_panel.add_child(btn)
		radio_channel_buttons.append(btn)


func _on_radio_channel_pressed(channel_id: String) -> void:
	if phase != "night":
		return
	if not _is_radio_active():
		return
	if radio_tuned_channel == channel_id:
		# Toggle off
		radio_tuned_channel = ""
		_log("电台调谐：清空。")
	else:
		radio_tuned_channel = channel_id
		_log("电台调谐到：%s" % channel_id)
	_play_sfx("click")
	_save_progress()


func _update_radio_panel() -> void:
	if radio_panel == null:
		return
	var show: bool = _is_radio_active() and player_target_id == "radio" and player_at_target
	if not show:
		# Also flash the panel briefly when a contact is made.
		radio_panel.visible = false
		return
	radio_panel.visible = true
	# Lazy-build channel buttons when the catalog becomes non-empty.
	if radio_channel_buttons.is_empty() and not radio_channels_catalog.is_empty():
		_refresh_radio_channels()
	radio_progress_label.text = "电台接通 %d/%d" % [radio_contacts_made, radio_contact_goal]
	radio_window_label.text = "窗口剩余 %.0f 秒" % radio_window_left
	var pct: float = clamp(radio_contact_progress / RADIO_CONTACT_SECONDS, 0.0, 1.0)
	radio_progress_bar.size.x = 372.0 * pct
	# Color shifts from blue to green as the bar fills.
	if pct >= 1.0:
		radio_progress_bar.color = Color(0.35, 0.92, 0.55, 0.95)
	else:
		radio_progress_bar.color = Color(0.45, 0.78, 1.0, 0.95)
	# Highlight currently-tuned channel button.
	var tuned_correct: bool = radio_target_channel != "" and radio_tuned_channel == radio_target_channel
	for i in range(radio_channel_buttons.size()):
		var btn: Button = radio_channel_buttons[i]
		if i >= radio_channels_catalog.size():
			continue
		var ch: Dictionary = radio_channels_catalog[i]
		var color_hex: String = str(ch.get("color", "#9CD9FF"))
		var tint: Color = Color(color_hex) if color_hex.begins_with("#") else Color(0.6, 0.85, 1.0)
		var is_tuned: bool = str(ch.get("id", "")) == radio_tuned_channel
		var s := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if is_tuned:
			s.border_color = Color(1.0, 0.95, 0.7) if tuned_correct else Color(1.0, 0.4, 0.4)
			s.border_width_top = 3
			s.border_width_bottom = 3
			s.border_width_left = 3
			s.border_width_right = 3
		else:
			s.border_color = tint
			s.border_width_top = 2
			s.border_width_bottom = 2
			s.border_width_left = 2
			s.border_width_right = 2
		btn.add_theme_stylebox_override("normal", s)
	# Description line under buttons
	if radio_channel_desc_label != null:
		if radio_tuned_channel == "":
			radio_channel_desc_label.text = "（未调谐：拨一个频道开始接通）"
		else:
			var matched: Dictionary = {}
			for ch in radio_channels_catalog:
				if str(ch.get("id", "")) == radio_tuned_channel:
					matched = ch
					break
			var suffix: String = "（正确）" if tuned_correct else "（错台，无人应答）"
			radio_channel_desc_label.text = "调谐：%s %s" % [str(matched.get("label", radio_tuned_channel)), suffix]


func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.position = pos
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _clear_card_layer() -> void:
	# Detach first, then queue_free. Doing `child.free()` directly is unsafe
	# when this is called from a button's `pressed` signal handler (e.g. the
	# Confirm button on the difficulty picker) — the button is locked while
	# its signal is being emitted, and `free()` raises
	#   "Attempted to free a locked object (calling or emitting)."
	# Detach + queue_free defers the actual delete to the next idle frame,
	# which sidesteps the lock and matches what tests already await on.
	for child in card_layer.get_children():
		card_layer.remove_child(child)
		child.queue_free()


# ============================================================================
# PHASE: cover
# ============================================================================

func _show_cover() -> void:
	# Backwards-compat shim. New code path is _show_slot_picker.
	_show_slot_picker()


# ============================================================================
# PHASE: shared UI helpers (ally strip + radio panel hide)
# ============================================================================

# Force-hide the radio contact progress panel. The panel is mounted on the
# in-game canvas and its visibility is driven by gameplay; some phase
# transitions (cover / night_report / final) can leave it in a stale
# "still visible" state if the player was standing at the radio when the
# night ended. Polish M10.5 fix — every non-night phase calls this.
func _hide_radio_panel() -> void:
	if radio_panel != null:
		radio_panel.visible = false


# Ally strip: a horizontal row of character portrait chips used on the
# cover, night report, and final screens. Renders ALL 6 characters
# (player / nora / elias / lily / tom / daniel) so the player always sees
# the full cast, with un-joined ones greyed out.
#
# Args:
#   pos: top-left position of the strip
#   per_chip: number of chips to render (set 0 to render all 6)
#   _report_success: reserved for the night-report variant (currently
#     unused — kept so the call site reads naturally and we can grow the
#     strip's behavior later without touching every call site)
func _build_ally_strip(pos: Vector2, per_chip: int = 7, _report_success: bool = true) -> void:
	var portraits: Array = [
		{"id": "player", "tex": art.get("portrait_player", null), "wide_tex": art.get("player_wide", null), "joined": true},
		{"id": "nora", "tex": art.get("portrait_nora", null), "wide_tex": art.get("nora_wide", null), "joined": bool(allies.get("nora", false))},
		{"id": "elias", "tex": art.get("portrait_elias", null), "wide_tex": art.get("elias_wide", null), "joined": bool(allies.get("elias", false))},
		{"id": "lily", "tex": null, "wide_tex": art.get("lily_wide", null), "joined": false},
		{"id": "tom", "tex": null, "wide_tex": art.get("tom_wide", null), "joined": false},
		{"id": "daniel", "tex": null, "wide_tex": art.get("daniel_wide", null), "joined": false},
	]
	var chip_size: float = 56.0
	var gap: float = 8.0
	var label_h: float = 16.0
	var strip_w: float = float(portraits.size()) * chip_size + float(portraits.size() - 1) * gap
	for i in range(portraits.size()):
		var p: Dictionary = portraits[i]
		var chip := PanelContainer.new()
		chip.position = pos + Vector2(float(i) * (chip_size + gap), 0)
		chip.size = Vector2(chip_size, chip_size + label_h)
		var style := StyleBoxFlat.new()
		if bool(p.get("joined", false)):
			style.bg_color = Color(0.10, 0.13, 0.18, 0.92)
			style.border_color = Color(0.85, 0.72, 0.32, 0.95)
		else:
			style.bg_color = Color(0.04, 0.05, 0.07, 0.85)
			style.border_color = Color(0.36, 0.40, 0.46, 0.55)
		for k in ["left", "right", "top", "bottom"]:
			style.set("border_width_" + k, 2)
		for k in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			style.set("corner_radius_" + k, 6)
		chip.add_theme_stylebox_override("panel", style)
		card_layer.add_child(chip)

		# Portrait texture
		var tex: Texture2D = p.get("tex", null) if p.get("tex", null) != null else p.get("wide_tex", null)
		if tex != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.position = Vector2(2, 2)
			tex_rect.size = Vector2(chip_size - 4, chip_size - 4)
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if not bool(p.get("joined", false)):
				tex_rect.modulate = Color(0.5, 0.5, 0.55, 0.65)
			chip.add_child(tex_rect)
		else:
			# Fallback: character initial on a dim background
			var initial := Label.new()
			initial.text = String(p.get("id", "")).substr(0, 1).to_upper()
			initial.position = Vector2(2, 12)
			initial.size = Vector2(chip_size - 4, chip_size - 4 - 12)
			initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			initial.add_theme_font_size_override("font_size", 22)
			initial.add_theme_color_override("font_color", Color(0.7, 0.74, 0.82, 0.6))
			chip.add_child(initial)

		# Name label below the chip
		var name_lbl := Label.new()
		name_lbl.text = String(p.get("id", "")).capitalize()
		name_lbl.position = Vector2(0, chip_size + 1)
		name_lbl.size = Vector2(chip_size, label_h)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 10)
		if bool(p.get("joined", false)):
			name_lbl.add_theme_color_override("font_color", Color(0.95, 0.86, 0.55))
		else:
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.55, 0.62, 0.6))
		chip.add_child(name_lbl)


func _show_cover_with_continue() -> void:
	# Cover screen variant that overlays a "Continue" button on top of the slot
	# picker. Used after a save so the player can resume without re-picking the
	# slot. The button loads the most recently saved slot.
	_show_slot_picker()
	var hint: Label = Label.new()
	hint.text = I18n.t("cover_save_hint")
	hint.position = Vector2(SCREEN_SIZE.x * 0.5 - 360, 140)
	hint.size = Vector2(720, 28)
	hint.add_theme_constant_override("font_size", 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.85, 0.85, 0.7, 1)
	card_layer.add_child(hint)

	# Pick the most recently saved slot (highest saved_at) so the continue
	# button always lands on the freshest save. Fall back to slot 1 if nothing
	# is populated.
	var best_slot: int = 0
	var best_saved_at: int = 0
	for s in range(1, NightShiftSave.SLOT_COUNT + 1):
		var summary: Dictionary = NightShiftSave.slot_summary(s)
		if summary.exists and int(summary.get("saved_at", 0)) > best_saved_at:
			best_saved_at = int(summary.get("saved_at", 0))
			best_slot = s

	var continue_btn := _make_button(
		I18n.t("cover_btn_continue"),
		Vector2(SCREEN_SIZE.x * 0.5 - 140, 180),
		Vector2(280, 52),
		_on_continue_pressed
	)
	if best_slot <= 0:
		continue_btn.disabled = true
		continue_btn.modulate = Color(0.6, 0.6, 0.6, 1)
	card_layer.add_child(continue_btn)


func _on_continue_pressed() -> void:
	# Find the most recent saved slot and resume from it.
	var best_slot: int = 0
	var best_saved_at: int = 0
	for s in range(1, NightShiftSave.SLOT_COUNT + 1):
		var summary: Dictionary = NightShiftSave.slot_summary(s)
		if summary.exists and int(summary.get("saved_at", 0)) > best_saved_at:
			best_saved_at = int(summary.get("saved_at", 0))
			best_slot = s
	if best_slot <= 0:
		return
	current_slot = best_slot
	var doc: Dictionary = NightShiftSave.read(best_slot)
	if doc.is_empty():
		return
	_load_state_from_doc(doc)
	_play_music("day")
	_show_day()


func _show_slot_picker() -> void:
	phase = "cover"
	_clear_card_layer()
	card_layer.visible = true
	# Hotspots only belong on the night map; cover/slot/difficulty pickers
	# would otherwise show stale button rings over the background.
	hotspot_layer.visible = false
	# Player token doesn't belong on the cover either — hide it so the
	# character overlay we add below is the only "who's in this game" hint.
	player_token.visible = false
	player_repair_token.visible = false
	# Polish M10.5: hide the radio panel so it doesn't bleed onto the cover.
	_hide_radio_panel()
	# Resource chips are night-only; show the prompt_label row again.
	_set_resource_bar_visible(false)
	# Cover has its own title block — the legacy prompt_label "subtitle"
	# and the body hint overlap with the new block, so hide them on cover.
	prompt_label.visible = false
	prompt_label.text = ""
	log_label.visible = false
	log_label.text = ""
	# Hide tutorial overlay on the cover.
	if tutorial_overlay:
		tutorial_overlay.visible = false
	if art.get("cover"):
		bg.texture = art["cover"]
	_play_music("cover")

	# Polish M10.5: cover now reads as a proper title screen, not just
	# "three save slots" sitting in a corner. Title block + tagline +
	# player silhouette in the lower-right + dim scrim. The slot cards
	# are pushed down to make room.
	_build_cover_title_block()
	_apply_cover_scrim()
	_build_cover_character_overlay()

	# Status / prompt / log fill different roles on the cover:
	#   - status_label = the big 末日电台 title (overridden by title block)
	#   - prompt_label = 旧体育馆守夜 · 第一章 subtitle
	#   - log_label    = body hint text (left as is, hidden by title block bg)
	prompt_label.text = I18n.t("subtitle_chapter")
	log_label.text = I18n.t("cover_body")

	# Build 3 slot cards side by side.
	var slot_w: float = 340.0
	var slot_h: float = 300.0
	var gap: float = 28.0
	var total_w: float = 3.0 * slot_w + 2.0 * gap
	var start_x: float = (SCREEN_SIZE.x - total_w) * 0.5
	var y: float = 260.0
	for slot in range(1, 4):
		var sx: float = start_x + (slot - 1) * (slot_w + gap)
		_build_slot_card(slot, Vector2(sx, y), Vector2(slot_w, slot_h))


# Cover-screen title block: big 末日电台 + 旧体育馆守夜 · 第一章 + tagline.
# Drawn into card_layer so it gets cleared on phase change. The three
# labels share a single dim backdrop so they stay readable over the
# stadium-room background.
func _build_cover_title_block() -> void:
	var block_w: float = 760.0
	var block_h: float = 150.0
	var block_x: float = (SCREEN_SIZE.x - block_w) * 0.5
	var block_y: float = 50.0
	var backdrop := ColorRect.new()
	backdrop.position = Vector2(block_x, block_y)
	backdrop.size = Vector2(block_w, block_h)
	backdrop.color = Color(0, 0, 0, 0.42)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_layer.add_child(backdrop)

	# Main title 末日电台 — also rebind status_label so the chrome strip
	# doesn't double-print the same string in tiny font.
	status_label.text = ""
	status_label.visible = false
	var title := Label.new()
	title.text = I18n.t("title_main")
	title.position = Vector2(block_x, block_y + 12)
	title.size = Vector2(block_w, 64)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.96, 0.86))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 4)
	card_layer.add_child(title)

	var subtitle := Label.new()
	subtitle.text = I18n.t("subtitle_chapter")
	subtitle.position = Vector2(block_x, block_y + 78)
	subtitle.size = Vector2(block_w, 32)
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.add_theme_color_override("font_color", Color(1.0, 0.78, 0.36))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	subtitle.add_theme_constant_override("outline_size", 3)
	card_layer.add_child(subtitle)

	var tagline := Label.new()
	tagline.text = "Ten Nights. One Watch."
	tagline.position = Vector2(block_x, block_y + 114)
	tagline.size = Vector2(block_w, 24)
	tagline.add_theme_font_size_override("font_size", 15)
	tagline.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	tagline.add_theme_constant_override("outline_size", 2)
	card_layer.add_child(tagline)


# Cover scrim: gentle top-to-bottom dark gradient so the title block + slot
# cards read clearly over the stadium-room background. The scrim is mouse-
# transparent so the underlying buttons still receive clicks.
func _apply_cover_scrim() -> void:
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0, 0, 0, 0.32)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sit ABOVE the bg but BELOW the slot-card buttons — card_layer z order
	# already does this (added before slot cards).
	card_layer.add_child(scrim)
	card_layer.move_child(scrim, 0)


# Player silhouette in the lower-right of the cover. Sized to a single
# small figure so the slot cards stay the visual focus. Uses
# character_player.png (the wide framing) — the same asset the in-game
# player_token uses. Falls back to portrait_player.png if the wider
# framing isn't available.
func _build_cover_character_overlay() -> void:
	var tex: Texture2D = art.get("player_wide", null)
	if tex == null:
		tex = art.get("portrait_player", null)
	if tex == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = tex
	# Constrain to the right edge, below the slot-card row. We aim for a
	# silhouette that's ~280px tall and tucked into the right gutter so
	# it doesn't compete with the slot cards for attention.
	var target_h: float = 290.0
	var src_size: Vector2 = tex.get_size()
	if src_size.y <= 0.0:
		return
	var scale: float = target_h / src_size.y
	var draw_w: float = src_size.x * scale
	sprite.scale = Vector2(scale, scale)
	# Position so the sprite's bottom-right corner sits in the lower-
	# right gutter. Sprite2D.position is the center, so back off half
	# the drawn width/height.
	sprite.position = Vector2(
		SCREEN_SIZE.x - draw_w * 0.5 - 8.0,
		SCREEN_SIZE.y - target_h * 0.5 - 16.0
	)
	sprite.modulate = Color(1, 1, 1, 0.92)
	sprite.z_index = 1  # above the dim scrim so the silhouette reads
	card_layer.add_child(sprite)


func _build_slot_card(slot: int, pos: Vector2, sz: Vector2) -> void:
	var summary: Dictionary = NightShiftSave.slot_summary(slot)
	var card := Panel.new()
	card.position = pos
	card.size = sz
	# Override the default light-grey stylebox with a dark scrim so the
	# card reads as a clear panel on top of the stadium-room background.
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.045, 0.060, 0.075, 0.92)
	card_style.border_color = Color(0.65, 0.55, 0.35, 0.95)
	for k in ["left", "right", "top", "bottom"]:
		card_style.set("border_width_" + k, 2)
	for k in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		card_style.set("corner_radius_" + k, 10)
	card_style.content_margin_left = 18
	card_style.content_margin_right = 18
	card_style.content_margin_top = 16
	card_style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", card_style)
	card_layer.add_child(card)

	var title: Label = Label.new()
	title.text = "Slot %d" % slot
	title.position = Vector2(20, 12)
	title.size = Vector2(sz.x - 40, 28)
	title.add_theme_constant_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("outline_size", 2)
	card.add_child(title)

	if summary.exists:
		var line1: Label = Label.new()
		var night_text: String = I18n.t("slot_night", [summary.night_index + 1])
		if summary.ng_plus > 0:
			line1.text = "%s · %s" % [night_text, I18n.t("slot_ng_plus", [summary.ng_plus])]
		else:
			line1.text = night_text
		line1.position = Vector2(20, 56)
		line1.size = Vector2(sz.x - 40, 28)
		line1.add_theme_font_size_override("font_size", 18)
		line1.add_theme_color_override("font_color", Color(0.92, 0.96, 0.90))
		card.add_child(line1)

		var diff_label: Label = Label.new()
		var preset: String = str(summary.get("current_difficulty", "standard"))
		if preset == "custom":
			diff_label.text = I18n.t("slot_difficulty_custom")
		else:
			diff_label.text = NightShiftSave.preset_label(preset)
		diff_label.position = Vector2(20, 88)
		diff_label.size = Vector2(sz.x - 40, 24)
		diff_label.add_theme_font_size_override("font_size", 14)
		diff_label.modulate = Color(0.7, 0.85, 1, 1)
		card.add_child(diff_label)

		var play_btn := _make_button(
			I18n.t("slot_play"),
			Vector2(20, 130),
			Vector2(sz.x - 40, 48),
			_on_slot_play_pressed.bind(slot)
		)
		card.add_child(play_btn)

		var erase_btn := _make_button(
			I18n.t("slot_erase"),
			Vector2(20, 192),
			Vector2(sz.x - 40, 42),
			_on_slot_erase_pressed.bind(slot)
		)
		card.add_child(erase_btn)
	else:
		var empty_label: Label = Label.new()
		empty_label.text = I18n.t("slot_empty")
		empty_label.position = Vector2(20, 90)
		empty_label.size = Vector2(sz.x - 40, 32)
		empty_label.add_theme_font_size_override("font_size", 18)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.modulate = Color(0.6, 0.6, 0.7, 1)
		card.add_child(empty_label)

		var new_btn := _make_button(
			I18n.t("slot_new"),
			Vector2(20, 160),
			Vector2(sz.x - 40, 76),
			_on_slot_new_pressed.bind(slot)
		)
		card.add_child(new_btn)


func _on_slot_play_pressed(slot: int) -> void:
	print("DEBUG _on_slot_play_pressed called")
	current_slot = slot
	var doc: Dictionary = NightShiftSave.read(slot)
	if doc.is_empty():
		_show_slot_picker()
		return
	_load_state_from_doc(doc)
	_play_music("day")
	_show_day()


func _on_slot_new_pressed(slot: int) -> void:
	current_slot = slot
	# Ask difficulty before starting a new game.
	_show_difficulty_picker()


func _on_slot_erase_pressed(slot: int) -> void:
	NightShiftSave.clear_slot(slot)
	if current_slot == slot:
		current_slot = 0
	_show_slot_picker()


func _show_difficulty_picker() -> void:
	_dx_debug_probe_phase = true
	phase = "cover"
	_clear_card_layer()
	card_layer.visible = true
	# Difficulty picker overlays the cover background; hide hotspots.
	hotspot_layer.visible = false
	player_token.visible = false
	player_repair_token.visible = false
	_hide_radio_panel()
	_set_resource_bar_visible(false)
	prompt_label.visible = false
	prompt_label.text = ""
	log_label.visible = false
	log_label.text = ""
	if tutorial_overlay:
		tutorial_overlay.visible = false

	status_label.text = I18n.t("difficulty_pick_title")
	prompt_label.text = ""
	log_label.text = ""

	# Banner if NG+ (player has finished the chapter at least once before)
	if ng_plus_count > 0:
		var banner: Label = Label.new()
		banner.text = I18n.t("ng_plus_banner")
		banner.position = Vector2(SCREEN_SIZE.x * 0.5 - 200, 100)
		banner.size = Vector2(400, 28)
		banner.add_theme_constant_override("font_size", 16)
		banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.modulate = Color(1, 0.85, 0.5, 1)
		card_layer.add_child(banner)

	# Seed the working modifiers from the current run if any, else standard.
	if difficulty_modifiers.is_empty():
		difficulty_modifiers = NightShiftSave.modifiers_for_preset(current_difficulty)

	# Panel background for the slider stack.
	var panel := Panel.new()
	panel.position = Vector2(SCREEN_SIZE.x * 0.5 - 380, 130)
	panel.size = Vector2(760, 460)
	card_layer.add_child(panel)

	# Preset chip row at the top of the panel — clicking a chip snaps the
	# sliders to that preset's values. The active chip is highlighted.
	var chip_y: float = 144.0
	var chip_w: float = 130.0
	var chip_h: float = 36.0
	var chip_gap: float = 14.0
	var chip_count: int = NightShiftSave.DIFFICULTY_PRESETS.size()
	var chip_total: float = float(chip_count) * chip_w + float(chip_count - 1) * chip_gap
	var chip_x: float = SCREEN_SIZE.x * 0.5 - chip_total * 0.5
	var preset_buttons := {}
	for preset_name in NightShiftSave.DIFFICULTY_PRESETS:
		var chip_btn := _make_button(
			NightShiftSave.preset_label(preset_name),
			Vector2(chip_x, chip_y),
			Vector2(chip_w, chip_h),
			_on_difficulty_preset_pressed.bind(preset_name)
		)
		chip_btn.set_meta("preset", preset_name)
		preset_buttons[preset_name] = chip_btn
		card_layer.add_child(chip_btn)
		chip_x += chip_w + chip_gap
	# "Custom" chip — always shown, active when sliders don't match any preset.
	var custom_btn := _make_button(
		NightShiftSave.preset_label("custom"),
		Vector2(chip_x, chip_y),
		Vector2(chip_w, chip_h),
		_on_difficulty_custom_pressed
	)
	custom_btn.set_meta("preset", "custom")
	preset_buttons["custom"] = custom_btn
	card_layer.add_child(custom_btn)
	_dx_highlight_active_preset(preset_buttons)

	# Slider rows. One per modifier axis. Each row has: label (left), the
	# slider, and a value readout (right). Live updates mark current_difficulty
	# as "custom" so the highlight shifts.
	var slider_x: float = SCREEN_SIZE.x * 0.5 - 360.0
	var slider_w: float = 540.0
	var value_w: float = 90.0
	var label_w: float = 160.0
	var slider_top: float = 200.0
	var slider_gap: float = 50.0
	var slider_rows := {}
	for i in NightShiftSave.MODIFIER_KEYS.size():
		var key: String = NightShiftSave.MODIFIER_KEYS[i]
		var bounds: Dictionary = NightShiftSave.DIFFICULTY_BOUNDS[key]
		var y_row: float = slider_top + float(i) * slider_gap
		if _dx_debug_probe_phase:
			print("DEBUG slider loop iter ", i, " key=", key)
		# Label
		var lab: Label = Label.new()
		lab.text = I18n.t("difficulty_axis_%s" % key)
		lab.position = Vector2(slider_x, y_row + 4)
		lab.size = Vector2(label_w, 24)
		lab.add_theme_constant_override("font_size", 16)
		lab.add_theme_constant_override("outline_size", 2)
		card_layer.add_child(lab)
		# Slider
		var sld := HSlider.new()
		sld.min_value = float(bounds["min"])
		sld.max_value = float(bounds["max"])
		sld.step = float(bounds["step"])
		sld.value = float(difficulty_modifiers.get(key, float(bounds["min"])))
		sld.position = Vector2(slider_x + label_w, y_row + 4)
		sld.size = Vector2(slider_w - label_w - value_w, 24)
		sld.set_meta("modifier_key", key)
		sld.value_changed.connect(_on_difficulty_slider_changed.bind(key))
		card_layer.add_child(sld)
		# Value readout
		var val_lab: Label = Label.new()
		val_lab.text = "%.2f" % sld.value
		val_lab.position = Vector2(slider_x + slider_w - value_w + 8, y_row + 4)
		val_lab.size = Vector2(value_w, 24)
		val_lab.add_theme_constant_override("font_size", 16)
		val_lab.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
		val_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lab.set_meta("value_label", true)
		sld.set_meta("value_label", val_lab)
		card_layer.add_child(val_lab)
		slider_rows[key] = sld
	if _dx_debug_probe_phase:
		print("DEBUG slider loop done")
	_dx_slider_row_handles = slider_rows
	_dx_preset_chip_handles = preset_buttons

	# Confirm + back buttons at the bottom.
	var confirm_btn := _make_button(
		I18n.t("btn_choose"),
		Vector2(SCREEN_SIZE.x * 0.5 - 220, SCREEN_SIZE.y - 80),
		Vector2(200, 50),
		_on_difficulty_confirm
	)
	card_layer.add_child(confirm_btn)
	var back_btn := _make_button(
		I18n.t("btn_back"),
		Vector2(SCREEN_SIZE.x * 0.5 + 20, SCREEN_SIZE.y - 80),
		Vector2(200, 50),
		_show_slot_picker
	)
	card_layer.add_child(back_btn)
	print("DEBUG _show_difficulty_picker done, _show_day calls during picker=", _dx_debug_probe_count)
	_dx_debug_probe_phase = false


# Handles the preset chip buttons. Snaps sliders to the preset's values.
func _on_difficulty_preset_pressed(preset: String) -> void:
	if _dx_debug_probe_phase:
		print("DEBUG _on_difficulty_preset_pressed", preset)
	difficulty_modifiers = NightShiftSave.modifiers_for_preset(preset)
	current_difficulty = preset
	_dx_apply_modifiers_to_sliders()
	_dx_highlight_active_preset(_dx_preset_chip_handles)


func _on_difficulty_custom_pressed() -> void:
	# Keep current sliders; just mark the selection as "custom" so the
	# highlight + status text reflect that we're off-preset.
	current_difficulty = "custom"
	_dx_highlight_active_preset(_dx_preset_chip_handles)


func _on_difficulty_slider_changed(value: float, key: String) -> void:
	if _dx_debug_probe_phase:
		print("DEBUG _on_difficulty_slider_changed", key, value)
	# Update the modifier dict + the live readout label. If the resulting
	# set no longer matches the active preset, demote to "custom".
	difficulty_modifiers[key] = value
	if _dx_slider_row_handles.has(key):
		var sld: HSlider = _dx_slider_row_handles[key]
		var vlab: Label = sld.get_meta("value_label") as Label
		if vlab:
			vlab.text = "%.2f" % value
	var matched: String = NightShiftSave.matches_preset(difficulty_modifiers)
	if matched != current_difficulty:
		current_difficulty = matched
		_dx_highlight_active_preset(_dx_preset_chip_handles)


func _on_difficulty_chosen(diff: int) -> void:
	# Legacy entry point used by old tests. Translates the v3 integer into
	# the matching v4 preset name + modifier dict, then proceeds as if the
	# player picked that preset via the slider panel.
	current_difficulty = "hard" if diff == NightShiftSave.DIFFICULTY_HARD else "standard"
	difficulty_modifiers = NightShiftSave.modifiers_for_preset(current_difficulty)
	_on_difficulty_confirm()


func _on_difficulty_confirm() -> void:
	# Final clamp + normalize before saving so any drift from slider snapping
	# is cleaned up. Then write the run start doc into the slot.
	print("DEBUG _on_difficulty_confirm called")
	difficulty_modifiers = NightShiftSave.normalize_modifiers(difficulty_modifiers)
	current_difficulty = NightShiftSave.matches_preset(difficulty_modifiers)
	NightShiftSave.clear_slot(current_slot)
	night_index = 0
	resources = data.initial_resource_values()
	upgrades.clear()
	allies = {"nora": false, "elias": false, "victor": true}
	unlocked_hotspots.clear()
	day_effects = NightShiftDayEffects.new()
	radio_available = false
	radio_completed = false
	radio_missed = false
	blackout = false
	radio_contact_goal = 1
	radio_window_left = 0.0
	radio_contacts_made = 0
	# Apply difficulty-driven starting offsets (NG+ bonus is added later).
	_apply_ng_plus_bonus()
	# Persist immediately so a crash mid-night-1 still has the right state.
	NightShiftSave.write({
		"night_index": night_index,
		"resources": resources,
		"upgrades": upgrades,
		"allies": allies,
		"unlocked_hotspots": unlocked_hotspots,
		"radio_available": radio_available,
		"radio_completed": radio_completed,
		"radio_missed": radio_missed,
		"blackout": blackout,
		"radio_contact_goal": radio_contact_goal,
		"radio_window_left": radio_window_left,
		"radio_tuned_channel": radio_tuned_channel,
		"radio_contacts_made": radio_contacts_made,
		"tutorial_done": false,
		"current_difficulty": current_difficulty,
		"difficulty_modifiers": difficulty_modifiers,
		"ng_plus_count": ng_plus_count,
	}, current_slot)
	_show_day()


# Slider + chip handles cached so _on_difficulty_slider_changed can update
# them without traversing the card layer.
var _dx_slider_row_handles: Dictionary = {}
var _dx_preset_chip_handles: Dictionary = {}
var _dx_debug_probe_phase: bool = false
var _dx_debug_probe_count: int = 0


func _dx_apply_modifiers_to_sliders() -> void:
	for key in _dx_slider_row_handles:
		var sld: HSlider = _dx_slider_row_handles[key]
		sld.value = float(difficulty_modifiers.get(key, sld.value))
		var vlab: Label = sld.get_meta("value_label") as Label
		if vlab:
			vlab.text = "%.2f" % sld.value


func _dx_highlight_active_preset(chips: Dictionary) -> void:
	# Pure visual: tint the active preset chip gold, dim the rest. Must NOT
	# write saves or transition phases — that's _on_difficulty_confirm's job.
	# (Earlier this function did all of that, which caused clicking "New Game"
	# on a slot to skip past the picker entirely and jump straight to day.)
	if _dx_debug_probe_phase:
		print("DEBUG _dx_highlight_active_preset called")
	for preset_name in chips:
		var btn: Button = chips[preset_name]
		var active: bool = preset_name == current_difficulty
		btn.modulate = Color(1.0, 0.95, 0.7, 1.0) if active else Color(0.7, 0.7, 0.78, 1.0)


func _apply_ng_plus_bonus() -> void:
	# NG+ bonuses:
	#   - +1 of each starting resource
	#   - One ally (Nora) joins from night 1
	if ng_plus_count <= 0:
		return
	for k in resources:
		if resources[k] is int or resources[k] is float:
			resources[k] = int(resources[k]) + 1 * ng_plus_count
	# Trust a little higher
	if not bool(allies.get("nora", false)):
		allies["nora"] = true
		if not _ach_recruit_nora:
			_ach_recruit_nora = true
			_unlock_ach("recruit_nora")
		if bool(allies.get("nora", false)) and bool(allies.get("elias", false)) and bool(allies.get("victor", false)):
			if not _ach_all_three:
				_ach_all_three = true
				_unlock_ach("all_three_allies")
	_log("New Game+ bonus: +%d to each starting resource, Nora starts available." % ng_plus_count)


func _load_state_from_doc(doc: Dictionary) -> void:
	# Sanity-check the save before loading. A valid game always starts with a
	# non-empty resource dict (planks/parts/battery/...) — an empty one means
	# the slot got partially written by an older buggy code path (e.g. the
	# _dx_highlight_active_preset write-before-confirm bug). Wipe it and bail
	# back to the slot picker so the player can start fresh instead of
	# loading a zero-resource dead run.
	var preview_resources: Dictionary = doc.get("resources", {}) as Dictionary
	if preview_resources.is_empty():
		var bad_slot: int = current_slot
		push_warning("NightShiftGame: slot %d has corrupt/empty resources, clearing and returning to slot picker" % bad_slot)
		NightShiftSave.clear_slot(bad_slot)
		if current_slot == bad_slot:
			current_slot = 0
		_show_slot_picker()
		return
	night_index = int(doc.get("night_index", 0))
	resources = (doc.get("resources", {}) as Dictionary).duplicate(true)
	upgrades.clear()
	for k in doc.get("upgrades", {}):
		upgrades[str(k)] = true
	allies = (doc.get("allies", {"nora": false, "elias": false, "victor": true}) as Dictionary).duplicate(true)
	unlocked_hotspots = []
	for h in doc.get("unlocked_hotspots", []):
		unlocked_hotspots.append(str(h))
	radio_available = bool(doc.get("radio_available", false))
	radio_completed = bool(doc.get("radio_completed", false))
	radio_missed = bool(doc.get("radio_missed", false))
	blackout = bool(doc.get("blackout", false))
	radio_contact_goal = int(doc.get("radio_contact_goal", 1))
	radio_window_left = float(doc.get("radio_window_left", 0.0))
	radio_tuned_channel = str(doc.get("radio_tuned_channel", ""))
	radio_contacts_made = int(doc.get("radio_contacts_made", 0))
	# Difficulty: v4 saves use current_difficulty + difficulty_modifiers; v3
	# saves only had the integer 'difficulty'. Inherit either, and let
	# NightShiftSave.normalize_modifiers() bound the dict to current limits.
	var diff_name: String = str(doc.get("current_difficulty", ""))
	var diff_int: int = int(doc.get("difficulty", NightShiftSave.DIFFICULTY_NORMAL))
	if diff_name == "":
		current_difficulty = "standard" if diff_int == NightShiftSave.DIFFICULTY_NORMAL else "hard"
	else:
		current_difficulty = diff_name
	var saved_mods: Variant = doc.get("difficulty_modifiers", null)
	if saved_mods is Dictionary and not (saved_mods as Dictionary).is_empty():
		difficulty_modifiers = NightShiftSave.normalize_modifiers(saved_mods)
	else:
		difficulty_modifiers = NightShiftSave.modifiers_for_preset(current_difficulty)
	# Rebuild day_effects from upgrades
	day_effects.clear()
	for k in upgrades:
		var card: Dictionary = data.get_card(str(k))
		day_effects.add_from_card(card)
	_log("已读档：第 %d 夜" % (night_index + 1))
	_show_day()


func _on_start_pressed() -> void:
	print("DEBUG _on_start_pressed called")
	night_index = 0
	resources = data.initial_resource_values()
	upgrades.clear()
	allies = {"nora": false, "elias": false, "victor": true}
	_show_day()


# ============================================================================
# PHASE: day
# ============================================================================

# Day-card gate: a card with `requires_unlocked: ["antenna", ...]` only appears
# once every hotspot in that list is in `unlocked_hotspots`. Prevents
# "Anchor Antenna" / "Signal Battery" / "Re-route Cables" from showing on
# night 3 before antenna unlocks. Cards without the field are unconstrained.
func _card_unlocked_for_now(card: Dictionary) -> bool:
	var req: Variant = card.get("requires_unlocked", [])
	if not (req is Array) or (req as Array).is_empty():
		return true
	for h in (req as Array):
		if not unlocked_hotspots.has(str(h)):
			return false
	return true


func _show_day() -> void:
	# Permanent diagnostic probe — count how many times _show_day fires per
	# probe-window. The number tells which caller (1 = ready, 2 = confim,
	# 3 = slider chain, 4 = something new).
	if _dx_debug_probe_phase:
		_dx_debug_probe_count += 1
		print("DEBUG _show_day probe call #", _dx_debug_probe_count)
	phase = "day"
	_clear_card_layer()
	card_layer.visible = true
	# Day picker overlays the room background; hide the night-only hotspots
	# so their stale state rings don't bleed through.
	hotspot_layer.visible = false
	# Hide in-room player + radio panel — the day picker is its own UI.
	player_token.visible = false
	player_repair_token.visible = false
	_hide_radio_panel()
	_set_resource_bar_visible(false)
	prompt_label.visible = true
	log_label.visible = true
	# Hide tutorial overlay on the day picker.
	if tutorial_overlay:
		tutorial_overlay.visible = false
	if art.get("day"):
		bg.texture = art["day"]
	_play_music("day")

	var level: Dictionary = NightShiftLevels.LEVELS[night_index]
	status_label.text = I18n.t("day_header", [night_index + 1])
	prompt_label.text = I18n.t_field(level, "briefing")

	# Polish M10.5: 6-character ally strip across the top so the day
	# picker makes the "who's in the shelter right now" state visible
	# without forcing the player to read the day-card body.
	_build_ally_strip(Vector2(20, 36), 7, true)

	# Build the card list: chapter-declared + always show "start" first as free pass.
	var raw_choices: Array = level.get("choices", [])
	var pickables: Array = []
	# Each entry in raw_choices is a dict with id/title/body (from NightShiftLevels.gd).
	# We need to look up the full card (cost/gain/effects) from data.get_card.
	for entry in raw_choices:
		if entry is Dictionary:
			var cid: String = str((entry as Dictionary).get("id", ""))
			# Skip the "start" sentinel — we add our own skip card below
			if cid == "start":
				continue
			var card: Dictionary = data.get_card(cid)
			if not card.is_empty() and _card_unlocked_for_now(card):
				pickables.append(card)
		elif entry is String:
			var cid2: String = str(entry)
			if cid2 == "start":
				continue
			var card2: Dictionary = data.get_card(cid2)
			if not card2.is_empty() and _card_unlocked_for_now(card2):
				pickables.append(card2)
	# Always add a "skip" card as the last option
	var skip := {
		"id": "start",
		"name": I18n.t("btn_pick_skip"),
		"name_en": "Skip prep",
		"body": I18n.t("btn_pick_skip_desc"),
		"body_en": "No fortification. Start the night as-is.",
		"cost": {},
		"gain": {},
		"effects": []
	}
	pickables.append(skip)

	# Layout: top status, then 3 (or 4) cards in a row, then "preview effects" panel.
	# With 4 cards at 320px each + 3x18px gaps, total is 1334 > SCREEN_SIZE.x (1280),
	# pushing the first card off-screen. Shrink card_w when the row would overflow
	# so n cards always fit between side_margin cushions.
	var n: int = pickables.size()
	var card_h: float = 220.0
	var gap: float = 18.0
	var side_margin: float = 24.0
	var max_total_w: float = SCREEN_SIZE.x - side_margin * 2.0
	var card_w: float = 320.0
	if n > 1:
		card_w = min(card_w, (max_total_w - (n - 1) * gap) / float(n))
	var total_w: float = n * card_w + (n - 1) * gap
	var start_x: float = (SCREEN_SIZE.x - total_w) * 0.5
	var y: float = 130.0

	for i in range(n):
		var card: Dictionary = pickables[i]
		var card_id: String = str(card.get("id", ""))
		var title: String = I18n.t_field(card, "name")
		var body: String = I18n.t_field(card, "body")
		var cost: Dictionary = card.get("cost", {}) as Dictionary
		var gain: Dictionary = card.get("gain", {}) as Dictionary
		var effects: Array = card.get("effects", []) as Array

		var card_panel := Panel.new()
		card_panel.position = Vector2(start_x + i * (card_w + gap), y)
		card_panel.size = Vector2(card_w, card_h)
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0.12, 0.13, 0.16, 0.92)
		ps.border_color = Color(0.65, 0.55, 0.35, 0.9)
		for k in ["left", "right", "top", "bottom"]:
			ps.set("border_width_" + k, 2)
		for k in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			ps.set("corner_radius_" + k, 8)
		ps.content_margin_left = 14
		ps.content_margin_right = 14
		ps.content_margin_top = 10
		ps.content_margin_bottom = 10
		card_panel.add_theme_stylebox_override("panel", ps)
		card_layer.add_child(card_panel)

		# Card icon: art["icons"][card_id] is loaded by NightShiftArt
		# load_upgrade_icon_textures() into 27 keyed slots covering all
		# upgrade ids (door_reinforce, window_brace, battery_buffer, etc).
		# Skip-card has id="start" and no icon — just leave the slot empty.
		# Icon is a 64x64 badge in the top-left; title shifts right by 70px
		# to avoid overlap, body/effects start at y=70 below the icon row.
		var has_icon: bool = false
		var icons_bucket: Dictionary = art.get("icons", {}) as Dictionary
		if icons_bucket.has(card_id):
			var maybe: Variant = icons_bucket[card_id]
			if maybe is Texture2D:
				var icon_rect := TextureRect.new()
				icon_rect.texture = maybe
				icon_rect.position = Vector2(0, 0)
				icon_rect.size = Vector2(64, 64)
				icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				card_panel.add_child(icon_rect)
				has_icon = true

		# Title shifts right of the icon when present.
		var title_x: float = 72.0 if has_icon else 0.0
		var title_lbl := _make_label(Vector2(title_x, 0), 22, Color(0.96, 0.92, 0.78))
		title_lbl.text = title
		title_lbl.add_theme_constant_override("outline_size", 4)
		title_lbl.size = Vector2(card_w - 14 - title_x, 30)
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_panel.add_child(title_lbl)

		# Body / cost / effects shift down by 70px when an icon is in the
		# top-left so they don't sit underneath the badge.
		var body_y: float = 70.0 if has_icon else 30.0
		var cg_y: float = 120.0 if has_icon else 90.0
		var eff_y: float = 146.0 if has_icon else 116.0

		var body_lbl := _make_label(Vector2(0, body_y), 14, Color(0.85, 0.85, 0.78))
		body_lbl.text = body
		body_lbl.size = Vector2(card_w - 28, 50)
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_panel.add_child(body_lbl)

		var cost_text := _format_resource_change(cost, false)
		var gain_text := _format_resource_change(gain, true)
		var bottom_text: String = ""
		if cost_text != "":
			bottom_text += "代价：%s" % cost_text
		if gain_text != "":
			if bottom_text != "":
				bottom_text += "  "
			bottom_text += "收益：%s" % gain_text
		var cg_lbl := _make_label(
			Vector2(0, cg_y),
			13,
			Color(0.95, 0.7, 0.5) if cost_text != "" else Color(0.7, 0.85, 0.7)
		)
		cg_lbl.text = bottom_text if bottom_text != "" else "无代价/收益"
		card_panel.add_child(cg_lbl)

		# Effects preview
		var eff_lines: Array = []
		for e in effects:
			var id_e: String = str(e.get("id", ""))
			var tgt: String = str(e.get("target", ""))
			match id_e:
				"barrier_pressure":
					eff_lines.append("门窗压力 x%.2f（%s）" % [float(e.get("multiplier", 1.0)), _target_label(tgt, "全部")])
				"barrier_cap":
					eff_lines.append("门窗上限 +%.0f（%s）" % [float(e.get("bonus", 0.0)), _target_label(tgt, "全部")])
				"support_pressure":
					eff_lines.append("%s 压力 x%.2f" % [_target_label(tgt, ""), float(e.get("multiplier", 1.0))])
				"support_cap":
					eff_lines.append("%s 上限 +%.0f" % [_target_label(tgt, ""), float(e.get("bonus", 0.0))])
				"generator_drain":
					eff_lines.append("发电机掉电 x%.2f" % float(e.get("multiplier", 1.0)))
				"repair_rate":
					eff_lines.append("修复 +%.0f/秒（%s）" % [float(e.get("bonus", 0.0)), _target_label(tgt, "全部")])
				"player_speed":
					eff_lines.append("主角速度 +%.0f" % float(e.get("bonus", 0.0)))
				"radio_contact_goal":
					eff_lines.append("电台接听 %+d 次" % int(e.get("value", 0.0)))
				"radio_window":
					eff_lines.append("电台窗口 +%.0f 秒" % float(e.get("bonus", 0.0)))
				"nora_work_rate":
					eff_lines.append("Nora 速度 +%.0f" % float(e.get("bonus", 0.0)))
				"elias_work_rate":
					eff_lines.append("Elias 速度 +%.0f" % float(e.get("bonus", 0.0)))
				"helper_work_rate":
					eff_lines.append("同伴速度 +%.0f" % float(e.get("bonus", 0.0)))
				_:
					eff_lines.append("%s（%s）" % [id_e, tgt])
		if eff_lines.is_empty():
			eff_lines.append("（无附加效果）")
		var eff_text: String = "效果：\n· " + "\n· ".join(eff_lines)
		var eff_lbl := _make_label(Vector2(0, eff_y), 12, Color(0.75, 0.82, 0.95))
		eff_lbl.text = eff_text
		eff_lbl.size = Vector2(card_w - 28, 80)
		eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_panel.add_child(eff_lbl)

		# Pick button
		var pick := _make_button(
			"选择",
			Vector2(0, card_h - 38),
			Vector2(card_w - 28, 32),
			_on_day_card_pressed.bind(card_id)
		)
		card_panel.add_child(pick)

	# Resources row
	var res_text: String = "资源："
	for k in resources:
		res_text += "%s %d  " % [_resource_name(str(k)), int(resources[k])]
	log_label.text = res_text


func _target_label(target: String, default_label: String) -> String:
	if target == "":
		return "全局"
	if target == default_label:
		return default_label
	match target:
		"front_door": return "正门"
		"back_door": return "后门"
		"left_window": return "左窗"
		"right_window": return "右窗"
		"generator": return "发电机"
		"radio": return "电台"
		"antenna": return "天线"
		"medbay": return "医务角"
		"storage": return "仓库"
		"windows": return "窗户"
		"all": return "全部"
		"all_barriers": return "所有门窗"
		_: return target


func _format_resource_change(change: Dictionary, is_gain: bool) -> String:
	if change.is_empty():
		return ""
	var parts := []
	for k in change:
		var v = int(change[k])
		var name := _resource_name(str(k))
		if v == 0:
			continue
		if is_gain:
			parts.append("%s %s%+d" % [name, "+" if v > 0 else "", v])
		else:
			parts.append("%s %s%d" % [name, "-" if v < 0 else "+", abs(v)])
	return "  ".join(parts) if not parts.is_empty() else ""


func _resource_name(id: String) -> String:
	# Resources carry a `name` (zh) + `name_en` field; we localize on read.
	var r: Dictionary = data.get_resource(id)
	if r.is_empty():
		return id
	if I18n.locale == "en" and r.has("name_en") and str(r["name_en"]) != "":
		return str(r["name_en"])
	return str(r.get("name", id))


func _on_day_card_pressed(card_id: String) -> void:
	if card_id == "start" or data.get_card(card_id).is_empty():
		upgrades["start"] = true
		_log("白天选择：直接进入今晚")
		_show_night()
		return
	var card: Dictionary = data.get_card(card_id)
	var cost: Dictionary = card.get("cost", {}) as Dictionary
	if not data.can_pay(resources, cost):
		_log("资源不足，无法选择此卡：%s" % str(card.get("name", card_id)))
		_play_sfx("fail")
		return
	resources = data.apply_resource_delta(resources, cost)
	resources = data.apply_resource_delta(resources, card.get("gain", {}) as Dictionary)
	upgrades[card_id] = true
	day_effects.add_from_card(card)
	_log("白天选择：%s" % str(card.get("name", card_id)))
	_play_sfx("unlock")
	# Persist after every choice
	_save_progress()
	_show_night()


# ============================================================================
# PHASE: night
# ============================================================================

func _show_night() -> void:
	phase = "night"
	_clear_card_layer()
	card_layer.visible = false
	# Reveal the hotspot map now that we're back on the room layout.
	hotspot_layer.visible = true
	if art.get("night"):
		bg.texture = art["night"]
	# Reset the dawn-fade overlay from the previous night. Without this
	# a successful night-1 dawn fade would carry over to night 2+ and
	# cover the whole screen with a warm/white tint for the entire
	# duration of the next night. round-2 visual fix.
	fx_dawn_target = 0.0
	fx_dawn_alpha = 0.0
	# Reset the procedural background event scheduler so night 2+ has
	# a fresh cadence of background warnings (see _update_events).
	_proc_next_warning_at = -1.0
	for id in hotspots:
		if hotspots[id].has("proc_cooldown"):
			hotspots[id]["proc_cooldown"] = 0.0
	# Re-show the player token (the cover screen hides it for the silhouette
	# overlay; night play needs the walk sprite visible).
	player_token.visible = true
	player_repair_token.visible = false
	_play_music("night_early")

	var level: Dictionary = NightShiftLevels.LEVELS[night_index]
	var night_def: Dictionary = data.get_night(night_index)

	night_duration = float(night_def.get("duration", level.get("duration", 60.0)))
	# Difficulty-driven night length: harder presets get shorter nights
	# (more time pressure). Capped so casual can never exceed +50%.
	var night_mod: float = clamp(1.4 - float(difficulty_modifiers.get("enemy_count", 1.0)) * 0.3, 0.7, 1.5)
	night_duration *= night_mod
	night_elapsed = 0.0
	survived = false
	player_target_id = ""
	player_at_target = false
	events_done.clear()
	logs.clear()
	flash_rect.visible = false
	enemy_tokens.clear()
	enemy_spawn_cooldown = 0.0
	radio_window_left = 0.0
	radio_contact_goal = 1 + day_effects.get_radio_goal_delta()
	radio_contact_progress = 0.0
	radio_contacts_made = 0
	radio_tuned_channel = ""
	radio_target_channel = str(night_def.get("radio_target_channel", ""))
	radio_channels_catalog = []
	radio_wrong_ticks.clear()
	# Build the channel catalog: prefer per-night data, fall back to global catalog.
	# `night_channels` may be null (older night data) — guard the cast.
	var raw_night_channels: Variant = night_def.get("radio_channels", [])
	var night_channels: Array = raw_night_channels if raw_night_channels is Array else []
	if not night_channels.is_empty():
		for ch in night_channels:
			radio_channels_catalog.append({
				"id": str(ch.get("id", "")),
				"label": str(ch.get("label", ch.get("id", ""))),
				"desc": str(ch.get("desc", "")),
				"color": str(ch.get("color", "#9CD9FF")),
				"exposure_on_wrong": float(ch.get("exposure_on_wrong", 0.0)),
			})
	else:
		radio_channels_catalog = data.get_signal_catalog()
	if radio_channels_catalog.is_empty():
		# signals.json missing or empty — fall back to a hard-coded 3-channel
		# list so the radio UI still functions in degraded setups.
		radio_channels_catalog = _fallback_signal_catalog()
	# Reset per-night stats for the report screen.
	night_stats = {
		"radio_contacts": 0,
		"enemies_despawned": 0,
		"hotfixes": 0,
		"breaches": 0,
		"breaches_first_id": "",
		"events_fired": 0,
	}

	# Build hotspot set from chapter data; fall back to level's stated list.
	unlocked_hotspots = []
	var declared: Array = night_def.get("unlocked_hotspots", []) as Array
	for id in declared:
		unlocked_hotspots.append(str(id))
	hotspots.clear()
	for id in unlocked_hotspots:
		if not HOTSPOT_POSITIONS.has(id):
			continue
		var kind: String = HOTSPOT_KIND.get(id, "support")
		var max_val: float = 100.0
		# Cap bonus only applies to the right kind of hotspot
		if kind == "barrier" and day_effects.get_cap_bonus(str(id)) > 0.0:
			max_val += day_effects.get_cap_bonus(str(id))
		elif kind == "support" and day_effects.get_cap_bonus(str(id)) > 0.0:
			# support_cap targets are usually already id-specific
			max_val += day_effects.get_cap_bonus(str(id))
		max_val = max(10.0, max_val)
		hotspots[id] = {
			"id": id,
			"kind": kind,
			"pos": HOTSPOT_POSITIONS[id],
			"value": max_val,
			"max_value": max_val,
			"pressure": 0.0,
			"active": false,
			"warning": false,
			"assault": false,
			"breach_timer": -1.0,
			"temp_seal": 0.0
		}
	# Reset player position to room center
	player_pos = Vector2(SCREEN_SIZE.x * 0.5, SCREEN_SIZE.y * 0.55)

	# Build event queue from night_def.fixed_events
	event_queue.clear()
	for ev in night_def.get("fixed_events", []):
		event_queue.append({
			"id": str(ev.get("id", "")),
			"time": float(ev.get("time", 0.0)),
			"type": str(ev.get("type", "warning")),
			"target": str(ev.get("target", "")),
			"pressure": float(ev.get("pressure", 0.0))
		})
	event_queue.sort_custom(func(a, b): return a["time"] < b["time"])

	# Story intro — pick the localized array based on current locale.
	var story_field: String = "story_start_en" if I18n.locale == "en" else "story_start"
	var story: Array = level.get(story_field, level.get("story_start", [])) as Array
	if not story.is_empty():
		_log(str(story[0]))
	else:
		_log("第 %d 夜开始。" % (night_index + 1))

	_rebuild_hotspot_visuals()
	_rebuild_zombie_outside_sprites()
	_draw_player()
	_update_status_label()
	_update_visual_feedback()

	# Wire FX layer to current hotspot positions (re-read every night since
	# unlocked_hotspots changes the set) and reset transient FX state.
	if fx_layer:
		var positions: Dictionary = {}
		for id in hotspots:
			positions[id] = hotspots[id]["pos"]
		fx_layer._fx_set_refs(fx_particles, fx_telegraphs, fx_shake, positions)
		fx_layer._fx_mark_dirty()
	fx_combo_count = 0
	fx_combo_time_left = 0.0
	_fx_combo_accum = 0.0
	fx_threat_arrows.clear()
	fx_threat_phase = 0.0
	fx_critical_alpha = 0.0
	fx_particles.clear()
	fx_telegraphs.clear()
	fx_shake = {"amount": 0.0, "decay": 6.0, "freq": 28.0, "phase": 0.0}
	fx_last_damage_tier.clear()

	# Tutorial overlay: only on Night 0, only if the save hasn't completed
	# the tutorial. If there's no save, this is the very first run — show it.
	_maybe_start_tutorial()


func _maybe_start_tutorial() -> void:
	if not tutorial_overlay:
		return
	if night_index != 0:
		return
	if tutorial_overlay.is_active():
		return
	if current_slot > 0 and NightShiftSave.read(current_slot).get("tutorial_done", false):
		return
	tutorial_overlay.start()


func _rebuild_hotspot_visuals() -> void:
	for child in hotspot_layer.get_children():
		child.queue_free()
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		var node := _make_hotspot_node(id, h)
		hotspot_layer.add_child(node)


# Build / refresh one zombie sprite per barrier hotspot (door + window).
# Sprites start hidden; _world_tick() flips them visible and animates them
# based on telegraph state. Sprites are placed at the hotspot position
# plus an anchor offset so doors have the body extending UP (off-screen)
# and windows have it extending SIDE (off-screen left/right).
func _rebuild_zombie_outside_sprites() -> void:
	if zombie_outside_layer == null:
		return
	for child in zombie_outside_layer.get_children():
		child.queue_free()
	zombie_outside_sprites.clear()
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if h.get("kind", "") != "barrier":
			continue
		var sprite := Sprite2D.new()
		sprite.name = "ZombieOutside_%s" % id
		sprite.texture = _zombie_tex_for(id, false)
		sprite.centered = true
		var anchor: Vector2 = WorldFx.zombie_anchor_offset(id)
		sprite.position = h["pos"] + anchor
		# Approx target height: ~360px on a 720-tall screen. The texture is
		# 1434x1920 so a scale of 0.18 gives ~345px tall.
		sprite.scale = Vector2(0.18, 0.18)
		sprite.modulate.a = 0.0
		sprite.visible = false
		zombie_outside_layer.add_child(sprite)
		zombie_outside_sprites[id] = {
			"sprite": sprite,
			"sway_acc": {"sway_phase": 0.0},
			"last_phase": WorldFx.ZOMBIE_PHASE_HIDDEN,
		}


# Pick the right texture pair for a hotspot. Doors use door sprites;
# windows use window sprites. `breach` selects between approach / breach.
func _zombie_tex_for(id: String, breach: bool) -> Texture2D:
	var is_window: bool = id.find("window") >= 0
	if breach:
		return zombie_breach_window_tex if is_window else zombie_breach_door_tex
	return zombie_approach_window_tex if is_window else zombie_approach_door_tex


func _make_hotspot_node(id: String, data_dict: Dictionary) -> Button:
	# Button is a Control — set its top-left so that the clickable area is
	# centered on the hotspot's world position. The button footprint is
	# HOTSPOT_BTN_SIZE (art + a thin integrity bar). The Art TextureRect
	# is the FIRST child so it renders BEHIND everything else; HotspotDot
	# then draws the state overlays (progress arc, warning, target ring,
	# locked) on top of the illustration.
	var btn := Button.new()
	var pos: Vector2 = data_dict["pos"]
	btn.position = pos - Vector2(HOTSPOT_ART_SIZE.x * 0.5, HOTSPOT_ART_SIZE.y * 0.5)
	btn.size = HOTSPOT_BTN_SIZE
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE

	# ART — the actual hotspot illustration (front_door/window/generator/
	# antenna/medbay/storage/radio). Texture is set later by
	# _update_visual_feedback via NightShiftArt.hotspot_texture_key().
	var art := TextureRect.new()
	art.name = "Art"
	art.position = Vector2(0, 0)
	art.size = HOTSPOT_ART_SIZE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(art)

	# HotspotDot draws the state overlays (progress arc, warning ring,
	# target ring, locked). It is sized to match the new art footprint.
	var dot := HotspotDot.new()
	dot.name = "Dot"
	dot.position = Vector2(0, 0)
	btn.add_child(dot)

	# Integrity bar background (under the art, sits in y=120..128).
	var bar_bg := ColorRect.new()
	bar_bg.name = "BarBg"
	bar_bg.position = Vector2(8, 124)
	bar_bg.size = Vector2(104, 6)
	bar_bg.color = Color(0, 0, 0, 0.6)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bar_bg)

	# Integrity bar fill
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.position = Vector2(8, 124)
	bar.size = Vector2(104, 6)
	bar.color = Color(0.4, 0.9, 0.4)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(bar)

	# Label above the art
	var lbl := Label.new()
	lbl.name = "Label"
	lbl.position = Vector2(-4, -22)
	lbl.size = Vector2(128, 18)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.text = _hotspot_label(id)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)

	btn.pressed.connect(_on_hotspot_pressed.bind(id))
	btn.set_meta("hotspot_id", id)
	return btn


func _hotspot_label(id: String) -> String:
	match id:
		"front_door": return I18n.t("hotspot_front_door")
		"back_door": return I18n.t("hotspot_back_door")
		"left_window": return I18n.t("hotspot_left_window")
		"right_window": return I18n.t("hotspot_right_window")
		"generator": return I18n.t("hotspot_generator")
		"radio": return I18n.t("hotspot_radio")
		"antenna": return I18n.t("hotspot_antenna")
		"medbay": return I18n.t("hotspot_medbay")
		"storage": return I18n.t("hotspot_storage")
		_: return id


func _on_hotspot_pressed(id: String) -> void:
	if phase != "night":
		return
	if not hotspots.has(id):
		return
	# Tutorial gate: any hotspot click counts as "they get the idea".
	if tutorial_overlay:
		tutorial_overlay.notify_hotspot_clicked()
	player_target_id = id
	_log("走向：%s" % _hotspot_label(id))


# ============================================================================
# PHASE: night loop
# ============================================================================

func _process(delta: float) -> void:
	# Report-music transition: when a one-shot success/failure sting ends,
	# the looping `music_report` bed takes over so the report screen has
	# its own ambient music instead of silence. Flag-based polling is more
	# robust than `await music_player.finished` because it survives the
	# player advancing to day or retrying mid-sting.
	if _pending_report_music and music_player:
		if not music_player.playing:
			_play_music("report", true)
			_pending_report_music = false
	if phase == "night":
		_update_night(delta)


func _update_night(delta: float) -> void:
	_update_player_movement(delta)
	_update_player_target_reached()
	_update_hotspots(delta)
	_update_events(delta)
	_update_radio(delta)
	_update_enemies(delta)
	_tick_npcs(delta)
	_update_visual_feedback()
	_update_status_label()
	_update_radio_panel()
	_fx_tick(delta)

	night_elapsed += delta
	if night_elapsed >= night_duration:
		_end_night(true)


# ----------------------------------------------------------------------------
# Procedural FX (particles, screen shake, telegraphs)
# ----------------------------------------------------------------------------

func _fx_tick(delta: float) -> void:
	# Particles advance; if we hit the cap, drop the oldest first so a long
	# battle doesn't slowly push newer ones out of frame.
	while fx_particles.size() > FX_PARTICLE_LIMIT:
		fx_particles.pop_front()
	Fx.tick_particles(fx_particles, delta)
	# Telegraphs pulse and (when their timer expires) return a fired-list for
	# the game to translate into actual assault events.
	Fx.telegraph_phase_tick(fx_telegraphs, delta)
	var fired: Array = Fx.telegraph_tick(fx_telegraphs, delta)
	for t in fired:
		# Replay the trigger event the telegraph was warning about. By the
		# time the warning timer hits zero, the player has had FX_TELEGRAPH_LEAD_TIME
		# seconds to react (move closer, brace, etc).
		_fx_fire_telegraph(t)
	# Shake decay.
	Fx.shake_tick(fx_shake, delta)
	# Apply shake offset to the world-position layers (player + enemies +
	# hotspots) so an impact feels like the room flinching. HUD labels are
	# exempt so the timer / status don't dance around.
	if fx_shake.get("amount", 0.0) > 0.0:
		var off: Vector2 = Fx.shake_offset(fx_shake)
		hotspot_layer.position = off
		enemy_layer.position = off
		player_token.position = player_pos + off
		fx_layer._fx_mark_dirty()
	else:
		if hotspot_layer.position != Vector2.ZERO:
			hotspot_layer.position = Vector2.ZERO
			enemy_layer.position = Vector2.ZERO
			player_token.position = player_pos
			fx_layer._fx_mark_dirty()
	# No shake but content is on screen — still need to redraw so the
	# particles advance. queue_redraw() is cheap when the canvas is small.
	if fx_particles.size() > 0 or fx_telegraphs.size() > 0 or fx_threat_arrows.size() > 0:
		fx_layer._fx_mark_dirty()

	# Repair-combo timer. _fx_on_repair_hit() extends the timer; if it
	# expires without another repair, the combo resets.
	if fx_combo_time_left > 0.0:
		fx_combo_time_left -= delta
		if fx_combo_time_left <= 0.0:
			fx_combo_time_left = 0.0
			if fx_combo_count >= 2:
				# Show the combo result on the log so the player notices.
				_log("维修连击结束：x%d（信任+%d）" % [fx_combo_count, fx_combo_count * COMBO_TRUST_BONUS])
			fx_combo_count = 0

	# Critical-tier overlay: alpha tracks the count of tier-3 hotspots,
	# pulsing at a steady rate so it feels alive but not seizure-y.
	var crit_count: int = 0
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if h["breach_timer"] >= 0.0:
			continue
		if float(h["value"]) / max(1.0, float(h["max_value"])) <= 0.25:
			crit_count += 1
	var target_alpha: float = 0.0
	if crit_count > 0:
		# Pulse 0.18..0.42 alpha at ~2Hz, scaled by crit_count (1..4).
		var pulse: float = 0.5 + 0.5 * sin(fx_threat_phase * 4.0)
		target_alpha = (0.18 + 0.08 * float(min(crit_count, 4))) * pulse
	# Smooth toward target so alpha doesn't snap on/off.
	fx_critical_alpha = lerp(fx_critical_alpha, target_alpha, min(1.0, delta * 6.0))
	if fx_critical_overlay:
		fx_critical_overlay.color.a = fx_critical_alpha

	# Radio static overlay: fade in when the player is tuned to the static
	# channel while the radio is active. Fade out otherwise. The actual
	# noise pattern is drawn by fx_layer in its _draw().
	fx_static_target = 0.0
	if radio_available and not radio_completed and radio_tuned_channel == "static":
		fx_static_target = 0.55
	fx_static_alpha = lerp(fx_static_alpha, fx_static_target, min(1.0, delta * 5.0))

	# Dawn fade: smoothly chase the target alpha (0 normally, set by
	# _end_night to 1 on success so the report screen fades in).
	fx_dawn_alpha = lerp(fx_dawn_alpha, fx_dawn_target, min(1.0, delta / DAWN_FADE_DURATION))

	# Footstep dust — only when the player is actually moving this frame.
	# Walking on carpet (inside the stadium) kicks up very little; the
	# stadium floor is dusty so a few specks reads as physicality without
	# covering the screen.
	if player_is_moving:
		fx_footstep_accum += delta
		while fx_footstep_accum >= FOOTSTEP_INTERVAL:
			fx_footstep_accum -= FOOTSTEP_INTERVAL
			var foot: Vector2 = player_pos + Vector2(0.0, 14.0)
			Fx.spawn_particle(
				fx_particles, foot, Vector2(-6.0 + randf() * 12.0, -10.0 - randf() * 8.0),
				0.35, Color(0.7, 0.62, 0.5, 0.6), 1.6, Fx.PARTICLE_KIND_DOT, 90.0
			)
			Fx.spawn_particle(
				fx_particles, foot, Vector2(-4.0 + randf() * 8.0, -6.0 - randf() * 4.0),
				0.28, Color(0.75, 0.68, 0.55, 0.5), 1.2, Fx.PARTICLE_KIND_DOT, 80.0
			)
			# One SFX per dust puff (alternates phase so a left/right pattern
			# is possible later). Cheap: the stream's already loaded.
			_play_sfx("footstep")
			fx_footstep_phase += 1
	else:
		# Drain the accumulator while idle so the first step after a long
		# pause doesn't immediately spit a cloud of dust.
		fx_footstep_accum = max(0.0, fx_footstep_accum - delta)

	# Threat arrows: build the arrow list fresh each frame. An arrow appears
	# for each assaulting hotspot that's either off-screen or beyond an
	# arrow-distance threshold from the player. Strength scales with how
	# badly damaged the hotspot is.
	fx_threat_arrows.clear()
	fx_threat_phase += delta
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if not bool(h.get("assault", false)):
			continue
		var pos: Vector2 = h.get("pos", Vector2.ZERO)
		var to: Vector2 = pos - player_pos
		var dist: float = to.length()
		var on_screen: bool = pos.x > 40.0 and pos.x < SCREEN_SIZE.x - 40.0 \
			and pos.y > 40.0 and pos.y < SCREEN_SIZE.y - 40.0
		var show_arrow: bool = not on_screen or dist > 320.0
		if not show_arrow:
			continue
		var hp_ratio: float = float(h.get("value", 1.0)) / max(1.0, float(h.get("max_value", 1.0)))
		var strength: float = clamp(1.0 - hp_ratio, 0.2, 1.0)
		fx_threat_arrows.append({
			"id": id,
			"target_pos": pos,
			"player_pos": player_pos,
			"strength": strength,
		})
	# Push the latest threat-arrow list to the fx layer so it can render.
	if fx_layer:
		fx_layer._fx_set_threat_arrows(fx_threat_arrows, fx_threat_phase)
		fx_layer._fx_set_overlays(fx_static_alpha, fx_dawn_alpha)
		fx_layer._fx_mark_dirty()

	# World-layer parallax + outside-zombie sprites. Independent from the
	# rest of the FX tick because the world layer renders in its own scene
	# tree positions (CanvasLayer-anchored, not shake-offset).
	_world_tick(delta)


# Drive world-layer parallax + per-hotspot zombie sprites. Called once per
# frame from _fx_tick. Reads fx_telegraphs + hotspots; mutates Sprite2D
# state. Pure data in / draw out — no particle spawning, no events fired.
func _world_tick(delta: float) -> void:
	# 1. Parallax drift on the background plates.
	world_parallax_phase += delta
	if world_layer_far:
		var far_off: Vector2 = WorldFx.parallax_offset(world_parallax_phase, 0, 6.0)
		world_layer_far.position = far_off
	if world_layer_mid:
		var mid_off: Vector2 = WorldFx.parallax_offset(world_parallax_phase, 1, 10.0)
		world_layer_mid.position = mid_off

	# 2. Build a quick id → telegraph lookup so the sprite loop is O(N+M).
	var telegraph_by_id: Dictionary = {}
	for t in fx_telegraphs:
		telegraph_by_id[str(t.get("hotspot_id", ""))] = t

	# 3. Update each barrier hotspot's sprite based on its current state.
	for id in zombie_outside_sprites:
		var entry: Dictionary = zombie_outside_sprites[id]
		var sprite: Sprite2D = entry["sprite"]
		if sprite == null:
			continue
		var sway_acc: Dictionary = entry["sway_acc"]
		# Resolve state → animation values
		var state: Dictionary
		if telegraph_by_id.has(id):
			state = WorldFx.zombie_phase_from_telegraph(
				telegraph_by_id[id], delta, sway_acc
			)
		elif hotspots.has(id) and bool(hotspots[id].get("assault", false)):
			# Assault is on but no telegraph is currently scheduled
			# (e.g. telegraph already fired but the event hasn't reset yet)
			state = WorldFx.zombie_phase_persisting(sway_acc, delta)
		else:
			state = WorldFx.zombie_phase_hidden(sway_acc)
		# Swap texture when crossing into / out of breach phase
		var new_phase: int = int(state["phase"])
		if new_phase != int(entry.get("last_phase", WorldFx.ZOMBIE_PHASE_HIDDEN)):
			var breach: bool = (new_phase == WorldFx.ZOMBIE_PHASE_BREACH)
			sprite.texture = _zombie_tex_for(id, breach)
			entry["last_phase"] = new_phase
		# Apply animation values
		var alpha: float = float(state["alpha"])
		var bob: float = float(state["bob_y"])
		var sc: float = float(state["scale"])
		var col: Color = sprite.modulate
		col.a = alpha
		sprite.modulate = col
		var anchor: Vector2 = WorldFx.zombie_anchor_offset(id)
		var hotspot_pos: Vector2 = (
			hotspots[id]["pos"] if hotspots.has(id) else Vector2.ZERO
		)
		sprite.position = hotspot_pos + anchor + Vector2(0.0, bob)
		sprite.scale = Vector2(0.18, 0.18) * sc
		# Visibility: only draw if alpha is above a tiny threshold so we
		# don't keep an invisible-but-still-rendering sprite around.
		sprite.visible = alpha > 0.01


func _fx_fire_telegraph(t: Dictionary) -> void:
	# Translate a timed-out telegraph into the real event. Mirrors the
	# body of _trigger_event for the assault case so we don't double-trigger.
	var id: String = str(t.get("hotspot_id", ""))
	var kind: String = str(t.get("kind", "assault"))
	if not hotspots.has(id):
		return
	var h: Dictionary = hotspots[id]
	match kind:
		"assault":
			h["assault"] = true
			h["warning"] = false
			h["pressure"] = min(1.0, h["pressure"] + 0.15)
			_play_sfx("breath")
			_log("%s 被冲击。" % _hotspot_label(id))
			Fx.shake_trigger(fx_shake, 4.0, 5.0, 24.0)
			# Particle burst keyed to hotspot kind (window vs door vs support).
			_fx_burst_for_kind(id, h, 1.0)
		"breach":
			# Forced breach — only used if some future event wants to bypass
			# the natural value==0 path. Treat like a regular breach.
			h["value"] = 0.0
			h["breach_timer"] = 0.0


func _fx_burst_for_kind(id: String, h: Dictionary, intensity: float) -> void:
	var kind: String = h.get("kind", "")
	var pos: Vector2 = h.get("pos", Vector2.ZERO)
	match kind:
		"barrier":
			# Doors and windows are barrier hotspots. Use the hotspot id to
			# pick the visual (cracks vs splinters).
			if id.find("window") >= 0:
				Fx.burst_window_crack(fx_particles, pos, intensity)
			else:
				Fx.burst_door_splinter(fx_particles, pos, intensity)
		"generator":
			Fx.burst_spark(fx_particles, pos, intensity)
		"support":
			# Antenna + radio + medbay + storage: amber static-ish spark.
			Fx.burst_spark(fx_particles, pos, intensity * 0.7)
		_:
			Fx.burst_window_crack(fx_particles, pos, intensity)


func _fx_damage_tier(value: float, max_value: float) -> int:
	# 0 = pristine, 1 = light damage, 2 = heavy damage, 3 = critical
	if max_value <= 0.0:
		return 0
	var ratio: float = value / max_value
	if ratio > 0.75:
		return 0
	if ratio > 0.5:
		return 1
	if ratio > 0.25:
		return 2
	return 3


# Repair-combo tick. Called every frame while the player is repairing a
# hotspot. Accumulates fractional seconds; when a full second passes, the
# combo step increments and the trust bonus for the new step is paid out
# immediately (so the player feels each chain reward land).
var _fx_combo_accum: float = 0.0
func _fx_on_repair_tick(id: String, delta: float) -> void:
	# Combo only applies to barriers / generator / antenna / support —
	# radio and medbay don't take repair damage in the same way, and
	# standing at them for a contact or healing should not snowball trust.
	var kind: String = ""
	if hotspots.has(id):
		kind = String(hotspots[id].get("kind", ""))
	if kind not in ["barrier", "generator", "antenna", "support"]:
		return
	fx_combo_time_left = COMBO_WINDOW
	_fx_combo_accum += delta
	if _fx_combo_accum >= 1.0:
		var steps: int = int(floor(_fx_combo_accum))
		_fx_combo_accum -= float(steps)
		fx_combo_count += steps
		# Trust bonus per chain step, scaled lightly so a long combo pays
		# meaningful trust without trivialising the resource.
		# Wood-plank nail SFX fires once per combo step (not every frame) so
		# the player gets a percussive hit on each chain payout.
		_play_sfx("wood_plank_nail")
		_apply_trust_delta(COMBO_TRUST_BONUS, "repair combo x%d" % fx_combo_count)
		_log("维修连击 x%d (+%d 信任)" % [fx_combo_count, COMBO_TRUST_BONUS])


# Seconds the player must stand on the radio to score one contact.
const RADIO_CONTACT_SECONDS := 3.0


# ---- radio interaction -------------------------------------------------

func _update_radio(delta: float) -> void:
	if not radio_available or radio_completed:
		# Idle: don't tick the progress bar.
		radio_contact_progress = 0.0
		return
	# Time-window countdown.
	if radio_window_left > 0.0:
		radio_window_left = max(0.0, radio_window_left - delta)
		if radio_window_left <= 0.0:
			radio_available = false
			radio_missed = true
			radio_contact_progress = 0.0
			_log("电台窗口结束，没接住全部呼叫。")
			_play_sfx("fail")
			# Reward hook: missed window raises exposure.
			_apply_exposure_delta(1.0, "missed window")
			_save_progress()
			return
	# Progress only while the player is at the radio hotspot AND tuned to the
	# correct channel. If the player hasn't tuned yet, or tuned to a wrong
	# channel, do not advance the contact timer.
	var at_radio: bool = player_target_id == "radio" and player_at_target
	if at_radio:
		if hotspots.has("radio") and hotspots["radio"]["breach_timer"] >= 0.0:
			# Radio itself is breached — can't progress.
			radio_contact_progress = 0.0
			return
		if radio_target_channel != "" and radio_tuned_channel != radio_target_channel:
			# Wrong channel: charge once per channel per session, then idle.
			if not radio_wrong_ticks.get(radio_tuned_channel, false):
				radio_wrong_ticks[radio_tuned_channel] = true
				var wrong_exp: float = _channel_exposure_on_wrong(radio_tuned_channel)
				if wrong_exp > 0.0:
					_apply_exposure_delta(wrong_exp, "wrong channel %s" % radio_tuned_channel)
			radio_contact_progress = 0.0
			return
		radio_contact_progress += delta
		if radio_contact_progress >= RADIO_CONTACT_SECONDS:
			_complete_radio_contact()
	else:
		# Stepped away — slowly bleed progress so accidental passes don't count.
		radio_contact_progress = max(0.0, radio_contact_progress - delta * 0.5)


func _complete_radio_contact() -> void:
	radio_contact_progress = 0.0
	radio_contacts_made += 1
	night_stats["radio_contacts"] = int(night_stats.get("radio_contacts", 0)) + 1
	if not _ach_first_contact:
		_ach_first_contact = true
		_unlock_ach("first_contact")
	if radio_target_channel == "victor" and not _ach_reach_victor:
		_ach_reach_victor = true
		_unlock_ach("reach_victor")
	# Reward hook: a successful contact raises trust.
	_apply_trust_delta(1, "radio contact")
	_play_sfx("unlock")
	# Visual celebration: ring burst at the radio hotspot. Soft glow so it
	# doesn't compete with breach alarms; trust is a positive moment.
	if hotspots.has("radio"):
		Fx.burst_radio_contact(fx_particles, hotspots["radio"]["pos"])
		Fx.shake_trigger(fx_shake, 2.5, 7.0, 30.0)
	if radio_contacts_made >= radio_contact_goal:
		radio_completed = true
		_log("电台接通完成：%d/%d 次。" % [radio_contacts_made, radio_contact_goal])
	else:
		_log("电台接通 %d/%d 次。" % [radio_contacts_made, radio_contact_goal])
	_save_progress()


func _channel_exposure_on_wrong(channel_id: String) -> float:
	for ch in radio_channels_catalog:
		if str(ch.get("id", "")) == channel_id:
			return float(ch.get("exposure_on_wrong", 0.0))
	return 0.0


func _apply_trust_delta(delta: int, reason: String) -> void:
	if resources.is_empty():
		return
	var before: int = int(resources.get("trust", 0))
	resources = data.apply_resource_delta(resources, {"trust": delta})
	var after: int = int(resources.get("trust", 0))
	if after != before:
		var sign: String = "+" if delta > 0 else ""
		_log("信任 %s%d (%s)" % [sign, delta, reason])


func _apply_exposure_delta(delta: float, reason: String) -> void:
	if resources.is_empty():
		return
	var before: int = int(resources.get("exposure", 0))
	resources = data.apply_resource_delta(resources, {"exposure": int(round(delta))})
	var after: int = int(resources.get("exposure", 0))
	if after != before:
		var sign: String = "+" if delta > 0 else ""
		_log("暴露度 %s%d (%s)" % [sign, int(round(delta)), reason])


func _is_radio_active() -> bool:
	return radio_available and not radio_completed and radio_window_left > 0.0


# ---- save / load --------------------------------------------------------

func _save_progress() -> void:
	if current_slot <= 0:
		return
	NightShiftSave.write({
		"night_index": night_index,
		"resources": resources,
		"upgrades": upgrades,
		"allies": allies,
		"unlocked_hotspots": unlocked_hotspots,
		"radio_available": radio_available,
		"radio_completed": radio_completed,
		"radio_missed": radio_missed,
		"blackout": blackout,
		"radio_contact_goal": radio_contact_goal,
		"radio_window_left": radio_window_left,
		"radio_tuned_channel": radio_tuned_channel,
		"radio_contacts_made": radio_contacts_made,
		"tutorial_done": current_slot > 0 and NightShiftSave.read(current_slot).get("tutorial_done", false),
		"current_difficulty": current_difficulty,
		"difficulty_modifiers": difficulty_modifiers,
		"difficulty": NightShiftSave.DIFFICULTY_HARD if current_difficulty == "hard" else NightShiftSave.DIFFICULTY_NORMAL,
		"ng_plus_count": ng_plus_count,
	}, current_slot)


# ---- enemies (breach visualization) -------------------------------------

func _update_enemies(delta: float) -> void:
	# Spawn enemies at assaulted hotspots
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if h["assault"] and not enemy_tokens.has(id):
			_spawn_enemy_swarm(id, h)
		elif not h["assault"] and enemy_tokens.has(id):
			_dismiss_enemy_swarm(id)

	# Move existing enemies toward their hotspot; on reach sit + bump value.
	# When the hotspot is no longer being assaulted, all enemies for that hotspot
	# fade out over time (faster than 10%/s) instead of being trapped mid-flight.
	for id in enemy_tokens.keys():
		var list: Array = enemy_tokens[id]
		var alive := []
		var target_pos: Vector2 = hotspots[id]["pos"] if hotspots.has(id) else Vector2.ZERO
		var still_assaulted: bool = hotspots.has(id) and bool(hotspots[id].get("assault", false))
		for e in list:
			var pos: Vector2 = e["pos"]
			var to := target_pos - pos
			if still_assaulted:
				if to.length() > 28.0:
					pos += to.normalized() * 60.0 * delta
					e["pos"] = pos
					alive.append(e)
				else:
					# On top of hotspot — apply tick pressure
					if hotspots.has(id) and hotspots[id]["breach_timer"] < 0.0:
						var h: Dictionary = hotspots[id]
						h["value"] = max(0.0, h["value"] - 4.0 * delta)
					# Slowly despawn (10% per second) so we don't pile up forever
					e["life"] = float(e.get("life", 1.0)) - 0.1 * delta
					if float(e["life"]) > 0.0:
						alive.append(e)
			else:
				# Assault dismissed — keep drifting toward the hotspot for visual
				# continuity, but tick life down faster (33%/s) so the swarm clears
				# within ~3 seconds.
				if to.length() > 4.0:
					pos += to.normalized() * 30.0 * delta
					e["pos"] = pos
				e["life"] = float(e.get("life", 1.0)) - 0.33 * delta
				if float(e["life"]) > 0.0:
					alive.append(e)
		if alive.is_empty():
			night_stats["enemies_despawned"] = int(night_stats.get("enemies_despawned", 0)) + 1
			enemy_tokens.erase(id)
		else:
			enemy_tokens[id] = alive
	# Redraw enemy nodes
	_redraw_enemy_visuals()


func _spawn_enemy_swarm(id: String, h: Dictionary) -> void:
	# Difficulty enemy_count multiplier scales the per-assault swarm size.
	# 0.5x = ~half as many, 2.0x = double. Floor of 1 enemy so even casual
	# has visible pressure on the screen.
	var count: int = 2 + rng.randi_range(0, 2)
	var enemy_mult: float = float(difficulty_modifiers.get("enemy_count", 1.0))
	count = max(1, int(round(float(count) * enemy_mult)))
	var center: Vector2 = h["pos"]
	var list: Array = []
	for i in range(count):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = 320.0 + rng.randf_range(0.0, 120.0)
		var start := center + Vector2(cos(angle), sin(angle)) * dist
		# Keep start on screen
		start.x = clamp(start.x, 60.0, SCREEN_SIZE.x - 60.0)
		start.y = clamp(start.y, 90.0, SCREEN_SIZE.y - 90.0)
		list.append({"pos": start, "life": 1.0, "size": rng.randf_range(7.0, 11.0), "tint": rng.randf()})
	enemy_tokens[id] = list
	_play_sfx("breach_alarm")


func _dismiss_enemy_swarm(_id: String) -> void:
	# Let them despawn naturally on next tick
	pass


func _redraw_enemy_visuals() -> void:
	for child in enemy_layer.get_children():
		child.queue_free()
	for id in enemy_tokens:
		var list: Array = enemy_tokens[id]
		for e in list:
			var dot := Node2D.new()
			# Jitter (±2 px per redraw) so the zombie read as "shambling",
			# not as a person standing still. polish spec §5.2.
			var jitter := Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
			dot.position = (e["pos"] as Vector2) + jitter
			dot.set_script(_make_enemy_dot_script(float(e["size"])))
			enemy_layer.add_child(dot)


func _make_enemy_dot_script(size: float) -> GDScript:
	var script := GDScript.new()
	script.source_code = """
extends Node2D
func _draw() -> void:
	var s := %f
	# Pale-green body — "definitely not a person" tint (polish spec §5.2).
	draw_circle(Vector2.ZERO, s, Color(0.55, 0.72, 0.48, 0.95))
	# Dark-green inner
	draw_circle(Vector2.ZERO, s * 0.5, Color(0.18, 0.32, 0.16, 1.0))
	# Sickly glow
	draw_arc(Vector2.ZERO, s * 1.4, 0, TAU, 18, Color(0.65, 0.85, 0.55, 0.45), 1.5)
""" % size
	script.reload()
	return script


# Called by NightShiftActors.decide_target as the `unlocked` callable.
# Returns true when `id` is in the current night's unlocked_hotspots.
func _is_unlocked(id: String) -> bool:
	return unlocked_hotspots.has(id)


# Per-NPC tick. Implements polish spec §4.2 rules 1-4 via
# NightShiftActors.decide_target + state-machine timers. Behaviour is
# intentionally light: emergency-only target pick, soft-lock 2s after a
# target change, defer to player, walk cooldown 1.5s after a target change.
# When close enough to the target hotspot, the NPC softly restores value
# (Nora ~12/s on windows, Elias ~10/s on antenna/radio) and clears the
# breach_timer if it had started ticking down.
func _tick_npcs(delta: float) -> void:
	if npc_state.is_empty():
		return
	var unlocked := Callable(self, "_is_unlocked")
	var antenna_low: bool = hotspots.has("antenna") and \
			float(hotspots["antenna"].get("value", 100.0)) < 30.0
	for npc_id in npc_state.keys():
		var st: Dictionary = npc_state[npc_id]
		# Tick the timers down.
		if float(st.get("commit_timer", 0.0)) > 0.0:
			st["commit_timer"] = float(st["commit_timer"]) - delta
		if float(st.get("walk_timer", 0.0)) > 0.0:
			st["walk_timer"] = float(st["walk_timer"]) - delta
		# Re-evaluate target every ~0.2s (decide_target internally enforces
		# the soft-commit 2s window).
		var eval_t: float = float(st.get("eval_timer", 0.0)) - delta
		if eval_t <= 0.0:
			st["eval_timer"] = 0.2
			var want: String = NightShiftActors.decide_target(
					npc_id, hotspots, unlocked, player_target_id, npc_state,
					hotspots.has("radio"), radio_completed, blackout, antenna_low, {})
			if want != st.get("target", ""):
				st["target"] = want
				st["commit_timer"] = 2.0
				st["walk_timer"] = 1.5
		# Walk toward target when walk cooldown is over.
		var tgt_id: String = str(st.get("target", ""))
		if tgt_id != "" and hotspots.has(tgt_id) and float(st.get("walk_timer", 0.0)) <= 0.0:
			var hp: Dictionary = hotspots[tgt_id]
			var np: Vector2 = st["pos"]
			var tp: Vector2 = hp["pos"]
			var d := tp - np
			if d.length() > 40.0:
				st["pos"] = np + d.normalized() * float(st.get("speed", 180.0)) * delta
			else:
				# Close enough — softly repair and clear breach countdown.
				var rate: float = 12.0
				if npc_id == "elias":
					rate = 10.0
				var cur: float = float(hp.get("value", 100.0))
				var cap: float = float(hp.get("max_value", 100.0))
				hp["value"] = min(cap, cur + rate * delta)
				if float(hp.get("breach_timer", -1.0)) >= 0.0:
					hp["breach_timer"] = -1.0
				hotspots[tgt_id] = hp
		npc_state[npc_id] = st


func _update_player_movement(delta: float) -> void:
	var prev_pos := player_pos
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1
	var current_speed: float = PLAYER_SPEED + day_effects.get_player_speed_bonus()
	current_speed *= float(difficulty_modifiers.get("player_speed", 1.0))
	if move.length() > 0:
		move = move.normalized()
		player_pos += move * current_speed * delta
		player_pos.x = clamp(player_pos.x, PLAY_RECT.position.x, PLAY_RECT.end.x)
		player_pos.y = clamp(player_pos.y, PLAY_RECT.position.y, PLAY_RECT.end.y)
		# Use WASD to override click-target so the player can ignore queued target.
		player_target_id = ""
	# Also move toward click-target if no WASD
	if move.length() == 0 and player_target_id != "" and hotspots.has(player_target_id):
		var tgt: Vector2 = hotspots[player_target_id]["pos"]
		var to: Vector2 = tgt - player_pos
		if to.length() > HOTSPOT_REACH * 0.5:
			player_pos += to.normalized() * current_speed * delta
			player_pos.x = clamp(player_pos.x, PLAY_RECT.position.x, PLAY_RECT.end.x)
			player_pos.y = clamp(player_pos.y, PLAY_RECT.position.y, PLAY_RECT.end.y)
	# Update facing + walk animation from actual delta
	var delta_v: Vector2 = player_pos - prev_pos
	var was_moving: bool = player_is_moving
	player_is_moving = delta_v.length() > 0.5
	if player_is_moving and not was_moving:
		# Just started moving this frame — fire the tutorial gate.
		if tutorial_overlay:
			tutorial_overlay.notify_player_moved()
	if player_is_moving:
		# Pick dominant axis (skip near-zero dominant case -> keep last facing)
		if abs(delta_v.x) > abs(delta_v.y) * 0.6 or abs(delta_v.y) > abs(delta_v.x) * 0.6:
			if abs(delta_v.x) >= abs(delta_v.y):
				player_facing = "left" if delta_v.x < 0 else "right"
			else:
				player_facing = "up" if delta_v.y < 0 else "down"
		player_walk_timer += delta
		var step: float = 1.0 / PLAYER_WALK_FPS
		while player_walk_timer >= step:
			player_walk_timer -= step
			player_walk_frame = (player_walk_frame + 1) % PLAYER_FRAMES_PER_DIR
	else:
		# Idle: stop on first frame of current facing
		player_walk_frame = 0
		player_walk_timer = 0.0
	_draw_player()


func _update_player_target_reached() -> void:
	player_at_target = false
	if player_target_id == "" or not hotspots.has(player_target_id):
		return
	var tgt: Vector2 = hotspots[player_target_id]["pos"]
	if player_pos.distance_to(tgt) < HOTSPOT_REACH:
		player_at_target = true


func _update_hotspots(delta: float) -> void:
	# Reset per-frame repair-action flag. _draw_player reads it to
	# decide whether to show the hammer sprite.
	player_repair_active = false
	# Player-side repair
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if h["breach_timer"] >= 0.0:
			continue
		if player_target_id == id and player_at_target:
			h["pressure"] = max(0.0, h["pressure"] - 0.8 * delta)
			var repair_bonus: float = day_effects.get_repair_bonus(str(id))
			h["value"] = min(h["max_value"], h["value"] + (REPAIR_RATE + repair_bonus) * delta)
			h["warning"] = false
			h["assault"] = false
			# Count how many seconds the player actually spent repairing this hotspot.
			night_stats["hotfixes"] = float(night_stats.get("hotfixes", 0.0)) + delta
			# Repair-combo: each second spent repairing extends the combo
			# window. Every full second adds a chain step that will pay
			# COMBO_TRUST_BONUS trust when the player moves on. Resets if
			# the player walks away and the timer expires.
			_fx_on_repair_tick(id, delta)
			# Flag the repair-action animation as active for this frame so
			# _draw_player swaps in the hammer sprite. Only barriers get
			# the hammer cycle (radio / medbay have their own flows).
			if PlayerRepairFx.is_repairable_hotspot(str(h.get("kind", ""))):
				player_repair_active = true
				player_repair_timer += delta

	# Background pressure decay (no events) — small slow drain
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if h["breach_timer"] >= 0.0:
			continue
		var kind: String = h["kind"]
		var drain_mod: float = float(difficulty_modifiers.get("drain_rate", 1.0))
		var drain := 0.0
		if kind == "barrier" and h["assault"]:
			drain = 12.0 * delta * day_effects.get_drain_multiplier(str(id), "barrier_assault") * drain_mod
		elif kind == "barrier" and h["warning"]:
			drain = 4.0 * delta * drain_mod
		elif kind == "generator":
			drain = 3.0 * delta * day_effects.get_drain_multiplier(str(id), "generator") * drain_mod
		elif kind == "antenna" and h["active"]:
			drain = 4.0 * delta * day_effects.get_drain_multiplier(str(id), "support") * drain_mod
		elif kind == "support" and h["active"]:
			drain = 2.0 * delta * day_effects.get_drain_multiplier(str(id), "support") * drain_mod
		if drain > 0.0:
			h["value"] = max(0.0, h["value"] - drain)

	# Breach check
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if h["breach_timer"] >= 0.0:
			continue
		if h["value"] <= 0.0:
			h["breach_timer"] = 0.0
			_log("%s 失守！" % _hotspot_label(id))
			_play_sfx("breach_alarm")
			night_stats["breaches"] = int(night_stats.get("breaches", 0)) + 1
			if str(night_stats.get("breaches_first_id", "")) == "":
				night_stats["breaches_first_id"] = id
			# Big breach explosion + heavy shake. The burst_breach helper
			# also drops a ring so the player can SEE the breach event in
			# addition to hearing the alarm.
			Fx.shake_trigger(fx_shake, 12.0, 4.0, 22.0)
			Fx.burst_breach(fx_particles, h["pos"], 1.5)
	# Damage-tier feedback: as the hotspot takes damage and crosses each
	# 25% threshold, spawn a small particle burst so the hit registers
	# visually even between explicit events.
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if h["breach_timer"] >= 0.0:
			continue
		var tier: int = _fx_damage_tier(h["value"], h["max_value"])
		var prev: int = int(fx_last_damage_tier.get(id, 0))
		if tier > prev:
			# Only spawn for barrier / generator / support kinds — radio and
			# medbay don't take damage in the same visual way.
			if h["kind"] in ["barrier", "generator", "support"]:
				_fx_burst_for_kind(id, h, 0.5 + 0.25 * float(tier - prev))
				if tier == 3:
					# Heavy shake when crossing into critical.
					Fx.shake_trigger(fx_shake, 6.0, 5.0, 26.0)
		fx_last_damage_tier[id] = tier
	# Grace countdown
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if h["breach_timer"] >= 0.0:
			continue
		# Repaired back up? Clear the breach and reset damage tracking so a
		# later re-breach re-fires the burst properly.
		if h["breach_timer"] >= 0.0 and h["value"] > h["max_value"] * 0.1:
			h["breach_timer"] = -1.0
			fx_last_damage_tier[id] = 0
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if h["breach_timer"] >= 0.0:
			h["breach_timer"] += delta
			if h["breach_timer"] >= _dx_breach_grace():
				_end_night(false)
				return


func _update_events(delta: float) -> void:
	# First pass: any assault events that are within the telegraph lead time
	# get a warning scheduled. The telegraph's _fx_fire_telegraph actually
	# applies the assault when its timer hits zero, which lines up with the
	# original event.time.
	var i: int = 0
	while i < event_queue.size():
		var ev: Dictionary = event_queue[i]
		var ev_id: String = str(ev.get("id", ""))
		var etype: String = str(ev.get("type", ""))
		var ev_time: float = float(ev.get("time", 0.0))
		if not events_done.has(ev_id) and etype == "assault":
			if ev_time - night_elapsed <= _dx_telegraph_lead() and not bool(ev.get("telegraph_scheduled", false)):
				Fx.telegraph_schedule(
					fx_telegraphs,
					str(ev.get("target", "")),
					max(0.1, ev_time - night_elapsed),
					"assault"
				)
				ev["telegraph_scheduled"] = true
		i += 1

	# Second pass: pop events whose time has actually arrived.
	while not event_queue.is_empty() and event_queue[0]["time"] <= night_elapsed:
		var ev: Dictionary = event_queue.pop_front()
		var ev_id: String = ev["id"]
		if events_done.has(ev_id):
			continue
		events_done[ev_id] = true
		night_stats["events_fired"] = int(night_stats.get("events_fired", 0)) + 1
		# If a telegraph was scheduled for this assault, the telegraph's
		# _fx_fire_telegraph already applied it — don't double-fire.
		if str(ev.get("type", "")) == "assault" and bool(ev.get("telegraph_scheduled", false)):
			continue
		_trigger_event(ev)

	# Third pass: procedural background warnings. Decays per-hotspot
	# cooldowns, then if the scheduler has reached the next-fire time
	# (or the night just started, when _proc_next_warning_at == -1.0)
	# picks a random eligible barrier hotspot and triggers a warning.
	# This is the round-2 pacing fix: night 2-10 used to have 40-90s
	# of dead air between fixed events; now we drip a fresh warning
	# every 6-10s so the player is always within one teleport of
	# needing to run.
	_proc_tick_background_warnings(delta)


func _proc_tick_background_warnings(delta: float) -> void:
	# Decay per-hotspot cooldowns.
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		var cd: float = float(h.get("proc_cooldown", 0.0))
		if cd > 0.0:
			h["proc_cooldown"] = max(0.0, cd - delta)
	# Initialize the scheduler on the first tick of a fresh night so
	# the first procedural warning lands ~8s in (gives the player a
	# brief moment to breathe + orients to the room).
	if _proc_next_warning_at < 0.0:
		_proc_next_warning_at = night_elapsed + 8.0
		return
	if night_elapsed < _proc_next_warning_at:
		return
	# Build the candidate list: barrier hotspots that are healthy,
	# not already in warning/assault/breach, and off cooldown. We allow
	# any health level -- the round-2 pacing fix is specifically to
	# keep the player active from the very first tick of a fresh night,
	# so a fresh full-health door is a valid procedural target. The
	# 25s per-hotspot cooldown handles the "don't spam the same door"
	# concern.
	var candidates: Array = []
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		if str(h.get("kind", "")) != "barrier":
			continue
		if h.get("assault", false) or h.get("warning", false):
			continue
		if h.get("breach_timer", -1.0) >= 0.0:
			continue
		if float(h.get("proc_cooldown", 0.0)) > 0.0:
			continue
		candidates.append(id)
	if candidates.is_empty():
		# No eligible hotspot right now -- try again in 4s.
		_proc_next_warning_at = night_elapsed + 4.0
		return
	# Pick a random candidate and trigger a warning on it.
	var pick_id: String = candidates[randi() % candidates.size()]
	var pick: Dictionary = hotspots[pick_id]
	pick["warning"] = true
	pick["proc_cooldown"] = PROC_HOTSPOT_COOLDOWN
	_log("远处传来声响——%s" % _hotspot_label(pick_id))
	Fx.telegraph_schedule(
		fx_telegraphs,
		pick_id,
		_dx_telegraph_lead(),
		"assault"
	)
	# Schedule the next warning 6-10s out, jittered so the cadence
	# doesn't feel mechanical. Slightly tighter cadence as the night
	# wears on so the late-game pressure keeps ramping.
	# round-2.1: base cadence switches from 6-10s (night 1-4) to
	# 4-7s (night 5+) so the late-game pressure never lets the
	# player stand still. The intra-night ramp on top of the base
	# still subtracts 1.5/2.0s as the night progresses.
	var base_min: float
	var base_max: float
	if night_index >= PROC_WARNING_LATE_NIGHT:
		base_min = PROC_WARNING_LATE_MIN
		base_max = PROC_WARNING_LATE_MAX
	else:
		base_min = PROC_WARNING_INTERVAL_MIN
		base_max = PROC_WARNING_INTERVAL_MAX
	var ramp: float = clamp(night_elapsed / max(1.0, night_duration), 0.0, 1.0)
	var min_gap: float = base_min - 1.5 * ramp
	var max_gap: float = base_max - 2.0 * ramp
	# Floor at 2.0s on the jittered max so we never spawn two
	# warnings back-to-back even at full late-night ramp.
	min_gap = max(2.0, min_gap)
	max_gap = max(min_gap + 0.5, max_gap)
	_proc_next_warning_at = night_elapsed + min_gap + randf() * (max_gap - min_gap)


func _trigger_event(ev: Dictionary) -> void:
	var etype: String = ev["type"]
	var target: String = ev["target"]
	var pressure: float = float(ev["pressure"])

	if target == "player" or target == "":
		# Global story beat (no hotspot attached)
		match etype:
			"radio":
				radio_available = true
				radio_window_left = 30.0 + day_effects.get_radio_window_bonus()
				_play_sfx("radio_static")
				_log("电台呼叫响起。")
			_:
				_log("事件：%s" % ev["id"])
		return

	if not hotspots.has(target):
		return
	var h: Dictionary = hotspots[target]
	match etype:
		"warning":
			h["warning"] = true
			_play_sfx("warning_beep")
			_log("%s 出现警告。" % _hotspot_label(target))
		"assault":
			h["assault"] = true
			h["warning"] = false
			h["pressure"] = min(1.0, h["pressure"] + pressure * 0.1)
			_play_sfx("breath")
			_log("%s 被冲击。" % _hotspot_label(target))
		"support":
			h["active"] = true
			h["value"] = max(0.0, h["value"] - pressure * 5.0)
			_play_sfx("warning_beep")
			_log("%s 出现干扰。" % _hotspot_label(target))
		"radio":
			h["active"] = true
			radio_available = true
			radio_window_left = 30.0 + day_effects.get_radio_window_bonus()
			_play_sfx("radio_static")
			_log("电台呼叫：%s" % _hotspot_label(target))


func _update_visual_feedback() -> void:
	# Per-hotspot: art texture + integrity bar + circle state overlays
	for child in hotspot_layer.get_children():
		if not child.has_meta("hotspot_id"):
			continue
		var id: String = child.get_meta("hotspot_id")
		if not hotspots.has(id):
			continue
		var h: Dictionary = hotspots[id]

		# Art texture — pick the illustration that matches the current
		# state via NightShiftArt.hotspot_texture_key (intact / warning /
		# assault / braced / broken for barriers; idle / low_power /
		# blackout / repaired for generator; etc).
		var art_node: TextureRect = child.get_node_or_null("Art") as TextureRect
		if art_node != null:
			var art_bucket: Dictionary = art.get("hotspots", {}) as Dictionary
			var ctx: Dictionary = {
				"blackout": blackout,
				"radio_completed": radio_completed,
				"radio_missed": radio_missed,
				"radio_available": radio_available,
				"player_target_id": player_target_id,
				"player_at_target": player_at_target,
			}
			var tex_key: String = NightShiftArt.hotspot_texture_key(id, h, ctx)
			var new_tex: Texture2D = art_bucket.get(tex_key, null) if tex_key != "" else null
			if new_tex != null and art_node.texture != new_tex:
				art_node.texture = new_tex

		# Integrity bar (color + width)
		var bar: ColorRect = child.get_node_or_null("Bar") as ColorRect
		var pct: float = h["value"] / h["max_value"]
		if bar:
			bar.size.x = 104.0 * pct
			if pct > 0.6:
				bar.color = Color(0.4, 0.9, 0.4)
			elif pct > 0.3:
				bar.color = Color(0.95, 0.8, 0.2)
			else:
				bar.color = Color(0.95, 0.3, 0.25)

		# Circle state — call set_state on the HotspotDot
		var dot: HotspotDot = child.get_node_or_null("Dot") as HotspotDot
		if dot:
			var pulse: float = 0.0
			if h["assault"]:
				pulse = 0.7
			elif h["warning"]:
				pulse = 0.35
			elif h["active"] and h["kind"] in ["generator", "antenna", "support", "radio"]:
				pulse = 0.2
			var is_target: bool = (player_target_id == id)
			var breached: bool = h["breach_timer"] >= 0.0
			var is_locked: bool = not id in unlocked_hotspots
			dot.set_state(pct, breached, is_target, is_locked, h["active"], h["warning"], pulse)

	# Blackout / danger flash overlay
	var danger := 0.0
	for id in hotspots:
		if hotspots[id]["assault"]:
			danger = max(danger, 0.4)
	if danger > 0.0:
		flash_rect.visible = true
		flash_rect.color = Color(0.6, 0.15, 0.1, danger)
	else:
		flash_rect.visible = false


func _draw_player() -> void:
	# Unified player visual across idle / walking / repair:
	#   - Idle / walking use the walk-frame art (128x160 baseline) so
	#     the player footprint is stable across the day. Previously idle
	#     switched to actor_player_*.png (768x1024, content bbox 52%x91%)
	#     which displayed at ~116 px tall vs walk's ~97 px tall -- a
	#     visible size jump on every transition.
	#   - Repair uses player_repair_token (3 art frames, scale 0.12, so
	#     the 896x1200 source art reads ~144px tall -- ~the same height
	#     as walk). M13.1 swaps the v0.5 drop overlay (alpha=0 pixels
	#     carried RGB 255/30/82 -> colored halo, polish spec §4.5) for
	#     real matrix-MCP-generated art with png_to_rgba.py v3 alpha
	#     restoration. Frame index follows PlayerRepairFx.repair_frame_for
	#     (start/mid/end on a 0.36s cycle, ~3 swings per repair bar).
	#   - Player silhouette is NEVER tilted or bobbed during repair --
	#     the swinging reads on the art-frame swap itself, not on a
	#     procedural hammer. Player itself stays locked to player_pos
	#     with rotation=0, so idle / walking / repair share the same
	#     footprint.
	var frames: Array = walk_frames.get(player_facing, [])
	var tex: Texture2D = null
	if not frames.is_empty():
		if player_is_moving:
			var fi: int = clamp(player_walk_frame, 0, frames.size() - 1)
			tex = frames[fi] if frames[fi] != null else frames[0]
		else:
			tex = frames[0]
	if tex != null:
		player_token.texture = tex
		player_token.scale = Vector2(1.0, 1.0)
		player_token.flip_h = false
		player_token.flip_v = false
		player_token.position = player_pos
		player_token.rotation = 0.0
		player_token.modulate.a = 1.0
	else:
		# Fallback: hide token (no colored circle in v0.5)
		player_token.modulate.a = 0.0
		player_token.position = player_pos
		player_token.rotation = 0.0

	# Drive the procedural hammer sprite. Sits at the player's hand
	# offset, rotates ±0.5 rad on PlayerRepairFx REPAIR_CYCLE_SEC
	# (~0.36s = ~3 swings per repair bar). Hidden when not repairing so
	# the player isn't dragging a hammer around during walk / idle.
	if hammer_sprite != null:
		if player_repair_active:
			hammer_sprite.visible = true
			# Hand offset relative to the player token. Player sprite
			# is 128x160; hand sits at top-right so the hammer is
			# clearly visible against the player silhouette.
			hammer_sprite.position = player_pos + Vector2(22.0, -54.0)
			var phase: float = fmod(player_repair_timer, PlayerRepairFx.REPAIR_CYCLE_SEC) / PlayerRepairFx.REPAIR_CYCLE_SEC
			# Two-segment swing: phase 0.0..0.45 -> swing DOWN (hammer
			# arcs from -PI/3 back to -PI/6+1.8, max forward thrust near
			# phase=0.5); phase 0.45..1.0 -> swing BACK (returns to
			# -PI/3 ready position). The swing amplitude is large (1.8
			# rad = ~103deg) so the hammer motion reads as a committed,
			# energetic hammer-strike even at 1280x720. round-2 visual
			# fix per user feedback: "哪怕边上加上锤子挥动的动画呢".
			# round-2.1 tweak: over-arm thrust bumped 1.4 -> 1.8 rad
			# (~23deg more forward) so the strike carries more weight
			# and the recovery arc is visibly longer / less jerky.
			var swing: float
			if phase < 0.45:
				# Forward swing: -PI/3 (60deg up) -> -PI/6 + 1.8 (over-arm thrust)
				swing = -PI / 3.0 + (phase / 0.45) * (PI / 6.0 + 1.8)
			else:
				# Recovery swing: back to -PI/3 over the remaining 0.55 phase
				var recover_t: float = (phase - 0.45) / 0.55
				swing = (-PI / 6.0 + 1.8) - recover_t * (PI / 3.0 + PI / 6.0 + 1.8)
			hammer_sprite.rotation = swing
			# M13 art-based hammer is a Sprite2D -- it redraws automatically
			# when rotation changes (no queue_redraw needed). The previous
			# procedural Node2D + _draw version needed the explicit
			# queue_redraw() to bypass the draw-cache.
		else:
			hammer_sprite.visible = false
			hammer_sprite.rotation = 0.0
			# Reset timer so next repair starts cleanly from FRAME_START.
			player_repair_timer = 0.0

	# Drive the repair-action sprite. The 3 art frames (start/mid/end)
	# replace the v0.5 drop overlay (alpha audit: start/mid/end carried
	# RGB 255/30/82 in alpha=0 pixels, layered as a colored halo around
	# the player -- polish spec §4.5). M13.1 ships real art frames
	# generated via matrix MCP, with alpha restored by png_to_rgba.py v3.
	# Token is mutually exclusive with the procedural hammer_sprite so we
	# don't double-draw the hammer (art frame already includes it).
	if player_repair_token != null:
		if player_repair_active:
			var frame_idx: int = PlayerRepairFx.repair_frame_for(player_repair_timer)
			player_repair_token.texture = player_repair_textures.get(frame_idx, null)
			player_repair_token.position = player_pos + Vector2(0.0, 8.0)
			player_repair_token.visible = true
			player_repair_token.modulate.a = 1.0
			# Token includes the hammer drawn into the art; suppress the
			# procedural hammer_sprite so it doesn't double up.
			if hammer_sprite != null:
				hammer_sprite.visible = false
		else:
			player_repair_token.visible = false
			player_repair_token.modulate.a = 0.0


# ============================================================================
# PHASE: night_report
# ============================================================================

func _end_night(success: bool) -> void:
	phase = "night_report"
	survived = success
	_play_sfx("unlock" if success else "fail")
	# One-shot sting: success/failure track plays once (not looped), then the
	# report-screen loop bed (`music_report`) takes over once the sting ends.
	# _pending_report_music is checked in _process and triggers the transition.
	if success:
		_play_music("success", false)
	else:
		_play_music("failure", false)
	_pending_report_music = true
	# Dawn fade: only on success — a failed night shouldn't get the warm
	# sunrise, the player needs to feel the failure state.
	if success:
		fx_dawn_target = 1.0

	# Apply night success/failure unlocks
	var night_def: Dictionary = data.get_night(night_index)
	if success:
		resources = data.apply_resource_delta(resources, {"trust": 1})
		# Apply success_unlocks (e.g. nora / right_window / radio / elias / antenna)
		for unlock in night_def.get("success_unlocks", []):
			var u: String = str(unlock)
			if u in ["nora", "elias"]:
				if not bool(allies.get(u, false)):
					allies[u] = true
					if u == "nora" and not _ach_recruit_nora:
						_ach_recruit_nora = true
						_unlock_ach("recruit_nora")
					elif u == "elias" and not _ach_recruit_elias:
						_ach_recruit_elias = true
						_unlock_ach("elias_recruit")
					if bool(allies.get("nora", false)) and bool(allies.get("elias", false)) and bool(allies.get("victor", false)):
						if not _ach_all_three:
							_ach_all_three = true
							_unlock_ach("all_three_allies")
					_log("%s 加入" % ("Nora" if u == "nora" else "Elias"))
					# Initialise runtime state for the new NPC. Default position
					# mirrors spec §4.5 — Nora on the right flank, Elias on the left.
					if u == "nora" and not npc_state.has("nora"):
						npc_state["nora"] = {
							"pos": Vector2(800.0, 360.0),
							"target": "",
							"commit_timer": 0.0,
							"walk_timer": 0.0,
							"eval_timer": 0.2,
							"speed": 180.0,
						}
					elif u == "elias" and not npc_state.has("elias"):
						npc_state["elias"] = {
							"pos": Vector2(480.0, 360.0),
							"target": "",
							"commit_timer": 0.0,
							"walk_timer": 0.0,
							"eval_timer": 0.2,
							"speed": 180.0,
						}
			elif u in ["right_window", "back_door", "radio", "antenna", "medbay", "storage"]:
				if not unlocked_hotspots.has(u):
					unlocked_hotspots.append(u)
					_log("解锁：%s" % _hotspot_label(u))
		# Check all-three-allies AFTER the loop so a single night that unlocks
		# both nora + elias (rare but possible) still fires the achievement.
		if bool(allies.get("nora", false)) and bool(allies.get("elias", false)) and bool(allies.get("victor", false)):
			if not _ach_all_three:
				_ach_all_three = true
				_unlock_ach("all_three_allies")
		# Achievement triggers tied to night-end (success only).
		if night_index == 0 and not _ach_first_night:
			_ach_first_night = true
			_unlock_ach("first_night")
		total_breaches += int(night_stats.get("breaches", 0))
		if night_index + 1 >= night_count:
			if not _ach_clear_all:
				_ach_clear_all = true
				_unlock_ach("clear_all_nights")
			if total_breaches == 0 and not _ach_no_breach:
				_ach_no_breach = true
				_unlock_ach("no_breach")

	# Pick report text from level data — uses the localized _en variant when
	# the locale is en, otherwise the Chinese original.
	var level: Dictionary = NightShiftLevels.LEVELS[night_index]
	var report_key: String = ("success_report_en" if success else "failure_report_en") if I18n.locale == "en" else ("success_report" if success else "failure_report")
	var report: String = str(level.get(report_key, ""))
	if report == "":
		report = "第 %d 夜 %s。" % [night_index + 1, ("成功" if success else "失败")]

	# Wipe enemies
	enemy_tokens.clear()
	_redraw_enemy_visuals()

	# Tutorial gate: if the player survived Night 0, the "Survive" step
	# auto-advances. The skip / advance already hide the overlay; this also
	# writes tutorial_done to the save via on_tutorial_finished.
	if success and tutorial_overlay:
		tutorial_overlay.notify_night_succeeded()

	# Persist (advance night_index to "next to play" so the save reflects
	# progress across the night boundary).
	if success:
		night_index += 1
		_save_progress()
		night_index -= 1
	else:
		# Failure: keep current index so player retries the same night.
		_save_progress()

	_show_night_report(success, report)


func _show_night_report(success: bool, body: String) -> void:
	last_report_success = success
	last_report_body = body
	_clear_card_layer()
	card_layer.visible = true
	# Night report uses the room background but the hotspot buttons are
	# context for the night map only — keep them hidden so the stats panel
	# is the focus.
	hotspot_layer.visible = false
	# Hide the player + repair token too — the report screen has its own
	# character strip and the in-room sprite would visually clash.
	player_token.visible = false
	player_repair_token.visible = false
	# Polish M10.5 fix: the radio contact progress panel belongs on the
	# night map only. After a night ends the panel sometimes still had
	# stale channel buttons visible; force-hide here so the report screen
	# reads as a single coherent surface.
	_hide_radio_panel()
	_set_resource_bar_visible(false)
	prompt_label.visible = true
	log_label.visible = true
	# Tutorial overlay belongs on the night map; force the whole
	# CanvasLayer invisible on the report screen so the stats panel
	# reads cleanly (some internal tutorial state can leave the skip
	# button visible even after hide_overlay()).
	if tutorial_overlay:
		tutorial_overlay.visible = false
	if success and art.get("report"):
		bg.texture = art["report"]
	elif not success and art.get("final_bad"):
		bg.texture = art["final_bad"]
	# Bug fix: was `_play_music("final" if success else "final")` — both
	# branches played the chapter-complete track on every night end. Now the
	# sting (success/failure) plays one-shot, and the looping `music_report`
	# bed takes over once the sting ends (see _process/_pending_report_music).
	_play_music("success" if success else "failure", false)
	_pending_report_music = true

	var level: Dictionary = NightShiftLevels.LEVELS[night_index]
	var night_def: Dictionary = data.get_night(night_index)
	var night_title: String = str(night_def.get("title", ""))
	var learning_goal: String = str(night_def.get("learning_goal", ""))

	# Status bar (top) — title + result
	status_label.text = "第 %d 夜 · %s%s" % [night_index + 1, night_title, (" · 成功" if success else " · 失败")]
	prompt_label.text = learning_goal

	# Polish M10.5: 6-character ally strip across the top of the report
	# so the player can see at a glance who's still in the shelter, who
	# hasn't joined yet, and who joined/left this night. Sits below the
	# status bar.
	_build_ally_strip(Vector2(20, 36), 7, success)

	# Body text in log area; append the hotspot status summary + per-night stats.
	var summary_lines: Array = []
	summary_lines.append("--- 战况 ---")
	for id in hotspots:
		var h: Dictionary = hotspots[id]
		var pct: float = h["value"] / h["max_value"]
		var status: String
		if h["breach_timer"] >= 0.0:
			status = "失守"
		elif pct >= 0.7:
			status = "完好"
		elif pct >= 0.3:
			status = "损伤"
		else:
			status = "告急"
		summary_lines.append("  %s  %3d%%  %s" % [_hotspot_label(id), int(pct * 100), status])

	# Stats block (always shown — useful for both success and failure reviews)
	summary_lines.append("--- 数据 ---")
	var elapsed_str := "%ds" % int(night_elapsed)
	summary_lines.append("  坚持时间：%s / %ds" % [elapsed_str, int(night_duration)])
	summary_lines.append("  修复时长：%.1f 秒" % float(night_stats.get("hotfixes", 0.0)))
	summary_lines.append("  失守次数：%d" % int(night_stats.get("breaches", 0)))
	var first_breach: String = str(night_stats.get("breaches_first_id", ""))
	if first_breach != "":
		summary_lines.append("  首失：%s" % _hotspot_label(first_breach))
	summary_lines.append("  事件触发：%d" % int(night_stats.get("events_fired", 0)))
	summary_lines.append("  敌人撤离：%d" % int(night_stats.get("enemies_despawned", 0)))
	summary_lines.append("  电台接通：%d" % int(night_stats.get("radio_contacts", 0)))
	# Resources at end
	summary_lines.append("--- 资源 ---")
	for k in resources:
		summary_lines.append("  %s %d" % [_resource_name(str(k)), int(resources[k])])

	if success and night_def.get("success_unlocks", []).size() > 0:
		summary_lines.append("--- 解锁 ---")
		for u in night_def["success_unlocks"]:
			var label: String = str(u)
			if label in ["nora", "elias"]:
				summary_lines.append("  同伴：%s" % ("Nora" if label == "nora" else "Elias"))
			elif HOTSPOT_POSITIONS.has(label):
				summary_lines.append("  位置：%s" % _hotspot_label(label))
			else:
				summary_lines.append("  %s" % label)
	summary_lines.append("")
	summary_lines.append(body)
	log_label.text = "\n".join(summary_lines)

	var label_text := "进入第 %d 夜" % (night_index + 2) if success else "重打第 %d 夜" % (night_index + 1)
	var btn_label := label_text
	if success and night_index + 1 >= night_count:
		btn_label = "查看结局"
	elif not success:
		btn_label = "重打第 %d 夜" % (night_index + 1)
	var btn := _make_button(
		btn_label,
		Vector2(SCREEN_SIZE.x * 0.5 - 160, SCREEN_SIZE.y - 80),
		Vector2(320, 56),
		_on_report_continue.bind(success)
	)
	card_layer.add_child(btn)


func _on_report_continue(success: bool) -> void:
	if success:
		night_index += 1
		if night_index >= night_count:
			_show_final()
			return
		_show_day()
	else:
		# Retry the same night
		_show_night()


# ============================================================================
# PHASE: final
# ============================================================================

func _show_final() -> void:
	phase = "final"
	_clear_card_layer()
	card_layer.visible = true
	# Same as night report — final screen is its own scene, hide the map
	# hotspot buttons so the dawn illustration reads cleanly.
	hotspot_layer.visible = false
	# Final screen has its own character overlay; hide the in-room sprite.
	player_token.visible = false
	player_repair_token.visible = false
	_hide_radio_panel()
	_set_resource_bar_visible(false)
	prompt_label.visible = true
	log_label.visible = true
	# Hide tutorial overlay on the final screen too.
	if tutorial_overlay:
		tutorial_overlay.visible = false
	if art.get("final_good"):
		bg.texture = art["final_good"]
	_play_music("final")
	status_label.text = "第一章通关"
	prompt_label.text = "旧体育馆成为城市里第一座被点亮的坐标。"

	# Polish M10.5: 6-character ally strip across the top so the final
	# screen acknowledges every survivor (and the ones who didn't make it
	# by greying them out — Tom's silhouette at night 8 reads as a quiet
	# elegy without needing extra UI).
	_build_ally_strip(Vector2(20, 36), 7, true)

	# Player silhouette on the right (matches the cover screen mirror).
	var final_tex: Texture2D = art.get("player_wide", null)
	if final_tex != null:
		var sprite := Sprite2D.new()
		sprite.texture = final_tex
		var h: float = SCREEN_SIZE.y * 0.62
		var w: float = h * 0.75
		sprite.position = Vector2(SCREEN_SIZE.x - w * 0.55, SCREEN_SIZE.y - h * 0.55)
		sprite.scale = Vector2(w / final_tex.get_width(), h / final_tex.get_height())
		sprite.modulate = Color(1, 1, 1, 0.65)
		sprite.z_index = -1
		card_layer.add_child(sprite)

	# Bump the NG+ counter and persist it before showing buttons.
	ng_plus_count += 1
	if current_slot > 0:
		var doc: Dictionary = NightShiftSave.read(current_slot)
		doc["ng_plus_count"] = ng_plus_count
		NightShiftSave.write(doc, current_slot)
	log_label.text = "体育馆亮起来了。Victor 的信号在城市上空转了一圈。\n更多的坐标等待回应，第二章的地图正在打开。\n\n通关次数: %d（再来一次解锁 New Game+ 加成）" % ng_plus_count

	var btn := _make_button(
		"重新开始",
		Vector2(SCREEN_SIZE.x * 0.5 - 140, SCREEN_SIZE.y - 160),
		Vector2(280, 64),
		_on_restart_pressed
	)
	card_layer.add_child(btn)


func _on_restart_pressed() -> void:
	# Going back to the slot picker, not directly to a new run — players
	# who finished the chapter usually want either to start NG+ on the same
	# slot (going to difficulty picker) or to switch slots.
	_show_slot_picker()


# ============================================================================
# PHASE: shared helpers
# ============================================================================

func _make_button(text: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 2)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.18, 0.22, 0.28, 0.92)
	s.border_color = Color(0.65, 0.55, 0.35)
	for k in ["left", "right", "top", "bottom"]:
		s.set("border_width_" + k, 2)
	for k in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		s.set("corner_radius_" + k, 6)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate()
	sh.bg_color = Color(0.28, 0.34, 0.42, 0.95)
	btn.add_theme_stylebox_override("hover", sh)
	var sp := s.duplicate()
	sp.bg_color = Color(0.4, 0.48, 0.58, 0.95)
	btn.add_theme_stylebox_override("pressed", sp)
	btn.pressed.connect(callback)
	if _dx_debug_probe_phase:
		print("DEBUG _make_button created for: ", text, " callback: ", callback)
	return btn


func _log(msg: String) -> void:
	logs.append(msg)
	if logs.size() > 6:
		logs.pop_front()
	log_label.text = "\n".join(logs)


# Build the resource-chip bar shown in the night HUD. Replaces the old
# text-only "木板 4 · 零件 4 ..." string with scannable icon + value chips.
# Hidden in non-night phases; _update_status_label flips it visible
# while the player is in the night map.
func _build_resource_bar() -> void:
	_resource_bar = HBoxContainer.new()
	_resource_bar.position = Vector2(24, 56)
	_resource_bar.add_theme_constant_override("separation", 6)
	_resource_bar.visible = false
	hud_layer.add_child(_resource_bar)

	# Chip order matches the canonical narrative: building blocks (plank /
	# parts) first, consumables (battery / medicine) next, then social
	# pressure (threat / trust). Each entry is:
	#   key      : resource key the value is read from
	#   icon_tex : Texture2D — icon_door_reinforce for plank, etc.
	#   name     : fallback letter glyph (used only if icon_tex is null)
	#   color    : chip background tint
	var chips: Array = [
		{"key": "plank",     "icon_tex": art.get("icons", {}).get("door_reinforce", null),  "name": "P", "color": Color(0.78, 0.55, 0.30)},
		{"key": "parts",     "icon_tex": art.get("icons", {}).get("workbench",     null),  "name": "K", "color": Color(0.65, 0.65, 0.70)},
		{"key": "battery",   "icon_tex": art.get("icons", {}).get("battery_buffer", null),  "name": "B", "color": Color(0.45, 0.78, 0.95)},
		{"key": "medicine",  "icon_tex": art.get("icons", {}).get("medbay",        null),  "name": "M", "color": Color(0.65, 0.95, 0.65)},
		{"key": "threat",    "icon_tex": art.get("alerts",  {}).get("warning",       null),  "name": "!", "color": Color(0.95, 0.55, 0.40)},
		{"key": "trust",     "icon_tex": art.get("alerts",  {}).get("braced",        null),  "name": "T", "color": Color(0.95, 0.85, 0.45)},
	]
	for c in chips:
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.55)
		style.border_color = (c.get("color", Color.WHITE) as Color)
		style.border_color.a = 0.85
		for k in ["left", "right", "top", "bottom"]:
			style.set("border_width_" + k, 1)
		for k in ["top_left", "top_right", "bottom_left", "bottom_right"]:
			style.set("corner_radius_" + k, 4)
		style.content_margin_left = 4
		style.content_margin_right = 6
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		chip.add_theme_stylebox_override("panel", style)
		_resource_bar.add_child(chip)

		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		chip.add_child(h)

		var icon := TextureRect.new()
		icon.size = Vector2(20, 20)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if c.get("icon_tex", null) != null:
			icon.texture = c["icon_tex"]
		else:
			# Fallback glyph: single letter on a tinted background.
			var fallback := Label.new()
			fallback.text = str(c.get("name", "?"))
			fallback.add_theme_font_size_override("font_size", 14)
			fallback.add_theme_color_override("font_color", c.get("color", Color.WHITE))
			fallback.size = Vector2(20, 20)
			fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			chip.add_child(fallback)
		h.add_child(icon)

		var val_lbl := Label.new()
		val_lbl.text = "0"
		val_lbl.add_theme_font_size_override("font_size", 15)
		val_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.86))
		val_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		val_lbl.add_theme_constant_override("outline_size", 2)
		h.add_child(val_lbl)
		_resource_chip_labels[str(c.get("key", ""))] = val_lbl


# Refresh chip values from the current resources dict. Called from
# _update_status_label during the night phase.
func _update_resource_bar() -> void:
	if _resource_bar == null:
		return
	for k in _resource_chip_labels:
		var lbl: Label = _resource_chip_labels[k]
		lbl.text = str(int(resources.get(k, 0)))
		# Tint threat chip red when the value is climbing — visual cue
		# to the player that "exposure" is the only resource that goes
		# the wrong way without being obviously broken.
		if k == "threat" and int(resources.get("threat", 0)) >= 5:
			lbl.add_theme_color_override("font_color", Color(1.0, 0.45, 0.40))


# Toggle the night-only resource chip bar. Hides the prompt_label row
# when on (so we don't double-print) and restores it when off. Every
# phase change calls this once.
func _set_resource_bar_visible(on: bool) -> void:
	if _resource_bar:
		_resource_bar.visible = on
	if prompt_label:
		prompt_label.visible = not on
		if not on:
			prompt_label.text = ""


func _unlock_ach(id: String) -> void:
	# Thin facade so all 8 trigger sites have one place to call. Steamworks
	# is registered as an autoload (project.godot:21); resolve via the
	# scene-tree path so headless --script runs without an autoload also work.
	var node: Node = get_node_or_null("/root/Steamworks")
	if node == null:
		node = Engine.get_singleton("Steamworks") if Engine.has_singleton("Steamworks") else null
	if node and node.has_method("unlock_achievement"):
		node.unlock_achievement(id)


func _update_status_label() -> void:
	var remaining: float = max(0.0, night_duration - night_elapsed)
	var mins := int(floor(remaining / 60.0))
	var secs := int(floor(remaining - mins * 60))
	status_label.text = "第 %d 夜  %02d:%02d" % [night_index + 1, mins, secs]

	# Polish M10.5: use the icon-chip resource bar instead of the old
	# "木板 4 · 零件 4 ..." text string. Hide the prompt_label row so
	# we don't double-print. The radio-active hint is appended to the
	# status_label so the player still sees "电台呼叫中".
	if _resource_bar:
		_resource_bar.visible = true
		_update_resource_bar()
	prompt_label.visible = false
	prompt_label.text = ""
	if _is_radio_active():
		status_label.text += "  ·  电台呼叫中"
