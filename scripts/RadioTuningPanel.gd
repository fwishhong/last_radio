extends PanelContainer

signal signal_locked(signal_id: String)
signal signal_forced_locked(signal_id: String)
signal signal_target_requested(location_id: String)
signal signal_marked(signal_id: String, mark_id: String)
signal signal_refined(signal_id: String)
signal signal_confirm_requested(signal_id: String)

var signals: Array[Dictionary] = []
var locked_ids: Array[String] = []
var signal_marks: Dictionary = {}
var signal_confirmations: Dictionary = {}
var resources: Dictionary = {}
var listen_time := 3
var selected_signal_id := ""
var spectrum: SpectrumBand
var selected_signal_image: TextureRect

class SpectrumBand:
	extends Control

	var controller: PanelContainer
	var sweep := 0.0

	func _process(delta: float) -> void:
		sweep = fposmod(sweep + delta * 0.18, 1.0)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if controller == null:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			controller.call("_select_signal_by_ratio", clamp(event.position.x / max(1.0, size.x), 0.0, 1.0))

	func _draw() -> void:
		if controller == null:
			return
		var rect := get_rect()
		var base_y := rect.size.y * 0.60
		draw_rect(Rect2(Vector2.ZERO, rect.size), Color(0.015, 0.026, 0.028, 0.96), true)
		for i in range(18):
			var x := rect.size.x * float(i) / 17.0
			var alpha := 0.18 if i % 3 == 0 else 0.08
			draw_line(Vector2(x, 10), Vector2(x, rect.size.y - 14), Color(0.45, 0.85, 0.92, alpha), 1.0)
		draw_line(Vector2(0, base_y), Vector2(rect.size.x, base_y), Color(0.46, 0.92, 1.0, 0.36), 2.0)

		var day_signals: Array = controller.get("signals")
		var locked: Array = controller.get("locked_ids")
		var selected := str(controller.get("selected_signal_id"))
		var story_focus := bool(controller.call("_story_focus_active"))
		for index in range(day_signals.size()):
			var signal_data: Dictionary = day_signals[index]
			var id := str(signal_data.get("id", ""))
			var x := _signal_x(index, signal_data, rect.size.x)
			var noise := float(signal_data.get("noise", 0))
			var height: float = 22.0 + (100.0 - min(85.0, noise)) * 0.54
			var is_selected := id == selected
			var is_locked := locked.has(id)
			var urgency := int(signal_data.get("urgency", 1))
			if story_focus and not bool(controller.call("_uses_story_tuning", signal_data)):
				var noise_color := Color(0.25, 0.38, 0.40, 0.42)
				draw_line(Vector2(x, base_y), Vector2(x, base_y - 38.0), noise_color, 2.0)
				draw_circle(Vector2(x, base_y - 38.0), 4.0, noise_color)
				continue
			var color := Color(0.50, 1.0, 0.72, 0.95) if is_locked else (Color(1.0, 0.82, 0.36, 1.0) if is_selected else _urgency_color(urgency))
			draw_line(Vector2(x, base_y), Vector2(x, base_y - height), color, 5.0 if is_selected else 3.0)
			draw_circle(Vector2(x, base_y - height), 7.0 if is_selected else 5.0, color)
			if urgency >= 4 and not is_locked:
				draw_circle(Vector2(x, base_y - height), 12.0, Color(color.r, color.g, color.b, 0.18))
			var caption := "北桥" if story_focus and bool(controller.call("_uses_story_tuning", signal_data)) else "%.1f" % _signal_freq(index, signal_data)
			draw_string(get_theme_default_font(), Vector2(x - 26, base_y + 20), caption, HORIZONTAL_ALIGNMENT_CENTER, 56, 12, Color(0.82, 0.92, 0.90, 0.85))

		var sweep_x := rect.size.x * sweep
		draw_line(Vector2(sweep_x, 8), Vector2(sweep_x, rect.size.y - 10), Color(0.80, 1.0, 0.92, 0.44), 2.0)

	func _signal_x(index: int, signal_data: Dictionary, width: float) -> float:
		var count: int = max(1, (controller.get("signals") as Array).size())
		var base := (float(index) + 0.5) / float(count)
		var offset := (float(int(signal_data.get("noise", 0)) % 17) - 8.0) / 140.0
		return clamp((base + offset) * width, 24.0, width - 24.0)

	func _signal_freq(index: int, signal_data: Dictionary) -> float:
		return 88.0 + float(index) * 5.7 + float(int(signal_data.get("noise", 0)) % 13) * 0.11

	func _urgency_color(urgency: int) -> Color:
		if urgency >= 5:
			return Color(1.0, 0.36, 0.28, 0.92)
		if urgency >= 4:
			return Color(1.0, 0.66, 0.30, 0.86)
		if urgency >= 3:
			return Color(0.82, 0.86, 0.50, 0.80)
		return Color(0.42, 0.82, 0.90, 0.72)

