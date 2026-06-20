extends SceneTree
# Regression test for the v0.5 portrait_* art integration.
#
# BaseScreen loads member portraits from data/v2_members.json which
# references res://assets/new/named/survivor_*.png files that don't
# ship in the repo. _resolve_closeup_portrait() falls back to the
# 384x384 portrait_{player,nora,elias}.png shipped in
# assets/final/night_shift/ based on member name keywords.
#
# This test verifies that:
# 1. _resolve_closeup_portrait returns a non-null Texture2D for each
#    of the four v2_members.json members.
# 2. The returned texture is the expected PNG (by resource path).
# 3. The fallback chain prefers the data file when it points to a
#    real asset.
# 4. Walking the BaseScreen tree finds the 4 portrait TextureRects
#    and verifies they all have non-null textures.

const BaseScreenScript := preload("res://scripts/BaseScreen.gd")
var portrait_count: int = 0
var null_count: int = 0

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

	var cases: Array = [
		{"idx": 0, "expect_file": "portrait_elias.png"},
		{"idx": 1, "expect_file": "portrait_player.png"},
		{"idx": 2, "expect_file": "portrait_player.png"},
		{"idx": 3, "expect_file": "portrait_nora.png"},
	]

	for case in cases:
		var ci: int = (case as Dictionary)["idx"]
		var member: Dictionary = members_data[ci]
		var name: String = str(member.get("name", "?"))
		var tex: Texture2D = g._resolve_closeup_portrait(member)
		if tex == null:
			print("FAIL: %s -> null portrait" % name)
			quit(1); return
		var path: String = tex.resource_path
		var expect: String = str((case as Dictionary)["expect_file"])
		if not path.ends_with(expect):
			print("FAIL: %s -> %s, expected to end with %s" % [name, path, expect])
			quit(1); return
		var w: int = tex.get_width()
		var h: int = tex.get_height()
		if w != 384 or h != 384:
			print("FAIL: %s texture is %dx%d, expected 384x384" % [name, w, h])
			quit(1); return
		print("ok: %s -> %s (%dx%d)" % [name, expect, w, h])

	# Synthetic member with a valid data portrait should win over fallback.
	var real_portrait_path: String = "res://assets/final/night_shift/portrait_player.png"
	var synthetic: Dictionary = {
		"id": "synthetic_test",
		"name": "Synthetic Test Subject",
		"role": "test",
		"portrait": real_portrait_path,
	}
	var real_tex: Texture2D = g._resolve_closeup_portrait(synthetic)
	if real_tex == null:
		print("FAIL: synthetic member with valid portrait returned null")
		quit(1); return
	if real_tex.resource_path != real_portrait_path:
		print("FAIL: synthetic portrait loaded from %s, expected %s" % [real_tex.resource_path, real_portrait_path])
		quit(1); return
	print("ok: synthetic member with valid portrait uses data file")

	# Random NPC with broken path -> falls back to portrait_player.png
	# (the default-protagonist slot). This is intentional: BaseScreen
	# shows SOMETHING for every roster member rather than leaving the
	# portrait slot empty. The slot won't crash on broken data paths.
	var broken: Dictionary = {
		"id": "broken_path_member",
		"name": "Random NPC 9",
		"role": "filler",
		"portrait": "res://assets/nonexistent/missing.png",
	}
	var fallback_tex: Texture2D = g._resolve_closeup_portrait(broken)
	if fallback_tex == null:
		print("FAIL: random NPC fallback should return portrait_player.png, got null")
		quit(1); return
	if not fallback_tex.resource_path.ends_with("portrait_player.png"):
		print("FAIL: random NPC should fall back to portrait_player.png, got %s" % fallback_tex.resource_path)
		quit(1); return
	print("ok: random NPC with broken path falls back to portrait_player.png")

	# Tree walk: verify the 4 member-panel portrait TextureRects have
	# non-null textures. We narrow to descendants of the member_box
	# (the left-side panel) so the DispatchPanel's broken-data icons
	# don't pollute the result.
	var member_box: Node = g.member_box
	if member_box == null:
		print("FAIL: member_box not found on BaseScreen")
		quit(1); return
	portrait_count = 0
	null_count = 0
	_walk_portraits(member_box)
	print("ok: tree walk found %d TextureRects in member_box" % portrait_count)
	if portrait_count < 4:
		print("FAIL: expected >=4 portrait TextureRects in member_box, found %d" % portrait_count)
		quit(1); return
	if null_count > 0:
		print("FAIL: %d portrait TextureRects in member_box still have null texture" % null_count)
		quit(1); return
	print("ok: %d member_box portrait TextureRects all have non-null textures" % portrait_count)

	print("Portrait swap test: PASS")
	quit(0)


# Recursive walker: counts TextureRects sized for the member panel
# (custom_minimum_size.x <= 40) and how many have null textures.
func _walk_portraits(node: Node) -> void:
	if node is TextureRect:
		var r: TextureRect = node
		if r.custom_minimum_size.x <= 40.0:
			portrait_count += 1
			if r.texture == null:
				null_count += 1
	for child in node.get_children():
		_walk_portraits(child)