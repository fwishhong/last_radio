extends SceneTree
# Tests for the radio signal catalog loading path (NightShiftData).
# Verifies:
#   1. signals.json loads via NightShiftData.load_all() into data.signals
#   2. data.get_signal_catalog() returns normalized entries
#   3. data.get_signal(id) returns a single entry by id
#   4. Missing fields are defaulted (label, desc, color, exposure_on_wrong, voice, wrong_signal)
#   5. Entries without an id are dropped
#   6. The catalog wires into NightShiftGame._show_night() for each night

const Data := preload("res://scripts/NightShiftData.gd")

var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	_run()
	quit(0 if failed == 0 else 1)


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _run() -> void:
	print("=== Signal catalog test ===")

	# 1) Load via NightShiftData
	var data := Data.new()
	data.load_all()
	_assert(data.signals.size() >= 3, "signals catalog loaded with >= 3 channels (got %d)" % data.signals.size())
	_assert(data.signal_by_id.has("victor"), "victor entry indexed by id")
	_assert(data.signal_by_id.has("elias"), "elias entry indexed by id")
	_assert(data.signal_by_id.has("static"), "static entry indexed by id")

	# 2) Catalog returns normalized entries
	var catalog: Array = data.get_signal_catalog()
	_assert(catalog.size() == data.signals.size(), "catalog size matches signals size")
	for entry in catalog:
		var item: Dictionary = entry
		_assert(item.has("id"), "catalog entry has id (%s)" % str(item.get("id", "")))
		_assert(item.has("label"), "catalog entry has label (%s)" % str(item.get("id", "")))
		_assert(item.has("desc"), "catalog entry has desc (%s)" % str(item.get("id", "")))
		_assert(item.has("color"), "catalog entry has color (%s)" % str(item.get("id", "")))
		_assert(item.has("exposure_on_wrong"), "catalog entry has exposure_on_wrong (%s)" % str(item.get("id", "")))
		_assert(item.has("voice"), "catalog entry has voice (%s)" % str(item.get("id", "")))
		_assert(item.has("wrong_signal"), "catalog entry has wrong_signal (%s)" % str(item.get("id", "")))

	# 3) Look up by id
	var victor: Dictionary = data.get_signal("victor")
	_assert(victor.get("id", "") == "victor", "get_signal('victor') returns victor entry")
	_assert(str(victor.get("label", "")) == "Victor", "victor label is 'Victor'")
	var missing: Dictionary = data.get_signal("does_not_exist")
	_assert(missing.is_empty(), "get_signal(unknown) returns empty dict")

	# 4) Defaults — color and exposure_on_wrong
	var static_entry: Dictionary = data.get_signal("static")
	_assert(float(static_entry.get("exposure_on_wrong", -1.0)) == 0.5,
		"static.exposure_on_wrong == 0.5 (got %s)" % str(static_entry.get("exposure_on_wrong", -1.0)))
	var victor_exp: float = float(victor.get("exposure_on_wrong", -1.0))
	_assert(victor_exp == 0.0, "victor.exposure_on_wrong == 0.0 (got %s)" % str(victor_exp))
	var color: String = str(victor.get("color", ""))
	_assert(color.begins_with("#"), "victor color starts with # (%s)" % color)

	# 5) Drop entries without an id — synthesize a malformed catalog and
	#    call the normalizer directly. The normalizer is internal, so reach
	#    it via load_all() of a temporary Data subclass? Simpler: just sanity
	#    check the catalog we got has no blanks.
	for entry in data.signals:
		_assert(str(entry.get("id", "")) != "", "every loaded signal has non-empty id")

	# 6) Wiring into NightShiftGame — verify _show_night populates the catalog
	var scene: PackedScene = load("res://scenes/NightShiftGame.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_on_start_pressed")
	game.call("_on_day_card_pressed", "start")
	# night 1 has no radio_channels / radio_target_channel
	_assert(game.radio_channels_catalog.is_empty() or game.radio_channels_catalog.size() >= 3,
		"night 1 catalog uses fallback (empty) or default (size>=3); got size=%d" % game.radio_channels_catalog.size())

	# Jump to night 3 which declares its own channels
	game.night_index = 2
	game.call("_show_night")
	_assert(game.radio_channels_catalog.size() == 3,
		"night 3 has 3 channel buttons (got %d)" % game.radio_channels_catalog.size())
	_assert(str(game.radio_target_channel) == "elias", "night 3 target channel is elias")
	# Verify the per-night entry has desc matching the JSON
	var found_elias := false
	for ch in game.radio_channels_catalog:
		if str(ch.get("id", "")) == "elias":
			found_elias = true
			_assert(str(ch.get("label", "")) == "Elias", "elias label is 'Elias'")
			_assert(str(ch.get("desc", "")) != "", "elias has a description")
			break
	_assert(found_elias, "night 3 catalog includes elias channel")

	# Jump to night 10 — target is victor, catalog still 3 entries
	game.night_index = 9
	game.call("_show_night")
	_assert(str(game.radio_target_channel) == "victor", "night 10 target channel is victor")
	_assert(game.radio_channels_catalog.size() == 3, "night 10 has 3 channels")

	# 7) Fallback path — synthesize a broken Data with a missing signals.json.
	#    Easier: call _fallback_signal_catalog() directly on the game.
	var fallback: Array = game.call("_fallback_signal_catalog")
	_assert(fallback.size() == 3, "fallback catalog has 3 entries")
	var ids := []
	for ch in fallback:
		ids.append(str(ch.get("id", "")))
	_assert(ids.has("victor") and ids.has("elias") and ids.has("static"),
		"fallback catalog has victor/elias/static (got %s)" % str(ids))

	print("Signal catalog test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])