extends Node2D

const FACILITIES_PATH := "res://data/defense_facilities.json"
const UNITS_PATH := "res://data/defense_units.json"
const CAMPAIGN_PATH := "res://data/defense_campaign.json"
const RADIO_ACTIONS_PATH := "res://data/defense_radio_actions.json"
const BACKGROUND_PATH := "res://assets/reused/lighthouse_base_v2.png"

const MAP_SIZE := Vector2(1280, 720)
const PLAY_RECT := Rect2(Vector2.ZERO, Vector2(960, 720))
const BASE_POSITION := Vector2(600, 360)
const MAX_BASE_HP := 24
const SHARED_RADIO_COOLDOWN := 6.0

var facility_defs: Dictionary = {}
var unit_defs: Dictionary = {}
var radio_action_defs: Dictionary = {}
var campaign_defs: Array[Dictionary] = []

var route_points := {}
var route_paths := {}
var route_jams := {}
var route_signal_lines := {}
var route_warning_lines := {}
var build_points := {}
var build_marker_nodes := {}
var build_buttons := {}

var resources := {
	"scrap": 0,
	"power": 0,
	"fuel": 0,
	"trust": 0,
	"threat": 0,
	"battery": 0
}
var base_hp := MAX_BASE_HP
var current_day_index := 0
var phase := "day"
var selected_signal_id := ""
var selected_build_point := ""
var selected_signal: Dictionary = {}
var active_units: Array[Dictionary] = []
var facilities: Array[Dictionary] = []
var spawn_tasks: Array[Dictionary] = []
var logs: Array[String] = []

var night_elapsed := 0.0
var ui_refresh_elapsed := 0.0
var exposure_timer := 0.0
var radio_cooldown := 0.0
var shake_timer := 0.0
var shake_duration := 0.0
var shake_strength := 0.0
var reroute_charges := 0
var reroute_source_route := ""
var tuned_route := "north_bridge"
var game_over := false
var outcome := ""

var spawned_total := 0
var killed_total := 0
var rescued_total := 0
var salvaged_total := 0
var turret_damage_done := 0
var base_damage_taken := 0
var radio_actions_used := 0
var exposure_spawns := 0

var map_layer: Node2D
var route_layer: Node2D
var facility_layer: Node2D
var unit_layer: Node2D
var effect_layer: Node2D
var ui_layer: CanvasLayer
var root_ui: Control
var status_label: Label
var resource_label: Label
var objective_label: Label
var signal_box: VBoxContainer
var action_title: Label
var action_box: VBoxContainer
var radio_box: VBoxContainer
var wave_label: Label
var log_title_label: Label
var log_body: RichTextLabel
var start_button: Button
var continue_button: Button
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var base_sprite: Node2D

func _ready() -> void:
	_load_data()
	_setup_level_data()
	_build_world()
	_build_ui()
	_reset_campaign()
	set_process(true)

func _process(delta: float) -> void:
	_advance_night(delta)
	_update_screen_shake(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") and phase == "night":
		_toggle_pause()

func _load_data() -> void:
	facility_defs = _array_to_dict(_load_json_array(FACILITIES_PATH))
	unit_defs = _array_to_dict(_load_json_array(UNITS_PATH))
	radio_action_defs = _array_to_dict(_load_json_array(RADIO_ACTIONS_PATH))
	campaign_defs.clear()
	for entry in _load_json_array(CAMPAIGN_PATH):
		campaign_defs.append(entry as Dictionary)

func _load_json_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data file: %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid JSON array: %s" % path)
		return []
	return parsed

func _array_to_dict(entries: Array) -> Dictionary:
	var result := {}
	for entry in entries:
		var data := entry as Dictionary
		result[str(data.get("id", ""))] = data
	return result

func _setup_level_data() -> void:
	route_points = {
		"north_bridge": [
			Vector2(35, 120),
			Vector2(250, 145),
			Vector2(395, 190),
			Vector2(510, 265),
			BASE_POSITION
		],
		"south_gate": [
			Vector2(35, 610),
			Vector2(260, 555),
			Vector2(420, 485),
			Vector2(515, 430),
			BASE_POSITION
		],
		"service_tunnel": [
			Vector2(920, 650),
			Vector2(835, 545),
			Vector2(740, 465),
			Vector2(665, 410),
			BASE_POSITION
		]
	}
	for route_id in route_points.keys():
		route_jams[route_id] = 0.0
	build_points = {
		"north_turret": {"name": "北桥火力点", "route": "north_bridge", "position": Vector2(385, 172), "allowed": ["turret", "relay"], "block_progress": 0.0},
		"north_barricade": {"name": "北桥拦截点", "route": "north_bridge", "position": Vector2(510, 265), "allowed": ["barricade", "decoy"], "block_progress": 0.72},
		"south_turret": {"name": "南门火力点", "route": "south_gate", "position": Vector2(405, 535), "allowed": ["turret", "relay"], "block_progress": 0.0},
		"south_barricade": {"name": "南门拦截点", "route": "south_gate", "position": Vector2(515, 455), "allowed": ["barricade", "decoy"], "block_progress": 0.70},
		"service_turret": {"name": "维修道火力点", "route": "service_tunnel", "position": Vector2(835, 545), "allowed": ["turret", "relay"], "block_progress": 0.0},
		"service_barricade": {"name": "维修道拦截点", "route": "service_tunnel", "position": Vector2(740, 465), "allowed": ["barricade", "decoy"], "block_progress": 0.58}
	}

func _build_world() -> void:
	map_layer = Node2D.new()
	add_child(map_layer)
	_create_map_backdrop()
	route_layer = Node2D.new()
	route_layer.z_index = 1
	map_layer.add_child(route_layer)
	facility_layer = Node2D.new()
	facility_layer.z_index = 3
	map_layer.add_child(facility_layer)
	unit_layer = Node2D.new()
	unit_layer.z_index = 4
	map_layer.add_child(unit_layer)
	effect_layer = Node2D.new()
	effect_layer.z_index = 5
	map_layer.add_child(effect_layer)
	for route_id in route_points.keys():
		_create_route(route_id, route_points[route_id])
	_create_base_marker()
	_create_build_point_markers()

func _create_map_backdrop() -> void:
	var ground := _create_rect_poly(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.026, 0.035, 0.034, 1.0))
	map_layer.add_child(ground)
	var bg := Sprite2D.new()
	bg.texture = _load_texture(BACKGROUND_PATH)
	if bg.texture != null:
		bg.centered = false
		var scale: float = max(PLAY_RECT.size.x / float(bg.texture.get_width()), PLAY_RECT.size.y / float(bg.texture.get_height()))
		bg.scale = Vector2.ONE * scale
		bg.position = Vector2((PLAY_RECT.size.x - float(bg.texture.get_width()) * scale) * 0.5, 0.0)
		bg.modulate = Color(0.76, 0.88, 0.86, 0.62)
		map_layer.add_child(bg)
	var wash := _create_rect_poly(Rect2(Vector2.ZERO, PLAY_RECT.size), Color(0.012, 0.018, 0.018, 0.22))
	map_layer.add_child(wash)
	for x in range(0, 961, 80):
		_add_map_line(Vector2(x, 0), Vector2(x, 720), Color(0.34, 0.75, 0.70, 0.14), 1)
	for y in range(0, 721, 80):
		_add_map_line(Vector2(0, y), Vector2(960, y), Color(0.34, 0.75, 0.70, 0.12), 1)

func _add_map_line(from_pos: Vector2, to_pos: Vector2, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array([from_pos, to_pos])
	line.width = width
	line.default_color = color
	map_layer.add_child(line)
	return line

func _create_rect_poly(rect: Rect2, color: Color) -> Polygon2D:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y)
	])
	poly.color = color
	return poly

func _add_health_bar(parent: Node2D, name_prefix: String, width: float, y: float, fill_color: Color) -> void:
	var back := Line2D.new()
	back.name = "%s_back" % name_prefix
	back.points = PackedVector2Array([Vector2(-width * 0.5, y), Vector2(width * 0.5, y)])
	back.width = 5
	back.default_color = Color(0.0, 0.0, 0.0, 0.72)
	parent.add_child(back)
	var fill := Line2D.new()
	fill.name = "%s_fill" % name_prefix
	fill.points = PackedVector2Array([Vector2(-width * 0.5, y), Vector2(width * 0.5, y)])
	fill.width = 3
	fill.default_color = fill_color
	fill.set_meta("bar_width", width)
	fill.set_meta("bar_y", y)
	parent.add_child(fill)

func _set_health_bar(parent: Node, name_prefix: String, hp: int, max_hp: int) -> void:
	var fill := parent.get_node_or_null("%s_fill" % name_prefix) as Line2D
	if fill == null:
		return
	var width := float(fill.get_meta("bar_width", 32.0))
	var y := float(fill.get_meta("bar_y", -24.0))
	var ratio: float = clamp(float(hp) / max(1.0, float(max_hp)), 0.0, 1.0)
	fill.points = PackedVector2Array([
		Vector2(-width * 0.5, y),
		Vector2(-width * 0.5 + width * ratio, y)
	])

