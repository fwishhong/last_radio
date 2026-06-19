extends SceneTree

# Render the night 1 report screen with stats summary.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/NightShiftGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	# Go to night 1, run halfway so the report has realistic stats
	game.call("_show_night")
	await process_frame
	# Damage one hotspot
	var h: Dictionary = (game.get("hotspots") as Dictionary)["left_window"]
	h["value"] = h["max_value"] * 0.4
	h["warning"] = true
	# Trigger end
	game.call("_end_night", true)
	await process_frame
	var save_dir: String = OS.get_user_data_dir()
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(save_dir + "/night_shift_report_n01.png")
	print("saved: " + save_dir + "/night_shift_report_n01.png")
	game.queue_free()
	await process_frame
	quit(0)
