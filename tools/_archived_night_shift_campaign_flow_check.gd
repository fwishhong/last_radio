extends SceneTree
# ARCHIVED — v0.5-era campaign flow check using the old _debug_* API
# (current_level / outcome / result_text / night_schedule). Replaced by
# tools/night_shift_full_flow_test.gd which drives the current 10-night
# campaign via the public API.

func _initialize() -> void:
	print("SKIP: _archived_night_shift_campaign_flow_check.gd — see night_shift_full_flow_test.gd")
	quit(0)