func _update_unit_health_visual(unit: Dictionary) -> void:
	if not is_instance_valid(unit.get("visual")):
		return
	_set_health_bar(unit["visual"] as Node, "unit_hp", int(unit.get("hp", 0)), int(unit.get("max_hp", 1)))

func _update_facility_health_visual(facility: Dictionary) -> void:
	if not is_instance_valid(facility.get("node")):
		return
	_set_health_bar(facility["node"] as Node, "facility_hp", int(facility.get("hp", 0)), int(facility.get("max_hp", 1)))

func _update_facility_level_visual(facility: Dictionary) -> void:
	if not is_instance_valid(facility.get("node")):
		return
	var node := facility["node"] as Node2D
	var old := node.get_node_or_null("level_marks")
	if old != null:
		old.queue_free()
	var marks := Node2D.new()
	marks.name = "level_marks"
	node.add_child(marks)
	var level := int(facility.get("level", 1))
	for i in range(level):
		var pip := Polygon2D.new()
		pip.position = Vector2(-12 + i * 12, -34)
		pip.polygon = _circle_points(3.2, 12)
		pip.color = Color(1.0, 0.82, 0.30, 1.0)
		marks.add_child(pip)

func _create_route(route_id: String, points: Array) -> void:
	var curve := Curve2D.new()
	for point in points:
		curve.add_point(point)
	var path := Path2D.new()
	path.name = route_id
	path.curve = curve
	route_layer.add_child(path)
	route_paths[route_id] = path
	_add_route_line(points, Color(0.01, 0.014, 0.013, 0.82), 24)
	_add_route_line(points, Color(0.28, 0.21, 0.15, 0.76), 11)
	var route_signal := _add_route_line(points, _route_color(route_id, 0.76), 3)
	route_signal.z_index = 2
	route_signal_lines[route_id] = route_signal
	var warning := _add_route_line(points, Color(1.0, 0.22, 0.12, 0.0), 6)
	warning.z_index = 3
	route_warning_lines[route_id] = warning

func _add_route_line(points: Array, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.points = PackedVector2Array(points)
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	route_layer.add_child(line)
	return line

func _create_base_marker() -> void:
	var base := Node2D.new()
	base.position = BASE_POSITION
	facility_layer.add_child(base)
	base.add_child(_create_circle_line(64, Color(0.18, 0.95, 1.0, 0.82), 4))
	base.add_child(_create_circle_line(43, Color(0.18, 0.95, 1.0, 0.34), 2))
	base.add_child(_create_shadow(Vector2(0, 11), 42, 0.48))
	var body := Polygon2D.new()
	body.polygon = _circle_points(25, 20)
	body.color = Color(0.05, 0.08, 0.075, 0.94)
	base.add_child(body)
	var core := Polygon2D.new()
	core.polygon = _circle_points(11, 18)
	core.color = Color(1.0, 0.78, 0.30, 1.0)
	base.add_child(core)
	var mast := Line2D.new()
	mast.points = PackedVector2Array([Vector2(0, -54), Vector2(0, -16)])
	mast.width = 5
	mast.default_color = Color(0.80, 0.86, 0.78, 1.0)
	base.add_child(mast)
	var mast_tip := Polygon2D.new()
	mast_tip.position = Vector2(0, -58)
	mast_tip.polygon = _circle_points(5, 12)
	mast_tip.color = Color(0.28, 1.0, 0.96, 1.0)
	base.add_child(mast_tip)
	base_sprite = base

func _create_build_point_markers() -> void:
	for point_id in build_points.keys():
		var point: Dictionary = build_points[point_id]
		var marker := Node2D.new()
		marker.position = point["position"]
		facility_layer.add_child(marker)
		build_marker_nodes[point_id] = marker
		marker.add_child(_create_circle_line(28, Color(0.28, 0.90, 0.96, 0.50), 3))
		var dot := Polygon2D.new()
		dot.polygon = _circle_points(5, 18)
		dot.color = Color(0.45, 1.0, 0.88, 0.72)
		marker.add_child(dot)

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	root_ui = Control.new()
	root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root_ui)
	var build_button_layer := Control.new()
	build_button_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_ui.add_child(build_button_layer)
	for point_id in build_points.keys():
		var point: Dictionary = build_points[point_id]
		var button := Button.new()
		button.position = point["position"] - Vector2(38, 38)
		button.size = Vector2(76, 76)
		button.text = ""
		_style_invisible_button(button)
		var captured_id := str(point_id)
		button.pressed.connect(func() -> void: _select_build_point(captured_id))
		build_button_layer.add_child(button)
		build_buttons[point_id] = button
	var top_panel := _make_panel(Vector2(18, 14), Vector2(944, 82))
	root_ui.add_child(top_panel)
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 4)
	top_panel.add_child(top_box)
	var title := Label.new()
	title.text = "最后电台：守夜防线 v0.4"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	top_box.add_child(title)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Color(0.78, 0.94, 0.95))
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top_box.add_child(status_label)
	var right_panel := _make_panel(Vector2(980, 14), Vector2(280, 692))
	root_ui.add_child(right_panel)
	var right_box := VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 5)
	right_panel.add_child(right_box)
	resource_label = Label.new()
	resource_label.add_theme_font_size_override("font_size", 13)
	resource_label.add_theme_color_override("font_color", Color(0.86, 0.96, 0.90))
	right_box.add_child(resource_label)
	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 12)
	objective_label.add_theme_color_override("font_color", Color(0.88, 0.94, 0.78))
	right_box.add_child(objective_label)
	var signal_title := Label.new()
	signal_title.text = "频段选择"
	signal_title.add_theme_font_size_override("font_size", 18)
	signal_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	right_box.add_child(signal_title)
	signal_box = VBoxContainer.new()
	signal_box.add_theme_constant_override("separation", 6)
	right_box.add_child(signal_box)
	start_button = Button.new()
	start_button.text = "开始夜晚"
	start_button.custom_minimum_size = Vector2(0, 32)
	start_button.pressed.connect(_start_night)
	right_box.add_child(start_button)
	action_title = Label.new()
	action_title.text = "防线操作"
	action_title.add_theme_font_size_override("font_size", 18)
	action_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	right_box.add_child(action_title)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	right_box.add_child(action_box)
	var radio_title := Label.new()
	radio_title.text = "电台控场"
	radio_title.add_theme_font_size_override("font_size", 18)
	radio_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	right_box.add_child(radio_title)
	wave_label = Label.new()
	wave_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wave_label.add_theme_font_size_override("font_size", 11)
	wave_label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.84))
	right_box.add_child(wave_label)
	radio_box = VBoxContainer.new()
	radio_box.add_theme_constant_override("separation", 6)
	right_box.add_child(radio_box)
	continue_button = Button.new()
	continue_button.text = "进入下一天"
	continue_button.custom_minimum_size = Vector2(0, 32)
	continue_button.pressed.connect(_continue_from_report)
	right_box.add_child(continue_button)
	var restart := Button.new()
	restart.text = "重开战役"
	restart.custom_minimum_size = Vector2(0, 30)
	restart.pressed.connect(_reset_campaign)
	right_box.add_child(restart)
	log_title_label = Label.new()
	log_title_label.text = "战况日志"
	log_title_label.add_theme_font_size_override("font_size", 16)
	log_title_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	right_box.add_child(log_title_label)
	log_body = RichTextLabel.new()
	log_body.bbcode_enabled = false
	log_body.custom_minimum_size = Vector2(0, 64)
	log_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_body.add_theme_font_size_override("normal_font_size", 12)
	log_body.add_theme_color_override("default_color", Color(0.78, 0.88, 0.84))
	right_box.add_child(log_body)
	result_panel = _make_panel(Vector2(330, 222), Vector2(560, 280))
	result_panel.visible = false
	root_ui.add_child(result_panel)
	var result_box := VBoxContainer.new()
	result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	result_box.add_theme_constant_override("separation", 12)
	result_panel.add_child(result_box)
	result_title = Label.new()
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 36)
	result_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.42))
	result_box.add_child(result_title)
	result_body = Label.new()
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_body.add_theme_font_size_override("font_size", 17)
	result_body.add_theme_color_override("font_color", Color(0.86, 0.96, 0.92))
	result_box.add_child(result_body)

func _make_panel(position: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = position
	panel.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.025, 0.024, 0.94)
	style.border_color = Color(0.23, 0.74, 0.78, 0.82)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	return panel

func _style_invisible_button(button: Button) -> void:
	var blank := StyleBoxFlat.new()
	blank.bg_color = Color(0, 0, 0, 0)
	blank.border_color = Color(0, 0, 0, 0)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.14, 0.45, 0.48, 0.24)
	hover.border_color = Color(0.35, 0.95, 1.0, 0.72)
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.corner_radius_top_left = 38
	hover.corner_radius_top_right = 38
	hover.corner_radius_bottom_left = 38
	hover.corner_radius_bottom_right = 38
	button.add_theme_stylebox_override("normal", blank)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", hover)

