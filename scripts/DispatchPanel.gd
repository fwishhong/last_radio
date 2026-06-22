extends PanelContainer

signal dispatch_launched(member_ids: Array[String], item_ids: Array[String], broadcast_mode: String, route_id: String, prep_id: String, order_id: String, objective_id: String)
signal field_choice_selected(choice_id: String)

const ROUTE_ORDER := ["safe", "fast", "unknown"]
const BROADCAST_ORDER := ["route_warning", "relay_help", "silent"]

var members: Dictionary = {}
var items: Dictionary = {}
var selected_location: Dictionary = {}
var selected_member_ids: Array[String] = []
var selected_item_ids: Array[String] = []
var broadcast_mode := "route_warning"
var route_id := "safe"
var prep_id := "none"
var order_id := "steady"
var objective_id := "balanced"
var phase := "planning"
var consulted_member_id := ""
var details_expanded := false
var story_route_confirmed := false
var can_dispatch := false
var dispatched_today := false
var last_result: Dictionary = {}
var preview_provider: Callable
var launch_button: Button
var route_map: RouteMap
var target_signal_image: TextureRect
var transmit_timer: Timer
var transmit_elapsed := 0.0
var texture_cache: Dictionary = {}

class RouteMap:
	extends Control

	var controller: PanelContainer
	var progress := 0.0
	var pulse := 0.0

	func _gui_input(event: InputEvent) -> void:
		if controller == null:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var clicked := _route_at(event.position)
			if clicked != "":
				controller.call("_set_route", clicked)

	func _process(delta: float) -> void:
		if controller == null:
			return
		pulse = fposmod(pulse + delta * 2.8, TAU)
		if str(controller.get("phase")) == "transmitting":
			progress = fposmod(progress + delta * 0.36, 1.0)
		queue_redraw()

	func _draw() -> void:
		if controller == null:
			return
		var rect := get_rect()
		var base := Vector2(rect.size.x * 0.18, rect.size.y * 0.72)
		var target := Vector2(rect.size.x * 0.78, rect.size.y * 0.28)
		_draw_map_backdrop(rect)
		_draw_route("safe", base, target, Vector2(0, -54), Color(0.38, 0.86, 0.62))
		_draw_route("fast", base, target, Vector2(0, 8), Color(1.0, 0.62, 0.34))
		_draw_route("unknown", base, target, Vector2(0, 62), Color(0.56, 0.74, 1.0))
		_draw_node(base, "基地", Color(0.62, 0.88, 1.0), false)
		_draw_node(target, str(controller.get("selected_location").get("name", "目标")), Color(1.0, 0.80, 0.42), true)

	func _draw_map_backdrop(rect: Rect2) -> void:
		draw_rect(rect, Color(0.022, 0.030, 0.028, 0.96), true)
		for index in range(7):
			var x := rect.size.x * (0.12 + float(index) * 0.12)
			draw_line(Vector2(x, rect.size.y * 0.12), Vector2(x - 72.0, rect.size.y * 0.92), Color(0.18, 0.25, 0.22, 0.22), 2.0)
		for index in range(5):
			var y := rect.size.y * (0.18 + float(index) * 0.16)
			draw_line(Vector2(rect.size.x * 0.08, y), Vector2(rect.size.x * 0.92, y + 22.0), Color(0.18, 0.25, 0.22, 0.18), 2.0)
		draw_string(get_theme_default_font(), Vector2(rect.size.x * 0.06, rect.size.y * 0.14), "旧城行动区", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.62, 0.72, 0.68, 0.68))

	func _draw_route(id: String, base: Vector2, target: Vector2, bend: Vector2, color: Color) -> void:
		var selected := str(controller.get("route_id")) == id
		var phase_name := str(controller.get("phase"))
		var mid := (base + target) * 0.5 + bend
		var points := PackedVector2Array([base, mid, target])
		var dim := Color(color.r, color.g, color.b, 0.28)
		var active := Color(color.r, color.g, color.b, 0.96)
		if selected:
			var glow := 10.0 + sin(pulse) * 2.5
			draw_polyline(points, Color(color.r, color.g, color.b, 0.22), glow, true)
		draw_polyline(points, active if selected else dim, 7.0 if selected else 4.0, true)
		draw_circle(mid, 9.0 if selected else 6.0, active if selected else dim)
		_draw_route_label(id, mid + Vector2(14, -12), active if selected else Color(0.62, 0.72, 0.70, 0.78))
		if selected and phase_name == "transmitting":
			var p := _sample_route(base, mid, target, progress)
			draw_circle(p, 7.0, Color(1.0, 0.96, 0.58, 1.0))
			draw_circle(p, 15.0, Color(1.0, 0.82, 0.22, 0.22))

	func _draw_route_label(id: String, position: Vector2, color: Color) -> void:
		var text := ""
		if bool(controller.call("_uses_story_dispatch")):
			match id:
				"safe":
					text = "侧巷绕行  更稳但会晚"
				"fast":
					text = "穿正街  更快也更显眼"
				"unknown":
					text = "地下通道  省路但没人熟"
		else:
			match id:
				"safe":
					text = "安全  准+10  获x0.75"
				"fast":
					text = "近路  准-10  暴+1"
				"unknown":
					text = "小路  油-1  暴-1"
		draw_string(get_theme_default_font(), position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

	func _draw_node(position: Vector2, label: String, color: Color, target_node: bool) -> void:
		draw_circle(position, 19.0 if target_node else 16.0, Color(color.r, color.g, color.b, 0.26))
		draw_circle(position, 10.0 if target_node else 8.0, color)
		draw_string(get_theme_default_font(), position + Vector2(-28, -24), label, HORIZONTAL_ALIGNMENT_LEFT, 96, 13, Color(0.90, 0.96, 0.90))

	func _route_at(position: Vector2) -> String:
		var rect := get_rect()
		var base := Vector2(rect.size.x * 0.18, rect.size.y * 0.72)
		var target := Vector2(rect.size.x * 0.78, rect.size.y * 0.28)
		var best := ""
		var best_distance := 9999.0
		for data in [
			["safe", Vector2(0, -54)],
			["fast", Vector2(0, 8)],
			["unknown", Vector2(0, 62)]
		]:
			var mid: Vector2 = (base + target) * 0.5 + (data[1] as Vector2)
			var dist := _distance_to_polyline(position, [base, mid, target])
			if dist < best_distance:
				best_distance = dist
				best = str(data[0])
		return best if best_distance <= 34.0 else ""

	func _distance_to_polyline(position: Vector2, points: Array) -> float:
		var best := 9999.0
		for index in range(points.size() - 1):
			best = min(best, _distance_to_segment(position, points[index], points[index + 1]))
		return best

	func _distance_to_segment(position: Vector2, a: Vector2, b: Vector2) -> float:
		var ab := b - a
		var t: float = clamp((position - a).dot(ab) / max(1.0, ab.length_squared()), 0.0, 1.0)
		return position.distance_to(a + ab * t)

	func _sample_route(base: Vector2, mid: Vector2, target: Vector2, t: float) -> Vector2:
		if t < 0.5:
			return base.lerp(mid, t * 2.0)
		return mid.lerp(target, (t - 0.5) * 2.0)

func setup(new_members: Dictionary, new_items: Dictionary, new_selected_location: Dictionary, new_dispatched_today: bool, new_preview_provider: Callable = Callable(), new_last_result: Dictionary = {}) -> void:
	members = new_members
	items = new_items
	selected_location = new_selected_location
	selected_member_ids.clear()
	selected_item_ids.clear()
	broadcast_mode = "route_warning"
	route_id = "safe"
	prep_id = "none"
	order_id = "steady"
	objective_id = "balanced"
	consulted_member_id = ""
	story_route_confirmed = false
	launch_button = null
	dispatched_today = new_dispatched_today
	can_dispatch = not dispatched_today and not selected_location.is_empty()
	preview_provider = new_preview_provider
	last_result = new_last_result
	if dispatched_today and not last_result.is_empty():
		var ui_phase := str(last_result.get("ui_phase", ""))
		if ui_phase == "awaiting_choice":
			phase = "awaiting_choice"
		elif ui_phase == "transmitting":
			phase = "transmitting"
		else:
			phase = "resolved"
	else:
		phase = "planning"
	transmit_elapsed = 0.0
	_rebuild()
	if phase == "transmitting":
		_start_transmit_timer()

func _rebuild() -> void:
	for child in get_children():
		if child == transmit_timer:
			continue
		remove_child(child)
		child.queue_free()
	add_theme_stylebox_override("panel", _panel_style(Color(0.030, 0.034, 0.032, 0.97), Color(0.76, 0.58, 0.36, 0.84)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var title := Label.new()
	title.text = _title_text()
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(title)

	if phase == "resolved":
		_build_resolved_state(root)
		return

	var board := HBoxContainer.new()
	board.add_theme_constant_override("separation", 12)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(board)

	var map_column := VBoxContainer.new()
	map_column.custom_minimum_size = Vector2(360, 0)
	map_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_column.add_theme_constant_override("separation", 8)
	board.add_child(map_column)

	var action_column := VBoxContainer.new()
	action_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_column.add_theme_constant_override("separation", 5)
	board.add_child(action_column)

	_build_route_map(map_column)
	if phase == "transmitting":
		_build_transmitting_state(action_column)
	elif phase == "awaiting_choice":
		_build_awaiting_choice_state(action_column)
	else:
		_build_planning_state(action_column)

func _title_text() -> String:
	if phase == "transmitting":
		return "外勤回传：%s" % str(selected_location.get("name", "未知节点"))
	if phase == "awaiting_choice":
		return "等待你的回传指令"
	if phase == "resolved":
		return "今日外勤结果"
	return "城市行动板：%s" % str(selected_location.get("name", "未选择节点"))

func _build_route_map(root: VBoxContainer) -> void:
	var target := Label.new()
	target.text = _target_summary_text()
	target.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target.add_theme_font_size_override("font_size", 14)
	target.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	root.add_child(target)

	_add_target_image(root)

	route_map = RouteMap.new()
	route_map.controller = self
	route_map.custom_minimum_size = Vector2(0, 206)
	route_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	route_map.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(route_map)

	if not _uses_story_dispatch():
		var routes := HBoxContainer.new()
		routes.add_theme_constant_override("separation", 6)
		root.add_child(routes)
		_add_route_chip(routes, "safe", "安全")
		_add_route_chip(routes, "fast", "近路")
		_add_route_chip(routes, "unknown", "小路")

func _add_target_image(root: VBoxContainer) -> void:
	var frame := Control.new()
	frame.clip_contents = true
	frame.custom_minimum_size = Vector2(0, 88)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	target_signal_image = TextureRect.new()
	target_signal_image.name = "TargetSignalImage"
	target_signal_image.texture = _load_texture(str(selected_location.get("signal_image", "")))
	target_signal_image.custom_minimum_size = Vector2(0, 88)
	target_signal_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_signal_image.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	target_signal_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target_signal_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if target_signal_image.texture != null:
		frame.add_child(target_signal_image)
		target_signal_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(frame)

func _target_summary_text() -> String:
	var name := str(selected_location.get("name", "未选择节点"))
	var base := "%s\n需要 %s\n风险 %d  等待 %d  物资 %d" % [
		name,
		_tag_list_text(_mission_tags()),
		int(selected_location.get("risk", 0)),
		int(selected_location.get("people_left", 0)),
		int(selected_location.get("supplies_left", 0))
	]
	match _progress_day():
		1:
			if _uses_story_dispatch():
				return "%s\n%s" % [name, str(selected_location.get("story_intro", ""))]
			return base
		2:
			return "%s\n%s\n%s" % [base, _intel_text(), _directive_preview_text()]
		_:
			return "%s  趋势 %d\n%s\n%s\n%s" % [
				base,
				int(selected_location.get("danger_trend", 0)),
				_intel_text(),
				_memory_text(),
				_directive_preview_text()
			]

func _build_planning_state(root: VBoxContainer) -> void:
	if _uses_story_dispatch():
		_build_story_planning_state(root)
		return
	_build_slots(root)

	launch_button = Button.new()
	launch_button.custom_minimum_size = Vector2(0, 36)
	launch_button.pressed.connect(func() -> void:
		if selected_member_ids.is_empty():
			return
		phase = "transmitting"
		_rebuild()
		dispatch_launched.emit(selected_member_ids.duplicate(), selected_item_ids.duplicate(), broadcast_mode, route_id, prep_id, order_id, objective_id)
		if not is_queued_for_deletion() and phase == "transmitting" and transmit_timer == null:
			_start_transmit_timer()
	)
	root.add_child(launch_button)
	_update_launch_state()

	var scroller := ScrollContainer.new()
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.custom_minimum_size = Vector2(0, 160)
	root.add_child(scroller)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	scroller.add_child(content)

	_build_unlock_hint(content)
	if _uses_story_dispatch():
		_build_advisor_panel(content)
	_build_member_pool(content)
	_build_item_pool(content)
	if _objective_unlocked():
		_build_objective_controls(content)
	if _prep_unlocked():
		_build_prep_controls(content)
	if _order_unlocked():
		_build_order_controls(content)
	if _broadcast_unlocked():
		_build_broadcast_controls(content)
	if _forecast_unlocked():
		_build_stakes(content)
		_build_forecast(content)
	else:
		_build_simple_forecast(content)
	if _uses_story_dispatch():
		_build_detail_ledger(content)

func _build_story_planning_state(root: VBoxContainer) -> void:
	_build_slots(root)
	var scroller := ScrollContainer.new()
	scroller.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.custom_minimum_size = Vector2(0, 190)
	root.add_child(scroller)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroller.add_child(content)

	if consulted_member_id == "":
		_build_story_advisor_step(content)
	elif selected_member_ids.size() < 2:
		_build_story_team_step(content)
	elif not story_route_confirmed:
		_build_story_route_step(content)
	else:
		_build_story_launch_step(content)

func _build_story_step_header(root: VBoxContainer, title_text: String, body_text: String) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(title)
	var body := Label.new()
	body.text = body_text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	root.add_child(body)

func _build_story_advisor_step(root: VBoxContainer) -> void:
	_build_story_step_header(root, "先问一个人", "北桥信号已经确认。先听一名队员的判断，再决定谁出门。")
	var lines: Dictionary = selected_location.get("advisor_lines", {})
	for member_id in _story_advisor_ids():
		if not members.has(member_id):
			continue
		var button := Button.new()
		button.text = "问 %s" % str((members[member_id] as Dictionary).get("name", member_id))
		button.custom_minimum_size = Vector2(0, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = str(lines.get(member_id, ""))
		_make_compact_button(button)
		button.pressed.connect(func() -> void:
			_consult_advisor(member_id)
		)
		root.add_child(button)

func _build_story_team_step(root: VBoxContainer) -> void:
	var lines: Dictionary = selected_location.get("advisor_lines", {})
	_build_story_step_header(root, "派谁出去", str(lines.get(consulted_member_id, "这条线索可以行动。")))
	var teams := [
		{"label": "Nora + Mara", "members": ["a_qing", "xu_lan"]},
		{"label": "Nora + Elias", "members": ["a_qing", "shen_luo"]},
		{"label": "Mara + Victor", "members": ["xu_lan", "lao_zhou"]}
	]
	for team in teams:
		var button := Button.new()
		button.text = str(team.get("label", "选择外勤"))
		button.custom_minimum_size = Vector2(0, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_make_compact_button(button)
		button.pressed.connect(func() -> void:
			_choose_story_team(team.get("members", []))
		)
		root.add_child(button)

func _build_story_route_step(root: VBoxContainer) -> void:
	_build_story_step_header(root, "走哪条路", "外勤队在门口等你的路线。这里先不看概率，只看后果。")
	var routes := [
		{"id": "safe", "label": "侧巷绕行", "hint": "更稳，但会晚一点"},
		{"id": "fast", "label": "穿正街", "hint": "更快，也更容易被看见"},
		{"id": "unknown", "label": "地下通道", "hint": "省路，但没人熟"}
	]
	for route in routes:
		var button := Button.new()
		button.text = "%s\n%s" % [str(route.get("label", "")), str(route.get("hint", ""))]
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_make_compact_button(button)
		button.pressed.connect(func() -> void:
			_confirm_story_route(str(route.get("id", "safe")))
		)
		root.add_child(button)

func _build_story_launch_step(root: VBoxContainer) -> void:
	_build_story_step_header(root, "确认派出", "%s 走 %s。装备由电台值班台按救援默认带上。" % [_story_team_names(), _story_route_result_label(route_id)])
	launch_button = Button.new()
	launch_button.text = "派出外勤队"
	launch_button.custom_minimum_size = Vector2(0, 46)
	launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch_button.disabled = not can_dispatch or selected_member_ids.is_empty()
	_make_compact_button(launch_button)
	launch_button.pressed.connect(func() -> void:
		if selected_member_ids.is_empty():
			return
		phase = "transmitting"
		_rebuild()
		dispatch_launched.emit(selected_member_ids.duplicate(), selected_item_ids.duplicate(), broadcast_mode, route_id, prep_id, order_id, objective_id)
		if not is_queued_for_deletion() and phase == "transmitting" and transmit_timer == null:
			_start_transmit_timer()
	)
	root.add_child(launch_button)

	var route_back := Button.new()
	route_back.text = "重选路线"
	route_back.custom_minimum_size = Vector2(0, 38)
	route_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_compact_button(route_back)
	route_back.pressed.connect(func() -> void:
		story_route_confirmed = false
		_rebuild()
	)
	root.add_child(route_back)

	var team_back := Button.new()
	team_back.text = "重选外勤"
	team_back.custom_minimum_size = Vector2(0, 38)
	team_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_make_compact_button(team_back)
	team_back.pressed.connect(func() -> void:
		selected_member_ids.clear()
		selected_item_ids.clear()
		story_route_confirmed = false
		_rebuild()
	)
	root.add_child(team_back)

func _build_transmitting_state(root: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "频道接通中..."
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(label)

	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 4)
	root.add_child(bars)
	for index in range(12):
		var bar := ColorRect.new()
		var height := 18 + int(abs(sin(transmit_elapsed * 4.0 + float(index))) * 42.0)
		bar.custom_minimum_size = Vector2(10, height)
		bar.color = Color(0.32, 0.90, 1.0, 0.45 + float(index % 3) * 0.12)
		bars.add_child(bar)

	var feed := Label.new()
	feed.text = _transmit_feed_text()
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.add_theme_font_size_override("font_size", 15)
	feed.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	root.add_child(feed)

func _build_awaiting_choice_state(root: VBoxContainer) -> void:
	var feed := Label.new()
	var lines: Array = last_result.get("pending_feed_lines", [])
	if lines.is_empty():
		lines = _field_choice_feed_lines()
	feed.text = "\n".join(lines)
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.add_theme_font_size_override("font_size", 15)
	feed.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	root.add_child(feed)

	var prompt := Label.new()
	prompt.text = str(_field_choice_data().get("prompt", "外勤队等待你的指令。"))
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt.add_theme_font_size_override("font_size", 17)
	prompt.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(prompt)

	var options: Array = _field_choice_data().get("options", [])
	for option in options:
		var data := option as Dictionary
		var button := Button.new()
		button.text = "%s\n%s" % [str(data.get("label", data.get("id", ""))), str(data.get("description", ""))]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 52)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			field_choice_selected.emit(str(data.get("id", "")))
		)
		root.add_child(button)

func _build_resolved_state(root: VBoxContainer) -> void:
	var stamp := Label.new()
	stamp.text = _quality_stamp(str(last_result.get("quality", "")))
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_theme_font_size_override("font_size", 32)
	stamp.add_theme_color_override("font_color", _quality_color(str(last_result.get("quality", ""))))
	root.add_child(stamp)

	var feed_title := Label.new()
	feed_title.text = "无线电回传"
	feed_title.add_theme_font_size_override("font_size", 17)
	feed_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(feed_title)

	var feed := Label.new()
	feed.text = _feed_text()
	feed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feed.add_theme_font_size_override("font_size", 14)
	feed.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	root.add_child(feed)

	var summary := Label.new()
	summary.text = str(last_result.get("summary", "外勤小队已经离开，今天不能再派出第二队。"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size", 15)
	summary.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	root.add_child(summary)

	var details := Label.new()
	if _uses_story_dispatch() or str(last_result.get("choice_id", "")) != "":
		details.text = "路线：%s  ·  现场判断：%s  ·  队伍回传已记录" % [
			_story_route_result_label(str(last_result.get("route_id", "safe"))),
			str(last_result.get("choice_label", "按回传稳住行动"))
		]
	else:
		details.text = "路线：%s  ·  目标：%s  ·  准则：%s  ·  准备 %d / 结算 %d" % [
			_route_label(str(last_result.get("route_id", "safe"))),
			str(_active_objective_def(str(last_result.get("objective_id", "balanced"))).get("name", "执行信号")),
			_order_label(str(last_result.get("order_id", "steady"))),
			int(last_result.get("base_score", 0)),
			int(last_result.get("final_score", 0))
		]
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 13)
	details.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	root.add_child(details)

	var next := Label.new()
	next.text = "下一步：点击右上方「查看夜间结算」。"
	next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	next.add_theme_font_size_override("font_size", 17)
	next.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(next)

func _build_slots(root: VBoxContainer) -> void:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	root.add_child(rows)
	var member_row := HBoxContainer.new()
	member_row.add_theme_constant_override("separation", 8)
	rows.add_child(member_row)
	for index in range(2):
		member_row.add_child(_slot_card("成员", _member_slot_text(index), _member_slot_avatar(index), index < selected_member_ids.size()))
	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 8)
	rows.add_child(item_row)
	for index in range(2):
		item_row.add_child(_slot_card("装备", _item_slot_text(index), _item_slot_avatar(index), index < selected_item_ids.size()))

func _slot_card(label: String, value: String, avatar: Control, filled: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 44)
	var border := Color(1.0, 0.78, 0.32, 0.86) if filled else Color(0.32, 0.52, 0.54, 0.55)
	panel.add_theme_stylebox_override("panel", _button_style(Color(0.040, 0.050, 0.047, 0.94), border))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)
	if avatar == null:
		avatar = _empty_slot_avatar()
	row.add_child(avatar)
	var text := Label.new()
	text.text = "%s\n%s" % [label, value]
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 12)
	text.add_theme_color_override("font_color", Color(0.84, 0.94, 0.90))
	row.add_child(text)
	return panel


# Returns the avatar Control for a dispatch slot: a colored glyph badge
# for member slots, an item TextureRect for equipment slots, or an
# empty 30x30 placeholder if the slot is unfilled. Keeps the slot
# layout identical to the old TextureRect-based version.
func _empty_slot_avatar() -> Control:
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(30, 30)
	rect.size = Vector2(30, 30)
	rect.color = Color(0.18, 0.22, 0.20, 0.65)
	return rect

func _build_member_pool(root: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "外勤成员"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	root.add_child(grid)
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		var fit := _member_fit_score(str(member_id))
		var button := _member_card(str(member_id), member, fit)
		button.pressed.connect(func() -> void:
			_toggle_member(str(member_id))
		)
		grid.add_child(button)

func _build_item_pool(root: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "装备"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	root.add_child(grid)
	for item_id in items.keys():
		var item: Dictionary = items[item_id]
		var fit := _item_fit_score(str(item_id))
		var button := _item_card(str(item_id), item, fit)
		button.pressed.connect(func() -> void:
			_toggle_item(str(item_id))
		)
		grid.add_child(button)

func _build_advisor_panel(root: VBoxContainer) -> void:
	var lines: Dictionary = selected_location.get("advisor_lines", {})
	if lines.is_empty():
		return
	var title := Label.new()
	title.text = "问一名队员"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 5)
	root.add_child(grid)
	for member_id in ["shen_luo", "a_qing", "xu_lan", "lao_zhou"]:
		if not members.has(member_id) or not lines.has(member_id):
			continue
		var member: Dictionary = members[member_id]
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = consulted_member_id == member_id
		button.text = str(member.get("name", member_id))
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.custom_minimum_size = Vector2(0, 34)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_make_compact_button(button)
		button.pressed.connect(func() -> void:
			_consult_advisor(member_id)
		)
		grid.add_child(button)

	var advice := Label.new()
	if consulted_member_id == "":
		advice.text = "只能先问一名队员。不同的人会提醒你不同的风险。"
	else:
		advice.text = str(lines.get(consulted_member_id, ""))
	advice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	advice.add_theme_font_size_override("font_size", 12)
	advice.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	root.add_child(advice)

func _consult_advisor(member_id: String) -> void:
	consulted_member_id = member_id
	_rebuild()

func _story_advisor_ids() -> Array[String]:
	return ["a_qing", "xu_lan", "shen_luo"]

func _choose_story_team(member_ids: Array) -> void:
	selected_member_ids.clear()
	for member_id in member_ids:
		var id := str(member_id)
		if members.has(id) and selected_member_ids.size() < 2:
			selected_member_ids.append(id)
	_select_story_default_items()
	story_route_confirmed = false
	_rebuild()

func _select_story_default_items() -> void:
	selected_item_ids.clear()
	if selected_member_ids.has("xu_lan") and _story_item_available("medkit"):
		selected_item_ids.append("medkit")
	if _story_item_available("radio") and selected_item_ids.size() < 2:
		selected_item_ids.append("radio")
	if selected_item_ids.size() < 2 and _story_item_available("crowbar"):
		selected_item_ids.append("crowbar")

func _story_item_available(item_id: String) -> bool:
	return items.has(item_id) and int((items[item_id] as Dictionary).get("count", 0)) > 0

func _confirm_story_route(new_route_id: String) -> void:
	route_id = new_route_id
	story_route_confirmed = true
	if route_map != null:
		route_map.queue_redraw()
	_rebuild()

func _story_team_names() -> String:
	var names: Array[String] = []
	for member_id in selected_member_ids:
		names.append(str((members.get(member_id, {}) as Dictionary).get("name", member_id)))
	if names.is_empty():
		return "外勤队"
	return " 和 ".join(names)

func _member_card(member_id: String, member: Dictionary, fit: int) -> Button:
	var selected := selected_member_ids.has(member_id)
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = selected
	button.disabled = not can_dispatch or not _member_available(member)
	button.custom_minimum_size = Vector2(0, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	button.tooltip_text = _member_status_help(str(member.get("status", "normal")))
	_style_card_button(button, selected, button.disabled)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var glyph := _resolve_member_glyph(member)
	var avatar := _build_glyph_badge(glyph["letter"], glyph["color"], 42)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(avatar)

	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)

	var name := Label.new()
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name.text = str(member.get("name", member_id))
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 13)
	name.add_theme_color_override("font_color", _fit_color(fit))
	info.add_child(name)

	var meta := Label.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _uses_story_dispatch():
		meta.text = "%s  %s" % [_status_label(str(member.get("status", "normal"))), _member_story_hint(member_id)]
	else:
		meta.text = "%s  压%d  %s" % [_status_label(str(member.get("status", "normal"))), int(member.get("stress", 0)), _fit_label(fit)]
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_theme_font_size_override("font_size", 10)
	meta.add_theme_color_override("font_color", Color(0.76, 0.86, 0.82))
	info.add_child(meta)

	var help := _member_status_help(str(member.get("status", "normal")))
	if help != "":
		var hint := Label.new()
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.text = help
		hint.clip_text = true
		hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hint.add_theme_font_size_override("font_size", 9)
		hint.add_theme_color_override("font_color", Color(0.68, 0.82, 0.78))
		info.add_child(hint)

	var stress_bar := ProgressBar.new()
	stress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stress_bar.custom_minimum_size = Vector2(0, 6)
	stress_bar.min_value = 0
	stress_bar.max_value = 100
	stress_bar.value = clamp(int(member.get("stress", 0)), 0, 100)
	stress_bar.show_percentage = false
	stress_bar.add_theme_stylebox_override("background", _progress_style(Color(0.10, 0.14, 0.13, 0.96)))
	stress_bar.add_theme_stylebox_override("fill", _progress_style(_stress_color(int(member.get("stress", 0)))))
	info.add_child(stress_bar)
	return button

func _item_card(item_id: String, item: Dictionary, fit: int) -> Button:
	var selected := selected_item_ids.has(item_id)
	var button := Button.new()
	button.toggle_mode = true
	button.button_pressed = selected
	button.disabled = not can_dispatch or int(item.get("count", 0)) <= 0
	button.custom_minimum_size = Vector2(0, 42)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = ""
	_style_card_button(button, selected, button.disabled)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	button.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _load_texture(str(item.get("icon", "")))
	row.add_child(icon)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _uses_story_dispatch():
		label.text = "%s\n%s" % [str(item.get("name", item_id)), _item_story_hint(item_id)]
	else:
		label.text = "%s x%d\n%s" % [str(item.get("name", item_id)), int(item.get("count", 0)), _fit_label(fit)]
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", _fit_color(fit))
	row.add_child(label)
	return button

func _build_broadcast_controls(root: VBoxContainer) -> void:
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	root.add_child(modes)
	_add_mode_button(modes, "route_warning", "警告")
	_add_mode_button(modes, "relay_help", "求救")
	_add_mode_button(modes, "silent", "静默")

func _build_order_controls(root: VBoxContainer) -> void:
	var orders := HBoxContainer.new()
	orders.add_theme_constant_override("separation", 4)
	root.add_child(orders)
	_add_order_button(orders, "fallback", "撤回")
	_add_order_button(orders, "steady", "稳进")
	_add_order_button(orders, "push", "强推")

func _build_prep_controls(root: VBoxContainer) -> void:
	var preps := HBoxContainer.new()
	preps.add_theme_constant_override("separation", 4)
	root.add_child(preps)
	_add_prep_button(preps, "none", "无")
	_add_prep_button(preps, "hot_meal", "热")
	_add_prep_button(preps, "battery_scan", "扫")
	_add_prep_button(preps, "quiet_departure", "静")

func _build_objective_controls(root: VBoxContainer) -> void:
	var objectives := HBoxContainer.new()
	objectives.add_theme_constant_override("separation", 4)
	root.add_child(objectives)
	_add_objective_button(objectives, "balanced", "信号")
	_add_objective_button(objectives, "rescue", "救人")
	_add_objective_button(objectives, "supply", "搜补")
	_add_objective_button(objectives, "scout", "侦查")

func _build_unlock_hint(root: VBoxContainer) -> void:
	var hint := Label.new()
	hint.text = _unlock_hint_text()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62))
	root.add_child(hint)

