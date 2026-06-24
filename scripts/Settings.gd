class_name Settings
extends RefCounted
# Persistent user settings.
# Backed by a single JSON file at user://settings.json. Keys:
#   locale (zh / en)
#   music_volume (0..1, default 0.8)
#   sfx_volume   (0..1, default 1.0)
#   audio_muted  (bool, default true) — global mute. Default is ON so dev /
#                  debug sessions don't disturb anyone in the room; players
#                  can flip it off in Settings → Audio. CLI --no-mute flag
#                  overrides for one session without persisting.
#   window_mode (windowed / borderless / fullscreen, default windowed)
#   resolution  (string like "1280x720", default "1280x720")
# All getters return the default if the key is missing or the file is corrupt,
# so callers don't have to defend against null.
#
# Settings is intentionally tiny so the i18n / pause-menu / options-menu
# milestones can each touch only what they need. M2 will add window + audio
# wiring on top of this.

const PATH := "user://settings.json"

const DEFAULT_LOCALE := "zh"
const DEFAULT_MUSIC_VOLUME := 0.8
const DEFAULT_SFX_VOLUME := 1.0
const DEFAULT_AUDIO_MUTED := true
const DEFAULT_WINDOW_MODE := "windowed"
const DEFAULT_RESOLUTION := "1280x720"

static var _cache: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_cache = parsed


static func _save() -> void:
	var dir := "user://"
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Settings: cannot write to %s" % PATH)
		return
	f.store_string(JSON.stringify(_cache, "  "))
	f.close()


# ---- locale ----------------------------------------------------------

static func get_locale() -> String:
	_ensure_loaded()
	return str(_cache.get("locale", ""))

static func set_locale(lang: String) -> void:
	_ensure_loaded()
	if lang == "" or lang == get_locale():
		return
	_cache["locale"] = lang
	_save()


# ---- audio volumes ---------------------------------------------------

static func get_music_volume() -> float:
	_ensure_loaded()
	return float(_cache.get("music_volume", DEFAULT_MUSIC_VOLUME))

static func set_music_volume(v: float) -> void:
	_ensure_loaded()
	_cache["music_volume"] = clamp(v, 0.0, 1.0)
	_save()

static func get_sfx_volume() -> float:
	_ensure_loaded()
	return float(_cache.get("sfx_volume", DEFAULT_SFX_VOLUME))

static func set_sfx_volume(v: float) -> void:
	_ensure_loaded()
	_cache["sfx_volume"] = clamp(v, 0.0, 1.0)
	_save()


# ---- audio mute (M11+) -------------------------------------------------
#
# Global mute flag. Default ON so a fresh launch / fresh save slot starts
# silent — useful for dev / debug runs in shared rooms where sound bleeds
# out and annoys people nearby. CLI flag `--no-mute` (and friends)
# overrides per-session without writing to settings.

static func get_audio_muted() -> bool:
	_ensure_loaded()
	return bool(_cache.get("audio_muted", DEFAULT_AUDIO_MUTED))


static func set_audio_muted(v: bool) -> void:
	_ensure_loaded()
	_cache["audio_muted"] = v
	_save()


# ---- display ---------------------------------------------------------

static func get_window_mode() -> String:
	_ensure_loaded()
	return str(_cache.get("window_mode", DEFAULT_WINDOW_MODE))

static func set_window_mode(mode: String) -> void:
	_ensure_loaded()
	_cache["window_mode"] = mode
	_save()

static func get_resolution() -> String:
	_ensure_loaded()
	return str(_cache.get("resolution", DEFAULT_RESOLUTION))

static func set_resolution(r: String) -> void:
	_ensure_loaded()
	_cache["resolution"] = r
	_save()


# ---- reset -----------------------------------------------------------

static func reset_all() -> void:
	_cache = {
		"locale": "",
		"music_volume": DEFAULT_MUSIC_VOLUME,
		"sfx_volume": DEFAULT_SFX_VOLUME,
		"audio_muted": DEFAULT_AUDIO_MUTED,
		"window_mode": DEFAULT_WINDOW_MODE,
		"resolution": DEFAULT_RESOLUTION,
	}
	_save()