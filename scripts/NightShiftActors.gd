extends RefCounted

class_name NightShiftActors

static func nora_work_rate(base_rate: float, upgrades: Dictionary) -> float:
	var rate := base_rate
	if bool(upgrades.get("window_brace", false)):
		rate += 3.0
	if bool(upgrades.get("medbay", false)):
		rate += 2.0
	if bool(upgrades.get("nora_kit", false)):
		rate += 2.0
	if bool(upgrades.get("all_hands", false)):
		rate += 2.0
	return rate

static func elias_work_rate(base_rate: float, upgrades: Dictionary) -> float:
	var rate := base_rate
	if bool(upgrades.get("medbay", false)):
		rate += 3.0
	if bool(upgrades.get("elias_tools", false)):
		rate += 3.0
	if bool(upgrades.get("all_hands", false)):
		rate += 3.0
	if bool(upgrades.get("command_routine", false)):
		rate += 2.0
	return rate

static func player_speed(base_speed: float, upgrades: Dictionary) -> float:
	return base_speed + (34.0 if bool(upgrades.get("runner_path", false)) else 0.0)

static func window_needing_help(hotspots: Dictionary, unlocked: Callable, player_target_id: String) -> String:
	# polish spec §4.2 rule 1: NPC only acts when emergency —
	# breach_timer>=0 OR value<35% of max. Without this filter the helper
	# would jump in at value<86 which steals the player's everyday repair.
	var best_id := ""
	var best_score := -999.0
	for id in ["left_window", "right_window"]:
		if not unlocked.call(id):
			continue
		if id == player_target_id:
			continue
		var data: Dictionary = hotspots[id]
		var value := float(data.get("value", 100.0))
		var max_v := float(data.get("max_value", 100.0))
		# Breach-in-progress takes absolute priority.
		if float(data.get("breach_timer", -1.0)) >= 0.0:
			return id
		# Emergency gate: only act on value<35% or active assault.
		var is_emergency: bool = value < 0.35 * max_v or bool(data.get("assault", false))
		if not is_emergency:
			continue
		if not bool(data.get("active", false)) and not bool(data.get("warning", false)):
			continue
		var score := max_v - value
		if bool(data.get("assault", false)):
			score += 65.0
		if bool(data.get("warning", false)):
			score += 30.0
		if score > best_score:
			best_score = score
			best_id = id
	return best_id

static func elias_needing_help(hotspots: Dictionary, unlocked: Callable, player_target_id: String, radio_available: bool, radio_completed: bool, blackout: bool, antenna_low: bool, upgrades: Dictionary) -> String:
	# Elias only ever goes to antenna — never to generator
	if unlocked.call("antenna") and player_target_id != "antenna":
		var antenna: Dictionary = hotspots["antenna"]
		if bool(antenna.get("active", false)) and float(antenna.get("value", 100.0)) < 76.0:
			return "antenna"
	if radio_available and not radio_completed and not blackout and not antenna_low and player_target_id != "radio":
		return "radio"
	return ""


# Decide whether NPC should commit to a target this tick. Returns hotspot_id
# or "" (idle). Implements the 4 rules from polish spec §4.2:
#   1. emergency only — caller filters breach_timer>=0 or value<35% via the
#      underlying helpers (window_needing_help / elias_needing_help already do
#      this; see D10 in spec §10)
#   2. soft-commit 2s — if commit_timer>0, hold previous target, don't re-eval
#   3. defer to player — if player is targeting the same hotspot, return ""
#   4. walk cooldown 1.5s — caller enforces via npc_state.walk_timer
#
# `npc_state` must be keyed by npc_id; each entry is a dict with
# `target` (String), `commit_timer` (float).
static func decide_target(npc_id: String, hotspots: Dictionary,
		unlocked: Callable, player_target_id: String,
		npc_state: Dictionary,
		radio_available: bool = false,
		radio_completed: bool = false,
		blackout: bool = false,
		antenna_low: bool = false,
		upgrades: Dictionary = {}) -> String:
	# Rule 2: soft-commit (2s window where we hold the previous target)
	var st: Dictionary = npc_state.get(npc_id, {})
	if float(st.get("commit_timer", 0.0)) > 0.0:
		return str(st.get("target", ""))
	# Compute want via the per-NPC selector
	var want: String = ""
	if npc_id == "nora":
		want = window_needing_help(hotspots, unlocked, player_target_id)
	elif npc_id == "elias":
		want = elias_needing_help(hotspots, unlocked, player_target_id,
				radio_available, radio_completed, blackout, antenna_low, upgrades)
	# Rule 3: defer to player
	if want != "" and want == player_target_id:
		want = ""
	return want
