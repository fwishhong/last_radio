extends SceneTree

const ASSET_DIR := "res://assets/final/night_shift"
const LARGE_FILE_LIMIT := 3_000_000

func _initialize() -> void:
	var dir := DirAccess.open(ASSET_DIR)
	if dir == null:
		push_error("Night shift asset audit: missing directory %s" % ASSET_DIR)
		quit(1)
		return
	var warnings: Array[String] = []
	var entries: Array[String] = []
	for file_name in dir.get_files():
		if not file_name.ends_with(".png"):
			continue
		var path := "%s/%s" % [ASSET_DIR, file_name]
		var image := Image.new()
		var err := image.load(ProjectSettings.globalize_path(path))
		if err != OK:
			warnings.append("%s: failed to load" % file_name)
			continue
		var size := FileAccess.get_file_as_bytes(path).size()
		var alpha_ratio := _alpha_ratio(image)
		var white_ratio := _white_ratio(image)
		entries.append("%s %dx%d bytes=%d alpha=%.2f white=%.2f" % [file_name, image.get_width(), image.get_height(), size, alpha_ratio, white_ratio])
		if size > LARGE_FILE_LIMIT and file_name.begins_with("overlay_"):
			warnings.append("%s: overlay is unexpectedly large" % file_name)
		if file_name.begins_with("overlay_") and alpha_ratio < 0.05:
			warnings.append("%s: overlay has little transparent area" % file_name)
		if file_name.begins_with("antenna_") and image.get_width() != 256:
			warnings.append("%s: antenna state should be 256px wide" % file_name)
		if file_name in ["stadium_room_topdown.png", "stadium_room_day.png", "stadium_room_breached.png", "day_planning_table.png", "night_report_clipboard.png"] and white_ratio > 0.16:
			warnings.append("%s: likely polluted by unrelated bright screenshot content" % file_name)
	print("Night shift asset audit:")
	for entry in entries:
		print("  " + entry)
	if warnings.is_empty():
		print("Night shift asset audit: PASS")
		quit(0)
		return
	for warning in warnings:
		push_warning("Night shift asset audit: " + warning)
	print("Night shift asset audit: WARN %d" % warnings.size())
	quit(0)

func _alpha_ratio(image: Image) -> float:
	if not image.detect_alpha():
		return 0.0
	var transparent := 0
	var total := image.get_width() * image.get_height()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a < 0.98:
				transparent += 1
	return float(transparent) / float(max(total, 1))

func _white_ratio(image: Image) -> float:
	var bright := 0
	var total := image.get_width() * image.get_height()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.1 and pixel.r > 0.86 and pixel.g > 0.86 and pixel.b > 0.82:
				bright += 1
	return float(bright) / float(max(total, 1))
