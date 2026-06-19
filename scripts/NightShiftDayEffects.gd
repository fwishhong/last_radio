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
]


# Each id -> { kind: "mult"|"add", target: String (""=global), value: float }
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
