extends RefCounted
class_name SpecDepgraphLib
# Spec dependency-graph parser library.
#
# Pure helpers used by:
#   - tools/spec_depgraph.gd       (SceneTree entry: parse + report)
#   - tools/spec_depgraph_test.gd  (SceneTree entry: fixture assertions)
#
# Scope:
#   - Split a markdown spec into headered sections.
#   - Extract references by class: scripts / scenes / data / i18n / assets /
#     tests / captures.
#   - Backtick-quoted tokens are the primary signal; bare script basenames
#     (loaded from scripts/ at runtime) are a secondary signal.
#
# No I/O lives here. The main tool wraps the body in I/O.

# ---------------------------------------------------------------------------
# Section parsing
# ---------------------------------------------------------------------------

# Returns Array of Dictionary: { id, level, line, body }
# id    = first 80 chars of header (with leading hashes stripped)
# level = 2 (`##`) / 3 (`###`) / 4 (`####`) — only those are kept
# line  = 1-indexed source line of header start
# body  = full markdown between this header and the next same-or-higher-level
#         header (or EOF)
static func parse_sections(text: String) -> Array:
	var sections: Array = []
	var lines := text.split("\n")
	var current: Dictionary = {}
	var current_body_lines: Array[String] = []
	var n_lines: int = lines.size()
	for i in n_lines:
		var raw_line: String = lines[i]
		var header_match = _match_header(raw_line)
		if header_match != null:
			# Flush previous section
			if not current.is_empty():
				current["body"] = "\n".join(current_body_lines)
				sections.append(current)
			var level: int = header_match["level"]
			var header_text: String = header_match["text"]
			current = {
				"id": header_text.substr(0, 80),
				"level": level,
				"line": i + 1,
			}
			current_body_lines = []
		else:
			if not current.is_empty():
				current_body_lines.append(raw_line)
	# Tail
	if not current.is_empty():
		current["body"] = "\n".join(current_body_lines)
		sections.append(current)
	return sections


static func _match_header(line: String):
	# Trim leading whitespace, then count leading '#' chars
	var stripped := line.lstrip(" \t")
	if stripped.is_empty() or stripped[0] != "#":
		return null
	var level := 0
	for ch in stripped:
		if ch == "#":
			level += 1
		else:
			break
	if level < 2 or level > 4:
		return null
	# After the hashes must come a space
	var rest := stripped.substr(level)
	if rest.is_empty() or rest[0] != " ":
		return null
	var text := rest.lstrip(" ").rstrip(" \r")
	return {"level": level, "text": text}


# ---------------------------------------------------------------------------
# Backtick extraction
# ---------------------------------------------------------------------------

# Returns Array of Dictionary: { token, line }
# A backtick token is anything between matching backticks on the same line.
static func extract_backticks(text: String) -> Array:
	var tokens: Array = []
	var regex := RegEx.new()
	regex.compile("`([^`\\n]+)`")
	for m in regex.search_all(text):
		var token: String = m.get_string(1)
		var line: int = _line_of_index(text, m.get_start())
		tokens.append({"token": token, "line": line})
	return tokens


static func _line_of_index(text: String, idx: int) -> int:
	var line := 1
	for i in range(min(idx, text.length())):
		if text[i] == "\n":
			line += 1
	return line


# ---------------------------------------------------------------------------
# Classification
# ---------------------------------------------------------------------------

