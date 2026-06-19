extends SceneTree
# ARCHIVED — v0.5-era capture script using the old _debug_* API which has
# since been removed. Superseded by tools/capture_night_shift_screens.gd
# which uses the current public API and saves to user://last_radio_screens/.
# Kept only as reference for what the v0.5 visual review captured.

func _initialize() -> void:
	print("SKIP: _archived_capture_night_shift_gui.gd — see tools/capture_night_shift_screens.gd")
	quit(0)