func setup(day_signals: Array[Dictionary], new_locked_ids: Array[String], new_listen_time: int, new_resources: Dictionary = {}, new_signal_marks: Dictionary = {}, new_signal_confirmations: Dictionary = {}) -> void:
	signals = day_signals
	locked_ids = new_locked_ids
	signal_marks = new_signal_marks
	signal_confirmations = new_signal_confirmations
	listen_time = new_listen_time
	resources = new_resources
	if _story_focus_active():
		selected_signal_id = _story_focus_signal_id()
	if selected_signal_id == "" or _signal_by_id(selected_signal_id).is_empty():
		selected_signal_id = str(signals[0].get("id", "")) if not signals.is_empty() else ""
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		child.queue_free()
	add_theme_stylebox_override("panel", _panel_style(Color(0.022, 0.037, 0.040, 0.97), Color(0.28, 0.62, 0.70, 0.88)))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	root.add_child(top)

	var title := Label.new()
	title.text = "监听台"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	top.add_child(title)

	var time := Label.new()
	time.text = "先听北桥" if _story_focus_active() else "剩余监听 %d" % listen_time
	time.add_theme_font_size_override("font_size", 17)
	time.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	top.add_child(time)

	spectrum = SpectrumBand.new()
	spectrum.controller = self
	spectrum.custom_minimum_size = Vector2(0, 168)
	spectrum.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(spectrum)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 0)
	left.add_theme_constant_override("separation", 7)
	body.add_child(left)
	_build_frequency_buttons(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_build_selected_monitor(right)

func _build_frequency_buttons(root: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "频点"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(label)

	for index in range(signals.size()):
		var signal_data := signals[index]
		var id := str(signal_data.get("id", ""))
		var locked := locked_ids.has(id)
		var urgency := int(signal_data.get("urgency", 1))
		var button := Button.new()
		if _story_focus_active() and not _uses_story_tuning(signal_data):
			button.text = "%s 背景噪声" % ("●" if id == selected_signal_id else "○")
			button.disabled = true
			button.custom_minimum_size = Vector2(0, 38)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			root.add_child(button)
			continue
		if _uses_story_tuning(signal_data):
			button.text = "%s %s%s" % [
				"●" if id == selected_signal_id else "○",
				str(signal_data.get("title", "信号")),
				"  已听清" if locked else ""
			]
		else:
			button.text = "%s %.1f  急%d  噪%d%s" % [
				"●" if id == selected_signal_id else "○",
				88.0 + float(index) * 5.7 + float(int(signal_data.get("noise", 0)) % 13) * 0.11,
				urgency,
				int(signal_data.get("noise", 0)),
				"  已锁" if locked else ""
			]
		button.toggle_mode = true
		button.button_pressed = id == selected_signal_id
		button.custom_minimum_size = Vector2(0, 38)
		button.pressed.connect(func() -> void:
			selected_signal_id = id
			_rebuild()
		)
		root.add_child(button)

func _build_selected_monitor(root: VBoxContainer) -> void:
	var signal_data := _signal_by_id(selected_signal_id)
	if signal_data.is_empty():
		var empty := Label.new()
		empty.text = "今天没有可监听频点。"
		empty.add_theme_color_override("font_color", Color(0.84, 0.94, 0.90))
		root.add_child(empty)
		return

	var id := str(signal_data.get("id", ""))
	var locked := locked_ids.has(id)

	var title := Label.new()
	title.text = "%s%s" % [str(signal_data.get("title", "")), "  / 已锁定" if locked else ""]
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.70, 0.96, 1.0) if locked else Color(0.92, 0.86, 0.68))
	root.add_child(title)

	if _uses_story_tuning(signal_data):
		_build_story_evidence(root, id, signal_data, locked)
		_build_signal_actions(root, id, signal_data, locked)
		_add_signal_image(root, signal_data)
		var story_text := Label.new()
		story_text.text = str(signal_data.get("full" if locked else "raw", ""))
		story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		story_text.add_theme_font_size_override("font_size", 15)
		story_text.add_theme_color_override("font_color", Color(0.84, 0.94, 0.90))
		root.add_child(story_text)
		return
	else:
		var meta := Label.new()
		meta.text = "急 %s%d  噪声 %d  监听 %d  可信度 %s  强锁 -1电 +1暴" % [
			str(signal_data.get("urgency_label", "")),
			int(signal_data.get("urgency", 1)),
			int(signal_data.get("noise", 0)),
			int(signal_data.get("listen_cost", 1)),
			str(signal_data.get("confidence", "unknown"))
		]
		meta.add_theme_font_size_override("font_size", 13)
		meta.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
		root.add_child(meta)

	_add_signal_image(root, signal_data)

	if int(signal_data.get("refined_count", 0)) > 0:
		var tuned := Label.new()
		tuned.text = "校准：已精听 %d 次，噪声下降，派遣预测更稳定。" % int(signal_data.get("refined_count", 0))
		tuned.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tuned.add_theme_font_size_override("font_size", 13)
		tuned.add_theme_color_override("font_color", Color(0.50, 1.0, 0.72))
		root.add_child(tuned)

	_build_signal_actions(root, id, signal_data, locked)

	var text := Label.new()
	text.text = str(signal_data.get("full" if locked else "raw", ""))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 15)
	text.add_theme_color_override("font_color", Color(0.84, 0.94, 0.90))
	root.add_child(text)

	if not _uses_story_tuning(signal_data):
		var consequence := Label.new()
		consequence.text = str(signal_data.get("ignore_preview", "忽视：暂无直接损失。"))
		consequence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		consequence.add_theme_font_size_override("font_size", 13)
		consequence.add_theme_color_override("font_color", Color(1.0, 0.74, 0.38) if int(signal_data.get("urgency", 1)) >= 4 else Color(0.74, 0.88, 0.82))
		root.add_child(consequence)

	var mark_line := Label.new()
	mark_line.text = _mark_preview_text(signal_data)
	mark_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mark_line.add_theme_font_size_override("font_size", 13)
	mark_line.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62))
	root.add_child(mark_line)

	var marks := HBoxContainer.new()
	marks.add_theme_constant_override("separation", 6)
	root.add_child(marks)
	_add_mark_button(marks, id, "trusted", "可信")
	_add_mark_button(marks, id, "suspect", "可疑")
	_add_mark_button(marks, id, "decoy", "诱饵")

	var tape := ColorRect.new()
	tape.custom_minimum_size = Vector2(0, 22)
	tape.color = Color(0.10, 0.24, 0.25, 0.72) if locked else Color(0.18, 0.14, 0.07, 0.72)
	root.add_child(tape)

