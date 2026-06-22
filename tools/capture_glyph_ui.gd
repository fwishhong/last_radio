extends SceneTree
# Visual proof for the v0.6 member-glyph UI swap.
#
# Renders two screenshots that show every UI member is now a colored
# letter badge instead of a portrait texture:
#   1) screenshots/art_audit/glyph_base.png  — BaseScreen with the
#      4 member rows on the left panel (E / M / V / N in role colors).
#   2) screenshots/art_audit/glyph_dispatch.png — DispatchPanel with
#      the 4 member pool cards (each showing its own glyph badge).
#
# These complement the existing capture_base_board.gd /
# capture_dispatch_board.gd scripts, which still capture the full
# screens. This script is a focused proof shot for the UI directive
# "在 UI 界面,角色不要露出来" (no character portraits in UI).

const ART_AUDIT_DIR := "user://screenshots/art_audit"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_ensure_dir(ART_AUDIT_DIR)
	await _capture_base()
	await _capture_dispatch()
	quit(0)

func _ensure_dir(path: String) -> void:
	var global_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(global_path)

func _capture_base() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var host := Control.new()
	host.size = Vector2(1280, 720)
	viewport.add_child(host)

	var clear := ColorRect.new()
	clear.color = Color(0.010, 0.018, 0.018, 1.0)
	clear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(clear)

	var scene: PackedScene = load("res://scenes/BaseScreen.tscn") as PackedScene
	var screen: Node = scene.instantiate()
	host.add_child(screen)
	if screen is Control:
		(screen as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	await process_frame
	if screen.has_method("_dismiss_intro_briefing"):
		screen.call("_dismiss_intro_briefing")
	await process_frame
	# Force a day-2 state so the member chip layout is fully populated
	# (the story-day-1 resource_box still shows the brief, but
	# member_box is rebuilt identically every day).
	screen.call("_start_day", 2)
	await process_frame
	await process_frame

	var texture := viewport.get_texture()
	if texture == null:
		push_error("glyph_base capture: viewport texture unavailable")
		viewport.queue_free()
		return
	var image := texture.get_image()
	if image == null:
		push_error("glyph_base capture: viewport image unavailable")
		viewport.queue_free()
		return
	var out_path := ProjectSettings.globalize_path(ART_AUDIT_DIR + "/glyph_base.png")
	image.save_png(out_path)
	print("glyph_base: %s" % out_path)
	viewport.queue_free()
	await process_frame

func _capture_dispatch() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var host := Control.new()
	host.size = Vector2(1280, 720)
	viewport.add_child(host)

	var clear := ColorRect.new()
	clear.color = Color(0.010, 0.018, 0.018, 1.0)
	clear.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(clear)

	# Mount the DispatchPanel directly so the four member pool cards
	# are the focus of the screenshot. We seed enough state to populate
	# the panel via its setup() entry point.
	var scene: PackedScene = load("res://scenes/DispatchPanel.tscn") as PackedScene
	var panel: Node = scene.instantiate()
	host.add_child(panel)
	if panel is Control:
		(panel as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Load members + items + a non-story location so the panel renders
	# the full member pool (not the story advisor step).
	var members_data: Array = _read_json("res://data/v2_members.json")
	var items_data: Array = _read_json("res://data/v2_items.json")
	var members: Dictionary = _array_to_dict(members_data)
	var items: Dictionary = _array_to_dict(items_data)
	var location: Dictionary = {
		"id": "north_bridge",
		"name": "北桥居民楼",
		"day": 2,
		"signal_image": "",
		"risk": 40,
		"people_left": 0,
		"supplies_left": 0,
		"danger_trend": 0,
		"mission_tags": ["rescue"],
		"signal_reward": {"rescued": 2},
		"signal_failure": {"trust": -1}
	}
	panel.call("setup", members, items, location, false, Callable(), {})
	await process_frame
	await process_frame
	# Select two members so the dispatch slot row also shows badges.
	panel.call("_toggle_member", "a_qing")
	panel.call("_toggle_member", "xu_lan")
	panel.call("_toggle_item", "medkit")
	await process_frame
	await process_frame

	var texture := viewport.get_texture()
	if texture == null:
		push_error("glyph_dispatch capture: viewport texture unavailable")
		viewport.queue_free()
		return
	var image := texture.get_image()
	if image == null:
		push_error("glyph_dispatch capture: viewport image unavailable")
		viewport.queue_free()
		return
	var out_path := ProjectSettings.globalize_path(ART_AUDIT_DIR + "/glyph_dispatch.png")
	image.save_png(out_path)
	print("glyph_dispatch: %s" % out_path)
	viewport.queue_free()


func _read_json(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		return []
	return parsed


func _array_to_dict(entries: Array) -> Dictionary:
	var result := {}
	for entry in entries:
		var data := entry as Dictionary
		result[str(data.get("id", ""))] = data
	return result