# classify_token: returns one of "script", "scene", "data", "asset", "i18n", "ignore"
# plus a normalized form (e.g. "NightShiftGame.gd") if applicable.
static func classify_token(token: String, known_scripts: Array[String], known_i18n: Array[String]) -> Dictionary:
	# File-like: ends with a known extension
	var lower := token.to_lower()
	if lower.ends_with(".gd"):
		var basename := token.get_file()
		return {"kind": "script", "value": basename, "raw": token}
	if lower.ends_with(".tscn"):
		return {"kind": "scene", "value": token.get_file(), "raw": token}
	if lower.ends_with(".json"):
		# data/i18n/<lang>.json vs data/<dir>/<file>.json vs other
		if token.begins_with("data/") or token.contains("/data/") or token.contains("data\\"):
			return {"kind": "data", "value": token, "raw": token}
		# Could be an inline example; still record
		return {"kind": "data", "value": token, "raw": token}
	if lower.ends_with(".png") or lower.ends_with(".tres") or lower.ends_with(".res") or lower.ends_with(".import") or lower.ends_with(".svg"):
		return {"kind": "asset", "value": token, "raw": token}
	# Glob patterns (e.g. `npc_{nora,elias}.png`) — not a real file path
	if "{" in token or "*" in token:
		return {"kind": "asset", "value": token, "raw": token}
	# i18n candidate: snake_case identifier
	# Strict mode: only classify as i18n if it's known (loaded from zh.json).
	# Bare snake_case words (function names, variable names) are too noisy to
	# auto-classify.
	if _is_snake_case(token):
		if known_i18n.has(token):
			return {"kind": "i18n", "value": token, "raw": token}
		return {"kind": "ignore", "value": token, "raw": token}
	# Anything else (paths with spaces, mixed case identifiers, etc.)
	return {"kind": "ignore", "value": token, "raw": token}


static func _is_snake_case(token: String) -> bool:
	if token.is_empty():
		return false
	for i in token.length():
		var c := token[i]
		var is_lower := c >= "a" and c <= "z"
		var is_upper := c >= "A" and c <= "Z"
		var is_digit := c >= "0" and c <= "9"
		var is_underscore := c == "_"
		if not (is_lower or is_upper or is_digit or is_underscore):
			return false
	return true


# ---------------------------------------------------------------------------
# Test / capture filename extraction (not always backticked)
# ---------------------------------------------------------------------------

# Look for `tools/xxx_test.gd` mentions in body. Returns basenames only.
static func extract_test_refs(body: String) -> Array[String]:
	var found: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("[\\w/\\-]+_test\\.gd")
	for m in regex.search_all(body):
		var name: String = m.get_string()
		var basename: String = name.get_file()
		if basename.is_empty():
			continue
		found[basename] = true
	var keys: Array = found.keys()
	keys.sort()
	var out: Array[String] = []
	for k in keys:
		out.append(str(k))
	return out


# Look for `tools/capture_xxx.gd` mentions in body. Returns basenames only.
static func extract_capture_refs(body: String) -> Array[String]:
	var found: Dictionary = {}
	var regex := RegEx.new()
	regex.compile("[\\w/\\-]+capture_[\\w\\-]+\\.gd")
	for m in regex.search_all(body):
		var name: String = m.get_string()
		var basename: String = name.get_file()
		if basename.is_empty():
			continue
		found[basename] = true
	var keys: Array = found.keys()
	keys.sort()
	var out: Array[String] = []
	for k in keys:
		out.append(str(k))
	return out


# ---------------------------------------------------------------------------
# Bare script name extraction
# ---------------------------------------------------------------------------

# Scan body for any of the known script basenames appearing as bare words.
# Returns Array[String] of script basenames WITH ".gd" suffix.
static func extract_bare_scripts(body: String, known_scripts: Array[String]) -> Array[String]:
	if known_scripts.is_empty():
		return []
	var alt_parts: Array[String] = []
	for s in known_scripts:
		alt_parts.append("\\b%s\\b" % s)
	var regex := RegEx.new()
	regex.compile("(" + "|".join(alt_parts) + ")")
	var found: Dictionary = {}
	for m in regex.search_all(body):
		var name: String = m.get_string()
		found[name] = true
	var out: Array[String] = []
	for k in found.keys():
		out.append(k + ".gd")
	out.sort()
	return out


# ---------------------------------------------------------------------------
# Section-level extraction (the meat)
# ---------------------------------------------------------------------------

