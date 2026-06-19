extends SceneTree
# ARCHIVED — v0.5-era audio probe calling _debug_get_audio_state,
# _debug_choose_day, _enter_day, etc. Those helpers were removed in the
# single-script rewrite. The current SFX + music loading is covered by
# tools/sfx_test.gd and tools/radio_contact_test.gd (SFX triggers).

func _initialize() -> void:
	print("SKIP: _archived_night_shift_audio_probe.gd — superseded by sfx_test.gd")
	quit(0)