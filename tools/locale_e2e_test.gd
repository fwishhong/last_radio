extends SceneTree
# Verifies that the actual game reads localized strings.
# Walks through Cover -> Day -> Night -> Report and checks the
# on-screen labels reflect the active locale.

const I18n := preload("res://scripts/I18n.gd")
const NightShiftData := preload("res://scripts/NightShiftData.gd")
const NightShiftLevels := preload("res://scripts/NightShiftLevels.gd")
const NightShiftSave := preload("res://scripts/NightShiftSave.gd")
const NightShiftGame := preload("res://scripts/NightShiftGame.gd")
const Settings := preload("res://scripts/Settings.gd")

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
	print("=== Locale E2E test ===")

	# Clean any leftover save + settings so Cover is fresh and locale is default.
	NightShiftSave.clear_save()
	Settings.reset_all()

	# 1) i18n + data load
	I18n.load_all()
	_assert(I18n.dicts.has("zh"), "zh loaded")
	_assert(I18n.dicts.has("en"), "en loaded")
	var data := NightShiftData.new()
	data.load_all()
	_assert(data.get_resource("planks").has("name_en"), "planks has name_en")
	_assert(data.get_resource("planks")["name_en"] == "Planks", "planks.name_en is Planks")
	_assert(data.get_resource("exposure")["name_en"] == "Exposure", "exposure.name_en is Exposure")

	# 2) All 10 levels have *_en fields
	for i in range(NightShiftLevels.LEVELS.size()):
		var level: Dictionary = NightShiftLevels.LEVELS[i]
		_assert(level.has("title_en"), "level %d has title_en" % i)
		_assert(level.has("briefing_en"), "level %d has briefing_en" % i)
		_assert(level.has("night_goal_en"), "level %d has night_goal_en" % i)
		_assert(level.has("success_report_en"), "level %d has success_report_en" % i)
		_assert(level.has("failure_report_en"), "level %d has failure_report_en" % i)
		_assert(level.has("story_intro_en"), "level %d has story_intro_en" % i)
		_assert(level.has("story_start_en") and (level["story_start_en"] as Array).size() > 0,
			"level %d has non-empty story_start_en" % i)
		var beats: Array = level.get("story_beats", [])
		_assert(beats.size() == 3, "level %d story_beats size = 3" % i)
		for b in beats:
			_assert((b as Dictionary).has("text_en"),
				"level %d beat has text_en" % i)

	# 3) t_field on a level returns the right language
	var level0: Dictionary = NightShiftLevels.LEVELS[0]
	I18n.locale = "zh"
	_assert(I18n.t_field(level0, "title") == "第一夜：三盏灯", "zh title correct")
	I18n.locale = "en"
	_assert(I18n.t_field(level0, "title") == "Night 1: Three Lights", "en title correct")
	_assert(I18n.t_field(level0, "night_goal") == "Only hold the front door, the left window, and the generator. Learn to move, repair, and judge priorities.",
		"en night_goal correct")

	# 4) Resources localize too
	I18n.locale = "zh"
	_assert(I18n.t_field(data.get_resource("battery"), "name") == "电池", "zh battery name")
	I18n.locale = "en"
	_assert(I18n.t_field(data.get_resource("battery"), "name") == "Battery", "en battery name")

	# 5) Day card body localizes. M14 (2026-06-25) rewrote the v0.5 short
	#    third-person descriptions ("Front door holds longer before
	#    breaking.") into first-person narrator monologues, so the
	#    golden strings here are the M14 versions.
	var card: Dictionary = data.get_card("door_reinforce")
	I18n.locale = "zh"
	_assert(I18n.t_field(card, "name") == "加固正门", "zh door_reinforce name")
	_assert(
		I18n.t_field(card, "body") == "正门在夜风里吱呀了一整晚。这块木板我多盯一眼吧。破门之前多争几秒，Nora 也好喘口气。",
		"zh door_reinforce body (M14 monologue)"
	)
	I18n.locale = "en"
	_assert(I18n.t_field(card, "name") == "Reinforce Front Door", "en door_reinforce name")
	_assert(
		I18n.t_field(card, "body") == "That front door has been groaning all night. One more plank here buys us a few extra seconds before it gives. Nora can use the breath.",
		"en door_reinforce body (M14 monologue)"
	)

	# 6) Game scene loads and reflects locale
	# We don't drive inputs here — we just verify that the cover screen
	# reads the active locale when it builds its labels. The simpler way to
	# check this in a headless SceneTree is to instantiate the script
	# directly (not the scene) and call _build_ui + _show_cover.
	I18n.locale = "zh"
	var g: Node = NightShiftGame.new()
	root.add_child(g)
	# _ready may not have run yet in headless; force the build path so
	# status_label etc. are populated.
	if g.status_label == null:
		g._build_ui()
	g._show_cover()
	_assert(g.status_label != null, "status_label exists after _show_cover")
	if g.status_label != null:
		_assert(g.status_label.text == "末日电台：旧体育馆守夜",
			"zh cover title: '%s'" % g.status_label.text)
	I18n.locale = "en"
	g._show_cover()
	if g.status_label != null:
		_assert(g.status_label.text == "Last Radio: Old Stadium Watch",
			"en cover title: '%s'" % g.status_label.text)
	I18n.locale = "zh"
	g._show_cover()
	if g.status_label != null:
		_assert(g.status_label.text == "末日电台：旧体育馆守夜",
			"zh cover title after switch: '%s'" % g.status_label.text)
	g.queue_free()

	print("Locale E2E test: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])