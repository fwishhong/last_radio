extends SceneTree

const DATA_DIR := "res://data/night_shift"
const RESOURCES_PATH := DATA_DIR + "/resources.json"
const DAY_CARDS_PATH := DATA_DIR + "/day_cards.json"
const NIGHTS_PATH := DATA_DIR + "/chapter_01_nights.json"

var failed := false
var resource_ids := {}
var card_ids := {}


func _initialize() -> void:
	var resources := _load_json_object(RESOURCES_PATH)
	var cards := _load_json_object(DAY_CARDS_PATH)
	var nights := _load_json_object(NIGHTS_PATH)
	if failed:
		_finish()
		return

	_validate_resources(resources)
	_validate_cards(cards)
	_validate_nights(nights)
	_finish()


func _load_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_fail("missing file: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("cannot open file: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		_fail("file must contain a JSON object: %s" % path)
		return {}
	return parsed as Dictionary


func _validate_resources(data: Dictionary) -> void:
	var resources := data.get("resources", []) as Array
	_expect(resources.size() >= 6, "resources define the formal core set")
	for entry in resources:
		var item := entry as Dictionary
		var id := str(item.get("id", ""))
		_expect(id != "", "resource has id")
		_expect(not resource_ids.has(id), "resource id is unique: %s" % id)
		resource_ids[id] = true
		_expect(str(item.get("name", "")) != "", "resource has display name: %s" % id)
		_expect(float(item.get("max", 0.0)) >= float(item.get("initial", 0.0)), "resource max covers initial: %s" % id)


func _validate_cards(data: Dictionary) -> void:
	var cards := data.get("cards", []) as Array
	_expect(cards.size() >= 20, "day cards include chapter one card pool")
	for entry in cards:
		var card := entry as Dictionary
		var id := str(card.get("id", ""))
		_expect(id != "", "card has id")
		_expect(not card_ids.has(id), "card id is unique: %s" % id)
		card_ids[id] = true
		_expect(["setup", "fortify", "rescue", "scavenge", "broadcast", "people"].has(str(card.get("type", ""))), "card type is valid: %s" % id)
		_expect(str(card.get("name", "")) != "", "card has name: %s" % id)
		_expect(str(card.get("body", "")) != "", "card has body: %s" % id)
		_validate_resource_map(card.get("cost", {}), "card cost %s" % id)
		_validate_resource_map(card.get("gain", {}), "card gain %s" % id)
		_expect(card.get("effects", []) is Array, "card effects array: %s" % id)


func _validate_nights(data: Dictionary) -> void:
	var nights := data.get("nights", []) as Array
	_expect(nights.size() == 10, "chapter one has exactly 10 nights")
	var expected_number := 1
	for entry in nights:
		var night := entry as Dictionary
		var id := str(night.get("id", ""))
		_expect(id != "", "night has id")
		_expect(int(night.get("number", 0)) == expected_number, "night number sequence: %s" % id)
		expected_number += 1
		_expect(float(night.get("duration", 0.0)) >= 60.0, "night duration is playable: %s" % id)
		_expect((night.get("unlocked_hotspots", []) as Array).size() >= 3, "night has unlocked hotspots: %s" % id)
		for card_id in night.get("day_cards", []) as Array:
			_expect(card_ids.has(str(card_id)), "night references existing card %s in %s" % [str(card_id), id])
		_expect((night.get("fixed_events", []) as Array).size() >= 1, "night has fixed events: %s" % id)


func _validate_resource_map(value: Variant, label: String) -> void:
	_expect(value is Dictionary, "%s is object" % label)
	if not (value is Dictionary):
		return
	for key in (value as Dictionary).keys():
		_expect(resource_ids.has(str(key)), "%s references existing resource: %s" % [label, str(key)])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)


func _fail(message: String) -> void:
	failed = true
	push_error("Night shift data validate: FAIL - %s" % message)
	print("Night shift data validate: FAIL - %s" % message)


func _finish() -> void:
	if failed:
		print("Night shift data validate: FAIL")
		quit(1)
	else:
		print("Night shift data validate: PASS")
		quit(0)
