extends SceneTree
# ARCHIVED — v0.5-era smoke test that drove NightShiftGame through a 10-night
# campaign using helpers like _debug_set_seed / _debug_step / nora_target_id /
# plank_cooldown / braced / director_event_count / story_beats. Those helpers
# and mechanics (Nora AI auto-repair, plank bracing, director pressure,
# five-second rhythm ticks) were removed when the game was rewritten to a
# single-script state machine (see scripts/NightShiftGame.gd header).
#
# The current smoke test lives in tools/night_shift_full_flow_test.gd and
# uses the real public API (_on_start_pressed / _show_night / _end_night /
# _update_night / etc.).
#
# This file is kept only as a reference for the legacy story-beat catalog
# (`_expect_story_catalog` / `_expect_story_timeline`) and intentionally
# short-circuits so it never runs.

const NightShiftLevels := preload("res://scripts/NightShiftLevels.gd")

var failed := false

func _initialize() -> void:
	print("SKIP: night_shift_smoke_test.gd is archived (see header).")
	print("      Use tools/night_shift_full_flow_test.gd for the current full-flow smoke.")
	quit(0)
	return
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	_expect(scene != null, "NightShiftGame scene loads")
	if scene == null:
		quit(1)
		return
	_expect_story_catalog()
	await _expect_story_timeline(scene)

	var game: Node = await _make_game(scene)
	var state: Dictionary = game.call("_debug_get_state") as Dictionary
	_expect(bool(game.call("_debug_final_assets_loaded")), "final night shift assets load")
	for event_id in ["nora_kit", "quiet_hours", "double_brace", "victor_cache", "cable_route"]:
		_expect(bool(game.call("_debug_upgrade_event_texture_loaded", event_id)), "upgrade event art loads for %s" % event_id)
	_expect(str(state.get("phase", "")) == "cover", "campaign starts from cover phase")
	_expect(game.call("_debug_start_campaign"), "cover starts campaign")
	state = game.call("_debug_get_state") as Dictionary
	_expect(str(state.get("phase", "")) == "day", "campaign starts in day phase")
	_expect(int(state.get("current_level", 0)) == 1, "starts at level 1")
	_expect(not ((state.get("unlocked_hotspots", []) as Array).has("right_window")), "right window is locked on level 1")
	_expect(not ((state.get("unlocked_hotspots", []) as Array).has("radio")), "radio is locked on level 1 tutorial")
	_expect(str(game.call("_debug_hotspot_texture_key", "front_door")) == "front_door_intact", "front door uses final intact art")

	_expect(game.call("_debug_set_seed", 101), "sets deterministic level 1 seed")
	_expect(game.call("_debug_choose_day", "start"), "starts first night from day panel")
	state = game.call("_debug_get_state") as Dictionary
	_expect(str(state.get("phase", "")) == "night", "day choice starts night phase")
	var first_schedule := state.get("night_schedule", {}) as Dictionary
	_expect(first_schedule.has("late_push"), "level 1 schedules late pressure")
	_expect(first_schedule.has("final_pressure"), "level 1 schedules final pressure")
	_expect(float(first_schedule.get("final_pressure", 0.0)) >= float(NightShiftLevels.get_level(0).get("duration", 90.0)) - 32.0, "final pressure lands in the last stretch")
	var second_sample := await _make_game(scene)
	_expect(second_sample.call("_debug_start_campaign"), "comparison sample starts campaign")
	_expect(second_sample.call("_debug_set_seed", 303), "sets comparison seed")
	_expect(second_sample.call("_debug_choose_day", "start"), "starts comparison night")
	var second_schedule := ((second_sample.call("_debug_get_state") as Dictionary).get("night_schedule", {}) as Dictionary)
	_expect(_schedules_differ(first_schedule, second_schedule), "different seeds produce different night schedules")
	second_sample.queue_free()
	_expect(game.call("_debug_click_hotspot", "front_door"), "clicks front door hotspot")
	_expect(str((game.call("_debug_get_state") as Dictionary).get("player_target_id", "")) == "front_door", "player target follows clicked hotspot")
	_expect(float((game.call("_debug_get_state") as Dictionary).get("time_scale", 0.0)) == 1.0, "night starts at normal time scale")
	var toggle_logs_before := ((game.call("_debug_get_state") as Dictionary).get("logs", []) as Array).size()
	_expect(game.call("_debug_toggle_time_scale"), "time scale toggles")
	_expect(float((game.call("_debug_get_state") as Dictionary).get("time_scale", 0.0)) == 2.0, "time scale can switch to 2x")
	var runtime_before := float((game.call("_debug_get_state") as Dictionary).get("time", 0.0))
	game.call("_debug_runtime_step", 1.0)
	var runtime_after := float((game.call("_debug_get_state") as Dictionary).get("time", 0.0))
	_expect(abs(runtime_after - runtime_before - 2.0) < 0.01, "2x runtime step advances game time twice as fast")
	_expect(game.call("_debug_toggle_time_scale"), "time scale toggles back")
	_expect(float((game.call("_debug_get_state") as Dictionary).get("time_scale", 0.0)) == 1.0, "time scale can return to 1x")
	var toggle_logs_after := ((game.call("_debug_get_state") as Dictionary).get("logs", []) as Array).size()
	_expect(toggle_logs_after == toggle_logs_before, "time scale toggle does not add log noise")

	var door_before := _hotspot_value(game, "front_door")
	_advance(game, 2.4)
	_expect(_hotspot_value(game, "front_door") > door_before, "working at the door repairs it")
	var rhythm_logs_before := ((game.call("_debug_get_state") as Dictionary).get("logs", []) as Array).size()
	_advance(game, 0.8)
	state = game.call("_debug_get_state") as Dictionary
	_expect(int(state.get("rhythm_tick_count", 0)) >= 1, "five-second rhythm tick runs")
	_expect(str(state.get("last_rhythm_kind", "")) != "", "rhythm tick records a beat type")
	_expect(((state.get("logs", []) as Array).size()) > rhythm_logs_before, "rhythm tick keeps the night from going silent")

	_force_hotspot(game, "generator", {"value": 0.0, "active": true, "pressure": 0.0})
	_advance(game, 0.2)
	_expect(bool((game.call("_debug_get_state") as Dictionary).get("blackout", false)), "generator reaching zero triggers blackout")
	_expect(str(game.call("_debug_hotspot_texture_key", "generator")) == "generator_blackout", "generator uses blackout art")
	_force_hotspot(game, "generator", {"value": 28.0, "active": true, "pressure": 0.0})
	_advance(game, 0.2)
	_expect(not bool((game.call("_debug_get_state") as Dictionary).get("blackout", false)), "repairing generator clears blackout")
	_expect(str(game.call("_debug_hotspot_texture_key", "generator")) == "generator_low_power", "generator uses low power art after blackout recovery")

	_expect(not bool(((game.call("_debug_get_state") as Dictionary).get("night_schedule", {}) as Dictionary).has("radio_call")), "level 1 tutorial has no radio call")
	_expect(not game.call("_debug_click_hotspot", "radio"), "level 1 radio hotspot is locked")

	_force_hotspot(game, "front_door", {"value": 100.0, "pressure": 0.0, "active": true, "breach_timer": -1.0, "assault": false, "warning": false})
	_force_hotspot(game, "left_window", {"value": 100.0, "pressure": 0.0, "active": false, "breach_timer": -1.0, "assault": false, "warning": false})
	_force_hotspot(game, "generator", {"value": 100.0, "pressure": 0.0, "active": true})
	_expect(game.call("_debug_click_hotspot", "front_door"), "player can hold a target before director event")
	game.set("night_elapsed", float((game.call("_debug_get_state") as Dictionary).get("next_director_time", 60.0)) - 0.1)
	_advance(game, 0.3)
	state = game.call("_debug_get_state") as Dictionary
	_expect(int(state.get("director_event_count", 0)) == 1, "director creates one level 1 side event")
	_expect(str(state.get("last_director_target", "")) != "front_door", "director avoids player's current target")

	game.set("night_elapsed", 59.9)
	_force_hotspot(game, "front_door", {"value": 100.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "left_window", {"value": 100.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "generator", {"value": 100.0, "active": true, "pressure": 0.0})
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 1 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from level 1 report")
	state = game.call("_debug_get_state") as Dictionary
	_expect(str(state.get("phase", "")) == "day", "continues to day phase after report")
	_expect(int(state.get("current_level", 0)) == 2, "continues to level 2")
	_expect(bool((state.get("allies", {}) as Dictionary).get("nora", false)), "Nora joins after surviving the tutorial night")

	_expect(game.call("_debug_set_seed", 202), "sets deterministic level 2 seed")
	_expect(game.call("_debug_choose_day", "window_brace"), "chooses a level 2 upgrade")
	_limit_random_events(game, ["right_window_warning", "right_window"])
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool((state.get("upgrades", {}) as Dictionary).get("window_brace", false)), "records selected upgrade")
	_expect((state.get("unlocked_hotspots", []) as Array).has("right_window"), "right window unlocks on level 2")
	game.set("night_elapsed", _schedule_time(game, "right_window_warning", 24.0) - 0.1)
	_advance(game, 0.3)
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool(((state.get("hotspots", {}) as Dictionary).get("right_window", {}) as Dictionary).get("warning", false)), "right window gets a warning before assault")
	_expect(str(game.call("_debug_hotspot_texture_key", "right_window")) == "window_warning", "right window uses warning art")
	_expect(game.call("_debug_click_hotspot", "right_window"), "player can respond to a warning before assault")
	_advance(game, 5.2)
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool(((state.get("hotspots", {}) as Dictionary).get("right_window", {}) as Dictionary).get("braced", false)), "responding early braces a warned window")
	_expect(str(game.call("_debug_hotspot_texture_key", "right_window")) == "window_braced", "right window uses braced art")
	_force_hotspot(game, "right_window", {"value": 100.0, "active": true, "warning": false, "braced": true, "assault": false, "pressure": 0.0, "temp_seal": 0.0})
	state = game.call("_debug_get_state") as Dictionary
	_expect(not bool(((state.get("hotspots", {}) as Dictionary).get("right_window", {}) as Dictionary).get("assault", false)), "braced warning prevents the scheduled assault")
	_force_hotspot(game, "right_window", {"value": 72.0, "active": true, "warning": false, "braced": false, "assault": true, "pressure": 3.0, "temp_seal": 0.0})
	game.set("player_target_id", "")
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool(((state.get("hotspots", {}) as Dictionary).get("right_window", {}) as Dictionary).get("assault", false)), "right window enters assault state")
	_expect(str(game.call("_debug_hotspot_texture_key", "right_window")) == "window_assault", "right window uses assault art")
	_expect(game.call("_debug_use_plank"), "emergency plank can be used during an assault")
	state = game.call("_debug_get_state") as Dictionary
	_expect(float(state.get("plank_cooldown", 0.0)) > 0.0, "emergency plank starts cooldown")
	_expect(float(((state.get("hotspots", {}) as Dictionary).get("right_window", {}) as Dictionary).get("temp_seal", 0.0)) > 0.0, "emergency plank applies a temporary seal")
	_expect(str(game.call("_debug_hotspot_texture_key", "right_window")) == "window_braced", "temporary seal uses braced window art")

	_limit_random_events(game, [])
	_force_hotspot(game, "left_window", {"value": 30.0, "active": true, "assault": true, "pressure": 0.0, "temp_seal": 0.0})
	_force_hotspot(game, "right_window", {"value": 36.0, "active": true, "pressure": 0.0})
	_expect(game.call("_debug_click_hotspot", "left_window"), "player targets one window")
	_advance(game, 0.2)
	state = game.call("_debug_get_state") as Dictionary
	_expect(str(state.get("nora_target_id", "")) == "right_window", "Nora avoids the player's current window when another window needs help")
	var right_before := _hotspot_value(game, "right_window")
	_advance(game, 9.0)
	_expect(_hotspot_value(game, "right_window") > right_before, "Nora repairs the damaged right window")

	game.set("night_elapsed", 119.9)
	_force_safe_level_2(game)
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 2 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from level 2 report")
	state = game.call("_debug_get_state") as Dictionary
	_expect(int(state.get("current_level", 0)) == 3, "continues to level 3")

	_expect(game.call("_debug_set_seed", 303), "sets deterministic level 3 seed")
	_expect(game.call("_debug_choose_day", "radio_booster"), "chooses a level 3 radio upgrade")
	game.set("night_elapsed", _schedule_time(game, "radio_call", 28.0) - 0.1)
	_force_hotspot(game, "front_door", {"value": 100.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "left_window", {"value": 100.0, "active": false, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "right_window", {"value": 100.0, "active": false, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "generator", {"value": 100.0, "active": true, "pressure": 0.0})
	_advance(game, 0.3)
	_expect(bool((game.call("_debug_get_state") as Dictionary).get("radio_available", false)), "level 3 radio call starts earlier")
	_expect(game.call("_debug_click_hotspot", "radio"), "clicks level 3 radio")
	_advance(game, 7.5)
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool((state.get("allies", {}) as Dictionary).get("elias", false)), "level 3 radio call unlocks Elias")

	game.set("night_elapsed", 179.9)
	_force_safe_level_3(game)
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 3 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from level 3 report")
	state = game.call("_debug_get_state") as Dictionary
	_expect(int(state.get("current_level", 0)) == 4, "continues to level 4")

	_expect(game.call("_debug_set_seed", 505), "sets deterministic level 4 seed")
	_expect(game.call("_debug_choose_day", "antenna_anchor"), "chooses a level 4 antenna upgrade")
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool((state.get("upgrades", {}) as Dictionary).get("antenna_anchor", false)), "records antenna upgrade")
	_expect((state.get("unlocked_hotspots", []) as Array).has("antenna"), "antenna unlocks on level 4")
	_force_hotspot(game, "antenna", {"value": 100.0, "active": false, "warning": false, "pressure": 0.0})
	game.set("night_elapsed", _schedule_time(game, "antenna_warning", 20.0) - 0.1)
	_advance(game, 0.3)
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool(((state.get("hotspots", {}) as Dictionary).get("antenna", {}) as Dictionary).get("active", false)), "level 4 antenna trouble starts")
	_expect(str(game.call("_debug_hotspot_texture_key", "antenna")) == "antenna_warning", "antenna uses active antenna art")
	_force_hotspot(game, "antenna", {"value": 24.0, "active": true, "warning": true, "pressure": 0.0})
	game.set("radio_available", true)
	game.set("radio_completed", false)
	game.set("player_target_id", "")
	_advance(game, 0.2)
	state = game.call("_debug_get_state") as Dictionary
	_expect(str(state.get("elias_target_id", "")) == "antenna", "Elias automatically protects the antenna")
	_expect(not game.call("_debug_click_hotspot", "radio"), "radio cannot be used while antenna signal is down")
	_expect(game.call("_debug_click_hotspot", "antenna"), "player can click the antenna hotspot")
	var antenna_before := _hotspot_value(game, "antenna")
	_advance(game, 4.0)
	_expect(_hotspot_value(game, "antenna") > antenna_before, "working at antenna restores signal")

	game.set("night_elapsed", 179.9)
	_force_safe_level_4(game)
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 4 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from level 4 report")
	state = game.call("_debug_get_state") as Dictionary
	_expect(int(state.get("current_level", 0)) == 5, "continues to level 5")

	_expect(game.call("_debug_set_seed", 606), "sets deterministic level 5 seed")
	_expect(game.call("_debug_choose_day", "command_routine"), "chooses a level 5 command upgrade")
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool((state.get("night_schedule", {}) as Dictionary).has("antenna_late")), "level 5 schedules a late antenna event")
	game.set("night_elapsed", _schedule_time(game, "antenna_late", 92.0) - 0.1)
	_force_safe_level_5(game)
	_advance(game, 0.3)
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool(((state.get("hotspots", {}) as Dictionary).get("antenna", {}) as Dictionary).get("active", false)), "level 5 repeats antenna pressure")
	game.set("night_elapsed", 179.9)
	_force_safe_level_5(game)
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 5 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from final report")
	state = game.call("_debug_get_state") as Dictionary
	_expect(int(state.get("current_level", 0)) == 6, "continues to level 6")

	_expect(game.call("_debug_set_seed", 707), "sets deterministic level 6 seed")
	_expect(game.call("_debug_choose_day", "back_door_bar"), "chooses a level 6 back door upgrade")
	state = game.call("_debug_get_state") as Dictionary
	_expect((state.get("unlocked_hotspots", []) as Array).has("back_door"), "back door unlocks on level 6")
	game.set("night_elapsed", _schedule_time(game, "back_door_warning", 36.0) - 0.1)
	_advance(game, 0.3)
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool(((state.get("hotspots", {}) as Dictionary).get("back_door", {}) as Dictionary).get("warning", false)), "level 6 back door warning starts")
	_expect(str(game.call("_debug_hotspot_texture_key", "back_door")) == "back_door_warning", "back door uses door warning art")
	game.set("night_elapsed", 179.9)
	_force_safe_level(game)
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 6 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from level 6 report")

	_expect(game.call("_debug_set_seed", 808), "sets deterministic level 7 seed")
	_expect(game.call("_debug_choose_day", "medbay_lamp"), "chooses a level 7 medbay upgrade")
	state = game.call("_debug_get_state") as Dictionary
	_expect((state.get("unlocked_hotspots", []) as Array).has("medbay"), "medbay unlocks on level 7")
	game.set("night_elapsed", _schedule_time(game, "medbay_call", 54.0) - 0.1)
	_advance(game, 0.3)
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool(((state.get("hotspots", {}) as Dictionary).get("medbay", {}) as Dictionary).get("active", false)), "level 7 medbay trouble starts")
	_expect(str(game.call("_debug_hotspot_texture_key", "medbay")) == "medbay_warning", "medbay uses warning art")
	_expect(game.call("_debug_click_hotspot", "medbay"), "player can click the medbay hotspot")
	_advance(game, 0.2)
	_expect(str(game.call("_debug_hotspot_texture_key", "medbay")) == "medbay_treating", "medbay uses treating art while handled")
	game.set("night_elapsed", 179.9)
	_force_safe_level(game)
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 7 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from level 7 report")

	_expect(game.call("_debug_set_seed", 909), "sets deterministic level 8 seed")
	_expect(game.call("_debug_choose_day", "salvage_planks"), "chooses a level 8 storage upgrade")
	state = game.call("_debug_get_state") as Dictionary
	_expect((state.get("unlocked_hotspots", []) as Array).has("storage"), "storage unlocks on level 8")
	game.set("night_elapsed", _schedule_time(game, "storage_shortage", 44.0) - 0.1)
	_advance(game, 0.3)
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool(((state.get("hotspots", {}) as Dictionary).get("storage", {}) as Dictionary).get("active", false)), "level 8 storage trouble starts")
	_expect(str(game.call("_debug_hotspot_texture_key", "storage")) == "storage_shortage", "storage uses shortage art")
	_expect(game.call("_debug_click_hotspot", "storage"), "player can click the storage hotspot")
	_advance(game, 0.2)
	_expect(str(game.call("_debug_hotspot_texture_key", "storage")) == "storage_repairing", "storage uses repairing art while handled")
	game.set("night_elapsed", 179.9)
	_force_safe_level(game)
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 8 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from level 8 report")

	_expect(game.call("_debug_set_seed", 1001), "sets deterministic level 9 seed")
	_expect(game.call("_debug_choose_day", "signal_battery"), "chooses a level 9 signal upgrade")
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool((state.get("night_schedule", {}) as Dictionary).has("antenna_blackout_link")), "level 9 schedules electric signal link")
	game.set("night_elapsed", 179.9)
	_force_safe_level(game)
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 9 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from level 9 report")

	_expect(game.call("_debug_set_seed", 1111), "sets deterministic level 10 seed")
	_expect(game.call("_debug_choose_day", "all_hands"), "chooses a level 10 final upgrade")
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool((state.get("night_schedule", {}) as Dictionary).has("final_wave")), "level 10 schedules final wave")
	game.set("night_elapsed", _schedule_time(game, "final_wave", 124.0) - 0.1)
	_force_safe_level(game)
	_advance(game, 0.3)
	state = game.call("_debug_get_state") as Dictionary
	_expect(bool(((state.get("hotspots", {}) as Dictionary).get("front_door", {}) as Dictionary).get("assault", false)), "level 10 final wave hits barriers")
	game.set("night_elapsed", 179.9)
	_force_safe_level(game)
	_advance(game, 0.3)
	_expect(str(game.get("phase")) == "report", "level 10 reaches report")
	_expect(game.call("_debug_continue_report"), "continues from final report")
	_expect(str(game.get("phase")) == "final", "campaign reaches v0.5 ten-night final")
	state = game.call("_debug_get_state") as Dictionary
	var final_text := str(state.get("result_text", ""))
	_expect(final_text.find("Victor") >= 0, "final story names Victor")
	_expect(final_text.find("Nora") >= 0 and final_text.find("Elias") >= 0, "final story keeps Nora and Elias alive")
	_expect(final_text.find("接住") >= 0, "final story says the channel is carried forward")

	game.queue_free()
	game = await _make_game(scene)
	_expect(game.call("_debug_start_campaign"), "failure sample starts campaign")
	_expect(game.call("_debug_set_seed", 404), "sets deterministic failure seed")
	_expect(game.call("_debug_choose_day", "start"), "restart sample night")
	_force_hotspot(game, "front_door", {"value": 0.0, "active": true, "pressure": 0.0, "breach_timer": 0.0})
	_advance(game, 10.3)
	_expect(str(game.get("phase")) == "report", "door breach countdown reports a failed night")
	state = game.call("_debug_get_state") as Dictionary
	_expect(str(state.get("outcome", "")) == "failure", "failed report tracks failure outcome")
	_expect(str(state.get("result_text", "")).find("Nora") >= 0, "failed report uses night-specific story text")

	if failed:
		quit(1)
		return
	print("Last Radio night shift v0.5 smoke test: PASS")
	quit(0)

