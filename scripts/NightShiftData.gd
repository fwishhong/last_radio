class_name NightShiftData
extends RefCounted

const DATA_DIR := "res://data/night_shift"
const RESOURCES_PATH := DATA_DIR + "/resources.json"
const DAY_CARDS_PATH := DATA_DIR + "/day_cards.json"
const CHAPTER_01_NIGHTS_PATH := DATA_DIR + "/chapter_01_nights.json"
const SIGNALS_PATH := DATA_DIR + "/signals.json"

var resources: Array = []
var resource_by_id := {}
var cards: Array = []
var card_by_id := {}
var nights: Array = []
var night_by_id := {}
var signals: Array = []
var signal_by_id := {}
var chapter_id := ""
var chapter_title := ""


func load_all() -> void:
	var resource_doc := _load_json_object(RESOURCES_PATH)
	var card_doc := _load_json_object(DAY_CARDS_PATH)
	var night_doc := _load_json_object(CHAPTER_01_NIGHTS_PATH)
	var signals_doc := _load_json_object(SIGNALS_PATH)
	resources = resource_doc.get("resources", []) as Array
	cards = card_doc.get("cards", []) as Array
	nights = night_doc.get("nights", []) as Array
	signals = _normalize_signal_catalog(signals_doc.get("channels", []) as Array)
	chapter_id = str(night_doc.get("chapter_id", ""))
	chapter_title = str(night_doc.get("title", ""))
	resource_by_id = _index_by_id(resources)
	card_by_id = _index_by_id(cards)
	night_by_id = _index_by_id(nights)
	signal_by_id = _index_by_id(signals)


func initial_resource_values() -> Dictionary:
	var values := {}
	for resource in resources:
		var item := resource as Dictionary
		values[str(item.get("id", ""))] = int(item.get("initial", 0))
	return values


func get_resource(id: String) -> Dictionary:
	return (resource_by_id.get(id, {}) as Dictionary).duplicate(true)


func get_card(id: String) -> Dictionary:
	return (card_by_id.get(id, {}) as Dictionary).duplicate(true)


func get_cards(ids: Array) -> Array:
	var result := []
	for id in ids:
		var card := get_card(str(id))
		if not card.is_empty():
			result.append(card)
	return result


func get_night(index: int) -> Dictionary:
	if nights.is_empty():
		return {}
	return (nights[clamp(index, 0, nights.size() - 1)] as Dictionary).duplicate(true)


func get_night_by_id(id: String) -> Dictionary:
	return (night_by_id.get(id, {}) as Dictionary).duplicate(true)


# ---- signal catalog (radio channels) ----------------------------------

# Returns the full list of channel entries from data/night_shift/signals.json.
# Each entry is normalized to {id, label, desc, color, exposure_on_wrong}.
# Returns an empty array if the file is missing or malformed — callers should
# fall back to a hard-coded list in that case.
func get_signal_catalog() -> Array:
	var out: Array = []
	for s in signals:
		out.append((s as Dictionary).duplicate(true))
	return out


# Look up a single channel by id. Returns an empty dictionary if not found.
func get_signal(id: String) -> Dictionary:
	return (signal_by_id.get(id, {}) as Dictionary).duplicate(true)


# Normalize a raw channels list (parsed from JSON) into a uniform schema:
#   {id, label, desc, color, exposure_on_wrong, voice?, wrong_signal?}
# Missing fields fall back to safe defaults. Drops entries without an id.
func _normalize_signal_catalog(raw: Array) -> Array:
	var out: Array = []
	for entry in raw:
		var item := entry as Dictionary
		var id: String = str(item.get("id", ""))
		if id == "":
			continue
		out.append({
			"id": id,
			"label": str(item.get("label", id)),
			"desc": str(item.get("desc", "")),
			"color": str(item.get("color", "#9CD9FF")),
			"exposure_on_wrong": float(item.get("exposure_on_wrong", 0.0)),
			"voice": str(item.get("voice", "")),
			"wrong_signal": str(item.get("wrong_signal", "")),
		})
	return out


func count_nights() -> int:
	return nights.size()


func get_day_cards_for_night(index: int) -> Array:
	var night := get_night(index)
	return get_cards(night.get("day_cards", []) as Array)


func apply_resource_delta(values: Dictionary, delta: Dictionary) -> Dictionary:
	var result := values.duplicate(true)
	for key in delta.keys():
		var id := str(key)
		var resource := get_resource(id)
		var min_value := int(resource.get("min", 0))
		var max_value := int(resource.get("max", 999))
		result[id] = clamp(int(result.get(id, 0)) + int(delta[key]), min_value, max_value)
	return result


func can_pay(values: Dictionary, cost: Dictionary) -> bool:
	for key in cost.keys():
		if int(values.get(str(key), 0)) < int(cost[key]):
			return false
	return true


func preview_card_resources(values: Dictionary, card_id: String) -> Dictionary:
	var card := get_card(card_id)
	if card.is_empty():
		return values.duplicate(true)
	var cost := card.get("cost", {}) as Dictionary
	var gain := card.get("gain", {}) as Dictionary
	var result := values.duplicate(true)
	for key in cost.keys():
		result[str(key)] = int(result.get(str(key), 0)) - int(cost[key])
	result = apply_resource_delta(result, gain)
	return result


func _index_by_id(entries: Array) -> Dictionary:
	var index := {}
	for entry in entries:
		var item := entry as Dictionary
		var id := str(item.get("id", ""))
		if id != "":
			index[id] = item
	return index


func _load_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("NightShiftData missing file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("NightShiftData cannot open file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed as Dictionary
	push_error("NightShiftData file must contain object: %s" % path)
	return {}