func _reset_campaign() -> void:
	_clear_combat_nodes()
	resources = {"scrap": 0, "power": 0, "fuel": 0, "trust": 0, "threat": 0, "battery": 0}
	base_hp = MAX_BASE_HP
	current_day_index = 0
	selected_signal_id = ""
	selected_signal.clear()
	selected_build_point = ""
	facilities.clear()
	active_units.clear()
	spawn_tasks.clear()
	logs.clear()
	game_over = false
	outcome = ""
	spawned_total = 0
	killed_total = 0
	rescued_total = 0
	salvaged_total = 0
	turret_damage_done = 0
	base_damage_taken = 0
	radio_actions_used = 0
	exposure_spawns = 0
	result_panel.visible = false
	_enter_day(0)

func _clear_combat_nodes() -> void:
	for facility in facilities:
		if is_instance_valid(facility.get("node")):
			(facility["node"] as Node).queue_free()
	for unit in active_units:
		if is_instance_valid(unit.get("follow")):
			(unit["follow"] as Node).queue_free()
	if effect_layer != null:
		for child in effect_layer.get_children():
			child.queue_free()

func _enter_day(day_index: int) -> void:
	current_day_index = clamp(day_index, 0, max(0, campaign_defs.size() - 1))
	phase = "day"
	selected_signal_id = ""
	selected_signal.clear()
	night_elapsed = 0.0
	radio_cooldown = 0.0
	exposure_timer = 0.0
	reroute_charges = 0
	reroute_source_route = ""
	tuned_route = "north_bridge"
	for route_id in route_jams.keys():
		route_jams[route_id] = 0.0
	_apply_resource_delta(_current_night().get("starting_modifiers", {}) as Dictionary)
	logs.append("白天 %d：扫描频段，选择今晚要回应的信号。" % (current_day_index + 1))
	_refresh_ui(true)

func _current_night() -> Dictionary:
	if campaign_defs.is_empty():
		return {}
	return campaign_defs[current_day_index] as Dictionary

func _select_signal(signal_id: String) -> bool:
	if phase != "day":
		return false
	var choices: Array = _current_night().get("signal_choices", []) as Array
	for signal_entry in choices:
		var data := signal_entry as Dictionary
		if str(data.get("id", "")) == signal_id:
			selected_signal = data
			selected_signal_id = signal_id
			_apply_signal_effects(data)
			phase = "prep"
			logs.append("锁定信号：%s。" % str(data.get("title", signal_id)))
			_refresh_ui(true)
			return true
	return false

func _apply_signal_effects(signal_data: Dictionary) -> void:
	var effects := signal_data.get("effects", {}) as Dictionary
	for key in ["scrap", "power", "fuel", "trust", "threat", "battery"]:
		if effects.has(key):
			resources[key] = max(0, int(resources.get(key, 0)) + int(effects[key]))

func _start_night() -> void:
	if phase != "prep":
		return
	phase = "night"
	night_elapsed = 0.0
	exposure_timer = 0.0
	_prepare_spawn_tasks()
	logs.append("夜晚 %d：%s，电台控场上线。" % [current_day_index + 1, str(_current_night().get("title", ""))])
	_refresh_ui(true)

func _prepare_spawn_tasks() -> void:
	spawn_tasks.clear()
	var all_spawns: Array = []
	var waves: Array = _current_night().get("waves", []) as Array
	for wave in waves:
		var wave_data := wave as Dictionary
		var wave_spawns: Array = wave_data.get("spawns", []) as Array
		for spawn in wave_spawns:
			var data := spawn as Dictionary
			data["wave_delay"] = float(wave_data.get("delay", 0.0))
			all_spawns.append(data)
	if not selected_signal.is_empty():
		var effects := selected_signal.get("effects", {}) as Dictionary
		var signal_spawns: Array = effects.get("add_spawns", []) as Array
		for spawn in signal_spawns:
			var data := spawn as Dictionary
			data["wave_delay"] = 0.0
			all_spawns.append(data)
	for spawn in all_spawns:
		var data := spawn as Dictionary
		spawn_tasks.append({
			"route": str(data.get("route", "")),
			"unit": str(data.get("unit", "")),
			"count": int(data.get("count", 0)),
			"interval": float(data.get("interval", 1.0)),
			"spawned": 0,
			"next_time": float(data.get("wave_delay", 0.0)) + float(data.get("delay", 0.0)),
			"done": false
		})

func _advance_night(delta: float) -> void:
	if phase != "night" or game_over:
		return
	night_elapsed += delta
	radio_cooldown = max(0.0, radio_cooldown - delta)
	for route_id in route_jams.keys():
		route_jams[route_id] = max(0.0, float(route_jams[route_id]) - delta)
	_process_spawns()
	_process_exposure_spawns(delta)
	_update_units(delta)
	_update_facilities(delta)
	_update_route_visuals()
	_check_terminal_state()
	ui_refresh_elapsed += delta
	if ui_refresh_elapsed >= 0.12:
		ui_refresh_elapsed = 0.0
		_refresh_ui(false)

func _debug_step(delta: float) -> void:
	_advance_night(delta)

func _process_spawns() -> void:
	for task in spawn_tasks:
		if bool(task.get("done", false)):
			continue
		while int(task["spawned"]) < int(task["count"]) and night_elapsed >= float(task["next_time"]):
			var route_id := str(task["route"])
			var unit_id := str(task["unit"])
			if reroute_charges > 0 and unit_id in ["infected", "howler", "armored"] and (reroute_source_route == "" or route_id == reroute_source_route):
				route_id = _alternate_route(route_id)
				reroute_charges -= 1
				if reroute_charges <= 0:
					reroute_source_route = ""
				_spawn_radio_wave(BASE_POSITION, _route_color(route_id, 0.85), 170)
			_spawn_unit(route_id, unit_id)
			task["spawned"] = int(task["spawned"]) + 1
			task["next_time"] = float(task["next_time"]) + float(task["interval"])
		if int(task["spawned"]) >= int(task["count"]):
			task["done"] = true

func _process_exposure_spawns(delta: float) -> void:
	var threat := int(resources.get("threat", 0))
	if threat < 2:
		return
	exposure_timer -= delta
	if exposure_timer > 0.0:
		return
	exposure_timer = max(6.0, 14.0 - float(threat) * 1.8)
	var route_id := _route_with_fewest_enemies()
	var unit_id := "howler" if threat >= 4 else "infected"
	_spawn_unit(route_id, unit_id)
	exposure_spawns += 1
	logs.append("暴露度引来额外压力：%s 出现在%s。" % [_unit_name(unit_id), _route_name(route_id)])

func _spawn_unit(route_id: String, unit_id: String) -> void:
	if not route_paths.has(route_id) or not unit_defs.has(unit_id):
		return
	var def: Dictionary = unit_defs[unit_id]
	var follow := PathFollow2D.new()
	follow.loop = false
	follow.rotates = false
	follow.progress = 0.0
	(route_paths[route_id] as Path2D).add_child(follow)
	var shadow := _create_shadow(Vector2(0, 8), 16, 0.38)
	follow.add_child(shadow)
	var visual := _create_unit_visual(unit_id)
	follow.add_child(visual)
	var unit := {
		"type": unit_id,
		"route": route_id,
		"follow": follow,
		"visual": visual,
		"hp": int(def.get("max_hp", 1)),
		"max_hp": int(def.get("max_hp", 1)),
		"speed": float(def.get("speed", 40)),
		"armor": int(def.get("armor", 0)),
		"base_damage": int(def.get("base_damage", 1)),
		"barrier_damage": int(def.get("barrier_damage", 1)),
		"attack_interval": float(def.get("attack_interval", 1.0)),
		"attack_timer": 0.0,
		"stun_timer": 0.0,
		"is_survivor": bool(def.get("is_survivor", false)),
		"trust_reward": int(def.get("trust_reward", 0))
	}
	active_units.append(unit)
	_update_unit_health_visual(unit)
	spawned_total += 1

