extends PanelContainer

signal continue_pressed

class NightBaseBoard:
	extends Control

	var active_facility := "base"
	var active_severity := "neutral"
	var event_index := 0
	var total_events := 1

	func _draw() -> void:
		var rect := get_rect()
		draw_rect(rect, Color(0.011, 0.018, 0.018, 0.98), true)
		var floor := Rect2(rect.size * Vector2(0.08, 0.12), rect.size * Vector2(0.84, 0.74))
		draw_rect(floor, Color(0.045, 0.056, 0.050, 0.92), true)
		draw_rect(floor, Color(0.26, 0.52, 0.54, 0.70), false, 2.0)
		draw_line(floor.position + Vector2(0, floor.size.y * 0.52), floor.position + Vector2(floor.size.x, floor.size.y * 0.52), Color(0.22, 0.40, 0.42, 0.42), 2.0)
		draw_line(floor.position + Vector2(floor.size.x * 0.48, 0), floor.position + Vector2(floor.size.x * 0.48, floor.size.y), Color(0.22, 0.40, 0.42, 0.42), 2.0)

		var base_pos := _facility_position("base")
		for facility_id in ["antenna", "gate", "infirmary", "battery"]:
			var pos := _facility_position(facility_id)
			draw_line(base_pos, pos, Color(0.18, 0.38, 0.40, 0.34), 2.0)

		for facility_id in ["base", "antenna", "gate", "infirmary", "battery"]:
			_draw_facility(facility_id)

		var progress_width := floor.size.x * 0.64
		var progress_pos := floor.position + Vector2(floor.size.x * 0.18, floor.size.y + 22.0)
		draw_rect(Rect2(progress_pos, Vector2(progress_width, 5.0)), Color(0.16, 0.27, 0.27, 0.9), true)
		var ratio: float = float(event_index + 1) / max(1.0, float(total_events))
		draw_rect(Rect2(progress_pos, Vector2(progress_width * ratio, 5.0)), _severity_color(active_severity), true)
		draw_string(get_theme_default_font(), progress_pos + Vector2(-8, 20), "%d/%d" % [event_index + 1, total_events], HORIZONTAL_ALIGNMENT_LEFT, 80, 13, Color(0.78, 0.88, 0.84))

	func _draw_facility(facility_id: String) -> void:
		var pos := _facility_position(facility_id)
		var active := facility_id == active_facility
		var color := _severity_color(active_severity) if active else Color(0.38, 0.75, 0.78, 0.90)
		var radius := 25.0 if facility_id != "base" else 31.0
		if active:
			draw_circle(pos, radius + 16.0, Color(color.r, color.g, color.b, 0.14))
			draw_circle(pos, radius + 7.0, Color(color.r, color.g, color.b, 0.20))
		draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.24))
		draw_circle(pos, radius * 0.58, color)
		draw_string(get_theme_default_font(), pos + Vector2(-45, -radius - 22.0), _facility_label(facility_id), HORIZONTAL_ALIGNMENT_CENTER, 90, 14, Color(0.88, 0.96, 0.91))

	func _facility_position(facility_id: String) -> Vector2:
		var rect := get_rect()
		match facility_id:
			"antenna":
				return Vector2(rect.size.x * 0.50, rect.size.y * 0.18)
			"gate":
				return Vector2(rect.size.x * 0.20, rect.size.y * 0.69)
			"infirmary":
				return Vector2(rect.size.x * 0.70, rect.size.y * 0.36)
			"battery":
				return Vector2(rect.size.x * 0.70, rect.size.y * 0.70)
			_:
				return Vector2(rect.size.x * 0.38, rect.size.y * 0.47)

	func _facility_label(facility_id: String) -> String:
		match facility_id:
			"antenna":
				return "天线"
			"gate":
				return "大门"
			"infirmary":
				return "医务"
			"battery":
				return "蓄电"
			_:
				return "电台"

	func _severity_color(severity: String) -> Color:
		match severity:
			"good":
				return Color(0.46, 0.92, 0.64, 1.0)
			"warning":
				return Color(1.0, 0.78, 0.34, 1.0)
			"danger":
				return Color(1.0, 0.36, 0.26, 1.0)
			_:
				return Color(0.55, 0.86, 0.90, 1.0)

var current_day := 1
var finished_slice := false
var events: Array[Dictionary] = []
var summary: Dictionary = {}
var visible_count := 1
var board: NightBaseBoard
var summary_strip: HBoxContainer
var event_list: VBoxContainer
var action_button: Button
var counter_label: Label

func setup(day: int, lines: Array, finished: bool, new_events: Array = [], new_summary: Dictionary = {}) -> void:
	current_day = day
	finished_slice = finished
	summary = new_summary.duplicate(true)
	events.clear()
	for entry in new_events:
		events.append(entry.duplicate(true))
	if events.is_empty():
		events = _events_from_lines(lines)
	visible_count = 1
	_build_ui()
	_refresh_replay_state()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()
	custom_minimum_size = Vector2(980, 600)
	add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.026, 0.028, 0.98), Color(0.80, 0.70, 0.42, 0.95), 2))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var title := Label.new()
	title.text = "第 %d 夜回放" % current_day
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	counter_label = Label.new()
	counter_label.add_theme_font_size_override("font_size", 16)
	counter_label.add_theme_color_override("font_color", Color(0.70, 0.86, 0.82))
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(counter_label)

	_build_summary_strip(root)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	board = NightBaseBoard.new()
	board.custom_minimum_size = Vector2(405, 405)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(board)

	var log_panel := PanelContainer.new()
	log_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.038, 0.036, 0.96), Color(0.22, 0.42, 0.40, 0.82), 1))
	log_panel.custom_minimum_size = Vector2(500, 0)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(log_panel)

	var log_margin := MarginContainer.new()
	log_margin.add_theme_constant_override("margin_left", 16)
	log_margin.add_theme_constant_override("margin_right", 16)
	log_margin.add_theme_constant_override("margin_top", 14)
	log_margin.add_theme_constant_override("margin_bottom", 14)
	log_panel.add_child(log_margin)

	event_list = VBoxContainer.new()
	event_list.add_theme_constant_override("separation", 8)
	log_margin.add_child(event_list)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)

	var hint := Label.new()
	hint.text = "无线电逐段回放今晚的后果"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.68, 0.78, 0.74))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)

	action_button = Button.new()
	action_button.custom_minimum_size = Vector2(190, 48)
	action_button.pressed.connect(_advance_replay)
	footer.add_child(action_button)

