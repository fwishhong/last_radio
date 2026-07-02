extends SceneTree
# Capture day picker, night report, final screens with new theme.

func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	_run.call_deferred()

func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game = scene.instantiate()
	vp.add_child(game)
	await process_frame
	await process_frame
	# Day picker (calls _show_day internally; that's the canonical entry)
	if game.has_method("_show_day"):
		game.call("_show_day")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var tex = vp.get_texture()
		var img: Image = tex.get_image()
		img.save_png("C:/Users/Administrator/Desktop/codex/last_radio v2/screenshots/_audit_v2/04_day_picker_v3.png")
		print("saved day_picker")
	# Cover (with footer)
	if game.has_method("_show_slot_picker"):
		game.call("_show_slot_picker")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var tex2 = vp.get_texture()
		var img2: Image = tex2.get_image()
		img2.save_png("C:/Users/Administrator/Desktop/codex/last_radio v2/screenshots/_audit_v2/05_slot_picker_v3.png")
		print("saved slot_picker")
	# Final
	if game.has_method("_show_final"):
		game.call("_show_final")
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var tex3 = vp.get_texture()
		var img3: Image = tex3.get_image()
		img3.save_png("C:/Users/Administrator/Desktop/codex/last_radio v2/screenshots/_audit_v2/06_final_v3.png")
		print("saved final")
	quit(0)