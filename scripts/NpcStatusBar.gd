extends Control
class_name NpcStatusBar
# NPC UI status bar — polish spec §4.4.
#
# Top-of-screen Panel that lists each joined NPC with portrait + name +
# status text. Hidden when no ally is currently in the rotation.
#
# Status mapping (in priority order):
#   1. global trust < 2                  -> "信任告急" / "Trust critical"
#   2. has target + walk_timer <= 0      -> "救急中"   / "Responding"
#      (NPC arrived at the hotspot and is softly repairing it)
#   3. has target + walk_timer > 0       -> "赶路中"   / "En route"
#      (NPC just chose a target, walk cooldown is ticking)
#   4. no target                         -> "待命"     / "Standing by"
#
# Re-resolution cadence matches NightShiftGame._tick_npcs (every 0.2s). The
# caller invokes refresh() after each tick — this avoids owning a Timer node
# and keeps the bar a pure view over game state.

const I18n := preload("res://scripts/I18n.gd")
const PortraitUtils := preload("res://scripts/MemberPanel.gd")

const ROW_HEIGHT := 40.0
const ROW_WIDTH := 240.0
const ROW_GAP := 8.0
const BAR_TOP := 4.0
const BAR_LEFT := 24.0
const LOW_TRUST_THRESHOLD := 2.0

# npc_id -> Dictionary {panel: Panel, portrait: TextureRect, name_lbl: Label,
#                       status_lbl: Label}
var _rows: Dictionary = {}

# i18n keys for status text. Loaded once at ready-time so refresh() doesn't
# pay the lookup cost per NPC per frame.
var _status_keys: Dictionary = {
	"emergency": "npc_status_emergency",
	"walking": "npc_status_walking",
	"idle": "npc_status_idle",
	"low_trust": "npc_status_low_trust",
}

# Display name fallback when no survivor_*_brief key is wired yet (B4b
# brings the per-NPC keys; until then the bar uses plain English names).
var _name_fallback: Dictionary = {
	"nora": "Nora",
	"elias": "Elias",
	"lily": "Lily",
	"tom": "Tom",
	"daniel": "Daniel",
	"victor": "Victor",
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


# Public API: refresh the bar from current game state. Caller invokes this
# every ~0.2s (same cadence as _tick_npcs) or whenever allies / npc_state
# change shape.
#
# allies     Dictionary npc_id -> bool (joined rotation)
# npc_state  Dictionary npc_id -> {target, walk_timer, ...}
# trust      float     global trust resource; < LOW_TRUST_THRESHOLD forces
#                       "信任告急" across all rows.
func refresh(allies: Dictionary, npc_state: Dictionary, trust: float) -> void:
	var npc_ids: Array = []
	for npc_id in allies.keys():
		if bool(allies[npc_id]) and npc_state.has(npc_id):
			npc_ids.append(npc_id)
	npc_ids.sort()
	# Hide when nothing to show.
	if npc_ids.is_empty():
		visible = false
		return
	visible = true
	# Ensure each displayed NPC has a row.
	var stale: Array = []
	for npc_id in _rows.keys():
		if not npc_id in npc_ids:
			stale.append(npc_id)
	for npc_id in stale:
		_remove_row(npc_id)
	# Place rows left-to-right.
	var x: float = BAR_LEFT
	for npc_id in npc_ids:
		if not _rows.has(npc_id):
			_rows[npc_id] = _build_row(npc_id)
		var row: Dictionary = _rows[npc_id]
		row.panel.position = Vector2(x, BAR_TOP)
		row.panel.size = Vector2(ROW_WIDTH, ROW_HEIGHT)
		row.name_lbl.text = _display_name(npc_id)
		row.status_lbl.text = _status_text(npc_id, npc_state[npc_id], trust)
		x += ROW_WIDTH + ROW_GAP


# --- internals ---


# Build a fresh row for an NPC. Adds the Panel + portrait + name + status
# Label children, attaches to self, and returns the row dict.
func _build_row(npc_id: String) -> Dictionary:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.09, 0.14, 0.92)
	ps.border_color = Color(0.55, 0.78, 1.0, 0.85)
	for k in ["left", "right", "top", "bottom"]:
		ps.set("border_width_" + k, 1)
	for k in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		ps.set("corner_radius_" + k, 4)
	ps.content_margin_left = 6
	ps.content_margin_right = 6
	ps.content_margin_top = 4
	ps.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# Portrait: try portrait_<id>.png; fall back to a letter badge so the
	# row still reads when art isn't on disk (Lily / Tom not yet shipped).
	var portrait := TextureRect.new()
	portrait.position = Vector2(6, 6)
	portrait.size = Vector2(28, 28)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_path := "res://assets/final/night_shift/portrait_%s.png" % npc_id
	if ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
	else:
		# Color-tint fallback so the slot still reads as a person.
		portrait.texture = null
		portrait.modulate = _npc_color(npc_id)
	panel.add_child(portrait)

	# Name label.
	var name_lbl := Label.new()
	name_lbl.position = Vector2(40, 6)
	name_lbl.size = Vector2(96, 14)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_constant_override("outline_size", 2)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(name_lbl)

	# Arrow + status text.
	var status_lbl := Label.new()
	status_lbl.position = Vector2(40, 22)
	status_lbl.size = Vector2(192, 16)
	status_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.7))
	status_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_constant_override("outline_size", 2)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(status_lbl)

	return {
		"panel": panel,
		"portrait": portrait,
		"name_lbl": name_lbl,
		"status_lbl": status_lbl,
	}