func _create_unit_visual(unit_id: String) -> Node2D:
	var node := Node2D.new()
	var body := Polygon2D.new()
	match unit_id:
		"runner":
			body.polygon = PackedVector2Array([Vector2(18, 0), Vector2(-11, -11), Vector2(-6, 0), Vector2(-11, 11)])
			body.color = _unit_color(unit_id)
			node.add_child(body)
			_add_visual_line(node, [Vector2(-18, -8), Vector2(-8, -8)], Color(1.0, 0.72, 0.22, 0.80), 2)
			_add_visual_line(node, [Vector2(-20, 8), Vector2(-8, 8)], Color(1.0, 0.72, 0.22, 0.70), 2)
		"howler":
			body.polygon = PackedVector2Array([Vector2(0, -15), Vector2(14, 0), Vector2(0, 15), Vector2(-14, 0)])
			body.color = _unit_color(unit_id)
			node.add_child(body)
			node.add_child(_create_circle_line(21, Color(1.0, 0.65, 0.18, 0.72), 2))
			_add_visual_line(node, [Vector2(-8, -4), Vector2(8, -4)], Color(0.12, 0.06, 0.02, 0.85), 3)
			_add_visual_line(node, [Vector2(-9, 5), Vector2(9, 5)], Color(0.12, 0.06, 0.02, 0.85), 3)
		"armored":
			body.polygon = PackedVector2Array([Vector2(-16, -10), Vector2(-6, -18), Vector2(10, -18), Vector2(18, -6), Vector2(14, 14), Vector2(-12, 14), Vector2(-18, 0)])
			body.color = _unit_color(unit_id)
			node.add_child(body)
			_add_visual_line(node, [Vector2(-10, -8), Vector2(12, -8)], Color(0.90, 0.76, 0.62, 0.78), 2)
			_add_visual_line(node, [Vector2(-13, 2), Vector2(14, 2)], Color(0.26, 0.20, 0.18, 0.82), 3)
		"survivor_group":
			body.polygon = _circle_points(10, 14)
			body.color = Color(0.08, 0.16, 0.13, 0.96)
			node.add_child(body)
			for offset in [Vector2(-8, 2), Vector2(0, -6), Vector2(8, 2)]:
				var survivor := Polygon2D.new()
				survivor.position = offset
				survivor.polygon = _circle_points(5, 12)
				survivor.color = _unit_color(unit_id)
				node.add_child(survivor)
			node.add_child(_create_circle_line(19, Color(0.38, 1.0, 0.80, 0.70), 2))
		_:
			body.polygon = PackedVector2Array([Vector2(-12, -10), Vector2(8, -13), Vector2(15, -2), Vector2(8, 12), Vector2(-11, 10), Vector2(-16, -1)])
			body.color = _unit_color(unit_id)
			node.add_child(body)
			_add_visual_line(node, [Vector2(-6, -4), Vector2(7, 5)], Color(0.12, 0.02, 0.02, 0.72), 2)
	_add_health_bar(node, "unit_hp", 30 if unit_id != "armored" else 38, -24, _unit_color(unit_id))
	return node

func _update_units(delta: float) -> void:
	for unit in active_units.duplicate():
		if not is_instance_valid(unit.get("follow")):
			active_units.erase(unit)
			continue
		var follow := unit["follow"] as PathFollow2D
		var path := route_paths[str(unit["route"])] as Path2D
		var length := path.curve.get_baked_length()
		unit["stun_timer"] = max(0.0, float(unit.get("stun_timer", 0.0)) - delta)
		if float(unit["stun_timer"]) > 0.0:
			continue
		var blocker: Variant = _blocking_facility_for_unit(unit)
		if blocker != null:
			if str(blocker.get("type", "")) == "barricade":
				follow.progress = float(blocker.get("block_progress", 0.0)) * length
			_attack_facility(unit, blocker, delta)
		else:
			follow.progress += _effective_unit_speed(unit) * delta
		if follow.progress >= length:
			_unit_reaches_base(unit)

func _attack_facility(unit: Dictionary, facility: Dictionary, delta: float) -> void:
	unit["attack_timer"] = max(0.0, float(unit.get("attack_timer", 0.0)) - delta)
	if float(unit["attack_timer"]) > 0.0:
		return
	_damage_facility(facility, int(unit.get("barrier_damage", 1)))
	unit["attack_timer"] = float(unit.get("attack_interval", 1.0))

func _blocking_facility_for_unit(unit: Dictionary) -> Variant:
	if bool(unit.get("is_survivor", false)):
		return null
	var decoy: Variant = _taunt_facility_for_unit(unit)
	if decoy != null:
		return decoy
	if str(unit.get("type", "")) == "runner":
		return null
	var path := route_paths[str(unit["route"])] as Path2D
	var length := path.curve.get_baked_length()
	var progress_ratio: float = (unit["follow"] as PathFollow2D).progress / max(1.0, length)
	for facility in facilities:
		if str(facility.get("type", "")) != "barricade":
			continue
		if str(facility.get("route", "")) != str(unit.get("route", "")):
			continue
		if not bool(facility.get("alive", false)):
			continue
		if progress_ratio >= float(facility.get("block_progress", 0.0)):
			return facility
	return null

func _taunt_facility_for_unit(unit: Dictionary) -> Variant:
	var unit_pos := (unit["follow"] as PathFollow2D).global_position
	for facility in facilities:
		if str(facility.get("type", "")) != "decoy" or not bool(facility.get("alive", false)):
			continue
		var def: Dictionary = facility_defs.get("decoy", {})
		if unit_pos.distance_to(facility["position"]) <= float(def.get("range", 120)):
			return facility
	return null

func _effective_unit_speed(unit: Dictionary) -> float:
	var speed := float(unit.get("speed", 40.0))
	var jam_time := float(route_jams.get(str(unit.get("route", "")), 0.0))
	if jam_time > 0.0 and not bool(unit.get("is_survivor", false)):
		var def: Dictionary = unit_defs.get(str(unit.get("type", "")), {})
		var resistance := float(def.get("radio_resistance", 0.0))
		speed *= 1.0 - 0.55 * (1.0 - resistance)
	return speed

func _damage_facility(facility: Dictionary, amount: int) -> void:
	facility["hp"] = max(0, int(facility.get("hp", 0)) - amount)
	if is_instance_valid(facility.get("node")):
		_spawn_hit_burst(facility["position"], Color(1.0, 0.34, 0.20, 0.92))
		_flash_node(facility["node"] as CanvasItem, Color(1.0, 0.48, 0.32, 1.0), 0.14)
		_update_facility_health_visual(facility)
	if int(facility.get("hp", 0)) <= 0 and bool(facility.get("alive", false)):
		facility["alive"] = false
		if is_instance_valid(facility.get("node")):
			(facility["node"] as Node2D).modulate = Color(0.30, 0.30, 0.30, 0.48)
		logs.append("%s 被撕毁。" % _facility_name(str(facility.get("type", ""))))

func _unit_reaches_base(unit: Dictionary) -> void:
	if bool(unit.get("is_survivor", false)):
		resources["trust"] = int(resources.get("trust", 0)) + int(unit.get("trust_reward", 0))
		rescued_total += 1
		logs.append("幸存者抵达电台：信任 +%d。" % int(unit.get("trust_reward", 0)))
	else:
		var def: Dictionary = unit_defs.get(str(unit.get("type", "")), {})
		var damage := int(unit.get("base_damage", 1))
		base_hp = max(0, base_hp - damage)
		base_damage_taken += damage
		resources["threat"] = max(0, int(resources.get("threat", 0)) + int(def.get("exposure_on_reach", 0)))
		_spawn_base_alarm(damage)
		logs.append("%s 冲入基地：生命 -%d。" % [_unit_name(str(unit.get("type", ""))), damage])
	_remove_unit(unit)

func _update_facilities(delta: float) -> void:
	for facility in facilities:
		if not bool(facility.get("alive", false)):
			continue
		if str(facility.get("type", "")) != "turret":
			continue
		facility["cooldown"] = max(0.0, float(facility.get("cooldown", 0.0)) - delta)
		if float(facility["cooldown"]) > 0.0:
			continue
		var def: Dictionary = facility_defs.get("turret", {})
		var level := int(facility.get("level", 1))
		var target: Variant = _nearest_enemy(facility["position"], float(def.get("range", 160)) + float(level - 1) * 24.0)
		if target == null:
			continue
		_damage_unit(target, int(def.get("damage", 1)) + level - 1, facility["position"])
		facility["cooldown"] = max(0.42, float(def.get("fire_interval", 0.8)) - float(level - 1) * 0.10)

func _nearest_enemy(origin: Vector2, max_range: float) -> Variant:
	var best: Variant = null
	var best_distance := max_range
	for unit in active_units:
		if bool(unit.get("is_survivor", false)) or not is_instance_valid(unit.get("follow")):
			continue
		var distance := origin.distance_to((unit["follow"] as PathFollow2D).global_position)
		if distance <= best_distance:
			best = unit
			best_distance = distance
	return best

func _damage_unit(unit: Dictionary, amount: int, source_position: Vector2) -> void:
	if not active_units.has(unit):
		return
	var actual_damage = max(1, amount - int(unit.get("armor", 0)))
	unit["hp"] = int(unit.get("hp", 0)) - actual_damage
	turret_damage_done += actual_damage
	var target_position := (unit["follow"] as PathFollow2D).global_position
	_spawn_shot_line(source_position, target_position)
	_spawn_hit_burst(target_position, Color(1.0, 0.82, 0.26, 0.95))
	if is_instance_valid(unit.get("visual")):
		_flash_node(unit["visual"] as CanvasItem, Color(1.0, 0.64, 0.28, 1.0), 0.10)
	_update_unit_health_visual(unit)
	if int(unit.get("hp", 0)) <= 0:
		killed_total += 1
		_award_kill_reward(unit, target_position)
		_remove_unit(unit)

