extends SceneTree

func _initialize() -> void:
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
	screen.set("pending_crisis", {"id": "gate_probe", "title": "陌生人试探大门", "summary": "暴露度偏高，夜里可能有人摸到基地入口。"})
	var resources: Dictionary = screen.get("resources")
	resources["food"] = 3
	resources["medicine"] = 2
	resources["influence"] = 1
	var members: Dictionary = screen.get("members")
	if members.has("xu_lan"):
		(members["xu_lan"] as Dictionary)["status"] = "injured"
		(members["xu_lan"] as Dictionary)["stress"] = 72
	if members.has("lao_zhou"):
		(members["lao_zhou"] as Dictionary)["stress"] = 84
	screen.call("_set_night_policy", "full_power")
	screen.call("_set_night_watch_member", "shen_luo")
	screen.call("_set_crisis_response", "repair")
	screen.call("_show_step", 3)
	await process_frame
	await process_frame
	await process_frame

	var texture := viewport.get_texture()
	if texture == null:
		push_error("Base board capture failed: viewport texture unavailable.")
		quit(1)
		return
	var image := texture.get_image()
	if image == null:
		push_error("Base board capture failed: viewport image unavailable.")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("user://last_radio_base_board.png")
	image.save_png(path)
	print(path)
	quit(0)