func _build_forecast(root: VBoxContainer) -> void:
	var preview := Label.new()
	preview.text = _probability_text()
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_theme_font_size_override("font_size", 11)
	preview.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	root.add_child(preview)

func _build_simple_forecast(root: VBoxContainer) -> void:
	var preview := Label.new()
	var data: Dictionary = _preview_data()
	if data.is_empty():
		preview.text = "无线电预感：选好成员后，电台会给出大致判断。"
	elif _uses_story_dispatch():
		preview.text = "无线电预感：%s" % _story_forecast_text(int(data.get("success", 0)), int(data.get("failure", 0)))
	else:
		preview.text = "无线电预测：成功 %d%% / 目标：按今日委托执行 / 命令与广播保持默认。" % int(data.get("success", 0))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview.add_theme_font_size_override("font_size", 12)
	preview.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	root.add_child(preview)

func _build_detail_ledger(root: VBoxContainer) -> void:
	var button := Button.new()
	button.text = "隐藏详细账本" if details_expanded else "查看详细账本"
	button.custom_minimum_size = Vector2(0, 34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		details_expanded = not details_expanded
		_rebuild()
	)
	root.add_child(button)
	if not details_expanded:
		return
	_build_stakes(root)
	_build_forecast(root)

func _preview_data() -> Dictionary:
	if not can_dispatch or selected_member_ids.is_empty() or not preview_provider.is_valid():
		return {}
	var preview: Dictionary = preview_provider.call(selected_member_ids, selected_item_ids, broadcast_mode, route_id, prep_id, order_id, objective_id)
	return preview

