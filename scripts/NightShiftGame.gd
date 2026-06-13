extends Node2D

const MAP_SIZE := Vector2(1280, 720)
const PLAY_RECT := Rect2(Vector2(24, 24), Vector2(928, 672))
const STADIUM_BACKDROP_RECT := Rect2(Vector2(24, 70), Vector2(960, 540))
const ROOM_RECT := Rect2(Vector2(86, 82), Vector2(786, 548))
const HUD_POS := Vector2(1010, 18)
const HUD_SIZE := Vector2(250, 288)

const PLAYER_SPEED := 270.0
const NORA_SPEED := 220.0
const ELIAS_SPEED := 220.0
const PLAYER_WORK_RATE := 28.0
const NORA_WORK_RATE := 16.0
const ELIAS_WORK_RATE := 15.0
const PLAYER_HOME := Vector2(500, 390)
const NORA_HOME := Vector2(870, 494)
const ELIAS_HOME := Vector2(748, 392)
const ACTOR_ARRIVE_DISTANCE := 6.0
const HELPER_COMMIT_DURATION := 3.4
const HELPER_TARGET_COOLDOWN := 4.5
const BREACH_GRACE := 10.0
const TEMP_SEAL_DURATION := 12.0
const PLANK_COOLDOWN := 25.0
const AUDIO_SAMPLE_RATE := 22050
const USE_FORMAL_BACKDROPS := true
const USE_PROCEDURAL_ACTOR_RIGS := true
const RHYTHM_TICK_INTERVAL := 5.0

const BACKGROUND_PATH := "res://assets/new/named/radio_room_topdown.png"
const FINAL_ASSET_PATH := "res://assets/final/night_shift/"
const AUDIO_ASSET_PATH := FINAL_ASSET_PATH + "audio/"
const IMPORTED_ASSET_PATH := "res://assets/imported/b33/"
const PLAYER_PORTRAIT_PATH := FINAL_ASSET_PATH + "character_player.png"
const NORA_PORTRAIT_PATH := FINAL_ASSET_PATH + "character_nora.png"
const ELIAS_PORTRAIT_PATH := FINAL_ASSET_PATH + "character_elias.png"
const PLAYER_ACTOR_FRONT_PATH := FINAL_ASSET_PATH + "actor_player_front.png"
const PLAYER_ACTOR_SIDE_PATH := FINAL_ASSET_PATH + "actor_player_side.png"
const PLAYER_ACTOR_BACK_PATH := FINAL_ASSET_PATH + "actor_player_back.png"
const PLAYER_WALK_FRAMES_PATH := FINAL_ASSET_PATH + "player_walk/player_walk_frames.res"
const NORA_WALK_FRAMES_PATH := FINAL_ASSET_PATH + "nora_walk/nora_walk_frames.res"
const ELIAS_WALK_FRAMES_PATH := FINAL_ASSET_PATH + "elias_walk/elias_walk_frames.res"
const PLAYER_WALK_FOOT_OFFSET := Vector2(-64, -150)
const PLAYER_WALK_SCALE := 0.67
const BATTERY_ICON_PATH := IMPORTED_ASSET_PATH + "power_station.png"
const RADIO_ICON_PATH := IMPORTED_ASSET_PATH + "radio_part_v2.png"
const PLANK_ICON_PATH := IMPORTED_ASSET_PATH + "blockade_prop.png"
const FRONT_THREAT_PATH := FINAL_ASSET_PATH + "threat_front_door.png"
const BACK_THREAT_PATH := FINAL_ASSET_PATH + "threat_back_door.png"
const LEFT_THREAT_PATH := FINAL_ASSET_PATH + "threat_left_window.png"
const RIGHT_THREAT_PATH := FINAL_ASSET_PATH + "threat_right_window.png"
const ZOMBIE_SINGLE_PATH := FINAL_ASSET_PATH + "zombie_shadow_single.png"
const ZOMBIE_PAIR_PATH := FINAL_ASSET_PATH + "zombie_shadow_pair.png"
const ZOMBIE_CROWD_PATH := FINAL_ASSET_PATH + "zombie_shadow_crowd.png"
const ZOMBIE_HANDS_PATH := FINAL_ASSET_PATH + "zombie_hands_reach.png"
const NightShiftLevels := preload("res://scripts/NightShiftLevels.gd")
const NightShiftArt := preload("res://scripts/NightShiftArt.gd")
const NightShiftActors := preload("res://scripts/NightShiftActors.gd")

var phase := "day"
var current_level_index := 0
var night_elapsed := 0.0
var blackout := false
var radio_available := false
var radio_missed := false
var radio_completed := false
var radio_call_started_at := -1.0
var radio_contacts_done := 0
var game_over := false
var outcome := ""
var result_text := ""
var last_night_success := false
var first_door_hint_done := false
var plank_cooldown := 0.0
var next_director_time := 0.0
var director_event_count := 0
var last_director_target := ""
var next_rhythm_time := RHYTHM_TICK_INTERVAL
var rhythm_tick_count := 0
var rhythm_pressure_count := 0
var last_rhythm_target := ""
var last_rhythm_kind := ""

var player_pos := PLAYER_HOME
var player_target_pos := PLAYER_HOME
var player_target_id := ""
var player_route: Array[Vector2] = []
var nora_pos := NORA_HOME
var nora_target_pos := NORA_HOME
var nora_target_id := ""
var nora_route: Array[Vector2] = []
var nora_commit_time := 0.0
var nora_target_cooldowns := {}
var elias_pos := ELIAS_HOME
var elias_target_pos := ELIAS_HOME
var elias_target_id := ""
var elias_route: Array[Vector2] = []
var elias_commit_time := 0.0
var elias_target_cooldowns := {}

var allies := {
	"nora": false,
	"elias": false
}
var upgrades := {}
var events_done := {}
var hotspots := {}
var logs: Array[String] = []
var night_rng := RandomNumberGenerator.new()
var debug_seed_override := -1
var night_seed := 0
var night_schedule := {}
var night_time_scale := 1.0

var background_texture: Texture2D
var day_background_texture: Texture2D
var breached_background_texture: Texture2D
var planning_table_texture: Texture2D
var report_table_texture: Texture2D
var ending_success_texture: Texture2D
var ending_failure_texture: Texture2D
var hud_panel_texture: Texture2D
var upgrade_card_texture: Texture2D
var blackout_overlay_texture: Texture2D
var danger_overlay_texture: Texture2D
var radio_waveform_texture: Texture2D
var player_texture: Texture2D
var nora_texture: Texture2D
var elias_texture: Texture2D
var player_actor_front_texture: Texture2D
var player_actor_side_texture: Texture2D
var player_actor_back_texture: Texture2D
var player_walk_frames: SpriteFrames
var nora_walk_frames: SpriteFrames
var elias_walk_frames: SpriteFrames
var player_actor_sprite: AnimatedSprite2D
var nora_actor_sprite: AnimatedSprite2D
var elias_actor_sprite: AnimatedSprite2D
var player_walk_animation: StringName = &"walk_down"
var nora_walk_animation: StringName = &"walk_down"
var elias_walk_animation: StringName = &"walk_down"
var formal_night_backdrop_valid := false
var battery_icon: Texture2D
var radio_icon: Texture2D
var plank_icon: Texture2D
var front_threat_texture: Texture2D
var back_threat_texture: Texture2D
var left_threat_texture: Texture2D
var right_threat_texture: Texture2D
var zombie_single_texture: Texture2D
var zombie_pair_texture: Texture2D
var zombie_crowd_texture: Texture2D
var zombie_hands_texture: Texture2D
var hotspot_state_textures := {}
var upgrade_icon_textures := {}
var upgrade_event_textures := {}
var upgrade_event_thumb_textures := {}
var alert_icon_textures := {}
var audio_enabled := false
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var procedural_ambience_stream: AudioStream
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams := {}
var sfx_volume_db := {}
var current_music_key := ""
var current_ambience_key := ""

var particles: Array[Dictionary] = []
var last_particle_emit_time := 0.0
const PARTICLE_EMIT_INTERVAL := 0.15
const MAX_PARTICLES := 60

var transition_overlay: ColorRect
var crisis_bar: ColorRect
var crisis_bar_bg: ColorRect
var log_highlight_index := 0
var first_hint_tween: Tween
var cover_tween: Tween
var pause_overlay: PanelContainer
var pause_menu_button_box: HBoxContainer
var game_paused := false
var achievements_unlocked := {}
var achievement_notification: PanelContainer

var opening_shown := false
var opening_index := 0
var opening_panel: PanelContainer
var opening_timer := 0.0
var in_opening := false
var prenight_label: Label
var prenight_phase := 0.0
var prenight_active := false
var radio_signal_text := ""
var radio_signal_char_index := 0
var radio_signal_active := false
var radio_signal_timer := 0.0
var result_page_2_text := ""
var result_on_page_2 := false
var result_original_text := ""

const OPENING_SLIDES := [
	{"text": "停电第一天。", "sub": "备用发电机还能撑住体育馆的灯。旧的广播系统播过最后一次通知：请待在家中，保持冷静。"},
	{"text": "第三天。", "sub": "水停了。看台下面开始有人发烧。你把体育馆的铁门从里面闩上。"},
	{"text": "第五天。", "sub": "一个叫 Nora 的女人从器材通道翻进来。袖子被铁丝割开，没说自己从哪来。"},
	{"text": "第六天。", "sub": "你在器材间翻出一台退役的业余电台。信号灯亮了。你对着话筒说了一句：有人在吗？"},
	{"text": "然后有人回答了。", "sub": ""}
]

const RADIO_MESSAGES := {
	"radio_call": "这里是旧体育馆……有人能听到吗？",
	"radio_call_2": "体育馆，你们的灯还在吗？这里是 Victor Hale，我在城东。",
	"radio_call_3": "最后确认坐标。东经……北纬……如果有人经过水塔路12号，二楼还活着两个。"
}

var ui_layer: CanvasLayer
var root_ui: Control
var hud_nodes: Array[CanvasItem] = []
var cover_panel: PanelContainer
var timer_label: Label
var objective_label: Label
var action_label: Label
var status_label: Label
var log_body: RichTextLabel
var day_panel: PanelContainer
var day_title: Label
var day_body: Label
var day_choice_box: VBoxContainer
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var result_button_box: HBoxContainer
var hotspot_buttons := {}
var hotspot_labels := {}
var first_hint_label: Label
var plank_button: Button
var speed_button: Button

func _ready() -> void:
	_load_assets()
	_build_walk_actor_sprites()
	_reset_campaign()
	_build_ui()
	_build_audio()
	_show_cover()
	set_process(true)

func _process(delta: float) -> void:
	if not game_paused:
		_debug_step(delta * _runtime_time_scale())
	_update_audio_mix()
	if prenight_active:
		prenight_phase += delta
		if prenight_phase < 0.6:
			prenight_label.modulate.a = prenight_phase / 0.6
		elif prenight_phase > 3.0:
			prenight_label.modulate.a = max(0.0, 1.0 - (prenight_phase - 3.0) / 0.8)
			if prenight_phase > 3.8:
				prenight_active = false
				prenight_label.visible = false
				_activate_night()
	if radio_signal_active and radio_signal_char_index < radio_signal_text.length():
		radio_signal_timer += delta
		if radio_signal_timer > 0.04:
			radio_signal_char_index += 1
			radio_signal_timer = 0.0
			queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()
		for id in hotspots.keys():
			if not _hotspot_unlocked(str(id)):
				continue
			var data: Dictionary = hotspots[id]
			var area := Rect2((data["position"] as Vector2) - Vector2(62, 54), Vector2(124, 108))
			if area.has_point(mouse_pos):
				_select_hotspot(str(id))
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var backdrop := _current_backdrop_texture()
	_draw_backdrop()
	if phase == "night" and backdrop == null:
		_draw_room()
	if phase == "night":
		_draw_threats()
		_draw_target_path()
		for id in hotspots.keys():
			if _hotspot_unlocked(str(id)):
				_draw_hotspot(str(id), hotspots[id])
		_draw_actors()
	_draw_final_overlays()

func _load_assets() -> void:
	background_texture = _load_texture(FINAL_ASSET_PATH + "stadium_room_topdown_clean.png")
	if background_texture == null:
		background_texture = _load_texture(FINAL_ASSET_PATH + "stadium_room_topdown.png")
	if background_texture == null:
		background_texture = _load_texture(BACKGROUND_PATH)
	formal_night_backdrop_valid = background_texture != null
	day_background_texture = _load_texture(FINAL_ASSET_PATH + "stadium_room_day_clean.png")
	if day_background_texture == null:
		day_background_texture = _load_texture(FINAL_ASSET_PATH + "stadium_room_day.png")
	breached_background_texture = _load_texture(FINAL_ASSET_PATH + "stadium_room_breached_clean.png")
	if breached_background_texture == null:
		breached_background_texture = _load_texture(FINAL_ASSET_PATH + "stadium_room_breached.png")
	planning_table_texture = _load_texture(FINAL_ASSET_PATH + "day_planning_table_clean.png")
	if planning_table_texture == null:
		planning_table_texture = _load_texture(FINAL_ASSET_PATH + "day_planning_table.png")
	report_table_texture = _load_texture(FINAL_ASSET_PATH + "night_report_clipboard_clean.png")
	if report_table_texture == null:
		report_table_texture = _load_texture(FINAL_ASSET_PATH + "night_report_clipboard.png")
	ending_success_texture = _load_texture(FINAL_ASSET_PATH + "ending_stadium_dawn_clean.png")
	if ending_success_texture == null:
		ending_success_texture = _load_texture(FINAL_ASSET_PATH + "ending_stadium_dawn.png")
	ending_failure_texture = _load_texture(FINAL_ASSET_PATH + "ending_breach_night_clean.png")
	if ending_failure_texture == null:
		ending_failure_texture = _load_texture(FINAL_ASSET_PATH + "ending_breach_night.png")
	hud_panel_texture = _load_texture(FINAL_ASSET_PATH + "hud_status_panel.png")
	upgrade_card_texture = _load_texture(FINAL_ASSET_PATH + "upgrade_card_frame.png")
	blackout_overlay_texture = _load_texture(FINAL_ASSET_PATH + "overlay_blackout.png")
	danger_overlay_texture = _load_texture(FINAL_ASSET_PATH + "overlay_danger_pulse.png")
	radio_waveform_texture = _load_texture(FINAL_ASSET_PATH + "radio_waveform_strip.png")
	player_texture = _load_texture(PLAYER_PORTRAIT_PATH)
	nora_texture = _load_texture(NORA_PORTRAIT_PATH)
	elias_texture = _load_texture(ELIAS_PORTRAIT_PATH)
	player_actor_front_texture = _load_texture(PLAYER_ACTOR_FRONT_PATH)
	player_actor_side_texture = _load_texture(PLAYER_ACTOR_SIDE_PATH)
	player_actor_back_texture = _load_texture(PLAYER_ACTOR_BACK_PATH)
	player_walk_frames = load(PLAYER_WALK_FRAMES_PATH) as SpriteFrames
	nora_walk_frames = load(NORA_WALK_FRAMES_PATH) as SpriteFrames
	elias_walk_frames = load(ELIAS_WALK_FRAMES_PATH) as SpriteFrames
	battery_icon = _load_texture(BATTERY_ICON_PATH)
	radio_icon = _load_texture(RADIO_ICON_PATH)
	plank_icon = _load_texture(PLANK_ICON_PATH)
	front_threat_texture = _load_texture(FRONT_THREAT_PATH)
	back_threat_texture = _load_texture(BACK_THREAT_PATH)
	left_threat_texture = _load_texture(LEFT_THREAT_PATH)
	right_threat_texture = _load_texture(RIGHT_THREAT_PATH)
	zombie_single_texture = _load_texture(ZOMBIE_SINGLE_PATH)
	zombie_pair_texture = _load_texture(ZOMBIE_PAIR_PATH)
	zombie_crowd_texture = _load_texture(ZOMBIE_CROWD_PATH)
	zombie_hands_texture = _load_texture(ZOMBIE_HANDS_PATH)
	_load_final_texture_sets()

func _load_final_texture_sets() -> void:
	hotspot_state_textures = NightShiftArt.load_hotspot_state_textures(FINAL_ASSET_PATH, _load_texture)
	upgrade_icon_textures = NightShiftArt.load_upgrade_icon_textures(FINAL_ASSET_PATH, _load_texture)
	upgrade_event_textures = NightShiftArt.load_upgrade_event_textures(FINAL_ASSET_PATH, _load_texture)
	upgrade_event_thumb_textures = _make_upgrade_event_thumbnails()
	alert_icon_textures = NightShiftArt.load_alert_icon_textures(FINAL_ASSET_PATH, _load_texture)