func _remove_row(npc_id: String) -> void:
	if not _rows.has(npc_id):
		return
	var row: Dictionary = _rows[npc_id]
	var panel: Panel = row["panel"]
	if panel.get_parent():
		panel.get_parent().remove_child(panel)
	panel.queue_free()
	_rows.erase(npc_id)


# Status text selection (priority order matches polish spec §4.4).
func _status_text(npc_id: String, st: Dictionary, trust: float) -> String:
	var key: String
	if trust < LOW_TRUST_THRESHOLD:
		key = _status_keys["low_trust"]
	else:
		var target: String = str(st.get("target", ""))
		var walk_timer: float = float(st.get("walk_timer", 0.0))
		if target == "":
			key = _status_keys["idle"]
		elif walk_timer > 0.0:
			key = _status_keys["walking"]
		else:
			key = _status_keys["emergency"]
	return I18n.t(key)


# Display name: prefer survivor_*_brief key if present in the active locale
# dict (so the row localizes properly), else fall back to the plain English
# name from _name_fallback. The polish spec calls for `survivor_nora_brief`
# etc.; until those land (B4b) we render the plain name so the bar still
# reads cleanly.
func _display_name(npc_id: String) -> String:
	var brief_key := "survivor_%s_brief" % npc_id
	if _i18n_locale_has(brief_key):
		var s: String = I18n.t(brief_key)
		if s.length() > 12:
			s = s.substr(0, 12) + "…"
		return s
	return _name_fallback.get(npc_id, npc_id.capitalize())


func _i18n_locale_has(key: String) -> bool:
	# Bypass I18n.t()'s key-as-fallback behaviour: we want a real membership
	# check so missing keys render the fallback name, not "survivor_nora_brief".
	if not I18n.dicts.has(I18n.locale):
		return false
	return (I18n.dicts[I18n.locale] as Dictionary).has(key)


# Fallback tint when no portrait asset exists. Matches the MemberPanel badge
# palette so the UI stays consistent.
func _npc_color(npc_id: String) -> Color:
	match npc_id:
		"nora": return Color(0.55, 0.85, 0.7)
		"elias": return Color(0.65, 0.78, 0.95)
		"lily": return Color(0.95, 0.85, 0.6)
		"tom": return Color(0.85, 0.65, 0.55)
		"daniel": return Color(0.8, 0.78, 0.65)
		"victor": return Color(0.7, 0.7, 0.95)
		_: return Color(0.78, 0.78, 0.78)