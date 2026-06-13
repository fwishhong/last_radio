extends PanelContainer

signal continue_pressed

func setup(day: int, lines: Array[String], can_continue: bool) -> void:
	for child in get_children():
		child.queue_free()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.02, 0.028, 0.03, 0.98)
	panel.border_color = Color(0.78, 0.70, 0.42, 0.95)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.corner_radius_top_left = 8
	panel.corner_radius_top_right = 8
	panel.corner_radius_bottom_left = 8
	panel.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = "第 %d 夜电台日志" % day
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	box.add_child(title)

	var body := Label.new()
	body.text = "\n".join(lines)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	box.add_child(body)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var button := Button.new()
	button.text = "进入下一天" if can_continue else "查看最终评分"
	button.custom_minimum_size = Vector2(0, 52)
	button.pressed.connect(func() -> void:
		continue_pressed.emit()
	)
	box.add_child(button)