func _story_forecast_text(success: int, failure: int) -> String:
	if failure >= 45:
		return "这次像是在赌命，最好再听一句或换更稳的路线。"
	if success >= 70:
		return "这段求救有把握，队伍知道自己要找什么。"
	if success >= 45:
		return "能试，但路上可能会出岔子。"
	return "线索还不够稳，外勤会很吃力。"

func _story_route_result_label(new_route_id: String) -> String:
	match new_route_id:
		"fast":
			return "穿正街"
		"unknown":
			return "走地下通道"
	return "侧巷绕行"

func _member_story_hint(member_id: String) -> String:
	match member_id:
		"shen_luo":
			return "听信号"
		"xu_lan":
			return "照看伤员"
		"lao_zhou":
			return "算口粮"
		"a_qing":
			return "认路开锁"
	return "可出勤"

func _item_story_hint(item_id: String) -> String:
	match item_id:
		"medkit":
			return "适合伤员"
		"radio":
			return "保持联络"
		"crowbar":
			return "开路破障"
		"battery":
			return "稳住电台"
	return "可带出"

func _build_stakes(root: VBoxContainer) -> void:
	var stakes := Label.new()
	stakes.text = _stakes_text()
	stakes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stakes.add_theme_font_size_override("font_size", 11)
	stakes.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62))
	root.add_child(stakes)