func _build_summary_strip(root: VBoxContainer) -> void:
	summary_strip = HBoxContainer.new()
	summary_strip.add_theme_constant_override("separation", 8)
	root.add_child(summary_strip)
	var texts := _summary_texts()
	for i in range(texts.size()):
		_add_summary_chip(summary_strip, texts[i], i)

func _add_summary_chip(root: HBoxContainer, text: String, index: int) -> void:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", _panel_style(Color(0.030, 0.044, 0.042, 0.95), _summary_color(index), 1))
	root.add_child(chip)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	chip.add_child(margin)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", _summary_color(index))
	margin.add_child(label)

func _summary_texts() -> Array[String]:
	var texts: Array[String] = []
	var deltas: Dictionary = summary.get("resource_delta", {})
	var resource_parts: Array[String] = []
	for key in ["food", "power", "medicine", "fuel", "parts", "trust", "influence", "threat", "rescued"]:
		var value := int(deltas.get(key, 0))
		if value != 0:
			resource_parts.append("%s%+d" % [_resource_short_name(key), value])
	if resource_parts.is_empty():
		resource_parts.append("资源持平")
	texts.append("资源  %s" % " ".join(resource_parts))
	var stress_delta := int(summary.get("stress_delta", 0))
	texts.append("压力  %+d" % stress_delta)
	var status_changes: Array = summary.get("status_changes", [])
	texts.append("状态  %s" % (" / ".join(status_changes) if not status_changes.is_empty() else "无变化"))
	texts.append("态势  %s" % _pressure_label(str(summary.get("pressure", "stable"))))
	return texts

func _summary_color(index: int) -> Color:
	if index == 3:
		match str(summary.get("pressure", "stable")):
			"good":
				return Color(0.46, 0.92, 0.64)
			"bad":
				return Color(1.0, 0.42, 0.34)
			_:
				return Color(0.55, 0.86, 0.90)
	return [Color(1.0, 0.84, 0.45), Color(0.74, 0.90, 1.0), Color(0.78, 0.92, 0.82), Color(0.55, 0.86, 0.90)][index]

func _resource_short_name(key: String) -> String:
	return {
		"power": "电",
		"food": "食",
		"medicine": "药",
		"fuel": "油",
		"parts": "件",
		"trust": "信",
		"influence": "影",
		"threat": "暴",
		"rescued": "救"
	}.get(key, key)

func _pressure_label(pressure: String) -> String:
	match pressure:
		"good":
			return "转好"
		"bad":
			return "吃紧"
		_:
			return "稳定"

func _refresh_replay_state() -> void:
	if events.is_empty():
		return
	for child in event_list.get_children():
		child.queue_free()
	var max_visible: int = min(visible_count, events.size())
	for i in range(max_visible):
		event_list.add_child(_event_card(events[i], i == max_visible - 1))
	var current: Dictionary = events[max_visible - 1]
	board.active_facility = str(current.get("facility", "base"))
	board.active_severity = str(current.get("severity", "neutral"))
	board.event_index = max_visible - 1
	board.total_events = events.size()
	board.queue_redraw()
	counter_label.text = "%d / %d" % [max_visible, events.size()]
	action_button.text = _final_button_text() if visible_count >= events.size() else "继续回放"

func _advance_replay() -> void:
	if visible_count < events.size():
		visible_count += 1
		_refresh_replay_state()
		return
	continue_pressed.emit()

func _event_card(event: Dictionary, active: bool) -> Control:
	var card := PanelContainer.new()
	var severity := str(event.get("severity", "neutral"))
	var bg := Color(0.035, 0.052, 0.050, 0.96)
	if active:
		bg = bg.lerp(_severity_color(severity), 0.16)
	card.add_theme_stylebox_override("panel", _panel_style(bg, _severity_color(severity).lerp(Color(0.12, 0.18, 0.18), 0.25), 1 if active else 0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	var title := Label.new()
	title.text = str(event.get("title", "基地记录"))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", _severity_color(severity))
	box.add_child(title)

	var body := Label.new()
	body.text = str(event.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	return card

func _events_from_lines(lines: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(lines.size()):
		result.append({
			"phase": "line",
			"title": "回放 %d" % (i + 1),
			"body": lines[i],
			"facility": "base",
			"resource": "none",
			"severity": "neutral"
		})
	if result.is_empty():
		result.append({
			"phase": "quiet",
			"title": "静默值守",
			"body": "今晚没有新的回放记录。",
			"facility": "base",
			"resource": "none",
			"severity": "neutral"
		})
	return result

func _final_button_text() -> String:
	return "完成切片" if finished_slice else "进入下一天"

func _severity_color(severity: String) -> Color:
	match severity:
		"good":
			return Color(0.46, 0.92, 0.64, 1.0)
		"warning":
			return Color(1.0, 0.78, 0.34, 1.0)
		"danger":
			return Color(1.0, 0.36, 0.26, 1.0)
		_:
			return Color(0.55, 0.86, 0.90, 1.0)

func _panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