# Returns Dictionary with keys: scripts, scenes, data, i18n, assets,
# tests, captures. All arrays, all sorted, all deduped.
static func extract_section(section: Dictionary, known_scripts: Array[String], known_i18n: Array[String]) -> Dictionary:
	var body: String = section.get("body", "")
	var backticks := extract_backticks(body)
	var scripts: Dictionary = {}
	var scenes: Dictionary = {}
	var data: Dictionary = {}
	var i18n: Dictionary = {}
	var assets: Dictionary = {}
	var tests: Dictionary = {}
	var captures: Dictionary = {}
	for entry in backticks:
		var token: String = entry["token"]
		var cls := classify_token(token, known_scripts, known_i18n)
		var kind: String = cls["kind"]
		var value: String = cls["value"]
		if kind == "script":
			# capture_*.gd and *_test.gd live in their own buckets even when
			# they appear in backticks (which classify_token treats as scripts).
			if value.begins_with("capture_"):
				captures[value] = true
			elif value.ends_with("_test.gd"):
				tests[value] = true
			else:
				scripts[value] = true
		elif kind == "scene":
			scenes[value] = true
		elif kind == "data":
			data[value] = true
		elif kind == "i18n":
			i18n[value] = true
		elif kind == "asset":
			assets[value] = true
	# Bare script references (e.g. "NightShiftGame" without backticks) — but
	# only if the bare name matches a known on-disk script.
	for s in extract_bare_scripts(body, known_scripts):
		if s.begins_with("capture_") or s.ends_with("_test.gd"):
			# bare script name happens to look like a tool name; ignore here,
			# the dedicated extract_*_refs pass below will pick it up if the
			# body actually contains a path-like reference.
			continue
		scripts[s] = true
	# Pick up tools/<...>_test.gd and tools/capture_<...>.gd even when the
	# spec author wrote them WITHOUT backticks (e.g. inside a markdown table).
	for t in extract_test_refs(body):
		tests[t] = true
		scripts.erase(t)
	for c in extract_capture_refs(body):
		captures[c] = true
		scripts.erase(c)
	return {
		"scripts": _sorted_keys(scripts),
		"scenes": _sorted_keys(scenes),
		"data": _sorted_keys(data),
		"i18n": _sorted_keys(i18n),
		"assets": _sorted_keys(assets),
		"tests": _sorted_keys(tests),
		"captures": _sorted_keys(captures),
	}


static func _sorted_keys(d: Dictionary) -> Array[String]:
	var keys: Array = d.keys()
	keys.sort()
	var out: Array[String] = []
	for k in keys:
		out.append(str(k))
	return out


# ---------------------------------------------------------------------------
# Cross-reference helpers
# ---------------------------------------------------------------------------

# Returns Dictionary with arrays of orphan / ghost / etc.
static func cross_ref(sections: Array, known_scripts: Array[String], known_i18n: Array[String]) -> Dictionary:
	var referenced_scripts: Dictionary = {}
	var referenced_scenes: Dictionary = {}
	var referenced_data: Dictionary = {}
	var referenced_i18n: Dictionary = {}
	var referenced_assets: Dictionary = {}
	var referenced_tests: Dictionary = {}
	var referenced_captures: Dictionary = {}
	for sec in sections:
		for s in sec.get("scripts", []):
			referenced_scripts[s] = true
		for s in sec.get("scenes", []):
			referenced_scenes[s] = true
		for s in sec.get("data", []):
			referenced_data[s] = true
		for s in sec.get("i18n", []):
			referenced_i18n[s] = true
		for s in sec.get("assets", []):
			referenced_assets[s] = true
		for s in sec.get("tests", []):
			referenced_tests[s] = true
		for s in sec.get("captures", []):
			referenced_captures[s] = true
	# scripts_orphan: spec references a basename that isn't on disk
	var scripts_orphan: Array[String] = []
	for s in referenced_scripts.keys():
		if s.ends_with("_test.gd") or s.begins_with("capture_"):
			continue
		if not known_scripts.has(s.trim_suffix(".gd")):
			scripts_orphan.append(s)
	scripts_orphan.sort()
	# scripts_ghost: on disk but no section references it
	var scripts_ghost: Array[String] = []
	for s in known_scripts:
		if not referenced_scripts.has(s + ".gd"):
			scripts_ghost.append(s + ".gd")
	scripts_ghost.sort()
	# i18n_keys_unused: zh.json keys no section references
	var i18n_unused: Array[String] = []
	for k in known_i18n:
		if not referenced_i18n.has(k):
			i18n_unused.append(k)
	i18n_unused.sort()
	# sections without any reference (potential content gaps)
	var bare_sections: Array[String] = []
	for sec in sections:
		var total: int = 0
		for k in ["scripts", "scenes", "data", "i18n", "assets", "tests", "captures"]:
			total += (sec.get(k, []) as Array).size()
		if total == 0:
			bare_sections.append(sec.get("id", ""))
	return {
		"scripts_orphan": scripts_orphan,
		"scripts_ghost": scripts_ghost,
		"i18n_keys_unused_in_spec": i18n_unused,
		"sections_with_no_refs": bare_sections,
	}


