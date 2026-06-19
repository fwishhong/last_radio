extends SceneTree
# ARCHIVED — v0.5-era DefenseGame GUI capture. The DefenseGame scene is
# kept as a legacy reference (see scenes/DefenseGame.tscn) but its visual
# capture isn't part of the night-shift workflow anymore. The current
# visual capture pipeline is tools/capture_night_shift_screens.gd.

func _initialize() -> void:
	print("SKIP: _archived_capture_defense_gui.gd — DefenseGame is legacy")
	quit(0)