func _make_game(scene: PackedScene) -> Node:
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	return game

func _advance(game: Node, seconds: float) -> void:
	var steps := int(ceil(seconds / 0.1))
	for i in range(steps):
		var remaining: float = max(0.0, seconds - float(i) * 0.1)
		game.call("_debug_step", min(0.1, remaining))

func _advance_story_safe(game: Node, seconds: float) -> void:
	var steps := int(ceil(seconds / 0.5))
	for i in range(steps):
		var remaining: float = max(0.0, seconds - float(i) * 0.5)
		game.call("_debug_step", min(0.5, remaining))
		_force_hotspot(game, "front_door", {"value": 120.0, "active": true, "pressure": 0.0, "breach_timer": -1.0, "assault": false, "warning": false})
		_force_hotspot(game, "left_window", {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0, "assault": false, "warning": false})
		_force_hotspot(game, "right_window", {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0, "assault": false, "warning": false})
		_force_hotspot(game, "generator", {"value": 100.0, "active": true, "pressure": 0.0})

func _expect_story_catalog() -> void:
	for i in range(NightShiftLevels.count()):
		var level := NightShiftLevels.get_level(i)
		var label := "level %d story" % (i + 1)
		_expect(str(level.get("story_intro", "")).length() > 12, "%s has an intro" % label)
		_expect((level.get("story_start", []) as Array).size() >= 1, "%s has night start lines" % label)
		var beats := level.get("story_beats", []) as Array
		_expect(beats.size() == 3, "%s has three story beats" % label)
		for beat_index in range(beats.size()):
			var beat := beats[beat_index] as Dictionary
			_expect(str(beat.get("id", "")) != "", "%s beat %d has id" % [label, beat_index + 1])
			_expect(abs(float(beat.get("at_ratio", 0.0)) - [0.18, 0.50, 0.78][beat_index]) < 0.001, "%s beat %d uses expected timing" % [label, beat_index + 1])
			_expect(str(beat.get("text", "")).length() > 12, "%s beat %d has text" % [label, beat_index + 1])
		_expect(str(level.get("success_report", "")).length() > 12, "%s has success report" % label)
		_expect(str(level.get("failure_report", "")).length() > 12, "%s has failure report" % label)

