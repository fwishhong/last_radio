extends SceneTree
# Regression test for the v0.6 member-glyph UI swap.
#
# User directive: "在 UI 界面,角色不要露出来" (in the UI, characters
# should not be visible). The old behavior loaded portrait textures
# from data/v2_members.json (which references survivor_*.png files
# that don't ship in the repo) and fell back to portrait_player/nora/
# elias.png in BaseScreen._resolve_closeup_portrait(). That whole
# portrait pipeline is gone — UI now shows a colored letter badge
# derived from member["name"] (first char) and member["role"]
# (keyword → color).
#
# This test verifies that:
# 1. _resolve_member_glyph returns a non-null dict for each of the 4
#    v2_members.json members.
# 2. The letter is the uppercase first char of the member's name.
# 3. The color matches the role keyword map (warm yellow / red /
#    blue-gray / green / neutral gray).
# 4. A member with a broken "portrait" path still produces a valid
#    glyph (no crash, no portrait load).
# 5. A member with an empty "role" falls back to neutral gray.
# 6. Tree walk: BaseScreen's member_box contains exactly 4 glyph
#    badges (PanelContainer with a centered Label).
# 7. Empty / invalid member dict → glyph returns "?" and gray color
#    without crashing.

const BaseScreenScript := preload("res://scripts/BaseScreen.gd")
var badge_count: int = 0
var letter_count: int = 0
var last_known_letter := ""
var last_known_color := Color(0, 0, 0)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: PackedScene = load("res://scenes/BaseScreen.tscn") as PackedScene
	var g := scene.instantiate()
	root.add_child(g)
	for i in 4: await process_frame

	var members_data: Array = g._load_json_array(g.MEMBERS_PATH) as Array
	if members_data.is_empty():
		print("FAIL: no members loaded from %s" % g.MEMBERS_PATH)
		quit(1); return
	print("ok: loaded %d members from %s" % [members_data.size(), g.MEMBERS_PATH])

	# Expected per-member: (name initial, role keyword → expected color).
	var expected: Array = [
		{"idx": 0, "letter": "E", "role": "Radio Technician", "color": Color(1.0, 0.84, 0.45)},
		{"idx": 1, "letter": "M", "role": "Field Medic", "color": Color(0.85, 0.40, 0.40)},
		{"idx": 2, "letter": "V", "role": "Quartermaster", "color": Color(0.45, 0.55, 0.70)},
		{"idx": 3, "letter": "N", "role": "Pathfinder Mechanic", "color": Color(0.40, 0.70, 0.55)},
	]

	for case in expected:
		var ci: int = (case as Dictionary)["idx"]
		var member: Dictionary = members_data[ci]
		var name: String = str(member.get("name", "?"))
		var glyph = g._resolve_member_glyph(member)
		if typeof(glyph) != TYPE_DICTIONARY or glyph.is_empty():
			print("FAIL: %s -> glyph is not a non-empty dict" % name)
			quit(1); return
		var letter: String = str(glyph.get("letter", ""))
		var want_letter: String = str((case as Dictionary)["letter"])
		if letter != want_letter:
			print("FAIL: %s -> letter %s, expected %s" % [name, letter, want_letter])
			quit(1); return
		var color: Color = glyph.get("color", Color(0, 0, 0))
		var want_color: Color = (case as Dictionary)["color"]
		if not _color_close(color, want_color, 0.01):
			print("FAIL: %s -> color %s, expected %s" % [name, color, want_color])
			quit(1); return
		print("ok: %s -> %s on %s" % [name, letter, want_color])

	# Synthetic member with broken "portrait" path must not crash and
	# must still produce a usable glyph (the role drives the color).
	var broken: Dictionary = {
		"id": "broken_path_member",
		"name": "Random NPC 9",
		"role": "Field Medic",
		"portrait": "res://assets/nonexistent/missing.png",
	}
	var broken_glyph = g._resolve_member_glyph(broken)
	if typeof(broken_glyph) != TYPE_DICTIONARY or str(broken_glyph.get("letter", "")) != "R":
		print("FAIL: broken-path member should still resolve letter 'R', got %s" % broken_glyph)
		quit(1); return
	if not _color_close(broken_glyph.get("color", Color.BLACK), Color(0.85, 0.40, 0.40), 0.01):
		print("FAIL: broken-path member color should be red, got %s" % broken_glyph.get("color"))
		quit(1); return
	print("ok: broken-portrait-path member still resolves glyph (letter + role color)")

	# Empty role → neutral gray fallback.
	var empty_role: Dictionary = {
		"id": "unknown",
		"name": "Mystery Person",
		"role": "",
		"portrait": "",
	}
	var empty_glyph = g._resolve_member_glyph(empty_role)
	if str(empty_glyph.get("letter", "")) != "M":
		print("FAIL: empty-role member letter should be 'M', got %s" % empty_glyph.get("letter"))
		quit(1); return
	if not _color_close(empty_glyph.get("color", Color.BLACK), Color(0.55, 0.55, 0.55), 0.01):
		print("FAIL: empty-role member color should be neutral gray, got %s" % empty_glyph.get("color"))
		quit(1); return
	print("ok: empty-role member falls back to neutral gray")

	# Empty / invalid member dict → "?" letter, neutral gray, no crash.
	var invalid_member: Dictionary = {}
	var invalid_glyph = g._resolve_member_glyph(invalid_member)
	if str(invalid_glyph.get("letter", "")) != "?":
		print("FAIL: invalid member letter should be '?', got %s" % invalid_glyph.get("letter"))
		quit(1); return
	if not _color_close(invalid_glyph.get("color", Color.BLACK), Color(0.55, 0.55, 0.55), 0.01):
		print("FAIL: invalid member color should be neutral gray, got %s" % invalid_glyph.get("color"))
		quit(1); return
	print("ok: empty member dict resolves to '?' and neutral gray without crashing")

	# Tree walk: member_box must contain exactly 4 glyph badges.
	# A glyph badge is a PanelContainer with a single Label child.
	var member_box: Node = g.member_box
	if member_box == null:
		print("FAIL: member_box not found on BaseScreen")
		quit(1); return
	badge_count = 0
	letter_count = 0
	last_known_letter = ""
	last_known_color = Color(0, 0, 0)
	_walk_badges(member_box)
	if badge_count != 4:
		print("FAIL: expected exactly 4 glyph badges in member_box, found %d" % badge_count)
		quit(1); return
	if letter_count != 4:
		print("FAIL: expected 4 labels inside glyph badges, found %d" % letter_count)
		quit(1); return
	print("ok: member_box tree walk found %d glyph badges (4 expected) with %d labels" % [badge_count, letter_count])

	# Verify the rendered badge for one of the slots is a proper
	# PanelContainer (not a TextureRect) and has the expected letter.
	var first_badge = _first_badge(member_box)
	if first_badge == null:
		print("FAIL: could not locate first glyph badge in member_box")
		quit(1); return
	if not (first_badge is PanelContainer):
		print("FAIL: first badge should be PanelContainer, got %s" % first_badge.get_class())
		quit(1); return
	var first_label = _label_in(first_badge)
	if first_label == null or not (first_label is Label):
		print("FAIL: first badge should contain a Label child")
		quit(1); return
	if str(first_label.text).length() != 1:
		print("FAIL: first badge label should be a single letter, got '%s'" % str(first_label.text))
		quit(1); return
	print("ok: first badge is PanelContainer with single-letter Label (%s)" % str(first_label.text))

	print("Member glyph test: PASS")
	quit(0)


