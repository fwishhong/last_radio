extends Control

const MAX_DAY := 7
const EVENTS_PATH := "res://data/events.json"
const SIGNAL_CARD_SCENE := preload("res://scenes/SignalCard.tscn")
const MEMBER_PANEL_SCENE := preload("res://scenes/MemberPanel.tscn")
const DAY_REPORT_SCENE := preload("res://scenes/EndOfDayReport.tscn")
const FINAL_SCORE_SCENE := preload("res://scenes/FinalScoreScreen.tscn")

var rng := RandomNumberGenerator.new()
var events: Array = []
var used_event_ids: Array[String] = []
var scheduled_events: Array[Dictionary] = []
var day_events: Array[Dictionary] = []
var resolved_count := 0
var dispatched_today: Array[String] = []
var resolved_event_ids_today: Array[String] = []
var tuned_event_ids_today: Array[String] = []
var daily_action_limit := 2
var daily_actions_used := 0
var tuning_charges := 2

var day := 1
var resources := {}
var members := {}
var stats := {}
var tags := {}
var logs: Array[String] = []
var day_result_lines: Array[String] = []

var day_label: Label
var phase_label: Label
var resource_box: VBoxContainer
var signal_container: HBoxContainer
var log_body: RichTextLabel
var member_slot: Control
var end_day_button: Button
var hint_label: Label
var overlay_layer: Control

func _ready() -> void:
	rng.randomize()
	_load_events()
	_reset_game()
	_build_ui()
	_start_day()

func _load_events() -> void:
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("Missing event data: %s" % EVENTS_PATH)
		events = []
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid event JSON. Expected an array.")
		events = []
		return
	events = parsed

func _reset_game() -> void:
	day = 1
	resources = {
		"power": 8,
		"food": 10,
		"medicine": 6,
		"trust": 50
	}
	members = {
		"shen_luo": {
			"name": "Elias Reed",
			"status": "normal",
			"trait": "Radio Technician。广播消耗电力 -1，外出风险更高。"
		},
		"xu_lan": {
			"name": "Mara Vale",
			"status": "normal",
			"trait": "Field Medic。治疗更省药，拒绝救援时更伤信任。"
		},
		"lao_zhou": {
			"name": "Victor Hale",
			"status": "normal",
			"trait": "Quartermaster。交易收益更高，但信任增长较慢。"
		},
		"a_qing": {
			"name": "Nora Quinn",
			"status": "normal",
			"trait": "Pathfinder Mechanic。救援和外出更稳，连续派遣会疲惫。"
		}
	}
	stats = {
		"rescued": 0,
		"influence": 0,
		"broadcasts": 0,
		"truths": 0,
		"lies": 0,
		"trades": 0,
		"rescues": 0,
		"dispatches": 0,
		"refused_rescue": 0,
		"blacktower": 0,
		"silent_days": 0,
		"final_broadcast": 0,
		"threat": 0
	}
	tags = {}
	logs = ["第 1 天：旧体育馆避难所重新接上短波电台。"]
	used_event_ids.clear()
	scheduled_events.clear()
	day_result_lines.clear()
	dispatched_today.clear()
	resolved_event_ids_today.clear()
	tuned_event_ids_today.clear()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.035, 0.034)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	root.add_child(header)

	var title := Label.new()
	title.text = "最后电台"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	header.add_child(title)

	day_label = Label.new()
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_label.add_theme_font_size_override("font_size", 24)
	day_label.add_theme_color_override("font_color", Color(0.74, 0.94, 1.0))
	header.add_child(day_label)

	var restart := Button.new()
	restart.text = "重新开局"
	restart.custom_minimum_size = Vector2(120, 42)
	restart.pressed.connect(func() -> void:
		_reset_game()
		_start_day()
	)
	header.add_child(restart)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	root.add_child(body)

	var left_panel := _make_panel()
	left_panel.custom_minimum_size = Vector2(250, 0)
	body.add_child(left_panel)
	resource_box = VBoxContainer.new()
	resource_box.add_theme_constant_override("separation", 10)
	left_panel.add_child(_wrap_margin(resource_box, 14))

	signal_container = HBoxContainer.new()
	signal_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	signal_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	signal_container.add_theme_constant_override("separation", 14)
	body.add_child(signal_container)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(300, 0)
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)

	member_slot = Control.new()
	member_slot.custom_minimum_size = Vector2(0, 270)
	right.add_child(member_slot)

	var log_panel := _make_panel()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_panel)
	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 14)
	log_margin.add_theme_constant_override("margin_right", 14)
	log_margin.add_theme_constant_override("margin_top", 14)
	log_margin.add_theme_constant_override("margin_bottom", 14)
	log_panel.add_child(log_margin)
	var log_box := VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 8)
	log_margin.add_child(log_box)
	var log_title := Label.new()
	log_title.text = "电台日志"
	log_title.add_theme_font_size_override("font_size", 22)
	log_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	log_box.add_child(log_title)
	log_body = RichTextLabel.new()
	log_body.fit_content = false
	log_body.bbcode_enabled = false
	log_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_body.add_theme_font_size_override("normal_font_size", 14)
	log_body.add_theme_color_override("default_color", Color(0.78, 0.88, 0.84))
	log_box.add_child(log_body)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)

	phase_label = Label.new()
	phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_label.add_theme_font_size_override("font_size", 17)
	phase_label.add_theme_color_override("font_color", Color(0.85, 0.92, 0.88))
	footer.add_child(phase_label)

	hint_label = Label.new()
	hint_label.custom_minimum_size = Vector2(270, 0)
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.add_theme_color_override("font_color", Color(0.72, 0.92, 0.95))
	footer.add_child(hint_label)

	end_day_button = Button.new()
	end_day_button.text = "夜间结算"
	end_day_button.custom_minimum_size = Vector2(150, 46)
	end_day_button.disabled = true
	end_day_button.pressed.connect(_show_day_report)
	footer.add_child(end_day_button)

	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)

