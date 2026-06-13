extends SceneTree

var failed := false

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	_expect(scene != null, "NightShiftGame scene loads")
	if scene == null:
		quit(1)
		return
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var cover_audio := game.call("_debug_get_audio_state") as Dictionary
	_expect(bool(cover_audio.get("music_stream_loaded", false)), "cover music stream loads")
	_expect(bool(cover_audio.get("music_loop", false)), "cover music loops")

	_expect(game.call("_debug_start_campaign"), "campaign starts")
	await process_frame
	_expect(game.call("_debug_choose_day", "start"), "level 1 night starts")
	await process_frame
	var night_one_audio := game.call("_debug_get_audio_state") as Dictionary
	_expect(str(night_one_audio.get("music_key", "")) == "night_early", "level 1 uses music_night_early")
	_expect(bool(night_one_audio.get("music_stream_loaded", false)), "level 1 music stream loads")
	_expect(bool(night_one_audio.get("music_playing", false)), "level 1 music is playing")
	_expect(bool(night_one_audio.get("music_loop", false)), "level 1 music loops")
	_expect(bool(night_one_audio.get("ambience_stream_loaded", false)), "level 1 ambience stream loads")
	_expect(bool(night_one_audio.get("ambience_loop", false)), "level 1 ambience loops")

	game.call("_enter_day", 5)
	await process_frame
	_expect(game.call("_debug_choose_day", "start"), "level 6 night starts")
	await process_frame
	var night_six_audio := game.call("_debug_get_audio_state") as Dictionary
	_expect(str(night_six_audio.get("music_key", "")) == "night_final", "level 6 uses music_night_final")
	_expect(bool(night_six_audio.get("music_stream_loaded", false)), "level 6 music stream loads")
	_expect(bool(night_six_audio.get("music_playing", false)), "level 6 music is playing")
	_expect(bool(night_six_audio.get("music_loop", false)), "level 6 music loops")
	_expect(str(night_six_audio.get("ambience_key", "")) == "night", "level 6 keeps early ambience")
	_expect(bool(night_six_audio.get("ambience_loop", false)), "level 6 ambience loops")

	game.queue_free()
	if failed:
		printerr("Night shift audio probe: FAIL")
		quit(1)
	else:
		print("Night shift audio probe: PASS")
		quit()

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		printerr("FAIL: %s" % label)
