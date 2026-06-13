extends PanelContainer

signal choice_selected(event_data: Dictionary, choice_data: Dictionary)
signal tune_requested(event_data: Dictionary)

var event_data: Dictionary = {}
var controller: Node
var resolved := false
var tuned := false
var outcome_label: Label

func setup(new_event: Dictionary, new_controller: Node, is_tuned := false, is_resolved := false) -> void:
	event_data = new_event
	controller = new_controller
	tuned = is_tuned
	resolved = is_resolved
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.048, 0.048, 0.96)
	panel.border_color = Color(0.28, 0.55, 0.58, 0.85)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 14)
	root.add_child(pad)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	pad.add_child(box)

	var meta := Label.new()
	meta.text = "%s / 可信度 %s%s" % [
		str(event_data.get("source", "未知")),
		str(event_data.get("confidence", "?")),
		" / 已校准" if tuned else " / 未校准"
	]
	meta.add_theme_color_override("font_color", Color(0.58, 0.92, 0.95))
	meta.add_theme_font_size_override("font_size", 14)
	box.add_child(meta)

	var title := Label.new()
	title.text = str(event_data.get("title", "未命名信号"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	var body := Label.new()
	body.text = str(event_data.get("signal_text", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	body.add_theme_font_size_override("font_size", 15)
	box.add_child(body)

	var tuning_note := Label.new()
	tuning_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tuning_note.add_theme_font_size_override("font_size", 13)
	tuning_note.add_theme_color_override("font_color", Color(0.62, 0.84, 0.90) if tuned else Color(0.92, 0.70, 0.42))
	tuning_note.text = _tuned_detail_text() if tuned else "未校准：按钮不会显示完整代价和收益。低可信信号直接处理可能引发额外损耗。"
	box.add_child(tuning_note)

	if not tuned and not resolved:
		var tune_button := Button.new()
		tune_button.text = "校准信号  -1电力"
		tune_button.custom_minimum_size = Vector2(0, 38)
		tune_button.disabled = controller != null and not controller.can_tune_event(event_data)
		tune_button.pressed.connect(func() -> void:
			tune_requested.emit(event_data)
		)
		box.add_child(tune_button)

	var sep := HSeparator.new()
	box.add_child(sep)

	var choices: Array = event_data.get("choices", [])
	for choice in choices:
		var button := Button.new()
		button.text = _choice_button_text(choice)
		button.tooltip_text = str(choice.get("description", ""))
		button.custom_minimum_size = Vector2(0, 46)
		button.disabled = controller != null and not controller.can_apply_choice(choice)
		if resolved:
			button.disabled = true
		button.pressed.connect(func() -> void:
			_select_choice(choice)
		)
		box.add_child(button)

	outcome_label = Label.new()
	outcome_label.text = "已处理。等待夜间结算。" if resolved else ""
	outcome_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outcome_label.add_theme_color_override("font_color", Color(0.72, 0.95, 0.73))
	outcome_label.add_theme_font_size_override("font_size", 14)
	box.add_child(outcome_label)

func _choice_button_text(choice: Dictionary) -> String:
	var parts: Array[String] = [str(choice.get("label", "选择"))]
	if not tuned:
		if choice.get("dispatch", false):
			parts.append("派遣")
		parts.append("代价未知")
		return "  ".join(parts)
	var cost_text := _delta_text(choice.get("cost", {}), "-")
	var reward_text := _delta_text(choice.get("reward", {}), "+")
	if cost_text != "":
		parts.append(cost_text)
	if reward_text != "":
		parts.append(reward_text)
	if choice.get("dispatch", false):
		parts.append("派遣")
	return "  ".join(parts)

func _delta_text(delta: Variant, prefix: String) -> String:
	if typeof(delta) != TYPE_DICTIONARY:
		return ""
	var labels := {
		"power": "电",
		"food": "食",
		"medicine": "药",
		"trust": "信",
		"influence": "声",
		"rescued": "人"
	}
	var result: Array[String] = []
	for key in delta.keys():
		var value := int(delta[key])
		if value == 0:
			continue
		var label := str(labels.get(str(key), str(key)))
		if prefix == "-":
			result.append("%s%d%s" % [prefix, abs(value), label])
		else:
			result.append("%s%d%s" % [prefix, value, label])
	return " ".join(result)

func _tuned_detail_text() -> String:
	var choices: Array = event_data.get("choices", [])
	var risky := 0
	var dispatch_count := 0
	for choice in choices:
		if choice.get("dispatch", false):
			dispatch_count += 1
		var risk: Dictionary = choice.get("risk", {})
		if not risk.is_empty():
			risky += 1
	var detail := "校准完成："
	if dispatch_count > 0:
		detail += "含 %d 个派遣选项；" % dispatch_count
	if risky > 0:
		detail += "存在受伤/失踪风险；"
	if str(event_data.get("confidence", "")) in ["低", "混杂"]:
		detail += "来源仍不可靠；"
	return detail.rstrip(";；")

func _select_choice(choice: Dictionary) -> void:
	if resolved:
		return
	resolved = true
	for node in find_children("*", "Button", true, false):
		(node as Button).disabled = true
	if outcome_label != null:
		outcome_label.text = str(choice.get("log", "已记录。"))
	choice_selected.emit(event_data, choice)