func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.032, 0.043, 0.043, 0.94)
	style.border_color = Color(0.30, 0.55, 0.58, 0.70)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _wrap_margin(content: Control, margin_value: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", margin_value)
	margin.add_theme_constant_override("margin_right", margin_value)
	margin.add_theme_constant_override("margin_top", margin_value)
	margin.add_theme_constant_override("margin_bottom", margin_value)
	margin.add_child(content)
	return margin

func _start_day() -> void:
	_clear_overlay()
	dispatched_today.clear()
	resolved_event_ids_today.clear()
	tuned_event_ids_today.clear()
	resolved_count = 0
	daily_actions_used = 0
	daily_action_limit = 3 if day == 1 else 2
	if int(resources.get("power", 0)) <= 0:
		daily_action_limit = 1
	tuning_charges = 2 if day <= 3 else 1
	day_result_lines = []
	day_events = _select_events_for_day()
	if day_events.is_empty():
		push_warning("No events selected for day %d" % day)
	_update_static_panels()
	_render_signal_cards()
	end_day_button.disabled = true
	day_label.text = "DAY %d / 7" % day
	phase_label.text = "晨间状态：接收 %d 条信号。今日只能回应 %d 次，未处理信号会在夜里变成后果。" % [day_events.size(), daily_action_limit]
	hint_label.text = "校准信号能看清代价，但会消耗电力。广播会提高暴露度。"

func _select_events_for_day() -> Array[Dictionary]:
	if int(resources.get("power", 0)) <= 0 and day < MAX_DAY:
		var powerless := _event_by_id("powerless_weak_signal")
		return [powerless] if not powerless.is_empty() else []

	var selected: Array[Dictionary] = []
	for event in events:
		var data := event as Dictionary
		if int(data.get("fixed_day", 0)) == day:
			selected.append(data)

	for scheduled in scheduled_events.duplicate():
		if int(scheduled.get("day", 0)) != day:
			continue
		var follow := _event_by_id(str(scheduled.get("event_id", "")))
		if not follow.is_empty() and not _contains_event_id(selected, str(follow.get("id", ""))):
			selected.append(follow)
		scheduled_events.erase(scheduled)

	var pool: Array[Dictionary] = []
	for event in events:
		var data := event as Dictionary
		var event_id := str(data.get("id", ""))
		if event_id == "powerless_weak_signal":
			continue
		if int(data.get("fixed_day", 0)) > 0:
			continue
		if used_event_ids.has(event_id) or _contains_event_id(selected, event_id):
			continue
		if _event_is_eligible(data):
			pool.append(data)
	pool.shuffle()

	while selected.size() < 3 and not pool.is_empty():
		selected.append(pool.pop_back())
	return selected.slice(0, 3)

func _event_is_eligible(event: Dictionary) -> bool:
	var day_range: Array = event.get("day_range", [1, MAX_DAY])
	if day_range.size() >= 2:
		if day < int(day_range[0]) or day > int(day_range[1]):
			return false
	var conditions: Dictionary = event.get("conditions", {})
	for tag_name in conditions.get("tags_all", []):
		if not tags.has(str(tag_name)):
			return false
	var any_tags: Array = conditions.get("tags_any", [])
	if not any_tags.is_empty():
		var found := false
		for tag_name in any_tags:
			if tags.has(str(tag_name)):
				found = true
				break
		if not found:
			return false
	for tag_name in conditions.get("not_tags", []):
		if tags.has(str(tag_name)):
			return false
	if conditions.has("trust_below") and int(resources.get("trust", 0)) >= int(conditions["trust_below"]):
		return false
	if conditions.has("trust_above") and int(resources.get("trust", 0)) <= int(conditions["trust_above"]):
		return false
	var resource_below: Dictionary = conditions.get("resource_below", {})
	for key in resource_below.keys():
		if int(resources.get(str(key), 0)) >= int(resource_below[key]):
			return false
	return true

func _event_by_id(event_id: String) -> Dictionary:
	for event in events:
		var data := event as Dictionary
		if str(data.get("id", "")) == event_id:
			return data
	return {}

func _contains_event_id(list: Array[Dictionary], event_id: String) -> bool:
	for event in list:
		if str(event.get("id", "")) == event_id:
			return true
	return false

func _render_signal_cards() -> void:
	for child in signal_container.get_children():
		child.queue_free()
	for i in range(day_events.size()):
		var card := SIGNAL_CARD_SCENE.instantiate()
		card.modulate.a = 0.0
		card.choice_selected.connect(_on_choice_selected)
		card.tune_requested.connect(_on_tune_requested)
		signal_container.add_child(card)
		var event_id := str(day_events[i].get("id", ""))
		card.setup(day_events[i], self, tuned_event_ids_today.has(event_id), resolved_event_ids_today.has(event_id))
		var tween := create_tween()
		tween.tween_interval(0.06 * float(i))
		tween.tween_property(card, "modulate:a", 1.0, 0.22)

func _update_static_panels() -> void:
	_update_resources()
	_update_members()
	_update_logs()

func _update_resources() -> void:
	for child in resource_box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "避难所状态"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	resource_box.add_child(title)

	var labels := {
		"power": "电力",
		"food": "食物",
		"medicine": "药品",
		"trust": "信任"
	}
	var max_values := {
		"power": 12,
		"food": 14,
		"medicine": 10,
		"trust": 100
	}
	for key in ["power", "food", "medicine", "trust"]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		resource_box.add_child(row)
		var label := Label.new()
		label.text = "%s：%d" % [labels[key], int(resources.get(key, 0))]
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", _resource_color(key))
		row.add_child(label)
		var bar := ProgressBar.new()
		bar.max_value = float(max_values[key])
		bar.value = clamp(float(resources.get(key, 0)), 0.0, float(max_values[key]))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		row.add_child(bar)

	var score_hint := Label.new()
	score_hint.text = "影响力：%d\n已救人数：%d\n广播次数：%d" % [
		int(stats.get("influence", 0)),
		int(stats.get("rescued", 0)),
		int(stats.get("broadcasts", 0))
	]
	score_hint.add_theme_font_size_override("font_size", 16)
	score_hint.add_theme_color_override("font_color", Color(0.82, 0.92, 0.88))
	resource_box.add_child(score_hint)

	var action_hint := Label.new()
	action_hint.text = "今日回应：%d / %d\n校准次数：%d\n暴露度：%d" % [
		daily_actions_used,
		daily_action_limit,
		tuning_charges,
		int(stats.get("threat", 0))
	]
	action_hint.add_theme_font_size_override("font_size", 16)
	action_hint.add_theme_color_override("font_color", Color(0.98, 0.78, 0.48) if int(stats.get("threat", 0)) >= 5 else Color(0.72, 0.92, 0.95))
	resource_box.add_child(action_hint)

func _resource_color(key: String) -> Color:
	if int(resources.get(key, 0)) <= 0:
		return Color(1.0, 0.34, 0.28)
	if key == "trust" and int(resources.get(key, 0)) < 20:
		return Color(1.0, 0.54, 0.30)
	match key:
		"power":
			return Color(0.72, 0.92, 1.0)
		"food":
			return Color(0.86, 0.96, 0.64)
		"medicine":
			return Color(0.62, 1.0, 0.74)
		_:
			return Color(1.0, 0.84, 0.45)

func _update_members() -> void:
	for child in member_slot.get_children():
		child.queue_free()
	var member_panel := MEMBER_PANEL_SCENE.instantiate()
	member_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	member_slot.add_child(member_panel)
	member_panel.setup(members)

func _update_logs() -> void:
	if log_body == null:
		return
	log_body.text = "\n".join(logs.slice(max(0, logs.size() - 12), logs.size()))

func can_apply_choice(choice: Dictionary) -> bool:
	if daily_actions_used >= daily_action_limit:
		return false
	var cost := _modified_cost(choice)
	for key in cost.keys():
		if resources.has(str(key)) and int(resources.get(str(key), 0)) < int(cost[key]):
			return false
	if choice.get("dispatch", false):
		var member_id := str(choice.get("member", ""))
		if member_id == "":
			return _first_available_member() != ""
		if not members.has(member_id):
			return false
		var status := str(members[member_id].get("status", "normal"))
		return status == "normal" or status == "tired"
	return true

func can_tune_event(event_data: Dictionary) -> bool:
	var event_id := str(event_data.get("id", ""))
	if tuned_event_ids_today.has(event_id) or resolved_event_ids_today.has(event_id):
		return false
	return tuning_charges > 0 and int(resources.get("power", 0)) > 0

func _modified_cost(choice: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var raw: Dictionary = choice.get("cost", {})
	for key in raw.keys():
		result[str(key)] = int(raw[key])
	if str(choice.get("type", "")) == "broadcast" and _member_available("shen_luo"):
		result["power"] = max(0, int(result.get("power", 0)) - 1)
	if str(choice.get("type", "")) == "treat" and _member_available("xu_lan"):
		result["medicine"] = max(0, int(result.get("medicine", 0)) - 1)
	if str(choice.get("type", "")) == "refuse_rescue" and _member_available("xu_lan"):
		result["trust"] = int(result.get("trust", 0)) + 1
	return result

func _member_available(member_id: String) -> bool:
	if not members.has(member_id):
		return false
	var status := str(members[member_id].get("status", "normal"))
	return status == "normal" or status == "tired"

func _first_available_member() -> String:
	for member_id in members.keys():
		if _member_available(str(member_id)):
			return str(member_id)
	return ""

func _on_choice_selected(event_data: Dictionary, choice: Dictionary) -> void:
	if daily_actions_used >= daily_action_limit:
		return
	var event_id := str(event_data.get("id", ""))
	if resolved_event_ids_today.has(event_id):
		return
	if not used_event_ids.has(str(event_data.get("id", ""))):
		used_event_ids.append(str(event_data.get("id", "")))
	resolved_event_ids_today.append(event_id)
	daily_actions_used += 1
	_apply_choice(event_data, choice)
	resolved_count += 1
	_update_static_panels()
	_render_signal_cards()
	end_day_button.disabled = resolved_count < day_events.size() and daily_actions_used < daily_action_limit
	if end_day_button.disabled:
		hint_label.text = "继续处理剩余信号。"
	else:
		hint_label.text = "回应额度已用完或当天信号已处理，可以进入夜间结算。"
	if int(resources.get("trust", 0)) <= 0:
		end_day_button.disabled = false
		hint_label.text = "信任已经归零，夜间结算将进入崩溃结局。"

func _on_tune_requested(event_data: Dictionary) -> void:
	if not can_tune_event(event_data):
		return
	var event_id := str(event_data.get("id", ""))
	tuned_event_ids_today.append(event_id)
	tuning_charges -= 1
	resources["power"] = max(0, int(resources.get("power", 0)) - 1)
	logs.append("Day %d / 校准：%s 的噪声被压低，代价和风险变得清楚。" % [day, str(event_data.get("title", ""))])
	_update_static_panels()
	_render_signal_cards()

func _apply_choice(event_data: Dictionary, choice: Dictionary) -> void:
	var cost := _modified_cost(choice)
	for key in cost.keys():
		if resources.has(str(key)):
			resources[str(key)] = max(0, int(resources[str(key)]) - int(cost[key]))
	var reward: Dictionary = choice.get("reward", {})
	for key in reward.keys():
		_apply_reward(str(key), int(reward[key]), choice)

	var choice_type := str(choice.get("type", ""))
	match choice_type:
		"rescue":
			stats["rescues"] = int(stats["rescues"]) + 1
		"trade":
			stats["trades"] = int(stats["trades"]) + 1
		"broadcast":
			stats["broadcasts"] = int(stats["broadcasts"]) + 1
			stats["threat"] = int(stats.get("threat", 0)) + 2
		"hide":
			stats["lies"] = int(stats["lies"]) + 1
		"refuse_rescue":
			stats["refused_rescue"] = int(stats["refused_rescue"]) + 1

	for tag_name in choice.get("tags", []):
		_add_tag(str(tag_name))
	if not tuned_event_ids_today.has(str(event_data.get("id", ""))) and str(event_data.get("confidence", "")) in ["低", "混杂"]:
		_apply_uncalibrated_penalty(event_data, choice)
	for scheduled in choice.get("schedule", []):
		if typeof(scheduled) == TYPE_DICTIONARY:
			scheduled_events.append((scheduled as Dictionary).duplicate(true))
	if choice.get("dispatch", false):
		_resolve_dispatch(choice)

	var line := "Day %d / %s：%s" % [day, str(event_data.get("title", "")), str(choice.get("log", "已记录。"))]
	logs.append(line)
	day_result_lines.append(str(choice.get("log", "已记录。")))

func _apply_uncalibrated_penalty(event_data: Dictionary, choice: Dictionary) -> void:
	if str(choice.get("type", "")) == "hide":
		return
	var penalty_roll := rng.randf()
	if penalty_roll < 0.55:
		resources["trust"] = max(0, int(resources.get("trust", 0)) - 2)
		stats["threat"] = int(stats.get("threat", 0)) + 1
		var text := "未校准处理低可信信号，后续出现了矛盾回传：-2 信任，+1 暴露度。"
		day_result_lines.append(text)
		logs.append("Day %d / 噪声误判：%s" % [day, text])

func _apply_reward(key: String, value: int, choice: Dictionary) -> void:
	if key in ["power", "food", "medicine", "trust"]:
		var adjusted := value
		if str(choice.get("type", "")) == "trade" and _member_available("lao_zhou") and key != "trust":
			adjusted += 1
		if _member_available("lao_zhou") and key == "trust" and str(choice.get("type", "")) == "trade":
			adjusted -= 1
		resources[key] = max(0, int(resources.get(key, 0)) + adjusted)
	elif key == "rescued":
		var rescued_gain := value
		if _member_available("a_qing") and str(choice.get("type", "")) == "rescue":
			rescued_gain += 1
		stats["rescued"] = int(stats.get("rescued", 0)) + rescued_gain
	elif key == "influence":
		stats["influence"] = int(stats.get("influence", 0)) + value
	elif stats.has(key):
		stats[key] = int(stats.get(key, 0)) + value

func _add_tag(tag_name: String) -> void:
	tags[tag_name] = int(tags.get(tag_name, 0)) + 1

func _resolve_dispatch(choice: Dictionary) -> void:
	var member_id := str(choice.get("member", ""))
	if member_id == "":
		member_id = _first_available_member()
	if member_id == "" or not members.has(member_id):
		return
	stats["dispatches"] = int(stats.get("dispatches", 0)) + 1
	dispatched_today.append(member_id)

	var risk: Dictionary = choice.get("risk", {})
	var injury := float(risk.get("injury", 0.0))
	var missing := float(risk.get("missing", 0.0))
	var tired := float(risk.get("tired", 0.35))
	if member_id == "shen_luo":
		injury += 0.12
		missing += 0.08
	if member_id == "a_qing":
		injury = max(0.0, injury - 0.15)
		missing = max(0.0, missing - 0.10)
	if str(members[member_id].get("status", "normal")) == "tired":
		injury += 0.12
		missing += 0.08

	var roll := rng.randf()
	if roll < missing:
		members[member_id]["status"] = "missing"
		day_result_lines.append("%s 没有按时回到电台。" % str(members[member_id]["name"]))
	elif roll < missing + injury:
		members[member_id]["status"] = "injured"
		day_result_lines.append("%s 带伤回来，需要处理伤口。" % str(members[member_id]["name"]))
	elif roll < missing + injury + tired:
		members[member_id]["status"] = "tired"
		day_result_lines.append("%s 完成外出，但已经疲惫。" % str(members[member_id]["name"]))
	else:
		day_result_lines.append("%s 平安回到电台。" % str(members[member_id]["name"]))

func _show_day_report() -> void:
	var lines := _night_settlement()
	_clear_overlay()
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var report := DAY_REPORT_SCENE.instantiate()
	report.continue_pressed.connect(_continue_after_report)
	overlay_layer.add_child(report)
	report.setup(day, lines, day < MAX_DAY and not _is_collapsed())

func _night_settlement() -> Array[String]:
	var lines: Array[String] = []
	for event in day_events:
		var event_id := str(event.get("id", ""))
		if resolved_event_ids_today.has(event_id):
			continue
		_apply_unresolved_signal_penalty(event, lines)
	lines.append_array(day_result_lines)
	if lines.is_empty():
		lines.append("今天没有留下足够明确的记录。")

	var food_upkeep := 2
	var power_upkeep := 1
	resources["food"] = max(0, int(resources.get("food", 0)) - food_upkeep)
	resources["power"] = max(0, int(resources.get("power", 0)) - power_upkeep)
	lines.append("夜间消耗：-%d 食物，-%d 电力。" % [food_upkeep, power_upkeep])

	if int(resources.get("food", 0)) <= 0:
		resources["trust"] = max(0, int(resources.get("trust", 0)) - 6)
		lines.append("食物见底，队伍的信任下降。")
		_tire_all_available()
	if int(resources.get("power", 0)) <= 0:
		lines.append("电力耗尽，明天只能收到一条弱信号。")
	if int(resources.get("medicine", 0)) <= 0:
		lines.append("药品耗尽，伤员只能等待。")
	if int(stats.get("threat", 0)) >= 6:
		resources["trust"] = max(0, int(resources.get("trust", 0)) - 3)
		resources["food"] = max(0, int(resources.get("food", 0)) - 1)
		lines.append("暴露度过高，夜里有人试探东门：-3 信任，-1 食物。")
	elif int(stats.get("threat", 0)) >= 3:
		resources["trust"] = max(0, int(resources.get("trust", 0)) - 1)
		lines.append("频段被更多人盯上，基地开始紧张：-1 信任。")
	stats["threat"] = max(0, int(stats.get("threat", 0)) - 2)

	_try_heal_one_injured(lines)
	_recover_tired_members(lines)

	if int(resources.get("trust", 0)) < 20 and day < MAX_DAY and not _scheduled_or_used("internal_low_trust"):
		scheduled_events.append({"day": min(MAX_DAY, day + 1), "event_id": "internal_low_trust"})
		lines.append("低信任正在酝酿内部冲突。")

	if resolved_count == 0:
		stats["silent_days"] = int(stats.get("silent_days", 0)) + 1
	logs.append("第 %d 夜：%s" % [day, " / ".join(lines.slice(max(0, lines.size() - 3), lines.size()))])
	_update_static_panels()
	return lines

func _apply_unresolved_signal_penalty(event: Dictionary, lines: Array[String]) -> void:
	var category := str(event.get("category", ""))
	var title := str(event.get("title", "未处理信号"))
	match category:
		"rescue":
			resources["trust"] = max(0, int(resources.get("trust", 0)) - 4)
			lines.append("未处理：%s。求救者没有等到回应，-4 信任。" % title)
		"faction":
			stats["threat"] = int(stats.get("threat", 0)) + 2
			resources["trust"] = max(0, int(resources.get("trust", 0)) - 1)
			lines.append("未处理：%s。外部势力开始自行解释你的沉默，+2 暴露度。" % title)
		"rumor":
			stats["threat"] = int(stats.get("threat", 0)) + 1
			resources["trust"] = max(0, int(resources.get("trust", 0)) - 2)
			lines.append("未处理：%s。谣言继续扩散，-2 信任。" % title)
		"resource", "trade":
			lines.append("未处理：%s。可能的物资机会消失了。" % title)
		_:
			resources["trust"] = max(0, int(resources.get("trust", 0)) - 1)
			lines.append("未处理：%s。控制室记下了这次沉默。" % title)

func _try_heal_one_injured(lines: Array[String]) -> void:
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		if str(member.get("status", "")) != "injured":
			continue
		var cost := 1
		if _member_available("xu_lan"):
			cost = 0
		if int(resources.get("medicine", 0)) >= cost:
			resources["medicine"] = max(0, int(resources.get("medicine", 0)) - cost)
			member["status"] = "normal"
			lines.append("%s 的伤势被处理，恢复正常。" % str(member.get("name", "")))
		return

func _recover_tired_members(lines: Array[String]) -> void:
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		if str(member.get("status", "")) == "tired" and not dispatched_today.has(str(member_id)):
			member["status"] = "normal"
			lines.append("%s 休息后恢复。" % str(member.get("name", "")))

func _tire_all_available() -> void:
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		if str(member.get("status", "")) == "normal":
			member["status"] = "tired"

func _scheduled_or_used(event_id: String) -> bool:
	if used_event_ids.has(event_id):
		return true
	for scheduled in scheduled_events:
		if str(scheduled.get("event_id", "")) == event_id:
			return true
	return false

func _continue_after_report() -> void:
	if _is_collapsed() or day >= MAX_DAY:
		_show_final_score()
		return
	day += 1
	_start_day()

func _is_collapsed() -> bool:
	if int(resources.get("trust", 0)) <= 0:
		return true
	var capable := 0
	for member_id in members.keys():
		var status := str(members[member_id].get("status", "normal"))
		if status == "normal" or status == "tired":
			capable += 1
	return capable <= 0

func _show_final_score() -> void:
	_clear_overlay()
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var final := FINAL_SCORE_SCENE.instantiate()
	final.restart_pressed.connect(func() -> void:
		_reset_game()
		_start_day()
	)
	overlay_layer.add_child(final)
	var score := _calculate_score()
	final.setup(score, _calculate_titles(score), logs)

func _calculate_score() -> Dictionary:
	var active_members := 0
	var member_penalty := 0
	for member_id in members.keys():
		var status := str(members[member_id].get("status", "normal"))
		if status != "missing":
			active_members += 1
		if status == "tired":
			member_penalty += 4
		elif status == "injured":
			member_penalty += 10
		elif status == "missing":
			member_penalty += 16
	var survivors := active_members + int(stats.get("rescued", 0))
	var influence := int(stats.get("influence", 0)) + int(stats.get("broadcasts", 0)) * 3 + int(stats.get("truths", 0)) * 2 - int(stats.get("lies", 0))
	var stability := int(resources.get("trust", 0)) + int(resources.get("power", 0)) * 3 + int(resources.get("food", 0)) * 3 + int(resources.get("medicine", 0)) * 4 - member_penalty
	var rating := "勉强维持"
	if _is_collapsed() or int(stats.get("final_broadcast", 0)) <= 0:
		rating = "崩溃"
	else:
		var passed := 0
		if survivors >= 7:
			passed += 1
		if influence >= 18:
			passed += 1
		if stability >= 70:
			passed += 1
		rating = "稳定播出" if passed >= 2 else "勉强维持"
	return {
		"survivors": survivors,
		"influence": influence,
		"stability": stability,
		"rating": rating
	}

func _calculate_titles(score: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if int(resources.get("trust", 0)) >= 65 and int(score.get("influence", 0)) >= 18:
		result.append("灯塔守夜人")
	if int(resources.get("food", 0)) + int(resources.get("medicine", 0)) + int(resources.get("power", 0)) >= 14 and int(stats.get("rescued", 0)) <= 2:
		result.append("冷血站长")
	if int(stats.get("lies", 0)) >= 2 or tags.has("rumor_spread"):
		result.append("谣言制造者")
	if int(stats.get("rescues", 0)) >= 3 and int(resources.get("medicine", 0)) <= 1:
		result.append("药箱见底")
	if int(stats.get("blacktower", 0)) >= 2 or tags.has("blacktower_partner"):
		result.append("黑塔合伙人")
	if int(stats.get("broadcasts", 0)) <= 1 and not _is_collapsed():
		result.append("沉默频段")
	if result.is_empty() and str(score.get("rating", "")) == "稳定播出":
		result.append("临时站长")
	return result.slice(0, 3)

func _clear_overlay() -> void:
	if overlay_layer == null:
		return
	for child in overlay_layer.get_children():
		child.queue_free()
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