func _award_kill_reward(unit: Dictionary, position: Vector2) -> void:
	var def: Dictionary = unit_defs.get(str(unit.get("type", "")), {})
	var reward := int(def.get("scrap_reward", 0))
	if reward <= 0:
		return
	resources["scrap"] = int(resources.get("scrap", 0)) + reward
	salvaged_total += reward
	_spawn_float_text("+%d 废料" % reward, position + Vector2(-18, -34), Color(1.0, 0.86, 0.30, 1.0))

func _remove_unit(unit: Dictionary) -> void:
	if is_instance_valid(unit.get("follow")):
		(unit["follow"] as Node).queue_free()
	active_units.erase(unit)

func _build_facility(point_id: String, facility_id: String) -> bool:
	if phase not in ["prep", "night"] or game_over:
		return false
	if not build_points.has(point_id) or not facility_defs.has(facility_id):
		return false
	if _facility_at_point(point_id) != null:
		return false
	var point: Dictionary = build_points[point_id]
	if not (point.get("allowed", []) as Array).has(facility_id):
		return false
	var def: Dictionary = facility_defs[facility_id]
	if not _has_power_for(def):
		logs.append("电力不足，无法启动%s。" % _facility_name(facility_id))
		_refresh_ui(true)
		return false
	if phase == "night" and int(resources.get("fuel", 0)) <= 0:
		logs.append("燃料不足，无法夜间紧急建造。")
		_refresh_ui(true)
		return false
	if not _pay_cost(def.get("cost", {}) as Dictionary):
		logs.append("废料不足，无法建造%s。" % _facility_name(facility_id))
		_refresh_ui(true)
		return false
	if phase == "night":
		resources["fuel"] = int(resources.get("fuel", 0)) - 1
		resources["threat"] = int(resources.get("threat", 0)) + 1
	var node := _create_facility_node(facility_id, point["position"])
	facility_layer.add_child(node)
	var facility := {
		"id": "%s_%s" % [point_id, facility_id],
		"type": facility_id,
		"point_id": point_id,
		"route": str(point.get("route", "")),
		"position": point["position"],
		"hp": int(def.get("max_hp", 1)),
		"max_hp": int(def.get("max_hp", 1)),
		"node": node,
		"cooldown": 0.0,
		"alive": true,
		"level": 1,
		"block_progress": float(point.get("block_progress", 0.0))
	}
	facilities.append(facility)
	_update_facility_level_visual(facility)
	_update_facility_health_visual(facility)
	logs.append("%s：%s 完成。" % ["紧急建造" if phase == "night" else "建造", _facility_name(facility_id)])
	_refresh_ui(true)
	return true

func _create_facility_node(facility_id: String, position: Vector2) -> Node2D:
	var node := Node2D.new()
	node.position = position
	node.add_child(_create_shadow(Vector2(0, 10), 32, 0.45))
	var body := Polygon2D.new()
	match facility_id:
		"turret":
			body.polygon = PackedVector2Array([Vector2(-23, -13), Vector2(13, -16), Vector2(25, -4), Vector2(21, 13), Vector2(-18, 16), Vector2(-28, 0)])
			body.color = Color(0.70, 0.62, 0.44, 1.0)
			_add_visual_line(node, [Vector2(-8, 0), Vector2(41, -3)], Color(0.92, 0.80, 0.52, 1.0), 7)
			_add_visual_line(node, [Vector2(-17, 18), Vector2(-4, 8), Vector2(14, 18)], Color(0.32, 0.30, 0.24, 1.0), 4)
		"barricade":
			body.polygon = PackedVector2Array([Vector2(-30, -16), Vector2(30, -16), Vector2(30, 16), Vector2(-30, 16)])
			body.color = Color(0.34, 0.43, 0.41, 1.0)
			_add_visual_line(node, [Vector2(-26, 12), Vector2(24, -12)], Color(0.74, 0.84, 0.78, 1.0), 5)
			_add_visual_line(node, [Vector2(-22, -12), Vector2(28, 12)], Color(0.74, 0.84, 0.78, 0.95), 5)
			_add_visual_line(node, [Vector2(-30, 0), Vector2(30, 0)], Color(0.11, 0.12, 0.11, 0.86), 3)
		"relay":
			body.polygon = _circle_points(20, 16)
			body.color = Color(0.07, 0.18, 0.19, 0.96)
			node.add_child(_create_circle_line(34, Color(0.26, 0.92, 1.0, 0.42), 2))
			node.add_child(_create_circle_line(49, Color(0.26, 0.92, 1.0, 0.20), 2))
			_add_visual_line(node, [Vector2(0, 18), Vector2(0, -26)], Color(0.55, 1.0, 0.98, 1.0), 4)
			_add_visual_line(node, [Vector2(-13, -10), Vector2(0, -25), Vector2(13, -10)], Color(0.55, 1.0, 0.98, 0.90), 3)
		"decoy":
			body.polygon = PackedVector2Array([Vector2(-22, 15), Vector2(8, 15), Vector2(8, -15), Vector2(-22, -15)])
			body.color = Color(0.76, 0.42, 0.19, 1.0)
			var cone := Polygon2D.new()
			cone.polygon = PackedVector2Array([Vector2(8, -13), Vector2(30, -24), Vector2(30, 24), Vector2(8, 13)])
			cone.color = Color(0.98, 0.70, 0.28, 1.0)
			node.add_child(cone)
			node.add_child(_create_circle_line(38, Color(1.0, 0.72, 0.26, 0.25), 2))
		_:
			body.polygon = _circle_points(20, 12)
			body.color = Color.WHITE
	node.add_child(body)
	_add_health_bar(node, "facility_hp", 44, 31, Color(0.25, 1.0, 0.74, 1.0))
	return node

func _select_build_point(point_id: String) -> void:
	selected_build_point = point_id
	_refresh_ui(true)

func _tune_route(route_id: String) -> void:
	if not route_points.has(route_id):
		return
	tuned_route = route_id
	logs.append("调频：当前锁定 %s。" % _route_name(route_id))
	_spawn_radio_wave(_route_midpoint(route_id), _route_color(route_id, 0.85), 120)
	_refresh_ui(true)

func _repair_selected_facility() -> void:
	var facility: Variant = _facility_at_point(selected_build_point)
	if facility == null or not bool(facility.get("alive", false)):
		return
	if int(resources.get("scrap", 0)) <= 0:
		logs.append("废料不足，无法维修。")
		_refresh_ui(true)
		return
	resources["scrap"] = int(resources.get("scrap", 0)) - 1
	var def: Dictionary = facility_defs.get(str(facility.get("type", "")), {})
	var repair_amount := int(def.get("repair_amount", 3))
	facility["hp"] = min(int(facility.get("max_hp", 1)), int(facility.get("hp", 0)) + repair_amount)
	_update_facility_health_visual(facility)
	logs.append("维修：%s 恢复 %d 耐久。" % [_facility_name(str(facility.get("type", ""))), repair_amount])
	_refresh_ui(true)

func _upgrade_selected_facility() -> bool:
	var facility: Variant = _facility_at_point(selected_build_point)
	if facility == null or not bool(facility.get("alive", false)):
		return false
	var level := int(facility.get("level", 1))
	if level >= 3:
		return false
	var def: Dictionary = facility_defs.get(str(facility.get("type", "")), {})
	var cost := def.get("upgrade_cost", {}) as Dictionary
	if not _pay_cost(cost):
		logs.append("废料不足，无法升级%s。" % _facility_name(str(facility.get("type", ""))))
		_refresh_ui(true)
		return false
	facility["level"] = level + 1
	var hp_gain := 2
	match str(facility.get("type", "")):
		"barricade":
			hp_gain = 5
		"decoy":
			hp_gain = 4
		_:
			hp_gain = 2
	facility["max_hp"] = int(facility.get("max_hp", 1)) + hp_gain
	facility["hp"] = int(facility.get("hp", 0)) + hp_gain
	_update_facility_level_visual(facility)
	_update_facility_health_visual(facility)
	_spawn_radio_wave(facility["position"], Color(1.0, 0.82, 0.32, 0.82), 90)
	logs.append("升级：%s 提升到 Lv.%d。" % [_facility_name(str(facility.get("type", ""))), int(facility["level"])])
	_refresh_ui(true)
	return true