func _build_audio() -> void:
	audio_enabled = DisplayServer.get_name() != "headless"
	if not audio_enabled:
		return
	music_player = AudioStreamPlayer.new()
	music_player.name = "NightShiftMusic"
	music_player.volume_db = -6.0
	add_child(music_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "NightShiftAmbience"
	ambience_player.volume_db = -31.0
	procedural_ambience_stream = _make_audio_stream(5.0, 44.0, 0.10, 0.10, true)
	ambience_player.stream = procedural_ambience_stream
	add_child(ambience_player)
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.name = "NightShiftSfx%d" % i
		add_child(player)
		sfx_players.append(player)
	_register_sfx("night_start", _make_audio_stream(0.9, 92.0, 0.18, 0.03), -14.0)
	_register_sfx("warning", _make_audio_stream(0.28, 660.0, 0.16, 0.04), -12.0)
	_register_sfx("door_hit", _make_audio_stream(0.62, 58.0, 0.42, 0.18), -7.0)
	_register_sfx("window_hit", _make_audio_stream(0.36, 280.0, 0.25, 0.20), -9.0)
	_register_sfx("radio_call", _make_audio_stream(0.72, 980.0, 0.15, 0.16), -11.0)
	_register_sfx("radio_connect", _make_audio_stream(0.82, 440.0, 0.18, 0.02), -11.0)
	_register_sfx("antenna", _make_audio_stream(0.42, 1240.0, 0.12, 0.20), -13.0)
	_register_sfx("support", _make_audio_stream(0.55, 520.0, 0.14, 0.05), -13.0)
	_register_sfx("plank", _make_audio_stream(0.22, 140.0, 0.34, 0.18), -8.0)
	_register_sfx("blackout", _make_audio_stream(1.15, 38.0, 0.34, 0.12), -7.0)
	_register_sfx("power_restore", _make_audio_stream(0.85, 120.0, 0.18, 0.03), -12.0)
	_register_sfx("story", _make_audio_stream(0.42, 392.0, 0.11, 0.01), -17.0)
	_register_sfx("success", _make_audio_stream(1.05, 330.0, 0.16, 0.01), -12.0)
	_register_sfx("failure", _make_audio_stream(1.2, 48.0, 0.28, 0.08), -8.0)

func _register_sfx(id: String, stream: AudioStream, volume_db: float) -> void:
	sfx_streams[id] = stream
	sfx_volume_db[id] = volume_db

func _make_audio_stream(duration: float, frequency: float, volume: float, noise: float, loop: bool = false) -> AudioStreamWAV:
	var sample_count: int = maxi(1, int(duration * AUDIO_SAMPLE_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / float(AUDIO_SAMPLE_RATE)
		var progress := float(i) / float(maxi(1, sample_count - 1))
		var attack: float = minf(1.0, progress / 0.08)
		var release: float = minf(1.0, (1.0 - progress) / 0.18)
		var envelope: float = 1.0 if loop else min(attack, release)
		var wave := sin(TAU * frequency * t)
		wave += 0.42 * sin(TAU * frequency * 0.51 * t)
		if noise > 0.0:
			var static_noise := sin(191.0 * t + sin(37.0 * t) * 4.0) * sin(823.0 * t)
			wave = lerpf(wave, static_noise, noise)
		var sample := int(clampf(wave * volume * envelope, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = sample_count
	return stream

func _refresh_audio_state() -> void:
	if not audio_enabled:
		return
	var key := _music_key()
	if key != current_music_key:
		current_music_key = key
		var music := _load_audio_stream("music_%s" % key)
		if music == null and key in ["night_late", "night_final"]:
			music = _load_audio_stream("music_night")
		if music == null and key in ["success", "failure"]:
			music = _load_audio_stream("music_report")
		if music != null:
			music_player.stream = _make_stream_loop(music)
			music_player.play()
		else:
			music_player.stop()
	if phase == "night":
		var ambience_key := _ambience_key()
		if ambience_key != current_ambience_key:
			current_ambience_key = ambience_key
			ambience_player.stream = _night_ambience_stream(ambience_key)
		if ambience_player != null and not ambience_player.playing:
			ambience_player.play()
	else:
		current_ambience_key = ""
		if ambience_player != null and ambience_player.playing:
			ambience_player.stop()
	_update_audio_mix()

func _music_key() -> String:
	if phase == "cover":
		return "cover"
	if phase == "day":
		return "day"
	if phase == "night":
		if _level_number() >= 6:
			return "night_final"
		return "night_early"
	if phase == "report":
		return "success" if last_night_success else "failure"
	if phase == "final":
		return "final"
	return "night"

func _ambience_key() -> String:
	if _level_number() >= 10:
		return "night_final"
	if _level_number() >= 7:
		return "night_late"
	return "night"

func _night_ambience_stream(key: String) -> AudioStream:
	var candidates: Array[String] = ["ambience_%s" % key]
	if key == "night_final":
		candidates.append("ambience_night_late")
	if key in ["night_final", "night_late"]:
		candidates.append("ambience_night")
	for candidate in candidates:
		var stream := _load_audio_stream(candidate)
		if stream != null:
			return _make_stream_loop(stream)
	return procedural_ambience_stream

func _load_audio_stream(name: String) -> AudioStream:
	for ext in [".ogg", ".mp3", ".wav"]:
		var path := "%s%s%s" % [AUDIO_ASSET_PATH, name, ext]
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null

func _make_stream_loop(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var looped := stream.duplicate(true) as AudioStream
	if looped == null:
		looped = stream
	for property in looped.get_property_list():
		if str(property.get("name", "")) == "loop":
			looped.set("loop", true)
		elif str(property.get("name", "")) == "loop_mode" and looped is AudioStreamWAV:
			(looped as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return looped

func _stream_has_loop_enabled(stream: AudioStream) -> bool:
	if stream == null:
		return false
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	for property in stream.get_property_list():
		if str(property.get("name", "")) == "loop":
			return bool(stream.get("loop"))
	return false

func _update_audio_mix() -> void:
	if not audio_enabled or ambience_player == null:
		return
	if phase != "night":
		return
	if ambience_player.stream != null and not ambience_player.playing:
		ambience_player.play()
	var crisis_count := _current_crisis_count()
	var target_volume := -31.0 + float(min(crisis_count, 5)) * 2.1
	if blackout:
		target_volume += 2.5
	ambience_player.volume_db = lerpf(ambience_player.volume_db, target_volume, 0.04)

func _play_sfx(id: String, volume_offset: float = 0.0) -> void:
	if not audio_enabled or not sfx_streams.has(id):
		return
	for player in sfx_players:
		if not player.playing:
			player.stream = sfx_streams[id] as AudioStream
			player.volume_db = float(sfx_volume_db.get(id, -12.0)) + volume_offset
			player.pitch_scale = randf_range(0.96, 1.04)
			player.play()
			return

func _reset_campaign() -> void:
	current_level_index = 0
	allies = {"nora": false, "elias": false}
	upgrades.clear()
	outcome = ""
	game_over = false
	logs.clear()
	_setup_hotspots()

func _setup_hotspots() -> void:
	hotspots = {
		"front_door": {
			"name": "正门",
			"kind": "barrier",
			"position": Vector2(506, 162),
			"work_position": Vector2(506, 226),
			"value": 78.0,
			"pressure": 4.4,
			"active": true,
			"assault": false,
			"warning": false,
			"braced": false,
			"temp_seal": 0.0,
			"breach_timer": -1.0,
			"hint": "挡住正门"
		},
		"left_window": {
			"name": "左窗",
			"kind": "barrier",
			"position": Vector2(150, 222),
			"work_position": Vector2(238, 260),
			"value": 100.0,
			"pressure": 0.0,
			"active": false,
			"assault": false,
			"warning": false,
			"braced": false,
			"temp_seal": 0.0,
			"breach_timer": -1.0,
			"hint": "钉住窗板"
		},
		"right_window": {
			"name": "右窗",
			"kind": "barrier",
			"position": Vector2(862, 222),
			"work_position": Vector2(792, 260),
			"value": 100.0,
			"pressure": 0.0,
			"active": false,
			"assault": false,
			"warning": false,
			"braced": false,
			"temp_seal": 0.0,
			"breach_timer": -1.0,
			"hint": "钉住窗板"
		},
		"generator": {
			"name": "发电机",
			"position": Vector2(464, 490),
			"work_position": Vector2(500, 430),
			"value": 82.0,
			"pressure": 0.0,
			"active": false,
			"assault": false,
			"warning": false,
			"braced": false,
			"temp_seal": 0.0,
			"breach_timer": -1.0,
			"hint": "恢复供电"
		},
		"radio": {
			"name": "电台",
			"kind": "radio",
			"position": Vector2(818, 360),
			"work_position": Vector2(760, 380),
			"value": 0.0,
			"pressure": 0.0,
			"active": false,
			"assault": false,
			"warning": false,
			"braced": false,
			"temp_seal": 0.0,
			"breach_timer": -1.0,
			"hint": "接通呼叫"
		},
		"antenna": {
			"name": "天线",
			"kind": "antenna",
			"position": Vector2(914, 162),
			"work_position": Vector2(830, 190),
			"value": 100.0,
			"pressure": 0.0,
			"active": false,
			"assault": false,
			"warning": false,
			"braced": false,
			"temp_seal": 0.0,
			"breach_timer": -1.0,
			"hint": "校准天线"
		},
		"back_door": {
			"name": "后门",
			"kind": "barrier",
			"position": Vector2(710, 526),
			"work_position": Vector2(670, 470),
			"value": 100.0,
			"pressure": 0.0,
			"active": false,
			"assault": false,
			"warning": false,
			"braced": false,
			"temp_seal": 0.0,
			"breach_timer": -1.0,
			"hint": "修理后门"
		},
		"medbay": {
			"name": "医务角",
			"position": Vector2(148, 378),
			"work_position": Vector2(238, 380),
			"value": 100.0,
			"pressure": 0.0,
			"active": false,
			"warning": false,
			"breach_timer": -1.0,
			"hint": "处理伤员"
		},
		"storage": {
			"name": "储物间",
			"position": Vector2(804, 488),
			"work_position": Vector2(740, 480),
			"value": 100.0,
			"pressure": 0.0,
			"active": false,
			"warning": false,
			"breach_timer": -1.0,
			"hint": "找木板"
	}
}

func _build_opening_panel() -> void:
	root_ui.add_child(opening_panel)
	var vbox := VBoxContainer.new()
	vbox.name = "OpeningVBox"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 60)
	vbox.add_theme_constant_override("separation", 16)
	opening_panel.add_child(vbox)
	var main_label := Label.new()
	main_label.name = "OpeningMain"
	main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_label.add_theme_font_size_override("font_size", 40)
	main_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	vbox.add_child(main_label)
	var sub_label := Label.new()
	sub_label.name = "OpeningSub"
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_label.custom_minimum_size = Vector2(600, 0)
	sub_label.add_theme_font_size_override("font_size", 20)
	sub_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.88, 1.0))
	vbox.add_child(sub_label)
	var prompt_label := Label.new()
	prompt_label.name = "OpeningPrompt"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Modified version to avoid const string literal
	prompt_label.text = "鐐�„�œ缁�…�”�"
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.add_theme_color_override("font_color", Color(0.50, 0.65, 0.62, 0.80))
	vbox.add_child(prompt_label)
	prenight_label = Label.new()
	prenight_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 40)
	prenight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prenight_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prenight_label.custom_minimum_size = Vector2(700, 0)
	prenight_label.add_theme_font_size_override("font_size", 26)
	prenight_label.add_theme_color_override("font_color", Color(0.88, 0.96, 0.92, 1.0))
	prenight_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	prenight_label.add_theme_constant_override("shadow_offset_x", 2)
	prenight_label.add_theme_constant_override("shadow_offset_y", 2)
	prenight_label.visible = false
	prenight_label.mouse_filter = Control.MOUSE_FILTER_STOP
	root_ui.add_child(prenight_label)

func _build_crisis_indicator() -> void:
	crisis_bar_bg = ColorRect.new()
	crisis_bar_bg.position = Vector2(1256, 320)
	crisis_bar_bg.size = Vector2(16, 80)
	crisis_bar_bg.color = Color(0.08, 0.02, 0.02, 0.40)
	crisis_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(crisis_bar_bg)
	crisis_bar = ColorRect.new()
	crisis_bar.position = Vector2(1258, 322)
	crisis_bar.size = Vector2(12, 76)
	crisis_bar.color = Color(0.90, 0.06, 0.0, 0.0)
	crisis_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ui.add_child(crisis_bar)

func _fade_transition(target_phase: String, callback: Callable, fade_out: float = 0.20, hold: float = 0.05, fade_in: float = 0.25) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(transition_overlay, "color:a", 1.0, fade_out)
	tween.tween_callback(callback)
	tween.tween_interval(hold)
	tween.tween_property(transition_overlay, "color:a", 0.0, fade_in)

func _animate_cover_entrance() -> void:
	if cover_panel == null:
		return
	if cover_tween != null and cover_tween.is_valid():
		cover_tween.kill()
	cover_panel.modulate = Color(1, 1, 1, 0)
	cover_panel.scale = Vector2(0.96, 0.96)
	cover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	cover_tween.tween_property(cover_panel, "scale", Vector2(1.0, 1.0), 0.40)
	cover_tween.parallel().tween_property(cover_panel, "modulate:a", 1.0, 0.30)

func _animate_hud_elements_in() -> void:
	for node in hud_nodes:
		if node is CanvasItem:
			node.modulate = Color(1, 1, 1, 0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	for node in hud_nodes:
		if node is CanvasItem:
			tween.tween_property(node, "modulate:a", 0.82 if node == hud_nodes[0] else 1.0, 0.25)

func _build_hotspot_buttons() -> void:
	hotspot_buttons.clear()
	hotspot_labels.clear()
	var button_layer := Control.new()
	button_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(button_layer)
	for id in hotspots.keys():
		var data: Dictionary = hotspots[id]
		var button := Button.new()
		button.text = ""
		button.position = (data["position"] as Vector2) - Vector2(44, 44)
		button.size = Vector2(88, 88)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = str(data.get("hint", ""))
		_style_hotspot_button(button)
		var captured_id := str(id)
		button.pressed.connect(func() -> void: _select_hotspot(captured_id))
		button_layer.add_child(button)
		hotspot_buttons[id] = button

		var label := Label.new()
		label.text = str(data.get("name", id))
		label.position = (data["position"] as Vector2) + Vector2(-42, 34)
		label.size = Vector2(84, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.86, 0.96, 0.90, 0.95))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		button_layer.add_child(label)
		hotspot_labels[id] = label

	first_hint_label = Label.new()
	first_hint_label.text = "鍏堢偣杩�“�™�"
	first_hint_label.position = Vector2(420, 42)
	first_hint_label.size = Vector2(116, 30)
	first_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	first_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	first_hint_label.add_theme_font_size_override("font_size", 20)
	first_hint_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32, 1.0))
	first_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	first_hint_label.add_theme_constant_override("shadow_offset_x", 2)
	first_hint_label.add_theme_constant_override("shadow_offset_y", 2)
	button_layer.add_child(first_hint_label)

func _build_hud() -> void:
	if hud_panel_texture != null:
		var hud_backdrop := TextureRect.new()
		hud_backdrop.position = HUD_POS
		hud_backdrop.size = HUD_SIZE
		hud_backdrop.texture = hud_panel_texture
		hud_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hud_backdrop.stretch_mode = TextureRect.STRETCH_SCALE
		hud_backdrop.modulate = Color(1, 1, 1, 0.82)
		hud_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ui.add_child(hud_backdrop)
		hud_nodes.append(hud_backdrop)
	var hud_panel := _make_panel(HUD_POS, HUD_SIZE, Color(0.018, 0.024, 0.026, 0.66), Color(0.30, 0.84, 0.82, 0.72))
	root_ui.add_child(hud_panel)
	hud_nodes.append(hud_panel)
	var margin := hud_panel.get_child(0) as MarginContainer
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var title := Label.new()
	title.text = "需要处理"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
	box.add_child(title)

	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 14)
	timer_label.add_theme_color_override("font_color", Color(0.78, 0.96, 0.94, 1.0))
	box.add_child(timer_label)

	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.82, 1.0))
	objective_label.custom_minimum_size = Vector2(0, 44)
	box.add_child(objective_label)

	action_label = Label.new()
	action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_label.add_theme_font_size_override("font_size", 13)
	action_label.add_theme_color_override("font_color", Color(0.42, 0.95, 1.0, 1.0))
	action_label.custom_minimum_size = Vector2(0, 24)
	box.add_child(action_label)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.78, 0.90, 0.88, 1.0))
	status_label.visible = false
	status_label.custom_minimum_size = Vector2(0, 0)
	box.add_child(status_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	box.add_child(action_row)

	plank_button = Button.new()
	plank_button.text = "扔木板"
	plank_button.custom_minimum_size = Vector2(156, 36)
	plank_button.add_theme_font_size_override("font_size", 16)
	plank_button.icon = plank_icon
	plank_button.expand_icon = true
	plank_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plank_button.pressed.connect(_use_emergency_plank)
	action_row.add_child(plank_button)

	speed_button = Button.new()
	speed_button.text = "1x"
	speed_button.tooltip_text = "需要处理"
	speed_button.custom_minimum_size = Vector2(62, 36)
	speed_button.add_theme_font_size_override("font_size", 16)
	speed_button.pressed.connect(_toggle_time_scale)
	action_row.add_child(speed_button)

	var log_title := Label.new()
	log_title.text = "最近记录"
	log_title.add_theme_font_size_override("font_size", 14)
	log_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
	box.add_child(log_title)

	log_body = RichTextLabel.new()
	log_body.bbcode_enabled = false
	log_body.fit_content = false
	log_body.scroll_active = false
	log_body.custom_minimum_size = Vector2(0, 86)
	log_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_body.add_theme_font_size_override("normal_font_size", 12)
	log_body.add_theme_color_override("default_color", Color(0.82, 0.92, 0.88, 1.0))
	box.add_child(log_body)

func _build_cover_panel() -> void:
	cover_panel = _make_panel(Vector2(96, 108), Vector2(760, 430), Color(0.012, 0.018, 0.018, 0.82), Color(1.0, 0.82, 0.42, 0.84))
	root_ui.add_child(cover_panel)
	var margin := cover_panel.get_child(0) as MarginContainer
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)
	var title := Label.new()
	title.text = "需要处理"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	box.add_child(title)
	var body := Label.new()
	body.text = ""
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.88, 0.96, 0.92, 1.0))
	body.custom_minimum_size = Vector2(0, 112)
	box.add_child(body)
	var start := Button.new()
	start.text = ""
	start.add_theme_font_size_override("font_size", 22)
	start.pressed.connect(func() -> void: _enter_day(0))
	box.add_child(start)

func _build_day_panel() -> void:
	day_panel = _make_panel(Vector2(62, 78), Vector2(866, 536), Color(0.018, 0.025, 0.024, 0.84), Color(0.35, 0.88, 0.82, 0.86))
	root_ui.add_child(day_panel)
	var margin := day_panel.get_child(0) as MarginContainer
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	day_title = Label.new()
	day_title.add_theme_font_size_override("font_size", 30)
	day_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
	box.add_child(day_title)
	day_body = Label.new()
	day_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	day_body.add_theme_font_size_override("font_size", 16)
	day_body.add_theme_color_override("font_color", Color(0.86, 0.96, 0.92, 1.0))
	day_body.custom_minimum_size = Vector2(0, 78)
	box.add_child(day_body)
	day_choice_box = VBoxContainer.new()
	day_choice_box.add_theme_constant_override("separation", 8)
	day_choice_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(day_choice_box)

func _build_result_panel() -> void:
	result_panel = _make_panel(Vector2(314, 196), Vector2(584, 328), Color(0.018, 0.023, 0.024, 0.84), Color(1.0, 0.82, 0.34, 0.92))
	result_panel.visible = false
	root_ui.add_child(result_panel)
	var margin := result_panel.get_child(0) as MarginContainer
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 15)
	margin.add_child(box)
	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 34)
	result_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
	box.add_child(result_title)
	result_body = Label.new()
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.add_theme_font_size_override("font_size", 17)
	result_body.add_theme_color_override("font_color", Color(0.88, 0.96, 0.92, 1.0))
	box.add_child(result_body)
	result_button_box = HBoxContainer.new()
	result_button_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_button_box.add_theme_constant_override("separation", 12)
	box.add_child(result_button_box)

func _enter_day(index: int) -> void:
	current_level_index = index
	phase = "day"
	last_night_success = false
	_setup_hotspots()
	night_elapsed = 0.0
	blackout = false
	radio_available = false
	radio_missed = false
	radio_completed = false
	result_text = ""
	player_target_id = ""
	_reset_actor_positions()
	logs.clear()
	_add_log("")
	day_tween.tween_property(day_panel, "modulate:a", 1.0, 0.30)
	_refresh_audio_state()
	_refresh_ui()

func _rebuild_day_panel() -> void:
	for child in day_choice_box.get_children():
		child.queue_free()
	var level := _level()
	day_title.text = str(level.get("title", "需要处理"))
	var intro := str(level.get("story_intro", level.get("briefing", "")))
	day_body.text = "%s\n\n浠�ƒ�„�”›?s" % [intro, str(level.get("night_goal", ""))]
	var choices: Array = level.get("choices", []) as Array
	for entry in choices:
		var choice := entry as Dictionary
		var button := Button.new()
		var captured_id := str(choice.get("id", "start"))
		var event_texture := _upgrade_event_texture(captured_id)
		var icon_texture := _upgrade_event_thumb_texture(captured_id)
		if icon_texture == null:
			icon_texture = _upgrade_icon_texture(captured_id)
		var has_event_art := event_texture != null
		button.text = "%s\n%s" % [str(choice.get("title", "")), str(choice.get("body", ""))]
		button.custom_minimum_size = Vector2(0, 112 if has_event_art else 68)
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		button.clip_contents = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 15 if has_event_art else 16)
		button.add_theme_constant_override("h_separation", 14 if has_event_art else 8)
		if icon_texture != null:
			button.icon = icon_texture
			button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_style_day_choice_button(button, has_event_art)
		button.pressed.connect(func() -> void: _choose_day_action(captured_id))
		day_choice_box.add_child(button)

func _show_cover() -> void:
	phase = "cover"
	game_over = false
	night_elapsed = 0.0
	if cover_panel != null:
		cover_panel.visible = true
	if day_panel != null:
		day_panel.visible = false
	if result_panel != null:
		result_panel.visible = false
	_refresh_audio_state()
	_animate_cover_entrance()
	_refresh_ui()

func _choose_day_action(choice_id: String) -> bool:
	if phase != "day":
		return false
	if choice_id != "start":
		upgrades[choice_id] = true
		_add_log("")
	phase = "night"
	night_elapsed = 0.0
	blackout = false
	radio_available = false
	radio_missed = false
	radio_completed = false
	radio_call_started_at = -1.0
	radio_contacts_done = 0
	result_text = ""
	first_door_hint_done = false
	plank_cooldown = 0.0
	night_time_scale = 1.0
	director_event_count = 0
	last_director_target = ""
	next_rhythm_time = RHYTHM_TICK_INTERVAL
	rhythm_tick_count = 0
	rhythm_pressure_count = 0
	last_rhythm_target = ""
	last_rhythm_kind = ""
	events_done.clear()
	_build_night_schedule()
	_schedule_next_director_event()
	_setup_night_hotspots()
	_reset_actor_positions()
	logs.clear()
	var start_lines := _story_lines(_level().get("story_start", []))
	if start_lines.is_empty():
		_add_log("")
		for line in start_lines:
			combined += line + "\n"
		prenight_label.text = combined.strip_edges()
		prenight_label.modulate.a = 0.0
		prenight_label.visible = true
		prenight_phase = 0.0
		prenight_active = true
		for line in start_lines:
			_add_log(line)
	_add_log("")
	_play_sfx("night_start")
	_refresh_audio_state()
	_refresh_ui()

func _reset_actor_positions() -> void:
	player_pos = PLAYER_HOME
	player_target_pos = player_pos
	player_target_id = ""
	player_route.clear()
	_reset_nora_home_state()
	_reset_elias_home_state()

func _reset_nora_home_state() -> void:
	nora_pos = NORA_HOME
	nora_target_pos = nora_pos
	nora_target_id = ""
	nora_route.clear()
	nora_commit_time = 0.0
	nora_target_cooldowns.clear()

func _reset_elias_home_state() -> void:
	elias_pos = ELIAS_HOME
	elias_target_pos = elias_pos
	elias_target_id = ""
	elias_route.clear()
	elias_commit_time = 0.0
	elias_target_cooldowns.clear()

func _setup_night_hotspots() -> void:
	_setup_hotspots()
	hotspots["front_door"]["value"] = min(_max_value("front_door"), 78.0 + current_level_index * 5.0)
	hotspots["front_door"]["pressure"] = 4.4 + current_level_index * 0.7
	hotspots["generator"]["value"] = _max_value("generator") if bool(upgrades.get("battery_buffer", false)) else 82.0
	if _level_number() >= 2:
		hotspots["right_window"]["value"] = min(_max_value("right_window"), 86.0)
	if _level_number() >= 4:
		hotspots["antenna"]["value"] = min(_max_value("antenna"), 92.0)
		hotspots["antenna"]["active"] = true
	if _level_number() >= 6:
		hotspots["back_door"]["value"] = min(_max_value("back_door"), 92.0)
	if _level_number() >= 7:
		hotspots["medbay"]["value"] = 86.0
	if _level_number() >= 8:
		hotspots["storage"]["value"] = 82.0

func _build_night_schedule() -> void:
	night_schedule.clear()
	if debug_seed_override >= 0:
		night_seed = debug_seed_override
		night_rng.seed = debug_seed_override
	else:
		night_rng.randomize()
		night_seed = int(night_rng.seed)
	var level_num := _level_number()
	night_schedule["generator_flicker"] = _roll_time(16.0, 22.0) if level_num == 1 else _roll_time(12.0, 21.0)
	if level_num >= 5:
		night_schedule["generator_second"] = _roll_time(76.0, 92.0)
	if level_num >= 5:
		var back_warning := _roll_time(30.0, 42.0)
		night_schedule["back_door_warning"] = back_warning
		night_schedule["back_door"] = back_warning + _roll_time(5.0, 8.0)
	if level_num >= 6:
		night_schedule["medbay_call"] = _roll_time(48.0, 66.0)
	if level_num >= 7:
		night_schedule["storage_shortage"] = _roll_time(38.0, 58.0)
	var first_window := "left_window"
	if level_num >= 2 and night_rng.randi_range(0, 1) == 0:
		first_window = "right_window"
	var second_window := "right_window" if first_window == "left_window" else "left_window"
	var first_warning := _roll_time(22.0, 30.0) if level_num >= 2 else _roll_time(24.0, 31.0)
	if level_num >= 3:
		first_warning = _roll_time(19.0, 27.0)
	night_schedule["%s_warning" % first_window] = first_warning
	night_schedule[first_window] = first_warning + _roll_time(4.5, 7.0)
	if level_num >= 2:
		var second_warning := first_warning + _roll_time(5.0, 11.0)
		night_schedule["%s_warning" % second_window] = second_warning
		night_schedule[second_window] = second_warning + _roll_time(4.5, 7.0)
	if level_num >= 4:
		var antenna_warning := _roll_time(18.0, 27.0)
		night_schedule["antenna_warning"] = antenna_warning
		night_schedule["antenna_drop"] = antenna_warning + _roll_time(5.0, 8.0)
		if level_num >= 5:
			night_schedule["antenna_late"] = _roll_time(88.0, 106.0)
		if level_num >= 9:
			night_schedule["antenna_blackout_link"] = _roll_time(68.0, 90.0)
		if level_num >= 10:
			night_schedule["final_wave"] = _roll_time(116.0, 132.0)
	if level_num >= 3:
		night_schedule["radio_call"] = _roll_time(24.0, 34.0)
	if level_num >= 4:
		night_schedule["radio_call"] = _roll_time(46.0, 60.0)
		night_schedule["radio_call_2"] = _roll_time(92.0, minf(_night_duration() - 22.0, 118.0))
	if level_num >= 9:
		night_schedule["radio_call_3"] = _roll_time(128.0, minf(_night_duration() - 18.0, 150.0))
	var latest_assault := float(night_schedule.get("left_window", 32.0))
	if night_schedule.has("right_window"):
		latest_assault = max(latest_assault, float(night_schedule["right_window"]))
	var duration := _night_duration()
	var hard_min: float = maxf(duration * 0.60, latest_assault + 22.0)
	var hard_max: float = minf(duration * 0.70, hard_min + 10.0)
	if hard_max < hard_min:
		hard_max = hard_min + 1.0
	night_schedule["hard_push"] = _roll_time(hard_min, hard_max)
	night_schedule["late_push"] = _roll_time(maxf(duration * 0.78, float(night_schedule["hard_push"]) + 16.0), maxf(duration * 0.82, float(night_schedule["hard_push"]) + 22.0))
	night_schedule["final_pressure"] = _roll_time(maxf(duration - 30.0, float(night_schedule["late_push"]) + 14.0), maxf(duration - 18.0, float(night_schedule["late_push"]) + 20.0))

