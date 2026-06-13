extends PanelContainer

func setup(members: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.042, 0.046, 0.94)
	panel.border_color = Color(0.36, 0.58, 0.64, 0.72)
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
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "基地成员"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	box.add_child(title)

	for id in members.keys():
		var member: Dictionary = members[id]
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		box.add_child(row)

		var name := Label.new()
		name.text = "%s  [%s]" % [str(member.get("name", id)), _status_label(str(member.get("status", "normal")))]
		name.add_theme_font_size_override("font_size", 16)
		name.add_theme_color_override("font_color", _status_color(str(member.get("status", "normal"))))
		row.add_child(name)

		var role := Label.new()
		role.text = "%s\n%s" % [str(member.get("role", "")), str(member.get("skill", member.get("trait", "")))]
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role.add_theme_font_size_override("font_size", 13)
		role.add_theme_color_override("font_color", Color(0.72, 0.84, 0.82))
		row.add_child(role)

		var help_text := _status_help(str(member.get("status", "normal")))
		if help_text != "":
			var help := Label.new()
			help.text = help_text
			help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			help.add_theme_font_size_override("font_size", 12)
			help.add_theme_color_override("font_color", Color(0.96, 0.78, 0.45))
			row.add_child(help)

func _status_label(status: String) -> String:
	match status:
		"normal":
			return "正常"
		"tired":
			return "疲惫"
		"injured":
			return "受伤"
		"missing":
			return "失踪"
		_:
			return status

func _status_color(status: String) -> Color:
	match status:
		"normal":
			return Color(0.78, 0.96, 0.80)
		"tired":
			return Color(0.96, 0.78, 0.45)
		"injured":
			return Color(1.0, 0.45, 0.38)
		"missing":
			return Color(0.52, 0.58, 0.60)
		_:
			return Color.WHITE

func _status_help(status: String) -> String:
	match status:
		"tired":
			return "疲惫：仍可派遣，但准备 -8；可通过轮休、医务角或部分夜间安排恢复。"
		"injured":
			return "受伤：不可正常恢复，需医务分诊或医务角处理。"
		_:
			return ""