func _progress_day() -> int:
	return clamp(int(selected_location.get("day", 1)), 1, 3)

func _objective_unlocked() -> bool:
	return _progress_day() >= 2

func _prep_unlocked() -> bool:
	return _progress_day() >= 2

func _order_unlocked() -> bool:
	return _progress_day() >= 3

func _broadcast_unlocked() -> bool:
	return _progress_day() >= 3

func _forecast_unlocked() -> bool:
	return _progress_day() >= 2

func _uses_story_dispatch() -> bool:
	return _progress_day() == 1 and str(selected_location.get("story_intro", "")) != ""

func _field_choice_data() -> Dictionary:
	if not last_result.is_empty() and (last_result.get("field_choice", {}) is Dictionary):
		var result_choice: Dictionary = last_result.get("field_choice", {})
		if not result_choice.is_empty():
			return result_choice
	return selected_location.get("field_choice", {}) as Dictionary

func _field_choice_feed_lines() -> Array:
	var choice := _field_choice_data()
	var lines: Array = choice.get("feed_lines", [])
	if lines.is_empty():
		return ["外勤队进入目标区域。", "无线电里传来短促呼吸。", "队伍等待你的指令。"]
	return lines

func _unlock_hint_text() -> String:
	match _progress_day():
		1:
			if _uses_story_dispatch():
				return "第一班：先问一名队员，选外勤和路线。目标、广播和推进命令先由电台默认处理。"
			return "今日工作：选 1-2 名外勤和最多 2 件装备，点击地图路线，然后派出。目标、广播和推进命令先由电台默认处理。"
		2:
			return "新功能：可以改外勤目标，也可以花资源做出发准备。广播和推进命令暂时保持默认。"
		_:
			return "全部功能已开放：目标、准备、推进命令和广播都会改变概率、收益和入夜风险。"

