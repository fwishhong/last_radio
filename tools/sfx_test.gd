extends SceneTree
# Sfx test — verifies the procedural SFX generator produces valid streams.

const Sfx := preload("res://scripts/NightShiftSfx.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run()


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _run() -> void:
	print("=== Sfx test ===")
	var all: Dictionary = Sfx.build_all()
	_assert(all.has("warning_beep"), "warning_beep present")
	_assert(all.has("breach_alarm"), "breach_alarm present")
	_assert(all.has("repair_ding"), "repair_ding present")
	_assert(all.has("radio_static"), "radio_static present")
	_assert(all.has("click"), "click present")
	_assert(all.has("fail"), "fail present")
	_assert(all.has("unlock"), "unlock present")

	for k in all:
		var s: AudioStreamWAV = all[k]
		_assert(s != null, "%s not null" % k)
		if s != null:
			_assert(s.data.size() > 0, "%s has data (%d bytes)" % [k, s.data.size()])
			_assert(s.mix_rate == 22050, "%s sample rate 22050" % k)
			_assert(s.format == AudioStreamWAV.FORMAT_16_BITS, "%s is 16-bit" % k)

	# Direct calls
	var beep := Sfx.beep(800.0, 0.1, 0.5)
	_assert(beep != null and beep.data.size() > 0, "beep() produces stream")

	var alarm := Sfx.alarm(400.0, 600.0, 0.3, 0.4)
	_assert(alarm != null and alarm.data.size() > 0, "alarm() produces stream")

	var chord := Sfx.chord([440.0, 660.0], 0.2, 0.3)
	_assert(chord != null and chord.data.size() > 0, "chord() produces stream")

	# --- External-loader SFX (footstep + wood_plank_nail) -----------------
	# Both keys must be present; both must yield a non-null AudioStream;
	# both must produce audible data (either the shipped file or the
	# procedural fallback). The fallback path is exercised by deleting the
	# .import sidecar, but here we just assert that the resolution works.
	_assert(all.has("footstep"), "footstep key present in build_all()")
	_assert(all.has("wood_plank_nail"), "wood_plank_nail key present in build_all()")
	var fs_stream: AudioStream = all["footstep"]
	var wpn_stream: AudioStream = all["wood_plank_nail"]
	_assert(fs_stream != null, "footstep stream non-null")
	_assert(wpn_stream != null, "wood_plank_nail stream non-null")
	# Either the shipped file loaded OR the procedural fallback did — both
	# are valid AudioStream subclasses. The fallback is an AudioStreamWAV
	# with non-empty data; the shipped file is whatever format the artist
	# chose (mp3/ogg/wav). We just confirm we got *something* playable.
	var fs_ok: bool = false
	if fs_stream != null:
		if fs_stream is AudioStreamWAV:
			fs_ok = (fs_stream.data.size() > 0)
		else:
			fs_ok = (fs_stream.get_length() >= 0.0)
	_assert(fs_ok, "footstep stream has data (or runtime playable length)")
	var wpn_ok: bool = false
	if wpn_stream != null:
		if wpn_stream is AudioStreamWAV:
			wpn_ok = (wpn_stream.data.size() > 0)
		else:
			wpn_ok = (wpn_stream.get_length() >= 0.0)
	_assert(wpn_ok, "wood_plank_nail stream has data (or runtime playable length)")
	# Fallback contract: when the path doesn't exist, _load_external_or must
	# return the fallback (not crash, not return null). Direct call so we
	# don't depend on any other test mutating build_all() state.
	var fallback_stream: AudioStream = Sfx._load_external_or(
		"res://assets/audio/__definitely_missing__.wav",
		Sfx.beep(440.0, 0.02, 0.1)
	)
	_assert(fallback_stream != null, "_load_external_or returns fallback when file missing")
	_assert(fallback_stream is AudioStreamWAV, "_load_external_or fallback is AudioStreamWAV")
	_assert((fallback_stream as AudioStreamWAV).data.size() > 0, "_load_external_or fallback has data")

	print("Sfx test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	quit(0 if failed == 0 else 1)