func _use_radio_action(action_id: String) -> bool:
	if phase != "night" or game_over or not radio_action_defs.has(action_id):
		return false
	var action: Dictionary = radio_action_defs[action_id]
	var cost := _radio_cost(action)
	if radio_cooldown > 0.0 or int(resources.get("battery", 0)) < cost:
		return false
	resources["battery"] = int(resources.get("battery", 0)) - cost
	resources["threat"] = max(0, int(resources.get("threat", 0)) + int(action.get("risk_delta", 0)))
	radio_cooldown = float(action.get("cooldown", SHARED_RADIO_COOLDOWN))
	radio_actions_used += 1
	var duration := _radio_duration(action)
	match str(action.get("effect", "")):
		"jam_route":
			var route_id := tuned_route
			route_jams[route_id] = max(float(route_jams.get(route_id, 0.0)), duration)
			logs.append("电台干扰：%s 敌群减速。" % _route_name(route_id))
			_spawn_radio_wave(_route_midpoint(route_id), _route_color(route_id, 0.90), 150)
		"reroute_next":
			reroute_charges += 1
			reroute_source_route = tuned_route
			logs.append("诱导信标：下一组%s感染者将被改道。" % _route_name(tuned_route))
			_spawn_radio_wave(_route_midpoint(tuned_route), Color(0.22, 0.92, 1.0, 0.75), 190)
		"summon_survivor":
			var survivor_route := tuned_route
			_spawn_unit(survivor_route, "survivor_group")
			_spawn_unit(_alternate_route(survivor_route), "infected")
			_spawn_unit(_alternate_route(survivor_route), "infected")
			logs.append("安抚广播：幸存者从%s靠近，感染者也被吸引。" % _route_name(survivor_route))
			_spawn_radio_wave(_route_midpoint(survivor_route), Color(0.42, 1.0, 0.78, 0.78), 210)
		"base_stun":
			base_hp = max(1, base_hp - 1)
			for unit in active_units:
				if is_instance_valid(unit.get("follow")) and (unit["follow"] as PathFollow2D).global_position.distance_to(BASE_POSITION) <= 210:
					unit["stun_timer"] = max(float(unit.get("stun_timer", 0.0)), duration)
			logs.append("过载脉冲：基地周边敌人眩晕，核心受损 1。")
			_spawn_radio_wave(BASE_POSITION, Color(1.0, 0.86, 0.24, 0.90), 330)
			_start_screen_shake(0.18, 6.0)
	_refresh_ui(true)
	return true

func _radio_cost(action: Dictionary) -> int:
	var cost := int(action.get("battery_cost", 1))
	for facility in facilities:
		if str(facility.get("type", "")) == "relay" and bool(facility.get("alive", false)):
			var def: Dictionary = facility_defs.get("relay", {})
			var bonus := def.get("radio_bonus", {}) as Dictionary
			cost -= int(bonus.get("cost_reduction", 0))
	return max(1, cost)

func _radio_duration(action: Dictionary) -> float:
	var duration := float(action.get("duration", 0.0))
	for facility in facilities:
		if str(facility.get("type", "")) == "relay" and bool(facility.get("alive", false)):
			var def: Dictionary = facility_defs.get("relay", {})
			var bonus := def.get("radio_bonus", {}) as Dictionary
			duration += float(bonus.get("duration_bonus", 0.0))
	return duration

func _check_terminal_state() -> void:
	if base_hp <= 0:
		_finish_campaign(false)
		return
	var all_done := true
	for task in spawn_tasks:
		if not bool(task.get("done", false)):
			all_done = false
			break
	if all_done and active_units.is_empty():
		_finish_night()

func _finish_night() -> void:
	phase = "report"
	_apply_resource_delta(_current_night().get("win_reward", {}) as Dictionary)
	logs.append("第 %d 夜结束：广播仍在继续。" % (current_day_index + 1))
	if current_day_index >= campaign_defs.size() - 1:
		_finish_campaign(true)
	else:
		_show_result_panel("夜晚守住", "获得奖励，明天继续扫描频段。\n信任 %d  废料 %d  电池 %d" % [int(resources["trust"]), int(resources["scrap"]), int(resources["battery"])])
		_refresh_ui(true)

func _continue_from_report() -> void:
	if phase != "report":
		return
	_clear_night_units()
	result_panel.visible = false
	_enter_day(current_day_index + 1)

func _finish_campaign(won: bool) -> void:
	game_over = true
	phase = "final"
	outcome = "胜利" if won else "失败"
	_show_result_panel("三夜广播完成" if won else "电台失守", "击倒 %d  救援 %d  回收废料 %d\n信任 %d  基地生命 %d/%d\n电台技能使用 %d 次" % [
		killed_total,
		rescued_total,
		salvaged_total,
		int(resources.get("trust", 0)),
		base_hp,
		MAX_BASE_HP,
		radio_actions_used
	])
	_refresh_ui(true)

func _clear_night_units() -> void:
	for unit in active_units:
		if is_instance_valid(unit.get("follow")):
			(unit["follow"] as Node).queue_free()
	active_units.clear()
	spawn_tasks.clear()
	for child in effect_layer.get_children():
		child.queue_free()

func _refresh_ui(rebuild_actions: bool) -> void:
	_update_status_text()
	_update_objective_text()
	_update_signal_box()
	_update_build_buttons()
	_update_build_markers()
	_update_radio_box()
	_update_wave_preview()
	_update_route_visuals()
	if rebuild_actions:
		_rebuild_action_box()
	start_button.visible = phase in ["day", "prep"]
	start_button.disabled = phase != "prep"
	continue_button.visible = phase == "report"
	if log_title_label != null:
		log_title_label.visible = phase != "night"
	if log_body != null:
		log_body.visible = phase != "night"
	log_body.text = "\n".join(logs.slice(max(0, logs.size() - 14), logs.size()))

func _update_status_text() -> void:
	var night := _current_night()
	resource_label.text = "第 %d/%d 夜  基地 %d/%d\n废料 %d  电池 %d  燃料 %d\n电力 %d/%d  信任 %d  暴露 %d  单位 %d" % [
		current_day_index + 1,
		max(1, campaign_defs.size()),
		base_hp,
		MAX_BASE_HP,
		int(resources.get("scrap", 0)),
		int(resources.get("battery", 0)),
		int(resources.get("fuel", 0)),
		_power_used(),
		int(resources.get("power", 0)),
		int(resources.get("trust", 0)),
		int(resources.get("threat", 0)),
		active_units.size()
	]
	match phase:
		"day":
			status_label.text = "%s：选择一个信号决定今晚的风险和收益。" % str(night.get("title", "白天"))
		"prep":
			status_label.text = "准备阶段：建造防线，然后开始夜晚。已锁定「%s」。" % str(selected_signal.get("title", "未知信号"))
		"night":
			status_label.text = "夜晚 %.1fs：用干扰、诱导、安抚广播和过载脉冲改变战场。" % night_elapsed
		"report":
			status_label.text = "夜间报告：守住了这一夜，可以进入下一天。"
		"final":
			status_label.text = "战役结算：%s。" % outcome

func _update_objective_text() -> void:
	if objective_label == null:
		return
	match phase:
		"day":
			objective_label.text = "战术目标：从 3 个信号中选 1 个。高收益信号会改变今晚波次。"
		"prep":
			var turret_ready := _has_facility_type("turret")
			var block_ready := _has_facility_type("barricade") or _has_facility_type("decoy")
			objective_label.text = "布防目标：%s 火力  %s 拦截\n建议：先守下一波路线，再留废料升级。" % [
				"OK" if turret_ready else "待建",
				"OK" if block_ready else "待建"
			]
		"night":
			var next_route := _next_pressure_route()
			var tip := "调频到%s，用干扰拖慢下一波。" % _route_name(next_route) if next_route != "" and tuned_route != next_route else "击杀回收废料，选择设施可升级或维修。"
			if int(resources.get("battery", 0)) < 1:
				tip = "电池耗尽：靠炮塔和路障撑住，优先升级火力。"
			objective_label.text = "战斗目标：守住广播，救到幸存者。\n%s" % tip
		"report":
			objective_label.text = "报告：用回收废料升级防线，下一夜压力会更高。"
		"final":
			objective_label.text = "结算：击杀、救援、信任和基地生命决定 demo 表现。"
		_:
			objective_label.text = ""

func _update_signal_box() -> void:
	for child in signal_box.get_children():
		child.queue_free()
	if phase != "day":
		var summary := Label.new()
		summary.text = "已锁定：%s" % str(selected_signal.get("title", "未选择"))
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary.add_theme_font_size_override("font_size", 12)
		summary.add_theme_color_override("font_color", Color(0.72, 0.90, 0.88))
		summary.custom_minimum_size = Vector2(0, 26)
		signal_box.add_child(summary)
		return
	var choices: Array = _current_night().get("signal_choices", []) as Array
	for signal_entry in choices:
		var data := signal_entry as Dictionary
		var button := Button.new()
		button.text = "%s\n%s" % [str(data.get("title", "")), str(data.get("raw", ""))]
		button.custom_minimum_size = Vector2(0, 50)
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = phase != "day"
		var signal_id := str(data.get("id", ""))
		button.pressed.connect(func() -> void: _select_signal(signal_id))
		signal_box.add_child(button)

func _update_build_buttons() -> void:
	for point_id in build_buttons.keys():
		var button := build_buttons[point_id] as Button
		var point: Dictionary = build_points[point_id]
		var facility: Variant = _facility_at_point(str(point_id))
		button.disabled = phase not in ["prep", "night"] or phase == "final"
		if facility == null:
			button.tooltip_text = "%s：空建造点" % str(point.get("name", point_id))
		else:
			button.tooltip_text = "%s：%s HP %d/%d" % [
				str(point.get("name", point_id)),
				_facility_name(str(facility.get("type", ""))),
				int(facility.get("hp", 0)),
				int(facility.get("max_hp", 0))
			]