func _add_route_chip(root: HBoxContainer, new_route_id: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_pressed = route_id == new_route_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 28)
	_make_compact_button(button)
	button.pressed.connect(func() -> void:
		_set_route(new_route_id)
	)
	root.add_child(button)

func _add_mode_button(root: HBoxContainer, new_mode: String, text: String) -> void:
	var button := Button.new()
	button.text = "%s %s" % [text, _broadcast_effect_text(new_mode)]
	button.toggle_mode = true
	button.button_pressed = broadcast_mode == new_mode
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 36)
	_make_compact_button(button)
	button.pressed.connect(func() -> void:
		broadcast_mode = new_mode
		_rebuild()
	)
	root.add_child(button)

func _add_prep_button(root: HBoxContainer, new_prep_id: String, text: String) -> void:
	var button := Button.new()
	button.text = "%s\n%s" % [text, _prep_cost_text(new_prep_id)]
	button.toggle_mode = true
	button.button_pressed = prep_id == new_prep_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 40)
	_make_compact_button(button)
	button.disabled = not _can_pay_prep(new_prep_id)
	button.pressed.connect(func() -> void:
		prep_id = new_prep_id
		_rebuild()
	)
	root.add_child(button)

func _add_order_button(root: HBoxContainer, new_order_id: String, text: String) -> void:
	var button := Button.new()
	button.text = "%s %s" % [text, _order_effect_text(new_order_id)]
	button.toggle_mode = true
	button.button_pressed = order_id == new_order_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 34)
	_make_compact_button(button)
	button.pressed.connect(func() -> void:
		order_id = new_order_id
		_rebuild()
	)
	root.add_child(button)

func _add_objective_button(root: HBoxContainer, new_objective_id: String, text: String) -> void:
	var button := Button.new()
	button.text = "%s\n%s" % [text, _objective_chip_text(new_objective_id)]
	button.toggle_mode = true
	button.button_pressed = objective_id == new_objective_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 42)
	_make_compact_button(button)
	button.pressed.connect(func() -> void:
		objective_id = new_objective_id
		_rebuild()
	)
	root.add_child(button)

func _set_route(new_route_id: String) -> void:
	if phase != "planning":
		return
	route_id = new_route_id
	if _uses_story_dispatch():
		story_route_confirmed = true
	_rebuild()

func _set_objective(new_objective_id: String) -> void:
	if phase != "planning":
		return
	objective_id = new_objective_id
	_rebuild()

func _start_transmit_timer() -> void:
	if transmit_timer != null:
		return
	transmit_timer = Timer.new()
	transmit_timer.wait_time = 0.18
	transmit_timer.one_shot = false
	transmit_timer.timeout.connect(_advance_transmission)
	add_child(transmit_timer)
	transmit_timer.start()

func _advance_transmission() -> void:
	transmit_elapsed += 0.18
	if route_map != null:
		route_map.queue_redraw()
	if transmit_elapsed >= 2.4:
		phase = "resolved"
		if transmit_timer != null:
			transmit_timer.stop()
			transmit_timer.queue_free()
			transmit_timer = null
		_rebuild()
		return
	_rebuild()

func _transmit_feed_text() -> String:
	var lines: Array = last_result.get("feed_lines", [])
	var visible_count: int = clamp(int(floor(transmit_elapsed / 0.72)) + 1, 1, max(1, lines.size()))
	var output := ""
	for index in range(min(visible_count, lines.size())):
		if index > 0:
			output += "\n"
		output += "%d. %s" % [index + 1, str(lines[index])]
	if output == "":
		output = "1. 频道接通。"
	return output

func _member_slot_text(index: int) -> String:
	if index >= selected_member_ids.size():
		return "空"
	var member_id := selected_member_ids[index]
	return str(members.get(str(member_id), {}).get("name", member_id))

func _item_slot_text(index: int) -> String:
	if index >= selected_item_ids.size():
		return "空"
	var item_id := selected_item_ids[index]
	return str(items.get(str(item_id), {}).get("name", item_id))

func _member_slot_avatar(index: int) -> Control:
	if index >= selected_member_ids.size():
		return _empty_slot_avatar()
	var member_id := selected_member_ids[index]
	var member: Dictionary = members.get(str(member_id), {})
	var glyph := _resolve_member_glyph(member)
	return _build_glyph_badge(glyph["letter"], glyph["color"], 30)

func _item_slot_texture(index: int) -> Texture2D:
	if index >= selected_item_ids.size():
		return null
	var item_id := selected_item_ids[index]
	var item: Dictionary = items.get(str(item_id), {})
	return _load_texture(str(item.get("icon", "")))

func _item_slot_avatar(index: int) -> Control:
	var tex := _item_slot_texture(index)
	if tex == null:
		return _empty_slot_avatar()
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(30, 30)
	rect.size = Vector2(30, 30)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.texture = tex
	return rect

# Map a member dict to a UI-safe "name initial + role color" glyph spec.
# Same role-keyword map as BaseScreen so the BaseScreen member chip
# and the DispatchPanel member card stay visually consistent.
func _resolve_member_glyph(member: Dictionary) -> Dictionary:
	var name_text: String = str(member.get("name", ""))
	var letter := "?"
	if name_text.length() > 0:
		letter = name_text.substr(0, 1).to_upper()
	return {"letter": letter, "color": _role_color(str(member.get("role", "")))}

func _role_color(role: String) -> Color:
	var haystack := role.to_lower()
	if haystack.find("radio") >= 0:
		return Color(1.0, 0.84, 0.45)
	if haystack.find("medic") >= 0 or haystack.find("medical") >= 0:
		return Color(0.85, 0.40, 0.40)
	if haystack.find("quartermaster") >= 0 or haystack.find("trade") >= 0 or haystack.find("scavenger") >= 0:
		return Color(0.45, 0.55, 0.70)
	if haystack.find("mechanic") >= 0 or haystack.find("pathfinder") >= 0 or haystack.find("repair") >= 0:
		return Color(0.40, 0.70, 0.55)
	return Color(0.55, 0.55, 0.55)

func _build_glyph_badge(letter: String, color: Color, size: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(size, size)
	panel.size = Vector2(size, size)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.85)
	style.border_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", max(14, int(size * 0.5)))
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	panel.add_child(label)
	return panel

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if texture_cache.has(path):
		return texture_cache[path] as Texture2D
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(path))
	if error != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	texture_cache[path] = texture
	return texture

func _feed_text() -> String:
	var feed_lines: Array = last_result.get("feed_lines", [])
	if feed_lines.is_empty():
		return "1. 频道接通。\n2. 队伍回传断续信号。\n3. 等待夜间结算。"
	var text := ""
	for index in range(feed_lines.size()):
		if index > 0:
			text += "\n"
		text += "%d. %s" % [index + 1, str(feed_lines[index])]
	return text

