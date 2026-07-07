class_name NightShiftDayEffects
extends RefCounted
# Aggregates effects from chosen day_cards and applies them to night params.
# Each effect in day_cards.json has shape:
#   { "id": "<effect_id>", "target": "<hotspot_id|all|generator>", ...value }
# Supported effect IDs (subset that matters for current chapters):
#   barrier_pressure : multiply barrier drain during assault; target = barrier id | "all_barriers"
#   barrier_cap      : add to barrier max_value;      target = barrier id | "all_barriers"
#   support_pressure : multiply support drain;        target = support id
#   support_cap      : add to support max_value;      target = support id
#   generator_drain  : multiply generator drain;      (no target)
#   repair_rate      : additive bonus to repair rate; target = hotspot id | "all"
#   player_speed     : additive bonus to player speed; (no target)
#   radio_contact_goal: additive change to radio contact goal; (no target)
#   radio_window     : additive bonus to radio contact window seconds; (no target)

# Effect IDs introduced by B1 polish:
#   radio_response       : additive int delta to tonight's radio window;
#                          target field is unused. read via
#                          get_radio_response_delta().
#   night_pressure_tag   : adds a tag string ("noise", etc) to tonight's
#                          pressure tag set; read via
#                          get_night_pressure_tags(). M11 NPC AI will
#                          consume this; for now it is exposed + summarized.
#   npc_keep             : per-night pin — target=<ally_id> means "do not
#                          let this ally be lost tonight" (e.g. Victor on
#                          night 9 via the victor_stay day card).
#                          read via get_npc_keep(<id>) -> bool.
#   npc_remove           : per-night removal — target=<ally_id> means
#                          "this ally is leaving tonight" (e.g. Daniel via
#                          the let_daniel_go day card). Applied at the
#                          pick site in NightShiftGame; queryable via
#                          get_npc_remove(<id>) so the night report can
#                          branch on it. (npc_remove was already in
#                          data/night_shift/day_cards.json pre-B1 even
#                          though it was not in SUPPORTED_IDS — the B2
#                          runtime hook is what makes it actually fire.)
const SUPPORTED_IDS := [
	"barrier_pressure",
	"barrier_cap",
	"support_pressure",
	"support_cap",
	"generator_drain",
	"repair_rate",
	"player_speed",
	"radio_contact_goal",
	"radio_window",
	"nora_work_rate",
	"elias_work_rate",
	"helper_work_rate",
	"radio_response",
	"night_pressure_tag",
	"npc_keep",
	"npc_remove",
]


# Each id -> { id, target, multiplier, bonus, value, tag }.
# `tag` (String) is only set for night_pressure_tag; defaults to "".
var entries: Array = []


func clear() -> void:
	entries.clear()


func add_from_card(card: Dictionary) -> void:
	for eff in card.get("effects", []):
		var item := eff as Dictionary
		var id: String = str(item.get("id", ""))
		if id == "":
			continue
		entries.append({
			"id": id,
			"target": str(item.get("target", "")),
			"multiplier": float(item.get("multiplier", 1.0)),
			"bonus": float(item.get("bonus", 0.0)),
			"value": float(item.get("value", 0.0)),
			"tag": str(item.get("tag", "")),
		})


func count() -> int:
	return entries.size()


# ---- queries -------------------------------------------------------------

# Multiplicative drain multiplier for a given hotspot id and base-drain kind.
# Base kinds we expose: "barrier_assault", "support", "generator"
func get_drain_multiplier(hotspot_id: String, base_kind: String) -> float:
	var mult := 1.0
	for e in entries:
		var id: String = e["id"]
		var target: String = e["target"]
		if base_kind == "barrier_assault" and id == "barrier_pressure":
			if target == hotspot_id or target == "all_barriers":
				mult *= float(e["multiplier"])
		elif base_kind == "support" and id == "support_pressure":
			if target == hotspot_id:
				mult *= float(e["multiplier"])
		elif base_kind == "generator" and id == "generator_drain":
			mult *= float(e["multiplier"])
	return mult


# Additive cap bonus (max_value) for a hotspot id.
func get_cap_bonus(hotspot_id: String) -> float:
	var bonus := 0.0
	for e in entries:
		var id: String = e["id"]
		var target: String = e["target"]
		if id == "barrier_cap" and (target == hotspot_id or target == "all_barriers"):
			bonus += float(e["bonus"])
		elif id == "support_cap" and target == hotspot_id:
			bonus += float(e["bonus"])
	return bonus


# Additive repair-rate bonus for a hotspot id.
func get_repair_bonus(hotspot_id: String) -> float:
	var bonus := 0.0
	for e in entries:
		if e["id"] == "repair_rate":
			var t: String = e["target"]
			if t == "all" or t == hotspot_id:
				bonus += float(e["bonus"])
	return bonus


# Additive player speed bonus.
func get_player_speed_bonus() -> float:
	var bonus := 0.0
	for e in entries:
		if e["id"] == "player_speed":
			bonus += float(e["bonus"])
	return bonus


