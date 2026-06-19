extends SceneTree

# Capture player sprite in all 4 facings to confirm walk_frames are wired right.
# Output: C:/Users/.../AppData/Roaming/Godot/app_userdata/Last Radio v2/player_facing_*.png

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game = load("res://scenes/NightShiftGame.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.call("_show_night")
	await process_frame
	# Disable hotspot pulsing / anim during capture for clean sprite
	game.set("player_target_id", "")
	game.set("player_pos", Vector2(640, 400))
	game.set("player_is_moving", false)
	game.set("player_walk_frame", 0)

	var save_dir: String = OS.get_user_data_dir()
	for dir_name in ["down", "up", "left", "right"]:
		game.set("player_facing", dir_name)
		game.call("_draw_player")
		await process_frame
		var img: Image = root.get_viewport().get_texture().get_image()
		var crop: Image = img.get_region(Rect2i(540, 300, 200, 200))
		var out_path: String = save_dir + "/player_facing_" + dir_name + ".png"
		crop.save_png(out_path)
		print("saved: " + out_path)
	game.queue_free()
	await process_frame
	quit(0)
