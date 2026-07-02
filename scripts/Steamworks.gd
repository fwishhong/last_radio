extends Node
# Steamworks facade. A thin wrapper around GodotSteam (when available)
# or a no-op stub (when not). This lets the rest of the game call
# `Steamworks.unlock_achievement("X")` without caring whether the SDK is loaded.
#
# GodotSteam 4.20 (Steamworks 1.64, Godot 4.7) is wired in via the
# combined binary at C:\Users\Administrator\Desktop\codex\
# Godot_v4.7-stable_win64_steam.exe (Godot 4.7 custom_build + GodotSteam
# linked in) — see docs/M6_steamworks_setup.md once M6 ship-note lands.
# The repo never carries the binary; CI / dev installs it locally. The
# facade below auto-detects via ClassDB.class_exists("Steam") and only
# hits the real API when that class is registered (i.e. when running
# under the combined GodotSteam binary, not the plain Godot 4.7 binary).
#
# Chapter 1 ships with 8 reachable achievements. NG+ and Hard-Mode clears
# are intentionally out of scope until those modes land.

const ACHIEVEMENT_IDS := {
	"first_night": "ACH_FIRST_NIGHT",
	"recruit_nora": "ACH_NORA",
	"recruit_elias": "ACH_ELIAS",
	"all_three_allies": "ACH_ALL_ALLIES",
	"clear_all_nights": "ACH_CLEAR",
	"no_breach": "ACH_FLAWLESS",
	"first_contact": "ACH_FIRST_CONTACT",
	"reach_victor": "ACH_VICTOR",
}

var _enabled: bool = false
var _unlocked: Dictionary = {}  # id -> bool (local cache for test inspection)


func _ready() -> void:
	# Auto-detect: try to find the Steam singleton.
	if ClassDB.class_exists("Steam") or Engine.has_singleton("Steam"):
		_enabled = true
		print("Steamworks: GodotSteam detected, enabling real backend")
	else:
		_enabled = false
		print("Steamworks: GodotSteam not found, using stub backend (achievements won't unlock on Steam)")


func is_enabled() -> bool:
	return _enabled


# ---------- achievements ----------

func unlock_achievement(id: String) -> bool:
	if not ACHIEVEMENT_IDS.has(id):
		push_warning("Steamworks: unknown achievement id '%s'" % id)
		return false
	if _unlocked.get(id, false):
		return true  # already unlocked
	_unlocked[id] = true
	if _enabled:
		# GodotSteam 4.20 / Steamworks 1.64. setAchievement marks the
		# achievement unlocked in the user's Steam profile; storeStats flushes
		# to the Steam backend so other clients see it promptly. Note:
		# setAchievement takes 1 arg in GodotSteam 4.20 (unlock only —
		# there's no clearAchievement-toggle in this binding).
		Steam.setAchievement(ACHIEVEMENT_IDS[id])
		Steam.storeStats()
	print("[Steam] achievement unlocked: %s" % id)
	return true


func is_achievement_unlocked(id: String) -> bool:
	return _unlocked.get(id, false)


func get_unlocked_achievements() -> Array:
	var out: Array = []
	for k in _unlocked:
		if _unlocked[k]:
			out.append(k)
	return out


# ---------- cloud save (skeleton) ----------

func cloud_write(filename: String, data: PackedByteArray) -> bool:
	if filename.is_empty():
		push_warning("Steamworks.cloud_write: empty filename")
		return false
	if _enabled:
		# GodotSteam 4.20 / Steamworks 1.64. fileWrite takes (file, data, size)
		# — passing data.size() so the binding forwards the full payload.
		# Returns false if Steam Cloud is disabled for the app or the user
		# is in Offline mode.
		var ok: bool = Steam.fileWrite(filename, data, data.size())
		print("[Steam] cloud_write: %s (%d bytes, ok=%s)" % [filename, data.size(), ok])
		return ok
	print("[Steam] cloud_write stub: %s (%d bytes)" % [filename, data.size()])
	return true  # stub mode: always succeed


func cloud_read(filename: String) -> PackedByteArray:
	if filename.is_empty():
		push_warning("Steamworks.cloud_read: empty filename")
		return PackedByteArray()
	if _enabled:
		# GodotSteam 4.20 / Steamworks 1.64. fileRead takes (file, bytes_to_read)
		# — bytes_to_read must be set explicitly. Look it up via getFileSize
		# first; -1 means file missing on Cloud, return empty.
		var fsize: int = Steam.getFileSize(filename)
		if fsize <= 0:
			print("[Steam] cloud_read: %s not found on Cloud (size=%d)" % [filename, fsize])
			return PackedByteArray()
		var result: Dictionary = Steam.fileRead(filename, fsize)
		if bool(result.get("ret", false)):
			var got: PackedByteArray = result.get("data", PackedByteArray())
			print("[Steam] cloud_read: %s (%d bytes)" % [filename, got.size()])
			return got
		print("[Steam] cloud_read failed: %s" % filename)
		return PackedByteArray()
	print("[Steam] cloud_read stub: %s" % filename)
	return PackedByteArray()


# ---------- rich presence ----------

func set_rich_presence(state: String) -> void:
	if _enabled:
		# GodotSteam 4.20 / Steamworks 1.64. setRichPresence under the
		# "steam_display" key shows up in the user's Friends list as their
		# current activity ("旧体育馆守夜 · 第 N 夜" etc.).
		Steam.setRichPresence("steam_display", state)
	# Always update the local state so tests can verify the call was made
	# regardless of whether the Steam backend is reachable.
	_rich_presence_state = state


var _rich_presence_state: String = ""


func get_rich_presence() -> String:
	return _rich_presence_state
