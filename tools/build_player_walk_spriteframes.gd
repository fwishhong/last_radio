extends SceneTree

const FRAME_DIR := "res://assets/final/night_shift/player_walk/"
const RESOURCE_PATH := FRAME_DIR + "player_walk_frames.res"
const DIRECTIONS := ["down", "right", "left", "up"]
const FRAME_COUNT := 12
const ANIMATION_SPEED := 12.0

func _init() -> void:
	var sprite_frames := SpriteFrames.new()
	if sprite_frames.has_animation("default"):
		sprite_frames.remove_animation("default")
	for direction in DIRECTIONS:
		var animation_name: StringName = "walk_" + direction
		sprite_frames.add_animation(animation_name)
		sprite_frames.set_animation_loop(animation_name, true)
		sprite_frames.set_animation_speed(animation_name, ANIMATION_SPEED)
		for index in range(FRAME_COUNT):
			var path := FRAME_DIR + "%s_%02d.png" % [direction, index]
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image == null or image.is_empty():
				push_error("Missing player walk frame: " + path)
				quit(1)
				return
			var texture := ImageTexture.create_from_image(image)
			sprite_frames.add_frame(animation_name, texture)
	var error := ResourceSaver.save(sprite_frames, RESOURCE_PATH)
	if error != OK:
		push_error("Could not save player walk SpriteFrames: %s" % error)
		quit(1)
		return
	print("Saved " + RESOURCE_PATH)
	quit()
