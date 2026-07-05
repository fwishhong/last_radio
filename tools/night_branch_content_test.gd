extends SceneTree
# Polish backlog B1 — night 5/7/8/9 day-card branch content.
#
# Scope (data layer only):
#   * 13 new i18n keys (7 log_ally_*/log_victor + 6 survivor_*_brief) pair-synced
#     in data/i18n/zh.json + data/i18n/en.json
#   * 5 new day-cards in data/night_shift/day_cards.json
#     (tom_memorial, victor_go_find, victor_stay, victor_broadcast, victor_silent)
#   * data/night_shift/chapter_01_nights.json
#       - night_08.day_cards prepends tom_memorial
#       - night_09.day_cards drops keep_silent and adds the 4 victor_* cards
#
# Reads JSON only — never touches GDScript, scenes, assets, or build_release.*.

const ZH_PATH := "res://data/i18n/zh.json"
const EN_PATH := "res://data/i18n/en.json"
const DAY_CARDS_PATH := "res://data/night_shift/day_cards.json"
const NIGHTS_PATH := "res://data/night_shift/chapter_01_nights.json"

# Polish spec §7.6 — NPC join / left / lost / victor-lost
const NEW_LOG_KEYS := [
	"log_ally_join_nora",
	"log_ally_join_elias",
	"log_ally_join_lily",
	"log_ally_join_tom",
	"log_ally_left_daniel",
	"log_ally_lost_tom",
	"log_victor_lost",
]

# Polish spec §7.7 — survivor briefs
const NEW_SURVIVOR_KEYS := [
	"survivor_nora_brief",
	"survivor_elias_brief",
	"survivor_lily_brief",
	"survivor_tom_brief",
	"survivor_daniel_brief",
	"survivor_victor_brief",
]

const NEW_CARD_IDS := [
	"tom_memorial",
	"victor_go_find",
	"victor_stay",
	"victor_broadcast",
	"victor_silent",
]

const VALID_CARD_TYPES := ["setup", "fortify", "rescue", "scavenge", "broadcast", "people"]

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run()
	quit(0 if failed == 0 else 1)


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _load_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw: Variant = JSON.parse_string(f.get_as_text())
	if not (raw is Dictionary):
		return {}
	return raw as Dictionary


# ---------------- TC1: 7 §7.6 log keys exist + non-empty in zh --------------
func _tc_zh_log_keys(zh: Dictionary) -> void:
	for k in NEW_LOG_KEYS:
		_assert(zh.has(k), "TC1 zh.json has §7.6 key '%s'" % k)
		_assert(zh.has(k) and str(zh[k]).strip_edges().length() > 0,
			"TC1 zh.json '%s' is non-empty" % k)


# ---------------- TC2: 7 §7.6 log keys exist + non-empty in en --------------
func _tc_en_log_keys(en: Dictionary) -> void:
	for k in NEW_LOG_KEYS:
		_assert(en.has(k), "TC2 en.json has §7.6 key '%s'" % k)
		_assert(en.has(k) and str(en[k]).strip_edges().length() > 0,
			"TC2 en.json '%s' is non-empty" % k)


# ---------------- TC3: 6 §7.7 survivor_brief keys exist + non-empty pair --
func _tc_survivor_keys(zh: Dictionary, en: Dictionary) -> void:
	for k in NEW_SURVIVOR_KEYS:
		_assert(zh.has(k) and str(zh[k]).strip_edges().length() > 0,
			"TC3 zh.json has §7.7 '%s' (non-empty)" % k)
		_assert(en.has(k) and str(en[k]).strip_edges().length() > 0,
			"TC3 en.json has §7.7 '%s' (non-empty)" % k)


# ---------------- TC4: 5 new cards exist in day_cards.json ------------------
func _tc_cards_exist(cards_root: Dictionary) -> void:
	var cards: Array = cards_root.get("cards", []) as Array
	var by_id := {}
	for entry in cards:
		var c := entry as Dictionary
		by_id[str(c.get("id", ""))] = c
	for cid in NEW_CARD_IDS:
		_assert(by_id.has(cid), "TC4 day_cards.json has card '%s'" % cid)


# ---------------- TC5: 5 new cards have valid type ---------------------------
func _tc_cards_type_valid(cards_root: Dictionary) -> void:
	var cards: Array = cards_root.get("cards", []) as Array
	for entry in cards:
		var c := entry as Dictionary
		var cid: String = str(c.get("id", ""))
		if not (cid in NEW_CARD_IDS):
			continue
		var t: String = str(c.get("type", ""))
		_assert(VALID_CARD_TYPES.has(t),
			"TC5 card '%s' type='%s' is in valid set" % [cid, t])