func _update_build_markers() -> void:
	for point_id in build_marker_nodes.keys():
		var marker := build_marker_nodes[point_id] as Node2D
		var facility: Variant = _facility_at_point(str(point_id))
		if str(point_id) == selected_build_point:
			marker.modulate = Color(1.0, 1.0, 1.0, 1.0)
			marker.scale = Vector2(1.12, 1.12)
		elif facility == null:
			marker.modulate = Color(0.75, 0.95, 1.0, 0.72)
			marker.scale = Vector2.ONE
		else:
			marker.modulate = Color(0.75, 0.95, 1.0, 0.24)
			marker.scale = Vector2.ONE

func _update_radio_box() -> void:
	for child in radio_box.get_children():
		child.queue_free()
	_add_radio_scope(radio_box)
	var tune_label := Label.new()
	tune_label.text = "当前频段：%s" % _route_name(tuned_route)
	tune_label.add_theme_font_size_override("font_size", 12)
	tune_label.add_theme_color_override("font_color", Color(0.82, 0.96, 0.96))
	radio_box.add_child(tune_label)
	var route_buttons := HBoxContainer.new()
	route_buttons.add_theme_constant_override("separation", 4)
	for route_id in ["north_bridge", "south_gate", "service_tunnel"]:
		var tune := Button.new()
		tune.text = _route_short_name(route_id)
		tune.custom_minimum_size = Vector2(0, 25)
		tune.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tune.disabled = phase not in ["prep", "night"]
		if route_id == tuned_route:
			tune.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36))
		var captured_route := str(route_id)
		tune.pressed.connect(func() -> void: _tune_route(captured_route))
		route_buttons.add_child(tune)
	radio_box.add_child(route_buttons)
	for action_id in ["jam", "reroute", "soothe", "overload"]:
		var action: Dictionary = radio_action_defs.get(action_id, {})
		var button := Button.new()
		var cost := _radio_cost(action)
		button.text = "%s  %s  电池 %d" % [str(action.get("name", action_id)), _radio_action_short(action_id), cost]
		button.custom_minimum_size = Vector2(0, 26)
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = phase != "night" or radio_cooldown > 0.0 or int(resources.get("battery", 0)) < cost
		button.tooltip_text = _radio_action_detail(action_id, cost)
		var captured_id := str(action_id)
		button.pressed.connect(func() -> void: _use_radio_action(captured_id))
		radio_box.add_child(button)
	var cd := Label.new()
	cd.text = "共享冷却：%.1fs" % radio_cooldown
	cd.add_theme_font_size_override("font_size", 11)
	cd.add_theme_color_override("font_color", Color(0.70, 0.88, 0.88))
	radio_box.add_child(cd)

func _add_radio_scope(parent: VBoxContainer) -> void:
	var scope := VBoxContainer.new()
	scope.add_theme_constant_override("separation", 3)
	parent.add_child(scope)
	var label := Label.new()
	label.text = "SIGNAL SCOPE"
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.35, 0.92, 0.96, 0.82))
	scope.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	scope.add_child(row)
	var pressure_route := _next_pressure_route()
	for i in range(16):
		var bar := ColorRect.new()
		var tuned_boost := 8.0 if tuned_route == _scope_route_for_index(i) else 0.0
		var pressure_boost := 9.0 if pressure_route == _scope_route_for_index(i) else 0.0
		var height: float = 6.0 + abs(sin(night_elapsed * 2.4 + float(i) * 0.73)) * 13.0 + tuned_boost * 0.5 + pressure_boost * 0.5
		bar.custom_minimum_size = Vector2(9, height)
		bar.color = Color(0.23, 0.95, 1.0, 0.88) if tuned_boost > 0.0 else Color(0.35, 0.72, 0.64, 0.58)
		if pressure_boost > 0.0:
			bar.color = Color(1.0, 0.36, 0.18, 0.88)
		row.add_child(bar)

func _scope_route_for_index(index: int) -> String:
	if index < 5:
		return "north_bridge"
	if index < 11:
		return "south_gate"
	return "service_tunnel"

func _radio_action_short(action_id: String) -> String:
	match action_id:
		"jam":
			return "减速55%"
		"reroute":
			return "改道+暴露"
		"soothe":
			return "救援+引怪"
		"overload":
			return "眩晕/自损"
		_:
			return ""

func _radio_action_detail(action_id: String, cost: int) -> String:
	match action_id:
		"jam":
			return "消耗 %d 电池：当前频段敌人减速，适合处理下一波压力路线。" % cost
		"reroute":
			return "消耗 %d 电池：把下一组感染者诱导到其他路线，暴露度 +1。" % cost
		"soothe":
			return "消耗 %d 电池：召来幸存者队伍，信任收益高，但额外吸引感染者。" % cost
		"overload":
			return "消耗 %d 电池：基地周边敌人眩晕，基地生命 -1。" % cost
		_:
			return ""

func _update_wave_preview() -> void:
	if wave_label == null:
		return
	if phase != "night":
		wave_label.text = "波次预告：开夜后显示下一组敌人。"
		return
	var next_task: Variant = null
	var best_time := INF
	for task in spawn_tasks:
		if bool(task.get("done", false)):
			continue
		var next_time := float(task.get("next_time", 0.0))
		if next_time < best_time:
			best_time = next_time
			next_task = task
	if next_task == null:
		wave_label.text = "波次预告：剩余敌人清理中。"
		return
	var seconds: float = max(0.0, best_time - night_elapsed)
	wave_label.text = "下一波：%.1fs 后 %s x%d\n路线：%s" % [
		seconds,
		_unit_name(str(next_task.get("unit", ""))),
		max(0, int(next_task.get("count", 0)) - int(next_task.get("spawned", 0))),
		_route_name(str(next_task.get("route", "")))
	]

func _next_pressure_route() -> String:
	if phase != "night":
		return ""
	var best_time := INF
	var route_id := ""
	for task in spawn_tasks:
		if bool(task.get("done", false)):
			continue
		var next_time := float(task.get("next_time", 0.0))
		if next_time < best_time:
			best_time = next_time
			route_id = str(task.get("route", ""))
	return route_id

func _update_route_visuals() -> void:
	var pressure_route := _next_pressure_route()
	for route_id in route_signal_lines.keys():
		var route_signal := route_signal_lines[route_id] as Line2D
		var warning := route_warning_lines.get(route_id, null) as Line2D
		var jammed := float(route_jams.get(route_id, 0.0)) > 0.0
		var tuned := str(route_id) == tuned_route
		var alpha := 0.52
		if tuned:
			alpha = 1.0
		elif jammed:
			alpha = 0.86
		route_signal.default_color = Color(0.45, 0.96, 1.0, alpha) if jammed else _route_color(str(route_id), alpha)
		route_signal.width = 6.0 if tuned or jammed else 3.0
		if warning != null:
			var pulse: float = 0.35 + 0.35 * abs(sin(night_elapsed * 4.2))
			warning.default_color = Color(1.0, 0.18, 0.10, pulse) if str(route_id) == pressure_route else Color(1.0, 0.18, 0.10, 0.0)

func _rebuild_action_box() -> void:
	for child in action_box.get_children():
		child.queue_free()
	if selected_build_point == "" or not build_points.has(selected_build_point):
		action_title.text = "防线操作"
		_add_action_hint("选择建造点。白天布防，夜晚可用燃料紧急补点。")
		return
	var point: Dictionary = build_points[selected_build_point]
	action_title.text = str(point.get("name", selected_build_point))
	var facility: Variant = _facility_at_point(selected_build_point)
	if facility != null:
		_add_action_hint("%s：HP %d/%d" % [_facility_name(str(facility.get("type", ""))), int(facility.get("hp", 0)), int(facility.get("max_hp", 0))])
		_add_action_hint("等级：Lv.%d / 3" % int(facility.get("level", 1)))
		if phase in ["prep", "night"] and bool(facility.get("alive", false)):
			var upgrade_cost := facility_defs.get(str(facility.get("type", "")), {}).get("upgrade_cost", {}) as Dictionary
			var upgrade := Button.new()
			upgrade.text = "升级  废料 %d" % int(upgrade_cost.get("scrap", 0))
			upgrade.custom_minimum_size = Vector2(0, 28)
			upgrade.disabled = int(facility.get("level", 1)) >= 3 or not _can_afford_cost(upgrade_cost)
			upgrade.pressed.connect(_upgrade_selected_facility)
			action_box.add_child(upgrade)
			var repair := Button.new()
			repair.text = "维修  废料 1"
			repair.custom_minimum_size = Vector2(0, 28)
			repair.disabled = int(resources.get("scrap", 0)) <= 0
			repair.pressed.connect(_repair_selected_facility)
			action_box.add_child(repair)
		return
	if phase not in ["prep", "night"]:
		_add_action_hint("当前阶段不能建造。")
		return
	var allowed: Array = point.get("allowed", []) as Array
	for facility_id in allowed:
		var def: Dictionary = facility_defs.get(str(facility_id), {})
		var button := Button.new()
		var cost := def.get("cost", {}) as Dictionary
		button.text = "%s%s  废料 %d%s" % [
			"紧急建造" if phase == "night" else "建造",
			_facility_name(str(facility_id)),
			int(cost.get("scrap", 0)),
			" / 燃料 1" if phase == "night" else ""
		]
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = not _can_start_facility(def)
		var captured_id := str(facility_id)
		button.pressed.connect(func() -> void: _build_facility(selected_build_point, captured_id))
		action_box.add_child(button)