func _expect_story_timeline(scene: PackedScene) -> void:
	var game := await _make_game(scene)
	_expect(game.call("_debug_start_campaign"), "story sample starts campaign")
	_expect(game.call("_debug_set_seed", 515), "story sample seed set")
	_expect(game.call("_debug_choose_day", "start"), "story sample starts first night")
	var level := NightShiftLevels.get_level(0)
	var duration := float(level.get("duration", 105.0))
	var beats := level.get("story_beats", []) as Array
	_advance_story_safe(game, duration * 0.20)
	var state := game.call("_debug_get_state") as Dictionary
	_expect(_logs_contain(state.get("logs", []) as Array, str((beats[0] as Dictionary).get("text", ""))), "first story beat fires by 20 percent")
	_advance_story_safe(game, duration * 0.35)
	state = game.call("_debug_get_state") as Dictionary
	_expect(_logs_contain(state.get("logs", []) as Array, str((beats[1] as Dictionary).get("text", ""))), "second story beat fires by 55 percent")
	_advance_story_safe(game, duration * 0.25)
	state = game.call("_debug_get_state") as Dictionary
	_expect(_logs_contain(state.get("logs", []) as Array, str((beats[2] as Dictionary).get("text", ""))), "third story beat fires by 80 percent")
	_expect(_log_occurrences(state.get("logs", []) as Array, str((beats[0] as Dictionary).get("text", ""))) == 1, "story beats do not repeat")
	game.queue_free()

