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

	print("Sfx test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	quit(0 if failed == 0 else 1)
