extends PanelContainer

signal location_selected(location_id: String)
signal city_action_requested(location_id: String, action_id: String)

var locations: Dictionary = {}
var selected_location_id := ""
var day_signals: Array = []
var locked_signal_ids: Array = []
var signal_marks: Dictionary = {}
var resources: Dictionary = {}
var city_action_defs: Dictionary = {}
var city_board: CityBoard
var detail_box: VBoxContainer
var texture_cache: Dictionary = {}

class CityBoard:
	extends Control

	var controller: PanelContainer
	var pulse := 0.0

	func _process(delta: float) -> void:
		pulse = fposmod(pulse + delta * 0.55, 1.0)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if controller == null:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var node_id := _node_at(event.position)
			if node_id != "":
				controller.call("_select_location_on_board", node_id)

	func _draw() -> void:
		if controller == null:
			return
		var rect := get_rect()
		draw_rect(rect, Color(0.015, 0.026, 0.026, 0.97), true)
		var bg: Texture2D = controller.call("_city_background_texture")
		if bg != null:
			draw_texture_rect(bg, rect, false, Color(1.0, 1.0, 1.0, 0.18))
		for i in range(10):
			var x := rect.size.x * (0.05 + float(i) * 0.10)
			draw_line(Vector2(x, 10), Vector2(x - 44.0, rect.size.y - 10), Color(0.14, 0.32, 0.34, 0.18), 1.0)
		for i in range(7):
			var y := rect.size.y * (0.10 + float(i) * 0.13)
			draw_line(Vector2(12, y), Vector2(rect.size.x - 12, y + 16.0), Color(0.14, 0.30, 0.30, 0.14), 1.0)
		_draw_links()
		var ids := _ordered_location_ids()
		for location_id in ids:
			_draw_location(str(location_id))

	func _draw_links() -> void:
		var base := _location_position("base")
		if base == Vector2.ZERO:
			return
		for location_id in _ordered_location_ids():
			if str(location_id) == "base":
				continue
			var target := _location_position(str(location_id))
			var location: Dictionary = (controller.get("locations") as Dictionary).get(str(location_id), {})
			var risk := int(location.get("risk", 0))
			var color := Color(0.28, 0.50, 0.54, 0.34)
			if risk >= 50:
				color = Color(1.0, 0.48, 0.30, 0.32)
			elif risk >= 40:
				color = Color(1.0, 0.74, 0.30, 0.30)
			draw_line(base, target, color, 2.0)

	func _draw_location(location_id: String) -> void:
		var data: Dictionary = (controller.get("locations") as Dictionary).get(location_id, {})
		if data.is_empty():
			return
		var pos := _location_position(location_id)
		var selected := location_id == str(controller.get("selected_location_id"))
		var status := str(data.get("status", "unknown"))
		var risk := int(data.get("risk", 0))
		var trend := int(data.get("danger_trend", 0))
		var people := int(data.get("people_left", 0))
		var supplies := int(data.get("supplies_left", 0))
		var color := _status_color(status, risk)
		var radius := 18.0 if location_id == "base" else 15.0
		if selected:
			var pulse_radius := radius + 12.0 + sin(pulse * TAU) * 3.0
			draw_circle(pos, pulse_radius, Color(color.r, color.g, color.b, 0.16))
			draw_circle(pos, radius + 7.0, Color(color.r, color.g, color.b, 0.22))
		if trend > 0:
			draw_arc(pos, radius + 9.0, 0.0, TAU * min(1.0, float(trend) / 4.0), 28, Color(1.0, 0.42, 0.28, 0.82), 3.0)
		draw_circle(pos, radius, Color(color.r, color.g, color.b, 0.28))
		draw_circle(pos, radius * 0.55, color)
		if people > 0:
			draw_circle(pos + Vector2(radius + 8.0, -radius + 3.0), 8.0, Color(0.52, 0.95, 1.0, 0.92))
			draw_string(get_theme_default_font(), pos + Vector2(radius + 4.0, -radius + 8.0), str(people), HORIZONTAL_ALIGNMENT_CENTER, 8, 10, Color(0.0, 0.05, 0.05))
		if supplies > 0:
			draw_rect(Rect2(pos + Vector2(radius + 2.0, radius - 4.0), Vector2(13, 10)), Color(1.0, 0.82, 0.34, 0.92), true)
			draw_string(get_theme_default_font(), pos + Vector2(radius + 4.0, radius + 5.0), str(supplies), HORIZONTAL_ALIGNMENT_CENTER, 8, 9, Color(0.08, 0.04, 0.0))
		_draw_signal_pins(location_id, pos, radius)
		var label_pos := pos + Vector2(-42.0, radius + 14.0)
		draw_string(get_theme_default_font(), label_pos, str(data.get("name", location_id)), HORIZONTAL_ALIGNMENT_CENTER, 84, 13, Color(0.90, 0.96, 0.91))
		draw_string(get_theme_default_font(), label_pos + Vector2(0, 16), "险%d 势%d" % [risk, trend], HORIZONTAL_ALIGNMENT_CENTER, 84, 11, Color(0.70, 0.84, 0.80))

	func _draw_signal_pins(location_id: String, pos: Vector2, radius: float) -> void:
		var signals_for_node: Array = controller.call("_signals_for_location", location_id)
		if signals_for_node.is_empty():
			return
		for index in range(min(3, signals_for_node.size())):
			var signal_data: Dictionary = signals_for_node[index]
			var pin_pos := pos + Vector2(-radius - 16.0 + float(index) * 13.0, -radius - 13.0)
			var color: Color = controller.call("_signal_pin_color", signal_data)
			var locked := (controller.get("locked_signal_ids") as Array).has(str(signal_data.get("id", "")))
			draw_circle(pin_pos, 6.0 if locked else 5.0, Color(color.r, color.g, color.b, 0.90))
			if locked:
				draw_arc(pin_pos, 10.0, 0.0, TAU, 20, Color(color.r, color.g, color.b, 0.72), 2.0)
		if signals_for_node.size() > 3:
			draw_string(get_theme_default_font(), pos + Vector2(-radius - 5.0, -radius - 26.0), "+%d" % (signals_for_node.size() - 3), HORIZONTAL_ALIGNMENT_LEFT, 24, 10, Color(0.82, 0.94, 0.90))

	func _node_at(position: Vector2) -> String:
		var best := ""
		var best_distance := 9999.0
		for location_id in _ordered_location_ids():
			var dist := position.distance_to(_location_position(str(location_id)))
			if dist < best_distance:
				best_distance = dist
				best = str(location_id)
		return best if best_distance <= 32.0 else ""

	func _location_position(location_id: String) -> Vector2:
		var data: Dictionary = (controller.get("locations") as Dictionary).get(location_id, {})
		var pos: Array = data.get("pos", [0.5, 0.5])
		return Vector2(float(pos[0]) * size.x, float(pos[1]) * size.y)

	func _ordered_location_ids() -> Array:
		var ids: Array = (controller.get("locations") as Dictionary).keys()
		ids.sort()
		if ids.has("base"):
			ids.erase("base")
			ids.push_front("base")
		return ids

	func _status_color(status: String, risk: int) -> Color:
		if status == "danger" or risk >= 55:
			return Color(1.0, 0.38, 0.28, 1.0)
		match status:
			"confirmed":
				return Color(0.48, 0.94, 0.68, 1.0)
			"explorable":
				return Color(1.0, 0.82, 0.36, 1.0)
			"looted":
				return Color(0.55, 0.70, 0.72, 1.0)
			"lost":
				return Color(0.55, 0.42, 0.42, 1.0)
			_:
				return Color(0.36, 0.76, 0.82, 1.0)

