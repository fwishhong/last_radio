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
	var best_id := ""
	var best_score := -999.0
	for id in ["left_window", "right_window"]:
		if not unlocked.call(id):
			continue
		if id == player_target_id:
			continue
		var data: Dictionary = hotspots[id]
		var value := float(data.get("value", 100.0))
		# Breach-in-progress takes absolute priority
		if float(data.get("breach_timer", -1.0)) >= 0.0:
			return id
		if not bool(data.get("active", false)) and not bool(data.get("warning", false)):
			continue
		var score := 100.0 - value
		if bool(data.get("assault", false)):
			score += 65.0
		if bool(data.get("warning", false)):
			score += 30.0
		if score > best_score and (value < 86.0 or bool(data.get("assault", false))):
			best_score = score
			best_id = id
	if best_id == "":
		for id in ["left_window", "right_window"]:
			if not unlocked.call(id):
				continue
			var data: Dictionary = hotspots[id]
			var value := float(data.get("value", 100.0))
			if bool(data.get("active", false)) and value < 70.0:
				best_id = id
				break
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