# Additive radio contact goal delta.
func get_radio_goal_delta() -> int:
	var v := 0
	for e in entries:
		if e["id"] == "radio_contact_goal":
			v += int(e["value"])
	return v


# Additive radio window seconds.
func get_radio_window_bonus() -> float:
	var bonus := 0.0
	for e in entries:
		if e["id"] == "radio_window":
			bonus += float(e["bonus"])
	return bonus


# B2 polish: additive int delta applied on top of the radio_window bonus
# whenever a radio contact event fires this night. Sourced from
# `radio_response` effect entries (e.g. victor_go_find → +2 sec).
func get_radio_response_delta() -> int:
	var v := 0
	for e in entries:
		if e["id"] == "radio_response":
			v += int(round(float(e["value"])))
	return v


# B2 polish: tag strings added to tonight's pressure tag set. Used by M11
# NPC AI (future hook) to bias behavior. For now it is exposed + summarized
# in the day panel so the QA can see it.
func get_night_pressure_tags() -> Array[String]:
	var out: Array[String] = []
	for e in entries:
		if e["id"] == "night_pressure_tag":
			var t: String = str(e.get("tag", ""))
			if t != "" and not out.has(t):
				out.append(t)
	return out


# B2 polish: per-night pin check. True iff there is an entry with
# id="npc_keep" and target=<target_id>. Used by the Victor night-9 失联
# logic to keep him connected when the player picked victor_stay.
func get_npc_keep(target_id: String) -> bool:
	for e in entries:
		if e["id"] == "npc_keep" and str(e["target"]) == target_id:
			return true
	return false


# B2 polish: per-night removal check (sibling of npc_keep). True iff
# there is an entry with id="npc_remove" and target=<target_id>. Used by
# the night-report diff to branch on "Daniel left tonight" (driven by
# the let_daniel_go card).
func get_npc_remove(target_id: String) -> bool:
	for e in entries:
		if e["id"] == "npc_remove" and str(e["target"]) == target_id:
			return true
	return false


# B2 polish: pretty-print the new effect IDs for the day panel.
func _summary_b2(id: String, e: Dictionary) -> String:
	match id:
		"radio_response":
			return "电台响应 %+d 秒" % int(round(float(e["value"])))
		"night_pressure_tag":
			var t: String = str(e.get("tag", ""))
			return "压力标签 +%s" % (t if t != "" else "—")
		"npc_keep":
			return "同伴保留：%s" % e["target"]
		"npc_remove":
			return "同伴离开：%s" % e["target"]
		_:
			return ""


# Compact list of human-readable summaries for the day panel.
func summarize() -> Array:
	var out: Array = []
	for e in entries:
		var id: String = e["id"]
		var target: String = e["target"]
		var line := ""
		match id:
			"barrier_pressure":
				line = "门窗压力 x%.2f（%s）" % [e["multiplier"], _target_label(target, "all_barriers")]
			"barrier_cap":
				line = "门窗上限 +%.0f（%s）" % [e["bonus"], _target_label(target, "all_barriers")]
			"support_pressure":
				line = "%s 压力 x%.2f" % [_target_label(target, ""), e["multiplier"]]
			"support_cap":
				line = "%s 上限 +%.0f" % [_target_label(target, ""), e["bonus"]]
			"generator_drain":
				line = "发电机掉电 x%.2f" % e["multiplier"]
			"repair_rate":
				line = "修复 +%.0f/秒（%s）" % [e["bonus"], _target_label(target, "all")]
			"player_speed":
				line = "主角速度 +%.0f" % e["bonus"]
			"radio_contact_goal":
				line = "电台接听 %+d 次" % int(e["value"])
			"radio_window":
				line = "电台窗口 +%.0f 秒" % e["bonus"]
			"nora_work_rate":
				line = "Nora 速度 +%.0f" % e["bonus"]
			"elias_work_rate":
				line = "Elias 速度 +%.0f" % e["bonus"]
			"helper_work_rate":
				line = "同伴速度 +%.0f" % e["bonus"]
			"radio_response", "night_pressure_tag", "npc_keep", "npc_remove":
				var b2_line: String = _summary_b2(id, e)
				line = b2_line if b2_line != "" else "%s（%s）" % [id, target]
			_:
				line = "%s（%s）" % [id, target]
		out.append(line)
	return out


func _target_label(target: String, default_label: String) -> String:
	if target == "" or target == default_label:
		if target == "":
			return "全局"
		return default_label
	match target:
		"front_door": return "正门"
		"back_door": return "后门"
		"left_window": return "左窗"
		"right_window": return "右窗"
		"generator": return "发电机"
		"radio": return "电台"
		"antenna": return "天线"
		"medbay": return "医务角"
		"storage": return "仓库"
		"windows": return "窗户"
		"all": return "所有"
		"all_barriers": return "所有门窗"
		_: return target
