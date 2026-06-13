extends SceneTree

var failed := false

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/DefenseGame.tscn") as PackedScene
	_expect(scene != null, "DefenseGame scene loads")
	if scene == null:
		quit(1)
		return

	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	_expect((game.get("facility_defs") as Dictionary).size() == 4, "loads 4 facility defs")
	_expect((game.get("unit_defs") as Dictionary).size() == 5, "loads 5 unit defs")
	_expect((game.get("campaign_defs") as Array).size() == 3, "loads 3 campaign nights")
	_expect((game.get("radio_action_defs") as Dictionary).size() == 4, "loads 4 radio actions")
	_expect(str(game.get("phase")) == "day", "starts in day signal phase")

	_expect(game.call("_select_signal", "garage_battery"), "selects night 1 signal")
	_expect(str(game.get("phase")) == "prep", "signal moves to prep phase")
	_expect(int((game.get("resources") as Dictionary).get("battery", 0)) >= 6, "signal effect grants battery")

	_expect(game.call("_build_facility", "north_turret", "turret"), "builds north turret")
	_expect(game.call("_build_facility", "north_barricade", "barricade"), "builds north barricade")
	_expect(game.call("_build_facility", "south_turret", "relay"), "builds relay")
	_expect((game.get("facilities") as Array).size() == 3, "tracks built facilities")

	game.call("_start_night")
	_expect(str(game.get("phase")) == "night", "starts night phase")
	game.call("_tune_route", "south_gate")
	_expect(str(game.get("tuned_route")) == "south_gate", "tunes radio to a route")
	_expect(game.call("_use_radio_action", "jam"), "uses jam radio action")
	_expect(float((game.get("route_jams") as Dictionary).get("south_gate", 0.0)) > 0.0, "jam applies to tuned route")
	_advance(game, 6.2)
	game.call("_tune_route", "north_bridge")
	_expect(game.call("_use_radio_action", "reroute"), "uses reroute radio action")
	_expect(str(game.get("reroute_source_route")) == "north_bridge" or int(game.get("reroute_charges")) == 0, "reroute is tied to tuned route")
	_advance(game, 6.2)
	game.call("_tune_route", "service_tunnel")
	_expect(game.call("_use_radio_action", "soothe"), "uses soothe radio action")
	_advance(game, 6.2)
	_expect(game.call("_use_radio_action", "overload"), "uses overload radio action")

	_play_until_not_night(game, 1400)
	_expect(str(game.get("phase")) in ["report", "final"], "night 1 reaches report or final")
	_expect(int(game.get("radio_actions_used")) >= 4, "tracks radio actions")
	_expect(int(game.get("spawned_total")) > 0, "spawns enemies")
	_expect(int(game.get("turret_damage_done")) > 0, "turret deals damage")
	_expect(int(game.get("salvaged_total")) > 0, "killed enemies drop scrap")
	_expect(int(game.get("rescued_total")) > 0, "survivor can be rescued")
	game.call("_select_build_point", "north_turret")
	if int((game.get("resources") as Dictionary).get("scrap", 0)) >= 4:
		_expect(game.call("_upgrade_selected_facility"), "upgrades a facility with salvage")

	if str(game.get("phase")) == "report":
		game.call("_continue_from_report")
		_expect(int(game.get("current_day_index")) == 1, "continues to day 2")
		_expect(game.call("_select_signal", "fake_mayday"), "selects night 2 signal")
		game.call("_build_facility", "south_barricade", "barricade")
		game.call("_build_facility", "service_turret", "turret")
		game.call("_start_night")
		_play_until_not_night(game, 1600)

	if str(game.get("phase")) == "report":
		game.call("_continue_from_report")
		_expect(int(game.get("current_day_index")) == 2, "continues to day 3")
		_expect(game.call("_select_signal", "antenna_crisis"), "selects night 3 signal")
		game.call("_build_facility", "service_barricade", "decoy")
		game.call("_start_night")
		_play_until_not_night(game, 2200)

	_expect(str(game.get("phase")) == "final", "campaign reaches final result")
	_expect(str(game.get("outcome")) in ["胜利", "失败"], "has campaign outcome")
	_expect(int(game.get("exposure_spawns")) >= 0, "tracks exposure pressure")

	if failed:
		quit(1)
		return
	print("Last Radio defense v0.4 smoke test: PASS")
	quit(0)

func _advance(game: Node, seconds: float) -> void:
	var steps := int(seconds / 0.1)
	for i in range(steps):
		game.call("_debug_step", 0.1)

func _play_until_not_night(game: Node, max_steps: int) -> void:
	for i in range(max_steps):
		if str(game.get("phase")) != "night":
			return
		if i % 90 == 0:
			game.call("_use_radio_action", "jam")
		elif i % 90 == 30:
			game.call("_use_radio_action", "reroute")
		elif i % 90 == 60:
			game.call("_use_radio_action", "overload")
		game.call("_debug_step", 0.1)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Last Radio defense smoke test: FAIL - %s" % message)
	print("Last Radio defense smoke test: FAIL - %s" % message)