func _toggle_member(member_id: String) -> void:
	if selected_member_ids.has(member_id):
		selected_member_ids.erase(member_id)
	elif selected_member_ids.size() < 2:
		selected_member_ids.append(member_id)
	_rebuild()

func _toggle_item(item_id: String) -> void:
	if selected_item_ids.has(item_id):
		selected_item_ids.erase(item_id)
	elif selected_item_ids.size() < 2:
		selected_item_ids.append(item_id)
	_rebuild()

func _update_launch_state() -> void:
	if launch_button == null:
		return
	launch_button.disabled = not can_dispatch or selected_member_ids.is_empty()
	if not can_dispatch:
		launch_button.text = "路线未确认"
	elif selected_member_ids.is_empty():
		launch_button.text = "选择队员"
	else:
		launch_button.text = "派出外勤队"

func _probability_text() -> String:
	if not can_dispatch:
		return "目标未确认。"
	if selected_member_ids.is_empty():
		return "选择队员后，电台会估算外勤结果。"
	if not preview_provider.is_valid():
		return "无线电预测不可用。"
	var preview: Dictionary = preview_provider.call(selected_member_ids, selected_item_ids, broadcast_mode, route_id, prep_id, order_id, objective_id)
	if preview.is_empty():
		return "无线电预测不可用。"
	var text := "成功 %d%% / 部分 %d%% / 失败 %d%%  ·  准备 %d" % [
		int(preview.get("success", 0)),
		int(preview.get("partial", 0)),
		int(preview.get("failure", 0)),
		int(preview.get("score", 0))
	]
	var reasons: Array = preview.get("reasons", [])
	for index in range(min(6, reasons.size())):
		text += "\n%s" % str(reasons[index])
	return text

func _stakes_text() -> String:
	if selected_location.is_empty():
		return "赌注：目标未确认。"
	var route_def := _active_route_def()
	var order_def := _active_order_def(order_id)
	var objective_def := _active_objective_def(objective_id)
	var multiplier := float(route_def.get("reward_multiplier", 1.0)) * float(order_def.get("reward_multiplier", 1.0)) * float(objective_def.get("reward_multiplier", 1.0))
	var rescue_multiplier := float(objective_def.get("rescue_multiplier", 1.0))
	var success := _format_delta_dict(selected_location.get("signal_reward", {}) as Dictionary, multiplier, rescue_multiplier)
	var partial := _format_delta_dict(selected_location.get("signal_reward", {}) as Dictionary, 0.5 * multiplier, rescue_multiplier)
	var failure := _format_delta_dict(selected_location.get("signal_failure", {}) as Dictionary, 1.0)
	var route_costs: Array[String] = []
	var fuel := int(route_def.get("fuel", 0))
	var threat := int(route_def.get("threat", 0))
	var failure_risk := int(route_def.get("failure_risk", 0))
	if fuel != 0:
		route_costs.append("燃料 -%d" % fuel)
	if threat != 0:
		route_costs.append("暴露 %+d" % threat)
	if failure_risk != 0:
		route_costs.append("失败风险 +%d" % failure_risk)
	if route_costs.is_empty():
		route_costs.append("无额外代价")
	var text := "赌注 成功 %s / 部分 %s / 败 %s\n路线 x%.2f：%s\n目标 %s / 情报 %s / 队伍 %s\n准则 %s / 委托 %s / 广播 %s / 入夜 %s" % [
		success,
		partial,
		failure,
		multiplier,
		"，".join(route_costs),
		_objective_effect_text(objective_id),
		_intel_text(),
		_team_chemistry_text(),
		_order_effect_text(order_id),
		_directive_preview_text(),
		_broadcast_effect_text(broadcast_mode),
		_night_forecast_text()
	]
	var shelter_text := _shelter_preview_text()
	if shelter_text != "":
		text += "\n%s" % shelter_text
	return text

func _shelter_preview_text() -> String:
	if not preview_provider.is_valid():
		return ""
	var preview: Dictionary = preview_provider.call(selected_member_ids, selected_item_ids, broadcast_mode, route_id, prep_id, order_id, objective_id)
	var shelter: Dictionary = preview.get("shelter", {})
	if shelter.is_empty():
		return ""
	var success_rescued := int(shelter.get("success_rescued", 0))
	var partial_rescued := int(shelter.get("partial_rescued", 0))
	var success_extra := int(shelter.get("success_extra_food", 0))
	var partial_extra := int(shelter.get("partial_extra_food", 0))
	var success_shortage := int(shelter.get("success_shortage", 0))
	var partial_shortage := int(shelter.get("partial_shortage", 0))
	var text := "安置 成功 +%d人 口粮 +%d / 部分 +%d人 口粮 +%d" % [
		success_rescued,
		success_extra,
		partial_rescued,
		partial_extra
	]
	if success_shortage > 0 or partial_shortage > 0:
		text += " / 短缺 成功 %d 部分 %d" % [success_shortage, partial_shortage]
	return text

func _night_forecast_text() -> String:
	var forecast: Array = selected_location.get("night_forecast", [])
	if forecast.is_empty():
		return "暂无额外余波。"
	var lines: Array[String] = []
	for index in range(min(2, forecast.size())):
		lines.append(_short_forecast_line(str(forecast[index])))
	return "；".join(lines)

func _short_forecast_line(line: String) -> String:
	return line.replace("危险趋势", "趋势").replace("信任", "信").replace("压力", "压").replace("夜间危机：", "危机 ")

func _can_pay_prep(new_prep_id: String) -> bool:
	var defs: Dictionary = selected_location.get("prep_defs", {})
	if not defs.has(new_prep_id):
		return new_prep_id == "none"
	var prep_def: Dictionary = defs[new_prep_id]
	var cost: Dictionary = prep_def.get("cost", {})
	var resources: Dictionary = selected_location.get("resources", {})
	for key in cost.keys():
		if int(resources.get(str(key), 0)) < int(cost[key]):
			return false
	return true

func _prep_cost_text(new_prep_id: String) -> String:
	match new_prep_id:
		"none":
			return "0"
		"hot_meal":
			return "食1 准8"
		"battery_scan":
			return "电1 暴1"
		"quiet_departure":
			return "油1 暴-1"
	var defs: Dictionary = selected_location.get("prep_defs", {})
	if not defs.has(new_prep_id):
		return ""
	var prep_def: Dictionary = defs[new_prep_id]
	var parts: Array[String] = []
	var cost: Dictionary = prep_def.get("cost", {})
	for key in cost.keys():
		parts.append("%s-%d" % [_resource_short_name(str(key)), int(cost[key])])
	if int(prep_def.get("threat", 0)) != 0:
		parts.append("暴%+d" % int(prep_def.get("threat", 0)))
	if int(prep_def.get("score", 0)) != 0:
		parts.append("准%+d" % int(prep_def.get("score", 0)))
	if parts.is_empty():
		return "免费"
	return " ".join(parts)

func _intel_text() -> String:
	if str(selected_location.get("linked_signal_title", "")) == "":
		return "情报：未接入信号"
	var confidence := _confidence_label(str(selected_location.get("signal_confidence", "unknown")))
	var noise := int(selected_location.get("signal_noise", 0))
	var score := int(selected_location.get("signal_intel_score", 0))
	var mark := str(selected_location.get("signal_mark", ""))
	if mark != "":
		return "情报：%s 噪%d 准%+d / 判断%s%+d" % [confidence, noise, score, _mark_label(mark), int(selected_location.get("signal_mark_score", 0))]
	return "情报：%s 噪%d 准%+d / 未判断" % [confidence, noise, score]

func _memory_text() -> String:
	var text := str(selected_location.get("memory_text", ""))
	if text != "":
		return text
	return "记忆：未踩点"

func _team_chemistry_text() -> String:
	var active := _active_team_chemistries()
	if selected_member_ids.size() < 2:
		return "未成队"
	if active.is_empty():
		return "无化学反应"
	var parts: Array[String] = []
	for chemistry in active:
		var data := chemistry as Dictionary
		var score := int(data.get("score", 0))
		var stress := int(data.get("stress", 0))
		var text := "%s 准%+d" % [str(data.get("name", "组合")), score]
		if stress != 0:
			text += " 压%+d" % stress
		parts.append(text)
	var bond_text := _team_bond_text()
	if bond_text != "":
		parts.append(bond_text)
	return "；".join(parts)