func _add_action_hint(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.82, 0.92, 0.88))
	action_box.add_child(label)

func _show_result_panel(title: String, body: String) -> void:
	result_panel.visible = true
	result_panel.modulate = Color(1, 1, 1, 0)
	result_title.text = title
	result_body.text = body
	var tween := create_tween()
	tween.tween_property(result_panel, "modulate:a", 1.0, 0.18)

func _apply_resource_delta(delta: Dictionary) -> void:
	for key in delta.keys():
		var id := str(key)
		resources[id] = max(0, int(resources.get(id, 0)) + int(delta[key]))

func _pay_cost(cost: Dictionary) -> bool:
	for key in cost.keys():
		if int(resources.get(str(key), 0)) < int(cost[key]):
			return false
	for key in cost.keys():
		resources[str(key)] = int(resources.get(str(key), 0)) - int(cost[key])
	return true

func _can_afford_cost(cost: Dictionary) -> bool:
	for key in cost.keys():
		if int(resources.get(str(key), 0)) < int(cost[key]):
			return false
	return true

func _has_power_for(def: Dictionary) -> bool:
	return _power_used() + int(def.get("power", 0)) <= int(resources.get("power", 0))

func _can_start_facility(def: Dictionary) -> bool:
	if not _can_afford_cost(def.get("cost", {}) as Dictionary):
		return false
	if not _has_power_for(def):
		return false
	if phase == "night" and int(resources.get("fuel", 0)) <= 0:
		return false
	return true

func _power_used() -> int:
	var total := 0
	for facility in facilities:
		if bool(facility.get("alive", false)):
			total += int(facility_defs.get(str(facility.get("type", "")), {}).get("power", 0))
	return total

func _has_facility_type(facility_id: String) -> bool:
	for facility in facilities:
		if str(facility.get("type", "")) == facility_id and bool(facility.get("alive", false)):
			return true
	return false

func _facility_at_point(point_id: String) -> Variant:
	for facility in facilities:
		if str(facility.get("point_id", "")) == point_id:
			return facility
	return null

func _signal_survivor_route() -> String:
	if selected_signal.is_empty():
		return "south_gate"
	var effects := selected_signal.get("effects", {}) as Dictionary
	return str(effects.get("survivor_route", "south_gate"))

func _route_with_most_enemies() -> String:
	var counts := {}
	for route_id in route_points.keys():
		counts[route_id] = 0
	for unit in active_units:
		if bool(unit.get("is_survivor", false)):
			continue
		var route_id := str(unit.get("route", "north_bridge"))
		counts[route_id] = int(counts.get(route_id, 0)) + 1
	var best := "north_bridge"
	for route_id in counts.keys():
		if int(counts[route_id]) > int(counts[best]):
			best = str(route_id)
	return best

func _route_with_fewest_enemies() -> String:
	var counts := {}
	for route_id in route_points.keys():
		counts[route_id] = 0
	for unit in active_units:
		var route_id := str(unit.get("route", "north_bridge"))
		counts[route_id] = int(counts.get(route_id, 0)) + 1
	var best := "north_bridge"
	for route_id in counts.keys():
		if int(counts[route_id]) < int(counts[best]):
			best = str(route_id)
	return best

func _alternate_route(route_id: String) -> String:
	match route_id:
		"north_bridge":
			return "south_gate"
		"south_gate":
			return "service_tunnel"
		_:
			return "north_bridge"

func _route_midpoint(route_id: String) -> Vector2:
	var points: Array = route_points.get(route_id, [BASE_POSITION])
	return points[int(points.size() / 2)]

func _route_name(route_id: String) -> String:
	match route_id:
		"north_bridge":
			return "北桥"
		"south_gate":
			return "南门"
		"service_tunnel":
			return "维修通道"
		_:
			return route_id

func _route_short_name(route_id: String) -> String:
	match route_id:
		"north_bridge":
			return "北桥"
		"south_gate":
			return "南门"
		"service_tunnel":
			return "维修"
		_:
			return route_id

func _route_color(route_id: String, alpha: float) -> Color:
	match route_id:
		"north_bridge":
			return Color(1.0, 0.70, 0.26, alpha)
		"south_gate":
			return Color(0.40, 0.92, 0.78, alpha)
		"service_tunnel":
			return Color(0.70, 0.58, 1.0, alpha)
		_:
			return Color.WHITE

func _unit_color(unit_id: String) -> Color:
	match unit_id:
		"infected":
			return Color(0.94, 0.16, 0.10, 1.0)
		"runner":
			return Color(1.0, 0.52, 0.12, 1.0)
		"howler":
			return Color(1.0, 0.78, 0.18, 1.0)
		"armored":
			return Color(0.62, 0.50, 0.46, 1.0)
		"survivor_group":
			return Color(0.40, 1.0, 0.76, 1.0)
		_:
			return Color.WHITE

func _facility_name(facility_id: String) -> String:
	return str(facility_defs.get(facility_id, {}).get("name", facility_id))

func _unit_name(unit_id: String) -> String:
	return str(unit_defs.get(unit_id, {}).get("name", unit_id))

func _toggle_pause() -> void:
	set_process(not is_processing())

func _spawn_shot_line(from_pos: Vector2, to_pos: Vector2) -> void:
	var line := Line2D.new()
	line.points = PackedVector2Array([from_pos, to_pos])
	line.width = 3
	line.default_color = Color(1.0, 0.82, 0.24, 0.95)
	effect_layer.add_child(line)
	var tween := create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.16)
	tween.tween_callback(Callable(line, "queue_free"))

func _spawn_hit_burst(position: Vector2, color: Color) -> void:
	var ring := _create_circle_line(12, color, 2)
	ring.position = position
	effect_layer.add_child(ring)
	var tween := create_tween()
	tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.20)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.20)
	tween.tween_callback(Callable(ring, "queue_free"))

func _spawn_radio_wave(position: Vector2, color: Color, radius: float) -> void:
	for i in range(3):
		var ring := _create_circle_line(28, color, 3)
		ring.position = position
		ring.scale = Vector2(0.3, 0.3)
		effect_layer.add_child(ring)
		var tween := create_tween()
		if i > 0:
			tween.tween_interval(0.09 * float(i))
		tween.tween_property(ring, "scale", Vector2.ONE * (radius / 28.0), 0.65)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.65)
		tween.tween_callback(Callable(ring, "queue_free"))

func _spawn_base_alarm(amount: int) -> void:
	_spawn_radio_wave(BASE_POSITION, Color(1.0, 0.18, 0.12, 0.88), 150 + amount * 30)
	_start_screen_shake(0.22, 7.0 + float(amount) * 2.0)

func _spawn_float_text(text: String, position: Vector2, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	effect_layer.add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", position + Vector2(0, -26), 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(Callable(label, "queue_free"))

func _add_visual_line(parent: Node, points: Array, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	var packed: Array[Vector2] = []
	for point in points:
		packed.append(point as Vector2)
	line.points = PackedVector2Array(packed)
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(line)
	return line

func _flash_node(node: CanvasItem, color: Color, duration: float) -> void:
	if node == null:
		return
	node.modulate = color
	var tween := create_tween()
	tween.tween_property(node, "modulate", Color.WHITE, duration)

func _start_screen_shake(duration: float, strength: float) -> void:
	shake_duration = max(shake_duration, duration)
	shake_timer = max(shake_timer, duration)
	shake_strength = max(shake_strength, strength)

func _update_screen_shake(delta: float) -> void:
	if map_layer == null:
		return
	if shake_timer <= 0.0:
		map_layer.position = Vector2.ZERO
		shake_duration = 0.0
		shake_strength = 0.0
		return
	shake_timer = max(0.0, shake_timer - delta)
	var ratio: float = shake_timer / max(0.01, shake_duration)
	map_layer.position = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength)) * ratio

func _create_circle_line(radius: float, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.points = _circle_points(radius, 48)
	line.width = width
	line.default_color = color
	return line

func _create_shadow(position: Vector2, radius: float, alpha: float) -> Polygon2D:
	var shadow := Polygon2D.new()
	shadow.position = position
	shadow.polygon = _circle_points(radius, 28)
	shadow.scale = Vector2(1.0, 0.34)
	shadow.color = Color(0.0, 0.0, 0.0, alpha)
	shadow.z_index = -1
	return shadow

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points: Array[Vector2] = []
	for i in range(segments + 1):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return PackedVector2Array(points)

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)
