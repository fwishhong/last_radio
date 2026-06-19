extends SceneTree

# Render a complex night (night 4, 6 hotspots) to verify visual scaling.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/NightShiftGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Skip to night 4
	for i in range(3):
		game.call("_show_night")
		await process_frame
		for h in (game.get("hotspots") as Dictionary).values():
			h["value"] = h["max_value"]
		game.set("night_elapsed", game.get("night_duration") + 1.0)
		game.call("_update_night", 0.0)
		await process_frame
		game.call("_end_night", true)
		await process_frame
		game.call("_on_report_continue", true)
		await process_frame
	# Now in night 4
	game.call("_show_night")
	await process_frame
	var save_dir: String = OS.get_user_data_dir()
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(save_dir + "/night_shift_complex_n04.png")
	print("saved: " + save_dir + "/night_shift_complex_n04.png")
	game.queue_free()
	await process_frame
	quit(0)