func _add_signal_image(root: VBoxContainer, signal_data: Dictionary) -> void:
	var frame := Control.new()
	frame.clip_contents = true
	frame.custom_minimum_size = Vector2(0, 104)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	selected_signal_image = TextureRect.new()
	selected_signal_image.name = "SelectedSignalImage"
	selected_signal_image.texture = _load_texture(str(signal_data.get("image", "")))
	selected_signal_image.custom_minimum_size = Vector2(0, 104)
	selected_signal_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_signal_image.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	selected_signal_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_signal_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if selected_signal_image.texture != null:
		frame.add_child(selected_signal_image)
		selected_signal_image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(frame)

func _build_story_evidence(root: VBoxContainer, signal_id: String, signal_data: Dictionary, locked: bool) -> void:
	var intro := Label.new()
	intro.text = str(signal_data.get("story_intro", "这段信号需要先听清。"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 14)
	intro.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	root.add_child(intro)

	var evidence := Label.new()
	evidence.text = "已听清线索：%s" % str(signal_data.get("full" if locked else "raw", ""))
	evidence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence.add_theme_font_size_override("font_size", 13)
	evidence.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	root.add_child(evidence)

	var confirm: Dictionary = signal_data.get("call_confirm", {})
	if confirm.is_empty():
		return
	if _signal_confirmed(signal_id):
		var response := Label.new()
		response.text = "呼叫确认：%s" % str(confirm.get("response", "对方给出了回应。"))
		response.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		response.add_theme_font_size_override("font_size", 14)
		response.add_theme_color_override("font_color", Color(0.50, 1.0, 0.72))
		root.add_child(response)
		return
	var call_button := Button.new()
	call_button.text = "呼叫确认：%s" % str(confirm.get("question", "请求对方确认身份。"))
	call_button.custom_minimum_size = Vector2(0, 40)
	call_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_button.disabled = not locked
	call_button.pressed.connect(func() -> void:
		signal_confirm_requested.emit(signal_id)
	)
	root.add_child(call_button)

func _build_signal_actions(root: VBoxContainer, signal_id: String, signal_data: Dictionary, locked: bool) -> void:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)

	var lock_button := Button.new()
	lock_button.text = "听清这段求救" if _uses_story_tuning(signal_data) and not locked else ("已经听清" if _uses_story_tuning(signal_data) else ("监听锁定" if not locked else "频点已锁定"))
	lock_button.custom_minimum_size = Vector2(0, 42)
	lock_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_button.disabled = locked or int(signal_data.get("listen_cost", 1)) > listen_time
	lock_button.pressed.connect(func() -> void:
		signal_locked.emit(signal_id)
	)
	actions.add_child(lock_button)

	if _uses_story_tuning(signal_data):
		var target_button := Button.new()
		target_button.text = "去派遣外勤"
		target_button.custom_minimum_size = Vector2(0, 42)
		target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_button.disabled = not locked
		target_button.pressed.connect(func() -> void:
			signal_target_requested.emit(str(signal_data.get("location", "")))
		)
		actions.add_child(target_button)
		return

	var refine_button := Button.new()
	refine_button.text = "精听\n噪-15"
	refine_button.custom_minimum_size = Vector2(86, 42)
	refine_button.disabled = locked or listen_time <= 0 or int(signal_data.get("refined_count", 0)) >= 2
	refine_button.pressed.connect(func() -> void:
		signal_refined.emit(signal_id)
	)
	actions.add_child(refine_button)

	var force_button := Button.new()
	force_button.text = "强锁"
	force_button.custom_minimum_size = Vector2(82, 42)
	force_button.disabled = locked or int(resources.get("power", 0)) <= 0
	force_button.pressed.connect(func() -> void:
		signal_forced_locked.emit(signal_id)
	)
	actions.add_child(force_button)

	var target_button := Button.new()
	target_button.text = "设为目标"
	target_button.custom_minimum_size = Vector2(0, 42)
	target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_button.disabled = not locked
	target_button.pressed.connect(func() -> void:
		signal_target_requested.emit(str(signal_data.get("location", "")))
	)
	actions.add_child(target_button)

