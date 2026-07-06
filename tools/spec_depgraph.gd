extends SceneTree
# Spec dependency graph tool.
#
# Usage:
#   godot --headless --path . --script res://tools/spec_depgraph.gd -- --spec=<markdown> --out=<json> [--no-write]
#
# Default --spec: docs/design/last_radio_v2_polish_spec.md
# Default --out: .harness/scratch/polish_depgraph.json
#
# Prints a human-readable table to stdout and writes a JSON file with the
# section-by-section dependency map + a cross-reference block (orphan / ghost
# / unused-i18n / no-ref sections).
#
# See tools/spec_depgraph_lib.gd for the actual parsing helpers.
# See tools/spec_depgraph_test.gd for the regression test.

const Lib := preload("res://tools/spec_depgraph_lib.gd")
const DEFAULT_SPEC := "res://docs/design/last_radio_v2_polish_spec.md"
const DEFAULT_OUT := ".harness/scratch/polish_depgraph.json"
const SCRIPTS_DIR := "res://scripts"
const I18N_PATH := "res://data/i18n/zh.json"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var spec_path := DEFAULT_SPEC
	var out_path := DEFAULT_OUT
	var no_write := false
	for arg in args:
		if arg == "--help" or arg == "-h":
			_print_usage()
			quit(0)
			return
		if arg == "--no-write":
			no_write = true
			continue
		if arg.begins_with("--spec="):
			spec_path = arg.substr(7)
			continue
		if arg.begins_with("--out="):
			out_path = arg.substr(5)
			continue
	if not FileAccess.file_exists(spec_path):
		push_error("spec_depgraph: spec file not found: %s" % spec_path)
		quit(1)
		return
	var text := FileAccess.get_file_as_string(spec_path)
	if text.is_empty():
		push_error("spec_depgraph: spec file empty: %s" % spec_path)
		quit(1)
		return
	var known_scripts := Lib.list_gd_scripts(SCRIPTS_DIR)
	var known_i18n := Lib.list_i18n_keys(I18N_PATH)
	var sections := Lib.parse_sections(text)
	var enriched: Array = []
	for sec in sections:
		var ext := Lib.extract_section(sec, known_scripts, known_i18n)
		var merged: Dictionary = sec.duplicate()
		merged["scripts"] = ext["scripts"]
		merged["scenes"] = ext["scenes"]
		merged["data"] = ext["data"]
		merged["i18n"] = ext["i18n"]
		merged["assets"] = ext["assets"]
		merged["tests"] = ext["tests"]
		merged["captures"] = ext["captures"]
		enriched.append(merged)
	var cross := Lib.cross_ref(enriched, known_scripts, known_i18n)
	var table := Lib.render_table(spec_path, enriched, cross)
	print(table)
	var json_dict := Lib.build_json(spec_path, enriched, cross)
	var json_text := JSON.stringify(json_dict, "  ")
	if no_write:
		print("")
		print("(skipped write per --no-write)")
		quit(0)
		return
	var out_abs := out_path
	if out_path.begins_with("res://"):
		out_abs = ProjectSettings.globalize_path(out_path)
	# Make sure parent dir exists
	var parent := out_abs.get_base_dir()
	if not DirAccess.dir_exists_absolute(parent):
		var mk_err := DirAccess.make_dir_recursive_absolute(parent)
		if mk_err != OK:
			push_error("spec_depgraph: failed to create dir %s (err %d)" % [parent, mk_err])
			quit(1)
			return
	var f := FileAccess.open(out_abs, FileAccess.WRITE)
	if f == null:
		push_error("spec_depgraph: failed to open %s for write (err %d)" % [out_abs, FileAccess.get_open_error()])
		quit(1)
		return
	f.store_string(json_text)
	f.close()
	print("")
	print("Wrote %s (%d bytes)" % [out_path, json_text.length()])
	quit(0)


func _print_usage() -> void:
	print("spec_depgraph — parse a markdown spec and emit a dependency graph")
	print("")
	print("Usage:")
	print("  godot --headless --path . --script res://tools/spec_depgraph.gd -- \\")
	print("    [--spec=<markdown-path>] [--out=<json-path>] [--no-write] [--help]")
	print("")
	print("Defaults:")
	print("  --spec  res://docs/design/last_radio_v2_polish_spec.md")
	print("  --out   .harness/scratch/polish_depgraph.json")
	print("")
	print("Reads:")
	print("  - The spec markdown for section content.")
	print("  - res://scripts/*.gd for known script basenames.")
	print("  - res://data/i18n/zh.json for known i18n keys.")
	print("")
	print("Writes:")
	print("  - JSON dependency map to --out.")
	print("  - Human-readable table to stdout.")