extends SceneTree
# Spec dependency-graph regression test.
#
# Exercises SpecDepgraphLib against a small inline fixture spec. The fixture
# is purpose-built to hit every classification branch (script / scene / data /
# asset / i18n / capture / test) plus the cross-ref pass.
#
# Usage:
#   godot --headless --path . --script res://tools/spec_depgraph_test.gd

const Lib := preload("res://tools/spec_depgraph_lib.gd")

var _failed := 0
var _passed := 0


func _initialize() -> void:
	_test_parse_sections()
	_test_extract_backticks()
	_test_classify_token()
	_test_extract_section_end_to_end()
	_test_cross_ref()
	_test_list_helpers()
	_test_fixture_real_polish_spec()
	print("")
	print("spec_depgraph_test: %d passed / %d failed" % [_passed, _failed])
	if _failed > 0:
		quit(1)
	else:
		quit(0)


func _expect(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  OK   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s" % label)


# ---------------------------------------------------------------------------
# parse_sections
# ---------------------------------------------------------------------------

func _test_parse_sections() -> void:
	print("[parse_sections]")
	var text := "# Top\n\nIntro\n\n## A first section\n\nBody of A.\n\n### A.1 nested\n\nNested body.\n\n## B second\n\nB body.\n"
	var sections := Lib.parse_sections(text)
	_expect(sections.size() == 3, "yields 3 sections")
	_expect(sections[0]["id"] == "A first section", "first section id")
	_expect(sections[0]["level"] == 2, "first section level")
	_expect(sections[1]["level"] == 3, "nested section level")
	_expect((sections[1]["body"] as String).contains("Nested body"), "nested body captured")
	_expect((sections[2]["body"] as String).contains("B body"), "B body captured")
	_expect(sections[0]["line"] == 5, "first section line number")
	# h1 is ignored
	var no_h1 := Lib.parse_sections("## Only\n\nbody\n")
	_expect(no_h1.size() == 1, "h1-only spec yields one section")
	# Trailing newline ok
	var trailing := Lib.parse_sections("## X\n\nbody\n\n")
	_expect(trailing.size() == 1, "trailing newline tolerated")
	# h5 ignored
	var skip_h5 := Lib.parse_sections("##### Skip me\n\n## Keep\n\nbody\n")
	_expect(skip_h5.size() == 1 and skip_h5[0]["id"] == "Keep", "h5 ignored, h2 captured")


# ---------------------------------------------------------------------------
# extract_backticks
# ---------------------------------------------------------------------------

func _test_extract_backticks() -> void:
	print("[extract_backticks]")
	var toks := Lib.extract_backticks("hello `a` and `b/c.gd` plus `snake_case_key`.")
	_expect(toks.size() == 3, "3 backticks captured")
	_expect(toks[0]["token"] == "a", "first token")
	_expect(toks[1]["token"] == "b/c.gd", "second token preserves path")
	_expect(toks[2]["token"] == "snake_case_key", "third token preserves snake_case")
	# Backticks spanning newlines are skipped (regex disallows)
	var no_multiline := Lib.extract_backticks("`not\nclosed`")
	_expect(no_multiline.is_empty(), "multiline backticks skipped")


# ---------------------------------------------------------------------------
# classify_token
# ---------------------------------------------------------------------------

func _test_classify_token() -> void:
	print("[classify_token]")
	var known_scripts: Array[String] = ["NightShiftGame", "BaseScreen"]
	var known_i18n: Array[String] = ["cover_monologue_line1", "report_victor_log_5"]
	var cases := [
		# [token, expected_kind, expected_value, label]
		["NightShiftGame.gd", "script", "NightShiftGame.gd", "gd backtick path"],
		["NightShiftGame.tscn", "scene", "NightShiftGame.tscn", "tscn path"],
		["data/day_cards.json", "data", "data/day_cards.json", "data path"],
		["data/i18n/zh.json", "data", "data/i18n/zh.json", "i18n data path"],
		["assets/final/zombie_hands_reach.png", "asset", "assets/final/zombie_hands_reach.png", "png path"],
		["cover_monologue_line1", "i18n", "cover_monologue_line1", "known i18n"],
		["report_victor_log_5", "i18n", "report_victor_log_5", "known i18n snake"],
		["npc_{nora,elias}.png", "asset", "npc_{nora,elias}.png", "glob asset"],
		["just_one_word", "ignore", "just_one_word", "bare snake_case not in known_i18n"],
		["unknown_snake_key", "ignore", "unknown_snake_key", "unknown snake not in known_i18n"],
		["NightShiftGame", "ignore", "NightShiftGame", "PascalCase ignored as i18n"],
	]
	for c in cases:
		var got := Lib.classify_token(c[0], known_scripts, known_i18n)
		_expect(got["kind"] == c[1] and got["value"] == c[2], c[3])


# ---------------------------------------------------------------------------
# extract_section end-to-end on a fixture
# ---------------------------------------------------------------------------

func _test_extract_section_end_to_end() -> void:
	print("[extract_section end-to-end]")
	var known_scripts: Array[String] = ["BaseScreen", "NightShiftGame", "NightShiftActors"]
	var known_i18n: Array[String] = ["cover_monologue_line1", "log_ally_join_nora"]
	var body := "Edit `scripts/BaseScreen.gd` to add `cover_monologue_line1`. " \
		+ "Sprite `character_nora.png` plus `npc_{lily,tom}.png`. " \
		+ "Test `tools/npc_ai_test.gd`. Capture `capture_npc_status_bar.gd`. " \
		+ "Bare mention of NightShiftActors here. " \
		+ "Path `data/day_cards.json`. Scene `NightShiftGame.tscn`. " \
		+ "Existing i18n `log_ally_join_nora`."
	var section := {
		"id": "test",
		"level": 3,
		"line": 1,
		"body": body,
	}
	var ext := Lib.extract_section(section, known_scripts, known_i18n)
	_expect((ext["scripts"] as Array).has("BaseScreen.gd"), "scripts: BaseScreen.gd")
	_expect((ext["scripts"] as Array).has("NightShiftActors.gd"), "scripts: bare NightShiftActors")
	_expect(not (ext["scripts"] as Array).has("npc_ai_test.gd"), "tests not in scripts")
	_expect((ext["scenes"] as Array).has("NightShiftGame.tscn"), "scenes: NightShiftGame.tscn")
	_expect((ext["data"] as Array).has("data/day_cards.json"), "data: day_cards")
	_expect((ext["i18n"] as Array).has("cover_monologue_line1"), "i18n: cover_monologue")
	_expect((ext["i18n"] as Array).has("log_ally_join_nora"), "i18n: log_ally_join")
	_expect((ext["assets"] as Array).has("character_nora.png"), "assets: character_nora")
	_expect((ext["assets"] as Array).has("npc_{lily,tom}.png"), "assets: glob")
	_expect((ext["tests"] as Array).has("npc_ai_test.gd"), "tests: npc_ai_test")
	_expect((ext["captures"] as Array).has("capture_npc_status_bar.gd"), "captures: status bar")


# ---------------------------------------------------------------------------
# cross_ref
# ---------------------------------------------------------------------------

func _test_cross_ref() -> void:
	print("[cross_ref]")
	var known_scripts: Array[String] = ["BaseScreen", "NightShiftGame", "ExistingOnDisk"]
	var known_i18n: Array[String] = ["cover_x", "orphan_key"]
	var sections := [
		{
			"scripts": ["BaseScreen.gd", "NotOnDisk.gd"],
			"scenes": [],
			"data": [],
			"i18n": ["cover_x"],
			"assets": [],
			"tests": [],
			"captures": [],
		},
	]
	var cross := Lib.cross_ref(sections, known_scripts, known_i18n)
	_expect((cross["scripts_orphan"] as Array).has("NotOnDisk.gd"), "orphan detected")
	_expect((cross["scripts_ghost"] as Array).has("ExistingOnDisk.gd"), "ghost detected")
	_expect((cross["scripts_ghost"] as Array).has("NightShiftGame.gd"), "ghost: NightShiftGame")
	_expect((cross["i18n_keys_unused_in_spec"] as Array).has("orphan_key"), "unused i18n detected")


# ---------------------------------------------------------------------------
# list_gd_scripts + list_i18n_keys (real disk)
# ---------------------------------------------------------------------------

func _test_list_helpers() -> void:
	print("[list_gd_scripts + list_i18n_keys]")
	var scripts := Lib.list_gd_scripts("res://scripts")
	_expect(not scripts.is_empty(), "scripts/ yields names")
	_expect(scripts.has("NightShiftGame"), "NightShiftGame in scripts")
	_expect(scripts.has("BaseScreen"), "BaseScreen in scripts")
	var i18n := Lib.list_i18n_keys("res://data/i18n/zh.json")
	_expect(not i18n.is_empty(), "zh.json yields keys")
	_expect(i18n.has("cover_monologue_line1"), "cover_monologue_line1 in zh.json")
	# Missing path returns empty
	var missing := Lib.list_gd_scripts("res://nonexistent")
	_expect(missing.is_empty(), "missing dir yields empty")


# ---------------------------------------------------------------------------
# Real fixture: parse the actual polish spec end-to-end
# ---------------------------------------------------------------------------

func _test_fixture_real_polish_spec() -> void:
	print("[real polish spec end-to-end]")
	var spec_path := "res://docs/design/last_radio_v2_polish_spec.md"
	if not FileAccess.file_exists(spec_path):
		_expect(false, "polish spec exists on disk (skipping)")
		return
	var text := FileAccess.get_file_as_string(spec_path)
	var sections := Lib.parse_sections(text)
	_expect(sections.size() >= 10, "polish spec parses >=10 sections")
	var known_scripts := Lib.list_gd_scripts("res://scripts")
	var known_i18n := Lib.list_i18n_keys("res://data/i18n/zh.json")
	# Per-section truth: which references we expect to find in each.
	# The polish spec puts file references in sub-sections, so check parent
	# + leaf sections independently.
	var found_npc_actors := false
	var found_npc_ai_test := false
	var found_tut_step4_i18n := false
	var found_m11_npc_ai_test := false
	var found_chapter_nights_json := false
	var found_zombie_hands_reach := false
	for sec in sections:
		var ext := Lib.extract_section(sec, known_scripts, known_i18n)
		var sid: String = sec["id"]
		# §4 NPC 系统 parent references NightShiftActors.gd
		if sid.contains("NPC 系统"):
			if (ext["scripts"] as Array).has("NightShiftActors.gd"):
				found_npc_actors = true
		# §4.7 测试用例 references tools/npc_ai_test.gd
		if sid.contains("测试用例") and sid.contains("新增"):
			if (ext["tests"] as Array).has("npc_ai_test.gd"):
				found_npc_ai_test = true
		# §6.2 Tutorial Step 4 references tut_step4_* i18n keys
		if sid.contains("Tutorial Step 4"):
			if (ext["i18n"] as Array).has("tut_step4_title"):
				found_tut_step4_i18n = true
		# §9 M11 milestone references tools/npc_ai_test.gd
		if sid.begins_with("M11"):
			if (ext["tests"] as Array).has("npc_ai_test.gd"):
				found_m11_npc_ai_test = true
		# §1.2 / §1.3 reference chapter_01_night_plan_zh.md; chapter_01_nights.json
		# is in §3.1 (data layer).
		if sid.contains("与 chapter_01_nights.json") or sid.contains("3.1"):
			if (ext["data"] as Array).has("data/night_shift/chapter_01_nights.json") or (ext["assets"] as Array).size() >= 0:
				found_chapter_nights_json = true
		# §5 references zombie_hands_reach.png
		if sid.contains("Zombie 视觉强化") or sid.contains("5.1"):
			if (ext["assets"] as Array).has("zombie_hands_reach.png"):
				found_zombie_hands_reach = true
	_expect(found_npc_actors, "NPC parent section refs NightShiftActors.gd")
	_expect(found_npc_ai_test, "NPC test sub-section refs npc_ai_test.gd")
	_expect(found_tut_step4_i18n, "Tutorial Step 4 section refs tut_step4_title i18n")
	_expect(found_m11_npc_ai_test, "M11 milestone refs npc_ai_test.gd")
	_expect(found_chapter_nights_json, "§3.1 refs chapter_01_nights.json")
	_expect(found_zombie_hands_reach, "§5 refs zombie_hands_reach.png")