extends SceneTree

var failed := false

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/BaseScreen.tscn") as PackedScene
	_expect(scene != null, "BaseScreen scene loads")
	if scene == null:
		quit(1)
		return
	var screen: Node = scene.instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame

	var overlay_layer: Control = screen.get("overlay_layer")
	_expect(overlay_layer != null and overlay_layer.get_child_count() > 0, "intro briefing appears")
	var intro_text := _visible_label_text(overlay_layer)
	_expect(intro_text.find("停电第六天") >= 0 and intro_text.find("旧体育馆") >= 0 and intro_text.find("radio officer") >= 0, "intro explains apocalypse setup and player identity")
	_expect(intro_text.find("第一班只做一件事") >= 0, "intro gives a simple first job")
	if screen.has_method("_dismiss_intro_briefing"):
		screen.call("_dismiss_intro_briefing")
		await process_frame
		_expect(overlay_layer.get_child_count() == 0, "intro briefing can be dismissed")
	_expect((screen.get("members") as Dictionary).size() == 4, "loads 4 members")
	_expect(str(((screen.get("members") as Dictionary)["shen_luo"] as Dictionary).get("name", "")) == "Elias Reed", "member display names are English")
	_expect((screen.get("locations") as Dictionary).size() == 5, "loads 5 locations")
	_expect((screen.get("items") as Dictionary).size() == 4, "loads 4 items")
	_expect((screen.get("signals") as Array).size() == 9, "loads 9 signals")
	var operation_track = screen.get("operation_track")
	_expect(operation_track != null, "operation track exists")
	if operation_track != null:
		_expect(int(operation_track.call("_active_step")) == 0, "operation track starts at tuning step")
	var status_label: Label = screen.get("status_label")
	_expect(status_label != null and status_label.text.find("今日委托") >= 0, "objective strip shows daily directive")
	var contextual_signals: Array = screen.call("_tuning_signals_with_context")
	_expect(int((contextual_signals[0] as Dictionary).get("urgency", 0)) >= 4, "rescue signal gets high urgency")
	_expect(str((contextual_signals[0] as Dictionary).get("ignore_preview", "")).find("Mara Vale压力") >= 0, "rescue signal shows ignored consequence")
	var story_scene_screen: Node = scene.instantiate()
	root.add_child(story_scene_screen)
	await process_frame
	var story_signal: Dictionary = (story_scene_screen.get("day_signals") as Array)[0]
	var story_signal_id := str(story_signal.get("id", ""))
	_expect(not story_scene_screen.call("_confirm_signal", story_signal_id), "radio call confirmation requires a locked story signal")
	story_scene_screen.call("_lock_signal", story_signal_id)
	var confirm_members: Array[String] = ["a_qing"]
	var confirm_items: Array[String] = ["radio"]
	var preview_before_confirm: Dictionary = story_scene_screen.call("_dispatch_preview", confirm_members, confirm_items, "route_warning", "safe")
	_expect(story_scene_screen.call("_confirm_signal", story_signal_id), "radio call confirmation can be recorded")
	var confirmations: Dictionary = story_scene_screen.get("signal_confirmations")
	_expect(str((confirmations.get(story_signal_id, {}) as Dictionary).get("flag", "")) == "confirmed_by_call", "radio call confirmation stores its effect flag")
	var confirmed_signals: Array = story_scene_screen.call("_tuning_signals_with_context")
	_expect(bool((confirmed_signals[0] as Dictionary).get("confirmed_by_call", false)), "tuning context carries confirmed story call")
	var preview_after_confirm: Dictionary = story_scene_screen.call("_dispatch_preview", confirm_members, confirm_items, "route_warning", "safe")
	_expect(int(preview_after_confirm.get("score", 0)) == int(preview_before_confirm.get("score", 0)) + 6, "confirmed call improves hidden dispatch score")
	_expect(_reasons_include(preview_after_confirm, "呼叫确认 +6"), "confirmed call remains visible in detailed ledger reasons")
	story_scene_screen.queue_free()
	var tuning_scene: PackedScene = load("res://scenes/RadioTuningPanel.tscn") as PackedScene
	_expect(tuning_scene != null, "RadioTuningPanel scene loads")
	if tuning_scene != null:
		var tuning_panel: Node = tuning_scene.instantiate()
		root.add_child(tuning_panel)
		tuning_panel.call("setup", contextual_signals, screen.get("locked_signal_ids"), screen.get("listen_time"))
		tuning_panel.call("_select_signal_by_ratio", 0.95)
		_expect(str(tuning_panel.get("selected_signal_id")) != "", "tuning panel selects a frequency point")
		var signal_image: TextureRect = tuning_panel.get("selected_signal_image")
		_expect(signal_image != null and signal_image.texture != null and signal_image.custom_minimum_size.y > 0.0, "tuning panel shows selected signal image")
		var first_context_signal: Dictionary = contextual_signals[0]
		var refined_context := first_context_signal.duplicate(true)
		refined_context["refined_count"] = 1
		_expect(str(refined_context.get("refined_count", "")) == "1", "context signal can carry refined state")
		tuning_panel.call("_mark_signal", str(first_context_signal.get("id", "")), "trusted")
		_expect(str((tuning_panel.get("signal_marks") as Dictionary).get(str(first_context_signal.get("id", "")), "")) == "trusted", "tuning panel stores intel judgment marks")
		tuning_panel.queue_free()
	var city_scene: PackedScene = load("res://scenes/CityMapScreen.tscn") as PackedScene
	_expect(city_scene != null, "CityMapScreen scene loads")
	if city_scene != null:
		var city_panel: Node = city_scene.instantiate()
		root.add_child(city_panel)
		(city_panel as Control).size = Vector2(720, 430)
		var city_action_defs := {
			"warn": {"name": "广播预警", "cost": {"influence": 1}, "risk": -4, "danger_trend": -1, "trust": 1, "flag": "warned"},
			"route_mark": {"name": "投放路标", "cost": {"parts": 1}, "risk": -8, "flag": "route_marked"},
			"cache": {"name": "补给缓存", "cost": {"food": 1}, "risk": -3, "supplies_left": 1, "flag": "supply_cache"}
		}
		city_panel.call("setup", screen.get("locations"), "north_bridge", contextual_signals, ["d1_north_bridge_help"], {"d1_north_bridge_help": "trusted"}, screen.get("resources"), city_action_defs)
		_expect(city_panel.get("city_board") != null, "city map has a drawn board")
		_expect((city_panel.call("_signals_for_location", "north_bridge") as Array).size() == 1, "city map receives signal pins for target nodes")
		var signal_summary := str(city_panel.call("_location_signal_summary", "north_bridge"))
		_expect(signal_summary.find("已锁") >= 0 and signal_summary.find("可信") >= 0, "city detail shows locked intel judgment")
		var board: Control = city_panel.get("city_board")
		board.size = Vector2(480, 340)
		_expect(str(board.call("_node_at", Vector2(0.82 * 480.0, 0.55 * 340.0))) == "garage", "city map hit tests a location node")
		city_panel.call("_select_location_on_board", "garage")
		_expect(str(city_panel.get("selected_location_id")) == "garage", "city map selection updates")
		_expect(str(city_panel.call("_city_action_effect_text", "route_mark")).find("件-1") >= 0, "city map shows node action costs")
		await process_frame
		var detail_box: Control = city_panel.get("detail_box")
		_expect(detail_box.get_global_rect().end.x <= (city_panel as Control).get_global_rect().end.x + 1.0, "city detail panel stays inside city screen")
		_expect(_visible_buttons_do_not_overlap(city_panel), "city action buttons do not overlap")
		_expect(_visible_buttons_have_min_width(city_panel, 90.0), "city action buttons keep readable width")
		city_panel.queue_free()
	var force_scene_screen: Node = scene.instantiate()
	root.add_child(force_scene_screen)
	await process_frame
	var force_signals: Array = force_scene_screen.get("day_signals")
	var expensive_signal: Dictionary = force_signals[2]
	force_scene_screen.set("listen_time", 0)
	var force_resources: Dictionary = force_scene_screen.get("resources")
	var power_before := int(force_resources.get("power", 0))
	var threat_before := int(force_resources.get("threat", 0))
	force_scene_screen.call("_lock_signal", str(expensive_signal.get("id", "")))
	_expect(not (force_scene_screen.get("locked_signal_ids") as Array).has(str(expensive_signal.get("id", ""))), "normal lock respects listen time")
	_expect(force_scene_screen.call("_force_lock_signal", str(expensive_signal.get("id", ""))), "force lock can bypass listen time")
	_expect((force_scene_screen.get("locked_signal_ids") as Array).has(str(expensive_signal.get("id", ""))), "force lock adds locked signal")
	_expect(int(force_resources.get("power", 0)) == power_before - 1, "force lock spends power")
	_expect(int(force_resources.get("threat", 0)) == threat_before + 1, "force lock raises exposure")
	force_scene_screen.queue_free()

	var refine_scene_screen: Node = scene.instantiate()
	root.add_child(refine_scene_screen)
	await process_frame
	var refine_signals: Array = refine_scene_screen.get("day_signals")
	var refine_signal: Dictionary = refine_signals[2]
	refine_scene_screen.set("selected_location_id", str(refine_signal.get("location", "")))
	var refine_members: Array[String] = ["a_qing"]
	var refine_items: Array[String] = ["radio"]
	var refine_preview_before: Dictionary = refine_scene_screen.call("_dispatch_preview", refine_members, refine_items, "route_warning", "safe")
	var refine_noise_before := int(refine_signal.get("noise", 0))
	var refine_listen_before := int(refine_scene_screen.get("listen_time"))
	_expect(refine_scene_screen.call("_refine_signal", str(refine_signal.get("id", ""))), "can refine a noisy signal before lock")
	var refine_preview_after: Dictionary = refine_scene_screen.call("_dispatch_preview", refine_members, refine_items, "route_warning", "safe")
	_expect(int(refine_signal.get("noise", 0)) == max(0, refine_noise_before - 15), "refine signal lowers noise")
	_expect(int(refine_scene_screen.get("listen_time")) == refine_listen_before - 1, "refine signal spends listen time")
	_expect(int(refine_preview_after.get("score", 0)) > int(refine_preview_before.get("score", 0)), "refined signal improves dispatch preview")
	refine_scene_screen.call("_lock_signal", str(refine_signal.get("id", "")))
	_expect(not refine_scene_screen.call("_refine_signal", str(refine_signal.get("id", ""))), "locked signal cannot be refined again")
	refine_scene_screen.queue_free()

	var prep_scene_screen: Node = scene.instantiate()
	root.add_child(prep_scene_screen)
	await process_frame
	var prep_signals: Array = prep_scene_screen.get("day_signals")
	var prep_signal: Dictionary = prep_signals[0]
	prep_scene_screen.call("_lock_signal", str(prep_signal.get("id", "")))
	var prep_members: Array[String] = ["a_qing"]
	var prep_items: Array[String] = []
	var no_prep_preview: Dictionary = prep_scene_screen.call("_dispatch_preview", prep_members, prep_items, "route_warning", "safe", "none")
	var hot_meal_preview: Dictionary = prep_scene_screen.call("_dispatch_preview", prep_members, prep_items, "route_warning", "safe", "hot_meal")
	_expect(int(hot_meal_preview.get("score", 0)) == int(no_prep_preview.get("score", 0)) + 8, "hot meal prep raises dispatch score")
	_expect(_reasons_include(hot_meal_preview, "热食动员 +8"), "prep score reason is visible")
	var prep_resources: Dictionary = prep_scene_screen.get("resources")
	var food_before := int(prep_resources.get("food", 0))
	prep_scene_screen.call("_launch_dispatch", prep_members, prep_items, "route_warning", "safe", "hot_meal")
	_expect(str((prep_scene_screen.get("last_dispatch_result") as Dictionary).get("prep_id", "")) == "hot_meal", "dispatch result records prep")
	_expect(int(prep_resources.get("food", 0)) == food_before - 1, "prep spends resource on launch")
	prep_scene_screen.queue_free()
	var policy_scene_screen: Node = scene.instantiate()
	root.add_child(policy_scene_screen)
	await process_frame
	var policy_signals: Array = policy_scene_screen.get("day_signals")
	var policy_signal: Dictionary = policy_signals[0]
	policy_scene_screen.call("_lock_signal", str(policy_signal.get("id", "")))
	var policy_members: Array[String] = ["a_qing"]
	var policy_items: Array[String] = []
	policy_scene_screen.call("_launch_dispatch", policy_members, policy_items, "route_warning", "safe")
	_expect(policy_scene_screen.call("_set_night_policy", "full_power"), "can set full power night policy")
	var policy_resources: Dictionary = policy_scene_screen.get("resources")
	var policy_power_before := int(policy_resources.get("power", 0))
	var policy_influence_before := int(policy_resources.get("influence", 0))
	policy_scene_screen.call("_night_lines")
	_expect(int(policy_resources.get("power", 0)) == policy_power_before - 2, "full power policy increases night power cost")
	_expect(int(policy_resources.get("influence", 0)) == policy_influence_before + 1, "full power policy increases influence")
	_expect(int(policy_scene_screen.get("next_day_listen_bonus")) == 1, "full power policy stores next day listen bonus")
	policy_scene_screen.call("_start_day", 2)
	_expect(int(policy_scene_screen.get("listen_time")) == 4, "full power policy boosts next day listen time")
	policy_scene_screen.queue_free()
	var watch_scene_screen: Node = scene.instantiate()
	root.add_child(watch_scene_screen)
	await process_frame
	watch_scene_screen.set("pending_crisis", {})
	watch_scene_screen.set("current_directive", {})
	watch_scene_screen.set("last_dispatch_result", {
		"summary": "测试外勤回传。",
		"quality": "success",
		"location_id": "north_bridge",
		"signal_id": "d1_north_bridge_help"
	})
	var watch_resources: Dictionary = watch_scene_screen.get("resources")
	var watch_members: Dictionary = watch_scene_screen.get("members")
	var watch_food_before := int(watch_resources.get("food", 0))
	_expect(watch_scene_screen.call("_set_night_watch_member", "lao_zhou"), "can assign a night watch member")
	watch_scene_screen.call("_night_lines")
	_expect(int(watch_resources.get("food", 0)) == watch_food_before - 1, "Lao Zhou night watch reduces food consumption")
	_expect(int((watch_members["lao_zhou"] as Dictionary).get("stress", 0)) == 5, "night watch adds stress to assigned member")
	watch_scene_screen.call("_start_day", 1)
	watch_scene_screen.set("pending_crisis", {})
	watch_scene_screen.set("current_directive", {})
	watch_scene_screen.set("last_dispatch_result", {
		"summary": "测试外勤回传。",
		"quality": "success",
		"location_id": "north_bridge",
		"signal_id": "d1_north_bridge_help"
	})
	watch_scene_screen.call("_set_night_policy", "full_power")
	watch_scene_screen.call("_set_night_watch_member", "shen_luo")
	watch_scene_screen.call("_night_lines")
	_expect(int(watch_scene_screen.get("next_day_listen_bonus")) == 2, "Elias night watch stacks with full power listening")
	watch_scene_screen.call("_start_day", 2)
	_expect(int(watch_scene_screen.get("listen_time")) == 5, "stacked night listening affects next day")
	watch_scene_screen.queue_free()

	var shelter_scene_screen: Node = scene.instantiate()
	root.add_child(shelter_scene_screen)
	await process_frame
	shelter_scene_screen.set("pending_crisis", {})
	shelter_scene_screen.set("current_directive", {})
	shelter_scene_screen.set("last_dispatch_result", {
		"summary": "测试外勤回传。",
		"quality": "success",
		"location_id": "north_bridge",
		"signal_id": "d1_north_bridge_help"
	})
	var shelter_locations: Dictionary = shelter_scene_screen.get("locations")
	for shelter_location_id in shelter_locations.keys():
		if str(shelter_location_id) != "base":
			(shelter_locations[shelter_location_id] as Dictionary)["people_left"] = 0
	var shelter_resources: Dictionary = shelter_scene_screen.get("resources")
	shelter_resources["food"] = 10
	shelter_resources["rescued"] = 4
	var shelter_lines: Array = shelter_scene_screen.call("_night_lines")
	var shelter_summary: Dictionary = shelter_scene_screen.get("night_report_summary")
	_expect(int(shelter_resources.get("food", 0)) == 6, "rescued survivors add shelter food pressure")
	_expect(_array_text_includes(shelter_lines, "安置压力"), "shelter pressure appears in night report")
	_expect(int((shelter_summary.get("resource_delta", {}) as Dictionary).get("food", 0)) == -4, "night summary includes shelter food delta")
	shelter_scene_screen.queue_free()

	var shelter_policy_scene_screen: Node = scene.instantiate()
	root.add_child(shelter_policy_scene_screen)
	await process_frame
	shelter_policy_scene_screen.set("pending_crisis", {})
	shelter_policy_scene_screen.set("current_directive", {})
	shelter_policy_scene_screen.set("last_dispatch_result", {
		"summary": "测试外勤回传。",
		"quality": "success",
		"location_id": "north_bridge",
		"signal_id": "d1_north_bridge_help"
	})
	var shelter_policy_locations: Dictionary = shelter_policy_scene_screen.get("locations")
	for shelter_policy_location_id in shelter_policy_locations.keys():
		if str(shelter_policy_location_id) != "base":
			(shelter_policy_locations[shelter_policy_location_id] as Dictionary)["people_left"] = 0
	var shelter_policy_resources: Dictionary = shelter_policy_scene_screen.get("resources")
	var shelter_policy_members: Dictionary = shelter_policy_scene_screen.get("members")
	shelter_policy_resources["food"] = 10
	shelter_policy_resources["power"] = 8
	shelter_policy_resources["trust"] = 20
	shelter_policy_resources["rescued"] = 4
	(shelter_policy_members["a_qing"] as Dictionary)["stress"] = 10
	_expect(shelter_policy_scene_screen.call("_set_night_policy", "shelter"), "can set shelter night policy")
	_expect(str(shelter_policy_scene_screen.call("_night_policy_effect_text", "shelter")).find("安-2") >= 0, "shelter night policy shows shelter relief")
	var shelter_policy_lines: Array = shelter_policy_scene_screen.call("_night_lines")
	_expect(int(shelter_policy_resources.get("food", 0)) == 8, "shelter policy relieves rescued survivor food pressure")
	_expect(int(shelter_policy_resources.get("power", 0)) == 6, "shelter policy costs extra power")
	_expect(int(shelter_policy_resources.get("trust", 0)) == 21, "shelter policy improves trust")
	_expect(int((shelter_policy_members["a_qing"] as Dictionary).get("stress", 0)) == 8, "shelter policy lowers member stress")
	_expect(_array_text_includes(shelter_policy_lines, "安置值守"), "shelter policy appears in night report")
	shelter_policy_scene_screen.queue_free()

	var infirmary_shelter_scene_screen: Node = scene.instantiate()
	root.add_child(infirmary_shelter_scene_screen)
	await process_frame
	infirmary_shelter_scene_screen.set("pending_crisis", {})
	infirmary_shelter_scene_screen.set("current_directive", {})
	infirmary_shelter_scene_screen.set("last_dispatch_result", {
		"summary": "测试外勤回传。",
		"quality": "success",
		"location_id": "north_bridge",
		"signal_id": "d1_north_bridge_help"
	})
	var infirmary_locations: Dictionary = infirmary_shelter_scene_screen.get("locations")
	for infirmary_location_id in infirmary_locations.keys():
		if str(infirmary_location_id) != "base":
			(infirmary_locations[infirmary_location_id] as Dictionary)["people_left"] = 0
	var infirmary_resources: Dictionary = infirmary_shelter_scene_screen.get("resources")
	var infirmary_upgrades: Dictionary = infirmary_shelter_scene_screen.get("base_upgrades")
	infirmary_resources["food"] = 10
	infirmary_resources["rescued"] = 0
	infirmary_upgrades["infirmary"] = 1
	_expect(int(infirmary_shelter_scene_screen.call("_base_shelter_relief")) == 1, "infirmary upgrade adds shelter relief")
	var infirmary_preview_members: Array[String] = ["a_qing"]
	var infirmary_preview_items: Array[String] = ["radio"]
	var infirmary_preview: Dictionary = infirmary_shelter_scene_screen.call("_dispatch_preview", infirmary_preview_members, infirmary_preview_items, "route_warning", "safe")
	var infirmary_preview_shelter: Dictionary = infirmary_preview.get("shelter", {})
	_expect(int(infirmary_preview_shelter.get("success_extra_food", -1)) == 0, "infirmary upgrade lowers dispatch shelter projection")
	infirmary_resources["rescued"] = 4
	var infirmary_lines: Array = infirmary_shelter_scene_screen.call("_night_lines")
	_expect(int(infirmary_resources.get("food", 0)) == 7, "infirmary upgrade reduces shelter food pressure at night")
	_expect(_array_text_includes(infirmary_lines, "医务角安置"), "infirmary shelter relief appears in night report")
	infirmary_shelter_scene_screen.queue_free()

	var shortage_scene_screen: Node = scene.instantiate()
	root.add_child(shortage_scene_screen)
	await process_frame
	shortage_scene_screen.set("pending_crisis", {})
	shortage_scene_screen.set("current_directive", {})
	shortage_scene_screen.set("last_dispatch_result", {
		"summary": "测试外勤回传。",
		"quality": "success",
		"location_id": "north_bridge",
		"signal_id": "d1_north_bridge_help"
	})
	var shortage_locations: Dictionary = shortage_scene_screen.get("locations")
	for shortage_location_id in shortage_locations.keys():
		if str(shortage_location_id) != "base":
			(shortage_locations[shortage_location_id] as Dictionary)["people_left"] = 0
	var shortage_resources: Dictionary = shortage_scene_screen.get("resources")
	var shortage_members: Dictionary = shortage_scene_screen.get("members")
	shortage_resources["food"] = 1
	shortage_resources["trust"] = 20
	shortage_resources["rescued"] = 4
	var shortage_lines: Array = shortage_scene_screen.call("_night_lines")
	_expect(int(shortage_resources.get("food", 0)) == 0, "shelter shortage can exhaust food")
	_expect(int(shortage_resources.get("trust", 0)) == 17, "shelter food shortage costs trust")
	_expect(int((shortage_members["a_qing"] as Dictionary).get("stress", 0)) == 6, "shelter food shortage stresses members")
	_expect(_array_text_includes(shortage_lines, "安置缺口"), "shelter shortage appears in night report")
	shortage_scene_screen.queue_free()

	var rest_scene_screen: Node = scene.instantiate()
	root.add_child(rest_scene_screen)
	await process_frame
	var rest_resources: Dictionary = rest_scene_screen.get("resources")
	var rest_members: Dictionary = rest_scene_screen.get("members")
	rest_resources["food"] = 3
	rest_resources["medicine"] = 2
	rest_resources["influence"] = 1
	rest_resources["trust"] = 30
	(rest_members["a_qing"] as Dictionary)["stress"] = 50
	(rest_members["xu_lan"] as Dictionary)["stress"] = 30
	(rest_members["lao_zhou"] as Dictionary)["stress"] = 20
	var rest_food_before := int(rest_resources.get("food", 0))
	_expect(rest_scene_screen.call("_apply_rest_action", "shared_meal"), "can run shared meal rest action")
	_expect(int(rest_resources.get("food", 0)) == rest_food_before - 1, "shared meal spends food")
	_expect(int((rest_members["a_qing"] as Dictionary).get("stress", 0)) == 42 and int((rest_members["xu_lan"] as Dictionary).get("stress", 0)) == 22, "shared meal lowers all member stress")
	_expect(not rest_scene_screen.call("_apply_rest_action", "shared_meal"), "rest action cannot be repeated in same day")
	(rest_members["xu_lan"] as Dictionary)["status"] = "injured"
	(rest_members["xu_lan"] as Dictionary)["stress"] = 70
	var rest_medicine_before := int(rest_resources.get("medicine", 0))
	_expect(rest_scene_screen.call("_apply_rest_action", "triage"), "can run triage rest action")
	_expect(int(rest_resources.get("medicine", 0)) == rest_medicine_before - 1, "triage spends medicine")
	_expect(str((rest_members["xu_lan"] as Dictionary).get("status", "")) == "tired" and int((rest_members["xu_lan"] as Dictionary).get("stress", 0)) == 60, "triage improves injured member and lowers stress")
	var stand_down_food_before := int(rest_resources.get("food", 0))
	_expect(rest_scene_screen.call("_apply_rest_action", "stand_down"), "can run stand down rest action")
	_expect(int(rest_resources.get("food", 0)) == stand_down_food_before - 1, "stand down spends food")
	_expect(str((rest_members["xu_lan"] as Dictionary).get("status", "")) == "normal" and int((rest_members["xu_lan"] as Dictionary).get("stress", 0)) == 52, "stand down restores tired member and lowers stress")
	_expect(str((rest_scene_screen.get("pending_rest_report_lines") as Array)[0]).find("Mara Vale 恢复正常") >= 0, "stand down records night report recovery reason")
	(rest_members["lao_zhou"] as Dictionary)["stress"] = 90
	var rest_trust_before := int(rest_resources.get("trust", 0))
	_expect(rest_scene_screen.call("_apply_rest_action", "debrief"), "can run debrief rest action")
	_expect(int(rest_resources.get("influence", 0)) == 0 and int(rest_resources.get("trust", 0)) == rest_trust_before + 1, "debrief spends influence and adds trust")
	_expect(int((rest_members["lao_zhou"] as Dictionary).get("stress", 0)) == 72, "debrief lowers highest stress member")
	_expect((rest_scene_screen.get("rest_actions_used") as Array).has("debrief"), "rest action records daily usage")
	rest_scene_screen.call("_start_day", 2)
	_expect(not (rest_scene_screen.get("rest_actions_used") as Array).has("shared_meal"), "rest actions reset on next day")
	rest_scene_screen.queue_free()

	var stand_down_scene_screen: Node = scene.instantiate()
	root.add_child(stand_down_scene_screen)
	await process_frame
	var stand_resources: Dictionary = stand_down_scene_screen.get("resources")
	var stand_members: Dictionary = stand_down_scene_screen.get("members")
	stand_resources["food"] = 2
	(stand_members["a_qing"] as Dictionary)["stress"] = 44
	(stand_members["xu_lan"] as Dictionary)["stress"] = 20
	_expect(stand_down_scene_screen.call("_apply_rest_action", "stand_down"), "stand down can lower highest stress when no one is tired")
	_expect(int((stand_members["a_qing"] as Dictionary).get("stress", 0)) == 38, "stand down lowers highest stress if no tired member exists")
	stand_down_scene_screen.queue_free()

	var crisis_scene_screen: Node = scene.instantiate()
	root.add_child(crisis_scene_screen)
	await process_frame
	crisis_scene_screen.set("pending_crisis", {"id": "gate_probe", "title": "test"})
	crisis_scene_screen.set("current_directive", {})
	var crisis_resources: Dictionary = crisis_scene_screen.get("resources")
	crisis_resources["trust"] = 20
	crisis_resources["threat"] = 0
	crisis_resources["parts"] = 2
	_expect(crisis_scene_screen.call("_set_crisis_response", "repair"), "can set a crisis response")
	var crisis_lines: Array[String] = []
	crisis_scene_screen.call("_apply_night_crisis", crisis_lines)
	_expect(int(crisis_resources.get("parts", 0)) == 1, "crisis response spends its resource cost")
	_expect(int(crisis_resources.get("trust", 0)) == 20 and int(crisis_resources.get("threat", 0)) == 0, "matched crisis response mitigates gate probe")
	_expect(str(crisis_lines[0]).find("危机应对") >= 0, "crisis response appears in night report lines")
	crisis_scene_screen.call("_start_day", 1)
	crisis_scene_screen.set("pending_crisis", {"id": "antenna_fault", "title": "test"})
	crisis_scene_screen.set("current_directive", {})
	crisis_resources = crisis_scene_screen.get("resources")
	crisis_resources["power"] = 8
	crisis_resources["influence"] = 0
	_expect(crisis_scene_screen.call("_set_crisis_response", "radio"), "can set radio crisis response")
	crisis_lines.clear()
	crisis_scene_screen.call("_apply_night_crisis", crisis_lines)
	_expect(int(crisis_scene_screen.get("next_day_listen_bonus")) == 1 and int(crisis_resources.get("influence", 0)) == 1, "radio crisis response improves next day listening")
	crisis_scene_screen.queue_free()

	var broadcast_scene_screen: Node = scene.instantiate()
	root.add_child(broadcast_scene_screen)
	await process_frame
	var broadcast_resources: Dictionary = broadcast_scene_screen.get("resources")
	var broadcast_power_before := int(broadcast_resources.get("power", 0))
	var broadcast_threat_before := int(broadcast_resources.get("threat", 0))
	var broadcast_influence_before := int(broadcast_resources.get("influence", 0))
	var broadcast_members: Array[String] = ["a_qing"]
	var broadcast_items: Array[String] = []
	broadcast_scene_screen.call("_launch_dispatch", broadcast_members, broadcast_items, "relay_help", "safe")
	_expect(int(broadcast_resources.get("power", 0)) == broadcast_power_before - 1, "relay help broadcast spends power")
	_expect(int(broadcast_resources.get("threat", 0)) == broadcast_threat_before + 2, "relay help broadcast raises exposure")
	_expect(int(broadcast_resources.get("influence", 0)) == broadcast_influence_before + 2, "relay help broadcast raises influence")
	broadcast_scene_screen.queue_free()
	var directive_scene_screen: Node = scene.instantiate()
	root.add_child(directive_scene_screen)
	await process_frame
	var directive_resources: Dictionary = directive_scene_screen.get("resources")
	var directive_trust_before := int(directive_resources.get("trust", 0))
	var directive_parts_before := int(directive_resources.get("parts", 0))
	directive_scene_screen.set("last_dispatch_result", {
		"quality": "success",
		"location_id": "north_bridge",
		"signal_id": "d1_north_bridge_help"
	})
	var directive_lines: Array[String] = []
	_expect(directive_scene_screen.call("_resolve_daily_directive", directive_lines), "rescue directive can be completed")
	_expect(int(directive_scene_screen.get("directive_success_count")) == 1, "completed directive increments counter")
	_expect(int(directive_resources.get("trust", 0)) == directive_trust_before + 2, "completed directive rewards trust")
	_expect(int(directive_resources.get("parts", 0)) == directive_parts_before + 1, "completed directive rewards parts")
	_expect(directive_lines.size() == 1 and str(directive_lines[0]).find("今日委托完成") >= 0, "completed directive appears in night report lines")
	directive_scene_screen.call("_start_day", 3)
	directive_resources["threat"] = 5
	directive_resources["trust"] = 20
	directive_scene_screen.set("last_dispatch_result", {
		"quality": "success",
		"location_id": "garage",
		"signal_id": "d3_blacktower_ping"
	})
	var failed_directive_lines: Array[String] = []
	_expect(not directive_scene_screen.call("_resolve_daily_directive", failed_directive_lines), "high exposure fails low-profile directive")
	_expect(int(directive_resources.get("trust", 0)) == 18, "failed directive applies penalty")
	directive_scene_screen.queue_free()
	var order_scene_screen: Node = scene.instantiate()
	root.add_child(order_scene_screen)
	await process_frame
	var order_resources: Dictionary = order_scene_screen.get("resources")
	var order_threat_before := int(order_resources.get("threat", 0))
	var order_members: Array[String] = ["a_qing"]
	var order_items: Array[String] = []
	order_scene_screen.call("_launch_dispatch", order_members, order_items, "route_warning", "safe", "none", "push")
	_expect(str((order_scene_screen.get("last_dispatch_result") as Dictionary).get("order_id", "")) == "push", "dispatch result records order")
	_expect(int(order_resources.get("threat", 0)) == order_threat_before + 2, "push order adds exposure with broadcast")
	var protect_scene_screen: Node = scene.instantiate()
	root.add_child(protect_scene_screen)
	await process_frame
	var protect_members_dict: Dictionary = protect_scene_screen.get("members")
	protect_members_dict["a_qing"]["status"] = "tired"
	var protect_locations: Dictionary = protect_scene_screen.get("locations")
	var protect_garage: Dictionary = protect_locations["garage"]
	protect_scene_screen.call("_resolve_dispatch_score", 0, protect_garage, {}, false, "safe", order_members, "fallback")
	_expect(str(protect_members_dict["a_qing"].get("status", "")) == "tired", "fallback order protects tired member from injury on failed dispatch")
	order_scene_screen.queue_free()
	protect_scene_screen.queue_free()

	var objective_scene_screen: Node = scene.instantiate()
	root.add_child(objective_scene_screen)
	await process_frame
	var objective_members: Array[String] = ["a_qing"]
	var objective_locations: Dictionary = objective_scene_screen.get("locations")
	var objective_garage: Dictionary = objective_locations["garage"]
	var objective_signal := {"title": "测试侦查", "location": "garage", "reward": {"food": 4}, "need_tags": ["supply"], "result": "测试完成"}
	var objective_risk_before := int(objective_garage.get("risk", 0))
	objective_scene_screen.call("_resolve_dispatch_score", 80, objective_garage, objective_signal, true, "safe", objective_members, "steady", "scout")
	_expect((objective_garage.get("flags", []) as Array).has("scouted"), "scout objective marks a location as scouted")
	_expect(int(objective_garage.get("risk", 0)) < objective_risk_before, "scout objective lowers future location risk on success")
	var launch_objective_screen: Node = scene.instantiate()
	root.add_child(launch_objective_screen)
	await process_frame
	var objective_items: Array[String] = ["radio"]
	launch_objective_screen.call("_launch_dispatch", objective_members, objective_items, "route_warning", "safe", "none", "steady", "scout")
	_expect(str((launch_objective_screen.get("last_dispatch_result") as Dictionary).get("objective_id", "")) == "scout", "dispatch result records objective")
	objective_scene_screen.queue_free()
	launch_objective_screen.queue_free()

	var preview_members: Array[String] = ["a_qing"]
	var preview_items: Array[String] = ["radio"]
	var safe_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "safe")
	var fast_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "fast")
	var unknown_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "unknown")
	var relay_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "relay_help", "safe")
	var silent_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "silent", "safe")
	var push_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "safe", "none", "push")
	var fallback_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "safe", "none", "fallback")
	var rescue_objective_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "safe", "none", "steady", "rescue")
	var supply_objective_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "safe", "none", "steady", "supply")
	var scout_objective_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "safe", "none", "steady", "scout")
	var safe_shelter: Dictionary = safe_preview.get("shelter", {})
	var medium_signal := {"confidence": "medium", "noise": 35}
	var high_signal := {"confidence": "high", "noise": 25}
	var low_signal := {"confidence": "low", "noise": 55, "failure": {"threat": 2}}
	var success_memory_location := {"flags": ["success_dispatch"], "last_visit_day": 1, "status": "confirmed"}
	var failed_memory_location := {"flags": ["failed_dispatch"], "last_visit_day": 1, "status": "danger"}
	var synergy_members: Array[String] = ["xu_lan", "a_qing"]
	var weak_members: Array[String] = ["lao_zhou"]
	var empty_items: Array[String] = []
	var synergy_preview: Dictionary = screen.call("_dispatch_preview", synergy_members, preview_items, "route_warning", "safe")
	var weak_preview: Dictionary = screen.call("_dispatch_preview", weak_members, empty_items, "route_warning", "safe")
	var bond_scene_screen: Node = scene.instantiate()
	root.add_child(bond_scene_screen)
	await process_frame
	var bond_members: Array[String] = ["a_qing", "xu_lan"]
	_expect(int(bond_scene_screen.call("_team_bond_score", bond_members)) == 0, "team bond starts neutral")
	var bond_review: Dictionary = bond_scene_screen.call("_apply_team_bond_result", bond_members, "success")
	_expect(int(bond_review.get("new", 0)) == 1 and int(bond_scene_screen.call("_team_bond_score", bond_members)) == 3, "successful pair builds team bond")
	var bond_preview: Dictionary = bond_scene_screen.call("_dispatch_preview", bond_members, preview_items, "route_warning", "safe")
	_expect(_reasons_include(bond_preview, "搭档记忆 +3"), "team bond appears in dispatch preview reasons")
	bond_scene_screen.call("_apply_team_bond_result", bond_members, "failure")
	bond_scene_screen.call("_apply_team_bond_result", bond_members, "failure")
	_expect(int(bond_scene_screen.call("_team_bond_score", bond_members)) == -3, "failed pair creates team bond penalty")
	bond_scene_screen.queue_free()
	_expect(not safe_preview.is_empty() and not fast_preview.is_empty() and not unknown_preview.is_empty(), "all routes generate dispatch preview")
	_expect(int(fast_preview.get("score", 0)) < int(safe_preview.get("score", 0)), "fast route is riskier than safe route")
	_expect(int(relay_preview.get("score", 0)) == int(safe_preview.get("score", 0)) + 3, "relay help broadcast improves dispatch score over route warning")
	_expect(int(silent_preview.get("score", 0)) == int(safe_preview.get("score", 0)) - 8, "silent broadcast lowers dispatch score")
	_expect(int(push_preview.get("score", 0)) == int(safe_preview.get("score", 0)) + 8, "push order raises dispatch score")
	_expect(int(fallback_preview.get("score", 0)) == int(safe_preview.get("score", 0)) - 6, "fallback order lowers dispatch score")
	_expect(int(rescue_objective_preview.get("score", 0)) == int(safe_preview.get("score", 0)) + 4, "rescue objective raises score on rescue target")
	_expect(int(supply_objective_preview.get("score", 0)) == int(safe_preview.get("score", 0)) - 4, "supply objective penalizes non-supply target")
	_expect(int(scout_objective_preview.get("score", 0)) == int(safe_preview.get("score", 0)) + 6, "scout objective raises preparation but lowers direct reward")
	_expect(not safe_shelter.is_empty() and int(safe_shelter.get("success_rescued", 0)) >= 1, "dispatch preview includes shelter projection for rescue reward")
	_expect(int(safe_shelter.get("success_extra_food", 0)) >= 1, "dispatch preview projects extra shelter food pressure")
	var stance_scene_screen: Node = scene.instantiate()
	root.add_child(stance_scene_screen)
	await process_frame
	var stance_members: Array[String] = ["a_qing"]
	var stance_items: Array[String] = ["radio"]
	var stance_default_preview: Dictionary = stance_scene_screen.call("_dispatch_preview", stance_members, stance_items, "route_warning", "safe")
	_expect(stance_scene_screen.call("_set_day_stance", "aid"), "can set daily aid stance before dispatch")
	var aid_preview: Dictionary = stance_scene_screen.call("_dispatch_preview", stance_members, stance_items, "route_warning", "safe")
	_expect(int(aid_preview.get("score", 0)) == int(stance_default_preview.get("score", 0)) + 6, "aid stance boosts rescue dispatch preview")
	_expect(_reasons_include(aid_preview, "救援广播网 +6"), "aid stance appears in preview reasons")
	stance_scene_screen.call("_select_location", "garage")
	_expect(stance_scene_screen.call("_set_day_stance", "salvage"), "can switch to salvage stance before dispatch")
	var salvage_preview: Dictionary = stance_scene_screen.call("_dispatch_preview", stance_members, stance_items, "route_warning", "safe")
	_expect(_reasons_include(salvage_preview, "补给优先 +5"), "salvage stance boosts supply dispatch preview")
	var stance_resources: Dictionary = stance_scene_screen.get("resources")
	var stance_threat_before := int(stance_resources.get("threat", 0))
	stance_scene_screen.call("_launch_dispatch", stance_members, stance_items, "route_warning", "safe")
	_expect(str((stance_scene_screen.get("last_dispatch_result") as Dictionary).get("day_stance_id", "")) == "salvage", "dispatch records daily stance")
	_expect(int(stance_resources.get("threat", 0)) >= stance_threat_before + 2, "salvage stance adds exposure with route warning")
	_expect(not stance_scene_screen.call("_set_day_stance", "quiet"), "daily stance cannot change after dispatch")
	stance_scene_screen.queue_free()
	_expect(int(screen.call("_signal_intel_score", medium_signal)) == 2, "medium noisy intel has small positive score")
	_expect(int(screen.call("_signal_intel_score", high_signal)) == 8, "high confidence intel has strong positive score")
	_expect(int(screen.call("_signal_intel_score", low_signal)) == -8, "low noisy intel has strong penalty")
	_expect(int(screen.call("_signal_mark_score", medium_signal, "trusted")) == 3, "trusted medium signal gives small intel judgment bonus")
	_expect(int(screen.call("_signal_mark_score", low_signal, "decoy")) == 6, "correct decoy read gives dispatch preparation bonus")
	_expect(int(screen.call("_signal_mark_score", {"confidence": "medium", "noise": 35, "need_tags": ["rescue"]}, "decoy")) == -8, "misreading a rescue signal as decoy penalizes preparation")
	var mark_scene_screen: Node = scene.instantiate()
	root.add_child(mark_scene_screen)
	await process_frame
	var mark_members: Array[String] = ["a_qing"]
	var mark_items: Array[String] = ["radio"]
	var mark_signals: Array = mark_scene_screen.get("day_signals")
	var mark_signal: Dictionary = mark_signals[0]
	mark_scene_screen.call("_lock_signal", str(mark_signal.get("id", "")))
	var unmarked_preview: Dictionary = mark_scene_screen.call("_dispatch_preview", mark_members, mark_items, "route_warning", "safe")
	mark_scene_screen.call("_mark_signal", str(mark_signal.get("id", "")), "trusted")
	var trusted_preview: Dictionary = mark_scene_screen.call("_dispatch_preview", mark_members, mark_items, "route_warning", "safe")
	_expect(int(trusted_preview.get("score", 0)) == int(unmarked_preview.get("score", 0)) + 3, "intel judgment affects dispatch preview score")
	_expect(_reasons_include(trusted_preview, "情报判断：可信 +3"), "intel judgment appears in dispatch preview reasons")
	var marked_location: Dictionary = mark_scene_screen.call("_dispatch_panel_location")
	_expect(str(marked_location.get("signal_mark", "")) == "trusted" and int(marked_location.get("signal_mark_score", 0)) == 3, "dispatch panel location carries intel judgment")
	var mark_resources: Dictionary = mark_scene_screen.get("resources")
	var mark_members_dict: Dictionary = mark_scene_screen.get("members")
	(mark_members_dict["shen_luo"] as Dictionary)["stress"] = 12
	var mark_influence_before := int(mark_resources.get("influence", 0))
	var hit_review: Dictionary = mark_scene_screen.call("_apply_intel_review", mark_signal, mark_members)
	_expect(str(hit_review.get("quality", "")) == "hit", "correct intel mark produces a hit review")
	_expect(int(mark_resources.get("influence", 0)) == mark_influence_before + 1 and int((mark_members_dict["shen_luo"] as Dictionary).get("stress", 0)) == 9, "hit intel review grants influence and relieves Elias Reed")
	_expect((mark_scene_screen.get("intel_reviews") as Array).size() == 1, "intel review is recorded")
	mark_scene_screen.queue_free()
	var miss_scene_screen: Node = scene.instantiate()
	root.add_child(miss_scene_screen)
	await process_frame
	var miss_signals: Array = miss_scene_screen.get("day_signals")
	var miss_signal: Dictionary = miss_signals[0]
	miss_scene_screen.call("_mark_signal", str(miss_signal.get("id", "")), "decoy")
	var miss_resources: Dictionary = miss_scene_screen.get("resources")
	var miss_members: Dictionary = miss_scene_screen.get("members")
	(miss_members["a_qing"] as Dictionary)["stress"] = 20
	var miss_trust_before := int(miss_resources.get("trust", 0))
	var miss_dispatch_members: Array[String] = ["a_qing"]
	var miss_review: Dictionary = miss_scene_screen.call("_apply_intel_review", miss_signal, miss_dispatch_members)
	_expect(str(miss_review.get("quality", "")) == "miss", "wrong intel mark produces a miss review")
	_expect(int(miss_resources.get("trust", 0)) == miss_trust_before - 1 and int((miss_members["a_qing"] as Dictionary).get("stress", 0)) == 24, "miss intel review costs trust and stresses field member")
	miss_scene_screen.queue_free()
	var review_scene_screen: Node = scene.instantiate()
	root.add_child(review_scene_screen)
	await process_frame
	var review_signals: Array = review_scene_screen.get("day_signals")
	var review_signal: Dictionary = review_signals[0]
	review_scene_screen.call("_mark_signal", str(review_signal.get("id", "")), "trusted")
	var review_locations: Dictionary = review_scene_screen.get("locations")
	var review_members: Array[String] = ["a_qing"]
	var review_result: Dictionary = review_scene_screen.call("_resolve_dispatch_score", 80, review_locations["north_bridge"], review_signal, true, "safe", review_members)
	_expect(not (review_result.get("intel_review", {}) as Dictionary).is_empty(), "dispatch result records intel review")
	_expect(str((review_result.get("feed_lines", []) as Array)[3]).find("情报复盘") >= 0, "dispatch feed includes intel review")
	review_scene_screen.set("last_dispatch_result", review_result)
	review_scene_screen.set("dispatched_today", true)
	review_scene_screen.set("pending_crisis", {})
	review_scene_screen.set("current_directive", {})
	var review_night_lines: Array = review_scene_screen.call("_night_lines")
	_expect(_array_text_includes(review_night_lines, "情报复盘"), "night report includes intel review")
	review_scene_screen.queue_free()
	screen.set("day", 2)
	_expect(int(screen.call("_location_memory_score", success_memory_location)) == 12, "successful prior visit gives location memory bonus")
	_expect(int(screen.call("_location_memory_score", failed_memory_location)) == -4, "failed prior visit leaves location memory penalty")
	var live_locations: Dictionary = screen.get("locations")
	var remembered_north_bridge: Dictionary = live_locations["north_bridge"]
	var old_flags: Array = (remembered_north_bridge.get("flags", []) as Array).duplicate()
	var old_visit := int(remembered_north_bridge.get("last_visit_day", 0))
	var old_status := str(remembered_north_bridge.get("status", ""))
	var old_risk := int(remembered_north_bridge.get("risk", 0))
	var old_trend := int(remembered_north_bridge.get("danger_trend", 0))
	var old_supplies := int(remembered_north_bridge.get("supplies_left", 0))
	remembered_north_bridge["flags"] = ["success_dispatch"]
	remembered_north_bridge["last_visit_day"] = 1
	remembered_north_bridge["status"] = "confirmed"
	var remembered_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "safe")
	_expect(int(remembered_preview.get("score", 0)) == int(safe_preview.get("score", 0)) + 12, "location memory affects dispatch preview score")
	_expect(_reasons_include(remembered_preview, "地点记忆 +12"), "location memory reason is visible")
	remembered_north_bridge["flags"] = []
	remembered_north_bridge["risk"] = 35
	remembered_north_bridge["danger_trend"] = 1
	var city_resources: Dictionary = screen.get("resources")
	var old_city_influence := int(city_resources.get("influence", 0))
	var old_city_parts := int(city_resources.get("parts", 0))
	var old_city_food := int(city_resources.get("food", 0))
	var old_city_trust := int(city_resources.get("trust", 0))
	city_resources["influence"] = 1
	city_resources["parts"] = 2
	city_resources["food"] = 10
	var city_trust_before := int(city_resources.get("trust", 0))
	_expect(screen.call("_apply_city_action", "north_bridge", "warn"), "can apply city warning action")
	_expect((remembered_north_bridge.get("flags", []) as Array).has("warned"), "city action writes location flag")
	_expect(int(remembered_north_bridge.get("danger_trend", 0)) == 0 and int(city_resources.get("trust", 0)) == city_trust_before + 1, "warning action slows danger and adds trust")
	_expect(not screen.call("_apply_city_action", "north_bridge", "warn"), "city action cannot be repeated on same node")
	_expect(screen.call("_apply_city_action", "north_bridge", "route_mark"), "can apply city route marker")
	var city_action_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "safe")
	_expect(int(city_action_preview.get("score", 0)) > int(safe_preview.get("score", 0)), "city actions improve dispatch preview")
	remembered_north_bridge["flags"] = old_flags
	remembered_north_bridge["last_visit_day"] = old_visit
	remembered_north_bridge["status"] = old_status
	remembered_north_bridge["risk"] = old_risk
	remembered_north_bridge["danger_trend"] = old_trend
	remembered_north_bridge["supplies_left"] = old_supplies
	city_resources["influence"] = old_city_influence
	city_resources["parts"] = old_city_parts
	city_resources["food"] = old_city_food
	city_resources["trust"] = old_city_trust
	screen.set("day", 1)
	_expect((safe_preview.get("reasons", []) as Array).size() > 0, "dispatch preview includes score reasons")
	_expect(_reasons_include(safe_preview, "情报可信度 +3") and _reasons_include(safe_preview, "信号噪声 -1"), "dispatch preview includes intel quality reasons")
	_expect(_reasons_include(push_preview, "强行推进 +8"), "order score reason is visible")
	_expect(_reasons_include(rescue_objective_preview, "救援优先 +4") and _reasons_include(scout_objective_preview, "侦查踩点 +6"), "objective score reasons are visible")
	_expect(_reasons_include(synergy_preview, "队伍协同 +8"), "complementary members add team synergy")
	_expect(_reasons_include(weak_preview, "Victor Hale -6"), "member weakness is visible in preview reasons")
	var preview_members_dict: Dictionary = screen.get("members")
	preview_members_dict["a_qing"]["stress"] = 60
	var stressed_preview: Dictionary = screen.call("_dispatch_preview", preview_members, preview_items, "route_warning", "safe")
	_expect(int(stressed_preview.get("score", 0)) == int(safe_preview.get("score", 0)) - 8, "high stress lowers dispatch score")
	preview_members_dict["a_qing"]["stress"] = 0
	var dispatch_scene: PackedScene = load("res://scenes/DispatchPanel.tscn") as PackedScene
	_expect(dispatch_scene != null, "DispatchPanel scene loads")
	if dispatch_scene != null:
		var dispatch_panel: Node = dispatch_scene.instantiate()
		root.add_child(dispatch_panel)
		(dispatch_panel as Control).size = Vector2(700, 500)
		var dispatch_location: Dictionary = screen.call("_dispatch_panel_location")
		var bonded_location := dispatch_location.duplicate(true)
		bonded_location["team_bonds"] = {"a_qing|xu_lan": 2}
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), bonded_location, false, Callable(screen, "_dispatch_preview"), {})
		dispatch_panel.call("_toggle_member", "a_qing")
		dispatch_panel.call("_toggle_member", "xu_lan")
		await process_frame
		_expect(_visible_buttons_do_not_overlap(dispatch_panel), "dispatch panel buttons do not overlap after selecting members")
		_expect(str(dispatch_panel.call("_team_bond_text")).find("+6") >= 0, "dispatch panel shows team bond memory")
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), dispatch_location, false, Callable(screen, "_dispatch_preview"), {})
		_expect(dispatch_panel.call("_uses_story_dispatch"), "day 1 north bridge uses story dispatch presentation")
		_expect(not bool(dispatch_panel.get("details_expanded")), "story dispatch keeps detailed ledger collapsed by default")
		_expect(_visible_button_count(dispatch_panel) <= 3, "story dispatch advisor step has at most three buttons")
		dispatch_panel.call("_consult_advisor", "xu_lan")
		_expect(str(dispatch_panel.get("consulted_member_id")) == "xu_lan", "dispatch panel records advisor consultation")
		_expect(_visible_button_count(dispatch_panel) <= 3, "story dispatch team step has at most three buttons")
		dispatch_panel.call("_choose_story_team", ["a_qing", "xu_lan"])
		_expect((dispatch_panel.get("selected_member_ids") as Array).size() == 2, "story dispatch team choice fills two member slots")
		_expect(_visible_button_count(dispatch_panel) <= 3, "story dispatch route step has at most three buttons")
		dispatch_panel.call("_confirm_story_route", "safe")
		_expect(_visible_button_count(dispatch_panel) <= 3, "story dispatch launch step has at most three buttons")
		_expect(str(dispatch_panel.call("_story_forecast_text", 72, 18)).find("有把握") >= 0, "story dispatch forecast uses consequence language instead of raw percent")
		_expect(not dispatch_panel.call("_objective_unlocked") and not dispatch_panel.call("_broadcast_unlocked"), "day 1 dispatch keeps advanced controls locked")
		var day_two_location := dispatch_location.duplicate(true)
		day_two_location["day"] = 2
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), day_two_location, false, Callable(screen, "_dispatch_preview"), {})
		_expect(dispatch_panel.call("_objective_unlocked") and dispatch_panel.call("_prep_unlocked") and not dispatch_panel.call("_broadcast_unlocked"), "day 2 dispatch unlocks objective and prep")
		var day_three_location := dispatch_location.duplicate(true)
		day_three_location["day"] = 3
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), day_three_location, false, Callable(screen, "_dispatch_preview"), {})
		_expect(dispatch_panel.call("_order_unlocked") and dispatch_panel.call("_broadcast_unlocked"), "day 3 dispatch unlocks order and broadcast")
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), dispatch_location, false, Callable(screen, "_dispatch_preview"), {})
		var target_image: TextureRect = dispatch_panel.get("target_signal_image")
		_expect(target_image != null and target_image.texture != null and target_image.custom_minimum_size.y > 0.0, "dispatch panel shows target signal image")
		_expect((dispatch_location.get("mission_tags", []) as Array).has("field"), "dispatch panel location includes signal need tags")
		_expect((dispatch_location.get("night_forecast", []) as Array).size() >= 1, "dispatch panel location includes night forecast")
		_expect((dispatch_location.get("broadcast_defs", {}) as Dictionary).has("relay_help"), "dispatch panel location includes broadcast definitions")
		_expect((dispatch_location.get("order_defs", {}) as Dictionary).has("push"), "dispatch panel location includes order definitions")
		_expect((dispatch_location.get("objective_defs", {}) as Dictionary).has("scout"), "dispatch panel location includes objective definitions")
		_expect(int(dispatch_location.get("signal_intel_score", 0)) == 2, "dispatch panel location includes signal intel score")
		_expect(str(dispatch_location.get("memory_text", "")).find("记忆") >= 0, "dispatch panel location includes memory text")
		_expect(not (dispatch_location.get("current_directive", {}) as Dictionary).is_empty(), "dispatch panel location includes current directive")
		_expect(int(dispatch_panel.call("_member_fit_score", "a_qing")) > 0, "dispatch panel shows member fit score")
		_expect(int(dispatch_panel.call("_member_fit_score", "lao_zhou")) < 0, "dispatch panel shows member weakness score")
		_expect(int(dispatch_panel.call("_item_fit_score", "radio")) > 0, "dispatch panel shows item fit score")
		var relay_effect := str(dispatch_panel.call("_broadcast_effect_text", "relay_help"))
		var silent_effect := str(dispatch_panel.call("_broadcast_effect_text", "silent"))
		_expect(relay_effect.find("准+8") >= 0 and relay_effect.find("电-1") >= 0, "dispatch panel shows relay help broadcast tradeoff")
		_expect(silent_effect.find("准-3") >= 0 and silent_effect.find("信-1") >= 0, "dispatch panel shows silent broadcast tradeoff")
		var push_effect := str(dispatch_panel.call("_order_effect_text", "push"))
		var fallback_effect := str(dispatch_panel.call("_order_effect_text", "fallback"))
		_expect(push_effect.find("准+8") >= 0 and push_effect.find("暴+1") >= 0, "dispatch panel shows push order tradeoff")
		_expect(fallback_effect.find("准-6") >= 0 and fallback_effect.find("护伤") >= 0, "dispatch panel shows fallback order protection")
		var rescue_objective_effect := str(dispatch_panel.call("_objective_effect_text", "rescue"))
		var scout_objective_effect := str(dispatch_panel.call("_objective_effect_text", "scout"))
		_expect(rescue_objective_effect.find("x1.35") >= 0 and scout_objective_effect.find("x0.45") >= 0 and scout_objective_effect.find("降险") >= 0, "dispatch panel shows objective tradeoffs")
		var intel_text := str(dispatch_panel.call("_intel_text"))
		_expect(intel_text.find("中可信") >= 0 and intel_text.find("准+2") >= 0, "dispatch panel shows intel quality text")
		var remembered_location := dispatch_location.duplicate(true)
		remembered_location["memory_text"] = "记忆：路线标记 准+6"
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), remembered_location, false, Callable(screen, "_dispatch_preview"), {})
		_expect(str(dispatch_panel.call("_memory_text")).find("路线标记") >= 0, "dispatch panel shows location memory text")
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), dispatch_location, false, Callable(screen, "_dispatch_preview"), {})
		var directive_preview := str(dispatch_panel.call("_directive_preview_text"))
		_expect(directive_preview.find("救援优先") >= 0 and directive_preview.find("可完成") >= 0, "dispatch panel shows directive completion preview")
		var safe_stakes := str(dispatch_panel.call("_stakes_text"))
		_expect(safe_stakes.find("安置") >= 0 and safe_stakes.find("口粮 +1") >= 0, "dispatch panel shows shelter food pressure before dispatch")
		var shelter_preview_text := str(dispatch_panel.call("_shelter_preview_text"))
		_expect(shelter_preview_text.find("成功 +") >= 0 and shelter_preview_text.find("口粮") >= 0, "dispatch panel exposes shelter projection text")
		_expect(safe_stakes.find("路线 x0.75") >= 0 and safe_stakes.find("信任 +3") >= 0 and safe_stakes.find("情报") >= 0 and safe_stakes.find("准则") >= 0 and safe_stakes.find("委托") >= 0 and safe_stakes.find("广播") >= 0, "dispatch panel shows safe route, intel, order, directive and broadcast stakes")
		_expect(safe_stakes.find("入夜") >= 0 and safe_stakes.find("Mara Vale压") >= 0, "dispatch panel shows ignored rescue consequence")
		var status_help := str(dispatch_panel.call("_member_status_help", "tired"))
		_expect(status_help.find("准备 -8") >= 0 and status_help.find("轮休") >= 0 and status_help.find("医务角") >= 0, "member status help explains fatigue recovery")
		dispatch_panel.call("_set_objective", "scout")
		_expect(str(dispatch_panel.get("objective_id")) == "scout", "dispatch panel accepts objective selection")
		var scout_stakes := str(dispatch_panel.call("_stakes_text"))
		_expect(scout_stakes.find("x0.45") >= 0 and scout_stakes.find("降险") >= 0, "dispatch panel stakes update for scout objective")
		dispatch_panel.call("_set_objective", "balanced")
		dispatch_panel.call("_set_route", "fast")
		_expect(str(dispatch_panel.get("route_id")) == "fast", "dispatch panel accepts fast route selection")
		var fast_stakes := str(dispatch_panel.call("_stakes_text"))
		_expect(fast_stakes.find("路线 x1.15") >= 0 and fast_stakes.find("暴露 +1") >= 0, "dispatch panel stakes update for fast route")
		dispatch_panel.call("_set_route", "unknown")
		_expect(str(dispatch_panel.get("route_id")) == "unknown", "dispatch panel accepts unknown route selection")
		var unknown_stakes := str(dispatch_panel.call("_stakes_text"))
		_expect(unknown_stakes.find("燃料 -1") >= 0 and unknown_stakes.find("失败风险 +10") >= 0, "dispatch panel stakes update for unknown route")
		var quiet_location := dispatch_location.duplicate(true)
		quiet_location["day"] = 3
		quiet_location["type"] = "supply"
		quiet_location["current_directive"] = {
			"title": "压低暴露",
			"condition": "threat_at_most",
			"max_threat": 2,
			"reward": {"trust": 2, "influence": 1},
			"failure": {"trust": -2}
		}
		var quiet_resources: Dictionary = quiet_location.get("resources", {})
		quiet_resources["threat"] = 2
		quiet_location["resources"] = quiet_resources
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), quiet_location, false, Callable(screen, "_dispatch_preview"), {})
		dispatch_panel.call("_set_route", "unknown")
		_expect(str(dispatch_panel.call("_directive_preview_text")).find("可完成 暴2/2") >= 0, "quiet directive accounts for unknown route exposure drop")
		dispatch_panel.call("_set_route", "safe")
		dispatch_panel.set("broadcast_mode", "relay_help")
		_expect(str(dispatch_panel.call("_directive_preview_text")).find("会失手 暴4/2") >= 0, "quiet directive accounts for broadcast exposure risk")
		dispatch_panel.set("broadcast_mode", "route_warning")
		dispatch_panel.set("order_id", "fallback")
		_expect(str(dispatch_panel.call("_directive_preview_text")).find("可完成 暴2/2") >= 0, "quiet directive accounts for fallback order exposure drop")
		dispatch_panel.call("_toggle_member", "a_qing")
		dispatch_panel.call("_toggle_item", "radio")
		await process_frame
		var launch_button: Button = dispatch_panel.get("launch_button")
		var panel_rect := (dispatch_panel as Control).get_global_rect()
		var button_rect := launch_button.get_global_rect()
		_expect(button_rect.end.y <= panel_rect.end.y + 1.0 and button_rect.end.x <= panel_rect.end.x + 1.0, "dispatch launch button stays inside panel")
		_expect(str(dispatch_panel.call("_objective_chip_text", "rescue")).find("x1.35") >= 0, "dispatch objective chips use compact labels")
		_expect(_visible_buttons_do_not_overlap(dispatch_panel), "dispatch planning buttons do not overlap")
		var probability_text := str(dispatch_panel.call("_probability_text"))
		_expect(probability_text.split("\n").size() >= 3, "dispatch panel shows multiple probability reasons")
		var resolved_result := {
			"quality": "success",
			"summary": "测试外勤完成。",
			"route_id": "safe",
			"order_id": "steady",
			"base_score": 66,
			"final_score": 70,
			"feed_lines": ["测试回传一。", "测试回传二。", "测试回传三。"]
		}
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), dispatch_location, true, Callable(screen, "_dispatch_preview"), resolved_result)
		_expect(str(dispatch_panel.get("phase")) == "resolved", "dispatch panel rebuilds completed result directly")
		var animated_result := resolved_result.duplicate(true)
		animated_result["ui_phase"] = "transmitting"
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), dispatch_location, true, Callable(screen, "_dispatch_preview"), animated_result)
		_expect(str(dispatch_panel.get("phase")) == "transmitting", "fresh dispatch result can enter transmitting state")
		_expect(str(dispatch_panel.call("_transmit_feed_text")).find("测试回传一") >= 0, "transmitting state shows radio feed lines")
		for _tick in range(14):
			dispatch_panel.call("_advance_transmission")
		_expect(str(dispatch_panel.get("phase")) == "resolved", "transmitting state resolves after radio playback")
		var awaiting_result := {
			"ui_phase": "awaiting_choice",
			"summary": "测试队伍等待回传。",
			"field_choice": dispatch_location.get("field_choice", {}),
			"pending_feed_lines": ["测试楼下回传。"]
		}
		dispatch_panel.call("setup", screen.get("members"), screen.get("items"), dispatch_location, true, Callable(screen, "_dispatch_preview"), awaiting_result)
		_expect(str(dispatch_panel.get("phase")) == "awaiting_choice", "story dispatch can build awaiting choice state")
		_expect(((dispatch_panel.call("_field_choice_data") as Dictionary).get("options", []) as Array).size() == 3, "awaiting choice exposes three field responses")
		dispatch_panel.queue_free()
	var choice_deltas := {}
	for choice_id in ["push_upstairs", "secure_exit", "hold_signal"]:
		var choice_screen: Node = scene.instantiate()
		root.add_child(choice_screen)
		await process_frame
		var choice_signal: Dictionary = (choice_screen.get("day_signals") as Array)[0]
		choice_screen.call("_lock_signal", str(choice_signal.get("id", "")))
		choice_screen.call("_select_location", str(choice_signal.get("location", "")))
		var choice_members: Array[String] = ["a_qing", "xu_lan"]
		var choice_items: Array[String] = ["radio"]
		choice_screen.call("_launch_dispatch", choice_members, choice_items, "route_warning", "safe")
		_expect(not (choice_screen.get("pending_dispatch_context") as Dictionary).is_empty(), "story dispatch stays pending before field choice")
		_expect(choice_screen.call("_resolve_pending_dispatch", choice_id), "field choice %s resolves pending dispatch" % choice_id)
		var choice_result: Dictionary = choice_screen.get("last_dispatch_result")
		_expect(str(choice_result.get("choice_id", "")) == choice_id, "dispatch result records field choice %s" % choice_id)
		_expect((choice_result.get("feed_lines", []) as Array).size() >= 4, "field choice %s produces radio feed and outcome" % choice_id)
		choice_deltas[choice_id] = int(choice_result.get("choice_score_delta", 0))
		choice_screen.queue_free()
	_expect(int(choice_deltas.get("push_upstairs", 0)) > int(choice_deltas.get("secure_exit", 0)) and int(choice_deltas.get("secure_exit", 0)) > int(choice_deltas.get("hold_signal", 0)), "field choices carry different hidden result tendencies")
	var report_scene: PackedScene = load("res://scenes/NightReport.tscn") as PackedScene
	_expect(report_scene != null, "NightReport scene loads")
	if report_scene != null:
		var report_panel: Node = report_scene.instantiate()
		root.add_child(report_panel)
		var report_events: Array[Dictionary] = [
			{"title": "外勤回传", "body": "测试回传。", "facility": "antenna", "severity": "neutral"},
			{"title": "基地警戒", "body": "测试警戒。", "facility": "gate", "severity": "warning"}
		]
		report_panel.call("setup", 1, ["测试回传。", "测试警戒。"], false, report_events)
		report_panel.set("summary", {
			"resource_delta": {"food": -2, "trust": 1, "threat": -1},
			"stress_delta": 4,
			"status_changes": ["Mara Vale 正常>疲惫"],
			"pressure": "bad"
		})
		var summary_texts: Array = report_panel.call("_summary_texts")
		_expect(int(report_panel.get("visible_count")) == 1, "night report starts as replay")
		_expect(summary_texts.size() == 4 and str(summary_texts[0]).find("食-2") >= 0 and str(summary_texts[3]).find("吃紧") >= 0, "night report shows summary chips")
		report_panel.call("_advance_replay")
		_expect(int(report_panel.get("visible_count")) == 2, "night report advances replay")
		report_panel.queue_free()
	var parts_before := int((screen.get("resources") as Dictionary).get("parts", 0))
	_expect(screen.call("_buy_base_upgrade", "gate"), "base facility board can buy gate upgrade")
	_expect(int((screen.get("base_upgrades") as Dictionary).get("gate", 0)) == 1, "gate upgrade level increases")
	_expect(int((screen.get("resources") as Dictionary).get("parts", 0)) < parts_before, "base upgrade spends parts")

	for target_day in [1, 2, 3]:
		_expect(int(screen.get("day")) == target_day, "is on expected day %d" % target_day)
		var day_signals: Array = screen.get("day_signals")
		_expect(day_signals.size() == 3, "day %d has 3 signals" % target_day)
		var first_signal: Dictionary = day_signals[0]
		screen.call("_lock_signal", str(first_signal.get("id", "")))
		if operation_track != null:
			var expected_step_after_lock := 0 if target_day == 1 else 2
			_expect(int(operation_track.call("_active_step")) == expected_step_after_lock, "operation track advances to the right step after locking a signal")
		if target_day == 1:
			_expect(screen.call("_confirm_signal", str(first_signal.get("id", ""))), "story signal confirmation advances the tutorial flow")
			if operation_track != null:
				_expect(int(operation_track.call("_active_step")) == 2, "operation track advances to dispatch step after confirming the story signal")
		var location_id := str(first_signal.get("location", ""))
		if location_id == "base":
			location_id = "garage"
		screen.call("_select_location", location_id)
		var members: Array[String] = ["a_qing"]
		var items: Array[String] = ["radio"]
		screen.call("_launch_dispatch", members, items, "route_warning")
		var pending_context: Dictionary = screen.get("pending_dispatch_context")
		if not pending_context.is_empty():
			var pending_result: Dictionary = screen.get("last_dispatch_result")
			_expect(str(pending_result.get("ui_phase", "")) == "awaiting_choice", "story dispatch waits for field choice")
			_expect(screen.call("_resolve_pending_dispatch", "secure_exit"), "story dispatch can resolve a field choice")
		if operation_track != null:
			_expect(int(operation_track.call("_active_step")) == 3, "operation track advances to night step after dispatch")
		var dispatch_result: Dictionary = screen.get("last_dispatch_result")
		_expect((dispatch_result.get("feed_lines", []) as Array).size() >= 3, "dispatch result has radio feed lines")
		screen.call("_night_lines")
		_expect((screen.get("night_report_events") as Array).size() >= 2, "night report has structured replay events")
		var night_summary: Dictionary = screen.get("night_report_summary")
		_expect(not night_summary.is_empty() and not (night_summary.get("resource_delta", {}) as Dictionary).is_empty(), "night report has resource summary")
		if target_day < 3:
			screen.call("_start_day", target_day + 1)

	var locations: Dictionary = screen.get("locations")
	var changed_location := false
	for location_id in locations.keys():
		if str(locations[location_id].get("status", "")) != "unknown" and str(location_id) != "base":
			changed_location = true
	var changed_member := false
	var loaded_members: Dictionary = screen.get("members")
	for member_id in loaded_members.keys():
		if str(loaded_members[member_id].get("status", "normal")) != "normal":
			changed_member = true
	var resources: Dictionary = screen.get("resources")
	_expect(changed_location, "at least one location changes state")
	_expect(changed_member, "at least one member changes state")
	_expect(int(resources.get("food", 10)) != 10 or int(resources.get("power", 8)) != 8, "resources change")
	var final_members: Dictionary = screen.get("members")
	_expect(int((final_members["xu_lan"] as Dictionary).get("stress", 0)) > 0, "ignored rescue pressure affects Mara Vale")
	var garage: Dictionary = locations["garage"]
	var garage_risk_before := int(garage.get("risk", 0))
	var garage_trend_before := int(garage.get("danger_trend", 0))
	screen.call("_resolve_dispatch_score", 0, garage, {}, false, "unknown", preview_members)
	_expect(int(garage.get("danger_trend", 0)) > garage_trend_before, "failed dispatch changes location danger trend")
	_expect(int(garage.get("risk", 0)) >= garage_risk_before + 10, "unknown route failure adds location risk")
	var final_report: Dictionary = screen.call("_build_final_report")
	_expect(int(final_report.get("score", -1)) >= 0, "final report computes a score")
	_expect(str(final_report.get("rank", "")) != "", "final report computes a rank")
	_expect((final_report.get("lines", []) as Array).size() >= 4, "final report has summary lines")
	screen.set("final_report", final_report)
	screen.call("_show_final_report")
	var overlay: Control = screen.get("overlay_layer")
	_expect(overlay != null and overlay.get_child_count() > 0, "final report overlay can be shown")

	if failed:
		quit(1)
		return
	print("Last Radio v2 smoke test: PASS")
	quit(0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error("Last Radio v2 smoke test: FAIL - %s" % message)
	print("Last Radio v2 smoke test: FAIL - %s" % message)

func _reasons_include(preview: Dictionary, needle: String) -> bool:
	for reason in preview.get("reasons", []):
		if str(reason).find(needle) >= 0:
			return true
	return false

func _array_text_includes(lines: Array, needle: String) -> bool:
	for line in lines:
		if str(line).find(needle) >= 0:
			return true
	return false

func _visible_buttons_do_not_overlap(root: Node) -> bool:
	var buttons: Array[Button] = []
	_collect_visible_buttons(root, buttons)
	for i in range(buttons.size()):
		var first_rect := buttons[i].get_global_rect()
		if first_rect.size.x <= 1.0 or first_rect.size.y <= 1.0:
			continue
		for j in range(i + 1, buttons.size()):
			var second_rect := buttons[j].get_global_rect()
			if second_rect.size.x <= 1.0 or second_rect.size.y <= 1.0:
				continue
			if first_rect.intersects(second_rect, true):
				return false
	return true

func _visible_button_count(root: Node) -> int:
	var buttons: Array[Button] = []
	_collect_visible_buttons(root, buttons)
	return buttons.size()

func _collect_visible_buttons(node: Node, buttons: Array[Button]) -> void:
	if node is Button and (node as Button).is_visible_in_tree():
		buttons.append(node as Button)
	for child in node.get_children():
		_collect_visible_buttons(child, buttons)

func _visible_buttons_have_min_width(root: Node, min_width: float) -> bool:
	var buttons: Array[Button] = []
	_collect_visible_buttons(root, buttons)
	for button in buttons:
		var rect := button.get_global_rect()
		if rect.size.x > 1.0 and rect.size.x < min_width:
			return false
	return true

func _visible_label_text(root: Node) -> String:
	var parts: Array[String] = []
	_collect_visible_label_text(root, parts)
	return "\n".join(parts)

func _collect_visible_label_text(node: Node, parts: Array[String]) -> void:
	if node is Label and (node as Label).is_visible_in_tree():
		parts.append((node as Label).text)
	for child in node.get_children():
		_collect_visible_label_text(child, parts)