func _team_bond_text() -> String:
	if selected_member_ids.size() < 2:
		return ""
	var bonds: Dictionary = selected_location.get("team_bonds", {})
	var bond := int(bonds.get(_team_pair_key(selected_member_ids), 0))
	if bond == 0:
		return ""
	return "搭档记忆 准%+d" % (bond * 3)

func _team_pair_key(member_ids: Array[String]) -> String:
	if member_ids.size() < 2:
		return ""
	var a := str(member_ids[0])
	var b := str(member_ids[1])
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

func _active_team_chemistries() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	if selected_member_ids.size() < 2:
		return active
	var defs: Dictionary = selected_location.get("team_chemistry_defs", {})
	var tags := _mission_tags()
	for pair_key in defs.keys():
		var pair := str(pair_key).split("|")
		if pair.size() != 2:
			continue
		if not selected_member_ids.has(str(pair[0])) or not selected_member_ids.has(str(pair[1])):
			continue
		var chemistry: Dictionary = (defs[pair_key] as Dictionary).duplicate(true)
		if not _chemistry_matches_tags(chemistry, tags):
			continue
		active.append(chemistry)
	return active

func _chemistry_matches_tags(chemistry: Dictionary, tags: Array[String]) -> bool:
	var rule_tags: Array = chemistry.get("tags", [])
	if rule_tags.is_empty():
		return true
	for tag in rule_tags:
		if tags.has(str(tag)):
			return true
	return false

func _confidence_label(confidence: String) -> String:
	match confidence.to_lower():
		"high":
			return "高可信"
		"medium", "mid":
			return "中可信"
		"low":
			return "低可信"
		_:
			return confidence

func _mark_label(mark_id: String) -> String:
	match mark_id:
		"trusted":
			return "可信"
		"suspect":
			return "可疑"
		"decoy":
			return "诱饵"
		_:
			return "未标记"

func _directive_preview_text() -> String:
	var directive: Dictionary = selected_location.get("current_directive", {})
	if directive.is_empty():
		return "无今日委托"
	if bool(selected_location.get("directive_resolved", false)):
		return "今日委托已结算"
	var reward_text := _format_compact_delta(directive.get("reward", {}) as Dictionary)
	var title := str(directive.get("title", "委托"))
	match str(directive.get("condition", "")):
		"rescue_not_failed":
			if str(selected_location.get("type", "")) == "rescue":
				return "%s：可完成，失败失手，奖%s" % [title, reward_text]
			return "%s：目标不匹配，奖%s" % [title, reward_text]
		"resource_reward_not_failed":
			if _has_resource_reward():
				return "%s：可完成，失败失手，奖%s" % [title, reward_text]
			return "%s：没有补给回流，奖%s" % [title, reward_text]
		"threat_at_most":
			var projected := _projected_threat()
			var max_threat := int(directive.get("max_threat", 2))
			var state := "可完成" if projected <= max_threat else "会失手"
			return "%s：%s 暴%d/%d，奖%s" % [title, state, projected, max_threat, reward_text]
		_:
			return "%s：夜间结算确认，奖%s" % [title, reward_text]

func _has_resource_reward() -> bool:
	var reward: Dictionary = selected_location.get("signal_reward", {})
	for key in ["power", "food", "medicine", "fuel", "parts"]:
		if int(reward.get(key, 0)) > 0:
			return true
	return false

func _projected_threat() -> int:
	var resources: Dictionary = selected_location.get("resources", {})
	var route_def := _active_route_def()
	var prep_def := _active_prep_def(prep_id)
	var broadcast_def := _active_broadcast_def(broadcast_mode)
	var order_def := _active_order_def(order_id)
	return max(0, int(resources.get("threat", 0)) + int(route_def.get("threat", 0)) + int(prep_def.get("threat", 0)) + int(broadcast_def.get("threat", 0)) + int(order_def.get("threat", 0)))

func _format_compact_delta(delta: Dictionary) -> String:
	if delta.is_empty():
		return "无"
	var parts: Array[String] = []
	for key in delta.keys():
		var value := int(delta[key])
		if value == 0:
			continue
		parts.append("%s%+d" % [_resource_short_name(str(key)), value])
	if parts.is_empty():
		return "无"
	return " ".join(parts)

func _order_effect_text(new_order_id: String) -> String:
	var order_def := _active_order_def(new_order_id)
	var parts: Array[String] = []
	var score := int(order_def.get("score", 0))
	if score != 0:
		parts.append("准%+d" % score)
	var reward_multiplier := float(order_def.get("reward_multiplier", 1.0))
	if not is_equal_approx(reward_multiplier, 1.0):
		parts.append("获x%.2f" % reward_multiplier)
	var threat := int(order_def.get("threat", 0))
	if threat != 0:
		parts.append("暴%+d" % threat)
	var stress := int(order_def.get("stress", 0))
	if stress != 0:
		parts.append("压%+d" % stress)
	var failure_risk := int(order_def.get("failure_risk", 0))
	if failure_risk != 0:
		parts.append("险%+d" % failure_risk)
	if bool(order_def.get("protect_injury", false)):
		parts.append("护伤")
	if parts.is_empty():
		return "均衡"
	return " ".join(parts)

func _broadcast_effect_text(new_mode: String) -> String:
	var broadcast_def := _active_broadcast_def(new_mode)
	var parts: Array[String] = []
	var score := int(broadcast_def.get("score", 0))
	if score != 0:
		parts.append("准%+d" % score)
	for key in ["power", "trust", "influence", "threat"]:
		var delta := int(broadcast_def.get(key, 0))
		if delta == 0:
			continue
		parts.append("%s%+d" % [_resource_short_name(str(key)), delta])
	if parts.is_empty():
		return "稳"
	return " ".join(parts)

func _active_broadcast_def(new_mode: String) -> Dictionary:
	var defs: Dictionary = selected_location.get("broadcast_defs", {})
	if defs.has(new_mode):
		return defs[new_mode] as Dictionary
	match new_mode:
		"relay_help":
			return {"score": 8, "influence": 2, "threat": 2, "power": -1, "trust": 0}
		"silent":
			return {"score": -3, "influence": 0, "threat": 0, "power": 0, "trust": -1}
		_:
			return {"score": 5, "influence": 1, "threat": 1, "power": 0, "trust": 0}

func _active_order_def(new_order_id: String) -> Dictionary:
	var defs: Dictionary = selected_location.get("order_defs", {})
	if defs.has(new_order_id):
		return defs[new_order_id] as Dictionary
	match new_order_id:
		"fallback":
			return {"score": -6, "reward_multiplier": 0.85, "threat": -1, "stress": -3, "failure_risk": -10, "protect_injury": true}
		"push":
			return {"score": 8, "reward_multiplier": 1.10, "threat": 1, "stress": 6, "failure_risk": 12, "protect_injury": false}
		_:
			return {"score": 0, "reward_multiplier": 1.0, "threat": 0, "stress": 0, "failure_risk": 0, "protect_injury": false}

func _active_objective_def(new_objective_id: String) -> Dictionary:
	var defs: Dictionary = selected_location.get("objective_defs", {})
	if defs.has(new_objective_id):
		return defs[new_objective_id] as Dictionary
	match new_objective_id:
		"rescue":
			return {"name": "救援优先", "score": 4, "mismatch_score": -4, "reward_multiplier": 0.85, "rescue_multiplier": 1.35, "threat": 0, "stress": 2, "failure_risk": 0}
		"supply":
			return {"name": "搜补给", "score": 3, "mismatch_score": -4, "reward_multiplier": 1.25, "rescue_multiplier": 0.5, "threat": 1, "stress": 1, "failure_risk": 4}
		"scout":
			return {"name": "侦查踩点", "score": 6, "reward_multiplier": 0.45, "rescue_multiplier": 0.5, "threat": 0, "stress": 0, "failure_risk": -6}
		_:
			return {"name": "执行信号", "score": 0, "reward_multiplier": 1.0, "rescue_multiplier": 1.0, "threat": 0, "stress": 0, "failure_risk": 0}

func _objective_effect_text(new_objective_id: String) -> String:
	var objective_def := _active_objective_def(new_objective_id)
	var delta_text := _objective_delta_text(new_objective_id)
	if delta_text == "原定":
		return str(objective_def.get("name", "执行信号"))
	return "%s %s" % [str(objective_def.get("name", new_objective_id)), delta_text]

