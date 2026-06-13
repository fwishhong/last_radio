extends RefCounted

class_name NightShiftArt

static func load_hotspot_state_textures(base_path: String, loader: Callable) -> Dictionary:
	return {
		"front_door_intact": loader.call(base_path + "front_door_intact.png"),
		"front_door_warning": loader.call(base_path + "front_door_warning.png"),
		"front_door_assault": loader.call(base_path + "front_door_assault.png"),
		"front_door_braced": loader.call(base_path + "front_door_braced.png"),
		"front_door_broken": loader.call(base_path + "front_door_broken.png"),
		"back_door_intact": loader.call(base_path + "back_door_intact.png"),
		"back_door_warning": loader.call(base_path + "back_door_warning.png"),
		"back_door_assault": loader.call(base_path + "back_door_assault.png"),
		"back_door_braced": loader.call(base_path + "back_door_braced.png"),
		"back_door_broken": loader.call(base_path + "back_door_broken.png"),
		"window_intact": loader.call(base_path + "window_intact.png"),
		"window_warning": loader.call(base_path + "window_warning.png"),
		"window_assault": loader.call(base_path + "window_assault.png"),
		"window_braced": loader.call(base_path + "window_braced.png"),
		"window_broken": loader.call(base_path + "window_broken.png"),
		"generator_stable": loader.call(base_path + "generator_stable.png"),
		"generator_low_power": loader.call(base_path + "generator_low_power.png"),
		"generator_blackout": loader.call(base_path + "generator_blackout.png"),
		"generator_repaired": loader.call(base_path + "generator_repaired.png"),
		"radio_idle": loader.call(base_path + "radio_idle.png"),
		"radio_calling": loader.call(base_path + "radio_calling.png"),
		"radio_connected": loader.call(base_path + "radio_connected.png"),
		"radio_missed": loader.call(base_path + "radio_missed.png"),
		"antenna_idle": loader.call(base_path + "antenna_idle.png"),
		"antenna_warning": loader.call(base_path + "antenna_warning.png"),
		"antenna_misaligned": loader.call(base_path + "antenna_misaligned.png"),
		"antenna_repaired": loader.call(base_path + "antenna_repaired.png"),
		"antenna_broken": loader.call(base_path + "antenna_broken.png"),
		"medbay_idle": loader.call(base_path + "medbay_idle.png"),
		"medbay_warning": loader.call(base_path + "medbay_warning.png"),
		"medbay_treating": loader.call(base_path + "medbay_treating.png"),
		"medbay_critical": loader.call(base_path + "medbay_critical.png"),
		"storage_idle": loader.call(base_path + "storage_idle.png"),
		"storage_shortage": loader.call(base_path + "storage_shortage.png"),
		"storage_repairing": loader.call(base_path + "storage_repairing.png"),
		"storage_empty": loader.call(base_path + "storage_empty.png")
	}

static func load_upgrade_icon_textures(base_path: String, loader: Callable) -> Dictionary:
	return {
		"door_reinforce": loader.call(base_path + "icon_door_reinforce.png"),
		"window_brace": loader.call(base_path + "icon_window_brace.png"),
		"battery_buffer": loader.call(base_path + "icon_battery_buffer.png"),
		"generator_tune": loader.call(base_path + "icon_generator_tune.png"),
		"radio_booster": loader.call(base_path + "icon_radio_booster.png"),
		"workbench": loader.call(base_path + "icon_workbench.png"),
		"antenna_anchor": loader.call(base_path + "icon_radio_booster.png"),
		"storage": loader.call(base_path + "icon_storage.png"),
		"medbay": loader.call(base_path + "icon_medbay.png"),
		"floodlights": loader.call(base_path + "icon_battery_buffer.png"),
		"second_plank": loader.call(base_path + "icon_window_brace.png"),
		"command_routine": loader.call(base_path + "icon_workbench.png"),
		"back_door_bar": loader.call(base_path + "icon_door_reinforce.png"),
		"generator_cage": loader.call(base_path + "icon_generator_tune.png"),
		"runner_path": loader.call(base_path + "icon_workbench.png"),
		"medbay_lamp": loader.call(base_path + "icon_medbay.png"),
		"nora_kit": loader.call(base_path + "icon_medbay.png"),
		"quiet_hours": loader.call(base_path + "icon_radio_booster.png"),
		"salvage_planks": loader.call(base_path + "icon_storage.png"),
		"double_brace": loader.call(base_path + "icon_window_brace.png"),
		"victor_cache": loader.call(base_path + "icon_storage.png"),
		"signal_battery": loader.call(base_path + "icon_battery_buffer.png"),
		"cable_route": loader.call(base_path + "icon_radio_booster.png"),
		"elias_tools": loader.call(base_path + "icon_workbench.png"),
		"final_barricade": loader.call(base_path + "icon_door_reinforce.png"),
		"all_hands": loader.call(base_path + "icon_workbench.png"),
		"radio_beacon": loader.call(base_path + "icon_radio_booster.png")
	}

