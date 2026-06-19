extends SceneTree
# Minimal capture - just shows the cover screen.
# This is a regression check: if it times out, something in _ready is broken.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game := scene.instantiate()
	viewport.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)

	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	if img != null:
		img.save_png("user://capture_minimal_cover.png")
		print("saved user://capture_minimal_cover.png")
	else:
		print("ERROR: null image")
	quit(0)
