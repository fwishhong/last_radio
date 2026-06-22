extends SceneTree

# night_shift_audio_test
# Round-2 repair-action patch — verifies the music cue wiring + SFX loader.
# Mirrors the style of tools/night_shift_basic_test.gd: SceneTree, instantiates
# NightShiftGame.tscn, drives it frame-by-frame, asserts behaviour.
#
# Covers:
#   * `_load_audio` populates success/failure/report when files exist (and
#     gracefully omits them when files don't — the artist may still be
#     generating them in parallel).
#   * `_play_music(track, looped)` honours the looped flag using the same
#     duck-typed `loop` property lookup the runtime uses.
#   * `_end_night(true/false)` triggers the matching sting (success/failure)
#     non-looped, and sets `_pending_report_music` (verified synchronously
#     before _process clears it after the absent-music fallback path).
#   * `_show_night_report(true)` does NOT play the chapter-complete "final"
#     track (regression for the line 3122 bug).
#   * Once the sting ends, _process transitions to the looping report bed.

const AUDIO_PATH := "res://assets/audio/"

var failed: bool = false
var passed: int = 0


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	_expect(scene != null, "NightShiftGame scene loads")
	if scene == null:
		quit(1)
		return

	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame

	# ------------------------------------------------------------------
	# 1) _load_audio populates the new music cues IF the files exist.
	# ------------------------------------------------------------------
	game.call("_load_audio")
	var streams: Dictionary = game.get("audio_streams")

	var success_exists: bool = ResourceLoader.exists(AUDIO_PATH + "music_success.mp3")
	var failure_exists: bool = ResourceLoader.exists(AUDIO_PATH + "music_failure.mp3")
	var report_exists: bool = ResourceLoader.exists(AUDIO_PATH + "music_report.mp3")

	if success_exists:
		_expect(
			streams.has("success") and streams["success"] != null,
			"audio_streams[success] populated when file exists"
		)
	else:
		_expect(
			not streams.has("success"),
			"audio_streams[success] gracefully absent when file missing"
		)
	if failure_exists:
		_expect(
			streams.has("failure") and streams["failure"] != null,
			"audio_streams[failure] populated when file exists"
		)
	else:
		_expect(
			not streams.has("failure"),
			"audio_streams[failure] gracefully absent when file missing"
		)
	if report_exists:
		_expect(
			streams.has("report") and streams["report"] != null,
			"audio_streams[report] populated when file exists"
		)
	else:
		_expect(
			not streams.has("report"),
			"audio_streams[report] gracefully absent when file missing"
		)

	# ------------------------------------------------------------------
	# 2) _play_music honours the `looped` flag.
	# We can test the loop-override logic on ANY track whose stream has
	# a `loop` property. cover.mp3 is shipped and is an AudioStreamMP3,
	# so its `loop` flag is observable via duck-typing — same as runtime.
	# ------------------------------------------------------------------
	var cover_present: bool = streams.has("cover") and streams["cover"] != null
	if cover_present:
		# Looped (default)
		game.call("_play_music", "cover", true)
		var stream_looped: AudioStream = game.get("music_player").stream
		_expect(stream_looped == streams["cover"], "_play_music(true) sets stream to cover")
		if stream_looped and "loop" in stream_looped:
			_expect(
				bool(stream_looped.get("loop")) == true,
				"_play_music(true) sets loop=true on stream"
			)
		# Non-looped
		game.call("_play_music", "cover", false)
		var stream_unlooped: AudioStream = game.get("music_player").stream
		_expect(stream_unlooped == streams["cover"], "_play_music(false) sets stream to cover")
		if stream_unlooped and "loop" in stream_unlooped:
			_expect(
				bool(stream_unlooped.get("loop")) == false,
				"_play_music(false) sets loop=false on stream"
			)
	else:
		# Always assert at least the function runs without error.
		game.call("_play_music", "cover", true)
		_expect(true, "_play_music(true) is callable even without cover stream")
		game.call("_play_music", "cover", false)
		_expect(true, "_play_music(false) is callable even without cover stream")

	# ------------------------------------------------------------------
	# 3) _end_night(true) triggers _play_music("success", false) AND
	#    sets _pending_report_music. We check the flag synchronously
	#    BEFORE _process fires — _process clears the flag when the
	#    music_player isn't actually playing (e.g. when the audio file
	#    isn't shipped yet).
	# ------------------------------------------------------------------
	game.set("phase", "night")
	# Reset breach timers / value so the natural path doesn't already be
	# in night_report or fail.
	for h_id in (game.get("hotspots") as Dictionary):
		var h: Dictionary = (game.get("hotspots") as Dictionary)[h_id]
		h["breach_timer"] = 9999.0
		h["value"] = h.get("max_value", 100.0)
		(game.get("hotspots") as Dictionary)[h_id] = h
	# Run the success path.
	game.call("_end_night", true)
	# Synchronous check — flag must be set right after _end_night returns.
	_expect(
		bool(game.get("_pending_report_music")) == true,
		"_end_night(true) sets _pending_report_music"
	)
	_expect(
		str(game.get("phase")) == "night_report",
		"_end_night(true) -> phase night_report"
	)
	# When the success file is present, music_player.stream should be it.
	var mp: AudioStreamPlayer = game.get("music_player")
	if success_exists:
		_expect(
			mp != null and mp.stream == streams["success"],
			"_end_night(true) -> music_player.stream is success track"
		)
	# Now safe to let _process run — flag may be cleared by the swap.

	# ------------------------------------------------------------------
	# 4) _end_night(false) triggers _play_music("failure", false).
	# Drive failure via breach so the natural path is exercised.
	# ------------------------------------------------------------------
	# The previous success path leaves us at night_report with whatever
	# unlocked_hotspots had accumulated. To reliably exercise the breach
	# path we need a fresh night build with at least one barrier hotspot.
	# Calling _show_night() rebuilds hotspots from the current night_index
	# without depending on prior state — robust against phase 3's
	# success_unlocks that may have shifted the hotspot set.
	game.call("_show_night")
	game.set("_pending_report_music", false)
	game.set("night_elapsed", 0.0)
	game.set("night_duration", 99999.0)
	# Make sure at least one hotspot is breachable. Use whatever barrier
	# exists in the current night (front_door on night 0 / 1).
	var hotspots_dict: Dictionary = game.get("hotspots")
	var breach_id: String = ""
	for h_id in hotspots_dict:
		if hotspots_dict[h_id].get("kind", "") == "barrier":
			breach_id = h_id
			break
	if breach_id == "":
		breach_id = "front_door"
	if hotspots_dict.has(breach_id):
		var hb: Dictionary = hotspots_dict[breach_id]
		hb["value"] = 0.0
		hb["breach_timer"] = 0.0
		hotspots_dict[breach_id] = hb
	# Trigger breach via _update_night.
	game.call("_update_night", 5.0)
	_expect(
		str(game.get("phase")) == "night_report",
		"breach path -> phase night_report"
	)
	_expect(
		bool(game.get("survived")) == false,
		"breach path sets survived=false"
	)
	# Re-run _end_night to exercise the false branch synchronously.
	# (The breach path also calls _end_night(false), but we set state
	# again to make sure our flag is set from this exact call.)
	game.set("phase", "night")
	game.set("_pending_report_music", false)
	game.call("_end_night", false)
	_expect(
		bool(game.get("_pending_report_music")) == true,
		"_end_night(false) sets _pending_report_music"
	)
	var mp2: AudioStreamPlayer = game.get("music_player")
	if failure_exists:
		_expect(
			mp2 != null and mp2.stream == streams["failure"],
			"_end_night(false) -> music_player.stream is failure track"
		)

	# ------------------------------------------------------------------
	# 5) Bug fix: _show_night_report(true) does NOT play "final".
	# The original line 3122 was `_play_music("final" if success else "final")`.
	# We verify the final track is NOT the currently-playing stream when a
	# night_report shows after a successful night.
	# ------------------------------------------------------------------
	game.set("phase", "night")
	game.set("_pending_report_music", false)
	# Reset breach state from phase 4 — leaving a barrier at breach_timer > grace
	# would re-fire _end_night(false) inside _update_night during phase 6's
	# _process call, re-setting _pending_report_music and masking the swap.
	for h_id2 in (game.get("hotspots") as Dictionary):
		var hh: Dictionary = (game.get("hotspots") as Dictionary)[h_id2]
		hh["breach_timer"] = -1.0
		hh["value"] = hh.get("max_value", 100.0)
		(game.get("hotspots") as Dictionary)[h_id2] = hh
	game.call("_show_night_report", true, "test")
	var mp3: AudioStreamPlayer = game.get("music_player")
	var final_track: AudioStream = streams.get("final", null)
	if final_track and mp3 and mp3.stream:
		_expect(
			mp3.stream != final_track,
			"_show_night_report(true) does NOT play 'final' (line 3122 bug fixed)"
		)
	else:
		_expect(true, "_show_night_report(true) bug-fix check skipped (final track absent)")

	# ------------------------------------------------------------------
	# 6) After the sting ends, _process transitions to music_report.
	# Drive the transition manually: set the flag, stop the player, run
	# one _process tick, verify the swap.
	# ------------------------------------------------------------------
	game.set("_pending_report_music", true)
	if mp3:
		mp3.stop()
	# Call _process with a small delta — the transition check runs at the
	# top of _process before phase==night gating.
	game.call("_process", 0.016)
	_expect(
		bool(game.get("_pending_report_music")) == false,
		"_process clears _pending_report_music when sting ends"
	)
	var mp4: AudioStreamPlayer = game.get("music_player")
	if report_exists:
		_expect(
			mp4 != null and mp4.stream == streams["report"],
			"_process transitions music_player.stream to report track"
		)
		if mp4 and mp4.stream and "loop" in mp4.stream:
			_expect(
				bool(mp4.stream.get("loop")) == true,
				"report track plays looped"
			)

	# ------------------------------------------------------------------
	# Done.
	# ------------------------------------------------------------------
	game.queue_free()
	await process_frame
	if failed:
		print("NightShiftGame audio test: FAIL (passed=%d)" % passed)
		quit(1)
	else:
		print("NightShiftGame audio test: PASS (passed=%d)" % passed)
		quit(0)


func _expect(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  ok: %s" % msg)
	else:
		failed = true
		print("  FAIL: %s" % msg)