func _roll_time(min_time: float, max_time: float) -> float:
	if max_time <= min_time:
		return min_time
	return snappedf(night_rng.randf_range(min_time, max_time), 0.1)

func _schedule_time(id: String, fallback: float) -> float:
	if night_schedule.has(id):
		return float(night_schedule[id])
	return fallback

func _schedule_next_director_event() -> void:
	var spacing_min := 16.0 if _level_number() == 1 else maxf(8.0, 13.0 - float(_level_number()) * 0.35)
	var spacing_max := 24.0 if _level_number() == 1 else maxf(13.0, 21.0 - float(_level_number()) * 0.45)
	var first_min := 34.0 if _level_number() == 1 else maxf(24.0, 38.0 - float(_level_number()) * 1.1)
	if director_event_count == 0:
		next_director_time = _roll_time(first_min, first_min + 10.0)
	else:
		next_director_time = night_elapsed + _roll_time(spacing_min, spacing_max)

func _director_event_limit() -> int:
	match _level_number():
		1:
			return 1
		2:
			return 2
		4:
			return 4
		5:
			return 5
		6, 7:
			return 6
		8, 9:
			return 7
		10:
			return 8
		_:
			return 3

func _run_director() -> void:
	if director_event_count >= _director_event_limit():
		return
	if night_elapsed < next_director_time:
		return
	var hard_push_time := _schedule_time("hard_push", 78.0)
	if night_elapsed >= hard_push_time - 4.0 and night_elapsed <= hard_push_time + 8.0:
		next_director_time = hard_push_time + 8.0
		return
	if _current_crisis_count() >= _director_crisis_cap():
		next_director_time = night_elapsed + _roll_time(7.0, 11.0)
		return
	var target := _director_pick_target()
	if target == "":
		next_director_time = night_elapsed + _roll_time(6.0, 10.0)
		return
	_apply_director_event(target)
	director_event_count += 1
	last_director_target = target
	_schedule_next_director_event()

func _current_crisis_count() -> int:
	var count := 0
	for id in _barrier_ids():
		if not _hotspot_unlocked(id):
			continue
		var data: Dictionary = hotspots[id]
		if bool(data.get("assault", false)) or float(data.get("breach_timer", -1.0)) >= 0.0:
			count += 1
	if _hotspot_unlocked("antenna"):
		var antenna: Dictionary = hotspots["antenna"]
		if bool(antenna.get("active", false)) and float(antenna.get("value", 100.0)) < 70.0:
			count += 1
	if blackout:
		count += 1
	if radio_available and not radio_completed:
		count += 1
	return count

func _barrier_ids() -> Array[String]:
	var ids: Array[String] = ["front_door", "left_window", "right_window"]
	if _hotspot_unlocked("back_door"):
		ids.append("back_door")
	return ids

func _director_pick_target() -> String:
	var candidates: Array[String] = []
	for id in ["front_door", "left_window", "right_window", "back_door", "generator", "antenna", "medbay", "storage"]:
		if not _hotspot_unlocked(id):
			continue
		if id == player_target_id or id == last_director_target:
			continue
		var data: Dictionary = hotspots[id]
		var value := float(data.get("value", 100.0))
		if value < 48.0:
			continue
		if float(data.get("temp_seal", 0.0)) > 0.0:
			continue
		if str(data.get("kind", "")) == "barrier" and bool(data.get("assault", false)):
			continue
		if str(data.get("kind", "")) == "generator" and blackout:
			continue
		if str(data.get("kind", "")) == "support" and bool(data.get("active", false)):
			continue
		candidates.append(id)
	if candidates.is_empty():
		return ""
	return candidates[night_rng.randi_range(0, candidates.size() - 1)]

func _director_crisis_cap() -> int:
	if _level_number() >= 8:
		return 4
	if _level_number() >= 4:
		return 3
	return 2

