extends SceneTree
# M13.1 capture: render the player_repair_token art (3 frames) so we can
# eyeball the matrix-MCP generated立绘 + alpha restoration. Run with:
#   godot_console.exe --headless --path . --script res://tools/capture_m13_1_player_repair.gd
# Output: user://last_radio_v2_m13_1_capture/  (resolves to
# C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Last Radio v2\last_radio_v2_m13_1_capture\)
#
# Captures:
#   player_repair_art_start.png  (cropped to bounding box)
#   player_repair_art_mid.png
#   player_repair_art_end.png
#   player_repair_grid.png       (3 frames stacked vertically, 60% scale,
#                                 for side-by-side style consistency check)

const ASSET_PATH := "res://assets/final/night_shift/"

func _init() -> void:
	var err := 0
	var ok := 0
	var out_dir := "user://last_radio_v2_m13_1_capture/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var frame_paths := {
		"start": ASSET_PATH + "player_repair_start.png",
		"mid":   ASSET_PATH + "player_repair_mid.png",
		"end":   ASSET_PATH + "player_repair_end.png",
	}

	var frames: Dictionary = {}
	for name in frame_paths.keys():
		var p: String = frame_paths[name]
		if not ResourceLoader.exists(p):
			printerr("FAIL: resource missing %s" % p)
			err += 1
			continue
		var tex: Texture2D = load(p)
		if tex == null:
			printerr("FAIL: load returned null %s" % p)
			err += 1
			continue
		frames[name] = tex
		# Single-frame crop capture
		var img: Image = tex.get_image()
		var bbox := _bbox_of_alpha(img)
		if bbox.size.x <= 0 or bbox.size.y <= 0:
			printerr("FAIL: empty bbox for %s" % p)
			err += 1
			continue
		var cropped: Image = img.get_region(bbox)
		var out_path := out_dir + "player_repair_art_" + str(name) + ".png"
		cropped.save_png(out_path)
		print("  ok: %s -> %s (%dx%d)" % [name, out_path, cropped.get_width(), cropped.get_height()])
		ok += 1

	if frames.size() < 3:
		printerr("FAIL: only %d frames loaded, skipping grid" % frames.size())
		_finish(err, ok)
		return

	# Build the 3-up grid at 60% scale (so ~720px tall total)
	var scale_pct := 0.6
	var single_w: int = (frames["start"] as Texture2D).get_width()
	var single_h: int = (frames["start"] as Texture2D).get_height()
	var grid_w: int = int(single_w * scale_pct)
	var grid_h: int = single_h * 3 * scale_pct
	var grid_img := Image.create(grid_w, grid_h, false, Image.FORMAT_RGBA8)
	grid_img.fill(Color(0, 0, 0, 0))
	for i in 3:
		var frame_order: Array[String] = ["start", "mid", "end"]
		var name: String = frame_order[i]
		var tex: Texture2D = frames[name]
		var img: Image = tex.get_image()
		img.resize(grid_w, int(single_h * scale_pct), Image.INTERPOLATE_BILINEAR)
		grid_img.blit_rect(img, Rect2i(0, 0, grid_w, int(single_h * scale_pct)), Vector2i(0, i * int(single_h * scale_pct)))
	var grid_path := out_dir + "player_repair_grid.png"
	grid_img.save_png(grid_path)
	print("  ok: 3-up grid -> %s (%dx%d)" % [grid_path, grid_w, grid_h])
	ok += 1

	_finish(err, ok)


func _bbox_of_alpha(img: Image) -> Rect2i:
	# Returns the tight bounding box of all non-transparent pixels.
	# Assumes FORMAT_RGBA8. Used to crop the mat-colored checker outside
	# the figure so the captured PNG is small + focused on the player.
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in h:
		for x in w:
			var a: float = img.get_pixel(x, y).a
			if a > 0.05:
				if x < min_x: min_x = x
				if y < min_y: min_y = y
				if x > max_x: max_x = x
				if y > max_y: max_y = y
	if max_x < 0:
		return Rect2i(0, 0, 0, 0)
	# Add 2px padding so the outline isn't clipped.
	var pad := 2
	min_x = max(0, min_x - pad)
	min_y = max(0, min_y - pad)
	max_x = min(w - 1, max_x + pad)
	max_y = min(h - 1, max_y + pad)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _finish(err: int, ok: int) -> void:
	if err == 0:
		print("M13.1 capture: PASS (ok=%d, err=%d)" % [ok, err])
		quit(0)
	else:
		print("M13.1 capture: FAIL (ok=%d, err=%d)" % [ok, err])
		quit(1)