func _color_close(a: Color, b: Color, tolerance: float) -> bool:
	return absf(a.r - b.r) <= tolerance and absf(a.g - b.g) <= tolerance and absf(a.b - b.b) <= tolerance


# Recursive walker: counts PanelContainer badges that have exactly one
# Label child (the glyph definition). Skips any non-glyph panel.
func _walk_badges(node: Node) -> void:
	if node is PanelContainer:
		var panel: PanelContainer = node
		var labels: Array = []
		for child in panel.get_children():
			if child is Label:
				labels.append(child)
		# A glyph badge is a small (≤50px) panel with a single label.
		if labels.size() == 1 and panel.custom_minimum_size.x <= 50.0 and panel.custom_minimum_size.x >= 20.0:
			badge_count += 1
			var lbl: Label = labels[0]
			letter_count += 1
			last_known_letter = str(lbl.text)
	for child in node.get_children():
		_walk_badges(child)


func _first_badge(node: Node) -> Node:
	if node is PanelContainer:
		var panel: PanelContainer = node
		var labels: Array = []
		for child in panel.get_children():
			if child is Label:
				labels.append(child)
		if labels.size() == 1 and panel.custom_minimum_size.x <= 50.0 and panel.custom_minimum_size.x >= 20.0:
			return panel
	for child in node.get_children():
		var found = _first_badge(child)
		if found != null:
			return found
	return null


func _label_in(panel: Node) -> Label:
	for child in panel.get_children():
		if child is Label:
			return child
	return null