func _apply_director_event(id: String) -> void:
	if not hotspots.has(id):
		return
	var data: Dictionary = hotspots[id]
	if str(data.get("kind", "")) == "generator":
		data["active"] = true
		data["braced"] = false
		data["pressure"] = max(float(data.get("pressure", 0.0)), _generator_pressure(0.9 + current_level_index * 0.22))
		data["value"] = max(0.0, float(data.get("value", 100.0)) - _roll_time(5.0, 10.0))
		hotspots[id] = data
		if str(data.get("kind", "")) == "antenna":
			_add_log("")
		data["active"] = true
		data["warning"] = true
		data["pressure"] = max(float(data.get("pressure", 0.0)), _antenna_pressure(1.1 + current_level_index * 0.16))
		data["value"] = max(0.0, float(data.get("value", 100.0)) - _roll_time(7.0, 13.0))
		hotspots[id] = data
		_add_log("")ind", "")) == "support":
		data["active"] = true
		data["warning"] = true
		data["pressure"] = max(float(data.get("pressure", 0.0)), 0.75 + current_level_index * 0.10)
		data["value"] = max(0.0, float(data.get("value", 100.0)) - _roll_time(6.0, 12.0))
		hotspots[id] = data
		_add_log("%s�–��ˆ�Ÿ�œ�†�捣绾�ˆ��…�”›屽緱�Ž��•Œ�”–杩�›��“澶�‹��‚Š�Š†? % str(data.get("name", id)))
		return
	var pressure := _door_pressure(2.5 + current_level_index * 0.35) if id == "front_door" or id == "back_door" else _window_pressure(2.7 + current_level_index * 0.35)
	data["active"] = true
	data["warning"] = true
	data["braced"] = false
	data["pressure"] = max(float(data.get("pressure", 0.0)), pressure)
	data["value"] = max(0.0, float(data.get("value", 100.0)) - _roll_time(3.0, 7.0))
	hotspots[id] = data
	_add_log("%s澶栫�Š�’跺�•��—ˆ�Ž�…�‰�ƒ�紝�“嬩竴�‰�Ž�紶�‰�ƒ��˜��Ž��ˆ��‚��…�‘�Ž��‚��š��Š†? % str(data.get("name", id)))

func _debug_step(delta: float) -> void:
	if phase != "night":
		_update_walk_actor_sprites()
		queue_redraw()
		return
	night_elapsed += delta
	_run_timeline()
	_update_player(delta)
	_update_nora(delta)
	_update_elias(delta)
	_update_hotspots(delta)
	_update_particles(delta)
	_check_end_conditions()
	_refresh_ui()
	_update_walk_actor_sprites()
	queue_redraw()

func _debug_click_hotspot(id: String) -> bool:
	return _select_hotspot(id)

func _debug_toggle_time_scale() -> bool:
	_toggle_time_scale()
	return true

func _debug_runtime_step(real_delta: float) -> void:
	_debug_step(real_delta * _runtime_time_scale())

func _debug_choose_day(choice_id: String = "start") -> bool:
	return _choose_day_action(choice_id)

func _debug_start_campaign() -> bool:
	if phase == "cover":
		_enter_day(0)
		return true
	return phase == "day"

func _debug_continue_report() -> bool:
	return _continue_from_report()

func _debug_set_seed(seed: int) -> bool:
	debug_seed_override = seed
	return true

func _debug_final_assets_loaded() -> bool:
	if background_texture == null or hud_panel_texture == null:
		return false
	if player_texture == null or nora_texture == null or elias_texture == null:
		return false
	if front_threat_texture == null or back_threat_texture == null or left_threat_texture == null or right_threat_texture == null:
		return false
	if zombie_single_texture == null or zombie_pair_texture == null or zombie_crowd_texture == null or zombie_hands_texture == null:
		return false
	for key in [
		"front_door_intact",
		"back_door_warning",
		"window_warning",
		"generator_stable",
		"radio_calling",
		"antenna_warning",
		"antenna_broken",
		"medbay_warning",
		"storage_shortage"
	]:
		if hotspot_state_textures.get(key) == null:
			return false
	for key in [
		"door_reinforce",
		"window_brace",
		"battery_buffer",
		"generator_tune",
		"radio_booster",
		"workbench",
		"antenna_anchor",
		"storage",
		"medbay",
		"floodlights",
		"second_plank",
		"command_routine",
		"back_door_bar",
		"generator_cage",
		"runner_path",
		"medbay_lamp",
		"nora_kit",
		"quiet_hours",
		"salvage_planks",
		"double_brace",
		"victor_cache",
		"signal_battery",
		"cable_route",
		"elias_tools",
		"final_barricade",
		"all_hands",
		"radio_beacon"
	]:
		if upgrade_event_textures.get(key) == null:
			return false
	return ending_success_texture != null and ending_failure_texture != null

func _debug_upgrade_event_texture_loaded(id: String) -> bool:
	return upgrade_event_textures.get(id) != null

func _debug_hotspot_texture_key(id: String) -> String:
	if not hotspots.has(id):
		return ""
	return _hotspot_texture_key(id, hotspots[id])

func _debug_get_state() -> Dictionary:
	var state_hotspots := {}
	var unlocked: Array[String] = []
	for id in hotspots.keys():
		var data: Dictionary = hotspots[id]
		if _hotspot_unlocked(str(id)):
			unlocked.append(str(id))
		state_hotspots[id] = {
			"value": float(data.get("value", 0.0)),
			"active": bool(data.get("active", false)),
			"breach_timer": float(data.get("breach_timer", -1.0)),
			"pressure": float(data.get("pressure", 0.0)),
			"assault": bool(data.get("assault", false)),
			"warning": bool(data.get("warning", false)),
			"braced": bool(data.get("braced", false)),
			"temp_seal": float(data.get("temp_seal", 0.0)),
			"unlocked": _hotspot_unlocked(str(id))
		}
	return {
		"phase": phase,
		"current_level": _level_number(),
		"time": night_elapsed,
		"blackout": blackout,
		"allies": allies.duplicate(true),
		"upgrades": upgrades.duplicate(true),
		"unlocked_hotspots": unlocked,
		"radio_available": radio_available,
		"radio_completed": radio_completed,
		"radio_missed": radio_missed,
		"radio_contacts_done": radio_contacts_done,
		"radio_call_started_at": radio_call_started_at,
		"night_seed": night_seed,
		"night_schedule": night_schedule.duplicate(true),
		"next_director_time": next_director_time,
		"director_event_count": director_event_count,
		"last_director_target": last_director_target,
		"next_rhythm_time": next_rhythm_time,
		"rhythm_tick_count": rhythm_tick_count,
		"rhythm_pressure_count": rhythm_pressure_count,
		"last_rhythm_target": last_rhythm_target,
		"last_rhythm_kind": last_rhythm_kind,
		"plank_cooldown": plank_cooldown,
		"time_scale": night_time_scale,
		"player_target_id": player_target_id,
		"nora_target_id": nora_target_id,
		"elias_target_id": elias_target_id,
		"outcome": outcome,
		"logs": logs.duplicate(),
		"result_text": result_text,
		"hotspots": state_hotspots
	}

func _debug_get_audio_state() -> Dictionary:
	return {
		"audio_enabled": audio_enabled,
		"music_key": current_music_key,
		"music_stream_loaded": music_player != null and music_player.stream != null,
		"music_playing": music_player != null and music_player.playing,
		"music_loop": music_player != null and _stream_has_loop_enabled(music_player.stream),
		"music_volume_db": music_player.volume_db if music_player != null else -80.0,
		"ambience_key": current_ambience_key,
		"ambience_stream_loaded": ambience_player != null and ambience_player.stream != null,
		"ambience_loop": ambience_player != null and _stream_has_loop_enabled(ambience_player.stream),
		"ambience_playing": ambience_player != null and ambience_player.playing,
		"ambience_volume_db": ambience_player.volume_db if ambience_player != null else -80.0
	}

func _select_hotspot(id: String) -> bool:
	if phase != "night":
		return false
	if not hotspots.has(id) or not _hotspot_unlocked(id):
		return false
	var data: Dictionary = hotspots[id]
	if id == "front_door":
		first_door_hint_done = true
	if str(data.get("kind", "")) == "radio" and (not radio_available or blackout or radio_completed):
		if blackout:
			_add_log("")�›彴宸�Œ�粡�Ž��ƒ��‚�氾紝缁�…�”��€��œ�‡�—‚�„�獥�Š†?)
		else:
			if str(data.get("kind", "")) == "radio" and _antenna_signal_low():
			_add_log("")
		_add_log("")ork_position"] as Vector2
	player_route = _route_to_hotspot(id, player_pos)
	_add_log("")ame", id)))
	return true

func _run_timeline() -> void:
	var level_num := _level_number()
	_run_story_beats()
	_run_rhythm_tick()
	if night_elapsed >= _schedule_time("generator_flicker", 18.0) and not bool(events_done.get("generator_flicker", false)):
		events_done["generator_flicker"] = true
		hotspots["generator"]["active"] = true
		hotspots["generator"]["pressure"] = _generator_pressure(1.15 + current_level_index * 0.35)
		_add_log("")enerator_second", 999.0) and level_num >= 5 and not bool(events_done.get("generator_second", false)):
		events_done["generator_second"] = true
		hotspots["generator"]["active"] = true
		hotspots["generator"]["pressure"] = max(float(hotspots["generator"].get("pressure", 0.0)), _generator_pressure(1.75 + current_level_index * 0.25))
		hotspots["generator"]["value"] = min(float(hotspots["generator"].get("value", 100.0)), 62.0)
		_add_log("")
	if night_elapsed >= _schedule_time("antenna_warning", 999.0) and level_num >= 4 and not bool(events_done.get("antenna_warning", false)):
		_start_antenna_trouble(_antenna_pressure(0.85 + current_level_index * 0.18), 78.0, "需要处理"antenna_warning")
	if night_elapsed >= _schedule_time("antenna_drop", 999.0) and level_num >= 4 and not bool(events_done.get("antenna_drop", false)):
		_start_antenna_trouble(_antenna_pressure(1.45 + current_level_index * 0.22), 56.0, "澶�•ƒ�šŽ绾跨�—�š�‚��‡�‰�’…紝�‡�€�彿�‡�‚��Ÿ‡�œ�—��‚�?, "antenna_drop")
	if night_elapsed >= _schedule_time("antenna_late", 999.0) and level_num >= 5 and not bool(events_done.get("antenna_late", false)):
		_start_antenna_trouble(_antenna_pressure(1.65 + current_level_index * 0.25), 50.0, "需要处理"antenna_late")
	if night_elapsed >= _schedule_time("back_door_warning", 999.0) and level_num >= 5 and not bool(events_done.get("back_door_warning", false)):
		_warn_barrier("back_door", "鍣�„��—�–�氶亾�–��ˆ�Ÿ浼�Š�潵�–��€�‘��Ž�栧湴鐨�‹�０�—Š�‚��‚�?)
	if night_elapsed >= _schedule_time("back_door", 999.0) and level_num >= 5 and not bool(events_done.get("back_door", false)):
		var cap := 78.0 if bool(upgrades.get("back_door_bar", false)) else 68.0
		_start_assault("back_door", _door_pressure(5.6 + current_level_index * 0.55), cap, "需要处理"medbay_call", 999.0) and level_num >= 6 and not bool(events_done.get("medbay_call", false)):
		_start_support_trouble("medbay", 1.25 + current_level_index * 0.12, 48.0, "需要处理"medbay_call")
	if night_elapsed >= _schedule_time("storage_shortage", 999.0) and level_num >= 7 and not bool(events_done.get("storage_shortage", false)):
		_start_support_trouble("storage", 1.5 + current_level_index * 0.12, 44.0, "需要处理"storage_shortage")
	if night_elapsed >= _schedule_time("antenna_blackout_link", 999.0) and level_num >= 9 and not bool(events_done.get("antenna_blackout_link", false)):
		events_done["antenna_blackout_link"] = true
		hotspots["generator"]["pressure"] = max(float(hotspots["generator"].get("pressure", 0.0)), _generator_pressure(2.1 + current_level_index * 0.2))
		_start_antenna_trouble(_antenna_pressure(1.75 + current_level_index * 0.2), 48.0, "需要处理"antenna_blackout_antenna")
	if night_elapsed >= _schedule_time("right_window_warning", 24.0) and level_num >= 2 and not bool(events_done.get("right_window_warning", false)):
		_warn_barrier("right_window", "需要处理"left_window_warning", 26.0) and not bool(events_done.get("left_window_warning", false)):
		_warn_barrier("left_window", "宸︾獥澶栦紶�‰�ƒ��Ÿ‰�Ž��€０�”›屽�„š�ˆ�‰�‰鍦�„��‡œ绐楁�ƒ��Š†?)
	if night_elapsed >= _schedule_time("radio_call", 999.0) and level_num >= 3 and not bool(events_done.get("radio_call", false)):
		_start_radio_call("鐢�›彴�–�屼紶�‰�ƒ�竻妤氱�‘澶栭�„��›�…Ž彿�”›氬�›��‹�„湁�œ�“„�‚��…Ž�•��”›�ƒ�‡�鍥�‚��“Ÿ�Š†?)
	if night_elapsed >= _schedule_time("radio_call_2", 999.0) and level_num >= 4 and not bool(events_done.get("radio_call_2", false)):
		_start_radio_call("鐢�›彴�—�ƒ�簩�†�€��’�’��‡�細浣�’��›棣�—�紝浣�Š��‘鐨�‹��…杩樺湪�š�‹紵")
		events_done["radio_call_2"] = true
	if night_elapsed >= _schedule_time("radio_call_3", 999.0) and level_num >= 9 and not bool(events_done.get("radio_call_3", false)):
		_start_radio_call("需要处理"radio_call_3"] = true
	if night_elapsed >= _schedule_time("right_window", 30.0) and level_num >= 2 and not bool(events_done.get("right_window", false)):
		_start_assault("right_window", _window_pressure(4.6 + current_level_index * 0.8), 72.0, "需要处理"left_window", 32.0) and not bool(events_done.get("left_window", false)):
		_start_assault("left_window", _window_pressure(5.0 + current_level_index * 0.7), 76.0, "宸︾獥�ˆ�„��˜�š�‚��Œ’�‰�’…紝鍐�’�š�寮�‚�濮嬨�‚�?)
	if _radio_should_timeout():
		radio_missed = true
		radio_available = false
		hotspots["radio"]["active"] = false
		_add_log("")ard_push", 78.0) and not bool(events_done.get("hard_push", false)):
		events_done["hard_push"] = true
		_start_assault("front_door", _door_pressure(6.8 + current_level_index * 0.7), 62.0, "姝�‰棬�œ�„棬�—‚�•€竴�’��ƒ�渿�’��”‹潵�Š†?, true)
		_start_assault("left_window", _window_pressure(6.2 + current_level_index * 0.6), 64.0, "宸︾獥�™堝搷�œ�—�紝杩欐�‚��‡�˜�‚��ƒ��‚�?, true)
		if level_num >= 2:
			_start_assault("right_window", _window_pressure(6.0 + current_level_index * 0.6), 64.0, "需要处理"generator"]["pressure"] = _generator_pressure(1.8 + current_level_index * 0.25)
		if level_num >= 4:
			_start_antenna_trouble(_antenna_pressure(1.25 + current_level_index * 0.18), 64.0, "需要处理"hard_push_antenna")
		_add_log("")ate_push", 999.0) and not bool(events_done.get("late_push", false)):
		events_done["late_push"] = true
		_apply_late_pressure_wave("需要处理"final_pressure", 999.0) and not bool(events_done.get("final_pressure", false)):
		events_done["final_pressure"] = true
		_apply_late_pressure_wave("澶�•�揩�œ�†�墠�™�ˆ�‚�屾渶�š�‰紝�Ž��‚��ˆ�‰�‰�–��•Œ�…��–��’��‰�‘��Š��—�Ž�嬨�‚�?, true)
	if night_elapsed >= _schedule_time("final_wave", 999.0) and level_num >= 10 and not bool(events_done.get("final_wave", false)):
		events_done["final_wave"] = true
		for id in _barrier_ids():
			_start_assault(id, _door_pressure(7.4 + current_level_index * 0.45) if id == "front_door" or id == "back_door" else _window_pressure(7.0 + current_level_index * 0.45), 64.0, "%s�š�‚�渶�š庝竴�‰�ˆ��•��‘�š�€Š浣�‹�‚�? % str(hotspots[id].get("name", id)), true)
		hotspots["generator"]["pressure"] = max(float(hotspots["generator"].get("pressure", 0.0)), _generator_pressure(2.4 + current_level_index * 0.25))
		_start_antenna_trouble(_antenna_pressure(1.9 + current_level_index * 0.18), 48.0, "需要处理"final_wave_antenna")
	_run_director()

func _apply_late_pressure_wave(text: String, force_pair: bool = false) -> void:
	var available_barriers: Array[String] = []
	for id in _barrier_ids():
		if not _hotspot_unlocked(id):
			continue
		var data: Dictionary = hotspots[id]
		if bool(data.get("assault", false)) or float(data.get("breach_timer", -1.0)) >= 0.0:
			continue
		if float(data.get("temp_seal", 0.0)) > 0.0:
			continue
		available_barriers.append(id)
	available_barriers.shuffle()
	var count := 1
	if force_pair or _level_number() >= 4:
		count = 2
	for i in range(min(count, available_barriers.size())):
		var id := available_barriers[i]
		var pressure := _door_pressure(5.2 + current_level_index * 0.42) if id == "front_door" or id == "back_door" else _window_pressure(5.0 + current_level_index * 0.42)
		_start_assault(id, pressure, 66.0, "%s鍦�„�粠�„庡墠�™堣椤�œ��‡�Š†? % str(hotspots[id].get("name", id)), true)
	if _hotspot_unlocked("generator"):
		hotspots["generator"]["active"] = true
		hotspots["generator"]["pressure"] = max(float(hotspots["generator"].get("pressure", 0.0)), _generator_pressure(1.35 + current_level_index * 0.18))
		hotspots["generator"]["value"] = min(float(hotspots["generator"].get("value", 100.0)), 72.0)
	if _hotspot_unlocked("antenna") and _level_number() >= 4:
		_start_antenna_trouble(_antenna_pressure(1.05 + current_level_index * 0.12), 72.0, "澶�•ƒ�šŽ�‡�€�彿鍦�„�粠�„庡墠�š�‚��—“�˜嬩�†�Š†?, "late_signal_%d" % int(night_elapsed))
	_add_log(text)

func _run_rhythm_tick() -> void:
	if phase != "night":
		return
	if night_elapsed < next_rhythm_time:
		return
	if night_elapsed >= _night_duration() - 3.0:
		return
	var tick_index := int(floor(night_elapsed / RHYTHM_TICK_INTERVAL))
	rhythm_tick_count = max(rhythm_tick_count, tick_index)
	next_rhythm_time = float(tick_index + 1) * RHYTHM_TICK_INTERVAL
	var crisis_cap := _director_crisis_cap()
	var crisis_count := _current_crisis_count()
	if crisis_count >= crisis_cap:
		_apply_rhythm_breath_tick()
		return
	if _rhythm_should_add_pressure(tick_index, crisis_count):
		var target := _rhythm_pick_target()
		if target != "":
			_apply_rhythm_pressure(target)
			rhythm_pressure_count += 1
			last_rhythm_target = target
			last_rhythm_kind = "pressure"
			return
	if _rhythm_should_hint_schedule(tick_index):
		_apply_rhythm_schedule_hint()
		return
	_apply_rhythm_breath_tick()

func _rhythm_should_add_pressure(tick_index: int, crisis_count: int) -> bool:
	var quiet_skip := 2 if bool(upgrades.get("quiet_hours", false)) else 0
	if tick_index < 2 + quiet_skip:
		return false
	if rhythm_pressure_count >= _rhythm_pressure_limit():
		return false
	if crisis_count >= max(1, _director_crisis_cap() - 1) and tick_index % 4 != 0:
		return false
	var cadence := 3 if _level_number() <= 2 else 2
	if tick_index % cadence != 0:
		return false
	return true

func _rhythm_pressure_limit() -> int:
	match _level_number():
		1:
			return 3
		2:
			return 4
		3, 4:
			return 5
		5, 6, 7:
			return 6
		_:
			return 7

func _rhythm_pick_target() -> String:
	var candidates: Array[String] = []
	for id in ["front_door", "left_window", "right_window", "back_door", "generator", "antenna", "medbay", "storage"]:
		if not _hotspot_unlocked(id):
			continue
		if id == player_target_id or id == last_rhythm_target:
			continue
		if not hotspots.has(id):
			continue
		var data: Dictionary = hotspots[id]
		var kind := str(data.get("kind", ""))
		var value := float(data.get("value", 100.0))
		if value < 42.0:
			continue
		if float(data.get("temp_seal", 0.0)) > 0.0:
			continue
		if kind == "barrier" and (bool(data.get("assault", false)) or float(data.get("breach_timer", -1.0)) >= 0.0):
			continue
		if kind == "generator" and blackout:
			continue
		if kind == "support" and bool(data.get("active", false)):
			continue
		if kind == "antenna" and bool(data.get("active", false)) and value < 72.0:
			continue
		candidates.append(id)
	if candidates.is_empty():
		return ""
	return candidates[night_rng.randi_range(0, candidates.size() - 1)]

func _apply_rhythm_pressure(id: String) -> void:
	if not hotspots.has(id):
		return
	var data: Dictionary = hotspots[id]
	var kind := str(data.get("kind", ""))
	if kind == "generator":
		data["active"] = true
		data["braced"] = false
		data["pressure"] = max(float(data.get("pressure", 0.0)), _generator_pressure(0.55 + current_level_index * 0.12))
		data["value"] = max(0.0, float(data.get("value", 100.0)) - _roll_time(3.0, 6.0))
		hotspots[id] = data
		_play_sfx("warning", -3.0)
		_add_log("")ntenna":
		data["active"] = true
		data["warning"] = true
		data["pressure"] = max(float(data.get("pressure", 0.0)), _antenna_pressure(0.62 + current_level_index * 0.10))
		data["value"] = max(0.0, float(data.get("value", 100.0)) - _roll_time(4.0, 7.0))
		hotspots[id] = data
		_play_sfx("antenna", -4.0)
		_add_log("")upport":
		data["active"] = true
		data["warning"] = true
		data["pressure"] = max(float(data.get("pressure", 0.0)), 0.45 + current_level_index * 0.06)
		data["value"] = max(0.0, float(data.get("value", 100.0)) - _roll_time(3.0, 6.0))
		hotspots[id] = data
		_play_sfx("support", -4.0)
		_add_log("%s�–��ˆ�Ÿ�ˆ�‰�‰�˜嬩�†澹伴�…�鍠婁簡�“�‚��™�ƒ�紝�—‡�‚��‘•佹�Š�Œ�™��…�“�‚�鐪笺�‚�? % str(data.get("name", id)))
		return
	data["active"] = true
	data["warning"] = true
	data["braced"] = false
	data["pressure"] = max(float(data.get("pressure", 0.0)), _rhythm_barrier_pressure(id))
	data["value"] = max(0.0, float(data.get("value", 100.0)) - _roll_time(1.5, 4.0))
	hotspots[id] = data
	_play_sfx("warning", -4.0)
	_add_log("%s澶栨湁褰�ž�“™�’��‹�Ž�”›�ƒ�•�Œ�„ƒ�Œ’�“婏紝浣�——０�—Š�†��‡�缁�“�ŸŒ�œ�—��‚�? % str(data.get("name", id)))

func _rhythm_barrier_pressure(id: String) -> float:
	if id == "front_door" or id == "back_door":
		return _door_pressure(1.35 + current_level_index * 0.18)
	return _window_pressure(1.45 + current_level_index * 0.18)

func _rhythm_should_hint_schedule(tick_index: int) -> bool:
	if tick_index % 2 == 0:
		return true
	return false

func _apply_rhythm_schedule_hint() -> void:
	last_rhythm_kind = "hint"
	var next_id := _next_scheduled_event_id()
	if next_id != "":
		_add_log(_rhythm_schedule_hint_text(next_id))
		return
	_apply_rhythm_breath_tick()

func _next_scheduled_event_id() -> String:
	var best_id := ""
	var best_time := INF
	for key in night_schedule.keys():
		var id := str(key)
		if bool(events_done.get(id, false)):
			continue
		if id.ends_with("_warning") and bool(events_done.get(id, false)):
			continue
		var event_time := float(night_schedule[key])
		if event_time <= night_elapsed or event_time - night_elapsed > 12.0:
			continue
		if event_time < best_time:
			best_time = event_time
			best_id = id
	return best_id

func _rhythm_schedule_hint_text(id: String) -> String:
	if id.find("radio_call") == 0:
		return "鐢�›彴搴�›ž�”�–�屾湁�‘™�‹�緥鐨�‹��–澹帮紝鍍�”湁�œ�“„揩�‘•佹帴杩�ˆ��•��ˆ�‚��‚�?
	if id.find("generator") == 0:
		return "需要处理"antenna") == 0:
		return "需要处理"window") >= 0:
		return "绐�€�˜�鐨�‹��‰�姝�ƒ�０缁�›š簡�“�‚�鍦堬紝鍍�“湪�Ž��‚��—�”�„��‘�ˆ�„��˜�Š†?
	if id.find("door") >= 0:
		return "需要处理"medbay") >= 0:
		return "需要处理"storage") >= 0:
		return "需要处理"鏁�‘�‡浣�’��›棣�—™�…��†�‚š�•��—ˆ�Ž�…�‰�ƒ�紝�™�ˆ�‚�屾洿鍍�”�š�‹庡墠鐨�‹��”–�—…欍�‚�?

func _apply_rhythm_breath_tick() -> void:
	last_rhythm_kind = "breath"
	var options: Array[String] = [
		"鐪嬪彴�“嬫湁�œ�“„�†浣�“�‡��š革紝�›�‰�˜�’�‚†�Ÿ‡�“嬩竴姝�ƒ��‚�?,
		"杩�ƒ�˜�浼�Š�潵�“�‚��—ƒ�ž��‹�›屽０�”›屽緢�‡�‚�張�š�‚��—“�š�‚��€�Š†?,
		"鐏�ˆ��•�œ�†��ƒ�”›屼絾姣�Ž�‡œ�œ洪�…˜鍦�„��ƒ‰�—‚�„��˜�鐨�‹�棿�—…�–��‚�?,
		"Nora �Ž��‚�簡�“�‚�鐪�‚�獥�ˆ�™�紝Elias 鐩�ˆœ�ƒ鐢�›彴�‰�ˆ��ˆ��Š†?
	]
	if _level_number() < 3:
		options = [
			"鐪嬪彴�“嬫湁�œ�“„�†浣�“�‡��š革紝�›�‰�˜�’�‚†�Ÿ‡�“嬩竴姝�ƒ��‚�?,
			"需要处理"鐏�ˆ��•�œ�†��ƒ�”›屼絾姣�Ž�‡œ�œ洪�…˜鍦�„��ƒ‰�—‚�„��˜�鐨�‹�棿�—…�–��‚�?
		]
	if _current_crisis_count() >= _director_crisis_cap():
		options = [
			"杩�Ž竴�—ƒ�›�‡�缁�“�™„�”�†‹紝鍏�Ÿ妸鐪�…Ž墠�œ�†��ƒ鐨�‹�偣�˜嬩�…�˜�‡�‚�?,
			"澹伴�…�鍏�„��‹鍦�„�竴�’��‡�紝�Š�‚�彮�™板彧�“�•€�…�ˆ�‚�杩�ˆ��‘�—遍�“�Š†?,
			"浣�’��›棣�—˜�—…�ˆ�Š�•€娣�˜�ŸŠ澹帮紝缁�Ž�˜�‘�Š��—�Ž��‚�œ��—ˆ�ˆ�嫿鍥�‚�潵�Š†?
		]
	_add_log(options[night_rng.randi_range(0, options.size() - 1)])

func _run_story_beats() -> void:
	var beats: Array = _level().get("story_beats", []) as Array
	for index in range(beats.size()):
		var beat := beats[index] as Dictionary
		var id := str(beat.get("id", str(index)))
		var event_id := "story_%s" % id
		if bool(events_done.get(event_id, false)):
			continue
		var at_ratio := clampf(float(beat.get("at_ratio", 0.0)), 0.0, 1.0)
		if night_elapsed < _night_duration() * at_ratio:
			continue
		events_done[event_id] = true
		_play_sfx("story")
		for line in _story_lines(beat.get("text", "")):
			_add_log(line)

func _warn_barrier(id: String, text: String) -> void:
	if not _hotspot_unlocked(id):
		return
	events_done["%s_warning" % id] = true
	hotspots[id]["warning"] = true
	hotspots[id]["active"] = true
	hotspots[id]["braced"] = false
	_play_sfx("warning")
	_add_log(text)

func _start_assault(id: String, pressure: float, value_cap: float, text: String, force: bool = false) -> void:
	if not _hotspot_unlocked(id):
		return
	events_done[id] = true
	if not force and bool(hotspots[id].get("braced", false)):
		hotspots[id]["warning"] = false
		hotspots[id]["assault"] = false
		hotspots[id]["pressure"] = 0.0
		_add_log("%s�Ž��„�墠椤�œ��‡�œ�—�紝杩欐�‚�鍐�’�š��Œ¤�…˜�Ž��‚��‘�Š†? % str(hotspots[id].get("name", id)))
		return
	hotspots[id]["active"] = true
	hotspots[id]["warning"] = false
	hotspots[id]["assault"] = true
	hotspots[id]["braced"] = false
	hotspots[id]["pressure"] = max(float(hotspots[id].get("pressure", 0.0)), pressure)
	hotspots[id]["value"] = min(float(hotspots[id].get("value", 100.0)), value_cap)
	_play_sfx("door_hit" if id == "front_door" or id == "back_door" else "window_hit")
	_add_log(text)

func _start_antenna_trouble(pressure: float, value_cap: float, text: String, event_id: String) -> void:
	if not _hotspot_unlocked("antenna"):
		return
	events_done[event_id] = true
	hotspots["antenna"]["active"] = true
	hotspots["antenna"]["warning"] = true
	hotspots["antenna"]["pressure"] = max(float(hotspots["antenna"].get("pressure", 0.0)), pressure)
	hotspots["antenna"]["value"] = min(float(hotspots["antenna"].get("value", 100.0)), value_cap)
	_play_sfx("antenna")
	_add_log(text)

func _start_support_trouble(id: String, pressure: float, value_cap: float, text: String, event_id: String) -> void:
	if not _hotspot_unlocked(id):
		return
	events_done[event_id] = true
	if id == "medbay" and bool(upgrades.get("medbay_lamp", false)):
		pressure *= 0.65
		value_cap = min(value_cap + 12.0, 100.0)
	hotspots[id]["active"] = true
	hotspots[id]["warning"] = true
	hotspots[id]["pressure"] = max(float(hotspots[id].get("pressure", 0.0)), pressure)
	hotspots[id]["value"] = min(float(hotspots[id].get("value", 100.0)), value_cap)
	_play_sfx("support")
	_add_log(text)

func _apply_temp_seal(id: String, duration: float) -> void:
	if not hotspots.has(id):
		return
	hotspots[id]["temp_seal"] = duration
	hotspots[id]["warning"] = false
	hotspots[id]["breach_timer"] = -1.0

func _start_radio_call(text: String) -> void:
	if not bool(events_done.get("radio_call", false)):
		events_done["radio_call"] = true
	radio_available = true
	radio_completed = false
	radio_missed = false
	radio_call_started_at = night_elapsed
	hotspots["radio"]["active"] = true
	hotspots["radio"]["value"] = 0.0
	_play_sfx("radio_call")
	_add_log(text)

func _radio_should_timeout() -> bool:
	if not radio_available or radio_completed or radio_missed:
		return false
	var call_start := radio_call_started_at
	if call_start < 0.0:
		call_start = _schedule_time("radio_call", 28.0 if _level_number() >= 3 else 45.0)
	var window := 20.0 if _level_number() >= 3 else 27.0
	if _level_number() >= 4:
		window = 18.0
	if bool(upgrades.get("radio_booster", false)):
		window += 12.0
	if bool(upgrades.get("antenna_anchor", false)):
		window += 5.0
	return night_elapsed >= call_start + window

func _update_player(delta: float) -> void:
	player_pos = _move_actor_along_route(player_pos, player_route, player_target_pos, _player_speed() * delta)
	if player_target_id == "":
		return
	if player_pos.distance_to(player_target_pos) > ACTOR_ARRIVE_DISTANCE:
		return
	_work_on_hotspot(player_target_id, _player_work_rate(), delta)

func _update_nora(delta: float) -> void:
	if not bool(allies.get("nora", false)):
		return
	_tick_target_cooldowns(nora_target_cooldowns, delta)
	nora_commit_time = max(0.0, nora_commit_time - delta)
	var current_done := _helper_target_finished(nora_target_id)
	if current_done and nora_target_id != "":
		nora_target_cooldowns[nora_target_id] = HELPER_TARGET_COOLDOWN
	if nora_commit_time <= 0.0 or nora_target_id == "" or current_done:
		var desired := _window_needing_help()
		if not _helper_candidate_allowed(desired, nora_target_cooldowns):
			desired = ""
		if desired != nora_target_id:
			_set_nora_target(desired)
	nora_pos = _move_actor_along_route(nora_pos, nora_route, nora_target_pos, NORA_SPEED * delta)
	if nora_target_id != "" and nora_pos.distance_to(nora_target_pos) <= ACTOR_ARRIVE_DISTANCE:
		_work_on_hotspot(nora_target_id, _nora_work_rate(), delta)

func _update_elias(delta: float) -> void:
	if not bool(allies.get("elias", false)):
		return
	_tick_target_cooldowns(elias_target_cooldowns, delta)
	elias_commit_time = max(0.0, elias_commit_time - delta)
	var current_done := _helper_target_finished(elias_target_id)
	if current_done and elias_target_id != "":
		elias_target_cooldowns[elias_target_id] = HELPER_TARGET_COOLDOWN
	if elias_commit_time <= 0.0 or elias_target_id == "" or current_done:
		var desired := _elias_needing_help()
		if not _helper_candidate_allowed(desired, elias_target_cooldowns):
			desired = ""
		if desired != elias_target_id:
			_set_elias_target(desired)
	elias_pos = _move_actor_along_route(elias_pos, elias_route, elias_target_pos, ELIAS_SPEED * delta)
	if elias_target_id != "" and elias_pos.distance_to(elias_target_pos) <= ACTOR_ARRIVE_DISTANCE:
		_work_on_hotspot(elias_target_id, _elias_work_rate(), delta)

func _elias_needing_help() -> String:
	return NightShiftActors.elias_needing_help(hotspots, _hotspot_unlocked, player_target_id, radio_available, radio_completed, blackout, _antenna_signal_low(), upgrades)

func _window_needing_help() -> String:
	if _hotspot_unlocked("medbay") and player_target_id != "medbay":
		var medbay: Dictionary = hotspots["medbay"]
		if bool(medbay.get("active", false)) and float(medbay.get("value", 100.0)) < 40.0:
			return "medbay"
	return NightShiftActors.window_needing_help(hotspots, _hotspot_unlocked, player_target_id)

func _set_nora_target(id: String) -> void:
	nora_target_id = id
	if id == "":
		nora_target_pos = NORA_HOME
		nora_route = _route_to_position(nora_pos, nora_target_pos)
		nora_commit_time = 0.0
		return
	nora_target_pos = hotspots[id]["work_position"] as Vector2
	nora_route = _route_to_hotspot(id, nora_pos)
	nora_commit_time = HELPER_COMMIT_DURATION

func _set_elias_target(id: String) -> void:
	elias_target_id = id
	if id == "":
		elias_target_pos = ELIAS_HOME
		elias_route = _route_to_position(elias_pos, elias_target_pos)
		elias_commit_time = 0.0
		return
	elias_target_pos = hotspots[id]["work_position"] as Vector2
	elias_route = _route_to_hotspot(id, elias_pos)
	elias_commit_time = HELPER_COMMIT_DURATION

func _tick_target_cooldowns(cooldowns: Dictionary, delta: float) -> void:
	for id in cooldowns.keys():
		var remaining := float(cooldowns.get(id, 0.0)) - delta
		if remaining <= 0.0:
			cooldowns.erase(id)
		else:
			cooldowns[id] = remaining

func _helper_candidate_allowed(id: String, cooldowns: Dictionary) -> bool:
	if id == "":
		return true
	if not hotspots.has(id) or not _hotspot_unlocked(id):
		return false
	if cooldowns.has(id) and not _helper_target_in_crisis(id):
		return false
	return true

func _helper_target_finished(id: String) -> bool:
	if id == "" or not hotspots.has(id) or not _hotspot_unlocked(id):
		return true
	var data: Dictionary = hotspots[id]
	var kind := str(data.get("kind", ""))
	var value := float(data.get("value", 0.0))
	if kind == "barrier":
		return not bool(data.get("active", false)) and not bool(data.get("warning", false)) and not bool(data.get("assault", false)) and float(data.get("breach_timer", -1.0)) < 0.0 and value >= min(_max_value(id), _brace_threshold(id))
	if kind == "generator":
		return not blackout and not bool(data.get("active", false)) and value >= 82.0
	if kind == "radio":
		return not radio_available or radio_completed
	if kind == "antenna":
		return not bool(data.get("active", false)) and value >= 70.0
	if kind == "support":
		return not bool(data.get("active", false)) and not bool(data.get("warning", false)) and value >= 76.0
	return false

func _helper_target_in_crisis(id: String) -> bool:
	if id == "" or not hotspots.has(id):
		return false
	var data: Dictionary = hotspots[id]
	var kind := str(data.get("kind", ""))
	var value := float(data.get("value", 100.0))
	if kind == "barrier":
		return bool(data.get("assault", false)) or float(data.get("breach_timer", -1.0)) >= 0.0 or value < 35.0
	if kind == "generator":
		return blackout or value < 35.0
	if kind == "radio":
		return radio_available and not radio_completed
	if kind == "antenna":
		return value < 40.0
	if kind == "support":
		return value < 35.0
	return false

func _work_on_hotspot(id: String, rate: float, delta: float) -> void:
	if not hotspots.has(id):
		return
	var data: Dictionary = hotspots[id]
	var kind := str(data.get("kind", ""))
	if kind == "radio":
		if not radio_available or blackout or radio_completed:
			return
		if _antenna_signal_low():
			return
		var radio_rate := rate * (1.05 if bool(upgrades.get("radio_booster", false)) else 0.92)
		data["value"] = min(100.0, float(data.get("value", 0.0)) + radio_rate * delta)
		if float(data.get("value", 0.0)) >= 100.0:
			_complete_radio_call()
	else:
		if kind == "barrier" and bool(data.get("assault", false)) and float(data.get("temp_seal", 0.0)) <= 0.0:
			data["temp_seal"] = _temp_seal_duration()
			data["warning"] = false
			data["breach_timer"] = -1.0
			_add_log("%s�š�‚�复�ƒ跺�š�浣忥紝�‘��Š��‹��“�‚�灏�Ž細�Ž裤�‚�? % str(data.get("name", id)))
		if kind != "antenna":
			data["value"] = min(_max_value(id), float(data.get("value", 0.0)) + rate * delta)
		if kind == "barrier" and bool(data.get("warning", false)) and not bool(data.get("assault", false)) and float(data.get("value", 0.0)) >= _brace_threshold(id):
			data = _brace_warning(id, data)
		if kind == "barrier" and (bool(data.get("assault", false)) or float(data.get("breach_timer", -1.0)) >= 0.0) and float(data.get("value", 0.0)) >= _brace_threshold(id):
			data["active"] = false
			data["warning"] = false
			data["assault"] = false
			data["braced"] = true
			data["pressure"] = 0.0
			data["temp_seal"] = 0.0
			data["breach_timer"] = -1.0
			_add_log("%s�š�‚�交搴�›��€Š鍥�‚��“�”›屾殏�ƒ�œ��‰鐢�„��•€鐩�ˆ˜�‚�? % str(data.get("name", id)))
		if kind == "barrier" and float(data.get("value", 0.0)) > 24.0:
			data["breach_timer"] = -1.0
		if kind == "antenna":
			var antenna_rate := 1.08 if bool(upgrades.get("cable_route", false)) else 0.86
			data["value"] = min(_max_value(id), float(data.get("value", 0.0)) + rate * antenna_rate * delta)
			data["signal_lost_logged"] = false
			if float(data.get("value", 0.0)) >= 88.0:
				data["active"] = false
				data["warning"] = false
				data["pressure"] = 0.0
		if kind == "support":
			var support_rate := rate * (1.2 if bool(upgrades.get("victor_cache", false) and id == "storage") else 1.0)
			data["value"] = min(_max_value(id), float(data.get("value", 0.0)) + support_rate * delta)
			if float(data.get("value", 0.0)) >= 92.0:
				data["active"] = false
				data["warning"] = false
				data["pressure"] = 0.0
	hotspots[id] = data

func _brace_warning(id: String, data: Dictionary) -> Dictionary:
	data["warning"] = false
	data["braced"] = true
	data["pressure"] = 0.0
	data["breach_timer"] = -1.0
	if id != "front_door" and id != "back_door":
		data["active"] = false
	_add_log("%s�š�‚�彁�“�…�ž鍥�Œ�紝澶栭潰鐨�‹��Œ’�‘�˜殏�ƒ跺�‡�“嬪�“�œ�—��‚�? % str(data.get("name", id)))
	return data

func _brace_threshold(id: String) -> float:
	if id == "front_door" or id == "back_door":
		return min(_max_value(id), 96.0)
	return min(_max_value(id), 94.0)

func _complete_radio_call() -> void:
	if radio_completed:
		return
	radio_completed = true
	radio_available = false
	radio_contacts_done += 1
	hotspots["radio"]["active"] = false
	_check_achievements()
	_play_sfx("radio_connect")
	if _level_number() == 1 and not bool(allies.get("nora", false)):
		allies["nora"] = true
		_reset_nora_home_state()
		_add_log("")
	elif _level_number() == 3 and not bool(allies.get("elias", false)):
		allies["elias"] = true
		_add_log("")
		_add_log("")�›彴�Ž��ƒ��‚�氫簡�”›屽�˜��—ˆ�ˆ��•�ˆ�‰�‰�š�„€緱�‘™佽�–�–�屻�‚�?)

func _update_hotspots(delta: float) -> void:
	plank_cooldown = max(0.0, plank_cooldown - delta)
	var barrier_multiplier := _blackout_barrier_multiplier() if blackout else 1.0
	for id in hotspots.keys():
		if not _hotspot_unlocked(str(id)):
			continue
		var data: Dictionary = hotspots[id]
		var kind := str(data.get("kind", ""))
		if float(data.get("temp_seal", 0.0)) > 0.0:
			data["temp_seal"] = max(0.0, float(data.get("temp_seal", 0.0)) - delta)
		if kind == "barrier" and bool(data.get("active", false)):
			var seal_multiplier := 0.12 if float(data.get("temp_seal", 0.0)) > 0.0 else 1.0
			var assault_multiplier := 1.65 if bool(data.get("assault", false)) else 0.38
			data["value"] = max(0.0, float(data.get("value", 0.0)) - float(data.get("pressure", 0.0)) * barrier_multiplier * assault_multiplier * seal_multiplier * delta)
			if float(data.get("value", 0.0)) <= 0.0:
				data["breach_timer"] = max(0.0, float(data.get("breach_timer", -1.0))) + delta
		elif kind == "generator" and bool(data.get("active", false)):
			data["value"] = max(0.0, float(data.get("value", 0.0)) - float(data.get("pressure", 0.0)) * delta)
		elif kind == "antenna" and bool(data.get("active", false)):
			var blackout_signal_multiplier := 1.75 if blackout and not bool(upgrades.get("signal_battery", false)) else 1.0
			data["value"] = max(0.0, float(data.get("value", 0.0)) - float(data.get("pressure", 0.0)) * blackout_signal_multiplier * delta)
			if float(data.get("value", 0.0)) <= 0.0 and not bool(data.get("signal_lost_logged", false)):
				data["signal_lost_logged"] = true
				_add_log("")
		elif kind == "support" and bool(data.get("active", false)):
			data["value"] = max(0.0, float(data.get("value", 0.0)) - float(data.get("pressure", 0.0)) * delta)
		hotspots[id] = data
	var generator_value := float(hotspots["generator"].get("value", 0.0))
	if generator_value <= 0.0 and not blackout:
		blackout = true
		_play_sfx("blackout")
		_add_log("")
		_play_sfx("power_restore")
		_add_log("")reach_timer", -1.0)) >= BREACH_GRACE:
			_finish_night(false, "%s�š�‚��Œ’寮�‚��”›屽�•�澶�ƒ�‘�’��ƒ��‚�? % str(data.get("name", id)))
			return
	if night_elapsed >= _night_duration():
		_finish_night(true, "澶�•€�’�œ�—��‚��‚ž棬杩樺湪�”›�€�•��™�‹Œ�•�œ�†��ƒ�Š†?)

func _finish_night(success: bool, body: String) -> void:
	if phase != "night":
		return
	if success and _level_number() == 1 and not bool(allies.get("nora", false)):
		allies["nora"] = true
		_add_log("")
	phase = "report"
	last_night_success = success
	outcome = "success" if success else "failure"
	_play_sfx("success" if success else "failure")
	_check_achievements()
	_add_log(_first_line(report_body))
	_show_report(success, report_body)

func _show_report(success: bool, body: String) -> void:
	result_panel.visible = true
	game_paused = false
	if pause_overlay != null:
		pause_overlay.visible = false
	result_title.text = "需要处理"�—?%d 澶�ƒ�‘�€�? % _level_number()
	var additions: Array[String] = [body]
	if not _has_story_report(success):
		if success and _level_number() == 1 and bool(allies.get("nora", false)):
			additions.append("Nora 鐣�Ž簡�“嬫潵�Š†�‚™箣�š庡�‚�浼氳�šœ�”�„��…��ˆ�‚��—遍�“鐨�‹�獥�Š†?)
		if success and _level_number() == 2:
			additions.append("需要处理"elias", false)):
			additions.append("Elias 灏�——湪�š庣�”�澶�„�„�—�“姪鐢�›彴�Š†?)
		if success and _level_number() == 4:
			additions.append("需要处理"�—�ƒ�簲澶�€�’�š庯紝�ƒ�‚�‹�‘��Ÿ��›��“�…�•€�™�…槸�“�˜�‚�–��—毦鐐�™�紝�‘�屾槸�“�‚�搴�†�…˜鍥�‚�簲姹�‚›�™�鐨�‹�嵁鐐广�‚�?)
		if success and _level_number() == 6:
			additions.append("鍣�„��—�–�氶亾�€��œ�‡�œ�—�紝�š庨棬浠庢紡娲�‚��‰�Ž��„�簡�—�ƒ�簩�–��’�槻绾裤�‚�?)
		if success and _level_number() == 7:
			additions.append("需要处理"�ˆ�„��˜�“�…�™„鐢�Ÿ’紝浣�—•�˜浠�„�妸姣�Ž竴鍧�…�…˜鐢�„�湪�œ�—š�‡š鐢�„��‘鍦�‰ˆ�ŸŸ�Š†?)
		if success and _level_number() == 9:
			additions.append("鐢�›�‹��‡�€�彿�Œ�„ƒ湁�“�‚��’��”‹�Ÿ‡�Ž��›紝Elias 缁�œ簬�‰句簡�™�†�š��Š†?)
		if success and _level_number() == 10:
			additions.append("需要处理"\n".join(additions)
	result_body.text = result_text
	_refresh_audio_state()
	_rebuild_result_buttons(success)
	result_panel.modulate = Color(1, 1, 1, 0)
	transition_overlay.color.a = 0.0
	var report_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	report_tween.tween_property(result_panel, "modulate:a", 1.0, 0.35)

func _story_report_text(success: bool, fallback: String) -> String:
	var key := "success_report" if success else "failure_report"
	var text := str(_level().get(key, ""))
	if text == "":
		return fallback
	if success:
		return text
	return "%s\n%s" % [text, fallback]

func _has_story_report(success: bool) -> bool:
	var key := "success_report" if success else "failure_report"
	return str(_level().get(key, "")) != ""

func _rebuild_result_second_page() -> void:
	if result_panel == null:
		return
	var additions := []
	var level_num := _level_number()
	if success and level_num == 10:
		additions.append("需要处理"澶�•€�’�š庨棬�‚�‹�™�澶�œ��ƒ�“�‚�寮�Š��„Š�”›屼�‚�—ˆ�ˆ��•��œ�—•竴�‰�€��š�“�…�‘�’��ˆœ�šŽ�Š†�‚›�—…�ˆ�Œ讲�š�ƒ�‚�?)
	elif success and level_num >= 4:
		additions.append("需要处理"澶�•€�’�ƒ�œ�竴�’�›��•��—ˆ欍�‚��‚™�˜杩樺湪杩�“�™��”›�€�•��™�‹Œ�•�œ�†��ƒ�Š†?)
	elif not success:
		additions.append("鐏�ˆœ�ƒ�š庡緢�”�’ƒ紝�ˆ�‰�‰鍦�„�粦�†椾�…‘�Ž�稿�ŸŒ�œ�—™�•��™�‰��‘�ƒ嬮�Œ��Š†�‚š�•��Œ�„ƒ湁鍐�…搷杩�›��‚�?)
	if int(radio_contacts_done) > 0:
		additions.append("澶栭�„�棰�ˆ�亾�ˆ�‚��š庝竴�†�„ƒ洿�‚帮細�“�ƒ�‚œ棰�ˆ�巼杩樻湁�“�Œ�€鐏�ˆ™�’鐫�‚��Š†?)
	if not additions.is_empty():
		result_page_2_text = "\n".join(additions)
	else:
		result_page_2_text = ""

func _rebuild_result_buttons(success: bool) -> void:
	for child in result_button_box.get_children():
		child.queue_free()
	var primary := Button.new()
	primary.custom_minimum_size = Vector2(168, 42)
	if success:
		primary.text = "缁�…�”�"
		primary.pressed.connect(_continue_from_report)
	var page2_btn := Button.new()
	page2_btn.text = "需要处理"" and result_on_page_2 == false:
			result_on_page_2 = true
			result_body.text = result_page_2_text
		else:
			result_on_page_2 = false
			result_body.text = result_text
	)
	_rebuild_result_second_page()
	if result_page_2_text != "" and not success:
		page2_btn.visible = true
	result_button_box.add_child(page2_btn)
	var page1_label := Label.new()
	page1_label.text = "1/2" if result_page_2_text != "" else ""
	page1_label.add_theme_font_size_override("font_size", 11)
	page1_label.add_theme_color_override("font_color", Color(0.50, 0.60, 0.58, 0.70))
	page2_btn.add_child(page1_label)
	if result_page_2_text != "" and success:
		result_body.text = result_text + "\n\n-- " + result_page_2_text
	else:
		primary.text = "需要处理"
	primary.pressed.connect(func() -> void: _start_night())
	_style_day_choice_button(primary, false)
	result_button_box.add_child(primary)
var restart := Button.new()
restart.text = "需要处理"
restart.custom_minimum_size = Vector2(126, 42)
_style_day_choice_button(restart, false)
restart.pressed.connect(func() -> void:
		_reset_campaign()
		_enter_day(0)
	)
	result_button_box.add_child(restart)

func _continue_from_report() -> bool:
	if phase != "report":
		return false
	if not last_night_success:
		_start_night()
		return true
	if current_level_index + 1 >= NightShiftLevels.count():
		_show_final()
	else:
		_enter_day(current_level_index + 1)
	return true

func _show_final() -> void:
	phase = "final"
	game_over = true
	outcome = "campaign_success"
	result_panel.visible = true
	day_panel.visible = false
	result_title.text = "需要处理"
	result_text = "需要处理"�–��†�ŸŠ寮�‚�濮?
	restart.custom_minimum_size = Vector2(168, 42)
	restart.pressed.connect(func() -> void:
		_reset_campaign()
		_enter_day(0)
	)
	result_button_box.add_child(restart)
	_refresh_ui()

func _refresh_ui() -> void:
	if timer_label == null:
		return
	for node in hud_nodes:
		node.visible = phase != "cover"
	if phase == "cover":
		timer_label.text = "灏�€潰  �ƒ�‚�‹�‘��Ÿ��›��€�堝�™�"
	elif phase == "night":
		var remaining: float = max(0.0, _night_duration() - night_elapsed)
		var story_seconds := int(round(remaining / max(1.0, _night_duration()) * 8.0 * 60.0 * 60.0))
		timer_label.text = "需要处理" % [_level_number(), int(story_seconds / 3600), int((story_seconds % 3600) / 60)]
	elif phase == "day":
		timer_label.text = "需要处理" % _level_number()
	else:
		timer_label.text = "需要处理"\n".join(logs.slice(max(0, logs.size() - 8), logs.size()))
	_sync_hotspot_controls()
	_sync_hotspot_labels()
	_sync_plank_button()
	_sync_speed_button()
	if first_hint_label != null:
		var hint_visible := phase == "night" and not first_door_hint_done and night_elapsed < 14.0
		first_hint_label.visible = hint_visible
		if hint_visible:
			var pulse_alpha := sin(night_elapsed * 3.5 * TAU) * 0.5 + 0.5
			first_hint_label.modulate.a = 0.50 + 0.50 * pulse_alpha
			first_hint_label.position.y = 42.0 + sin(night_elapsed * 2.0 * TAU) * 4.0
	queue_redraw()

func _sync_hotspot_controls() -> void:
	for id in hotspot_buttons.keys():
		var button := hotspot_buttons[id] as Button
		button.visible = phase == "night" and _hotspot_unlocked(str(id))
		button.disabled = phase != "night"
		if phase == "night" and hotspot_buttons.has(id) and hotspots.has(id):
			var data: Dictionary = hotspots[id]
			var crisis := bool(data.get("assault", false)) or bool(data.get("warning", false)) or bool(data.get("active", false))
			if crisis and not button.disabled:
				var pulse := sin(night_elapsed * 3.0 * TAU) * 0.5 + 0.5
				if hotspot_buttons[id] is Button:
					var hb := hotspot_buttons[id] as Button
					var style := hb.get_theme_stylebox("hover").duplicate() as StyleBoxFlat
					if style != null:
						var alpha := 0.12 + 0.18 * pulse
						if bool(data.get("assault", false)):
							alpha = 0.20 + 0.40 * pulse
						style.bg_color = Color(0.82, 0.06, 0.0, alpha)
						style.border_color = Color(1.0, 0.38, 0.0, 0.40 + 0.40 * pulse)
						hb.add_theme_stylebox_override("normal", style)
						continue
			var normal_style := StyleBoxFlat.new()
			normal_style.bg_color = Color(0, 0, 0, 0)
			normal_style.border_color = Color(0, 0, 0, 0)
			button.add_theme_stylebox_override("normal", normal_style)
	for id in hotspot_labels.keys():
		var label := hotspot_labels[id] as Label
		label.visible = phase == "night" and _hotspot_unlocked(str(id))

func _sync_hotspot_labels() -> void:
	for id in hotspot_labels.keys():
		var label := hotspot_labels[id] as Label
		if not _hotspot_unlocked(str(id)):
			continue
		var state := _hotspot_state(str(id))
		var color := _state_color(state)
		label.add_theme_color_override("font_color", color.lightened(0.14))
		label.add_theme_font_size_override("font_size", 18 if state in ["需要处理", "需要处理"鐮�’�槻�Š�Ž•�…��ƒ?, "需要处理", "需要处理"鐢�›�‡浣?, "需要处理"�‡�€�彿寮?, "需要处理"�›�ƒ�‚�?, "需要处理"night"
	var target := _most_urgent_barrier()
	plank_button.disabled = phase != "night" or plank_cooldown > 0.0 or target == ""
	if plank_cooldown > 0.0:
		plank_button.text = "需要处理" % ceil(plank_cooldown)
	else:
		plank_button.text = "需要处理"night"
	speed_button.disabled = phase != "night"
	speed_button.text = "2x" if night_time_scale > 1.0 else "1x"

func _sync_crisis_bar() -> void:
	if crisis_bar == null or crisis_bar_bg == null:
		return
	if phase != "night":
		crisis_bar_bg.visible = false
		crisis_bar.visible = false
		return
	crisis_bar_bg.visible = true
	crisis_bar.visible = true
	var crisis_count := _current_crisis_count()
	var crisis_ratio := clampf(crisis_count / 6.0, 0.0, 1.0)
	crisis_bar.size.y = max(1.0, 76.0 * crisis_ratio)
	var pulse := sin(night_elapsed * 4.0 * TAU) * 0.5 + 0.5
	var alpha := 0.30 + crisis_ratio * 0.50 + (1.0 - crisis_ratio) * 0.20 * pulse
	crisis_bar.color = Color(0.90, 0.06, 0.0, clampf(alpha, 0.0, 0.85))

func _sync_timer_pulse() -> void:
	if timer_label == null or phase != "night":
		return
	var remaining: float = _night_duration() - night_elapsed
	if remaining <= 0.0:
		return
	var ratio := remaining / max(1.0, _night_duration())
	if ratio < 0.20:
		var pulse := sin(night_elapsed * 5.0 * TAU) * 0.5 + 0.5
		var r := 0.85 + 0.15 * pulse
		timer_label.add_theme_color_override("font_color", Color(r, 0.45 + 0.15 * pulse, 0.30 + 0.10 * pulse, 1.0))
	else:
		timer_label.add_theme_color_override("font_color", Color(0.78, 0.96, 0.94, 1.0))

func _toggle_time_scale() -> void:
	if phase != "night":
		return
	night_time_scale = 1.0 if night_time_scale > 1.0 else 2.0
	_sync_speed_button()
	_refresh_ui()

func _use_emergency_plank() -> bool:
	if phase != "night" or plank_cooldown > 0.0:
		return false
	var target := _most_urgent_barrier()
	if target == "":
		_add_log("")lank")
	_add_log("浣�Š�妸�ˆ�„��˜鐢�•��‚œ%s�”›屾殏�ƒ�ˆ��…浣�Ž簡鍐�’�š��Š†? % str(hotspots[target].get("name", target)))
	_refresh_ui()
	return true

func _debug_use_plank() -> bool:
	return _use_emergency_plank()

func _most_urgent_barrier() -> String:
	var best_id := ""
	var best_score := -999.0
	for id in _barrier_ids():
		if not _hotspot_unlocked(id):
			continue
		var data: Dictionary = hotspots[id]
		if not bool(data.get("active", false)) and not bool(data.get("warning", false)):
			continue
		var value := float(data.get("value", 100.0))
		var score := 100.0 - value
		if bool(data.get("assault", false)):
			score += 55.0
		if bool(data.get("warning", false)):
			score += 24.0
		if float(data.get("breach_timer", -1.0)) >= 0.0:
			score += 120.0
		if float(data.get("temp_seal", 0.0)) > 0.0:
			score -= 80.0
		if score > best_score:
			best_score = score
			best_id = id
	return best_id

func _current_objective() -> String:
	if phase == "cover":
		return "需要处理"day":
		return "鐧�—‰�‰�™�„�›�“�‚��“�„�–…�€�氾紝�’跺�‚—鍏�ƒ��™��Š†?
	if phase == "report":
		return "鐪嬪�™��—‚寸粨�‹滐紝鍐�†��•�缁�…�”��Ž�栭�™��’‡�›˜�‚�?
	if phase == "final":
		return "需要处理"front_door") in ["需要处理"�—遍�“", "鐮�’�槻�Š�Ž•�…��ƒ?]:
		return "姝�‰棬�‡�‚��‹��“�„�‡�œ�—�紝鍏堢偣姝�‰棬�Š†?
	if _hotspot_unlocked("back_door") and _hotspot_state("back_door") in ["鍐�’�š��“?, "需要处理"�—遍�“", "鐮�’�槻�Š�Ž•�…��ƒ?]:
		return "需要处理"�‹�…�•��œ�—�紝鐐�‘��‚鐢�ž��€�Š†?
	if _hotspot_state("left_window") in ["鍐�’�š��“?, "需要处理"�—遍�“", "鐮�’�槻�Š�Ž•�…��ƒ?]:
		return "宸︾獥鍦�„��—�”›�€偣宸︾獥�Š†?
	if _hotspot_unlocked("right_window") and _hotspot_state("right_window") in ["鍐�’�š��“?, "需要处理"�—遍�“", "鐮�’�槻�Š�Ž•�…��ƒ?]:
		return "需要处理"antenna") and _hotspot_state("antenna") in ["需要处理"�‡�€�彿�‚?, "鏍�€��™��“?]:
		return "需要处理"medbay") and _hotspot_state("medbay") in ["需要处理"�—‡�‚��‘•佸�˜��ž?]:
		return "需要处理"storage") and _hotspot_state("storage") in ["需要处理"�—‡�‚��‘•佸�˜��ž?]:
		return "需要处理"鐢�›彴�ˆ�Š�‡��™�‚�紝鐐�œ��•��™�‰ˆ帴浣�“�•��Š†?
	return "鐪嬪�‘��–�屼�’�’��”‹潵�”›屽氨�’��•��‚��‚�彮�›樿�‡杩�›��“�Š†?

func _current_action_text() -> String:
	if phase == "cover":
		return "需要处理"night":
		return "需要处理"":
		return "需要处理"name", player_target_id))
	if player_pos.distance_to(player_target_pos) <= 5.0:
		return "姝�…湪澶�‹��‚Š�”›?s" % name
	return "需要处理" % name

func _status_summary() -> String:
	if phase == "cover":
		return "需要处理"front_door", "left_window", "right_window", "back_door", "generator", "antenna", "radio", "medbay", "storage"]:
		if not _hotspot_unlocked(id):
			continue
		var data: Dictionary = hotspots[id]
		var state := _hotspot_state(id)
		if str(data.get("kind", "")) == "radio" and not radio_available and not radio_completed:
			continue
		parts.append("%s�”›?s" % [str(data.get("name", id)), state])
	if bool(allies.get("nora", false)):
		parts.append("Nora�”›氳�šœ�”�„�洴绐?)
	if bool(allies.get("elias", false)):
		parts.append("Elias�”›氱�•��™�‰ˆ妧�ˆ�ˆš�†�")
	return "\n".join(parts)

func _hotspot_state(id: String) -> String:
	if not hotspots.has(id):
		return ""
	var data: Dictionary = hotspots[id]
	var kind := str(data.get("kind", ""))
	var value := float(data.get("value", 0.0))
	if kind == "radio":
		if radio_completed:
			return "宸�‰帴�–�?
		if radio_missed:
			return "需要处理"
		if radio_available:
			return "需要处理"�—ˆ�“粯"
	if kind == "generator":
		if blackout:
			return "需要处理"
		if value < 28.0:
			return "需要处理"鐢�›�‡浣?
		if value < 82.0:
			return "需要处理"
		return "需要处理"
	if kind == "antenna":
		if value < 28.0:
			return "需要处理"�‡�€�彿寮?
		if bool(data.get("active", false)) or bool(data.get("warning", false)):
			return "鏍�€��™��“?
		return "需要处理"
	if kind == "support":
		if value < 28.0:
			return "需要处理"active", false)) or bool(data.get("warning", false)) or value < 70.0:
			return "需要处理"�‹�†��•�"
	if bool(data.get("assault", false)):
		if float(data.get("temp_seal", 0.0)) > 0.0:
			return "需要处理"
		return "鍐�’�š��“?
	if float(data.get("temp_seal", 0.0)) > 0.0:
		return "需要处理"
	if bool(data.get("braced", false)):
		return "宸�Ÿ��€Š浣?
	if bool(data.get("warning", false)):
		return "需要处理"鐮�’�槻�Š�Ž•�…��ƒ?
	if value < 28.0:
		return "需要处理"�—遍�“"
	if value < 82.0:
		return "需要处理"
	return "需要处理"

func _draw_backdrop() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.016, 0.021, 0.022, 1.0), true)
	var backdrop := _current_backdrop_texture()
	if backdrop != null:
		if phase == "night":
			draw_texture_rect(backdrop, STADIUM_BACKDROP_RECT, false, Color(1, 1, 1, 0.98))
			draw_rect(STADIUM_BACKDROP_RECT, Color(0.0, 0.0, 0.0, 0.05), true)
			return
		draw_texture_rect(backdrop, Rect2(Vector2.ZERO, MAP_SIZE), false, Color(1, 1, 1, 0.96))
		draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.0, 0.0, 0.0, 0.08), true)
		return
	draw_rect(PLAY_RECT, Color(0.0, 0.0, 0.0, 0.46), true)
	for x in range(int(PLAY_RECT.position.x), int(PLAY_RECT.end.x), 72):
		draw_line(Vector2(x, PLAY_RECT.position.y), Vector2(x, PLAY_RECT.end.y), Color(0.28, 0.68, 0.65, 0.10), 1.0)
	for y in range(int(PLAY_RECT.position.y), int(PLAY_RECT.end.y), 72):
		draw_line(Vector2(PLAY_RECT.position.x, y), Vector2(PLAY_RECT.end.x, y), Color(0.28, 0.68, 0.65, 0.08), 1.0)

func _current_backdrop_texture() -> Texture2D:
	if not USE_FORMAL_BACKDROPS:
		return null
	if phase == "cover":
		if ending_success_texture != null:
			return ending_success_texture
		if day_background_texture != null:
			return day_background_texture
	if phase == "day" and planning_table_texture != null:
		return planning_table_texture
	if phase == "report":
		if not last_night_success and ending_failure_texture != null:
			return ending_failure_texture
		if last_night_success and day_background_texture != null:
			return day_background_texture
		if not last_night_success and breached_background_texture != null:
			return breached_background_texture
		if report_table_texture != null:
			return report_table_texture
	if phase == "final":
		if ending_success_texture != null:
			return ending_success_texture
		if day_background_texture != null:
			return day_background_texture
	if not formal_night_backdrop_valid:
		return null
	return background_texture

func _draw_final_overlays() -> void:
	if blackout:
		if blackout_overlay_texture != null:
			var flicker := _blackout_flicker()
			draw_texture_rect(blackout_overlay_texture, Rect2(Vector2.ZERO, MAP_SIZE), false, Color(1, 1, 1, flicker))
			if night_rng.randf() < 0.006:
				draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.0, 0.0, 0.0, night_rng.randf_range(0.1, 0.5)), true)
		else:
			draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.0, 0.0, 0.0, 0.42), true)
	var crisis_count := _current_crisis_count()
	if crisis_count > 0:
		if danger_overlay_texture != null:
			var pulse_alpha := _danger_pulse_alpha(crisis_count)
			draw_texture_rect(danger_overlay_texture, Rect2(Vector2.ZERO, MAP_SIZE), false, Color(1, 1, 1, pulse_alpha))
		else:
			var alpha: float = clamp(0.12 + float(crisis_count) * 0.08, 0.0, 0.42)
			draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.42, 0.02, 0.0, alpha * 0.38), true)
			draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE.x, 62)), Color(0.82, 0.03, 0.0, alpha * 0.42), true)
			draw_rect(Rect2(Vector2(0, MAP_SIZE.y - 70), Vector2(MAP_SIZE.x, 70)), Color(0.82, 0.03, 0.0, alpha * 0.34), true)
			draw_rect(Rect2(Vector2.ZERO, Vector2(56, MAP_SIZE.y)), Color(0.82, 0.03, 0.0, alpha * 0.34), true)
			draw_rect(Rect2(Vector2(MAP_SIZE.x - 56, 0), Vector2(56, MAP_SIZE.y)), Color(0.82, 0.03, 0.0, alpha * 0.34), true)
	if phase == "night" and radio_available and not radio_completed and radio_waveform_texture != null:
		var wave_rect := Rect2(Vector2(998, 404), Vector2(240, 72))
		draw_texture_rect(radio_waveform_texture, wave_rect, false, Color(1, 1, 1, 0.84))
	if radio_signal_active and radio_signal_text.length() > 0 and radio_signal_char_index > 0:
		var visible_text := radio_signal_text.substr(0, radio_signal_char_index)
		var sig_rect := Rect2(Vector2(984, 482), Vector2(274, 44))
		draw_rect(sig_rect, Color(0.012, 0.016, 0.018, 0.70), true)
		draw_rect(sig_rect, Color(0.32, 0.78, 0.72, 0.50), false, 1.0)
		var text_pos := Vector2(990, 502)
		var font := ThemeDB.fallback_font
		if font != null:
			var fs := ThemeDB.fallback_font_size
			var text_color := Color(0.56, 0.98, 0.88, 0.92)
			draw_string(font, text_pos, visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, text_color)
	_draw_particles()

func _blackout_flicker() -> float:
	if night_elapsed <= 0.0:
		return 0.72
	var base_alpha := 0.72
	var t := night_elapsed * 12.0
	var noise: float = sin(t * TAU) * 0.5 + sin(t * 2.3 * TAU) * 0.25 + sin(t * 4.7 * TAU) * 0.125
	noise /= 0.875
	return clampf(base_alpha + (noise - 0.5) * 0.12, 0.35, 0.92)

func _danger_pulse_alpha(crisis_count: int) -> float:
	var base := clampf(0.18 + float(crisis_count) * 0.07, 0.0, 0.58)
	var pulse := sin(night_elapsed * 3.0 * TAU) * 0.5 + 0.5
	var strength := 0.12 + float(crisis_count) * 0.04
	return clampf(base + (pulse - 0.5) * strength, 0.0, 0.78)

func _emit_particle(pos: Vector2, vel: Vector2, lifetime: float, color: Color, size: float) -> void:
	if particles.size() >= MAX_PARTICLES:
		return
	particles.append({
		"pos": pos,
		"vel": vel,
		"lifetime": lifetime,
		"max_lifetime": lifetime,
		"color": color,
		"size": size
	})

func _update_particles(delta: float) -> void:
	if not audio_enabled:
		return
	if phase != "night":
		particles.clear()
		return
	var emit_interval := night_elapsed - last_particle_emit_time
	if emit_interval > PARTICLE_EMIT_INTERVAL:
		last_particle_emit_time = night_elapsed
		for _i in range(2):
			var dust_pos := Vector2(randf_range(PLAY_RECT.position.x, PLAY_RECT.end.x), randf_range(PLAY_RECT.position.y, PLAY_RECT.end.y))
			var dust_vel := Vector2(randf_range(-5.0, 5.0), randf_range(-4.0, -1.0))
			_emit_particle(dust_pos, dust_vel, randf_range(3.0, 7.0), Color(0.5, 0.55, 0.5, 0.10), randf_range(1.5, 3.0))
	for id in _barrier_ids():
		if not _hotspot_unlocked(id):
			continue
		var data: Dictionary = hotspots[id]
		if bool(data.get("assault", false)):
			var threat_pos := _threat_position(id)
			if threat_pos != Vector2():
				_emit_particle(threat_pos + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)), Vector2(randf_range(-25.0, 25.0), randf_range(-35.0, -8.0)), randf_range(0.3, 0.7), Color(1.0, 0.6, 0.1, 0.6), randf_range(2.5, 4.0))
	for i in range(particles.size()):
		var p = particles[i]
		p["lifetime"] -= delta
		if p["lifetime"] <= 0.0:
			continue
		p["pos"] += p["vel"] * delta
		p["vel"] += Vector2(0, 6.0) * delta
	var to_remove: Array[int] = []
	for i in range(particles.size()):
		if particles[i]["lifetime"] <= 0.0:
			to_remove.append(i)
	to_remove.reverse()
	for idx in to_remove:
		particles.remove_at(idx)

func _draw_particles() -> void:
	if particles.is_empty():
		return
	for p in particles:
		var life_ratio := p["lifetime"] / p["max_lifetime"]
		if life_ratio <= 0.0:
			continue
		var alpha := p["color"].a * life_ratio
		var draw_color := Color(p["color"].r, p["color"].g, p["color"].b, alpha)
		draw_circle(p["pos"], p["size"] * life_ratio, draw_color)

func _draw_room() -> void:
	draw_rect(ROOM_RECT, Color(0.046, 0.058, 0.055, 0.97), true)
	draw_rect(ROOM_RECT, Color(0.44, 0.78, 0.74, 0.64), false, 4.0)
	draw_rect(Rect2(Vector2(326, 252), Vector2(250, 172)), Color(0.026, 0.034, 0.033, 0.96), true)
	draw_rect(Rect2(Vector2(326, 252), Vector2(250, 172)), Color(0.32, 0.72, 0.70, 0.36), false, 2.0)
	draw_rect(Rect2(Vector2(112, 132), Vector2(190, 162)), Color(0.031, 0.041, 0.039, 0.76), true)
	draw_rect(Rect2(Vector2(612, 400), Vector2(220, 154)), Color(0.031, 0.041, 0.039, 0.76), true)
	draw_line(Vector2(86, 426), Vector2(348, 426), Color(0.44, 0.78, 0.74, 0.26), 3.0)
	draw_line(Vector2(584, 256), Vector2(872, 256), Color(0.44, 0.78, 0.74, 0.26), 3.0)
	draw_line(Vector2(620, 112), Vector2(708, 112), Color(1.0, 0.78, 0.28, 0.42), 5.0)
	draw_line(Vector2(122, 318), Vector2(214, 318), Color(1.0, 0.78, 0.28, 0.32), 4.0)
	if _hotspot_unlocked("right_window"):
		draw_line(Vector2(840, 232), Vector2(746, 248), Color(1.0, 0.78, 0.28, 0.32), 4.0)
	if _hotspot_unlocked("back_door"):
		draw_line(Vector2(672, 624), Vector2(776, 624), Color(1.0, 0.78, 0.28, 0.34), 5.0)
	if _hotspot_unlocked("medbay"):
		draw_rect(Rect2(Vector2(172, 444), Vector2(112, 70)), Color(0.10, 0.20, 0.18, 0.56), true)
		draw_rect(Rect2(Vector2(172, 444), Vector2(112, 70)), Color(0.44, 0.96, 0.72, 0.22), false, 2.0)
	if _hotspot_unlocked("storage"):
		draw_rect(Rect2(Vector2(808, 500), Vector2(96, 80)), Color(0.12, 0.10, 0.06, 0.56), true)
		draw_rect(Rect2(Vector2(808, 500), Vector2(96, 80)), Color(1.0, 0.78, 0.28, 0.22), false, 2.0)
	draw_line(Vector2(470, 566), Vector2(470, 496), Color(0.32, 0.86, 1.0, 0.26), 4.0)
	draw_line(Vector2(764, 382), Vector2(686, 374), Color(0.32, 0.86, 1.0, 0.26), 4.0)

func _draw_threats() -> void:
	for id in _barrier_ids():
		if not _hotspot_unlocked(id):
			continue
		var data: Dictionary = hotspots[id]
		if not bool(data.get("warning", false)) and not bool(data.get("assault", false)) and float(data.get("temp_seal", 0.0)) <= 0.0:
			continue
		var texture := _threat_texture(id)
		var anchor := _threat_position(id)
		var alpha := 0.46
		if bool(data.get("assault", false)):
			alpha = 0.88
		if float(data.get("temp_seal", 0.0)) <= 0.0:
			_draw_zombie_attack_effect(id, data, anchor)
		if texture != null and float(data.get("temp_seal", 0.0)) <= 0.0:
			var size := Vector2(74, 74)
			if id == "front_door" or id == "back_door":
				size = Vector2(82, 82)
			draw_texture_rect(texture, Rect2(anchor - size * 0.5, size), false, Color(1, 1, 1, alpha * 0.28))
		if plank_icon != null and float(data.get("temp_seal", 0.0)) > 0.0:
			var plank_size := Vector2(86, 50)
			if id == "front_door" or id == "back_door":
				plank_size = Vector2(96, 54)
			draw_texture_rect(plank_icon, Rect2(anchor - plank_size * 0.5, plank_size), false, Color(1, 1, 1, 0.95))

func _draw_zombie_attack_effect(id: String, data: Dictionary, anchor: Vector2) -> void:
	var direction := _threat_inward_direction(id)
	if direction == Vector2.ZERO:
		return
	var warning := bool(data.get("warning", false))
	var assault := bool(data.get("assault", false))
	var breach := float(data.get("breach_timer", -1.0)) >= 0.0
	var pulse: float = abs(sin(night_elapsed * (11.0 if assault else 4.6)))
	var impact: float = pow(abs(sin(night_elapsed * 15.0)), 5.0) if assault or breach else 0.0
	var group_count := 1
	if assault:
		group_count = 3
	if breach:
		group_count = 4
	var base_alpha := 0.48 if warning else 0.72
	if breach:
		base_alpha = 0.90
	var base_distance := 46.0 if warning else 34.0
	base_distance -= impact * 18.0
	var tangent := Vector2(-direction.y, direction.x)
	var texture := zombie_crowd_texture if assault or breach else (zombie_pair_texture if warning and pulse > 0.48 else zombie_single_texture)
	if texture != null:
		var side := sin(night_elapsed * 4.2) * (5.0 if warning else 8.0)
		var pos := anchor - direction * (base_distance - pulse * 6.0) + tangent * side
		var size := Vector2(100, 100) if warning else Vector2(132, 132)
		if id == "front_door" or id == "back_door":
			size *= 1.12
		if breach:
			size *= 1.18
		_draw_zombie_texture(texture, pos, direction, size, base_alpha)
	else:
		for i in range(group_count):
			var side := (float(i) - float(group_count - 1) * 0.5) * (18.0 if id == "front_door" or id == "back_door" else 14.0)
			var wobble := sin(night_elapsed * (4.0 + float(i)) + float(i) * 1.7) * 4.0
			var pos := anchor - direction * (base_distance + float(i % 2) * 10.0 - pulse * 5.0) + tangent * (side + wobble)
			var scale := (0.62 if warning else 0.78) + float(i) * 0.045
			_draw_zombie_silhouette(pos, direction, scale, base_alpha - float(i) * 0.06)
	if assault or breach:
		var hand_pos := anchor - direction * (18.0 - impact * 10.0)
		if zombie_hands_texture != null:
			var hand_size := Vector2(124, 124)
			if id == "front_door" or id == "back_door":
				hand_size *= 1.10
			_draw_zombie_texture(zombie_hands_texture, hand_pos, direction, hand_size, 0.86 if breach else 0.68)
		else:
			_draw_zombie_hands(hand_pos, direction, 0.72 if breach else 0.55)
	if breach:
		var red_alpha: float = 0.22 + pulse * 0.22
		draw_circle(anchor, 54.0 + pulse * 10.0, Color(1.0, 0.04, 0.0, red_alpha))

func _draw_zombie_texture(texture: Texture2D, pos: Vector2, direction: Vector2, size: Vector2, alpha: float) -> void:
	draw_set_transform(pos, 0.0, Vector2.ONE)
	draw_texture_rect(texture, Rect2(-size * 0.5, size), false, Color(1.0, 1.0, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_zombie_silhouette(pos: Vector2, direction: Vector2, scale: float, alpha: float) -> void:
	var angle := direction.angle() - PI * 0.5
	draw_set_transform(pos, angle, Vector2(scale, scale))
	var body := Color(0.025, 0.075, 0.085, alpha)
	var rim := Color(0.34, 0.92, 1.0, alpha * 0.52)
	var red := Color(1.0, 0.08, 0.02, alpha * 0.34)
	draw_circle(Vector2(0, -18), 13.0, body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, -6),
		Vector2(16, -4),
		Vector2(19, 28),
		Vector2(6, 46),
		Vector2(-10, 42),
		Vector2(-20, 22)
	]), body)
	draw_line(Vector2(-13, 6), Vector2(-34, 32), body, 8.0)
	draw_line(Vector2(13, 6), Vector2(34, 33), body, 8.0)
	draw_line(Vector2(-34, 32), Vector2(-42, 44), body, 4.0)
	draw_line(Vector2(34, 33), Vector2(43, 44), body, 4.0)
	draw_line(Vector2(-8, 40), Vector2(-16, 62), body, 8.0)
	draw_line(Vector2(9, 41), Vector2(18, 62), body, 8.0)
	draw_line(Vector2(-19, -8), Vector2(-33, 28), rim, 2.0)
	draw_line(Vector2(18, -4), Vector2(36, 28), red, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_zombie_hands(pos: Vector2, direction: Vector2, alpha: float) -> void:
	var angle := direction.angle() - PI * 0.5
	draw_set_transform(pos, angle, Vector2.ONE)
	var color := Color(0.0, 0.014, 0.018, alpha)
	var rim := Color(0.28, 0.86, 1.0, alpha * 0.45)
	for i in range(3):
		var x := -22.0 + float(i) * 22.0
		var start := Vector2(x, -10.0 + float(i % 2) * 4.0)
		var finish := Vector2(x + sin(night_elapsed * 8.0 + float(i)) * 4.0, 34.0)
		draw_line(start, finish, color, 7.0)
		draw_line(start + Vector2(-2, 0), finish + Vector2(-2, 0), rim, 1.4)
		for claw in range(3):
			var claw_offset := Vector2(float(claw - 1) * 4.0, 0)
			draw_line(finish, finish + claw_offset + Vector2(float(claw - 1) * 3.0, 11.0), color, 2.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _threat_inward_direction(id: String) -> Vector2:
	match id:
		"front_door":
			return Vector2(0, 1)
		"back_door":
			return Vector2(0, -1)
		"left_window":
			return Vector2(1, 0)
		"right_window":
			return Vector2(-1, 0)
		_:
			return Vector2.ZERO

func _threat_texture(id: String) -> Texture2D:
	match id:
		"front_door":
			return front_threat_texture
		"back_door":
			return back_threat_texture
		"left_window":
			return left_threat_texture
		"right_window":
			return right_threat_texture
		_:
			return null

func _threat_position(id: String) -> Vector2:
	match id:
		"front_door":
			return Vector2(506, 108)
		"back_door":
			return Vector2(710, 574)
		"left_window":
			return Vector2(96, 222)
		"right_window":
			return Vector2(916, 222)
		_:
			return Vector2.ZERO

func _draw_target_path() -> void:
	if phase != "night" or player_target_id == "":
		return
	var pulse: float = 0.45 + 0.35 * abs(sin(night_elapsed * 8.0))
	var path_points: Array[Vector2] = [player_pos]
	for point in player_route:
		path_points.append(point)
	if path_points[path_points.size() - 1].distance_to(player_target_pos) > 2.0:
		path_points.append(player_target_pos)
	for i in range(path_points.size() - 1):
		draw_line(path_points[i], path_points[i + 1], Color(0.34, 0.92, 1.0, pulse * 0.72), 2.0)
	draw_circle(player_target_pos, 9.0 + 4.0 * pulse, Color(0.34, 0.92, 1.0, 0.16))

func _draw_hotspot(id: String, data: Dictionary) -> void:
	var pos := data["position"] as Vector2
	var kind := str(data.get("kind", ""))
	var value := float(data.get("value", 0.0))
	var state := _hotspot_state(id)
	var pulse: float = 0.5 + 0.5 * abs(sin(night_elapsed * 5.0))
	var color := _state_color(state)
	var radius := 44.0
	var texture := _hotspot_texture(id, data)
	if _hotspot_needs_pulse(id, data, kind, value):
		draw_circle(pos, radius + 10.0 * pulse, Color(color.r, color.g, color.b, 0.16 + pulse * 0.12))
	if texture != null:
		_draw_hotspot_state_icon(pos, texture, color, id)
	else:
		draw_circle(pos, radius, Color(0.018, 0.025, 0.024, 0.92))
		draw_arc(pos, radius, 0.0, TAU, 64, color, 4.0)
		if kind == "generator" and battery_icon != null:
			draw_texture_rect(battery_icon, Rect2(pos - Vector2(22, 22), Vector2(44, 44)), false, Color(1, 1, 1, 0.92))
		elif kind == "radio" and radio_icon != null:
			draw_texture_rect(radio_icon, Rect2(pos - Vector2(22, 22), Vector2(44, 44)), false, Color(1, 1, 1, 0.92))
		else:
			var marker_rect := Rect2(pos - Vector2(19, 23), Vector2(38, 46))
			draw_rect(marker_rect, color.darkened(0.42), true)
			draw_rect(marker_rect, color, false, 3.0)
	var bar_rect := Rect2(pos + Vector2(-30, 34), Vector2(60, 6))
	draw_rect(bar_rect, Color(0.0, 0.0, 0.0, 0.62), true)
	draw_rect(Rect2(bar_rect.position, Vector2(bar_rect.size.x * clamp(value / _max_value(id), 0.0, 1.0), bar_rect.size.y)), color, true)

func _draw_hotspot_state_icon(pos: Vector2, texture: Texture2D, color: Color, id: String) -> void:
	var icon_size := _hotspot_texture_size(id)
	var icon_rect := Rect2(pos - icon_size * 0.5, icon_size)
	draw_circle(pos + Vector2(0, 4), max(icon_size.x, icon_size.y) * 0.42, Color(0.0, 0.0, 0.0, 0.30))
	draw_circle(pos, max(icon_size.x, icon_size.y) * 0.46, Color(color.r, color.g, color.b, 0.10))
	draw_texture_rect(texture, icon_rect, false, Color(1.18, 1.18, 1.12, 0.98))
	draw_arc(pos, max(icon_size.x, icon_size.y) * 0.47, 0.0, TAU, 48, Color(color.r, color.g, color.b, 0.86), 2.0)

func _draw_texture_cover(texture: Texture2D, rect: Rect2, modulate: Color) -> void:
	var source_size := texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var source_ratio := source_size.x / source_size.y
	var target_ratio := rect.size.x / rect.size.y
	var source_rect := Rect2(Vector2.ZERO, source_size)
	if source_ratio > target_ratio:
		var crop_width := source_size.y * target_ratio
		source_rect.position.x = (source_size.x - crop_width) * 0.5
		source_rect.size.x = crop_width
	else:
		var crop_height := source_size.x / target_ratio
		source_rect.position.y = (source_size.y - crop_height) * 0.5
		source_rect.size.y = crop_height
	draw_texture_rect_region(texture, rect, source_rect, modulate)

func _hotspot_texture(id: String, data: Dictionary) -> Texture2D:
	var key := _hotspot_texture_key(id, data)
	if key == "":
		return null
	return hotspot_state_textures.get(key) as Texture2D

func _hotspot_texture_key(id: String, data: Dictionary) -> String:
	return NightShiftArt.hotspot_texture_key(id, data, {
		"blackout": blackout,
		"player_target_id": player_target_id,
		"player_at_target": player_pos.distance_to(player_target_pos) <= 5.0,
		"radio_completed": radio_completed,
		"radio_missed": radio_missed,
		"radio_available": radio_available
	})

func _hotspot_texture_size(id: String) -> Vector2:
	return NightShiftArt.hotspot_texture_size(id)

func _hotspot_needs_pulse(id: String, data: Dictionary, kind: String, value: float) -> bool:
	if kind == "barrier":
		return bool(data.get("assault", false)) or bool(data.get("warning", false)) or float(data.get("breach_timer", -1.0)) >= 0.0 or value < 55.0
	if kind == "generator":
		return blackout or value < 55.0
	if kind == "radio":
		return radio_available and not radio_completed
	if kind == "antenna":
		return bool(data.get("active", false)) or value < 55.0
	if kind == "support":
		return bool(data.get("active", false)) or bool(data.get("warning", false)) or value < 70.0
	return false

func _draw_actors() -> void:
	var actors: Array[Dictionary] = [
		{
			"pos": player_pos,
			"texture": player_texture,
			"color": Color(0.86, 1.0, 0.96, 1.0),
			"label": "YOU",
			"target": player_target_id
		}
	]
	if bool(allies.get("elias", false)):
		actors.append({
			"pos": elias_pos,
			"texture": elias_texture,
			"color": Color(0.56, 0.88, 1.0, 1.0),
			"label": "ELIAS",
			"target": elias_target_id
		})
	if bool(allies.get("nora", false)):
		actors.append({
			"pos": nora_pos,
			"texture": nora_texture,
			"color": Color(1.0, 0.82, 0.42, 1.0),
			"label": "NORA",
			"target": nora_target_id
		})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["pos"] as Vector2).y < (b["pos"] as Vector2).y
	)
	for actor in actors:
		_draw_token(actor["pos"] as Vector2, actor["texture"] as Texture2D, actor["color"] as Color, str(actor["label"]), str(actor["target"]))

func _draw_token(pos: Vector2, texture: Texture2D, accent_color: Color, label: String, target_id: String) -> void:
	var scale := _actor_scale(pos)
	var working := target_id != "" and pos.distance_to(_actor_target_position(target_id)) <= ACTOR_ARRIVE_DISTANCE + 1.0
	var bob := sin(night_elapsed * (12.0 if working else 7.0) + pos.x * 0.015) * (2.0 if working else 1.0)
	var actor_visual_scale := PLAYER_WALK_SCALE if _walk_sprite_available(label) else 1.0
	var shadow_radius := 17.0 * scale * actor_visual_scale
	draw_set_transform(pos + Vector2(0, 3), 0.0, Vector2(1.85, 0.42) * scale * actor_visual_scale)
	draw_circle(Vector2.ZERO, shadow_radius, Color(0.0, 0.0, 0.0, 0.48))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _walk_sprite_available(label):
		pass
	elif label == "YOU" and _player_actor_sources_loaded():
		_draw_player_source_rig(pos, target_id, scale, working, bob)
	elif USE_PROCEDURAL_ACTOR_RIGS:
		_draw_actor_rig(pos, accent_color, label, target_id, scale, working, bob)
	elif texture != null:
		var body_size := _actor_draw_size(label) * scale
		var body_rect := Rect2(pos + Vector2(-body_size.x * 0.5, -body_size.y + bob), body_size)
		draw_texture_rect_region(texture, Rect2(body_rect.position + Vector2(2, 3), body_rect.size), _actor_source_rect(label, texture), Color(0.0, 0.0, 0.0, 0.40))
		draw_texture_rect_region(texture, body_rect, _actor_source_rect(label, texture), _actor_modulate(label))
	else:
		draw_rect(Rect2(pos + Vector2(-12, -46) * scale, Vector2(24, 46) * scale), accent_color.darkened(0.15), true)
		draw_circle(pos + Vector2(0, -54) * scale, 9.0 * scale, accent_color)
	if working:
		_draw_actor_work_effect(pos, accent_color, scale)
	var label_font := ThemeDB.fallback_font
	var label_size := label_font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
	var label_rect := Rect2(pos + Vector2(-label_size.x * 0.5 - 6.0, 6.0), Vector2(label_size.x + 12.0, 15.0))
	draw_rect(label_rect, Color(0.0, 0.0, 0.0, 0.56), true)
	draw_string(label_font, label_rect.position + Vector2(6, 12), label, HORIZONTAL_ALIGNMENT_LEFT, label_rect.size.x, 11, accent_color.lightened(0.18))

func _player_actor_sources_loaded() -> bool:
	return player_actor_front_texture != null and player_actor_side_texture != null and player_actor_back_texture != null

func _draw_player_source_rig(pos: Vector2, target_id: String, scale: float, working: bool, bob: float) -> void:
	var facing := _player_actor_facing(pos, target_id)
	var texture := player_actor_front_texture
	var mirror := false
	if facing == "back":
		texture = player_actor_back_texture
	elif facing == "side_left":
		texture = player_actor_side_texture
		mirror = true
	elif facing == "side_right":
		texture = player_actor_side_texture
	var moving := target_id != "" and pos.distance_to(_actor_target_position(target_id)) > ACTOR_ARRIVE_DISTANCE + 1.0
	var stride := sin(night_elapsed * (11.5 if moving else 3.2))
	var work := sin(night_elapsed * 15.0)
	var draw_size := Vector2(94, 126) * scale
	var root := pos + Vector2(0, bob)
	var parts := _player_actor_parts("side" if facing.begins_with("side") else facing)
	for part in parts:
		var part_id := str(part.get("id", ""))
		var angle := _player_actor_part_angle(part_id, stride, work, working)
		_draw_actor_source_piece(texture, root, draw_size, part, angle, mirror)

func _player_actor_facing(pos: Vector2, target_id: String) -> String:
	var target := _actor_target_position(target_id)
	if target_id == "" or target.x < -9000.0:
		return "front"
	var delta := target - pos
	if abs(delta.x) > abs(delta.y) * 0.72:
		return "side_left" if delta.x < 0.0 else "side_right"
	return "back" if delta.y < 0.0 else "front"

func _player_actor_parts(facing: String) -> Array[Dictionary]:
	if facing == "side":
		return [
			{"id": "far_leg", "src": Rect2(292, 570, 145, 390), "pivot": Vector2(345, 600), "anchor": Vector2(384, 1006)},
			{"id": "near_leg", "src": Rect2(360, 560, 210, 425), "pivot": Vector2(423, 596), "anchor": Vector2(384, 1006)},
			{"id": "torso", "src": Rect2(194, 198, 360, 470), "pivot": Vector2(378, 405), "anchor": Vector2(384, 1006)},
			{"id": "head", "src": Rect2(300, 54, 190, 210), "pivot": Vector2(386, 210), "anchor": Vector2(384, 1006)},
			{"id": "far_arm", "src": Rect2(184, 260, 150, 360), "pivot": Vector2(285, 292), "anchor": Vector2(384, 1006)},
			{"id": "near_arm", "src": Rect2(400, 250, 170, 410), "pivot": Vector2(430, 290), "anchor": Vector2(384, 1006)}
		]
	if facing == "back":
		return [
			{"id": "far_arm", "src": Rect2(118, 265, 160, 385), "pivot": Vector2(260, 300), "anchor": Vector2(384, 1006)},
			{"id": "far_leg", "src": Rect2(260, 560, 150, 420), "pivot": Vector2(324, 596), "anchor": Vector2(384, 1006)},
			{"id": "near_leg", "src": Rect2(372, 555, 170, 435), "pivot": Vector2(430, 596), "anchor": Vector2(384, 1006)},
			{"id": "torso", "src": Rect2(180, 205, 410, 470), "pivot": Vector2(384, 410), "anchor": Vector2(384, 1006)},
			{"id": "head", "src": Rect2(276, 46, 230, 225), "pivot": Vector2(384, 216), "anchor": Vector2(384, 1006)},
			{"id": "near_arm", "src": Rect2(496, 268, 150, 385), "pivot": Vector2(515, 306), "anchor": Vector2(384, 1006)}
		]
	return [
		{"id": "far_arm", "src": Rect2(118, 260, 165, 410), "pivot": Vector2(258, 300), "anchor": Vector2(384, 1006)},
		{"id": "far_leg", "src": Rect2(246, 570, 155, 420), "pivot": Vector2(320, 602), "anchor": Vector2(384, 1006)},
		{"id": "near_leg", "src": Rect2(365, 570, 170, 420), "pivot": Vector2(432, 602), "anchor": Vector2(384, 1006)},
		{"id": "torso", "src": Rect2(176, 205, 420, 480), "pivot": Vector2(384, 410), "anchor": Vector2(384, 1006)},
		{"id": "head", "src": Rect2(268, 48, 240, 230), "pivot": Vector2(384, 218), "anchor": Vector2(384, 1006)},
		{"id": "near_arm", "src": Rect2(510, 260, 155, 420), "pivot": Vector2(526, 300), "anchor": Vector2(384, 1006)}
	]

func _player_actor_part_angle(part_id: String, stride: float, work: float, working: bool) -> float:
	if working and part_id in ["near_arm", "far_arm"]:
		return deg_to_rad((10.0 if part_id == "near_arm" else -6.0) + work * 8.0)
	match part_id:
		"near_leg":
			return deg_to_rad(stride * 12.0)
		"far_leg":
			return deg_to_rad(stride * -9.0)
		"near_arm":
			return deg_to_rad(stride * -10.0)
		"far_arm":
			return deg_to_rad(stride * 7.0)
		"head":
			return deg_to_rad(stride * 1.0)
		_:
			return 0.0

func _draw_actor_source_piece(texture: Texture2D, root: Vector2, draw_size: Vector2, part: Dictionary, angle: float, mirror: bool) -> void:
	if texture == null:
		return
	var src: Rect2 = part["src"]
	var pivot_px: Vector2 = part["pivot"]
	var anchor_px: Vector2 = part["anchor"]
	var source_size := Vector2(768, 1024)
	var pivot_offset := (pivot_px - anchor_px) / source_size * draw_size
	if mirror:
		pivot_offset.x = -pivot_offset.x
		angle = -angle
	var dest_size := src.size / source_size * draw_size
	var local_pivot := (pivot_px - src.position) / src.size * dest_size
	if mirror:
		local_pivot.x = dest_size.x - local_pivot.x
	draw_set_transform(root + pivot_offset, angle, Vector2(-1.0 if mirror else 1.0, 1.0))
	draw_texture_rect_region(texture, Rect2(-local_pivot, dest_size), src, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_actor_rig(pos: Vector2, accent_color: Color, label: String, target_id: String, scale: float, working: bool, bob: float) -> void:
	var moving := target_id != "" and pos.distance_to(_actor_target_position(target_id)) > ACTOR_ARRIVE_DISTANCE + 1.0
	var phase_offset := float(abs(hash(label)) % 1000) * 0.01
	var stride := sin(night_elapsed * (13.0 if moving else 4.0) + phase_offset) * (1.0 if moving else 0.18)
	var work_swing := sin(night_elapsed * 15.0 + phase_offset)
	var root := pos + Vector2(0, bob)
	var coat := _actor_coat_color(label)
	var pants := Color(0.12, 0.14, 0.13, 1.0)
	var boot := Color(0.045, 0.043, 0.038, 1.0)
	var skin := Color(0.62, 0.50, 0.40, 1.0)
	var outline := Color(0.015, 0.018, 0.016, 1.0)
	var hip := root + Vector2(0, -38) * scale
	var chest := root + Vector2(0, -72) * scale
	var head := root + Vector2(0, -94) * scale
	var shoulder_left := chest + Vector2(-15, 4) * scale
	var shoulder_right := chest + Vector2(15, 4) * scale
	var hip_left := hip + Vector2(-10, 4) * scale
	var hip_right := hip + Vector2(10, 4) * scale
	var foot_left := root + Vector2(-8 - stride * 4.5, -2 + abs(stride) * 1.5) * scale
	var foot_right := root + Vector2(8 + stride * 4.5, -2 + abs(stride) * 1.5) * scale
	var knee_left := root + Vector2(-7 + stride * 3.0, -21) * scale
	var knee_right := root + Vector2(7 - stride * 3.0, -21) * scale
	_draw_limb(hip_left, knee_left, foot_left, pants, boot, outline, 6.5 * scale)
	_draw_limb(hip_right, knee_right, foot_right, pants.darkened(0.08), boot, outline, 6.5 * scale)
	draw_colored_polygon(PackedVector2Array([
		shoulder_left + Vector2(-3, -2) * scale,
		shoulder_right + Vector2(3, -2) * scale,
		hip_right + Vector2(5, 2) * scale,
		hip_left + Vector2(-5, 2) * scale
	]), coat)
	draw_line(shoulder_left + Vector2(-2, 0) * scale, hip_left + Vector2(-5, 2) * scale, outline, 2.0 * scale)
	draw_line(shoulder_right + Vector2(2, 0) * scale, hip_right + Vector2(5, 2) * scale, outline, 2.0 * scale)
	draw_line(chest + Vector2(0, -2) * scale, hip + Vector2(0, 4) * scale, accent_color, 2.0 * scale)
	var left_hand_target := root + Vector2(-20 - stride * 3.0, -39 + stride * 2.0) * scale
	var right_hand_target := root + Vector2(22 + stride * 2.0, -41 - stride * 2.0) * scale
	if working:
		var side := _actor_work_side(root, target_id)
		right_hand_target = root + Vector2(26.0 * side, -52.0 + work_swing * 5.0) * scale
		left_hand_target = root + Vector2(15.0 * side, -45.0 - work_swing * 4.0) * scale
	_draw_arm(shoulder_left, left_hand_target, coat.darkened(0.08), skin, outline, 5.0 * scale)
	_draw_arm(shoulder_right, right_hand_target, coat.darkened(0.04), skin, outline, 5.0 * scale)
	draw_circle(head + Vector2(1.5, 1.5) * scale, 10.5 * scale, outline)
	draw_circle(head, 10.0 * scale, skin)
	draw_rect(Rect2(head + Vector2(-8, -5) * scale, Vector2(16, 11) * scale), Color(0.05, 0.045, 0.04, 1.0), true)
	draw_line(head + Vector2(-7, 5) * scale, head + Vector2(8, 5) * scale, accent_color.darkened(0.1), 2.0 * scale)
	if label == "ELIAS":
		draw_rect(Rect2(chest + Vector2(8, -4) * scale, Vector2(7, 18) * scale), Color(0.07, 0.09, 0.10, 1.0), true)
		draw_line(chest + Vector2(9, 0) * scale, chest + Vector2(18, -11) * scale, accent_color, 1.5 * scale)

func _draw_limb(hip: Vector2, knee: Vector2, foot: Vector2, cloth: Color, boot_color: Color, outline: Color, width: float) -> void:
	draw_line(hip, knee, outline, width + 2.0)
	draw_line(knee, foot, outline, width + 2.0)
	draw_line(hip, knee, cloth, width)
	draw_line(knee, foot, cloth.darkened(0.06), width)
	draw_circle(foot, width * 0.58, boot_color)

func _draw_arm(shoulder: Vector2, hand: Vector2, sleeve: Color, skin: Color, outline: Color, width: float) -> void:
	var elbow := shoulder.lerp(hand, 0.52) + Vector2(0, 6)
	draw_line(shoulder, elbow, outline, width + 1.6)
	draw_line(elbow, hand, outline, width + 1.6)
	draw_line(shoulder, elbow, sleeve, width)
	draw_line(elbow, hand, sleeve.darkened(0.05), width)
	draw_circle(hand, width * 0.48, skin)

func _actor_coat_color(label: String) -> Color:
	match label:
		"YOU":
			return Color(0.28, 0.33, 0.31, 1.0)
		"NORA":
			return Color(0.38, 0.30, 0.18, 1.0)
		"ELIAS":
			return Color(0.19, 0.28, 0.34, 1.0)
		_:
			return Color(0.30, 0.32, 0.30, 1.0)

func _actor_work_side(actor_pos: Vector2, target_id: String) -> float:
	if target_id != "" and hotspots.has(target_id):
		var target_pos := hotspots[target_id]["position"] as Vector2
		return -1.0 if target_pos.x < actor_pos.x else 1.0
	return 1.0

func _draw_actor_work_effect(pos: Vector2, accent_color: Color, scale: float) -> void:
	var t := night_elapsed * 14.0
	var side := Vector2(22.0 * scale, -42.0 * scale)
	for i in range(3):
		var angle := t + float(i) * 2.1
		var start := pos + side + Vector2(cos(angle), sin(angle)) * 4.0
		var finish := start + Vector2(cos(angle + 0.8), sin(angle + 0.8)) * (8.0 + float(i) * 2.0)
		draw_line(start, finish, Color(accent_color.r, accent_color.g, accent_color.b, 0.72), 2.0)

func _actor_scale(pos: Vector2) -> float:
	var ratio: float = clamp((pos.y - STADIUM_BACKDROP_RECT.position.y) / STADIUM_BACKDROP_RECT.size.y, 0.0, 1.0)
	return lerpf(0.78, 1.08, ratio)

func _actor_draw_size(label: String) -> Vector2:
	match label:
		"YOU":
			return Vector2(76, 122)
		"NORA":
			return Vector2(72, 122)
		"ELIAS":
			return Vector2(72, 122)
		_:
			return Vector2(68, 116)

func _actor_modulate(label: String) -> Color:
	match label:
		"YOU":
			return Color(2.05, 1.98, 1.72, 1.0)
		"NORA":
			return Color(2.08, 1.98, 1.72, 1.0)
		"ELIAS":
			return Color(2.16, 2.04, 1.72, 1.0)
		_:
			return Color(2.0, 1.95, 1.75, 1.0)

func _actor_source_rect(label: String, texture: Texture2D) -> Rect2:
	var size := texture.get_size()
	match label:
		"YOU":
			return Rect2(Vector2(78, 34), Vector2(312, 470)).intersection(Rect2(Vector2.ZERO, size))
		"NORA":
			return Rect2(Vector2(72, 34), Vector2(224, 470)).intersection(Rect2(Vector2.ZERO, size))
		"ELIAS":
			return Rect2(Vector2(0, 70), Vector2(178, 442)).intersection(Rect2(Vector2.ZERO, size))
		_:
			return Rect2(Vector2.ZERO, size)

func _actor_target_position(target_id: String) -> Vector2:
	if target_id != "" and hotspots.has(target_id):
		return hotspots[target_id]["work_position"] as Vector2
	return Vector2(-9999, -9999)

func _state_color(state: String) -> Color:
	match state:
		"稳住", "稳住", "稳住":
			return Color(0.38, 0.96, 0.72, 1.0)
		"吃紧", "吃紧", "吃紧"鏍�€��™��“?, "需要处理"危险", "危险"鐮�’�槻�Š�Ž•�…��ƒ?, "危险", "危险"鐢�›�‡浣?, "危险"需要处理"危险"需要处理"�ˆ�Š�‡��™?:
			return Color(0.35, 0.88, 1.0, 1.0)
		"宸�‰帴�–�?:
			return Color(0.52, 1.0, 0.72, 1.0)
		_:
			return Color(0.66, 0.78, 0.76, 1.0)

func _add_log(text: String) -> void:
	logs.append(text)
	if logs.size() > 32:
		logs.pop_front()

func _story_lines(value: Variant) -> Array[String]:
	var lines: Array[String] = []
	if value is Array:
		for entry in value:
			var line := str(entry).strip_edges()
			if line != "":
				lines.append(line)
		return lines
	var line := str(value).strip_edges()
	if line != "":
		lines.append(line)
	return lines

func _first_line(text: String) -> String:
	var lines := text.split("\n", false)
	if lines.is_empty():
		return text
	return str(lines[0])

func _route_to_hotspot(id: String, from_pos: Vector2) -> Array[Vector2]:
	if not hotspots.has(id):
		return []
	var final_pos := hotspots[id]["work_position"] as Vector2
	var approach := _hotspot_approach_position(id)
	var route: Array[Vector2] = []
	if from_pos.distance_to(approach) > 34.0 and approach.distance_to(final_pos) > 8.0:
		route.append(approach)
	route.append(final_pos)
	return route

func _route_to_position(from_pos: Vector2, final_pos: Vector2) -> Array[Vector2]:
	var route: Array[Vector2] = []
	if from_pos.distance_to(final_pos) > 4.0:
		route.append(final_pos)
	return route

func _hotspot_approach_position(id: String) -> Vector2:
	match id:
		"front_door":
			return Vector2(506, 288)
		"left_window":
			return Vector2(292, 306)
		"right_window":
			return Vector2(734, 306)
		"generator":
			return Vector2(520, 430)
		"radio":
			return Vector2(704, 390)
		"antenna":
			return Vector2(790, 250)
		"back_door":
			return Vector2(682, 438)
		"medbay":
			return Vector2(286, 382)
		"storage":
			return Vector2(738, 478)
		_:
			if hotspots.has(id):
				return hotspots[id]["work_position"] as Vector2
			return PLAYER_HOME

func _move_actor_along_route(pos: Vector2, route: Array[Vector2], final_pos: Vector2, distance: float) -> Vector2:
	var target := final_pos
	if not route.is_empty():
		target = route[0]
	var next_pos := _move_toward(pos, target, distance)
	if not route.is_empty() and next_pos.distance_to(target) <= ACTOR_ARRIVE_DISTANCE:
		route.remove_at(0)
	return next_pos

func _move_toward(from: Vector2, to: Vector2, distance: float) -> Vector2:
	var offset := to - from
	if offset.length() <= distance or offset.length() <= 0.01:
		return to
	return from + offset.normalized() * distance

func _level() -> Dictionary:
	return NightShiftLevels.get_level(current_level_index)

func _level_number() -> int:
	return current_level_index + 1

func _night_duration() -> float:
	return float(_level().get("duration", 105.0))

func _runtime_time_scale() -> float:
	if phase != "night":
		return 1.0
	return night_time_scale

func _hotspot_unlocked(id: String) -> bool:
	if id == "right_window":
		return _level_number() >= 2
	if id == "radio":
		return _level_number() >= 3
	if id == "antenna":
		return _level_number() >= 4
	if id == "back_door":
		return _level_number() >= 5
	if id == "medbay":
		return _level_number() >= 6
	if id == "storage":
		return _level_number() >= 7
	return hotspots.has(id)

func _max_value(id: String) -> float:
	match id:
		"front_door":
			return 120.0 if bool(upgrades.get("door_reinforce", false)) else 100.0
		"left_window", "right_window":
			return 115.0 if bool(upgrades.get("window_brace", false)) else 100.0
		"back_door":
			return 120.0 if bool(upgrades.get("back_door_bar", false)) else 100.0
		"generator":
			return 115.0 if bool(upgrades.get("battery_buffer", false)) else 100.0
		"antenna":
			return 115.0 if bool(upgrades.get("antenna_anchor", false)) else 100.0
		"medbay", "storage":
			return 100.0
		_:
			return 100.0

func _player_work_rate() -> float:
	return PLAYER_WORK_RATE + (4.0 if bool(upgrades.get("workbench", false)) else 0.0)

func _nora_work_rate() -> float:
	return NightShiftActors.nora_work_rate(NORA_WORK_RATE, upgrades)

func _elias_work_rate() -> float:
	return NightShiftActors.elias_work_rate(ELIAS_WORK_RATE, upgrades)

func _player_speed() -> float:
	return NightShiftActors.player_speed(PLAYER_SPEED, upgrades)

func _door_pressure(base: float) -> float:
	var multiplier := 0.82 if bool(upgrades.get("door_reinforce", false) or upgrades.get("final_barricade", false)) else 1.0
	return base * multiplier

func _window_pressure(base: float) -> float:
	return base * (0.84 if bool(upgrades.get("window_brace", false)) else 1.0)

func _generator_pressure(base: float) -> float:
	var reduction := 0.0
	if bool(upgrades.get("generator_tune", false)):
		reduction += 0.55
	if bool(upgrades.get("generator_cage", false)):
		reduction += 0.35
	return max(0.2, base - reduction)

func _antenna_pressure(base: float) -> float:
	return base * (0.72 if bool(upgrades.get("antenna_anchor", false)) else 1.0)

func _blackout_clear_value() -> float:
	return 18.0 if bool(upgrades.get("generator_tune", false)) else 25.0

func _blackout_barrier_multiplier() -> float:
	return 1.34 if bool(upgrades.get("floodlights", false) or upgrades.get("signal_battery", false)) else 1.55

func _temp_seal_duration() -> float:
	var duration := TEMP_SEAL_DURATION
	if bool(upgrades.get("storage", false)):
		duration += 4.0
	if bool(upgrades.get("double_brace", false)):
		duration += 4.0
	return duration

func _plank_cooldown_duration() -> float:
	var cooldown := PLANK_COOLDOWN
	if bool(upgrades.get("storage", false)):
		cooldown -= 5.0
	if bool(upgrades.get("second_plank", false)):
		cooldown -= 6.0
	if bool(upgrades.get("salvage_planks", false)):
		cooldown -= 7.0
	return max(12.0, cooldown)

func _antenna_signal_low() -> bool:
	if not _hotspot_unlocked("antenna"):
		return false
	return float(hotspots["antenna"].get("value", 100.0)) < 42.0

func _upgrade_name(id: String) -> String:
	match id:
		"door_reinforce":
			return "需要处理"
		"window_brace":
			return "需要处理"battery_buffer":
			return "需要处理"generator_tune":
			return "妫�‚��‡�†��‚鐢�ž��€"
		"radio_booster":
			return "需要处理"
		"workbench":
			return "鏁寸�‚Š宸�ƒ�叿�™?
		"antenna_anchor":
			return "鍥�“„�•�澶�•ƒ�šŽ"
		"storage":
			return "鏁寸�‚Š�Œ�„�墿�—‚?
		"medbay":
			return "需要处理"
		"floodlights":
			return "需要处理"
		"second_plank":
			return "棰�‹��ž��ˆ�„��˜"
		"command_routine":
			return "需要处理"
		"back_door_bar":
			return "妯�ˆ棭�š庨棬"
		"generator_cage":
			return "鍥翠�‡�™�ˆ��•��ˆ?
		"runner_path":
			return "需要处理"
		"medbay_lamp":
			return "需要处理"
		"nora_kit":
			return "鏁寸�‚Š�‘��ˆœ�†ˆ"
		"quiet_hours":
			return "需要处理"
		"salvage_planks":
			return "需要处理"double_brace":
			return "需要处理"
		"victor_cache":
			return "鏍�›��†‡�—�•„祫绠?
		"signal_battery":
			return "需要处理"
		"cable_route":
			return "需要处理"
		"elias_tools":
			return "缁?Elias 宸�ƒ�叿"
		"final_barricade":
			return "需要处理"all_hands":
			return "鍏�„��†��’�——伐"
		"radio_beacon":
			return "寮�‚��‡�„ƒ�ˆ�"
		_:
			return id

func _make_panel(position: Vector2, size: Vector2, bg_color: Color, border_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	return panel

func _upgrade_event_texture(id: String) -> Texture2D:
	if upgrade_event_textures.has(id):
		return upgrade_event_textures[id] as Texture2D
	return null

func _upgrade_event_thumb_texture(id: String) -> Texture2D:
	if upgrade_event_thumb_textures.has(id):
		return upgrade_event_thumb_textures[id] as Texture2D
	return null

func _upgrade_icon_texture(id: String) -> Texture2D:
	if upgrade_icon_textures.has(id):
		return upgrade_icon_textures[id] as Texture2D
	return null

func _make_upgrade_event_thumbnails() -> Dictionary:
	var thumbnails := {}
	for key in upgrade_event_textures.keys():
		var texture := upgrade_event_textures[key] as Texture2D
		if texture == null:
			continue
		thumbnails[key] = _make_texture_thumbnail(texture, Vector2i(178, 100))
	return thumbnails

func _make_texture_thumbnail(texture: Texture2D, target_size: Vector2i) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	var source_size := image.get_size()
	if source_size.x <= 0 or source_size.y <= 0:
		return texture
	var target_aspect := float(target_size.x) / float(target_size.y)
	var source_aspect := float(source_size.x) / float(source_size.y)
	var crop_width := source_size.x
	var crop_height := source_size.y
	if source_aspect > target_aspect:
		crop_width = int(round(float(source_size.y) * target_aspect))
	else:
		crop_height = int(round(float(source_size.x) / target_aspect))
	var crop_x := int(max(0, floor(float(source_size.x - crop_width) * 0.5)))
	var crop_y := int(max(0, floor(float(source_size.y - crop_height) * 0.5)))
	var cropped := image.get_region(Rect2i(crop_x, crop_y, crop_width, crop_height))
	cropped.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(cropped)

func _style_day_choice_button(button: Button, has_event_art: bool) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.035, 0.052, 0.052, 0.88)
	normal.border_color = Color(0.32, 0.72, 0.68, 0.42)
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.07, 0.11, 0.105, 0.94)
	hover.border_color = Color(0.75, 0.95, 0.72, 0.82)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.06, 0.09, 0.082, 0.98)
	pressed.border_color = Color(1.0, 0.82, 0.42, 0.88)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(0.88, 0.98, 0.94, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.94, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.52, 1.0))

func _style_hotspot_button(button: Button) -> void:
	var blank := StyleBoxFlat.new()
	blank.bg_color = Color(0, 0, 0, 0)
	blank.border_color = Color(0, 0, 0, 0)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.16, 0.58, 0.62, 0.18)
	hover.border_color = Color(0.42, 0.98, 1.0, 0.68)
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.corner_radius_top_left = 18
	hover.corner_radius_top_right = 18
	hover.corner_radius_bottom_left = 18
	hover.corner_radius_bottom_right = 18
	button.add_theme_stylebox_override("normal", blank)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", blank)

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if path.begins_with(FINAL_ASSET_PATH):
		var final_image := Image.new()
		var final_err := final_image.load(ProjectSettings.globalize_path(path))
		if final_err == OK:
			return ImageTexture.create_from_image(final_image)
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)

func _build_walk_actor_sprites() -> void:
	player_actor_sprite = _make_walk_actor_sprite("PlayerWalkActor", player_walk_frames, Color(1.12, 1.10, 1.02, 1.0))
	elias_actor_sprite = _make_walk_actor_sprite("EliasWalkActor", elias_walk_frames, Color(1.08, 1.10, 1.06, 1.0))
	nora_actor_sprite = _make_walk_actor_sprite("NoraWalkActor", nora_walk_frames, Color(1.08, 1.08, 1.04, 1.0))

func _make_walk_actor_sprite(sprite_name: String, frames: SpriteFrames, tint: Color) -> AnimatedSprite2D:
	if frames == null:
		return null
	var sprite := AnimatedSprite2D.new()
	sprite.name = sprite_name
	sprite.sprite_frames = frames
	sprite.centered = false
	sprite.offset = PLAYER_WALK_FOOT_OFFSET
	sprite.visible = false
	sprite.z_index = 20
	sprite.modulate = tint
	add_child(sprite)
	return sprite

func _update_walk_actor_sprites() -> void:
	player_walk_animation = _update_walk_actor_sprite(player_actor_sprite, player_pos, player_target_pos, player_walk_animation, true)
	elias_walk_animation = _update_walk_actor_sprite(elias_actor_sprite, elias_pos, elias_target_pos, elias_walk_animation, bool(allies.get("elias", false)))
	nora_walk_animation = _update_walk_actor_sprite(nora_actor_sprite, nora_pos, nora_target_pos, nora_walk_animation, bool(allies.get("nora", false)))

func _update_walk_actor_sprite(sprite: AnimatedSprite2D, pos: Vector2, target_pos: Vector2, animation_name: StringName, active: bool) -> StringName:
	if sprite == null:
		return animation_name
	if phase != "night" or not active:
		sprite.visible = false
		return animation_name
	sprite.visible = true
	sprite.position = pos
	var scale_value := _actor_scale(pos) * PLAYER_WALK_SCALE
	sprite.scale = Vector2(scale_value, scale_value)
	sprite.z_index = int(pos.y)
	var next_animation := _walk_animation_for(pos, target_pos, animation_name)
	if sprite.animation != next_animation:
		sprite.play(next_animation)
	var moving := pos.distance_to(target_pos) > ACTOR_ARRIVE_DISTANCE + 1.0
	if moving:
		if not sprite.is_playing():
			sprite.play(next_animation)
	else:
		sprite.pause()
		sprite.frame = 0
	return next_animation

func _walk_animation_for(pos: Vector2, target_pos: Vector2, fallback: StringName) -> StringName:
	var delta := target_pos - pos
	if delta.length() <= 0.01:
		return fallback
	if abs(delta.x) > abs(delta.y) * 0.72:
		return &"walk_left" if delta.x < 0.0 else &"walk_right"
	if delta.y < 0.0:
		return &"walk_up"
	return &"walk_down"

func _walk_sprite_available(label: String) -> bool:
	match label:
		"YOU":
			return player_actor_sprite != null and player_walk_frames != null
		"NORA":
			return nora_actor_sprite != null and nora_walk_frames != null
		"ELIAS":
			return elias_actor_sprite != null and elias_walk_frames != null
		_:
			return false

func _texture_looks_polluted(texture: Texture2D) -> bool:
	var image := texture.get_image()
	if image == null:
		return false
	var size := image.get_size()
	if size.x <= 0 or size.y <= 0:
		return false
	var total := 0
	var suspicious := 0
	var step := 24
	for y in range(0, size.y, step):
		for x in range(0, size.x, step):
			var color := image.get_pixel(x, y)
			total += 1
			var orange_ui := color.r > 0.46 and color.g > 0.24 and color.b < 0.20
			var blue_ui := color.b > 0.45 and color.b > color.r + 0.16 and color.g > 0.18
			var bright_white_ui := color.r > 0.78 and color.g > 0.78 and color.b > 0.78
			if orange_ui or blue_ui or bright_white_ui:
				suspicious += 1
	if total == 0:
		return false
	return float(suspicious) / float(total) > 0.16
var pause_overlay: PanelContainer
var pause_menu_button_box: HBoxContainer
var game_paused := false
var achievements_unlocked := {}
var achievement_notification: PanelContainer
func _build_pause_menu() -> void:
	pause_overlay = PanelContainer.new()
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.70)
	pause_overlay.add_theme_stylebox_override("panel", style)
	root_ui.add_child(pause_overlay)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE, 40)
	vbox.add_theme_constant_override("separation", 14)
	pause_overlay.add_child(vbox)
	var title := Label.new()
	title.text = "需要处理"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42, 1.0))
	vbox.add_child(title)
	pause_menu_button_box = HBoxContainer.new()
	pause_menu_button_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_menu_button_box.add_theme_constant_override("separation", 12)
	vbox.add_child(pause_menu_button_box)
	_rebuild_pause_buttons()
func _rebuild_pause_buttons() -> void:
	if pause_menu_button_box == null:
		return
	for child in pause_menu_button_box.get_children():
		child.queue_free()
	var resume_btn := Button.new()
	resume_btn.text = "缁�…�”�"
	resume_btn.custom_minimum_size = Vector2(140, 44)
	_style_day_choice_button(resume_btn, false)
	resume_btn.pressed.connect(_toggle_pause)
	pause_menu_button_box.add_child(resume_btn)
	var save_btn := Button.new()
	save_btn.text = "需要处理"
	save_btn.custom_minimum_size = Vector2(140, 44)
	_style_day_choice_button(save_btn, false)
	save_btn.pressed.connect(_save_game)
	pause_menu_button_box.add_child(save_btn)
	var load_btn := Button.new()
	load_btn.text = "需要处理"
	load_btn.custom_minimum_size = Vector2(140, 44)
	_style_day_choice_button(load_btn, false)
	load_btn.pressed.connect(_load_game)
	pause_menu_button_box.add_child(load_btn)
	if phase == "cover" or phase == "final":
		load_btn.disabled = true
	var quit_btn := Button.new()
	quit_btn.text = "需要处理"cover":
		return
	game_paused = not game_paused
	pause_overlay.visible = game_paused
	if game_paused:
		_rebuild_pause_buttons()
func _save_game() -> void:
	var slot := _level_number()
	if NightShiftSave.save(self, slot):
		_add_log("")ight":
		return
	var slot_load := _level_number()
	if NightShiftSave.has_save(slot_load) and NightShiftSave.load(self, slot_load):
		game_paused = false
		if pause_overlay != null:
			pause_overlay.visible = false
		_refresh_ui()
func _quit_to_cover() -> void:
	game_paused = false
	if pause_overlay != null:
		pause_overlay.visible = false
	_reset_campaign()
	_show_cover()
�”˜縡unc _start_opening() -> void:
	if in_opening:
		return
	in_opening = true
	opening_shown = true
	opening_index = 0
	if opening_panel != null:
		opening_panel.visible = true
	_update_opening_slide()

func _update_opening_slide() -> void:
	if opening_index < 0 or opening_index >= OPENING_SLIDES.size():
		return
	var slide := OPENING_SLIDES[opening_index] as Dictionary
	if opening_panel == null:
		return
	var main_label := opening_panel.find_child("OpeningMain", true, false) as Label
	var sub_label := opening_panel.find_child("OpeningSub", true, false) as Label
	var prompt_label := opening_panel.find_child("OpeningPrompt", true, false) as Label
	if main_label != null:
		main_label.text = str(slide.get("text", ""))
	if sub_label != null:
		sub_label.text = str(slide.get("sub", ""))
	if prompt_label != null:
		prompt_label.text = "鐐�„�œ缁�…�”�"
	opening_panel.modulate = Color(1, 1, 1, 0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(opening_panel, "modulate:a", 1.0, 0.30)


func _activate_night() -> void:
	prenight_active = false
	prenight_label.visible = false
	day_panel.visible = false
	result_panel.visible = false
	transition_overlay.color.a = 0.0
	var night_tween := create_tween().set_trans(Tween.TRANS_SINE)
	for node in hud_nodes:
		if node is CanvasItem:
			node.modulate = Color(1, 1, 1, 0)
	night_tween.tween_interval(0.08)
	for node in hud_nodes:
		if node is CanvasItem:
			night_tween.tween_property(node, "modulate:a", 0.82 if node == hud_nodes[0] else 1.0, 0.15)
	_play_sfx("night_start")
	_refresh_audio_state()
	_refresh_ui()
func _advance_opening() -> void:
	opening_index += 1
	if opening_index >= OPENING_SLIDES.size():
		in_opening = false
		if opening_panel != null:
			opening_panel.visible = false
		return
	_update_opening_slide()


func _check_achievements() -> void:
	var level_num := _level_number()
	if level_num >= 1:
		_unlock_achievement("first_night")
	if bool(allies.get("nora", false)):
		_unlock_achievement("nora_joined")
	if bool(allies.get("elias", false)):
		_unlock_achievement("elias_joined")
	var radio_contacts: int = int(radio_contacts_done)
	if radio_contacts >= 1:
		_unlock_achievement("first_call")
	if radio_contacts >= 3:
		_unlock_achievement("radio_net")
	if level_num >= 5:
		_unlock_achievement("halfway")
	if level_num >= 10:
		_unlock_achievement("ten_nights")
	if game_over and outcome == "campaign_success":
		_unlock_achievement("campaign_clear")
func _unlock_achievement(id: String) -> void:
	if achievements_unlocked.has(id):
		return
	var ac_list := _achievement_defs()
	if not ac_list.has(id):
		return
	achievements_unlocked[id] = true
	var ac: Dictionary = ac_list[id]
	_add_log("") % [str(ac.get("name", id)), str(ac.get("desc", ""))])
	_show_achievement_notification(id)
static func _achievement_defs() -> Dictionary:
	return {
		"first_night": {"name": "需要处理"desc": "需要处理"nora_joined": {"name": "绐�„�Ÿ鐨�‹��–�€›?, "desc": "Nora �”�Š��†�Š�…Ž�•�"},
		"elias_joined": {"name": "需要处理", "desc": "Elias 鍥�‚�簲�›�…Ž彿"},
		"first_call": {"name": "需要处理"desc": "需要处理"radio_net": {"name": "需要处理"desc": "需要处理"halfway": {"name": "需要处理"desc": "需要处理"ten_nights": {"name": "需要处理"desc": "需要处理"campaign_clear": {"name": "鐏�ˆš�”™", "desc": "需要处理"}
	}
func _show_achievement_notification(id: String) -> void:
	if achievement_notification != null:
		achievement_notification.queue_free()
	var ac_list := _achievement_defs()
	var ac: Dictionary = ac_list.get(id, {"name": id, "desc": ""})
	var notif := _make_panel(Vector2(280, 60), Vector2(520, 72), Color(0.04, 0.06, 0.06, 0.92), Color(1.0, 0.82, 0.42, 0.88))
	achievement_notification = notif
	root_ui.add_child(notif)
	var margin := notif.get_child(0) as MarginContainer
	var vbox := VBoxContainer.new()
	margin.add_child(vbox)
	var name_label := Label.new()
	name_label.text = "需要处理" % str(ac.get("name", id))
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52, 1.0))
	vbox.add_child(name_label)
	var desc_label := Label.new()
	desc_label.text = str(ac.get("desc", ""))
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.88, 1.0))
	vbox.add_child(desc_label)
	notif.modulate = Color(1, 1, 1, 0)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(notif, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.5)
	tween.tween_property(notif, "modulate:a", 0.0, 0.40)
	tween.tween_callback(func() -> void:
		if achievement_notification == notif:
			achievement_notification.queue_free()
			achievement_notification = null
	)
