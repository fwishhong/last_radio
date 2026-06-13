extends PanelContainer

signal restart_pressed

func setup(score: Dictionary, title_names: Array[String], logs: Array[String]) -> void:
	for child in get_children():
		child.queue_free()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.018, 0.026, 0.028, 0.98)
	panel.border_color = Color(0.38, 0.76, 0.82, 0.90)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	add_theme_stylebox_override("panel", panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 28)
	margin.add_child(root)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 16)
	root.add_child(left)

	var title := Label.new()
	title.text = "第七日最终广播"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	left.add_child(title)

	var rating := Label.new()
	rating.text = str(score.get("rating", "未知结局"))
	rating.add_theme_font_size_override("font_size", 46)
	rating.add_theme_color_override("font_color", _rating_color(str(score.get("rating", ""))))
	left.add_child(rating)

	var numbers := Label.new()
	numbers.text = "幸存人数：%d\n电台影响力：%d\n基地稳定度：%d" % [
		int(score.get("survivors", 0)),
		int(score.get("influence", 0)),
		int(score.get("stability", 0))
	]
	numbers.add_theme_font_size_override("font_size", 22)
	numbers.add_theme_color_override("font_color", Color(0.84, 0.94, 0.90))
	left.add_child(numbers)

	var badges := Label.new()
	badges.text = "结算称号：%s" % ("、".join(title_names) if not title_names.is_empty() else "无名频段")
	badges.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badges.add_theme_font_size_override("font_size", 20)
	badges.add_theme_color_override("font_color", Color(0.78, 0.92, 1.0))
	left.add_child(badges)

	var restart := Button.new()
	restart.text = "重新开局"
	restart.custom_minimum_size = Vector2(0, 56)
	restart.pressed.connect(func() -> void:
		restart_pressed.emit()
	)
	left.add_child(restart)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(420, 0)
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)

	var log_title := Label.new()
	log_title.text = "关键日志"
	log_title.add_theme_font_size_override("font_size", 24)
	log_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	right.add_child(log_title)

	var log_body := RichTextLabel.new()
	log_body.bbcode_enabled = false
	log_body.fit_content = false
	log_body.text = "\n".join(logs.slice(max(0, logs.size() - 12), logs.size()))
	log_body.add_theme_font_size_override("normal_font_size", 15)
	log_body.add_theme_color_override("default_color", Color(0.78, 0.88, 0.86))
	log_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_body)

func _rating_color(rating: String) -> Color:
	if rating.find("稳定") >= 0:
		return Color(0.56, 1.0, 0.68)
	if rating.find("崩溃") >= 0:
		return Color(1.0, 0.36, 0.30)
	return Color(1.0, 0.78, 0.40)
