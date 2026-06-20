extends Node
# Steamworks facade. A thin wrapper around GodotSteam (when available)
# or a no-op stub (when not). This lets the rest of the game call
# `Steam.unlock_achievement("X")` without caring whether the SDK is loaded.
#
# The actual GodotSteam extension is NOT bundled in this repo (its license
# is permissive but the binary distribution model is awkward). To enable
# real Steam integration:
#   1. Install GodotSteam via the Asset Library or by adding the GDExtension
#   2. Replace the body of each method below with the real call:
#        Steam.unlockAchievement("X")  (or Steam.setAchievement)
#        Steam.fileWrite(...)        (or Steam.storeText)
#        Steam.setRichPresence("X")
#   3. Set config/use_steam = true in project.godot
#
# For now: every method either logs (debug) or no-ops. The interface stays
# the same, so swapping is a one-file change.

const ACHIEVEMENT_IDS := {
	"first_night": "ACH_FIRST_NIGHT",
	"recruit_nora": "ACH_NORA",
	"recruit_elias": "ACH_ELIAS",
	"all_three_allies": "ACH_ALL_ALLIES",
	"clear_all_nights": "ACH_CLEAR",
	"no_breach": "ACH_FLAWLESS",
	"first_contact": "ACH_FIRST_CONTACT",
	"reach_victor": "ACH_VICTOR",
	"hard_clear": "ACH_HARD_CLEAR",
	"ng_plus_one": "ACH_NG_PLUS_1",
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
		# Real call (commented out; uncomment when GodotSteam is wired in):
		# Steam.setAchievement(ACHIEVEMENT_IDS[id], true)
		# Steam.storeStats()
		pass
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
		# Real call: Steam.fileWrite(filename, data)
		pass
	print("[Steam] cloud_write stub: %s (%d bytes)" % [filename, data.size()])
	return true  # always succeed for now


func cloud_read(filename: String) -> PackedByteArray:
	if filename.is_empty():
		push_warning("Steamworks.cloud_read: empty filename")
		return PackedByteArray()
	if _enabled:
		# Real call: Steam.fileRead(filename)
		pass
	print("[Steam] cloud_read stub: %s" % filename)
	return PackedByteArray()


# ---------- rich presence ----------

func set_rich_presence(state: String) -> void:
	if _enabled:
		# Real call: Steam.setRichPresence("steam_display", state)
		pass
	# In headless / stub mode this is a no-op. We still update the local
	# state so tests can verify the call was made.
	_rich_presence_state = state


var _rich_presence_state: String = ""


func get_rich_presence() -> String:
	return _rich_presence_state
