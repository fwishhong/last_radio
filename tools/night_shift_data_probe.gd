extends SceneTree

var failed := false


func _initialize() -> void:
	print("Night shift data probe: START")
	var data_script: Script = load("res://scripts/NightShiftData.gd") as Script
	var data: RefCounted = data_script.new() as RefCounted
	data.call("load_all")
	_expect(int(data.call("count_nights")) == 10, "loads 10 chapter-one nights")
	_expect((data.call("get_card", "window_brace") as Dictionary).get("type", "") == "fortify", "loads day card by id")
	_expect((data.call("get_resource", "exposure") as Dictionary).get("kind", "") == "pressure", "loads resource by id")
	var values: Dictionary = data.call("initial_resource_values")
	_expect(int(values.get("planks", -1)) == 4, "initial planks loaded")
	_expect(int(values.get("trust", -1)) == 3, "initial trust loaded")
	var night_five: Dictionary = data.call("get_night", 4)
	_expect(str(night_five.get("id", "")) == "night_05", "loads night by index")
	var night_five_cards: Array = data.call("get_day_cards_for_night", 4)
	_expect(night_five_cards.size() >= 4, "night five has expanded day card options")
	_expect(bool(data.call("can_pay", values, {"planks": 1})), "can pay available resource")
	_expect(not bool(data.call("can_pay", values, {"planks": 99})), "cannot overpay unavailable resource")
	var after_storage: Dictionary = data.call("preview_card_resources", values, "storage_sweep")
	_expect(int(after_storage.get("planks", 0)) == 6, "card preview adds planks")
	_expect(int(after_storage.get("parts", 0)) == 5, "card preview adds parts")
	var after_silent: Dictionary = data.call("preview_card_resources", values, "keep_silent")
	_expect(int(after_silent.get("exposure", 0)) == 0, "resource preview clamps exposure minimum")

	if failed:
		print("Night shift data probe: FAIL")
		quit(1)
	else:
		print("Night shift data probe: PASS")
		quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Night shift data probe: FAIL - %s" % message)
	print("Night shift data probe: FAIL - %s" % message)