func setup(new_locations: Dictionary, new_selected_location_id: String, new_day_signals: Array = [], new_locked_signal_ids: Array = [], new_signal_marks: Dictionary = {}, new_resources: Dictionary = {}, new_city_action_defs: Dictionary = {}) -> void:
	locations = new_locations
	selected_location_id = new_selected_location_id
	day_signals = new_day_signals
	locked_signal_ids = new_locked_signal_ids
	signal_marks = new_signal_marks
	resources = new_resources
	city_action_defs = new_city_action_defs
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	add_theme_stylebox_override("panel", _panel_style(Color(0.032, 0.038, 0.035, 0.96), Color(0.48, 0.62, 0.48, 0.82)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var title := Label.new()
	title.text = "城市态势图"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	city_board = CityBoard.new()
	city_board.controller = self
	city_board.custom_minimum_size = Vector2(390, 0)
	city_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	city_board.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(city_board)

	detail_box = VBoxContainer.new()
	detail_box.custom_minimum_size = Vector2(205, 0)
	detail_box.add_theme_constant_override("separation", 8)
	body.add_child(detail_box)
	_refresh_detail_box()

	var hint := Label.new()
	hint.text = "点击节点切换今日目标；节点旁小点表示今日信号，亮环为已锁定，颜色来自可信/可疑/诱饵判断。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.78, 0.88, 0.84))
	root.add_child(hint)

func _select_location_on_board(location_id: String) -> void:
	if not locations.has(location_id):
		return
	selected_location_id = location_id
	_refresh_detail_box()
	if city_board != null:
		city_board.queue_redraw()
	location_selected.emit(location_id)

func _refresh_detail_box() -> void:
	if detail_box == null:
		return
	for child in detail_box.get_children():
		child.queue_free()
	var location: Dictionary = locations.get(selected_location_id, {})
	if location.is_empty():
		_add_detail_label("未选择节点", 20, Color(1.0, 0.84, 0.45))
		return
	_add_detail_label(str(location.get("name", selected_location_id)), 20, Color(1.0, 0.84, 0.45))
	_add_detail_label("%s / %s" % [_status_label(str(location.get("status", "unknown"))), _type_label(str(location.get("type", "")))], 14, Color(0.72, 0.94, 1.0))
	_add_detail_label("风险 %d  趋势 %d" % [int(location.get("risk", 0)), int(location.get("danger_trend", 0))], 15, _risk_color(int(location.get("risk", 0)), int(location.get("danger_trend", 0))))
	_add_detail_label("等待救援 %d  剩余物资 %d" % [int(location.get("people_left", 0)), int(location.get("supplies_left", 0))], 15, Color(0.86, 0.94, 0.90))
	_add_detail_label("势力：%s" % str(location.get("faction", "unknown")), 14, Color(0.72, 0.86, 0.82))
	var signal_summary := _location_signal_summary(selected_location_id)
	if signal_summary != "":
		_add_detail_label(signal_summary, 13, Color(0.96, 0.86, 0.62))
	_add_detail_label("标记：%s" % _flags_text(location.get("flags", [])), 13, Color(0.70, 0.80, 0.76))
	if str(selected_location_id) != "base" and not city_action_defs.is_empty():
		_add_detail_label("节点处置", 15, Color(1.0, 0.84, 0.45))
		var grid := GridContainer.new()
		grid.columns = 1
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("v_separation", 5)
		detail_box.add_child(grid)
		for action_id in ["warn", "route_mark", "cache"]:
			if city_action_defs.has(action_id):
				_add_city_action_button(grid, str(action_id), location)

func _add_detail_label(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	detail_box.add_child(label)

func _add_city_action_button(root: Control, action_id: String, location: Dictionary) -> void:
	var action: Dictionary = city_action_defs.get(action_id, {})
	var button := Button.new()
	button.text = "%s  %s" % [str(action.get("name", action_id)), _city_action_effect_text(action_id)]
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(180, 36)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 11)
	button.disabled = not _can_use_city_action(action_id, location)
	button.pressed.connect(func() -> void:
		city_action_requested.emit(selected_location_id, action_id)
	)
	root.add_child(button)

func _can_use_city_action(action_id: String, location: Dictionary) -> bool:
	if not city_action_defs.has(action_id):
		return false
	var action: Dictionary = city_action_defs[action_id]
	var flags: Array = location.get("flags", [])
	if flags.has(str(action.get("flag", action_id))):
		return false
	var cost: Dictionary = action.get("cost", {})
	for key in cost.keys():
		if int(resources.get(str(key), 0)) < int(cost[key]):
			return false
	return true

func _city_action_effect_text(action_id: String) -> String:
	var action: Dictionary = city_action_defs.get(action_id, {})
	var parts: Array[String] = []
	var cost: Dictionary = action.get("cost", {})
	for key in cost.keys():
		parts.append("%s-%d" % [_resource_short_name(str(key)), int(cost[key])])
	if int(action.get("risk", 0)) != 0:
		parts.append("险%+d" % int(action.get("risk", 0)))
	if int(action.get("danger_trend", 0)) != 0:
		parts.append("势%+d" % int(action.get("danger_trend", 0)))
	if int(action.get("supplies_left", 0)) != 0:
		parts.append("物%+d" % int(action.get("supplies_left", 0)))
	if int(action.get("trust", 0)) != 0:
		parts.append("信%+d" % int(action.get("trust", 0)))
	if parts.is_empty():
		return "无消耗"
	return " ".join(parts)

func _resource_short_name(key: String) -> String:
	return {
		"power": "电",
		"food": "食",
		"medicine": "药",
		"fuel": "油",
		"parts": "件",
		"trust": "信",
		"influence": "影",
		"threat": "暴"
	}.get(key, key)

func _status_label(status: String) -> String:
	match status:
		"confirmed":
			return "已确认"
		"unknown":
			return "未确认"
		"explorable":
			return "可探索"
		"danger":
			return "危险"
		"looted":
			return "已搜刮"
		"lost":
			return "失联"
		_:
			return status

func _type_label(location_type: String) -> String:
	return {
		"base": "基地",
		"rescue": "救援点",
		"medical": "医疗点",
		"supply": "补给点"
	}.get(location_type, location_type)

func _risk_color(risk: int, trend: int) -> Color:
	if risk >= 55 or trend >= 3:
		return Color(1.0, 0.42, 0.32)
	if risk >= 40 or trend > 0:
		return Color(1.0, 0.78, 0.34)
	return Color(0.50, 0.95, 0.66)

func _flags_text(flags_value: Variant) -> String:
	var flags: Array = flags_value as Array
	if flags.is_empty():
		return "无"
	return "、".join(flags)

func _signals_for_location(location_id: String) -> Array:
	var matched: Array = []
	for signal_data in day_signals:
		if str((signal_data as Dictionary).get("location", "")) == location_id:
			matched.append(signal_data)
	return matched

func _location_signal_summary(location_id: String) -> String:
	var signals_for_node := _signals_for_location(location_id)
	if signals_for_node.is_empty():
		return "今日信号：无"
	var parts: Array[String] = []
	for signal_data in signals_for_node:
		var data := signal_data as Dictionary
		var id := str(data.get("id", ""))
		var locked := locked_signal_ids.has(id)
		var mark := str(signal_marks.get(id, data.get("player_mark", "")))
		parts.append("%s%s %s 急%d 噪%d" % [
			"已锁 " if locked else "",
			_mark_label(mark),
			str(data.get("title", "信号")),
			int(data.get("urgency", 1)),
			int(data.get("noise", 0))
		])
	return "今日信号：%s" % "；".join(parts)

func _signal_pin_color(signal_data: Dictionary) -> Color:
	var id := str(signal_data.get("id", ""))
	var mark := str(signal_marks.get(id, signal_data.get("player_mark", "")))
	match mark:
		"trusted":
			return Color(0.50, 1.0, 0.72, 1.0)
		"suspect":
			return Color(1.0, 0.80, 0.32, 1.0)
		"decoy":
			return Color(1.0, 0.36, 0.28, 1.0)
		_:
			var urgency := int(signal_data.get("urgency", 1))
			if urgency >= 4:
				return Color(1.0, 0.68, 0.30, 1.0)
			return Color(0.42, 0.82, 0.90, 1.0)

func _city_background_texture() -> Texture2D:
	return _load_texture("res://assets/new/named/city_map_table.png")

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if texture_cache.has(path):
		return texture_cache[path] as Texture2D
	if ResourceLoader.exists(path, "Texture2D"):
		var resource_texture := load(path) as Texture2D
		texture_cache[path] = resource_texture
		return resource_texture
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return null
	var image_texture := ImageTexture.create_from_image(image)
	texture_cache[path] = image_texture
	return image_texture

func _mark_label(mark_id: String) -> String:
	match mark_id:
		"trusted":
			return "可信"
		"suspect":
			return "可疑"
		"decoy":
			return "诱饵"
		_:
			return "未判"

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