func _logs_contain(log_values: Array, needle: String) -> bool:
	for entry in log_values:
		if str(entry).find(needle) >= 0:
			return true
	return false

func _log_occurrences(log_values: Array, needle: String) -> int:
	var count := 0
	for entry in log_values:
		if str(entry).find(needle) >= 0:
			count += 1
	return count

func _force_safe_level_2(game: Node) -> void:
	_force_hotspot(game, "front_door", {"value": 120.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "left_window", {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "right_window", {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "generator", {"value": 100.0, "active": true, "pressure": 0.0})

func _force_safe_level_3(game: Node) -> void:
	_force_hotspot(game, "front_door", {"value": 120.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "left_window", {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "right_window", {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "generator", {"value": 100.0, "active": true, "pressure": 0.0})

func _force_safe_level_4(game: Node) -> void:
	_force_hotspot(game, "front_door", {"value": 120.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "left_window", {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "right_window", {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0})
	_force_hotspot(game, "generator", {"value": 100.0, "active": true, "pressure": 0.0})
	_force_hotspot(game, "antenna", {"value": 115.0, "active": false, "warning": false, "pressure": 0.0})
	game.set("radio_available", false)
	game.set("radio_completed", true)

func _force_safe_level_5(game: Node) -> void:
	_force_safe_level_4(game)

func _force_safe_level(game: Node) -> void:
	var state := game.call("_debug_get_state") as Dictionary
	var unlocked := state.get("unlocked_hotspots", []) as Array
	for id in unlocked:
		var id_text := str(id)
		match id_text:
			"front_door", "back_door":
				_force_hotspot(game, id_text, {"value": 120.0, "active": true, "pressure": 0.0, "breach_timer": -1.0, "assault": false, "warning": false, "temp_seal": 0.0})
			"left_window", "right_window":
				_force_hotspot(game, id_text, {"value": 115.0, "active": true, "pressure": 0.0, "breach_timer": -1.0, "assault": false, "warning": false, "temp_seal": 0.0})
			"generator":
				_force_hotspot(game, id_text, {"value": 115.0, "active": true, "pressure": 0.0})
			"antenna":
				_force_hotspot(game, id_text, {"value": 115.0, "active": false, "warning": false, "pressure": 0.0})
			"medbay", "storage":
				_force_hotspot(game, id_text, {"value": 100.0, "active": false, "warning": false, "pressure": 0.0})
	game.set("radio_available", false)
	game.set("radio_completed", true)
	game.set("blackout", false)

func _force_hotspot(game: Node, id: String, patch: Dictionary) -> void:
	var hotspots := game.get("hotspots") as Dictionary
	var data := hotspots[id] as Dictionary
	for key in patch.keys():
		data[key] = patch[key]
	hotspots[id] = data
	game.set("hotspots", hotspots)

func _clear_event_flags(game: Node, ids: Array[String]) -> Dictionary:
	var events := game.get("events_done") as Dictionary
	for id in ids:
		events.erase(id)
	return events

func _limit_random_events(game: Node, allowed_ids: Array[String]) -> void:
	var state := game.call("_debug_get_state") as Dictionary
	var schedule := state.get("night_schedule", {}) as Dictionary
	var filtered := []
	for event in schedule.get("random_events", []) as Array:
		var data := event as Dictionary
		if allowed_ids.has(str(data.get("id", ""))):
			filtered.append(data)
	schedule["random_events"] = filtered
	game.set("night_schedule", schedule)

func _hotspot_value(game: Node, id: String) -> float:
	var hotspots := game.get("hotspots") as Dictionary
	var data := hotspots[id] as Dictionary
	return float(data.get("value", 0.0))

func _schedule_time(game: Node, id: String, fallback: float) -> float:
	var state := game.call("_debug_get_state") as Dictionary
	var schedule := state.get("night_schedule", {}) as Dictionary
	return float(schedule.get(id, fallback))

func _schedules_differ(first: Dictionary, second: Dictionary) -> bool:
	for id in ["generator_flicker", "left_window_warning", "left_window", "radio_call", "hard_push"]:
		if abs(float(first.get(id, 0.0)) - float(second.get(id, 0.0))) > 0.01:
			return true
	return false

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Last Radio night shift smoke test: FAIL - %s" % message)
	print("Last Radio night shift smoke test: FAIL - %s" % message)