# ---------------- TC6: 5 new cards have zh body + en body_en ---------------
func _tc_cards_body(cards_root: Dictionary) -> void:
	var cards: Array = cards_root.get("cards", []) as Array
	for entry in cards:
		var c := entry as Dictionary
		var cid: String = str(c.get("id", ""))
		if not (cid in NEW_CARD_IDS):
			continue
		_assert(str(c.get("body", "")).strip_edges().length() > 0,
			"TC6 card '%s' has non-empty zh body" % cid)
		_assert(str(c.get("body_en", "")).strip_edges().length() > 0,
			"TC6 card '%s' has non-empty en body_en" % cid)
		_assert(c.get("cost", null) is Dictionary,
			"TC6 card '%s' cost is object" % cid)
		_assert(c.get("gain", null) is Dictionary,
			"TC6 card '%s' gain is object" % cid)
		_assert(c.get("effects", null) is Array,
			"TC6 card '%s' effects is array" % cid)


# ---------------- TC7: night_08 first day_card is tom_memorial ---------------
func _tc_night_08(nights_root: Dictionary) -> void:
	var nights: Array = nights_root.get("nights", []) as Array
	var night_08 := _find_night(nights, 8)
	_assert(not night_08.is_empty(), "TC7 night_08 found in chapter")
	if night_08.is_empty():
		return
	var dcs: Array = night_08.get("day_cards", []) as Array
	_assert(dcs.size() >= 1 and str(dcs[0]) == "tom_memorial",
		"TC7 night_08 day_cards[0] == 'tom_memorial'")
	_assert(_has_string(dcs, "tom_memorial"),
		"TC7 night_08 day_cards contains tom_memorial")


# ---------------- TC8: night_09 drops keep_silent, adds 4 victor_* ----------
func _tc_night_09(nights_root: Dictionary) -> void:
	var nights: Array = nights_root.get("nights", []) as Array
	var night_09 := _find_night(nights, 9)
	_assert(not night_09.is_empty(), "TC8 night_09 found in chapter")
	if night_09.is_empty():
		return
	var dcs: Array = night_09.get("day_cards", []) as Array
	_assert(not _has_string(dcs, "keep_silent"),
		"TC8 night_09 day_cards no longer includes 'keep_silent'")
	_assert(_has_string(dcs, "victor_silent"),
		"TC8 night_09 day_cards replaces with 'victor_silent'")
	for cid in ["victor_go_find", "victor_stay", "victor_broadcast"]:
		_assert(_has_string(dcs, cid),
			"TC8 night_09 day_cards contains '%s'" % cid)


# ---------------- TC9: the 13 spec keys are exactly zh+en paired non-empty --
func _tc_13_keys_full_pair(zh: Dictionary, en: Dictionary) -> void:
	var all_keys: Array = NEW_LOG_KEYS + NEW_SURVIVOR_KEYS
	_assert(all_keys.size() == 13,
		"TC9 spec key list is exactly 13 entries (got %d)" % all_keys.size())
	for k in all_keys:
		_assert(zh.has(k) and en.has(k),
			"TC9 key '%s' present on BOTH zh and en side" % k)


# ---------------- TC10: zh and en side identical key set (no orphans) -------
func _tc_pair_identical_keys(zh: Dictionary, en: Dictionary) -> void:
	var zh_only: Array = []
	var en_only: Array = []
	for k in zh.keys():
		if not en.has(k):
			zh_only.append(k)
	for k in en.keys():
		if not zh.has(k):
			en_only.append(k)
	_assert(zh_only.is_empty(),
		"TC10 zh.json has no keys missing in en.json (orphans=%s)" % str(zh_only))
	_assert(en_only.is_empty(),
		"TC10 en.json has no keys missing in zh.json (orphans=%s)" % str(en_only))


# ---------------- helpers ----------------------------------------------------
func _find_night(nights: Array, number: int) -> Dictionary:
	for entry in nights:
		var n := entry as Dictionary
		if int(n.get("number", -1)) == number:
			return n
	return {}


func _has_string(arr: Array, value: String) -> bool:
	for v in arr:
		if str(v) == value:
			return true
	return false


# -----------------------------------------------------------------------------
func _run() -> void:
	print("=== Night branch content test (polish backlog B1) ===")

	var zh := _load_dict(ZH_PATH)
	var en := _load_dict(EN_PATH)
	var cards := _load_dict(DAY_CARDS_PATH)
	var nights := _load_dict(NIGHTS_PATH)

	if zh.is_empty() or en.is_empty():
		print("  FAIL: cannot load zh.json or en.json (paths missing?)")
		failed += 1
	if cards.is_empty():
		print("  FAIL: cannot load day_cards.json")
		failed += 1
	if nights.is_empty():
		print("  FAIL: cannot load chapter_01_nights.json")
		failed += 1

	if not zh.is_empty() and not en.is_empty():
		_tc_zh_log_keys(zh)
		_tc_en_log_keys(en)
		_tc_survivor_keys(zh, en)
		_tc_13_keys_full_pair(zh, en)
		_tc_pair_identical_keys(zh, en)

	if not cards.is_empty():
		_tc_cards_exist(cards)
		_tc_cards_type_valid(cards)
		_tc_cards_body(cards)

	if not nights.is_empty():
		_tc_night_08(nights)
		_tc_night_09(nights)

	print("Night branch content test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
