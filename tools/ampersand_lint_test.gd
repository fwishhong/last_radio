extends SceneTree
# Ampersand lint — fails if any .gd file under res://scripts/ or res://tools/
# contains the double-ampersand logical-AND operator.
#
# Last Radio v2 style uses the GDScript keyword `and` for logical AND. A
# double ampersand is a tell-tale sign someone copy-pasted C/JS bitwise or
# logical AND into a .gd by accident (in GDScript the operator is accepted
# but the project chose the keyword exclusively). This test is the regression
# gate — keeps the codebase consistent without code review.
#
# Scope: res://scripts/ + res://tools/, all .gd files (recursive).
# Expected baseline: zero hits. Verified 2026-06-21.
#
# If you legitimately need the operator, add a per-file allow-list with a
# justification comment rather than disabling this lint.
#
# NB: this lint scans itself. We construct the forbidden substring at
# runtime so the test's own source does not contain it as a literal.

const SCAN_DIRS := ["res://scripts/", "res://tools/"]

var passed: int = 0
var failed: int = 0
var hits: Array = []


func _initialize() -> void:
	_run()


func _assert(cond: bool, name: String) -> void:
	if cond:
		print("  ok: %s" % name)
		passed += 1
	else:
		print("  FAIL: %s" % name)
		failed += 1


func _walk_gd_files(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path + f)
	for d in dir.get_directories():
		out.append_array(_walk_gd_files(dir_path + d + "/"))
	return out


func _run() -> void:
	# Build the forbidden substring at runtime so this lint's own source
	# does not contain it as a literal token.
	var forbidden: String = "&" + "&"
	print("=== Ampersand lint ===")
	for d in SCAN_DIRS:
		var files := _walk_gd_files(d)
		for f in files:
			var content := FileAccess.get_file_as_string(f)
			var idx := content.find(forbidden)
			if idx >= 0:
				var line_no := content.substr(0, idx).count("\n") + 1
				hits.append("%s:%d" % [f, line_no])
				print("  HIT: %s line %d contains double ampersand" % [f, line_no])
	_assert(hits.is_empty(), "no double-ampersand in %s" % str(SCAN_DIRS))

	if failed > 0:
		print("Hits (%d):" % hits.size())
		for h in hits:
			print("  %s" % h)

	print("Ampersand lint: %s (passed=%d, failed=%d)" % [
		"PASS" if failed == 0 else "FAIL", passed, failed
	])
	quit(0 if failed == 0 else 1)