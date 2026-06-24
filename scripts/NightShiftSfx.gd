class_name NightShiftSfx
extends RefCounted
# Procedural SFX generator. Builds short PCM AudioStreamWAV clips from
# sine + envelope so we don't need shipped .wav files.
# Supported: warning_beep, breach_alarm, repair_ding, radio_static, click, fail

const SAMPLE_RATE := 22050


static func build_all() -> Dictionary:
	var sfx := {
		"warning_beep": beep(720.0, 0.10, 0.18),
		"breach_alarm": alarm(360.0, 480.0, 0.55, 0.55),
		"repair_ding": beep(1180.0, 0.06, 0.12),
		"radio_static": static_(0.32),
		"click": beep(540.0, 0.025, 0.06),
		"fail": alarm(440.0, 220.0, 0.4, 0.5),
		"unlock": chord([660.0, 880.0], 0.18, 0.22),
		"breath": breath(0.55),
	}
	# External SFX shipped as audio files — load via ResourceLoader when the
	# file is present, otherwise fall back to a procedural clip so the game
	# still plays something. Both must be AudioStream-compatible so the
	# generic _play_sfx path can swap them in without branching.
	sfx["footstep"] = _load_external_or(
		"res://assets/audio/sfx_footstep.wav",
		beep(180.0, 0.05, 0.12)
	)
	sfx["wood_plank_nail"] = _load_external_or(
		"res://assets/audio/sfx_wood_plank_nail.wav",
		beep(220.0, 0.04, 0.18)
	)
	return sfx


# Load an external audio resource if present, otherwise return the fallback.
# Returns AudioStream (not AudioStreamWAV) so .mp3 / .ogg files don't fail
# the static type check. Runtime casting happens at the _play_sfx call site.
static func _load_external_or(path: String, fallback: AudioStreamWAV) -> AudioStream:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is AudioStream:
			return res
	return fallback


# Short sine with quick attack/release envelope.
static func beep(freq: float, dur: float, volume: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	var phase_inc := TAU * freq / SAMPLE_RATE
	for i in range(frames):
		# ASR: 6 ms attack, 6 ms release, otherwise sustain
		var t: float = float(i) / float(frames)
		var env: float = 1.0
		var attack := 0.006
		var release := 0.006
		if t < attack / dur:
			env = t * dur / attack
		elif t > 1.0 - release / dur:
			env = (1.0 - t) * dur / release
		env = clamp(env, 0.0, 1.0)
		var s: float = sin(phase) * env * volume
		phase += phase_inc
		var sample := int(s * 32767.0)
		data.encode_s16(i * 2, sample)
	return _to_wav(data, 1)


# Frequency sweep, used for breach/fail alarm.
static func alarm(freq_a: float, freq_b: float, dur: float, volume: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in range(frames):
		var t: float = float(i) / float(frames)
		var f: float = lerp(freq_a, freq_b, t)
		phase += TAU * f / SAMPLE_RATE
		var env: float = 1.0
		var release := 0.05
		if t > 1.0 - release / dur:
			env = (1.0 - t) * dur / release
		env = clamp(env, 0.0, 1.0)
		var s: float = sin(phase) * env * volume
		var sample := int(s * 32767.0)
		data.encode_s16(i * 2, sample)
	return _to_wav(data, 1)


# Two-note happy chord.
static func chord(freqs: Array, dur: float, volume: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phases := []
	for f in freqs:
		phases.append(0.0)
	for i in range(frames):
		var t: float = float(i) / float(frames)
		var env: float = 1.0
		var attack := 0.01
		var release := 0.05
		if t < attack / dur:
			env = t * dur / attack
		elif t > 1.0 - release / dur:
			env = (1.0 - t) * dur / release
		env = clamp(env, 0.0, 1.0)
		var s := 0.0
		for k in range(freqs.size()):
			var f: float = float(freqs[k])
			phases[k] += TAU * f / SAMPLE_RATE
			s += sin(phases[k])
		s = s / float(freqs.size()) * env * volume
		var sample := int(s * 32767.0)
		data.encode_s16(i * 2, sample)
	return _to_wav(data, 1)


# White noise envelope.
static func static_(dur: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	for i in range(frames):
		var t: float = float(i) / float(frames)
		var env: float = sin(PI * t)  # fade in/out
		var s: float = rng.randf_range(-1.0, 1.0) * env * 0.18
		var sample := int(s * 32767.0)
		data.encode_s16(i * 2, sample)
	return _to_wav(data, 1)


# Slow swell, used for "breath" ambience when no SFX loaded.
static func breath(dur: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var phase := 0.0
	for i in range(frames):
		var t: float = float(i) / float(frames)
		var env: float = sin(PI * t) * 0.4
		phase += TAU * 110.0 / SAMPLE_RATE
		var s: float = sin(phase) * env
		var sample := int(s * 32767.0)
		data.encode_s16(i * 2, sample)
	return _to_wav(data, 1)


static func _to_wav(data: PackedByteArray, channels: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
