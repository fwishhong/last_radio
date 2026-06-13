extends SceneTree

const ACTORS := ["player", "elias", "nora"]
const FRAME_COUNT := 12
const ANIMATION_SPEED := 12.0
const DIRECTIONS := ["down", "right", "left", "up"]

func _init() -> void:
	for actor in ACTORS:
		var frame_dir := "res://assets/final/night_shift/%s_walk/" % actor
		var resource_path := frame_dir + "%s_walk_frames.res" % actor
		var sprite_frames := SpriteFrames.new()
		if sprite_frames.has_animation("default"):
			sprite_frames.remove_animation("default")
		for direction in DIRECTIONS:
			var animation_name: StringName = "walk_" + direction
			sprite_frames.add_animation(animation_name)
			sprite_frames.set_animation_loop(animation_name, true)
			sprite_frames.set_animation_speed(animation_name, ANIMATION_SPEED)
			for index in range(FRAME_COUNT):
				var path := frame_dir + "%s_%02d.png" % [direction, index]
				var image := Image.load_from_file(ProjectSettings.globalize_path(path))
				if image == null or image.is_empty():
					push_error("Missing walk frame: " + path)
					quit(1)
					return
				sprite_frames.add_frame(animation_name, ImageTexture.create_from_image(image))
		var error := ResourceSaver.save(sprite_frames, resource_path)
		if error != OK:
			push_error("Could not save walk SpriteFrames: %s" % error)
			quit(1)
			return
		print("Saved " + resource_path)
	quit()
