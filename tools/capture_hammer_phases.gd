extends SceneTree
# Round-5 single-iteration capture. Uses the proven probe pattern
# (DISABLED mode, 1 iter, 1 save) which works reliably. We call this
# script once per (hotspot, phase) combo from a shell loop, so the
# command line is: capture_hammer_phases.gd <hotspot> <phase>
# Default to front_door / phase 0.0 (rest pose).
#
# IMPORTANT: this script is invoked repeatedly by the harness to grab
# the full 4-hotspot x 6-phase grid (24 captures), since multi-iter
# in a single SubViewport hangs in DISABLED mode (the second
# get_image() call blocks).

const OUTPUT_DIR := "user://last_radio_v5_hammer_phases"
const HOTSPOT_REACH := 70.0
const GRIP_OFFSET := -(HOTSPOT_REACH + 6.0)  # -76


func _initialize() -> void:
	# Default to muted so dev / capture runs in shared rooms don't bleed
	# sound out. Capture scripts run a real (non-headless) Godot process
	# so the audio driver IS active; we hard-mute the Music + SFX buses
	# here so it doesn't matter whether the game's _ready +
	# _apply_audio_mute path has run yet.
	for bus in ["Music", "SFX"]:
		var idx: int = AudioServer.get_bus_index(bus)
		if idx >= 0:
			AudioServer.set_bus_mute(idx, true)
	if DisplayServer.get_name() == "headless":
		print("SKIP: capture requires display")
		quit(0)
		return
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var h_id: String = args[0] if args.size() >= 1 else "front_door"
	var phase_str: String = args[1] if args.size() >= 2 else "0.0"
	# The first arg is the *normalized* phase in [0, 1) across the cycle;
	# the runtime computes phase = fmod(player_repair_timer,
	# REPAIR_CYCLE_SEC) / REPAIR_CYCLE_SEC inside _draw_player, so we
	# scale the normalized phase back to absolute seconds before
	# pinning the timer. Hardcoded REPAIR_CYCLE_SEC = 0.7 (round-5
	# slower swing, see scripts/PlayerRepairFx.gd).
	var phase_norm: float = float(phase_str)
	var phase: float = phase_norm * 0.7

	var abs_path: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)

	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game: Node = scene.instantiate()
	vp.add_child(game)

	for i in range(8):
		await process_frame

	# Re-mute AFTER MenuUI._ready() has run. MenuUI._apply_audio_mute()
	# reads Settings.audio_muted (NOT the CLI --mute flag) and will un-mute
	# the buses mid-ready-chain if the user has previously toggled mute
	# off in Settings UI — wiping out our top-of-_initialize() mute.
	# The 8-frame wait above guarantees MenuUI._ready() has fired; we
	# stamp the buses muted again here so capture runs stay silent
	# regardless of persisted settings.json state.
	for bus in ["Music", "SFX"]:
		var idx2: int = AudioServer.get_bus_index(bus)
		if idx2 >= 0:
			AudioServer.set_bus_mute(idx2, true)

	game.process_mode = Node.PROCESS_MODE_DISABLED

	if game.has_method("_show_night"):
		game.call("_show_night")
	if "card_layer" in game and game.card_layer != null:
		for child in game.card_layer.get_children():
			game.card_layer.remove_child(child)
			child.queue_free()
		game.card_layer.visible = false
	if "night_cg_overlay" in game and game.night_cg_overlay != null:
		game.night_cg_overlay.visible = false
		game.night_cg_overlay.queue_free()
	if "night_paused" in game:
		game.set("night_paused", false)
	for i in range(3):
		await process_frame

	# Force-inject the 4 barrier hotspots we want to review regardless
	# of the active night (night 0 only unlocks front_door + left_window
	# + generator; back_door and right_window aren't in game.hotspots
	# until later nights). Positions mirror NightShiftGame.HOTSPOT_POSITIONS
	# (top half of the stadium room for doors, left/right side for
	# windows). The dict shape is what _start_night builds inside
	# NightShiftGame so the hammer / repair code paths don't crash when
	# they read "kind" / "pos" / "value".
	var forced: Dictionary = {
		"front_door": Vector2(640.0, 85.0),
		"back_door": Vector2(1000.0, 80.0),
		"left_window": Vector2(270.0, 250.0),
		"right_window": Vector2(1080.0, 200.0),
	}
	for fid in forced.keys():
		if not game.hotspots.has(fid):
			game.hotspots[fid] = {
				"id": fid,
				"kind": "barrier",
				"pos": forced[fid],
				"value": 100.0,
				"max_value": 100.0,
				"pressure": 0.0,
				"active": false,
				"warning": false,
				"assault": false,
				"breach_timer": -1.0,
				"temp_seal": 0.0,
			}

	var anchor: Vector2 = game.hotspots[h_id]["pos"]
	game.set("player_pos", anchor + _player_offset_for(h_id))
	game.set("player_target_id", h_id)
	game.set("player_at_target", true)
	game.set("player_repair_active", true)
	game.set("player_facing", _facing_for(h_id))
	game.set("player_is_moving", false)
	game.set("player_repair_timer", phase)  # absolute seconds, REPAIR_CYCLE_SEC * normalized

	if game.has_method("_draw_player"):
		game.call("_draw_player")

	for i in range(2):
		await process_frame

	var img: Image = vp.get_texture().get_image()
	var fname: String = "hammer_%s_phase_%.3f.png" % [h_id, phase_norm]
	img.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + fname))
	print("saved %s (h=%s phase_norm=%.3f, timer=%.3f)" % [fname, h_id, phase_norm, phase])

	# Numerical grip check: predict on-screen grip from sprite transform
	# and compare to expected upper-left position. Print so the harness
	# can grep for errors.
	var hs: Node2D = game.hammer_sprite
	var theta: float = float(hs.rotation)
	var ct: float = cos(theta)
	var st: float = sin(theta)
	var pvx: float = 2.0 * (-302.9) * (1.0 / 22.0)
	var pvy: float = 2.0 * 343.0 * (1.0 / 22.0)
	var prx: float = pvx * ct - pvy * st
	var pry: float = pvx * st + pvy * ct
	var predicted_grip: Vector2 = hs.position + Vector2(prx, pry)
	var expected_grip: Vector2 = anchor + Vector2(GRIP_OFFSET, GRIP_OFFSET)
	var err: float = predicted_grip.distance_to(expected_grip)
	var swing_dbg: float = _swing_for_phase(phase_norm)
	var base_dbg: float = theta - swing_dbg
	var base_err: float = abs(base_dbg - PI / 4.0)
	print("grip_err=%.4f  base_err=%.4f  expected_grip=%s  predicted_grip=%s" % [
		err, base_err, str(expected_grip), str(predicted_grip)
	])

	# Audio self-check: capture runs MUST stay silent regardless of
	# settings.json state (MenuUI._ready() un-mutes when audio_muted=false;
	# the post-frame re-mute above must hold). Print bus state so the
	# harness / dev can grep "AUDIO OK" to confirm.
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	var music_state: String = "n/a"
	var sfx_state: String = "n/a"
	if music_idx >= 0:
		music_state = "MUTED" if AudioServer.is_bus_mute(music_idx) else "UN-MUTED"
	if sfx_idx >= 0:
		sfx_state = "MUTED" if AudioServer.is_bus_mute(sfx_idx) else "UN-MUTED"
	var audio_ok: bool = (music_state == "MUTED" and sfx_state == "MUTED")
	print("AUDIO %s: Music=%s SFX=%s" % ["OK" if audio_ok else "LEAK", music_state, sfx_state])
	if not audio_ok:
		push_error("capture_hammer_phases: audio leak detected (Music=%s SFX=%s)" % [music_state, sfx_state])

	quit(0)


func _player_offset_for(h_id: String) -> Vector2:
	match h_id:
		"front_door":
			return Vector2(0.0, 60.0)
		"back_door":
			return Vector2(0.0, 60.0)
		"left_window":
			return Vector2(60.0, 0.0)
		"right_window":
			return Vector2(-60.0, 0.0)
		_:
			return Vector2(0.0, 60.0)


func _facing_for(h_id: String) -> String:
	match h_id:
		"front_door":
			return "down"
		"back_door":
			return "up"
		"left_window":
			return "right"
		"right_window":
			return "left"
		_:
			return "down"


func _swing_for_phase(phase: float) -> float:
	if phase < 0.45:
		return -PI / 3.0 + (phase / 0.45) * (PI / 6.0 + 1.8)
	var recover_t: float = (phase - 0.45) / 0.55
	return (-PI / 6.0 + 1.8) - recover_t * (PI / 3.0 + PI / 6.0 + 1.8)