static func load_upgrade_event_textures(base_path: String, loader: Callable) -> Dictionary:
	return {
		"door_reinforce": loader.call(base_path + "event_door_reinforce.png"),
		"window_brace": loader.call(base_path + "event_window_brace.png"),
		"battery_buffer": loader.call(base_path + "event_battery_cache.png"),
		"generator_tune": loader.call(base_path + "event_generator_tune.png"),
		"radio_booster": loader.call(base_path + "event_radio_antenna.png"),
		"workbench": loader.call(base_path + "event_workbench.png"),
		"antenna_anchor": loader.call(base_path + "event_antenna_anchor.png"),
		"storage": loader.call(base_path + "event_storage.png"),
		"medbay": loader.call(base_path + "event_medbay.png"),
		"floodlights": loader.call(base_path + "event_floodlights.png"),
		"second_plank": loader.call(base_path + "event_second_plank.png"),
		"command_routine": loader.call(base_path + "event_command_routine.png"),
		"back_door_bar": loader.call(base_path + "event_back_door_bar.png"),
		"generator_cage": loader.call(base_path + "event_generator_cage.png"),
		"runner_path": loader.call(base_path + "event_runner_path.png"),
		"medbay_lamp": loader.call(base_path + "event_medbay_lamp.png"),
		"nora_kit": loader.call(base_path + "event_nora_kit.png"),
		"quiet_hours": loader.call(base_path + "event_quiet_hours.png"),
		"salvage_planks": loader.call(base_path + "event_salvage_planks.png"),
		"double_brace": loader.call(base_path + "event_double_brace.png"),
		"victor_cache": loader.call(base_path + "event_victor_cache.png"),
		"signal_battery": loader.call(base_path + "event_signal_battery.png"),
		"cable_route": loader.call(base_path + "event_cable_route.png"),
		"elias_tools": loader.call(base_path + "event_elias_tools.png"),
		"final_barricade": loader.call(base_path + "event_final_barricade.png"),
		"all_hands": loader.call(base_path + "event_all_hands.png"),
		"radio_beacon": loader.call(base_path + "event_radio_beacon.png")
	}

static func load_alert_icon_textures(base_path: String, loader: Callable) -> Dictionary:
	return {
		"warning": loader.call(base_path + "alert_warning.png"),
		"assault": loader.call(base_path + "alert_assault.png"),
		"blackout": loader.call(base_path + "alert_blackout.png"),
		"radio_call": loader.call(base_path + "alert_radio_call.png"),
		"braced": loader.call(base_path + "alert_braced.png")
	}

static func hotspot_texture_key(id: String, data: Dictionary, context: Dictionary) -> String:
	var kind := str(data.get("kind", ""))
	var value := float(data.get("value", 0.0))
	if kind == "barrier":
		var prefix := "front_door" if id == "front_door" else ("back_door" if id == "back_door" else "window")
		if float(data.get("breach_timer", -1.0)) >= 0.0 or value <= 0.0:
			return "%s_broken" % prefix
		if float(data.get("temp_seal", 0.0)) > 0.0 or bool(data.get("braced", false)):
			return "%s_braced" % prefix
		if bool(data.get("assault", false)):
			return "%s_assault" % prefix
		if bool(data.get("warning", false)):
			return "%s_warning" % prefix
		return "%s_intact" % prefix
	if kind == "generator":
		if bool(context.get("blackout", false)) or value <= 0.0:
			return "generator_blackout"
		if str(context.get("player_target_id", "")) == id and bool(context.get("player_at_target", false)):
			return "generator_repaired"
		if value < 55.0:
			return "generator_low_power"
		return "generator_stable"
	if kind == "radio":
		if bool(context.get("radio_completed", false)):
			return "radio_connected"
		if bool(context.get("radio_missed", false)):
			return "radio_missed"
		if bool(context.get("radio_available", false)):
			return "radio_calling"
		return "radio_idle"
	if kind == "antenna":
		if value < 28.0:
			return "antenna_broken"
		if value < 55.0:
			return "antenna_misaligned"
		if bool(data.get("active", false)):
			if str(context.get("player_target_id", "")) == id and bool(context.get("player_at_target", false)):
				return "antenna_repaired"
			return "antenna_warning"
		return "antenna_idle"
	if kind == "support":
		var player_assigned := str(context.get("player_target_id", "")) == id
		if id == "medbay":
			if value < 28.0:
				return "medbay_critical"
			if player_assigned and bool(data.get("active", false)):
				return "medbay_treating"
			if bool(data.get("active", false)) or bool(data.get("warning", false)) or value < 70.0:
				return "medbay_warning"
			return "medbay_idle"
		if id == "storage":
			if value < 28.0:
				return "storage_empty"
			if player_assigned and bool(data.get("active", false)):
				return "storage_repairing"
			if bool(data.get("active", false)) or bool(data.get("warning", false)) or value < 70.0:
				return "storage_shortage"
			return "storage_idle"
	return ""

static func hotspot_texture_size(id: String) -> Vector2:
	match id:
		"front_door", "back_door":
			return Vector2(66, 66)
		"left_window", "right_window":
			return Vector2(58, 58)
		"generator", "radio", "antenna", "medbay", "storage":
			return Vector2(62, 62)
		_:
			return Vector2(56, 56)
