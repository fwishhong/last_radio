extends SceneTree


func _initialize() -> void:
	var p := "res://assets/audio/sfx_footstep.mp3"
	print("ResourceLoader.exists: %s" % str(ResourceLoader.exists(p)))
	var s: Resource = load(p)
	print("Loaded: %s, class=%s" % [str(s), s.get_class() if s != null else "<null>"])
	if s is AudioStream:
		var t: float = (s as AudioStream).get_length()
		print("get_length: %.3f sec" % t)
	quit(0)