func _add_mark_button(root: HBoxContainer, signal_id: String, mark_id: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_pressed = str(signal_marks.get(signal_id, "")) == mark_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 32)
	button.pressed.connect(func() -> void:
		_mark_signal(signal_id, mark_id)
	)
	root.add_child(button)

func _mark_signal(signal_id: String, mark_id: String) -> void:
	var current := str(signal_marks.get(signal_id, ""))
	if current == mark_id:
		signal_marks.erase(signal_id)
		signal_marked.emit(signal_id, "")
	else:
		signal_marks[signal_id] = mark_id
		signal_marked.emit(signal_id, mark_id)
	_rebuild()

func _mark_preview_text(signal_data: Dictionary) -> String:
	var mark := str(signal_marks.get(str(signal_data.get("id", "")), ""))
	if mark == "":
		return "判断：未标记。标记会进入派遣准备值，押错也会扣分。"
	var score := int(signal_data.get("mark_score", 0))
	var label := _mark_label(mark)
	if score > 0:
		return "判断：%s  准备 %+d。%s" % [label, score, _mark_reason(signal_data, mark)]
	if score < 0:
		return "判断：%s  准备 %d。%s" % [label, score, _mark_reason(signal_data, mark)]
	return "判断：%s  暂无加成。%s" % [label, _mark_reason(signal_data, mark)]

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

func _mark_reason(signal_data: Dictionary, mark_id: String) -> String:
	var confidence := str(signal_data.get("confidence", "unknown"))
	var noise := int(signal_data.get("noise", 0))
	match mark_id:
		"trusted":
			return "来源 %s，噪声 %d。" % [confidence, noise]
		"suspect":
			return "低可信或高噪声更适合保守处理。"
		"decoy":
			return "若它确实像诱饵，外勤会更谨慎；若是真求救，会误伤准备。"
	return ""

func _uses_story_tuning(signal_data: Dictionary) -> bool:
	return int(signal_data.get("day", 0)) == 1 and str(signal_data.get("story_intro", "")) != ""

func _story_focus_active() -> bool:
	return _story_focus_signal_id() != ""

func _story_focus_signal_id() -> String:
	for signal_data in signals:
		if _uses_story_tuning(signal_data):
			return str(signal_data.get("id", ""))
	return ""

func _signal_confirmed(signal_id: String) -> bool:
	return signal_confirmations.has(signal_id)

func _select_signal_by_ratio(ratio: float) -> void:
	if signals.is_empty():
		return
	if _story_focus_active():
		selected_signal_id = _story_focus_signal_id()
		_rebuild()
		return
	var best_index := 0
	var best_distance := 999.0
	for index in range(signals.size()):
		var signal_data := signals[index]
		var position := (float(index) + 0.5) / float(signals.size())
		position += (float(int(signal_data.get("noise", 0)) % 17) - 8.0) / 140.0
		var distance: float = abs(position - ratio)
		if distance < best_distance:
			best_distance = distance
			best_index = index
	selected_signal_id = str(signals[best_index].get("id", ""))
	_rebuild()

func _signal_by_id(signal_id: String) -> Dictionary:
	for signal_data in signals:
		if str(signal_data.get("id", "")) == signal_id:
			return signal_data
	return {}

func _urgency_color(urgency: int) -> Color:
	if urgency >= 5:
		return Color(1.0, 0.36, 0.28, 0.92)
	if urgency >= 4:
		return Color(1.0, 0.66, 0.30, 0.86)
	if urgency >= 3:
		return Color(0.82, 0.86, 0.50, 0.80)
	return Color(0.42, 0.82, 0.90, 0.72)

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
