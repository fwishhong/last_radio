extends SceneTree

var failed := false

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/RadioScreen.tscn") as PackedScene
	if scene == null:
		_fail("RadioScreen scene failed to load")
		return
	var screen: Node = scene.instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame

	_expect(screen.get("events").size() == 28, "event pool should contain 28 events")
	_expect(screen.get("day") == 1, "game starts on day 1")
	_expect(screen.get("day_events").size() == 3, "day 1 starts with 3 signals")

	var guard := 0
	while int(screen.get("day")) <= 7 and guard < 12:
		guard += 1
		var day_events: Array = screen.get("day_events")
		_expect(not day_events.is_empty(), "day %d should have at least one signal" % int(screen.get("day")))
		for event in day_events:
			if int(screen.get("daily_actions_used")) >= int(screen.get("daily_action_limit")):
				break
			var choice := _pick_affordable_choice(screen, event)
			_expect(not choice.is_empty(), "event %s should have an affordable choice" % str(event.get("id", "")))
			screen.call("_on_choice_selected", event, choice)
		screen.call("_night_settlement")
		if int(screen.get("day")) >= 7 or screen.call("_is_collapsed"):
			break
		screen.set("day", int(screen.get("day")) + 1)
		screen.call("_start_day")
	var score: Dictionary = screen.call("_calculate_score")
	_expect(score.has("rating"), "final score has a rating")
	_expect(score.has("survivors"), "final score has survivors")
	if failed:
		quit(1)
		return
	print("Last Radio smoke test: PASS")
	quit(0)

func _pick_affordable_choice(screen: Node, event: Dictionary) -> Dictionary:
	var choices: Array = event.get("choices", [])
	for choice in choices:
		if screen.call("can_apply_choice", choice):
			return choice
	return {}

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)

func _fail(message: String) -> void:
	failed = true
	push_error("Last Radio smoke test: FAIL - %s" % message)
	print("Last Radio smoke test: FAIL - %s" % message)