# ---------------------------------------------------------------------------
# Disk scan helpers (used by main tool, but pure-functional so testable)
# ---------------------------------------------------------------------------

# List all .gd files under a given res:// path. Returns Array[String] of
# basenames (no extension).
static func list_gd_scripts(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if not dir.current_is_dir() and name.ends_with(".gd"):
			out.append(name.get_basename())
		name = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


# Load zh.json keys. Returns Array[String] of leaf keys (top-level only, since
# zh.json is a flat dict).
static func list_i18n_keys(i18n_path: String) -> Array[String]:
	var out: Array[String] = []
	if not FileAccess.file_exists(i18n_path):
		return out
	var text := FileAccess.get_file_as_string(i18n_path)
	if text.is_empty():
		return out
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return out
	for k in (parsed as Dictionary).keys():
		out.append(str(k))
	out.sort()
	return out


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------

# Render sections + cross_ref into a human-readable stdout table.
static func render_table(spec_path: String, sections: Array, cross: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("=== Spec Dependency Graph: %s ===" % spec_path)
	lines.append("")
	lines.append("Sections: %d  |  scripts referenced: %d  |  i18n keys referenced: %d" % [
		sections.size(),
		_count_unique(sections, "scripts"),
		_count_unique(sections, "i18n"),
	])
	lines.append("")
	for sec in sections:
		lines.append("§%s  (line %d)" % [sec.get("id", "?"), sec.get("line", 0)])
		for category in ["scripts", "scenes", "data", "i18n", "assets", "tests", "captures"]:
			var arr: Array = sec.get(category, [])
			if arr.is_empty():
				lines.append("    %-9s —" % category)
			else:
				lines.append("    %-9s %s" % [category, ", ".join(arr)])
		lines.append("")
	# Cross-ref section
	lines.append("=== Cross-reference ===")
	for k in ["scripts_orphan", "scripts_ghost", "i18n_keys_unused_in_spec", "sections_with_no_refs"]:
		var arr: Array = cross.get(k, [])
		lines.append("    %-30s %d" % [k, arr.size()])
		if not arr.is_empty() and arr.size() <= 20:
			lines.append("        " + ", ".join(arr))
		elif not arr.is_empty():
			lines.append("        " + ", ".join(arr.slice(0, 20)) + " ... (+%d more)" % (arr.size() - 20))
	return "\n".join(lines)


static func _count_unique(sections: Array, category: String) -> int:
	var seen: Dictionary = {}
	for sec in sections:
		for v in sec.get(category, []):
			seen[v] = true
	return seen.size()


# Build JSON-serializable Dictionary.
static func build_json(spec_path: String, sections: Array, cross: Dictionary) -> Dictionary:
	var out_sections: Array = []
	for sec in sections:
		out_sections.append({
			"id": sec.get("id", ""),
			"level": sec.get("level", 0),
			"line": sec.get("line", 0),
			"scripts": sec.get("scripts", []),
			"scenes": sec.get("scenes", []),
			"data": sec.get("data", []),
			"i18n": sec.get("i18n", []),
			"assets": sec.get("assets", []),
			"tests": sec.get("tests", []),
			"captures": sec.get("captures", []),
		})
	return {
		"spec_path": spec_path,
		"section_count": sections.size(),
		"sections": out_sections,
		"cross_ref": cross,
	}