func _objective_chip_text(new_objective_id: String) -> String:
	match new_objective_id:
		"rescue":
			return "救x%.2f" % float(_active_objective_def(new_objective_id).get("rescue_multiplier", 1.0))
		"supply":
			return "物x%.2f" % float(_active_objective_def(new_objective_id).get("reward_multiplier", 1.0))
		"scout":
			return "降险"
		_:
			return "原定"

func _objective_delta_text(new_objective_id: String) -> String:
	var objective_def := _active_objective_def(new_objective_id)
	var parts: Array[String] = []
	var score := _objective_score_hint(new_objective_id)
	if score != 0:
		parts.append("准%+d" % score)
	var reward_multiplier := float(objective_def.get("reward_multiplier", 1.0))
	if not is_equal_approx(reward_multiplier, 1.0):
		parts.append("物x%.2f" % reward_multiplier)
	var rescue_multiplier := float(objective_def.get("rescue_multiplier", 1.0))
	if not is_equal_approx(rescue_multiplier, 1.0):
		parts.append("救x%.2f" % rescue_multiplier)
	var threat := int(objective_def.get("threat", 0))
	if threat != 0:
		parts.append("暴%+d" % threat)
	var failure_risk := int(objective_def.get("failure_risk", 0))
	if failure_risk != 0:
		parts.append("险%+d" % failure_risk)
	if new_objective_id == "scout":
		parts.append("降险")
	if parts.is_empty():
		return "原定"
	return " ".join(parts)

func _objective_score_hint(new_objective_id: String) -> int:
	var objective_def := _active_objective_def(new_objective_id)
	match new_objective_id:
		"rescue":
			if str(selected_location.get("type", "")) == "rescue" or _mission_tags().has("rescue"):
				return int(objective_def.get("score", 0))
			return int(objective_def.get("mismatch_score", 0))
		"supply":
			if _has_resource_reward():
				return int(objective_def.get("score", 0))
			return int(objective_def.get("mismatch_score", 0))
		_:
			return int(objective_def.get("score", 0))

func _make_compact_button(button: Button) -> void:
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 10)

func _style_card_button(button: Button, selected: bool, disabled: bool) -> void:
	var bg := Color(0.050, 0.064, 0.058, 0.98)
	var border := Color(0.30, 0.46, 0.43, 0.70)
	if selected:
		bg = Color(0.085, 0.078, 0.050, 0.98)
		border = Color(1.0, 0.78, 0.30, 0.90)
	if disabled:
		bg = Color(0.030, 0.036, 0.034, 0.72)
		border = Color(0.16, 0.20, 0.19, 0.65)
	button.add_theme_stylebox_override("normal", _button_style(bg, border))
	button.add_theme_stylebox_override("hover", _button_style(bg.lightened(0.08), border.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.11, 0.10, 0.062, 0.98), Color(1.0, 0.84, 0.42, 1.0)))
	button.add_theme_stylebox_override("disabled", _button_style(bg, border))

func _progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _stress_color(stress: int) -> Color:
	if stress >= 85:
		return Color(1.0, 0.28, 0.22, 0.92)
	if stress >= 60:
		return Color(1.0, 0.72, 0.24, 0.92)
	return Color(0.42, 0.92, 0.58, 0.88)

func _quality_stamp(quality: String) -> String:
	match quality:
		"success":
			return "外勤成功"
		"partial":
			return "部分成功"
		"failure":
			return "外勤失败"
		_:
			return "外勤完成"

func _quality_color(quality: String) -> Color:
	match quality:
		"success":
			return Color(0.48, 1.0, 0.66)
		"partial":
			return Color(1.0, 0.84, 0.45)
		"failure":
			return Color(1.0, 0.38, 0.32)
		_:
			return Color(0.86, 0.94, 0.90)

func _route_label(new_route_id: String) -> String:
	match new_route_id:
		"safe":
			return "安全慢路"
		"fast":
			return "危险近路"
		"unknown":
			return "未知小路"
		_:
			return "未记录"

func _order_label(new_order_id: String) -> String:
	match new_order_id:
		"fallback":
			return "遇险撤回"
		"push":
			return "强行推进"
		_:
			return "稳步推进"

func _active_route_def() -> Dictionary:
	var defs: Dictionary = selected_location.get("route_defs", {})
	if defs.has(route_id):
		return defs[route_id] as Dictionary
	return {
		"name": _route_label(route_id),
		"reward_multiplier": 1.0,
		"fuel": 0,
		"threat": 0,
		"failure_risk": 0
	}

func _active_prep_def(new_prep_id: String) -> Dictionary:
	var defs: Dictionary = selected_location.get("prep_defs", {})
	if defs.has(new_prep_id):
		return defs[new_prep_id] as Dictionary
	return {
		"name": new_prep_id,
		"score": 0,
		"cost": {},
		"threat": 0,
		"stress": 0
	}

func _format_delta_dict(delta: Dictionary, multiplier: float, rescue_multiplier: float = 1.0) -> String:
	if delta.is_empty():
		return "无直接变化"
	var parts: Array[String] = []
	for key in delta.keys():
		var active_multiplier := multiplier * (rescue_multiplier if str(key) == "rescued" else 1.0)
		var value := _scaled_delta(int(delta[key]), active_multiplier)
		if value == 0:
			continue
		parts.append("%s %+d" % [_resource_name(str(key)), value])
	if parts.is_empty():
		return "无直接变化"
	return "，".join(parts)

func _scaled_delta(value: int, multiplier: float) -> int:
	if value == 0:
		return 0
	var scaled := int(round(float(value) * multiplier))
	if value > 0:
		return max(1, scaled)
	return min(-1, scaled)

func _resource_name(key: String) -> String:
	return {
		"power": "电力",
		"food": "食物",
		"medicine": "药品",
		"fuel": "燃料",
		"parts": "零件",
		"trust": "信任",
		"influence": "影响力",
		"threat": "暴露",
		"rescued": "救回"
	}.get(key, key)

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

func _member_available(member: Dictionary) -> bool:
	var status := str(member.get("status", "normal"))
	return status == "normal" or status == "tired"

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

func _member_status_help(status: String) -> String:
	match status:
		"tired":
			return "疲惫：仍可派遣，但准备 -8；可通过轮休、医务角或部分夜间安排恢复。"
		"injured":
			return "受伤：不可正常恢复，需医务分诊或医务角处理。"
		_:
			return ""

func _mission_tags() -> Array[String]:
	var tags: Array[String] = []
	for source in [selected_location.get("mission_tags", []), selected_location.get("tags", [])]:
		for tag in source:
			var tag_id := str(tag)
			if tag_id == "" or tags.has(tag_id):
				continue
			tags.append(tag_id)
	return tags

func _member_fit_score(member_id: String) -> int:
	var member: Dictionary = members.get(member_id, {})
	var strengths: Array = member.get("strengths", [])
	var weaknesses: Array = member.get("weaknesses", [])
	var score := 0
	for tag in _mission_tags():
		if strengths.has(tag):
			score += 12
		if weaknesses.has(tag):
			score -= 6
	if str(member.get("status", "normal")) == "tired":
		score -= 8
	if int(member.get("stress", 0)) >= 60:
		score -= 8
	return score

func _item_fit_score(item_id: String) -> int:
	var item: Dictionary = items.get(item_id, {})
	var item_tags: Array = item.get("tags", [])
	for tag in _mission_tags():
		if item_tags.has(tag):
			return int(item.get("bonus", 0))
	return 0

func _fit_label(score: int) -> String:
	if score > 0:
		return "契合 +%d" % score
	if score < 0:
		return "短板 %d" % score
	return "无契合"

func _fit_color(score: int) -> Color:
	if score > 0:
		return Color(0.78, 1.0, 0.82)
	if score < 0:
		return Color(1.0, 0.70, 0.58)
	return Color(0.82, 0.92, 0.88)

func _tag_list_text(tags: Array[String]) -> String:
	if tags.is_empty():
		return "未确认"
	var labels: Array[String] = []
	for tag in tags:
		labels.append(_tag_label(str(tag)))
	return " / ".join(labels)

func _tag_label(tag: String) -> String:
	match tag:
		"rescue":
			return "救援"
		"field":
			return "外勤"
		"medical":
			return "医疗"
		"trade":
			return "交易"
		"supply":
			return "补给"
		"repair":
			return "修理"
		"radio":
			return "电台"
		"fuel":
			return "燃料"
		"family":
			return "居民"
		"children":
			return "学生"
		"safe":
			return "安全"
		_:
			return tag

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

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style
