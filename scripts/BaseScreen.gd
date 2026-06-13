extends Control

const MAX_DAY := 3
const MEMBERS_PATH := "res://data/v2_members.json"
const LOCATIONS_PATH := "res://data/v2_locations.json"
const ITEMS_PATH := "res://data/v2_items.json"
const SIGNALS_PATH := "res://data/v2_signals.json"
const TUNING_SCENE := preload("res://scenes/RadioTuningPanel.tscn")
const CITY_SCENE := preload("res://scenes/CityMapScreen.tscn")
const DISPATCH_SCENE := preload("res://scenes/DispatchPanel.tscn")
const REPORT_SCENE := preload("res://scenes/NightReport.tscn")
const ROUTE_DEFS := {
	"safe": {
		"name": "安全慢路",
		"score": 10,
		"reward_multiplier": 0.75,
		"threat": 0,
		"fuel": 0,
		"failure_risk": 0
	},
	"fast": {
		"name": "危险近路",
		"score": -10,
		"reward_multiplier": 1.15,
		"threat": 1,
		"fuel": 0,
		"failure_risk": 0
	},
	"unknown": {
		"name": "未知小路",
		"score": -4,
		"reward_multiplier": 1.0,
		"threat": -1,
		"fuel": 1,
		"failure_risk": 10
	}
}
const BROADCAST_DEFS := {
	"route_warning": {
		"name": "路线警告",
		"score": 5,
		"influence": 1,
		"threat": 1,
		"power": 0,
		"trust": 0
	},
	"relay_help": {
		"name": "转播求救",
		"score": 8,
		"influence": 2,
		"threat": 2,
		"power": -1,
		"trust": 0
	},
	"silent": {
		"name": "保持低调",
		"score": -3,
		"influence": 0,
		"threat": 0,
		"power": 0,
		"trust": -1
	}
}
const DAILY_DIRECTIVE_DEFS := {
	1: {
		"id": "rescue_priority",
		"title": "救援优先",
		"brief": "今天处理任一救援点，外勤不能失败。",
		"condition": "rescue_not_failed",
		"reward": {"trust": 2, "parts": 1},
		"failure": {"trust": -1}
	},
	2: {
		"id": "supply_backflow",
		"title": "补给回流",
		"brief": "今天带回电力、食物、药品或燃料。",
		"condition": "resource_reward_not_failed",
		"reward": {"food": 1, "influence": 1},
		"failure": {"food": -1}
	},
	3: {
		"id": "quiet_frequency",
		"title": "压低暴露",
		"brief": "入夜前把暴露度压在 2 以下。",
		"condition": "threat_at_most",
		"max_threat": 2,
		"reward": {"trust": 2, "influence": 1},
		"failure": {"trust": -2}
	}
}
const DAY_STANCE_DEFS := {
	"balanced": {
		"name": "稳态运营",
		"score": 0,
		"reward_multiplier": 1.0,
		"rescue_multiplier": 1.0,
		"threat": 0,
		"stress": 0,
		"failure_risk": 0,
		"brief": "不改变外勤风险和收益。"
	},
	"aid": {
		"name": "救援广播网",
		"score": 0,
		"rescue_score": 6,
		"reward_multiplier": 0.9,
		"rescue_multiplier": 1.25,
		"threat": 1,
		"stress": 2,
		"failure_risk": 0,
		"brief": "更适合救人，但会暴露基地。"
	},
	"salvage": {
		"name": "补给优先",
		"score": 0,
		"supply_score": 5,
		"rescue_score": -3,
		"reward_multiplier": 1.18,
		"rescue_multiplier": 0.75,
		"threat": 1,
		"stress": 1,
		"failure_risk": 4,
		"brief": "多拿物资，救援效率下降。"
	},
	"quiet": {
		"name": "低调潜行",
		"score": -3,
		"reward_multiplier": 0.85,
		"rescue_multiplier": 1.0,
		"threat": -1,
		"stress": -2,
		"failure_risk": -6,
		"brief": "压低暴露，但行动更保守。"
	}
}
const PREP_DEFS := {
	"none": {
		"name": "无准备",
		"score": 0,
		"cost": {},
		"threat": 0,
		"stress": 0
	},
	"hot_meal": {
		"name": "热食动员",
		"score": 8,
		"cost": {"food": 1},
		"threat": 0,
		"stress": -4
	},
	"battery_scan": {
		"name": "电池扫频",
		"score": 10,
		"cost": {"power": 1},
		"threat": 1,
		"stress": 0
	},
	"quiet_departure": {
		"name": "静默出发",
		"score": 6,
		"cost": {"fuel": 1},
		"threat": -1,
		"stress": 0
	}
}
const ORDER_DEFS := {
	"steady": {
		"name": "稳步推进",
		"score": 0,
		"reward_multiplier": 1.0,
		"threat": 0,
		"stress": 0,
		"failure_risk": 0,
		"protect_injury": false
	},
	"fallback": {
		"name": "遇险撤回",
		"score": -6,
		"reward_multiplier": 0.85,
		"threat": -1,
		"stress": -3,
		"failure_risk": -10,
		"protect_injury": true
	},
	"push": {
		"name": "强行推进",
		"score": 8,
		"reward_multiplier": 1.10,
		"threat": 1,
		"stress": 6,
		"failure_risk": 12,
		"protect_injury": false
	}
}
const OBJECTIVE_DEFS := {
	"balanced": {
		"name": "执行信号",
		"score": 0,
		"reward_multiplier": 1.0,
		"rescue_multiplier": 1.0,
		"threat": 0,
		"stress": 0,
		"failure_risk": 0,
		"brief": "按信号原目标行动。"
	},
	"rescue": {
		"name": "救援优先",
		"score": 4,
		"mismatch_score": -4,
		"reward_multiplier": 0.85,
		"rescue_multiplier": 1.35,
		"threat": 0,
		"stress": 2,
		"failure_risk": 0,
		"brief": "优先带人离开，物资少拿。"
	},
	"supply": {
		"name": "搜补给",
		"score": 3,
		"mismatch_score": -4,
		"reward_multiplier": 1.25,
		"rescue_multiplier": 0.5,
		"threat": 1,
		"stress": 1,
		"failure_risk": 4,
		"brief": "多装物资，救援效率下降。"
	},
	"scout": {
		"name": "侦查踩点",
		"score": 6,
		"reward_multiplier": 0.45,
		"rescue_multiplier": 0.5,
		"threat": 0,
		"stress": 0,
		"failure_risk": -6,
		"brief": "少拿东西，降低后续风险。"
	}
}
const TEAM_CHEMISTRY_DEFS := {
	"a_qing|xu_lan": {
		"name": "救援默契",
		"tags": ["rescue", "field", "medical"],
		"score": 5,
		"stress": -3
	},
	"lao_zhou|shen_luo": {
		"name": "后勤校准",
		"tags": ["radio", "repair", "supply", "trade"],
		"score": 4,
		"stress": -2
	},
	"a_qing|lao_zhou": {
		"name": "搜刮搭档",
		"tags": ["supply", "fuel", "trade"],
		"score": 4,
		"stress": -2
	},
	"lao_zhou|xu_lan": {
		"name": "救援分歧",
		"tags": ["rescue", "children", "family"],
		"score": -5,
		"stress": 4
	},
	"a_qing|shen_luo": {
		"name": "冒进争执",
		"tags": ["field", "repair"],
		"score": -3,
		"stress": 3
	}
}
const NIGHT_POLICY_DEFS := {
	"normal": {
		"name": "常规值守",
		"power_delta": 0,
		"listen_bonus": 0,
		"trust": 0,
		"influence": 0,
		"threat": 0,
		"stress": 0
	},
	"conserve": {
		"name": "节电守夜",
		"power_delta": -1,
		"listen_bonus": -1,
		"trust": -1,
		"influence": 0,
		"threat": 0,
		"stress": 2
	},
	"full_power": {
		"name": "全功率监听",
		"power_delta": 1,
		"listen_bonus": 1,
		"trust": 0,
		"influence": 1,
		"threat": 1,
		"stress": 0
	},
	"shelter": {
		"name": "安置优先",
		"power_delta": 1,
		"listen_bonus": -1,
		"trust": 1,
		"influence": 0,
		"threat": 0,
		"stress": -2,
		"shelter_relief": 2
	}
}
const NIGHT_CRISIS_RESPONSE_DEFS := {
	"hold": {
		"name": "硬扛",
		"brief": "不消耗，只承受危机后果。",
		"cost": {},
		"mitigation": 0,
		"matches": [],
		"stress": 1
	},
	"repair": {
		"name": "加固抢修",
		"brief": "消耗零件，缓冲设备和入口危机。",
		"cost": {"parts": 1},
		"mitigation": 2,
		"matches": ["antenna_fault", "gate_probe", "blackout"],
		"stress": 0
	},
	"medical": {
		"name": "医疗待命",
		"brief": "消耗药品，稳定停电和口粮恐慌。",
		"cost": {"medicine": 1},
		"mitigation": 2,
		"matches": ["blackout", "ration_pressure"],
		"trust": 1,
		"stress": -2
	},
	"radio": {
		"name": "守频追踪",
		"brief": "消耗电力，追踪天线和试探者动向。",
		"cost": {"power": 1},
		"mitigation": 1,
		"matches": ["antenna_fault", "gate_probe"],
		"influence": 1,
		"listen_bonus": 1,
		"stress": 2
	}
}
const CITY_ACTION_DEFS := {
	"warn": {
		"name": "广播预警",
		"cost": {"influence": 1},
		"risk": -4,
		"danger_trend": -1,
		"trust": 1,
		"flag": "warned",
		"brief": "提醒附近幸存者，减缓节点恶化。"
	},
	"route_mark": {
		"name": "投放路标",
		"cost": {"parts": 1},
		"risk": -8,
		"danger_trend": 0,
		"flag": "route_marked",
		"brief": "标出回撤路线，提升后续外勤准备。"
	},
	"cache": {
		"name": "补给缓存",
		"cost": {"food": 1},
		"risk": -3,
		"supplies_left": 1,
		"flag": "supply_cache",
		"brief": "留下临时物资，增加后续节点回报。"
	}
}
const REST_ACTION_DEFS := {
	"shared_meal": {
		"name": "热餐安抚",
		"cost": {"food": 1},
		"stress_all": -8,
		"brief": "全员压力下降。"
	},
	"stand_down": {
		"name": "轮休",
		"cost": {"food": 1},
		"stress_target": -6,
		"recover_tired": true,
		"brief": "疲惫成员恢复；无人疲惫时降低最高压力。"
	},
	"triage": {
		"name": "医务分诊",
		"cost": {"medicine": 1},
		"stress_target": -10,
		"recover": true,
		"brief": "优先处理伤疲成员。"
	},
	"debrief": {
		"name": "复盘谈话",
		"cost": {"influence": 1},
		"stress_target": -18,
		"trust": 1,
		"brief": "安抚压力最高成员。"
	}
}
const NIGHT_WATCH_DEFS := {
	"none": {
		"name": "无人加班",
		"brief": "不增加成员压力。",
		"stress": 0
	},
	"shen_luo": {
		"name": "Elias守频",
		"brief": "次日监听 +1。",
		"listen_bonus": 1,
		"stress": 7
	},
	"xu_lan": {
		"name": "Mara巡诊",
		"brief": "全员压力 -4。",
		"stress_relief": 4,
		"stress": 5
	},
	"lao_zhou": {
		"name": "Victor盘库",
		"brief": "夜间食物消耗 -1。",
		"food_save": 1,
		"stress": 5
	},
	"a_qing": {
		"name": "Nora巡夜",
		"brief": "暴露 -1，信任 +1。",
		"threat": -1,
		"trust": 1,
		"stress": 7
	}
}
const BASE_UPGRADE_DEFS := {
	"antenna": {
		"name": "增益天线",
		"max": 2,
		"costs": [2, 4],
		"effect": "监听时间 +1/级；锁定信号后的派遣更稳。"
	},
	"gate": {
		"name": "加固大门",
		"max": 2,
		"costs": [2, 4],
		"effect": "降低夜间试探和暴露危机的损失。"
	},
	"infirmary": {
		"name": "临时医务角",
		"max": 2,
		"costs": [2, 3],
		"effect": "夜间自动处理伤员；每级安置口粮压力 -1，高等级可缓解疲惫。"
	},
	"battery": {
		"name": "蓄电池组",
		"max": 2,
		"costs": [2, 4],
		"effect": "降低夜间电力消耗；停电危机损失更小。"
	}
}

class BaseBackdrop:
	extends Control

	func _draw() -> void:
		var rect := get_rect()
		draw_rect(rect, Color(0.010, 0.018, 0.018, 1.0), true)
		for i in range(9):
			var y := rect.size.y * (0.10 + float(i) * 0.095)
			draw_line(Vector2(0, y), Vector2(rect.size.x, y + 18.0), Color(0.08, 0.18, 0.18, 0.28), 2.0)
		for i in range(8):
			var x := rect.size.x * (0.08 + float(i) * 0.12)
			draw_line(Vector2(x, 0), Vector2(x - 55.0, rect.size.y), Color(0.08, 0.15, 0.16, 0.22), 1.0)
		var table := Rect2(Vector2(rect.size.x * 0.22, rect.size.y * 0.70), Vector2(rect.size.x * 0.58, rect.size.y * 0.20))
		draw_rect(table, Color(0.09, 0.075, 0.050, 0.68), true)
		draw_rect(table, Color(0.35, 0.23, 0.12, 0.42), false, 2.0)
		for i in range(6):
			var p := Vector2(rect.size.x * (0.28 + float(i) * 0.075), rect.size.y * 0.77)
			draw_circle(p, 8.0, Color(0.75, 0.52, 0.22, 0.32))
			draw_circle(p, 3.0, Color(1.0, 0.76, 0.36, 0.58))
		draw_circle(Vector2(rect.size.x * 0.70, rect.size.y * 0.25), 80.0, Color(0.22, 0.52, 0.55, 0.08))
		draw_circle(Vector2(rect.size.x * 0.70, rect.size.y * 0.25), 44.0, Color(0.24, 0.62, 0.70, 0.07))

class BaseFacilityBoard:
	extends Control

	var controller: Control

	func _gui_input(event: InputEvent) -> void:
		if controller == null:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var clicked := _facility_at(event.position)
			if clicked != "":
				controller.call("_buy_base_upgrade", clicked)

	func _draw() -> void:
		if controller == null:
			return
		var rect := get_rect()
		draw_rect(rect, Color(0.012, 0.020, 0.020, 0.96), true)
		var bg: Texture2D = controller.call("_load_texture", "res://assets/new/named/radio_room_topdown.png")
		var floor := Rect2(rect.size * Vector2(0.08, 0.16), rect.size * Vector2(0.84, 0.68))
		draw_rect(floor, Color(0.045, 0.058, 0.052, 0.90), true)
		if bg != null:
			draw_texture_rect(bg, floor, false, Color(1.0, 1.0, 1.0, 0.22))
		draw_rect(floor, Color(0.28, 0.54, 0.56, 0.72), false, 2.0)
		draw_line(floor.position + Vector2(0, floor.size.y * 0.52), floor.position + Vector2(floor.size.x, floor.size.y * 0.52), Color(0.22, 0.42, 0.44, 0.42), 2.0)
		draw_line(floor.position + Vector2(floor.size.x * 0.48, 0), floor.position + Vector2(floor.size.x * 0.48, floor.size.y), Color(0.22, 0.42, 0.44, 0.42), 2.0)
		for upgrade_id in ["antenna", "gate", "infirmary", "battery"]:
			_draw_facility(upgrade_id)
		var crisis_id := str((controller.get("pending_crisis") as Dictionary).get("id", ""))
		var target := _crisis_facility(crisis_id)
		if target != "":
			var pos := _facility_position(target)
			draw_circle(pos, 34.0, Color(1.0, 0.34, 0.22, 0.16))
			draw_circle(pos, 40.0, Color(1.0, 0.34, 0.22, 0.09))

	func _draw_facility(upgrade_id: String) -> void:
		var pos := _facility_position(upgrade_id)
		var level := int((controller.get("base_upgrades") as Dictionary).get(upgrade_id, 0))
		var pending := _crisis_facility(str((controller.get("pending_crisis") as Dictionary).get("id", ""))) == upgrade_id
		var color := Color(0.34, 0.78, 0.84, 0.96) if not pending else Color(1.0, 0.56, 0.28, 1.0)
		draw_circle(pos, 29.0, Color(color.r, color.g, color.b, 0.20))
		draw_circle(pos, 18.0, color)
		draw_string(get_theme_default_font(), pos + Vector2(-44, -34), _facility_short_name(upgrade_id), HORIZONTAL_ALIGNMENT_CENTER, 88, 14, Color(0.90, 0.96, 0.90))
		draw_string(get_theme_default_font(), pos + Vector2(-22, 38), "Lv.%d" % level, HORIZONTAL_ALIGNMENT_CENTER, 44, 13, Color(1.0, 0.84, 0.45))

	func _facility_position(upgrade_id: String) -> Vector2:
		var rect := get_rect()
		match upgrade_id:
			"antenna":
				return Vector2(rect.size.x * 0.50, rect.size.y * 0.17)
			"gate":
				return Vector2(rect.size.x * 0.19, rect.size.y * 0.70)
			"infirmary":
				return Vector2(rect.size.x * 0.70, rect.size.y * 0.36)
			"battery":
				return Vector2(rect.size.x * 0.70, rect.size.y * 0.70)
			_:
				return rect.size * 0.5

	func _facility_at(position: Vector2) -> String:
		for upgrade_id in ["antenna", "gate", "infirmary", "battery"]:
			if position.distance_to(_facility_position(upgrade_id)) <= 42.0:
				return upgrade_id
		return ""

	func _crisis_facility(crisis_id: String) -> String:
		match crisis_id:
			"antenna_fault":
				return "antenna"
			"gate_probe":
				return "gate"
			"blackout":
				return "battery"
			"ration_pressure":
				return "infirmary"
			_:
				return ""

	func _facility_short_name(upgrade_id: String) -> String:
		match upgrade_id:
			"antenna":
				return "天线"
			"gate":
				return "大门"
			"infirmary":
				return "医务"
			"battery":
				return "蓄电"
			_:
				return upgrade_id

class OperationTrack:
	extends Control

	var controller: Control

	func _gui_input(event: InputEvent) -> void:
		if controller == null:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var step := _step_at(event.position)
			match step:
				0:
					controller.call("_show_step", 0)
				1:
					controller.call("_show_step", 1)
				2:
					controller.call("_show_step", 2)
				3:
					if bool(controller.get("dispatched_today")):
						controller.call("_show_night_report")

	func _draw() -> void:
		if controller == null:
			return
		var rect := get_rect()
		draw_rect(rect, Color(0.020, 0.030, 0.030, 0.95), true)
		draw_rect(rect, Color(0.30, 0.56, 0.58, 0.72), false, 2.0)
		var active_step := _active_step()
		var labels := ["调频", "选点", "派遣", "入夜"]
		var details := [
			"听北桥" if bool(controller.call("_story_day1_mode")) else "监听 %d" % int(controller.get("listen_time")),
			_target_short_text(),
			"已完成" if bool(controller.get("dispatched_today")) else "待出发",
			"可结算" if bool(controller.get("dispatched_today")) else "等待"
		]
		var left_width := rect.size.x * 0.72
		var step_width := left_width / 4.0
		for index in range(4):
			var step_rect := Rect2(Vector2(float(index) * step_width + 12.0, 12.0), Vector2(step_width - 18.0, rect.size.y - 24.0))
			_draw_step(step_rect, labels[index], details[index], index, active_step)
			if index < 3:
				var y := step_rect.position.y + step_rect.size.y * 0.50
				draw_line(Vector2(step_rect.end.x + 2.0, y), Vector2(step_rect.end.x + 16.0, y), Color(0.30, 0.56, 0.58, 0.50), 2.0)
		_draw_alarm_panel(Rect2(Vector2(left_width + 12.0, 12.0), Vector2(rect.size.x - left_width - 24.0, rect.size.y - 24.0)))

	func _draw_step(step_rect: Rect2, label: String, detail: String, index: int, active_step: int) -> void:
		var completed := index < active_step
		var active := index == active_step
		var color := Color(0.48, 0.92, 0.70, 1.0) if completed else (Color(1.0, 0.82, 0.36, 1.0) if active else Color(0.36, 0.64, 0.68, 0.82))
		var bg := Color(color.r, color.g, color.b, 0.18 if active else 0.08)
		draw_rect(step_rect, bg, true)
		draw_rect(step_rect, Color(color.r, color.g, color.b, 0.82 if active else 0.36), false, 1.0 if active else 0.0)
		var center := step_rect.position + Vector2(22.0, step_rect.size.y * 0.50)
		draw_circle(center, 12.0, Color(color.r, color.g, color.b, 0.24))
		draw_circle(center, 6.0, color)
		draw_string(get_theme_default_font(), step_rect.position + Vector2(42.0, 25.0), label, HORIZONTAL_ALIGNMENT_LEFT, step_rect.size.x - 48.0, 17, Color(0.96, 1.0, 0.92))
		draw_string(get_theme_default_font(), step_rect.position + Vector2(42.0, 48.0), detail, HORIZONTAL_ALIGNMENT_LEFT, step_rect.size.x - 48.0, 12, Color(0.72, 0.86, 0.82))

	func _draw_alarm_panel(panel_rect: Rect2) -> void:
		if bool(controller.call("_story_day1_mode")):
			draw_rect(panel_rect, Color(0.030, 0.042, 0.040, 0.94), true)
			draw_rect(panel_rect, Color(0.72, 0.94, 1.0, 0.52), false, 1.0)
			draw_string(get_theme_default_font(), panel_rect.position + Vector2(12.0, 24.0), "值班提示", HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 24.0, 15, Color(1.0, 0.84, 0.45))
			draw_string(get_theme_default_font(), panel_rect.position + Vector2(12.0, 50.0), "先听清求救", HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 24.0, 13, Color(0.82, 0.94, 0.90))
			draw_string(get_theme_default_font(), panel_rect.position + Vector2(12.0, 72.0), "数字稍后再交给你", HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 24.0, 12, Color(0.72, 0.86, 0.82))
			return
		var resources: Dictionary = controller.get("resources")
		var threat := int(resources.get("threat", 0))
		var trust := int(resources.get("trust", 0))
		var crisis: Dictionary = controller.get("pending_crisis")
		var threat_color := Color(1.0, 0.38, 0.30, 1.0) if threat >= 3 else (Color(1.0, 0.78, 0.34, 1.0) if threat > 0 else Color(0.46, 0.92, 0.70, 1.0))
		draw_rect(panel_rect, Color(0.030, 0.042, 0.040, 0.94), true)
		draw_rect(panel_rect, Color(threat_color.r, threat_color.g, threat_color.b, 0.72), false, 1.0)
		draw_string(get_theme_default_font(), panel_rect.position + Vector2(12.0, 23.0), "基地警戒", HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 24.0, 15, Color(1.0, 0.84, 0.45))
		var gauge_pos := panel_rect.position + Vector2(12.0, 34.0)
		for index in range(5):
			var tick := Rect2(gauge_pos + Vector2(float(index) * 22.0, 0.0), Vector2(16.0, 8.0))
			draw_rect(tick, threat_color if index < threat else Color(0.16, 0.28, 0.28, 0.9), true)
		var crisis_text := str(crisis.get("title", "无预警")) if not crisis.is_empty() else "无预警"
		draw_string(get_theme_default_font(), panel_rect.position + Vector2(12.0, 61.0), "暴露 %d  信任 %d" % [threat, trust], HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 24.0, 13, Color(0.82, 0.94, 0.90))
		draw_string(get_theme_default_font(), panel_rect.position + Vector2(12.0, 79.0), crisis_text, HORIZONTAL_ALIGNMENT_LEFT, panel_rect.size.x - 24.0, 12, Color(0.72, 0.86, 0.82))

	func _active_step() -> int:
		if bool(controller.get("dispatched_today")):
			return 3
		var locked: Array = controller.get("locked_signal_ids")
		if locked.is_empty():
			return 0
		if bool(controller.call("_story_day1_mode")):
			var confirmations: Dictionary = controller.get("signal_confirmations")
			if not confirmations.has("d1_north_bridge_help"):
				return 0
		if not bool(controller.call("_has_dispatch_target")):
			return 1
		return 2

	func _target_short_text() -> String:
		var selected_id := str(controller.get("selected_location_id"))
		var locations: Dictionary = controller.get("locations")
		if selected_id == "" or not locations.has(selected_id):
			return "未定"
		return str((locations[selected_id] as Dictionary).get("name", selected_id))

	func _step_at(position: Vector2) -> int:
		var left_width := size.x * 0.72
		if position.x >= left_width:
			return 3
		var step_width := left_width / 4.0
		return clamp(int(floor(position.x / max(1.0, step_width))), 0, 3)

var rng := RandomNumberGenerator.new()
var day := 1
var resources := {
	"power": 8,
	"food": 10,
	"medicine": 6,
	"trust": 50,
	"fuel": 3,
	"parts": 4,
	"influence": 0,
	"threat": 0,
	"rescued": 0
}
var members: Dictionary = {}
var locations: Dictionary = {}
var items: Dictionary = {}
var signals: Array[Dictionary] = []
var day_signals: Array[Dictionary] = []
var locked_signal_ids: Array[String] = []
var signal_marks: Dictionary = {}
var signal_confirmations: Dictionary = {}
var team_bonds: Dictionary = {}
var listen_time := 3
var selected_location_id := "north_bridge"
var dispatched_today := false
var last_dispatch_result: Dictionary = {}
var pending_dispatch_context: Dictionary = {}
var dispatch_animation_pending := false
var base_upgrades := {}
var pending_crisis: Dictionary = {}
var night_report_lines: Array[String] = []
var night_report_events: Array[Dictionary] = []
var night_report_summary: Dictionary = {}
var final_report: Dictionary = {}
var intel_reviews: Array[Dictionary] = []
var night_policy_id := "normal"
var night_crisis_response_id := "hold"
var night_watch_member_id := "none"
var rest_actions_used: Array[String] = []
var pending_rest_report_lines: Array[String] = []
var next_day_listen_bonus := 0
var day_stance_id := "balanced"
var current_directive: Dictionary = {}
var directive_resolved := false
var directive_success_count := 0
var logs: Array[String] = []
var intro_dismissed := false

var resource_box: VBoxContainer
var member_box: VBoxContainer
var tuning_slot: Control
var city_slot: Control
var dispatch_slot: Control
var base_slot: Control
var log_body: RichTextLabel
var day_label: Label
var status_label: Label
var report_button: Button
var main_tabs: TabContainer
var overlay_layer: Control
var operation_track: OperationTrack

func _ready() -> void:
	rng.randomize()
	_load_data()
	_init_base_upgrades()
	_build_ui()
	_start_day(1)
	if not intro_dismissed:
		_show_intro_briefing()

func _load_data() -> void:
	members = _array_to_dict(_load_json_array(MEMBERS_PATH))
	locations = _array_to_dict(_load_json_array(LOCATIONS_PATH))
	items = _array_to_dict(_load_json_array(ITEMS_PATH))
	_normalize_member_data()
	_normalize_location_data()
	signals = []
	for entry in _load_json_array(SIGNALS_PATH):
		signals.append(entry as Dictionary)

func _load_json_array(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Missing data file: %s" % path)
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid JSON array: %s" % path)
		return []
	return parsed

func _array_to_dict(entries: Array) -> Dictionary:
	var result := {}
	for entry in entries:
		var data := entry as Dictionary
		result[str(data.get("id", ""))] = data
	return result

func _init_base_upgrades() -> void:
	for upgrade_id in BASE_UPGRADE_DEFS.keys():
		if not base_upgrades.has(upgrade_id):
			base_upgrades[upgrade_id] = 0

func _normalize_member_data() -> void:
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		if not member.has("stress"):
			member["stress"] = 0
		if not member.has("dispatch_count"):
			member["dispatch_count"] = 0
		if not member.has("values"):
			match str(member_id):
				"shen_luo":
					member["values"] = ["radio", "repair"]
				"xu_lan":
					member["values"] = ["rescue", "medical"]
				"lao_zhou":
					member["values"] = ["trade", "supply"]
				"a_qing":
					member["values"] = ["field", "rescue"]
				_:
					member["values"] = []

func _normalize_location_data() -> void:
	for location_id in locations.keys():
		var location: Dictionary = locations[location_id]
		var location_type := str(location.get("type", ""))
		if not location.has("supplies_left"):
			location["supplies_left"] = _default_location_supplies(location_type)
		if not location.has("people_left"):
			location["people_left"] = 2 if location_type == "rescue" else 0
		if not location.has("faction"):
			location["faction"] = _default_location_faction(location_type)
		if not location.has("danger_trend"):
			location["danger_trend"] = 0
		if not location.has("last_visit_day"):
			location["last_visit_day"] = 0
		if not location.has("flags"):
			location["flags"] = []

func _default_location_supplies(location_type: String) -> int:
	match location_type:
		"medical":
			return 2
		"supply":
			return 2
		"rescue":
			return 1
		_:
			return 0

func _default_location_faction(location_type: String) -> String:
	match location_type:
		"base":
			return "base"
		"medical":
			return "clinic"
		"supply":
			return "scavengers"
		_:
			return "civilians"

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var solid_bg := ColorRect.new()
	solid_bg.color = Color(0.010, 0.018, 0.018, 1.0)
	solid_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(solid_bg)

	var bg := BaseBackdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var tint := ColorRect.new()
	tint.color = Color(0.015, 0.025, 0.026, 0.52)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(tint)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	root.add_child(header)

	var title := Label.new()
	title.text = "最后电台：生存切片"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	header.add_child(title)

	day_label = Label.new()
	day_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	day_label.add_theme_font_size_override("font_size", 23)
	day_label.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	header.add_child(day_label)

	var restart := Button.new()
	restart.text = "重开切片"
	restart.custom_minimum_size = Vector2(130, 42)
	restart.pressed.connect(func() -> void:
		_reset_run()
	)
	header.add_child(restart)

	var command_strip := HBoxContainer.new()
	command_strip.add_theme_constant_override("separation", 12)
	root.add_child(command_strip)

	operation_track = OperationTrack.new()
	operation_track.controller = self
	operation_track.custom_minimum_size = Vector2(0, 96)
	operation_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	operation_track.mouse_filter = Control.MOUSE_FILTER_STOP
	command_strip.add_child(operation_track)

	var command_right := VBoxContainer.new()
	command_right.custom_minimum_size = Vector2(240, 96)
	command_right.add_theme_constant_override("separation", 8)
	command_strip.add_child(command_right)

	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	command_right.add_child(status_label)

	report_button = Button.new()
	report_button.text = "夜间结算"
	report_button.custom_minimum_size = Vector2(0, 40)
	report_button.pressed.connect(_show_night_report)
	command_right.add_child(report_button)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 0)
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)

	resource_box = VBoxContainer.new()
	resource_box.add_theme_constant_override("separation", 8)
	left.add_child(_panel(resource_box))

	member_box = VBoxContainer.new()
	member_box.add_theme_constant_override("separation", 8)
	var member_panel := _panel(member_box)
	member_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(member_panel)

	main_tabs = TabContainer.new()
	main_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_tabs.tab_changed.connect(func(_tab: int) -> void:
		if operation_track != null:
			operation_track.queue_redraw()
	)
	body.add_child(main_tabs)

	tuning_slot = Control.new()
	tuning_slot.name = "1 调频"
	tuning_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tuning_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_tabs.add_child(tuning_slot)

	city_slot = Control.new()
	city_slot.name = "2 城市"
	city_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_tabs.add_child(city_slot)

	dispatch_slot = Control.new()
	dispatch_slot.name = "3 派遣"
	dispatch_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_tabs.add_child(dispatch_slot)

	base_slot = Control.new()
	base_slot.name = "4 基地"
	base_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_tabs.add_child(base_slot)

	var log_panel_content := VBoxContainer.new()
	log_panel_content.add_theme_constant_override("separation", 8)
	var log_panel := _panel(log_panel_content)
	log_panel.custom_minimum_size = Vector2(260, 0)
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(log_panel)

	var log_title := Label.new()
	log_title.text = "电台日志"
	log_title.add_theme_font_size_override("font_size", 22)
	log_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	log_panel_content.add_child(log_title)

	log_body = RichTextLabel.new()
	log_body.fit_content = false
	log_body.bbcode_enabled = false
	log_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_body.add_theme_font_size_override("normal_font_size", 14)
	log_body.add_theme_color_override("default_color", Color(0.78, 0.88, 0.84))
	log_panel_content.add_child(log_body)

	overlay_layer = Control.new()
	overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_layer)

func _panel(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.040, 0.040, 0.92)
	style.border_color = Color(0.32, 0.56, 0.60, 0.76)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	margin.add_child(content)
	return panel

func _show_intro_briefing() -> void:
	if overlay_layer == null:
		return
	_clear(overlay_layer)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.54)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_layer.add_child(shade)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(860, 520)
	card.size = Vector2(860, 520)
	card.position = Vector2(210, 100)
	card.add_theme_stylebox_override("panel", _final_panel_style(Color(0.014, 0.022, 0.022, 0.96), Color(0.72, 0.94, 1.0, 0.82), 2))
	overlay_layer.add_child(card)

	var stack := Control.new()
	stack.clip_contents = true
	card.add_child(stack)

	var bg := TextureRect.new()
	bg.texture = _load_texture("res://assets/new/named/radio_room_interior.png")
	if bg.texture == null:
		bg.texture = _load_texture("res://assets/new/named/lighthouse_keyart.png")
	bg.modulate = Color(1.0, 1.0, 1.0, 0.28)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(bg)

	var tint := ColorRect.new()
	tint.color = Color(0.0, 0.0, 0.0, 0.46)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(tint)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	stack.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "停电第六天"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(title)

	var role := Label.new()
	role.text = "城市广播塔倒下后，电话、网络和官方频道一起沉默。旧体育馆被临时改成避难基地，灯光靠蓄电池撑着，门外每天都有新的求救和假信号。"
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.add_theme_font_size_override("font_size", 18)
	role.add_theme_color_override("font_color", Color(0.90, 0.98, 0.94))
	root.add_child(role)

	var identity := Label.new()
	identity.text = "你不是士兵，也不是市长。你是这座基地的 radio officer：戴着耳机判断哪段声音是真的，决定外勤队去哪条路，晚上把坏消息报给所有还醒着的人。"
	identity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_theme_font_size_override("font_size", 17)
	identity.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	root.add_child(identity)

	var goals := Label.new()
	goals.text = "三夜目标\n1. 从噪声里锁定可靠信号\n2. 派外勤带回幸存者和物资\n3. 控制暴露、疲惫和基地信任"
	goals.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goals.add_theme_font_size_override("font_size", 17)
	goals.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	root.add_child(goals)

	var hint := Label.new()
	hint.text = "第一班只做一件事：先锁定一条求救信号，再派一支外勤队出去。后续每天会开放更多选择，先别管全部参数。疲惫成员仍可出发，但准备 -8；轮休、医务角和部分夜间安排可以恢复。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	root.add_child(hint)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	var start := Button.new()
	start.text = "开始值班"
	start.custom_minimum_size = Vector2(180, 48)
	start.size_flags_horizontal = Control.SIZE_SHRINK_END
	start.pressed.connect(_dismiss_intro_briefing)
	root.add_child(start)

func _dismiss_intro_briefing() -> void:
	intro_dismissed = true
	if overlay_layer != null:
		_clear(overlay_layer)
		overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show_step(0)

func _reset_run() -> void:
	resources = {
		"power": 8,
		"food": 10,
		"medicine": 6,
		"trust": 50,
		"fuel": 3,
		"parts": 4,
		"influence": 0,
		"threat": 0,
		"rescued": 0
	}
	_load_data()
	team_bonds.clear()
	base_upgrades = {
		"antenna": 0,
		"gate": 0,
		"infirmary": 0,
		"battery": 0
	}
	_init_base_upgrades()
	pending_crisis.clear()
	night_report_lines.clear()
	night_report_events.clear()
	night_report_summary.clear()
	final_report.clear()
	intel_reviews.clear()
	night_policy_id = "normal"
	night_crisis_response_id = "hold"
	night_watch_member_id = "none"
	rest_actions_used.clear()
	pending_rest_report_lines.clear()
	next_day_listen_bonus = 0
	day_stance_id = "balanced"
	current_directive.clear()
	directive_resolved = false
	directive_success_count = 0
	logs.clear()
	logs.append("停电第六天：旧体育馆电台重新接线，三夜值班开始。")
	intro_dismissed = false
	_start_day(1)
	_show_intro_briefing()

func _start_day(new_day: int) -> void:
	day = new_day
	locked_signal_ids.clear()
	signal_marks.clear()
	signal_confirmations.clear()
	dispatched_today = false
	last_dispatch_result.clear()
	pending_dispatch_context.clear()
	night_report_lines.clear()
	night_report_events.clear()
	night_report_summary.clear()
	current_directive = _directive_for_day(day)
	directive_resolved = false
	if day == 1:
		final_report.clear()
	listen_time = 3
	listen_time += int(base_upgrades.get("antenna", 0))
	if next_day_listen_bonus != 0:
		listen_time = max(1, listen_time + next_day_listen_bonus)
		logs.append("Day %d：昨夜值守策略调整监听时间 %+d。" % [day, next_day_listen_bonus])
		next_day_listen_bonus = 0
	night_policy_id = "normal"
	night_crisis_response_id = "hold"
	night_watch_member_id = "none"
	rest_actions_used.clear()
	pending_rest_report_lines.clear()
	day_stance_id = "balanced"
	selected_location_id = "north_bridge" if day == 1 else ("school" if day == 2 else "base")
	if day == 3 and (int(resources["power"]) < 5 or _locked_count_before_day_three() < 3):
		listen_time = max(1, listen_time - 1)
		logs.append("Day 3：前两天的电力和监听不足让噪声变重，今天监听时间减少。")
	day_signals = []
	for signal_data in signals:
		if int(signal_data.get("day", 0)) == day:
			day_signals.append(signal_data)
	pending_crisis = _roll_night_crisis()
	if not current_directive.is_empty():
		logs.append("Day %d 今日委托「%s」：%s 奖励 %s，失手 %s。" % [
			day,
			str(current_directive.get("title", "")),
			str(current_directive.get("brief", "")),
			_format_resource_delta(current_directive.get("reward", {}) as Dictionary),
			_format_resource_delta(current_directive.get("failure", {}) as Dictionary)
		])
	if not pending_crisis.is_empty():
		logs.append("Day %d：夜间风险预警「%s」。" % [day, str(pending_crisis.get("title", ""))])
	_refresh_all()
	_show_step(0)

func _locked_count_before_day_three() -> int:
	var count := 0
	for log_line in logs:
		if str(log_line).find("锁定信号") >= 0:
			count += 1
	return count

func _directive_for_day(new_day: int) -> Dictionary:
	if DAILY_DIRECTIVE_DEFS.has(new_day):
		return (DAILY_DIRECTIVE_DEFS[new_day] as Dictionary).duplicate(true)
	return {}

func _roll_night_crisis() -> Dictionary:
	if day == 3:
		return {
			"id": "antenna_fault",
			"title": "楼顶天线偏转",
			"summary": "如果今天不修理天线，夜里会损失电力和远距监听稳定性。"
		}
	if int(resources.get("threat", 0)) >= 3:
		return {
			"id": "gate_probe",
			"title": "陌生人试探大门",
			"summary": "暴露度偏高，夜里可能有人摸到基地入口。"
		}
	if int(resources.get("power", 0)) <= 3:
		return {
			"id": "blackout",
			"title": "蓄电不足",
			"summary": "电力低于安全线，夜里可能出现停电。"
		}
	if int(resources.get("food", 0)) <= 4:
		return {
			"id": "ration_pressure",
			"title": "口粮争执",
			"summary": "食物库存太低，成员开始质疑配给。"
		}
	return {}

func _refresh_all() -> void:
	day_label.text = "DAY %d / 3" % day
	_refresh_resources()
	_refresh_members()
	_refresh_tuning()
	_refresh_city()
	_refresh_dispatch()
	_refresh_base()
	_refresh_logs()
	_refresh_objective()

func _refresh_objective() -> void:
	if report_button != null:
		report_button.disabled = not dispatched_today or not pending_dispatch_context.is_empty()
		report_button.text = "等待回传指令" if not pending_dispatch_context.is_empty() else ("查看夜间结算" if dispatched_today else "夜间结算")
		report_button.modulate = Color(1.0, 0.92, 0.62) if dispatched_today else Color.WHITE
	if operation_track != null:
		operation_track.queue_redraw()
	var directive_line := _directive_status_line()
	if locked_signal_ids.is_empty():
		status_label.text = "%s\n下一步：点击「听清这段求救」。先不用管资源和概率。" % directive_line if _story_day1_mode() else "%s\n行动指令：调频锁定 1 条信号，确认目标地点和完整情报。" % directive_line
		return
	if _story_day1_mode() and not signal_confirmations.has("d1_north_bridge_help"):
		status_label.text = "%s\n下一步：点击「呼叫确认」，确认这不是循环录音。" % directive_line
		return
	if not _has_dispatch_target():
		status_label.text = "%s\n下一步：把北桥设为目标，准备派外勤。" % directive_line if _story_day1_mode() else "%s\n行动指令：把已锁定信号标为今日目标，或在城市地图点选节点。" % directive_line
		return
	if not dispatched_today:
		var location: Dictionary = locations.get(selected_location_id, {})
		status_label.text = "%s\n下一步：问一名队员，选两名外勤和路线，然后派出。" % directive_line if _story_day1_mode() else "%s\n行动指令：目标「%s」。组队、押路线，派出外勤队。" % [directive_line, str(location.get("name", "未知节点"))]
		return
	status_label.text = "%s\n下一步：查看夜间结算。" % directive_line if _story_day1_mode() else "%s\n行动指令：外勤回传完毕。入夜结算消耗、危机和成员状态。" % directive_line

func _directive_status_line() -> String:
	if current_directive.is_empty():
		return "今日委托：无"
	if _story_day1_mode():
		return "今日委托：北桥求救（先听清，再确认，再派人）"
	var reward_text := _format_resource_delta(current_directive.get("reward", {}) as Dictionary)
	var state := "已结算" if directive_resolved else "待确认"
	return "今日委托：%s（%s） 奖励 %s" % [
		str(current_directive.get("title", "")),
		state,
		reward_text
	]

func _has_dispatch_target() -> bool:
	return selected_location_id != "" and locations.has(selected_location_id)

func _story_day1_mode() -> bool:
	return day == 1

func _story_shift_brief_text() -> String:
	if locked_signal_ids.is_empty():
		return "你坐在旧体育馆电台前。\n\n现在只做一件事：听清北桥那段求救。\n\n下一步：点击中间的「听清这段求救」。"
	if not signal_confirmations.has("d1_north_bridge_help"):
		return "北桥信号已经听清。\n\n它提到三楼、孩子和暖气管，但你还需要确认这不是录音。\n\n下一步：点击「呼叫确认」。"
	if not dispatched_today:
		return "三下敲击回来了。\n\n现在该决定派谁出去、走哪条路。\n\n下一步：进入派遣，问一名队员，然后派出外勤。"
	if not pending_dispatch_context.is_empty():
		return "外勤队已经到楼下。\n\n他们在等你给现场指令。\n\n下一步：选择一条回传指令。"
	return "北桥外勤已经回传。\n\n下一步：查看夜间结算，看看这次选择带来的后果。"

func _show_step(tab_index: int) -> void:
	if main_tabs == null:
		return
	if tab_index >= 0 and tab_index < main_tabs.get_tab_count():
		main_tabs.current_tab = tab_index
	if operation_track != null:
		operation_track.queue_redraw()

func _refresh_resources() -> void:
	for child in resource_box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "当前值班" if _story_day1_mode() else "基地资源"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	resource_box.add_child(title)
	if _story_day1_mode():
		var brief := Label.new()
		brief.text = _story_shift_brief_text()
		brief.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		brief.add_theme_font_size_override("font_size", 15)
		brief.add_theme_color_override("font_color", Color(0.84, 0.94, 0.90))
		resource_box.add_child(brief)
		return
	for key in ["power", "food", "medicine", "fuel", "parts", "trust", "influence", "threat", "rescued"]:
		var label := Label.new()
		label.text = "%s：%d" % [_resource_name(key), int(resources.get(key, 0))]
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", Color(1.0, 0.46, 0.38) if key == "threat" and int(resources[key]) > 0 else Color(0.84, 0.94, 0.90))
		resource_box.add_child(label)

func _refresh_members() -> void:
	for child in member_box.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = "可询问的人" if _story_day1_mode() else "成员"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	member_box.add_child(title)
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		member_box.add_child(row)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(34, 34)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var texture_path := str(member.get("portrait", ""))
		portrait.texture = _load_texture(texture_path)
		row.add_child(portrait)
		var text := Label.new()
		if _story_day1_mode():
			text.text = "%s / %s\n%s" % [
				str(member.get("name", member_id)),
				_status_label(str(member.get("status", "normal"))),
				str(member.get("role", ""))
			]
		else:
			text.text = "%s / %s / 压力 %d\n%s" % [
				str(member.get("name", member_id)),
				_status_label(str(member.get("status", "normal"))),
				int(member.get("stress", 0)),
				str(member.get("role", ""))
			]
		text.tooltip_text = _member_status_help(str(member.get("status", "normal")))
		text.custom_minimum_size = Vector2(170, 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_OFF
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.add_theme_font_size_override("font_size", 12)
		text.add_theme_color_override("font_color", Color(0.82, 0.92, 0.88))
		row.add_child(text)
		var status_help := _member_status_help(str(member.get("status", "normal")))
		if status_help != "":
			var hint := Label.new()
			hint.text = status_help
			hint.custom_minimum_size = Vector2(170, 0)
			hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hint.add_theme_font_size_override("font_size", 10)
			hint.add_theme_color_override("font_color", Color(0.68, 0.82, 0.78))
			member_box.add_child(hint)

func _refresh_tuning() -> void:
	_clear(tuning_slot)
	var panel := TUNING_SCENE.instantiate()
	panel.signal_locked.connect(_lock_signal)
	panel.signal_forced_locked.connect(_force_lock_signal)
	panel.signal_target_requested.connect(_select_location)
	panel.signal_marked.connect(_mark_signal)
	panel.signal_refined.connect(_refine_signal)
	panel.signal_confirm_requested.connect(_confirm_signal)
	tuning_slot.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.setup(_tuning_signals_with_context(), locked_signal_ids, listen_time, resources, signal_marks, signal_confirmations)

func _tuning_signals_with_context() -> Array[Dictionary]:
	var contextual: Array[Dictionary] = []
	for signal_data in day_signals:
		var entry := (signal_data as Dictionary).duplicate(true)
		var location_id := str(entry.get("location", ""))
		var location: Dictionary = locations.get(location_id, {})
		var urgency := _signal_urgency(entry, location)
		entry["urgency"] = urgency
		entry["urgency_label"] = _urgency_label(urgency)
		entry["ignore_preview"] = _signal_ignore_preview(entry, location)
		var mark_id := str(signal_marks.get(str(entry.get("id", "")), ""))
		entry["player_mark"] = mark_id
		entry["mark_score"] = _signal_mark_score(entry, mark_id)
		entry["confirmed_by_call"] = signal_confirmations.has(str(entry.get("id", "")))
		contextual.append(entry)
	return contextual

func _signal_urgency(signal_data: Dictionary, location: Dictionary) -> int:
	var urgency := 1
	var need_tags: Array = signal_data.get("need_tags", [])
	var failure: Dictionary = signal_data.get("failure", {})
	if need_tags.has("rescue") or int(location.get("people_left", 0)) > 0:
		urgency += 2 + min(2, int(location.get("people_left", 0)))
	if failure.has("trust") and int(failure.get("trust", 0)) < 0:
		urgency += 1
	if failure.has("threat") and int(failure.get("threat", 0)) > 0:
		urgency += 1
	if int(location.get("danger_trend", 0)) > 0:
		urgency += min(2, int(location.get("danger_trend", 0)))
	if int(signal_data.get("listen_cost", 1)) > listen_time:
		urgency += 1
	return clamp(urgency, 1, 5)

func _urgency_label(urgency: int) -> String:
	if urgency >= 5:
		return "危急"
	if urgency >= 4:
		return "高"
	if urgency >= 3:
		return "中"
	return "低"

func _signal_ignore_preview(signal_data: Dictionary, location: Dictionary) -> String:
	if location.is_empty():
		return "忽视：目标未确认。"
	if int(location.get("people_left", 0)) > 0 or (signal_data.get("need_tags", []) as Array).has("rescue"):
		return "忽视：信任 -1，危险趋势 +1，Mara Vale压力 +12。"
	var failure: Dictionary = signal_data.get("failure", {})
	if failure.is_empty():
		return "忽视：暂无直接损失，但会错过今日窗口。"
	return "若错过后失败：%s。" % _format_delta_preview(failure)

func _format_delta_preview(delta: Dictionary) -> String:
	var parts: Array[String] = []
	for key in delta.keys():
		var value := int(delta[key])
		parts.append("%s %+d" % [_resource_name(str(key)), value])
	return "，".join(parts)

func _refresh_city() -> void:
	_clear(city_slot)
	var panel := CITY_SCENE.instantiate()
	panel.location_selected.connect(_select_location)
	panel.city_action_requested.connect(_apply_city_action)
	city_slot.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.setup(locations, selected_location_id, _tuning_signals_with_context(), locked_signal_ids, signal_marks, resources, CITY_ACTION_DEFS)

func _refresh_dispatch() -> void:
	_clear(dispatch_slot)
	var panel := DISPATCH_SCENE.instantiate()
	panel.dispatch_launched.connect(_launch_dispatch)
	panel.field_choice_selected.connect(_resolve_pending_dispatch)
	dispatch_slot.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_result := last_dispatch_result.duplicate(true)
	if dispatch_animation_pending and dispatched_today and not panel_result.is_empty():
		panel_result["ui_phase"] = "transmitting"
		dispatch_animation_pending = false
	panel.setup(members, items, _dispatch_panel_location(), dispatched_today, Callable(self, "_dispatch_preview"), panel_result)

func _dispatch_panel_location() -> Dictionary:
	var location: Dictionary = locations.get(selected_location_id, {}).duplicate(true)
	if location.is_empty():
		return location
	var linked_signal := _best_signal_for_location(selected_location_id)
	location["mission_tags"] = _mission_tags(location, linked_signal)
	location["linked_signal_title"] = str(linked_signal.get("title", ""))
	location["signal_image"] = str(linked_signal.get("image", ""))
	location["linked_signal_locked"] = not linked_signal.is_empty() and locked_signal_ids.has(str(linked_signal.get("id", "")))
	location["signal_confidence"] = str(linked_signal.get("confidence", "unknown"))
	location["signal_noise"] = int(linked_signal.get("noise", 0))
	location["signal_intel_score"] = _signal_intel_score(linked_signal)
	var mark_id := str(signal_marks.get(str(linked_signal.get("id", "")), ""))
	location["signal_mark"] = mark_id
	location["signal_mark_score"] = _signal_mark_score(linked_signal, mark_id)
	location["signal_confirmed"] = signal_confirmations.has(str(linked_signal.get("id", "")))
	location["story_intro"] = str(linked_signal.get("story_intro", ""))
	location["advisor_lines"] = (linked_signal.get("advisor_lines", {}) as Dictionary).duplicate(true)
	location["field_choice"] = (linked_signal.get("field_choice", {}) as Dictionary).duplicate(true)
	location["outcome_story"] = (linked_signal.get("outcome_story", {}) as Dictionary).duplicate(true)
	location["active_signal_id"] = str(linked_signal.get("id", ""))
	location["memory_score"] = _location_memory_score(location)
	location["memory_text"] = _location_memory_text(location)
	location["signal_reward"] = (linked_signal.get("reward", {}) as Dictionary).duplicate(true)
	location["signal_failure"] = (linked_signal.get("failure", {}) as Dictionary).duplicate(true)
	location["signal_result"] = str(linked_signal.get("result", ""))
	location["route_defs"] = ROUTE_DEFS.duplicate(true)
	location["prep_defs"] = PREP_DEFS.duplicate(true)
	location["broadcast_defs"] = BROADCAST_DEFS.duplicate(true)
	location["order_defs"] = ORDER_DEFS.duplicate(true)
	location["objective_defs"] = OBJECTIVE_DEFS.duplicate(true)
	location["team_chemistry_defs"] = TEAM_CHEMISTRY_DEFS.duplicate(true)
	location["team_bonds"] = team_bonds.duplicate(true)
	location["resources"] = resources.duplicate(true)
	location["current_directive"] = current_directive.duplicate(true)
	location["directive_resolved"] = directive_resolved
	location["day"] = day
	location["day_stance_id"] = day_stance_id
	location["day_stance_defs"] = DAY_STANCE_DEFS.duplicate(true)
	location["night_forecast"] = _night_forecast_for_target(selected_location_id)
	return location

func _night_forecast_for_target(target_location_id: String) -> Array[String]:
	var lines: Array[String] = []
	var ignored_names: Array[String] = []
	for location_id in locations.keys():
		if str(location_id) == "base" or str(location_id) == target_location_id:
			continue
		var location: Dictionary = locations[location_id]
		if str(location.get("type", "")) != "rescue":
			continue
		if int(location.get("people_left", 0)) <= 0:
			continue
		if int(location.get("last_visit_day", 0)) == day:
			continue
		ignored_names.append(str(location.get("name", location_id)))
	if not ignored_names.is_empty():
		lines.append("忽视 %s：信任 -%d，危险趋势 +1。" % ["、".join(ignored_names), ignored_names.size()])
		lines.append("Mara Vale压力 +%d。" % (12 * ignored_names.size()))
	if pending_crisis.is_empty():
		lines.append("夜间危机：无预警。")
	else:
		lines.append("夜间危机：%s。" % str(pending_crisis.get("title", "")))
	return lines

func _refresh_base() -> void:
	if base_slot == null:
		return
	_clear(base_slot)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	var panel := _panel(content)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base_slot.add_child(panel)

	var title := Label.new()
	title.text = "基地升级"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	content.add_child(title)

	var stock := Label.new()
	stock.text = "可用零件：%d" % int(resources.get("parts", 0))
	stock.add_theme_font_size_override("font_size", 15)
	stock.add_theme_color_override("font_color", Color(0.84, 0.94, 0.90))
	content.add_child(stock)

	if not pending_crisis.is_empty():
		var warning := Label.new()
		warning.text = "今晚风险：%s" % str(pending_crisis.get("summary", pending_crisis.get("title", "")))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warning.add_theme_font_size_override("font_size", 13)
		warning.add_theme_color_override("font_color", Color(1.0, 0.70, 0.42))
		content.add_child(warning)

	var board_row := HBoxContainer.new()
	board_row.add_theme_constant_override("separation", 12)
	board_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(board_row)

	var board := BaseFacilityBoard.new()
	board.controller = self
	board.custom_minimum_size = Vector2(360, 0)
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.mouse_filter = Control.MOUSE_FILTER_STOP
	board_row.add_child(board)

	var details_scroll := ScrollContainer.new()
	details_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	board_row.add_child(details_scroll)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	details_scroll.add_child(details)

	var hint := Label.new()
	hint.text = "点击基地平面图上的设施进行升级。危机对应设施会发出橙色警戒。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.72, 0.94, 1.0))
	details.add_child(hint)

	var rest_title := Label.new()
	rest_title.text = "休整行动"
	rest_title.add_theme_font_size_override("font_size", 16)
	rest_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	details.add_child(rest_title)

	var rest_row := VBoxContainer.new()
	rest_row.add_theme_constant_override("separation", 6)
	details.add_child(rest_row)
	_add_rest_action_button(rest_row, "shared_meal")
	_add_rest_action_button(rest_row, "stand_down")
	_add_rest_action_button(rest_row, "triage")
	_add_rest_action_button(rest_row, "debrief")

	var stance_title := Label.new()
	stance_title.text = "今日准则"
	stance_title.add_theme_font_size_override("font_size", 16)
	stance_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	details.add_child(stance_title)

	var stance_grid := VBoxContainer.new()
	stance_grid.add_theme_constant_override("separation", 5)
	details.add_child(stance_grid)
	for stance_id in ["balanced", "aid", "salvage", "quiet"]:
		_add_day_stance_button(stance_grid, str(stance_id))

	if not pending_crisis.is_empty():
		var response_title := Label.new()
		response_title.text = "危机应对"
		response_title.add_theme_font_size_override("font_size", 16)
		response_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
		details.add_child(response_title)

		var response_row := HBoxContainer.new()
		response_row.add_theme_constant_override("separation", 6)
		details.add_child(response_row)
		_add_crisis_response_button(response_row, "hold", "硬扛")
		_add_crisis_response_button(response_row, "repair", "抢修")
		_add_crisis_response_button(response_row, "medical", "医疗")
		_add_crisis_response_button(response_row, "radio", "守频")

	var policy_title := Label.new()
	policy_title.text = "今夜值守"
	policy_title.add_theme_font_size_override("font_size", 16)
	policy_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	details.add_child(policy_title)

	var policy_row := HBoxContainer.new()
	policy_row.add_theme_constant_override("separation", 6)
	details.add_child(policy_row)
	_add_night_policy_button(policy_row, "normal", "常规")
	_add_night_policy_button(policy_row, "conserve", "节电")
	_add_night_policy_button(policy_row, "full_power", "全功率")
	_add_night_policy_button(policy_row, "shelter", "安置")

	var watch_title := Label.new()
	watch_title.text = "值班成员"
	watch_title.add_theme_font_size_override("font_size", 16)
	watch_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	details.add_child(watch_title)

	var watch_grid := GridContainer.new()
	watch_grid.columns = 2
	watch_grid.add_theme_constant_override("h_separation", 6)
	watch_grid.add_theme_constant_override("v_separation", 5)
	details.add_child(watch_grid)
	_add_night_watch_button(watch_grid, "none")
	for member_id in members.keys():
		_add_night_watch_button(watch_grid, str(member_id))

	for upgrade_id in BASE_UPGRADE_DEFS.keys():
		var def: Dictionary = BASE_UPGRADE_DEFS[upgrade_id]
		var level := int(base_upgrades.get(upgrade_id, 0))
		var max_level := int(def.get("max", 0))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.add_child(row)

		var text := Label.new()
		text.text = "%s  Lv.%d/%d%s\n%s" % [
			str(def.get("name", upgrade_id)),
			level,
			max_level,
			"  危机目标" if _crisis_target_upgrade() == str(upgrade_id) else "",
			str(def.get("effect", ""))
		]
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 13)
		text.add_theme_color_override("font_color", Color(0.82, 0.92, 0.88))
		row.add_child(text)

		var button := Button.new()
		button.custom_minimum_size = Vector2(118, 42)
		if level >= max_level:
			button.text = "已满级"
			button.disabled = true
		else:
			var cost := _upgrade_cost(upgrade_id)
			button.text = "升级  零件 %d" % cost
			button.disabled = int(resources.get("parts", 0)) < cost
			button.pressed.connect(func() -> void:
				_buy_base_upgrade(str(upgrade_id))
			)
		row.add_child(button)

func _upgrade_cost(upgrade_id: String) -> int:
	if not BASE_UPGRADE_DEFS.has(upgrade_id):
		return 999
	var level := int(base_upgrades.get(upgrade_id, 0))
	var costs: Array = BASE_UPGRADE_DEFS[upgrade_id].get("costs", [])
	if level < 0 or level >= costs.size():
		return 999
	return int(costs[level])

func _buy_base_upgrade(upgrade_id: String) -> bool:
	if not BASE_UPGRADE_DEFS.has(upgrade_id):
		return false
	var def: Dictionary = BASE_UPGRADE_DEFS[upgrade_id]
	var level := int(base_upgrades.get(upgrade_id, 0))
	if level >= int(def.get("max", 0)):
		return false
	var cost := _upgrade_cost(upgrade_id)
	if int(resources.get("parts", 0)) < cost:
		return false
	resources["parts"] = int(resources.get("parts", 0)) - cost
	base_upgrades[upgrade_id] = level + 1
	logs.append("基地升级：%s 提升到 Lv.%d。" % [str(def.get("name", upgrade_id)), int(base_upgrades[upgrade_id])])
	_refresh_all()
	return true

func _add_day_stance_button(root: Container, stance_id: String) -> void:
	var stance: Dictionary = DAY_STANCE_DEFS.get(stance_id, DAY_STANCE_DEFS["balanced"])
	var button := Button.new()
	button.text = "%s\n%s" % [str(stance.get("name", stance_id)), _day_stance_effect_text(stance_id)]
	button.toggle_mode = true
	button.button_pressed = day_stance_id == stance_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 42)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.disabled = dispatched_today
	button.pressed.connect(func() -> void:
		_set_day_stance(stance_id)
	)
	root.add_child(button)

func _set_day_stance(stance_id: String) -> bool:
	if dispatched_today or not DAY_STANCE_DEFS.has(stance_id):
		return false
	day_stance_id = stance_id
	logs.append("Day %d：今日准则切换为《%s》。" % [day, str((DAY_STANCE_DEFS[stance_id] as Dictionary).get("name", stance_id))])
	_refresh_base()
	_refresh_dispatch()
	_refresh_objective()
	return true

func _day_stance_effect_text(stance_id: String) -> String:
	var stance: Dictionary = DAY_STANCE_DEFS.get(stance_id, DAY_STANCE_DEFS["balanced"])
	var parts: Array[String] = []
	var score := int(stance.get("score", 0))
	if score != 0:
		parts.append("准%+d" % score)
	var rescue_score := int(stance.get("rescue_score", 0))
	if rescue_score != 0:
		parts.append("救%+d" % rescue_score)
	var supply_score := int(stance.get("supply_score", 0))
	if supply_score != 0:
		parts.append("补%+d" % supply_score)
	var reward_multiplier := float(stance.get("reward_multiplier", 1.0))
	if not is_equal_approx(reward_multiplier, 1.0):
		parts.append("物x%.2f" % reward_multiplier)
	var rescue_multiplier := float(stance.get("rescue_multiplier", 1.0))
	if not is_equal_approx(rescue_multiplier, 1.0):
		parts.append("救x%.2f" % rescue_multiplier)
	var threat := int(stance.get("threat", 0))
	if threat != 0:
		parts.append("暴%+d" % threat)
	var stress := int(stance.get("stress", 0))
	if stress != 0:
		parts.append("压%+d" % stress)
	if parts.is_empty():
		return "稳定"
	return " ".join(parts)

func _add_rest_action_button(root: Container, action_id: String) -> void:
	var action: Dictionary = REST_ACTION_DEFS.get(action_id, {})
	var button := Button.new()
	button.text = "%s\n%s" % [str(action.get("name", action_id)), _rest_action_effect_text(action_id)]
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 40)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.disabled = not _can_use_rest_action(action_id)
	button.pressed.connect(func() -> void:
		_apply_rest_action(action_id)
	)
	root.add_child(button)

func _can_use_rest_action(action_id: String) -> bool:
	if not REST_ACTION_DEFS.has(action_id):
		return false
	if rest_actions_used.has(action_id):
		return false
	var action: Dictionary = REST_ACTION_DEFS[action_id]
	var cost: Dictionary = action.get("cost", {})
	for key in cost.keys():
		if int(resources.get(str(key), 0)) < int(cost[key]):
			return false
	if action_id == "triage":
		return _triage_target_member_id() != ""
	if action_id == "stand_down":
		return _stand_down_target_member_id() != ""
	if action_id == "debrief":
		return _highest_stress_member_id() != ""
	return true

func _apply_rest_action(action_id: String) -> bool:
	if not _can_use_rest_action(action_id):
		return false
	var action: Dictionary = REST_ACTION_DEFS[action_id]
	var cost: Dictionary = action.get("cost", {})
	for key in cost.keys():
		resources[str(key)] = max(0, int(resources.get(str(key), 0)) - int(cost[key]))
	var target_id := ""
	var target_name := ""
	var report_line := ""
	if int(action.get("stress_all", 0)) != 0:
		_adjust_all_member_stress(int(action.get("stress_all", 0)))
	if bool(action.get("recover_tired", false)):
		target_id = _stand_down_target_member_id()
		if target_id != "":
			var rest_member: Dictionary = members[target_id]
			target_name = str(rest_member.get("name", target_id))
			if str(rest_member.get("status", "normal")) == "tired":
				rest_member["status"] = "normal"
				_adjust_member_stress(target_id, -8)
				report_line = "轮休：%s 恢复正常。" % target_name
			else:
				_adjust_member_stress(target_id, int(action.get("stress_target", 0)))
				report_line = "轮休：%s 压力 -6。" % target_name
	if int(action.get("stress_target", 0)) != 0:
		if not bool(action.get("recover_tired", false)):
			target_id = _triage_target_member_id() if bool(action.get("recover", false)) else _highest_stress_member_id()
		if target_id != "":
			if not bool(action.get("recover_tired", false)):
				_adjust_member_stress(target_id, int(action.get("stress_target", 0)))
			target_name = str((members.get(target_id, {}) as Dictionary).get("name", target_id))
	if bool(action.get("recover", false)) and target_id != "":
		var member: Dictionary = members[target_id]
		var status := str(member.get("status", "normal"))
		if status == "injured":
			member["status"] = "tired"
		elif status == "tired":
			member["status"] = "normal"
	if int(action.get("trust", 0)) != 0:
		resources["trust"] = max(0, int(resources.get("trust", 0)) + int(action.get("trust", 0)))
	if report_line != "":
		pending_rest_report_lines.append(report_line)
	rest_actions_used.append(action_id)
	var target_suffix := (" -> %s" % target_name) if target_name != "" else ""
	logs.append("Day %d：基地休整《%s》%s：%s" % [
		day,
		str(action.get("name", action_id)),
		target_suffix,
		str(action.get("brief", ""))
	])
	_refresh_all()
	_show_step(3)
	return true

func _rest_action_effect_text(action_id: String) -> String:
	var action: Dictionary = REST_ACTION_DEFS.get(action_id, {})
	var parts: Array[String] = []
	var cost: Dictionary = action.get("cost", {})
	for key in cost.keys():
		parts.append("%s-%d" % [_resource_short_name(str(key)), int(cost[key])])
	var stress_all := int(action.get("stress_all", 0))
	if stress_all != 0:
		parts.append("全压%+d" % stress_all)
	var stress_target := int(action.get("stress_target", 0))
	if stress_target != 0:
		parts.append("单压%+d" % stress_target)
	if bool(action.get("recover", false)):
		parts.append("恢复")
	if bool(action.get("recover_tired", false)):
		parts.append("轮休")
	var trust_delta := int(action.get("trust", 0))
	if trust_delta != 0:
		parts.append("%s%+d" % [_resource_short_name("trust"), trust_delta])
	if rest_actions_used.has(action_id):
		parts.append("已用")
	if parts.is_empty():
		return "稳定"
	return " ".join(parts)

func _highest_stress_member_id() -> String:
	var best_id := ""
	var best_stress := -1
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		var stress := int(member.get("stress", 0))
		if best_id == "" or stress > best_stress:
			best_id = str(member_id)
			best_stress = stress
	return best_id

func _stand_down_target_member_id() -> String:
	var tired_id := ""
	var tired_stress := -1
	var highest_id := ""
	var highest_stress := -1
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		var stress := int(member.get("stress", 0))
		if str(member.get("status", "normal")) == "tired":
			if tired_id == "" or stress > tired_stress:
				tired_id = str(member_id)
				tired_stress = stress
		if highest_id == "" or stress > highest_stress:
			highest_id = str(member_id)
			highest_stress = stress
	if tired_id != "":
		return tired_id
	return highest_id

func _triage_target_member_id() -> String:
	var injured_id := ""
	var injured_stress := -1
	var tired_id := ""
	var tired_stress := -1
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		var stress := int(member.get("stress", 0))
		match str(member.get("status", "normal")):
			"injured":
				if injured_id == "" or stress > injured_stress:
					injured_id = str(member_id)
					injured_stress = stress
			"tired":
				if tired_id == "" or stress > tired_stress:
					tired_id = str(member_id)
					tired_stress = stress
	if injured_id != "":
		return injured_id
	if tired_id != "":
		return tired_id
	return _highest_stress_member_id()

func _add_night_policy_button(root: HBoxContainer, policy_id: String, text: String) -> void:
	var button := Button.new()
	button.text = "%s\n%s" % [text, _night_policy_effect_text(policy_id)]
	button.toggle_mode = true
	button.button_pressed = night_policy_id == policy_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 42)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(func() -> void:
		_set_night_policy(policy_id)
	)
	root.add_child(button)

func _set_night_policy(policy_id: String) -> bool:
	if not NIGHT_POLICY_DEFS.has(policy_id):
		return false
	night_policy_id = policy_id
	_refresh_base()
	_refresh_objective()
	return true

func _add_crisis_response_button(root: HBoxContainer, response_id: String, text: String) -> void:
	var button := Button.new()
	button.text = "%s\n%s" % [text, _crisis_response_effect_text(response_id)]
	button.toggle_mode = true
	button.button_pressed = night_crisis_response_id == response_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 42)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.disabled = not _can_pay_crisis_response(response_id)
	button.pressed.connect(func() -> void:
		_set_crisis_response(response_id)
	)
	root.add_child(button)

func _set_crisis_response(response_id: String) -> bool:
	if not NIGHT_CRISIS_RESPONSE_DEFS.has(response_id):
		return false
	if not _can_pay_crisis_response(response_id):
		return false
	night_crisis_response_id = response_id
	_refresh_base()
	_refresh_objective()
	return true

func _can_pay_crisis_response(response_id: String) -> bool:
	var response: Dictionary = NIGHT_CRISIS_RESPONSE_DEFS.get(response_id, NIGHT_CRISIS_RESPONSE_DEFS["hold"])
	var cost: Dictionary = response.get("cost", {})
	for key in cost.keys():
		if int(resources.get(str(key), 0)) < int(cost[key]):
			return false
	return true

func _crisis_response_effect_text(response_id: String) -> String:
	var response: Dictionary = NIGHT_CRISIS_RESPONSE_DEFS.get(response_id, NIGHT_CRISIS_RESPONSE_DEFS["hold"])
	var parts: Array[String] = []
	var mitigation := int(response.get("mitigation", 0))
	if mitigation != 0:
		parts.append("缓+%d" % mitigation)
	var cost: Dictionary = response.get("cost", {})
	for key in cost.keys():
		parts.append("%s-%d" % [_resource_short_name(str(key)), int(cost[key])])
	for key in ["trust", "influence", "threat"]:
		var delta := int(response.get(key, 0))
		if delta != 0:
			parts.append("%s%+d" % [_resource_short_name(str(key)), delta])
	if int(response.get("listen_bonus", 0)) != 0:
		parts.append("听%+d" % int(response.get("listen_bonus", 0)))
	var stress := int(response.get("stress", 0))
	if stress != 0:
		parts.append("压%+d" % stress)
	if parts.is_empty():
		return "不耗"
	if not pending_crisis.is_empty() and response_id != "hold" and not _crisis_response_matches(response_id, str(pending_crisis.get("id", ""))):
		parts.append("不匹配")
	return " ".join(parts)

func _crisis_response_matches(response_id: String, crisis_id: String) -> bool:
	if response_id == "hold":
		return true
	var response: Dictionary = NIGHT_CRISIS_RESPONSE_DEFS.get(response_id, NIGHT_CRISIS_RESPONSE_DEFS["hold"])
	var matches: Array = response.get("matches", [])
	return matches.has(crisis_id)

func _add_night_watch_button(root: GridContainer, member_id: String) -> void:
	var button := Button.new()
	button.text = _night_watch_button_text(member_id)
	button.toggle_mode = true
	button.button_pressed = night_watch_member_id == member_id
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 42)
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if member_id != "none":
		var member: Dictionary = members.get(member_id, {})
		button.disabled = not _member_available(member)
	button.pressed.connect(func() -> void:
		_set_night_watch_member(member_id)
	)
	root.add_child(button)

func _set_night_watch_member(member_id: String) -> bool:
	if member_id != "none" and (not members.has(member_id) or not _member_available(members.get(member_id, {}))):
		return false
	night_watch_member_id = member_id
	_refresh_base()
	_refresh_objective()
	return true

func _night_watch_button_text(member_id: String) -> String:
	var name := "无人"
	var effect := _night_watch_effect_text(member_id)
	if member_id != "none":
		var member: Dictionary = members.get(member_id, {})
		name = str(member.get("name", member_id))
	return "%s\n%s" % [name, effect]

func _night_watch_effect_text(member_id: String) -> String:
	var def: Dictionary = NIGHT_WATCH_DEFS.get(member_id, NIGHT_WATCH_DEFS["none"])
	var parts: Array[String] = []
	if int(def.get("listen_bonus", 0)) != 0:
		parts.append("听%+d" % int(def.get("listen_bonus", 0)))
	if int(def.get("food_save", 0)) != 0:
		parts.append("食-%d" % int(def.get("food_save", 0)))
	if int(def.get("stress_relief", 0)) != 0:
		parts.append("全压-%d" % int(def.get("stress_relief", 0)))
	if int(def.get("threat", 0)) != 0:
		parts.append("暴%+d" % int(def.get("threat", 0)))
	if int(def.get("trust", 0)) != 0:
		parts.append("信%+d" % int(def.get("trust", 0)))
	if int(def.get("stress", 0)) != 0:
		parts.append("自压+%d" % int(def.get("stress", 0)))
	if parts.is_empty():
		return "不加压"
	return " ".join(parts)

func _night_policy_effect_text(policy_id: String) -> String:
	var policy: Dictionary = NIGHT_POLICY_DEFS.get(policy_id, NIGHT_POLICY_DEFS["normal"])
	var parts: Array[String] = []
	var power_delta := int(policy.get("power_delta", 0))
	var listen_bonus := int(policy.get("listen_bonus", 0))
	var trust_delta := int(policy.get("trust", 0))
	var influence_delta := int(policy.get("influence", 0))
	var threat_delta := int(policy.get("threat", 0))
	var shelter_relief := int(policy.get("shelter_relief", 0))
	if power_delta != 0:
		parts.append("电%+d" % (-power_delta))
	if listen_bonus != 0:
		parts.append("听%+d" % listen_bonus)
	if trust_delta != 0:
		parts.append("信%+d" % trust_delta)
	if influence_delta != 0:
		parts.append("影%+d" % influence_delta)
	if threat_delta != 0:
		parts.append("暴%+d" % threat_delta)
	if shelter_relief != 0:
		parts.append("安-%d" % shelter_relief)
	if parts.is_empty():
		return "稳定"
	return " ".join(parts)

func _crisis_target_upgrade() -> String:
	match str(pending_crisis.get("id", "")):
		"antenna_fault":
			return "antenna"
		"gate_probe":
			return "gate"
		"blackout":
			return "battery"
		"ration_pressure":
			return "infirmary"
		_:
			return ""

func _refresh_logs() -> void:
	if _story_day1_mode():
		log_body.text = _story_log_text()
		return
	log_body.text = "\n".join(logs.slice(max(0, logs.size() - 14), logs.size()))

func _story_log_text() -> String:
	var lines: Array[String] = []
	lines.append("停电第六天，旧体育馆电台重新接线。")
	if locked_signal_ids.is_empty():
		lines.append("北桥方向有断续求救，还没听清。")
		lines.append("你需要先把这段声音从噪声里捞出来。")
	elif not signal_confirmations.has("d1_north_bridge_help"):
		lines.append("北桥居民楼三楼有人被困。")
		lines.append("信号提到孩子和暖气管，但还需要确认。")
	elif not dispatched_today:
		lines.append("三下敲击从噪声后面传回来，不像录音。")
		lines.append("外勤队在门口等你的安排。")
	elif not pending_dispatch_context.is_empty():
		lines.append("外勤队抵达北桥楼下，正在等你的回传。")
	else:
		lines.append(str(last_dispatch_result.get("summary", "外勤队已经回传。")))
		lines.append("入夜前，基地里的人都在等结果。")
	return "\n".join(lines)

func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _lock_signal(signal_id: String) -> void:
	var signal_data := _signal_by_id(signal_id)
	if signal_data.is_empty():
		return
	var cost := int(signal_data.get("listen_cost", 1))
	if cost > listen_time or locked_signal_ids.has(signal_id):
		return
	listen_time -= cost
	locked_signal_ids.append(signal_id)
	logs.append("Day %d：锁定信号「%s」：%s" % [day, str(signal_data.get("title", "")), str(signal_data.get("full", ""))])
	var loc_id := str(signal_data.get("location", ""))
	if locations.has(loc_id) and str(locations[loc_id].get("status", "")) == "unknown":
		locations[loc_id]["status"] = "explorable"
	if locations.has(loc_id):
		selected_location_id = loc_id
	_refresh_all()
	if _story_day1_mode() and signal_data.has("call_confirm") and not signal_confirmations.has(signal_id):
		_show_step(0)
	else:
		_show_step(2)

func _force_lock_signal(signal_id: String) -> bool:
	var signal_data := _signal_by_id(signal_id)
	if signal_data.is_empty():
		return false
	if locked_signal_ids.has(signal_id):
		return false
	if int(resources.get("power", 0)) <= 0:
		return false
	resources["power"] = max(0, int(resources.get("power", 0)) - 1)
	resources["threat"] = int(resources.get("threat", 0)) + 1
	locked_signal_ids.append(signal_id)
	logs.append("Day %d：强锁信号「%s」：-1 电力，+1 暴露。%s" % [
		day,
		str(signal_data.get("title", "")),
		str(signal_data.get("full", ""))
	])
	var loc_id := str(signal_data.get("location", ""))
	if locations.has(loc_id) and str(locations[loc_id].get("status", "")) == "unknown":
		locations[loc_id]["status"] = "explorable"
	if locations.has(loc_id):
		selected_location_id = loc_id
	_refresh_all()
	_show_step(2)
	return true

func _refine_signal(signal_id: String) -> bool:
	var signal_data := _signal_by_id(signal_id)
	if signal_data.is_empty():
		return false
	if locked_signal_ids.has(signal_id) or listen_time <= 0:
		return false
	if int(signal_data.get("refined_count", 0)) >= 2:
		return false
	listen_time -= 1
	var noise_before := int(signal_data.get("noise", 0))
	var reduction := 15 + int(base_upgrades.get("antenna", 0)) * 5
	signal_data["noise"] = max(0, noise_before - reduction)
	signal_data["refined_count"] = int(signal_data.get("refined_count", 0)) + 1
	signal_data["refined_day"] = day
	logs.append("Day %d：精听校准「%s」：噪声 %d -> %d，剩余监听 %d。" % [
		day,
		str(signal_data.get("title", "")),
		noise_before,
		int(signal_data.get("noise", 0)),
		listen_time
	])
	_refresh_tuning()
	_refresh_dispatch()
	_refresh_objective()
	return true

func _mark_signal(signal_id: String, mark_id: String) -> void:
	if _signal_by_id(signal_id).is_empty():
		return
	if mark_id == "":
		signal_marks.erase(signal_id)
		logs.append("Day %d：移除信号判断「%s」。" % [day, str(_signal_by_id(signal_id).get("title", ""))])
	else:
		signal_marks[signal_id] = mark_id
		logs.append("Day %d：信号「%s」标记为%s。" % [day, str(_signal_by_id(signal_id).get("title", "")), _signal_mark_label(mark_id)])
	_refresh_tuning()
	_refresh_dispatch()
	_refresh_objective()

func _confirm_signal(signal_id: String) -> bool:
	var signal_data := _signal_by_id(signal_id)
	if signal_data.is_empty():
		return false
	if not locked_signal_ids.has(signal_id):
		return false
	var confirm: Dictionary = signal_data.get("call_confirm", {})
	if confirm.is_empty():
		return false
	if signal_confirmations.has(signal_id):
		return false
	var flag := str(confirm.get("effect_flag", "confirmed_by_call"))
	signal_confirmations[signal_id] = {
		"flag": flag,
		"response": str(confirm.get("response", "")),
		"day": day
	}
	logs.append("Day %d：呼叫确认「%s」：%s" % [
		day,
		str(signal_data.get("title", "")),
		str(confirm.get("response", "对方给出了回应。"))
	])
	_refresh_tuning()
	_refresh_dispatch()
	_refresh_resources()
	_refresh_logs()
	_refresh_objective()
	_show_step(2)
	return true

func _select_location(location_id: String) -> void:
	if not locations.has(location_id):
		return
	selected_location_id = location_id
	_refresh_city()
	_refresh_dispatch()
	_refresh_objective()
	_show_step(2)

func _apply_city_action(location_id: String, action_id: String) -> bool:
	if not locations.has(location_id) or not CITY_ACTION_DEFS.has(action_id):
		return false
	if str(location_id) == "base":
		return false
	var action: Dictionary = CITY_ACTION_DEFS[action_id]
	var location: Dictionary = locations[location_id]
	var flag := str(action.get("flag", action_id))
	var flags: Array = location.get("flags", [])
	if flags.has(flag):
		return false
	var cost: Dictionary = action.get("cost", {})
	for key in cost.keys():
		if int(resources.get(str(key), 0)) < int(cost[key]):
			return false
	for key in cost.keys():
		resources[str(key)] = max(0, int(resources.get(str(key), 0)) - int(cost[key]))
	if int(action.get("risk", 0)) != 0:
		location["risk"] = clamp(int(location.get("risk", 0)) + int(action.get("risk", 0)), 5, 90)
	if int(action.get("danger_trend", 0)) != 0:
		location["danger_trend"] = max(0, int(location.get("danger_trend", 0)) + int(action.get("danger_trend", 0)))
	if int(action.get("supplies_left", 0)) != 0:
		location["supplies_left"] = max(0, int(location.get("supplies_left", 0)) + int(action.get("supplies_left", 0)))
	if int(action.get("trust", 0)) != 0:
		resources["trust"] = max(0, int(resources.get("trust", 0)) + int(action.get("trust", 0)))
	_add_location_flag(location, flag)
	location["last_city_action_day"] = day
	logs.append("Day %d：城市处置「%s」用于 %s。%s" % [
		day,
		str(action.get("name", action_id)),
		str(location.get("name", location_id)),
		str(action.get("brief", ""))
	])
	_refresh_all()
	_show_step(1)
	return true

func _dispatch_preview(member_ids: Array[String], item_ids: Array[String], broadcast_mode: String, route_id: String = "safe", prep_id: String = "none", order_id: String = "steady", objective_id: String = "balanced") -> Dictionary:
	if not _has_dispatch_target():
		return {}
	var location: Dictionary = locations.get(selected_location_id, {})
	var linked_signal := _best_signal_for_location(selected_location_id)
	var locked := not linked_signal.is_empty() and locked_signal_ids.has(str(linked_signal.get("id", "")))
	var active_prep_id := _usable_prep_id(prep_id)
	var active_order_id := _usable_order_id(order_id)
	var active_objective_id := _usable_objective_id(objective_id)
	var breakdown := _dispatch_score_breakdown(member_ids, item_ids, broadcast_mode, location, linked_signal, locked, route_id, active_prep_id, active_order_id, active_objective_id, day_stance_id)
	var preview := _score_probability(int(breakdown.get("score", 0)))
	preview["reasons"] = breakdown.get("reasons", [])
	preview["prep_id"] = active_prep_id
	preview["order_id"] = active_order_id
	preview["objective_id"] = active_objective_id
	preview["shelter"] = _dispatch_shelter_preview(linked_signal, route_id, active_prep_id, active_order_id, active_objective_id, day_stance_id)
	return preview

func _launch_dispatch(member_ids: Array[String], item_ids: Array[String], broadcast_mode: String, route_id: String = "safe", prep_id: String = "none", order_id: String = "steady", objective_id: String = "balanced") -> void:
	if dispatched_today:
		return
	dispatched_today = true
	var active_route_id := _usable_route_id(route_id)
	var active_prep_id := _usable_prep_id(prep_id)
	var active_order_id := _usable_order_id(order_id)
	var active_objective_id := _usable_objective_id(objective_id)
	var location: Dictionary = locations.get(selected_location_id, {})
	var linked_signal := _best_signal_for_location(selected_location_id)
	var locked := not linked_signal.is_empty() and locked_signal_ids.has(str(linked_signal.get("id", "")))
	var base_score := _calculate_dispatch_score(member_ids, item_ids, broadcast_mode, location, linked_signal, locked, active_route_id, active_prep_id, active_order_id, active_objective_id, day_stance_id)
	for member_id in member_ids:
		_mark_member_after_dispatch(str(member_id))
	for item_id in item_ids:
		if items.has(item_id):
			items[item_id]["count"] = max(0, int(items[item_id].get("count", 0)) - 1)
	_apply_route_cost(active_route_id)
	_apply_prep_cost(active_prep_id, member_ids)
	_apply_broadcast_effect(broadcast_mode)
	_apply_order_effect(active_order_id, member_ids)
	_apply_objective_effect(active_objective_id, member_ids)
	_apply_day_stance_effect(day_stance_id, member_ids)
	_apply_team_chemistry_stress(member_ids, location, linked_signal)
	var field_choice: Dictionary = linked_signal.get("field_choice", {})
	if not field_choice.is_empty():
		pending_dispatch_context = {
			"base_score": base_score,
			"location": location.duplicate(true),
			"signal": linked_signal.duplicate(true),
			"locked": locked,
			"route_id": active_route_id,
			"prep_id": active_prep_id,
			"order_id": active_order_id,
			"objective_id": active_objective_id,
			"day_stance_id": day_stance_id,
			"member_ids": member_ids.duplicate(),
			"item_ids": item_ids.duplicate(),
			"field_choice": field_choice.duplicate(true)
		}
		last_dispatch_result = {
			"ui_phase": "awaiting_choice",
			"summary": "外勤队抵达北桥楼下，等待你的回传指令。",
			"field_choice": field_choice.duplicate(true),
			"pending_feed_lines": (field_choice.get("feed_lines", []) as Array).duplicate(),
			"base_score": base_score,
			"location_id": str(location.get("id", selected_location_id)),
			"signal_id": str(linked_signal.get("id", "")),
			"route_id": active_route_id,
			"prep_id": active_prep_id,
			"order_id": active_order_id,
			"objective_id": active_objective_id,
			"day_stance_id": day_stance_id
		}
		logs.append(str(last_dispatch_result.get("summary", "")))
		_refresh_all()
		return
	var score := base_score + rng.randi_range(-8, 8)
	last_dispatch_result = _resolve_dispatch_score(score, location, linked_signal, locked, active_route_id, member_ids, active_order_id, active_objective_id, day_stance_id)
	last_dispatch_result["base_score"] = base_score
	last_dispatch_result["final_score"] = score
	last_dispatch_result["location_id"] = str(location.get("id", selected_location_id))
	last_dispatch_result["signal_id"] = str(linked_signal.get("id", ""))
	last_dispatch_result["route_id"] = active_route_id
	last_dispatch_result["prep_id"] = active_prep_id
	last_dispatch_result["order_id"] = active_order_id
	last_dispatch_result["objective_id"] = active_objective_id
	last_dispatch_result["day_stance_id"] = day_stance_id
	dispatch_animation_pending = true
	logs.append(str(last_dispatch_result.get("summary", "")))
	_refresh_all()

func _resolve_pending_dispatch(choice_id: String) -> bool:
	if pending_dispatch_context.is_empty():
		return false
	var choice_data := _pending_field_choice_option(choice_id)
	if choice_data.is_empty():
		return false
	var member_ids: Array[String] = []
	for member_id in pending_dispatch_context.get("member_ids", []):
		member_ids.append(str(member_id))
	var stress_delta := int(choice_data.get("stress_delta", 0))
	if stress_delta != 0:
		for member_id in member_ids:
			_adjust_member_stress(str(member_id), stress_delta)
	var base_score := int(pending_dispatch_context.get("base_score", 0))
	var choice_delta := int(choice_data.get("score_delta", 0))
	var score := base_score + choice_delta + rng.randi_range(-8, 8)
	var result := _resolve_dispatch_score(
		score,
		pending_dispatch_context.get("location", {}) as Dictionary,
		pending_dispatch_context.get("signal", {}) as Dictionary,
		bool(pending_dispatch_context.get("locked", false)),
		str(pending_dispatch_context.get("route_id", "safe")),
		member_ids,
		str(pending_dispatch_context.get("order_id", "steady")),
		str(pending_dispatch_context.get("objective_id", "balanced")),
		str(pending_dispatch_context.get("day_stance_id", "balanced"))
	)
	var feed_lines: Array = []
	for line in (pending_dispatch_context.get("field_choice", {}) as Dictionary).get("feed_lines", []):
		feed_lines.append(str(line))
	if str(choice_data.get("feed_line", "")) != "":
		feed_lines.append(str(choice_data.get("feed_line", "")))
	feed_lines.append(str(result.get("summary", "")))
	result["feed_lines"] = feed_lines
	result["choice_id"] = choice_id
	result["choice_label"] = str(choice_data.get("label", choice_id))
	result["choice_score_delta"] = choice_delta
	result["base_score"] = base_score
	result["final_score"] = score
	result["location_id"] = str((pending_dispatch_context.get("location", {}) as Dictionary).get("id", selected_location_id))
	result["signal_id"] = str((pending_dispatch_context.get("signal", {}) as Dictionary).get("id", ""))
	result["route_id"] = str(pending_dispatch_context.get("route_id", "safe"))
	result["prep_id"] = str(pending_dispatch_context.get("prep_id", "none"))
	result["order_id"] = str(pending_dispatch_context.get("order_id", "steady"))
	result["objective_id"] = str(pending_dispatch_context.get("objective_id", "balanced"))
	result["day_stance_id"] = str(pending_dispatch_context.get("day_stance_id", "balanced"))
	last_dispatch_result = result
	pending_dispatch_context.clear()
	dispatch_animation_pending = true
	logs.append(str(last_dispatch_result.get("summary", "")))
	_refresh_all()
	return true

func _pending_field_choice_option(choice_id: String) -> Dictionary:
	var field_choice: Dictionary = pending_dispatch_context.get("field_choice", {})
	for option in field_choice.get("options", []):
		var data := option as Dictionary
		if str(data.get("id", "")) == choice_id:
			return data
	return {}

func _calculate_dispatch_score(member_ids: Array[String], item_ids: Array[String], broadcast_mode: String, location: Dictionary, signal_data: Dictionary, locked: bool, route_id: String = "safe", prep_id: String = "none", order_id: String = "steady", objective_id: String = "balanced", stance_id: String = "balanced") -> int:
	return int(_dispatch_score_breakdown(member_ids, item_ids, broadcast_mode, location, signal_data, locked, route_id, prep_id, order_id, objective_id, stance_id).get("score", 0))

func _dispatch_score_breakdown(member_ids: Array[String], item_ids: Array[String], broadcast_mode: String, location: Dictionary, signal_data: Dictionary, locked: bool, route_id: String = "safe", prep_id: String = "none", order_id: String = "steady", objective_id: String = "balanced", stance_id: String = "balanced") -> Dictionary:
	var reasons: Array[String] = []
	var score := 45
	reasons.append(_format_reason("基础准备", 45))
	var risk_penalty := -int(location.get("risk", 0))
	score += risk_penalty
	reasons.append(_format_reason("地点风险", risk_penalty))
	var trend_penalty := -int(location.get("danger_trend", 0)) * 4
	if trend_penalty != 0:
		score += trend_penalty
		reasons.append(_format_reason("危险趋势", trend_penalty))
	var memory_bonus := _location_memory_score(location)
	if memory_bonus != 0:
		score += memory_bonus
		reasons.append(_format_reason("地点记忆", memory_bonus))
	if locked:
		var lock_bonus := 20 + int(base_upgrades.get("antenna", 0)) * 5
		score += lock_bonus
		reasons.append(_format_reason("锁定信号", lock_bonus))
	if not signal_data.is_empty():
		var confidence_bonus := _signal_confidence_score(signal_data)
		if confidence_bonus != 0:
			score += confidence_bonus
			reasons.append(_format_reason("情报可信度", confidence_bonus))
		var noise_penalty := _signal_noise_penalty(signal_data)
		if noise_penalty != 0:
			score += noise_penalty
			reasons.append(_format_reason("信号噪声", noise_penalty))
		var mark_bonus := _signal_mark_score(signal_data, str(signal_marks.get(str(signal_data.get("id", "")), "")))
		if mark_bonus != 0:
			score += mark_bonus
			reasons.append(_format_reason("情报判断：%s" % _signal_mark_label(str(signal_marks.get(str(signal_data.get("id", "")), ""))), mark_bonus))
		if signal_confirmations.has(str(signal_data.get("id", ""))):
			score += 6
			reasons.append(_format_reason("呼叫确认", 6))
	var gate_bonus := int(base_upgrades.get("gate", 0)) * 3
	if gate_bonus != 0:
		score += gate_bonus
		reasons.append(_format_reason("加固大门", gate_bonus))
	for member_id in member_ids:
		var member_bonus := _member_bonus(str(member_id), location, signal_data)
		score += member_bonus
		var member: Dictionary = members.get(str(member_id), {})
		reasons.append(_format_reason(str(member.get("name", member_id)), member_bonus))
	var synergy_bonus := _team_synergy_bonus(member_ids, location, signal_data)
	if synergy_bonus != 0:
		score += synergy_bonus
		reasons.append(_format_reason("队伍协同", synergy_bonus))
	var chemistry_bonus := _team_chemistry_score(member_ids, location, signal_data)
	if chemistry_bonus != 0:
		score += chemistry_bonus
		reasons.append(_format_reason("队伍化学", chemistry_bonus))
	var bond_bonus := _team_bond_score(member_ids)
	if bond_bonus != 0:
		score += bond_bonus
		reasons.append(_format_reason("搭档记忆", bond_bonus))
	for item_id in item_ids:
		var item_bonus := _item_bonus(str(item_id), location, signal_data)
		score += item_bonus
		var item: Dictionary = items.get(str(item_id), {})
		reasons.append(_format_reason(str(item.get("name", item_id)), item_bonus))
	var route_bonus := _route_score_bonus(route_id)
	score += route_bonus
	reasons.append(_format_reason(_route_name(route_id), route_bonus))
	var prep_bonus := _prep_score_bonus(prep_id)
	if prep_bonus != 0:
		score += prep_bonus
		reasons.append(_format_reason(_prep_name(prep_id), prep_bonus))
	var order_bonus := _order_score_bonus(order_id)
	if order_bonus != 0:
		score += order_bonus
		reasons.append(_format_reason(_order_name(order_id), order_bonus))
	var objective_bonus := _objective_score_bonus(objective_id, location, signal_data)
	if objective_bonus != 0:
		score += objective_bonus
		reasons.append(_format_reason(_objective_name(objective_id), objective_bonus))
	var stance_bonus := _day_stance_score_bonus(stance_id, location, signal_data)
	if stance_bonus != 0:
		score += stance_bonus
		reasons.append(_format_reason(_day_stance_name(stance_id), stance_bonus))
	var broadcast_bonus := _broadcast_score_bonus(broadcast_mode)
	score += broadcast_bonus
	reasons.append(_format_reason(_broadcast_name(broadcast_mode), broadcast_bonus))
	return {
		"score": score,
		"reasons": reasons
	}

func _dispatch_shelter_preview(signal_data: Dictionary, route_id: String = "safe", prep_id: String = "none", order_id: String = "steady", objective_id: String = "balanced", stance_id: String = "balanced") -> Dictionary:
	if signal_data.is_empty():
		return {}
	var reward: Dictionary = signal_data.get("reward", {})
	var base_rescued: int = int(reward.get("rescued", 0))
	if base_rescued <= 0:
		return {}
	var reward_multiplier: float = _route_reward_multiplier(route_id) * _order_reward_multiplier(order_id) * _objective_reward_multiplier(objective_id) * _day_stance_reward_multiplier(stance_id)
	var rescue_multiplier: float = _objective_rescue_multiplier(objective_id) * _day_stance_rescue_multiplier(stance_id)
	var success_rescued: int = max(0, _scaled_delta(base_rescued, reward_multiplier * rescue_multiplier))
	var partial_rescued: int = max(0, _scaled_delta(base_rescued, 0.5 * reward_multiplier * rescue_multiplier))
	var current_rescued: int = max(0, int(resources.get("rescued", 0)))
	var base_relief: int = _base_shelter_relief()
	var current_pressure: int = _shelter_food_pressure_for_count(current_rescued, base_relief)
	var success_pressure: int = _shelter_food_pressure_for_count(current_rescued + success_rescued, base_relief)
	var partial_pressure: int = _shelter_food_pressure_for_count(current_rescued + partial_rescued, base_relief)
	var prep_def: Dictionary = PREP_DEFS.get(_normalized_prep_id(prep_id), PREP_DEFS["none"])
	var prep_cost: Dictionary = prep_def.get("cost", {})
	var food_after_launch: int = max(0, int(resources.get("food", 0)) - int(prep_cost.get("food", 0)))
	var success_food: int = food_after_launch + _scaled_delta(int(reward.get("food", 0)), reward_multiplier)
	var partial_food: int = food_after_launch + _scaled_delta(int(reward.get("food", 0)), 0.5 * reward_multiplier)
	var success_night_food: int = 2 + success_pressure
	var partial_night_food: int = 2 + partial_pressure
	return {
		"current_rescued": current_rescued,
		"success_rescued": success_rescued,
		"partial_rescued": partial_rescued,
		"current_food_pressure": current_pressure,
		"success_food_pressure": success_pressure,
		"partial_food_pressure": partial_pressure,
		"success_extra_food": max(0, success_pressure - current_pressure),
		"partial_extra_food": max(0, partial_pressure - current_pressure),
		"success_shortage": max(0, success_night_food - success_food),
		"partial_shortage": max(0, partial_night_food - partial_food),
		"base_shelter_relief": base_relief
	}

func _format_reason(label: String, value: int) -> String:
	if value >= 0:
		return "%s +%d" % [label, value]
	return "%s %d" % [label, value]

func _signal_intel_score(signal_data: Dictionary) -> int:
	if signal_data.is_empty():
		return 0
	return _signal_confidence_score(signal_data) + _signal_noise_penalty(signal_data)

func _signal_confidence_score(signal_data: Dictionary) -> int:
	match str(signal_data.get("confidence", "")).to_lower():
		"high", "高":
			return 8
		"medium", "mid", "中":
			return 3
		"low", "低":
			return -5
		_:
			return 0

func _signal_noise_penalty(signal_data: Dictionary) -> int:
	var noise := int(signal_data.get("noise", 0))
	return -int(floor(float(max(0, noise - 20)) / 10.0))

func _signal_mark_score(signal_data: Dictionary, mark_id: String) -> int:
	if signal_data.is_empty() or mark_id == "":
		return 0
	var confidence := str(signal_data.get("confidence", "")).to_lower()
	var noise := int(signal_data.get("noise", 0))
	var need_tags: Array = signal_data.get("need_tags", [])
	var failure: Dictionary = signal_data.get("failure", {})
	match mark_id:
		"trusted":
			if confidence in ["high", "高"]:
				return 5
			if confidence in ["medium", "mid", "中"]:
				return 3
			if confidence in ["low", "低"]:
				return -6
		"suspect":
			if confidence in ["low", "低"] or noise >= 55:
				return 4
			if confidence in ["medium", "mid", "中"]:
				return 1
			if confidence in ["high", "高"]:
				return -2
		"decoy":
			if (confidence in ["low", "低"] and noise >= 55) or int(failure.get("threat", 0)) > 0:
				return 6
			if need_tags.has("rescue") and not (confidence in ["low", "低"]):
				return -8
			return -2
	return 0

func _signal_mark_label(mark_id: String) -> String:
	match mark_id:
		"trusted":
			return "可信"
		"suspect":
			return "可疑"
		"decoy":
			return "诱饵"
		_:
			return "未标记"

func _location_memory_score(location: Dictionary) -> int:
	var score := 0
	var flags: Array = location.get("flags", [])
	if flags.has("success_dispatch"):
		score += 6
	if flags.has("partial_dispatch"):
		score -= 3
	if flags.has("failed_dispatch") or flags.has("failure_dispatch"):
		score -= 8
	if flags.has("scouted"):
		score += 4
	if flags.has("route_marked"):
		score += 5
	if flags.has("warned"):
		score += 2
	if flags.has("supply_cache"):
		score += 3
	var last_visit := int(location.get("last_visit_day", 0))
	if last_visit > 0 and last_visit < day:
		score += 4
	var status := str(location.get("status", ""))
	if status == "confirmed" or status == "looted":
		score += 2
	return score

func _location_memory_text(location: Dictionary) -> String:
	var score := _location_memory_score(location)
	if score == 0:
		return "记忆：未踩点"
	var flags: Array = location.get("flags", [])
	var tags: Array[String] = []
	if flags.has("success_dispatch"):
		tags.append("路线标记")
	if flags.has("partial_dispatch"):
		tags.append("混乱回传")
	if flags.has("failed_dispatch") or flags.has("failure_dispatch"):
		tags.append("失败阴影")
	if flags.has("scouted"):
		tags.append("侦查标记")
	if flags.has("route_marked"):
		tags.append("路标")
	if flags.has("warned"):
		tags.append("预警")
	if flags.has("supply_cache"):
		tags.append("补给缓存")
	var last_visit := int(location.get("last_visit_day", 0))
	if last_visit > 0 and last_visit < day:
		tags.append("旧路线")
	var status := str(location.get("status", ""))
	if status == "confirmed" or status == "looted":
		tags.append("地形已知")
	if tags.is_empty():
		tags.append("残留记录")
	return "记忆：%s 准%+d" % [" / ".join(tags), score]

func _broadcast_score_bonus(broadcast_mode: String) -> int:
	return int(_broadcast_effect(broadcast_mode).get("score", 0))

func _broadcast_name(broadcast_mode: String) -> String:
	return str(_broadcast_effect(broadcast_mode).get("name", "广播模式"))

func _broadcast_effect(broadcast_mode: String) -> Dictionary:
	return BROADCAST_DEFS.get(_normalized_broadcast_mode(broadcast_mode), BROADCAST_DEFS["route_warning"]) as Dictionary

func _normalized_broadcast_mode(broadcast_mode: String) -> String:
	if BROADCAST_DEFS.has(broadcast_mode):
		return broadcast_mode
	return "route_warning"

func _apply_broadcast_effect(broadcast_mode: String) -> void:
	var effect := _broadcast_effect(broadcast_mode)
	for key in ["power", "trust", "influence", "threat"]:
		var delta := int(effect.get(key, 0))
		if delta == 0:
			continue
		resources[key] = max(0, int(resources.get(key, 0)) + delta)

func _route_score_bonus(route_id: String) -> int:
	var route_def: Dictionary = ROUTE_DEFS.get(_normalized_route_id(route_id), ROUTE_DEFS["safe"])
	return int(route_def.get("score", 0))

func _prep_score_bonus(prep_id: String) -> int:
	var prep_def: Dictionary = PREP_DEFS.get(_normalized_prep_id(prep_id), PREP_DEFS["none"])
	return int(prep_def.get("score", 0))

func _prep_name(prep_id: String) -> String:
	var prep_def: Dictionary = PREP_DEFS.get(_normalized_prep_id(prep_id), PREP_DEFS["none"])
	return str(prep_def.get("name", prep_id))

func _order_score_bonus(order_id: String) -> int:
	var order_def: Dictionary = ORDER_DEFS.get(_normalized_order_id(order_id), ORDER_DEFS["steady"])
	return int(order_def.get("score", 0))

func _order_name(order_id: String) -> String:
	var order_def: Dictionary = ORDER_DEFS.get(_normalized_order_id(order_id), ORDER_DEFS["steady"])
	return str(order_def.get("name", order_id))

func _normalized_order_id(order_id: String) -> String:
	if ORDER_DEFS.has(order_id):
		return order_id
	return "steady"

func _usable_order_id(order_id: String) -> String:
	return _normalized_order_id(order_id)

func _apply_order_effect(order_id: String, member_ids: Array[String]) -> void:
	var order_def: Dictionary = ORDER_DEFS.get(_normalized_order_id(order_id), ORDER_DEFS["steady"])
	resources["threat"] = max(0, int(resources.get("threat", 0)) + int(order_def.get("threat", 0)))
	var stress_delta := int(order_def.get("stress", 0))
	if stress_delta != 0:
		for member_id in member_ids:
			_adjust_member_stress(str(member_id), stress_delta)

func _order_reward_multiplier(order_id: String) -> float:
	var order_def: Dictionary = ORDER_DEFS.get(_normalized_order_id(order_id), ORDER_DEFS["steady"])
	return float(order_def.get("reward_multiplier", 1.0))

func _order_failure_risk(order_id: String) -> int:
	var order_def: Dictionary = ORDER_DEFS.get(_normalized_order_id(order_id), ORDER_DEFS["steady"])
	return int(order_def.get("failure_risk", 0))

func _order_protects_injury(order_id: String) -> bool:
	var order_def: Dictionary = ORDER_DEFS.get(_normalized_order_id(order_id), ORDER_DEFS["steady"])
	return bool(order_def.get("protect_injury", false))

func _objective_name(objective_id: String) -> String:
	var objective_def: Dictionary = OBJECTIVE_DEFS.get(_normalized_objective_id(objective_id), OBJECTIVE_DEFS["balanced"])
	return str(objective_def.get("name", objective_id))

func _normalized_objective_id(objective_id: String) -> String:
	if OBJECTIVE_DEFS.has(objective_id):
		return objective_id
	return "balanced"

func _usable_objective_id(objective_id: String) -> String:
	return _normalized_objective_id(objective_id)

func _objective_score_bonus(objective_id: String, location: Dictionary, signal_data: Dictionary) -> int:
	var active_id := _normalized_objective_id(objective_id)
	var objective_def: Dictionary = OBJECTIVE_DEFS.get(active_id, OBJECTIVE_DEFS["balanced"])
	match active_id:
		"rescue":
			if str(location.get("type", "")) == "rescue" or _mission_tags(location, signal_data).has("rescue"):
				return int(objective_def.get("score", 0))
			return int(objective_def.get("mismatch_score", 0))
		"supply":
			if _signal_has_resource_reward(signal_data):
				return int(objective_def.get("score", 0))
			return int(objective_def.get("mismatch_score", 0))
		_:
			return int(objective_def.get("score", 0))

func _signal_has_resource_reward(signal_data: Dictionary) -> bool:
	var reward: Dictionary = signal_data.get("reward", {})
	for key in ["power", "food", "medicine", "fuel", "parts"]:
		if int(reward.get(key, 0)) > 0:
			return true
	return false

func _day_stance_name(stance_id: String) -> String:
	var stance: Dictionary = DAY_STANCE_DEFS.get(_normalized_day_stance_id(stance_id), DAY_STANCE_DEFS["balanced"])
	return str(stance.get("name", stance_id))

func _normalized_day_stance_id(stance_id: String) -> String:
	if DAY_STANCE_DEFS.has(stance_id):
		return stance_id
	return "balanced"

func _day_stance_score_bonus(stance_id: String, location: Dictionary, signal_data: Dictionary) -> int:
	var active_id := _normalized_day_stance_id(stance_id)
	var stance: Dictionary = DAY_STANCE_DEFS.get(active_id, DAY_STANCE_DEFS["balanced"])
	var score := int(stance.get("score", 0))
	var tags := _mission_tags(location, signal_data)
	if str(location.get("type", "")) == "rescue" or tags.has("rescue"):
		score += int(stance.get("rescue_score", 0))
	if _signal_has_resource_reward(signal_data) or tags.has("supply") or tags.has("trade"):
		score += int(stance.get("supply_score", 0))
	return score

func _apply_day_stance_effect(stance_id: String, member_ids: Array[String]) -> void:
	var stance: Dictionary = DAY_STANCE_DEFS.get(_normalized_day_stance_id(stance_id), DAY_STANCE_DEFS["balanced"])
	resources["threat"] = max(0, int(resources.get("threat", 0)) + int(stance.get("threat", 0)))
	var stress_delta := int(stance.get("stress", 0))
	if stress_delta != 0:
		for member_id in member_ids:
			_adjust_member_stress(str(member_id), stress_delta)

func _day_stance_reward_multiplier(stance_id: String) -> float:
	var stance: Dictionary = DAY_STANCE_DEFS.get(_normalized_day_stance_id(stance_id), DAY_STANCE_DEFS["balanced"])
	return float(stance.get("reward_multiplier", 1.0))

func _day_stance_rescue_multiplier(stance_id: String) -> float:
	var stance: Dictionary = DAY_STANCE_DEFS.get(_normalized_day_stance_id(stance_id), DAY_STANCE_DEFS["balanced"])
	return float(stance.get("rescue_multiplier", 1.0))

func _day_stance_failure_risk(stance_id: String) -> int:
	var stance: Dictionary = DAY_STANCE_DEFS.get(_normalized_day_stance_id(stance_id), DAY_STANCE_DEFS["balanced"])
	return int(stance.get("failure_risk", 0))

func _objective_reward_multiplier(objective_id: String) -> float:
	var objective_def: Dictionary = OBJECTIVE_DEFS.get(_normalized_objective_id(objective_id), OBJECTIVE_DEFS["balanced"])
	return float(objective_def.get("reward_multiplier", 1.0))

func _objective_rescue_multiplier(objective_id: String) -> float:
	var objective_def: Dictionary = OBJECTIVE_DEFS.get(_normalized_objective_id(objective_id), OBJECTIVE_DEFS["balanced"])
	return float(objective_def.get("rescue_multiplier", 1.0))

func _objective_failure_risk(objective_id: String) -> int:
	var objective_def: Dictionary = OBJECTIVE_DEFS.get(_normalized_objective_id(objective_id), OBJECTIVE_DEFS["balanced"])
	return int(objective_def.get("failure_risk", 0))

func _apply_objective_effect(objective_id: String, member_ids: Array[String]) -> void:
	var objective_def: Dictionary = OBJECTIVE_DEFS.get(_normalized_objective_id(objective_id), OBJECTIVE_DEFS["balanced"])
	resources["threat"] = max(0, int(resources.get("threat", 0)) + int(objective_def.get("threat", 0)))
	var stress_delta := int(objective_def.get("stress", 0))
	if stress_delta != 0:
		for member_id in member_ids:
			_adjust_member_stress(str(member_id), stress_delta)

func _normalized_prep_id(prep_id: String) -> String:
	if PREP_DEFS.has(prep_id):
		return prep_id
	return "none"

func _can_pay_prep(prep_id: String) -> bool:
	var prep_def: Dictionary = PREP_DEFS.get(_normalized_prep_id(prep_id), PREP_DEFS["none"])
	var cost: Dictionary = prep_def.get("cost", {})
	for key in cost.keys():
		if int(resources.get(str(key), 0)) < int(cost[key]):
			return false
	return true

func _usable_prep_id(prep_id: String) -> String:
	var normalized := _normalized_prep_id(prep_id)
	if not _can_pay_prep(normalized):
		return "none"
	return normalized

func _apply_prep_cost(prep_id: String, member_ids: Array[String]) -> void:
	var prep_def: Dictionary = PREP_DEFS.get(_normalized_prep_id(prep_id), PREP_DEFS["none"])
	var cost: Dictionary = prep_def.get("cost", {})
	for key in cost.keys():
		resources[str(key)] = max(0, int(resources.get(str(key), 0)) - int(cost[key]))
	resources["threat"] = max(0, int(resources.get("threat", 0)) + int(prep_def.get("threat", 0)))
	var stress_delta := int(prep_def.get("stress", 0))
	if stress_delta != 0:
		for member_id in member_ids:
			_adjust_member_stress(str(member_id), stress_delta)

func _route_name(route_id: String) -> String:
	var route_def: Dictionary = ROUTE_DEFS.get(_normalized_route_id(route_id), ROUTE_DEFS["safe"])
	return str(route_def.get("name", route_id))

func _normalized_route_id(route_id: String) -> String:
	if ROUTE_DEFS.has(route_id):
		return route_id
	return "safe"

func _usable_route_id(route_id: String) -> String:
	var normalized := _normalized_route_id(route_id)
	var route_def: Dictionary = ROUTE_DEFS.get(normalized, ROUTE_DEFS["safe"])
	if int(route_def.get("fuel", 0)) > int(resources.get("fuel", 0)):
		logs.append("燃料不足，未知小路改走安全慢路。")
		return "safe"
	return normalized

func _apply_route_cost(route_id: String) -> void:
	var route_def: Dictionary = ROUTE_DEFS.get(_normalized_route_id(route_id), ROUTE_DEFS["safe"])
	resources["fuel"] = max(0, int(resources.get("fuel", 0)) - int(route_def.get("fuel", 0)))
	resources["threat"] = max(0, int(resources.get("threat", 0)) + int(route_def.get("threat", 0)))

func _route_reward_multiplier(route_id: String) -> float:
	var route_def: Dictionary = ROUTE_DEFS.get(_normalized_route_id(route_id), ROUTE_DEFS["safe"])
	return float(route_def.get("reward_multiplier", 1.0))

func _route_failure_risk(route_id: String) -> int:
	var route_def: Dictionary = ROUTE_DEFS.get(_normalized_route_id(route_id), ROUTE_DEFS["safe"])
	return int(route_def.get("failure_risk", 0))

func _score_probability(base_score: int) -> Dictionary:
	var success := 0
	var partial := 0
	var failure := 0
	for roll in range(-8, 9):
		var final_score := base_score + roll
		if final_score >= 70:
			success += 1
		elif final_score >= 45:
			partial += 1
		else:
			failure += 1
	var total := 17.0
	return {
		"score": base_score,
		"success": int(round(float(success) / total * 100.0)),
		"partial": int(round(float(partial) / total * 100.0)),
		"failure": int(round(float(failure) / total * 100.0))
	}

func _resolve_dispatch_score(score: int, location: Dictionary, signal_data: Dictionary, locked: bool, route_id: String = "safe", dispatched_member_ids: Array[String] = [], order_id: String = "steady", objective_id: String = "balanced", stance_id: String = "balanced") -> Dictionary:
	var result := {}
	var loc_id := str(location.get("id", ""))
	var title := str(signal_data.get("title", location.get("name", "")))
	var reward_multiplier := _route_reward_multiplier(route_id) * _order_reward_multiplier(order_id) * _objective_reward_multiplier(objective_id) * _day_stance_reward_multiplier(stance_id)
	var rescue_multiplier := _objective_rescue_multiplier(objective_id) * _day_stance_rescue_multiplier(stance_id)
	if score >= 70:
		_apply_signal_reward(signal_data, reward_multiplier, rescue_multiplier)
		if locations.has(loc_id):
			locations[loc_id]["status"] = "looted" if str(location.get("type", "")) == "supply" else "confirmed"
			locations[loc_id]["risk"] = max(5, int(locations[loc_id]["risk"]) - 15)
			_apply_location_memory(loc_id, "success", route_id, signal_data)
			_apply_objective_location_effect(loc_id, objective_id, "success")
		_apply_member_result_stress(dispatched_member_ids, "success", location, signal_data)
		var story_success := str((signal_data.get("outcome_story", {}) as Dictionary).get("success", ""))
		result["summary"] = story_success if story_success != "" else "外勤成功：%s。%s" % [title, str(signal_data.get("result", "队伍带回了有价值情报。"))]
		result["quality"] = "success"
	elif score >= 45:
		_apply_partial_reward(signal_data, reward_multiplier, rescue_multiplier)
		if locations.has(loc_id):
			locations[loc_id]["status"] = "danger"
			_apply_location_memory(loc_id, "partial", route_id, signal_data)
		_apply_objective_location_effect(loc_id, objective_id, "partial")
		_apply_member_result_stress(dispatched_member_ids, "partial", location, signal_data)
		var story_partial := str((signal_data.get("outcome_story", {}) as Dictionary).get("partial", ""))
		result["summary"] = story_partial if story_partial != "" else "外勤部分成功：%s。队伍带回一部分结果，但节点风险上升。" % title
		result["quality"] = "partial"
	else:
		_apply_signal_failure(signal_data)
		if not _order_protects_injury(order_id):
			_injure_random_dispatched(dispatched_member_ids)
		if locations.has(loc_id):
			locations[loc_id]["status"] = "danger"
			locations[loc_id]["risk"] = min(90, max(0, int(locations[loc_id]["risk"]) + (15 if locked else 25) + _route_failure_risk(route_id) + _order_failure_risk(order_id) + _objective_failure_risk(objective_id) + _day_stance_failure_risk(stance_id)))
		_apply_location_memory(loc_id, "failure", route_id, signal_data)
		_apply_member_result_stress(dispatched_member_ids, "failure", location, signal_data)
		var story_failure := str((signal_data.get("outcome_story", {}) as Dictionary).get("failure", ""))
		result["summary"] = story_failure if story_failure != "" else "外勤失败：%s。情报%s，队伍遭遇意外。" % [title, "已锁定但准备不足" if locked else "未确认"]
		result["quality"] = "failure"
	var intel_review := _apply_intel_review(signal_data, dispatched_member_ids)
	if not intel_review.is_empty():
		result["intel_review"] = intel_review
	var bond_review := _apply_team_bond_result(dispatched_member_ids, str(result.get("quality", "")))
	if not bond_review.is_empty():
		result["team_bond"] = bond_review
	var feed_lines := _dispatch_feed_lines(str(result.get("quality", "")), route_id, location, score, order_id, objective_id)
	if not intel_review.is_empty():
		feed_lines.append(str(intel_review.get("line", "")))
	if not bond_review.is_empty():
		feed_lines.append(str(bond_review.get("line", "")))
	result["feed_lines"] = feed_lines
	return result

func _dispatch_feed_lines(quality: String, route_id: String, location: Dictionary, score: int, order_id: String = "steady", objective_id: String = "balanced") -> Array[String]:
	var route_label := _route_name(route_id)
	var order_label := _order_name(order_id)
	var target_name := str(location.get("name", "未知节点"))
	match quality:
		"success":
			return [
				"队伍按「%s」沿%s抵达%s，信号稳定。" % [order_label, route_label, target_name],
				"回传坐标和现场标记，准备值压过风险。",
				"外勤队带着情报和物资返回基地。"
			]
		"partial":
			return [
				"队伍按「%s」沿%s推进，%s附近出现干扰。" % [order_label, route_label, target_name],
				"频道里夹着杂音，只确认了一部分目标。",
				"队伍撤回，节点风险继续上升。"
			]
		"failure":
			return [
				"队伍按「%s」沿%s进入%s后短暂失联。" % [order_label, route_label, target_name],
				"最后一次回传只有碰撞声和断续呼号。",
				"结算值 %d，准备不足导致外勤失败。" % score
			]
		_:
			return [
				"队伍离开基地。",
				"电台等待回传。",
				"结果将在夜间报告中记录。"
			]

func _apply_intel_review(signal_data: Dictionary, dispatched_member_ids: Array[String] = []) -> Dictionary:
	if signal_data.is_empty():
		return {}
	var signal_id := str(signal_data.get("id", ""))
	var mark_id := str(signal_marks.get(signal_id, ""))
	if mark_id == "":
		return {}
	var mark_score := _signal_mark_score(signal_data, mark_id)
	var mark_label := _signal_mark_label(mark_id)
	var review := {
		"signal_id": signal_id,
		"title": str(signal_data.get("title", "")),
		"mark_id": mark_id,
		"mark_label": mark_label,
		"mark_score": mark_score
	}
	if mark_score > 0:
		resources["influence"] = int(resources.get("influence", 0)) + 1
		_adjust_member_stress("shen_luo", -3)
		review["quality"] = "hit"
		review["line"] = "情报复盘：判断「%s」命中，电台影响 +1，Elias Reed压力 -3。" % mark_label
	elif mark_score < 0:
		resources["trust"] = max(0, int(resources.get("trust", 0)) - 1)
		for member_id in dispatched_member_ids:
			_adjust_member_stress(str(member_id), 4)
		review["quality"] = "miss"
		review["line"] = "情报复盘：判断「%s」失准，基地信任 -1，外勤成员压力 +4。" % mark_label
	else:
		review["quality"] = "neutral"
		review["line"] = "情报复盘：判断「%s」没有提供明确优势。" % mark_label
	intel_reviews.append(review.duplicate(true))
	return review

func _show_night_report() -> void:
	if not dispatched_today:
		_refresh_objective()
		return
	var lines := _night_lines()
	_clear(overlay_layer)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var report := REPORT_SCENE.instantiate()
	report.continue_pressed.connect(func() -> void:
		_clear(overlay_layer)
		overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if day >= MAX_DAY:
			final_report = _build_final_report()
			logs.append("三天切片结束：%s，评分 %d。" % [str(final_report.get("outcome", "")), int(final_report.get("score", 0))])
			_refresh_logs()
			_show_final_report()
			return
		_start_day(day + 1)
	)
	overlay_layer.add_child(report)
	report.setup(day, lines, day >= MAX_DAY, night_report_events, night_report_summary)

func _build_final_report() -> Dictionary:
	var unresolved_people := _unresolved_people_count()
	var danger_locations := _danger_location_count()
	var injured_members := _member_status_count("injured")
	var tired_members := _member_status_count("tired")
	var score := int(resources.get("trust", 0))
	score += int(resources.get("rescued", 0)) * 14
	score += int(resources.get("influence", 0)) * 10
	score += directive_success_count * 6
	score += min(10, int(resources.get("food", 0))) * 2
	score += min(8, int(resources.get("power", 0))) * 2
	score += min(8, int(resources.get("medicine", 0)))
	score += int(resources.get("fuel", 0)) * 2
	score -= int(resources.get("threat", 0)) * 12
	score -= unresolved_people * 8
	score -= danger_locations * 6
	score -= injured_members * 10
	score -= tired_members * 4
	score = clamp(score, 0, 140)
	var outcome := _final_outcome(score)
	var rank := _final_rank(score)
	var lines: Array[String] = [
		"救回 %d 人，信任 %d，影响力 %d，暴露 %d。" % [
			int(resources.get("rescued", 0)),
			int(resources.get("trust", 0)),
			int(resources.get("influence", 0)),
			int(resources.get("threat", 0))
		],
		"剩余资源：食物 %d，电力 %d，药品 %d，燃料 %d。" % [
			int(resources.get("food", 0)),
			int(resources.get("power", 0)),
			int(resources.get("medicine", 0)),
			int(resources.get("fuel", 0))
		],
		"未救援人数 %d，危险节点 %d，伤员 %d，疲惫成员 %d。" % [
			unresolved_people,
			danger_locations,
			injured_members,
			tired_members
		],
		"完成每日委托 %d/3，额外评分 %+d。" % [directive_success_count, directive_success_count * 6],
		"评级 %s：%s。" % [rank, outcome]
	]
	return {
		"score": score,
		"rank": rank,
		"outcome": outcome,
		"lines": lines,
		"rescued": int(resources.get("rescued", 0)),
		"trust": int(resources.get("trust", 0)),
		"influence": int(resources.get("influence", 0)),
		"threat": int(resources.get("threat", 0)),
		"unresolved_people": unresolved_people,
		"danger_locations": danger_locations,
		"injured_members": injured_members,
		"tired_members": tired_members,
		"directive_success_count": directive_success_count
	}

func _show_final_report() -> void:
	if final_report.is_empty():
		final_report = _build_final_report()
	_clear(overlay_layer)
	overlay_layer.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 570)
	panel.size = Vector2(960, 570)
	panel.position = Vector2(160, 75)
	panel.add_theme_stylebox_override("panel", _final_panel_style(Color(0.018, 0.026, 0.028, 0.98), Color(1.0, 0.78, 0.36, 0.95), 2))
	overlay_layer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "三日最终电报"
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.45))
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "%s  /  评级 %s  /  评分 %d" % [
		str(final_report.get("outcome", "")),
		str(final_report.get("rank", "")),
		int(final_report.get("score", 0))
	]
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", _final_rank_color(str(final_report.get("rank", ""))))
	root.add_child(subtitle)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(390, 0)
	left.add_theme_constant_override("separation", 10)
	body.add_child(left)
	_add_final_metric(left, "救回人数", int(final_report.get("rescued", 0)), Color(0.48, 1.0, 0.66))
	_add_final_metric(left, "基地信任", int(final_report.get("trust", 0)), Color(0.72, 0.94, 1.0))
	_add_final_metric(left, "电台影响", int(final_report.get("influence", 0)), Color(1.0, 0.84, 0.45))
	_add_final_metric(left, "暴露度", int(final_report.get("threat", 0)), Color(1.0, 0.46, 0.38))
	_add_final_metric(left, "未救援", int(final_report.get("unresolved_people", 0)), Color(1.0, 0.70, 0.42))

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	var ending_image := TextureRect.new()
	ending_image.texture = _load_texture("res://assets/new/named/ending_lighthouse.png")
	ending_image.custom_minimum_size = Vector2(0, 150)
	ending_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ending_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ending_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ending_image.texture != null:
		right.add_child(ending_image)
	var lines: Array = final_report.get("lines", [])
	for line in lines:
		var label := Label.new()
		label.text = str(line)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
		right.add_child(label)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	root.add_child(footer)
	var hint := Label.new()
	hint.text = "这不是终点，只是这一段广播留下的城市记忆。"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.70, 0.82, 0.78))
	footer.add_child(hint)
	var restart := Button.new()
	restart.text = "重新开局"
	restart.custom_minimum_size = Vector2(160, 46)
	restart.pressed.connect(func() -> void:
		_clear(overlay_layer)
		overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reset_run()
	)
	footer.add_child(restart)

func _add_final_metric(root: VBoxContainer, label: String, value: int, color: Color) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _final_panel_style(Color(0.035, 0.052, 0.050, 0.94), Color(color.r, color.g, color.b, 0.62), 1))
	root.add_child(row)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 10)
	margin.add_child(line)
	var name := Label.new()
	name.text = label
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", 16)
	name.add_theme_color_override("font_color", Color(0.86, 0.94, 0.90))
	line.add_child(name)
	var number := Label.new()
	number.text = str(value)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.custom_minimum_size = Vector2(70, 0)
	number.add_theme_font_size_override("font_size", 20)
	number.add_theme_color_override("font_color", color)
	line.add_child(number)

func _final_outcome(score: int) -> String:
	if score >= 110:
		return "稳定广播"
	if score >= 82:
		return "守住电台"
	if score >= 55:
		return "勉强存续"
	return "频段失守"

func _final_rank(score: int) -> String:
	if score >= 110:
		return "S"
	if score >= 92:
		return "A"
	if score >= 72:
		return "B"
	if score >= 55:
		return "C"
	return "D"

func _final_rank_color(rank: String) -> Color:
	match rank:
		"S":
			return Color(0.58, 1.0, 0.70)
		"A":
			return Color(0.72, 0.94, 1.0)
		"B":
			return Color(1.0, 0.84, 0.45)
		"C":
			return Color(1.0, 0.64, 0.36)
		_:
			return Color(1.0, 0.42, 0.34)

func _unresolved_people_count() -> int:
	var count := 0
	for location_id in locations.keys():
		if str(location_id) == "base":
			continue
		var location: Dictionary = locations[location_id]
		count += max(0, int(location.get("people_left", 0)))
	return count

func _danger_location_count() -> int:
	var count := 0
	for location_id in locations.keys():
		if str(location_id) == "base":
			continue
		var location: Dictionary = locations[location_id]
		if str(location.get("status", "")) == "danger" or int(location.get("danger_trend", 0)) >= 3:
			count += 1
	return count

func _member_status_count(status: String) -> int:
	var count := 0
	for member_id in members.keys():
		if str(members[member_id].get("status", "normal")) == status:
			count += 1
	return count

func _final_panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _night_lines() -> Array[String]:
	var resources_before := resources.duplicate(true)
	var stress_before := _member_stress_snapshot()
	var status_before := _member_status_snapshot()
	var lines: Array[String] = []
	if last_dispatch_result.is_empty():
		lines.append("今天没有派出外勤队，未处理信号在城市里继续发酵。")
		resources["trust"] = max(0, int(resources["trust"]) - 2)
		resources["threat"] = int(resources["threat"]) + 1
	else:
		lines.append(str(last_dispatch_result.get("summary", "")))
		if str(last_dispatch_result.get("signal_id", "")) == "d1_north_bridge_help":
			match str(last_dispatch_result.get("quality", "")):
				"success":
					lines.append("北桥救回的母子睡在看台下，孩子还攥着一截耳机线。")
					lines.append("基地更愿意相信你的判断，但今晚口粮更紧。")
					lines.append("Mara 对这次救援松了一口气。")
				"partial":
					lines.append("母亲被安置在看台下，北桥三楼仍有人等着下一次回传。")
					lines.append("基地知道你尽力了，但今晚口粮更紧。")
				"failure":
					lines.append("北桥的敲击声停了。Mara 很久没有摘下手套。")
		var intel_review: Dictionary = last_dispatch_result.get("intel_review", {})
		if not intel_review.is_empty():
			lines.append(str(intel_review.get("line", "")))
	_resolve_daily_directive(lines)
	var base_power_cost: int = max(0, 1 - int(base_upgrades.get("battery", 0)))
	var power_cost: int = _apply_night_policy(lines, base_power_cost)
	var food_save := _apply_night_watch(lines)
	if not pending_rest_report_lines.is_empty():
		for rest_line in pending_rest_report_lines:
			lines.append(str(rest_line))
		pending_rest_report_lines.clear()
	var raw_shelter_food_cost := _raw_shelter_food_pressure_for_count(int(resources.get("rescued", 0)))
	var base_shelter_relief: int = min(_base_shelter_relief(), raw_shelter_food_cost)
	var shelter_after_base: int = max(0, raw_shelter_food_cost - base_shelter_relief)
	var shelter_policy_relief: int = min(_night_policy_shelter_relief(), shelter_after_base)
	var shelter_food_cost: int = max(0, shelter_after_base - shelter_policy_relief)
	var food_cost: int = max(0, 2 + shelter_food_cost - food_save)
	if base_shelter_relief > 0:
		lines.append("医务角安置：分诊和床位让口粮压力 -%d。" % base_shelter_relief)
	if shelter_policy_relief > 0:
		lines.append("安置值守：腾出临时床位，口粮压力 -%d。" % shelter_policy_relief)
	if shelter_food_cost > 0:
		lines.append("安置压力：救回 %d 人，今晚额外消耗 %d 食物。" % [
			int(resources.get("rescued", 0)),
			shelter_food_cost
		])
	var food_before_spend := int(resources.get("food", 0))
	resources["food"] = max(0, food_before_spend - food_cost)
	resources["power"] = max(0, int(resources["power"]) - power_cost)
	if food_before_spend < food_cost:
		var shortage := food_cost - food_before_spend
		var stress_gain := shortage * 2
		resources["trust"] = max(0, int(resources.get("trust", 0)) - shortage)
		_adjust_all_member_stress(stress_gain)
		lines.append("安置缺口：食物不足，信任 -%d，全员压力 +%d。" % [shortage, stress_gain])
	lines.append("夜间消耗：-%d 食物，-%d 电力。" % [food_cost, power_cost])
	_advance_unhandled_locations(lines)
	_apply_night_crisis(lines)
	_apply_infirmary_recovery(lines)
	_apply_stress_reactions(lines)
	if int(resources["threat"]) >= 4:
		var trust_loss: int = max(0, 3 - int(base_upgrades.get("gate", 0)))
		resources["trust"] = max(0, int(resources["trust"]) - trust_loss)
		lines.append("暴露度过高，夜里有人试探大门：-%d 信任。" % trust_loss)
	resources["threat"] = max(0, int(resources["threat"]) - 1)
	night_report_lines = lines.duplicate()
	night_report_events = _build_night_report_events(lines)
	night_report_summary = _build_night_report_summary(resources_before, stress_before, status_before)
	logs.append("Day %d 夜：%s" % [day, " / ".join(lines)])
	_refresh_all()
	return lines

func _resolve_daily_directive(lines: Array[String]) -> bool:
	if current_directive.is_empty() or directive_resolved:
		return false
	directive_resolved = true
	var success := _directive_condition_met(current_directive)
	var delta: Dictionary = current_directive.get("reward", {}) if success else current_directive.get("failure", {})
	_apply_resource_delta(delta)
	if success:
		directive_success_count += 1
		lines.append("今日委托完成「%s」：%s。" % [
			str(current_directive.get("title", "")),
			_format_resource_delta(delta)
		])
	else:
		lines.append("今日委托失手「%s」：%s。" % [
			str(current_directive.get("title", "")),
			_format_resource_delta(delta)
		])
	return success

func _directive_condition_met(directive: Dictionary) -> bool:
	if last_dispatch_result.is_empty():
		return false
	var quality := str(last_dispatch_result.get("quality", ""))
	match str(directive.get("condition", "")):
		"rescue_not_failed":
			var location_id := str(last_dispatch_result.get("location_id", ""))
			var location: Dictionary = locations.get(location_id, {})
			return str(location.get("type", "")) == "rescue" and quality != "failure"
		"resource_reward_not_failed":
			if quality == "failure":
				return false
			var signal_data := _signal_by_id(str(last_dispatch_result.get("signal_id", "")))
			var reward: Dictionary = signal_data.get("reward", {})
			for key in ["power", "food", "medicine", "fuel", "parts"]:
				if int(reward.get(key, 0)) > 0:
					return true
			return false
		"threat_at_most":
			return int(resources.get("threat", 0)) <= int(directive.get("max_threat", 2))
		_:
			return false

func _apply_night_policy(lines: Array[String], base_power_cost: int) -> int:
	var policy: Dictionary = NIGHT_POLICY_DEFS.get(night_policy_id, NIGHT_POLICY_DEFS["normal"])
	var policy_name := str(policy.get("name", "常规值守"))
	var power_cost: int = max(0, base_power_cost + int(policy.get("power_delta", 0)))
	next_day_listen_bonus = int(policy.get("listen_bonus", 0))
	var trust_delta := int(policy.get("trust", 0))
	var influence_delta := int(policy.get("influence", 0))
	var threat_delta := int(policy.get("threat", 0))
	if trust_delta != 0:
		resources["trust"] = max(0, int(resources.get("trust", 0)) + trust_delta)
	if influence_delta != 0:
		resources["influence"] = int(resources.get("influence", 0)) + influence_delta
	if threat_delta != 0:
		resources["threat"] = max(0, int(resources.get("threat", 0)) + threat_delta)
	var stress_delta := int(policy.get("stress", 0))
	if stress_delta != 0:
		for member_id in members.keys():
			_adjust_member_stress(str(member_id), stress_delta)
	if night_policy_id != "normal":
		lines.append("值守策略：%s，电力消耗调整为 %d，次日监听 %+d。" % [
			policy_name,
			power_cost,
			next_day_listen_bonus
		])
	return power_cost

func _shelter_food_pressure() -> int:
	return _shelter_food_pressure_for_count(int(resources.get("rescued", 0)), _base_shelter_relief())

func _base_shelter_relief() -> int:
	return max(0, int(base_upgrades.get("infirmary", 0)))

func _night_policy_shelter_relief() -> int:
	var policy: Dictionary = NIGHT_POLICY_DEFS.get(night_policy_id, NIGHT_POLICY_DEFS["normal"])
	return max(0, int(policy.get("shelter_relief", 0)))

func _shelter_food_pressure_for_count(rescued_count: int, relief: int = 0) -> int:
	return max(0, _raw_shelter_food_pressure_for_count(rescued_count) - max(0, relief))

func _raw_shelter_food_pressure_for_count(rescued_count: int) -> int:
	rescued_count = max(0, rescued_count)
	if rescued_count <= 0:
		return 0
	return min(3, int(floor(float(rescued_count) / 2.0)))

func _apply_night_watch(lines: Array[String]) -> int:
	if night_watch_member_id == "none":
		return 0
	if not members.has(night_watch_member_id):
		return 0
	var member: Dictionary = members[night_watch_member_id]
	if not _member_available(member):
		lines.append("值班缺席：%s 无法承担夜间岗位。" % str(member.get("name", night_watch_member_id)))
		return 0
	var def: Dictionary = NIGHT_WATCH_DEFS.get(night_watch_member_id, NIGHT_WATCH_DEFS["none"])
	var member_name := str(member.get("name", night_watch_member_id))
	var listen_bonus := int(def.get("listen_bonus", 0))
	var food_save := int(def.get("food_save", 0))
	var stress_relief := int(def.get("stress_relief", 0))
	var threat_delta := int(def.get("threat", 0))
	var trust_delta := int(def.get("trust", 0))
	if listen_bonus != 0:
		next_day_listen_bonus += listen_bonus
	if threat_delta != 0:
		resources["threat"] = max(0, int(resources.get("threat", 0)) + threat_delta)
	if trust_delta != 0:
		resources["trust"] = max(0, int(resources.get("trust", 0)) + trust_delta)
	if stress_relief != 0:
		for other_id in members.keys():
			if str(other_id) == night_watch_member_id:
				continue
			_adjust_member_stress(str(other_id), -stress_relief)
	var stress_delta := int(def.get("stress", 0))
	if stress_delta != 0:
		_adjust_member_stress(night_watch_member_id, stress_delta)
	lines.append("值班成员：%s，%s。" % [member_name, str(def.get("brief", "完成夜间岗位"))])
	return max(0, food_save)

func _member_stress_snapshot() -> Dictionary:
	var snapshot := {}
	for member_id in members.keys():
		snapshot[str(member_id)] = int((members[member_id] as Dictionary).get("stress", 0))
	return snapshot

func _member_status_snapshot() -> Dictionary:
	var snapshot := {}
	for member_id in members.keys():
		snapshot[str(member_id)] = str((members[member_id] as Dictionary).get("status", "normal"))
	return snapshot

func _build_night_report_summary(resources_before: Dictionary, stress_before: Dictionary, status_before: Dictionary) -> Dictionary:
	var resource_delta := {}
	for key in ["food", "power", "medicine", "fuel", "parts", "trust", "influence", "threat", "rescued"]:
		var delta := int(resources.get(key, 0)) - int(resources_before.get(key, 0))
		if delta != 0:
			resource_delta[key] = delta
	var stress_delta := 0
	var status_changes: Array[String] = []
	for member_id in members.keys():
		var id := str(member_id)
		var member: Dictionary = members[id]
		stress_delta += int(member.get("stress", 0)) - int(stress_before.get(id, 0))
		var old_status := str(status_before.get(id, "normal"))
		var new_status := str(member.get("status", "normal"))
		if old_status != new_status:
			status_changes.append("%s %s>%s" % [
				str(member.get("name", id)),
				_status_label(old_status),
				_status_label(new_status)
			])
	var pressure := "stable"
	if int(resource_delta.get("trust", 0)) < 0 or int(resource_delta.get("threat", 0)) > 0 or stress_delta >= 8:
		pressure = "bad"
	elif int(resource_delta.get("trust", 0)) > 0 or int(resource_delta.get("influence", 0)) > 0 or stress_delta < 0:
		pressure = "good"
	return {
		"resource_delta": resource_delta,
		"stress_delta": stress_delta,
		"status_changes": status_changes,
		"pressure": pressure
	}

func _build_night_report_events(lines: Array[String]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in range(lines.size()):
		events.append(_night_event_from_line(lines[i], i))
	if events.is_empty():
		events.append({
			"phase": "quiet",
			"title": "静默值守",
			"body": "今晚没有新的回放记录。",
			"facility": "base",
			"resource": "none",
			"severity": "neutral"
		})
	return events

func _night_event_from_line(line: String, index: int) -> Dictionary:
	var phase := "base"
	var title := "基地记录"
	if index == 0:
		phase = "dispatch"
		title = "外勤回传"
	if line.find("夜间消耗") >= 0:
		phase = "consumption"
		title = "值守消耗"
	elif line.find("夜间危机") >= 0:
		phase = "crisis"
		title = "夜间危机"
	elif line.find("医务角") >= 0:
		phase = "infirmary"
		title = "医务处理"
	elif line.find("压力") >= 0 or line.find("没有合眼") >= 0 or line.find("疲惫") >= 0:
		phase = "member"
		title = "成员状态"
	elif line.find("忽视") >= 0 or line.find("未处理") >= 0 or line.find("城市") >= 0:
		phase = "city"
		title = "城市余波"
	elif line.find("暴露") >= 0 or line.find("大门") >= 0:
		phase = "security"
		title = "基地警戒"
	var facility := _night_event_facility(line, phase)
	var severity := _night_event_severity(line)
	var resource := _night_event_resource(line)
	return {
		"phase": phase,
		"title": title,
		"body": line,
		"facility": facility,
		"resource": resource,
		"severity": severity
	}

func _night_event_facility(line: String, phase: String) -> String:
	if line.find("天线") >= 0 or line.find("频段") >= 0 or line.find("监听") >= 0:
		return "antenna"
	if line.find("大门") >= 0 or line.find("陌生人") >= 0 or line.find("暴露") >= 0:
		return "gate"
	if line.find("医务") >= 0 or line.find("伤势") >= 0 or line.find("药品") >= 0 or line.find("疲惫") >= 0 or line.find("压力") >= 0:
		return "infirmary"
	if line.find("电力") >= 0 or line.find("蓄电") >= 0 or line.find("停电") >= 0 or line.find("冷藏") >= 0:
		return "battery"
	if phase == "consumption":
		return "battery"
	return "base"

func _night_event_resource(line: String) -> String:
	if line.find("食物") >= 0 or line.find("口粮") >= 0:
		return "food"
	if line.find("电力") >= 0 or line.find("蓄电") >= 0:
		return "power"
	if line.find("信任") >= 0:
		return "trust"
	if line.find("暴露") >= 0:
		return "threat"
	if line.find("药品") >= 0:
		return "medicine"
	return "none"

func _night_event_severity(line: String) -> String:
	if line.find("失败") >= 0 or line.find("受损") >= 0 or line.find("试探") >= 0 or line.find("暴露") >= 0:
		return "danger"
	if line.find("危机") >= 0 or line.find("忽视") >= 0 or line.find("未处理") >= 0 or line.find("压力") >= 0 or line.find("疲惫") >= 0:
		return "warning"
	if line.find("成功") >= 0 or line.find("恢复") >= 0 or line.find("保持稳定") >= 0 or line.find("救援") >= 0:
		return "good"
	return "neutral"

func _apply_crisis_response(lines: Array[String]) -> int:
	var response_id := night_crisis_response_id
	if not NIGHT_CRISIS_RESPONSE_DEFS.has(response_id) or not _can_pay_crisis_response(response_id):
		response_id = "hold"
	var response: Dictionary = NIGHT_CRISIS_RESPONSE_DEFS.get(response_id, NIGHT_CRISIS_RESPONSE_DEFS["hold"])
	if response_id == "hold":
		_adjust_all_member_stress(int(response.get("stress", 0)))
		lines.append("危机应对：硬扛，不消耗资源。")
		return 0
	var cost: Dictionary = response.get("cost", {})
	for key in cost.keys():
		resources[str(key)] = max(0, int(resources.get(str(key), 0)) - int(cost[key]))
	var matched := _crisis_response_matches(response_id, str(pending_crisis.get("id", "")))
	var mitigation := int(response.get("mitigation", 0))
	if not matched:
		mitigation = int(floor(float(mitigation) * 0.5))
	else:
		for key in ["trust", "influence", "threat"]:
			var delta := int(response.get(key, 0))
			if delta != 0:
				resources[key] = max(0, int(resources.get(key, 0)) + delta)
		next_day_listen_bonus += int(response.get("listen_bonus", 0))
	_adjust_all_member_stress(int(response.get("stress", 0)))
	lines.append("危机应对：%s%s，缓冲 +%d。" % [
		str(response.get("name", response_id)),
		"生效" if matched else "不完全匹配",
		mitigation
	])
	return mitigation

func _apply_night_crisis(lines: Array[String]) -> void:
	if pending_crisis.is_empty():
		return
	if str(pending_crisis.get("id", "")) == "antenna_fault" and (_was_signal_handled("d3_antenna_crisis") or int(base_upgrades.get("antenna", 0)) >= 2):
		lines.append("夜间危机：天线偏转被及时修正，远距频段保持稳定。")
		resources["influence"] = int(resources.get("influence", 0)) + 1
		return
	var mitigation := _apply_crisis_response(lines)
	match str(pending_crisis.get("id", "")):
		"antenna_fault":
			if _was_signal_handled("d3_antenna_crisis") or int(base_upgrades.get("antenna", 0)) >= 2:
				lines.append("夜间危机：天线偏转被及时修正，远距频段保持稳定。")
				resources["influence"] = int(resources.get("influence", 0)) + 1
				return
			var loss: int = max(0, 3 - int(base_upgrades.get("antenna", 0)) - int(base_upgrades.get("battery", 0)) - mitigation)
			var trust_loss := 0 if mitigation >= 2 else 1
			resources["power"] = max(0, int(resources.get("power", 0)) - loss)
			resources["trust"] = max(0, int(resources.get("trust", 0)) - trust_loss)
			lines.append("夜间危机：天线未修好，电台远距频段丢失一段时间：-%d 电力，-1 信任。" % loss)
		"gate_probe":
			var threat_gain: int = max(0, 2 - int(base_upgrades.get("gate", 0)) - mitigation)
			var trust_loss: int = max(0, 2 - int(base_upgrades.get("gate", 0)) - mitigation)
			resources["threat"] = int(resources.get("threat", 0)) + threat_gain
			resources["trust"] = max(0, int(resources.get("trust", 0)) - trust_loss)
			lines.append("夜间危机：陌生人试探大门：+%d 暴露，-%d 信任。" % [threat_gain, trust_loss])
		"blackout":
			var medicine_loss: int = max(0, 2 - int(base_upgrades.get("battery", 0)) - mitigation)
			resources["medicine"] = max(0, int(resources.get("medicine", 0)) - medicine_loss)
			lines.append("夜间危机：蓄电不足导致冷藏药品受损：-%d 药品。" % medicine_loss)
		"ration_pressure":
			var trust_loss: int = 2
			if int(base_upgrades.get("gate", 0)) > 0:
				trust_loss = 1
			trust_loss = max(0, trust_loss - mitigation)
			resources["trust"] = max(0, int(resources.get("trust", 0)) - trust_loss)
			lines.append("夜间危机：口粮争执让基地气氛紧绷：-%d 信任。" % trust_loss)

func _apply_infirmary_recovery(lines: Array[String]) -> void:
	var level := int(base_upgrades.get("infirmary", 0))
	if level <= 0:
		return
	for member_id in members.keys():
		if str(members[member_id].get("status", "")) == "injured":
			members[member_id]["status"] = "tired"
			_adjust_member_stress(str(member_id), -10)
			lines.append("医务角处理了 %s 的伤势，状态转为疲惫。" % str(members[member_id].get("name", member_id)))
			return
	if level < 2:
		return
	for member_id in members.keys():
		if str(members[member_id].get("status", "")) == "tired":
			members[member_id]["status"] = "normal"
			_adjust_member_stress(str(member_id), -8)
			lines.append("医务角安排轮休，%s 恢复正常。" % str(members[member_id].get("name", member_id)))
			return

func _was_signal_handled(signal_id: String) -> bool:
	return str(last_dispatch_result.get("signal_id", "")) == signal_id and str(last_dispatch_result.get("quality", "")) != "failure"

func _apply_location_memory(location_id: String, quality: String, route_id: String, signal_data: Dictionary) -> void:
	if not locations.has(location_id):
		return
	var location: Dictionary = locations[location_id]
	location["last_visit_day"] = day
	_add_location_flag(location, "%s_dispatch" % quality)
	match quality:
		"success":
			location["danger_trend"] = max(0, int(location.get("danger_trend", 0)) - 1)
			_reduce_location_stakes(location, signal_data, 1.0)
		"partial":
			location["danger_trend"] = int(location.get("danger_trend", 0)) + 1
			_reduce_location_stakes(location, signal_data, 0.5)
		"failure":
			location["danger_trend"] = int(location.get("danger_trend", 0)) + 2
			_add_location_flag(location, "failed_dispatch")
			if _normalized_route_id(route_id) == "unknown":
				location["danger_trend"] = int(location.get("danger_trend", 0)) + 1
	if int(location.get("danger_trend", 0)) >= 3 and str(location.get("type", "")) != "base":
		location["status"] = "danger"

func _apply_objective_location_effect(location_id: String, objective_id: String, quality: String) -> void:
	if not locations.has(location_id):
		return
	if _normalized_objective_id(objective_id) != "scout":
		return
	var location: Dictionary = locations[location_id]
	_add_location_flag(location, "scouted")
	if quality == "success":
		location["risk"] = max(5, int(location.get("risk", 0)) - 12)
		location["danger_trend"] = max(0, int(location.get("danger_trend", 0)) - 1)
	elif quality == "partial":
		location["risk"] = max(5, int(location.get("risk", 0)) - 5)

func _reduce_location_stakes(location: Dictionary, signal_data: Dictionary, ratio: float) -> void:
	var reward: Dictionary = signal_data.get("reward", {})
	var rescued_delta := int(ceil(float(reward.get("rescued", 0)) * ratio))
	if rescued_delta > 0:
		location["people_left"] = max(0, int(location.get("people_left", 0)) - rescued_delta)
		return
	if int(location.get("supplies_left", 0)) > 0:
		location["supplies_left"] = max(0, int(location.get("supplies_left", 0)) - max(1, int(ceil(ratio))))

func _add_location_flag(location: Dictionary, flag: String) -> void:
	var flags: Array = location.get("flags", [])
	if not flags.has(flag):
		flags.append(flag)
	location["flags"] = flags

func _advance_unhandled_locations(lines: Array[String]) -> void:
	var ignored_names: Array[String] = []
	for location_id in locations.keys():
		if str(location_id) == "base":
			continue
		var location: Dictionary = locations[location_id]
		if str(location.get("type", "")) != "rescue":
			continue
		if int(location.get("people_left", 0)) <= 0:
			continue
		if int(location.get("last_visit_day", 0)) == day:
			continue
		location["danger_trend"] = int(location.get("danger_trend", 0)) + 1
		if int(location.get("danger_trend", 0)) >= 3:
			location["status"] = "danger"
		ignored_names.append(str(location.get("name", location_id)))
	if ignored_names.is_empty():
		return
	resources["trust"] = max(0, int(resources.get("trust", 0)) - ignored_names.size())
	_adjust_member_stress("xu_lan", 12 * ignored_names.size())
	lines.append("未处理救援点继续恶化：%s，-%d 信任。" % ["、".join(ignored_names), ignored_names.size()])

func _apply_member_result_stress(member_ids: Array[String], quality: String, location: Dictionary, signal_data: Dictionary) -> void:
	for member_id in member_ids:
		match quality:
			"success":
				_adjust_member_stress(str(member_id), -4)
			"partial":
				_adjust_member_stress(str(member_id), 5)
			"failure":
				_adjust_member_stress(str(member_id), 15)
	if quality == "success":
		var location_type := str(location.get("type", ""))
		var need_tags: Array = signal_data.get("need_tags", [])
		if location_type == "rescue":
			_adjust_member_stress("xu_lan", -8)
		if location_type == "supply" or location_type == "medical" or need_tags.has("trade") or need_tags.has("supply"):
			_adjust_member_stress("lao_zhou", -6)
		if location_type == "base" or need_tags.has("radio") or need_tags.has("repair"):
			_adjust_member_stress("shen_luo", -6)

func _adjust_member_stress(member_id: String, delta: int) -> void:
	if not members.has(member_id):
		return
	var member: Dictionary = members[member_id]
	member["stress"] = clamp(int(member.get("stress", 0)) + delta, 0, 100)

func _adjust_all_member_stress(delta: int) -> void:
	if delta == 0:
		return
	for member_id in members.keys():
		_adjust_member_stress(str(member_id), delta)

func _member_available(member: Dictionary) -> bool:
	var status := str(member.get("status", "normal"))
	return status == "normal" or status == "tired"

func _apply_stress_reactions(lines: Array[String]) -> void:
	for member_id in members.keys():
		var member: Dictionary = members[member_id]
		if int(member.get("stress", 0)) < 85:
			continue
		if int(member.get("last_stress_reaction_day", 0)) == day:
			continue
		member["last_stress_reaction_day"] = day
		if str(member.get("status", "normal")) == "normal":
			member["status"] = "tired"
		lines.append("%s 压力过高，夜里几乎没有合眼。" % str(member.get("name", member_id)))

func _best_signal_for_location(location_id: String) -> Dictionary:
	for signal_data in day_signals:
		if str(signal_data.get("location", "")) == location_id:
			return signal_data
	return {}

func _signal_by_id(signal_id: String) -> Dictionary:
	for signal_data in day_signals:
		if str(signal_data.get("id", "")) == signal_id:
			return signal_data
	return {}

func _member_bonus(member_id: String, location: Dictionary, signal_data: Dictionary) -> int:
	var member: Dictionary = members.get(member_id, {})
	var bonus := 0
	var strengths: Array = member.get("strengths", [])
	var weaknesses: Array = member.get("weaknesses", [])
	var tags := _mission_tags(location, signal_data)
	for tag in tags:
		if strengths.has(tag):
			bonus += 12
		if weaknesses.has(tag):
			bonus -= 6
	if str(member.get("status", "")) == "tired":
		bonus -= 8
	if int(member.get("stress", 0)) >= 60:
		bonus -= 8
	if member_id == "shen_luo" and str(location.get("type", "")) != "base":
		bonus -= 5
	return bonus

func _team_synergy_bonus(member_ids: Array[String], location: Dictionary, signal_data: Dictionary) -> int:
	if member_ids.size() < 2:
		return 0
	var tags := _mission_tags(location, signal_data)
	var covered_by: Dictionary = {}
	for tag in tags:
		for member_id in member_ids:
			var member: Dictionary = members.get(str(member_id), {})
			if (member.get("strengths", []) as Array).has(tag):
				if not covered_by.has(tag):
					covered_by[tag] = []
				(covered_by[tag] as Array).append(str(member_id))
	var covered_count := 0
	var distinct_members := {}
	for tag in tags:
		if not covered_by.has(tag):
			continue
		covered_count += 1
		for member_id in covered_by[tag]:
			distinct_members[str(member_id)] = true
	if covered_count >= min(2, tags.size()) and distinct_members.size() >= 2:
		return 8
	return 0

func _team_chemistry_score(member_ids: Array[String], location: Dictionary, signal_data: Dictionary) -> int:
	var score := 0
	for chemistry in _active_team_chemistries(member_ids, location, signal_data):
		score += int((chemistry as Dictionary).get("score", 0))
	return score

func _team_bond_score(member_ids: Array[String]) -> int:
	if member_ids.size() < 2:
		return 0
	var bond := int(team_bonds.get(_team_pair_key(member_ids), 0))
	return bond * 3

func _team_pair_key(member_ids: Array[String]) -> String:
	if member_ids.size() < 2:
		return ""
	var a := str(member_ids[0])
	var b := str(member_ids[1])
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]

func _apply_team_bond_result(member_ids: Array[String], quality: String) -> Dictionary:
	if member_ids.size() < 2:
		return {}
	var key := _team_pair_key(member_ids)
	if key == "":
		return {}
	var old_bond := int(team_bonds.get(key, 0))
	var delta := 0
	match quality:
		"success":
			delta = 1
		"failure":
			delta = -1
		_:
			delta = 0
	if delta == 0:
		return {}
	var new_bond: int = clamp(old_bond + delta, -2, 3)
	team_bonds[key] = new_bond
	var names: String = _team_pair_names(member_ids)
	var line := "搭档记忆：%s 默契提升到 %+d，后续同队准备 %+d。" % [names, new_bond, new_bond * 3]
	if delta < 0:
		line = "搭档记忆：%s 留下裂痕 %+d，后续同队准备 %+d。" % [names, new_bond, new_bond * 3]
	return {
		"pair": key,
		"old": old_bond,
		"new": new_bond,
		"delta": delta,
		"line": line
	}

func _team_pair_names(member_ids: Array[String]) -> String:
	var names: Array[String] = []
	for member_id in member_ids.slice(0, min(2, member_ids.size())):
		var member: Dictionary = members.get(str(member_id), {})
		names.append(str(member.get("name", member_id)))
	return " / ".join(names)

func _apply_team_chemistry_stress(member_ids: Array[String], location: Dictionary, signal_data: Dictionary) -> void:
	for chemistry in _active_team_chemistries(member_ids, location, signal_data):
		var data := chemistry as Dictionary
		var stress_delta := int(data.get("stress", 0))
		if stress_delta == 0:
			continue
		var pair: Array = data.get("pair", [])
		for member_id in pair:
			if member_ids.has(str(member_id)):
				_adjust_member_stress(str(member_id), stress_delta)

func _active_team_chemistries(member_ids: Array[String], location: Dictionary, signal_data: Dictionary) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	if member_ids.size() < 2:
		return active
	var tags := _mission_tags(location, signal_data)
	for pair_key in TEAM_CHEMISTRY_DEFS.keys():
		var pair := str(pair_key).split("|")
		if pair.size() != 2:
			continue
		if not member_ids.has(str(pair[0])) or not member_ids.has(str(pair[1])):
			continue
		var chemistry: Dictionary = (TEAM_CHEMISTRY_DEFS[pair_key] as Dictionary).duplicate(true)
		if not _chemistry_matches_tags(chemistry, tags):
			continue
		chemistry["pair"] = [str(pair[0]), str(pair[1])]
		active.append(chemistry)
	return active

func _chemistry_matches_tags(chemistry: Dictionary, tags: Array[String]) -> bool:
	var rule_tags: Array = chemistry.get("tags", [])
	if rule_tags.is_empty():
		return true
	for tag in rule_tags:
		if tags.has(str(tag)):
			return true
	return false

func _item_bonus(item_id: String, location: Dictionary, signal_data: Dictionary) -> int:
	var item: Dictionary = items.get(item_id, {})
	var tags := _mission_tags(location, signal_data)
	var bonus := 0
	for tag in tags:
		if (item.get("tags", []) as Array).has(tag):
			bonus += int(item.get("bonus", 0))
			break
	return bonus

func _mission_tags(location: Dictionary, signal_data: Dictionary = {}) -> Array[String]:
	var tags: Array[String] = []
	for source in [location.get("tags", []), signal_data.get("need_tags", []), location.get("mission_tags", [])]:
		for tag in source:
			var tag_id := str(tag)
			if tag_id == "" or tags.has(tag_id):
				continue
			tags.append(tag_id)
	return tags

func _mark_member_after_dispatch(member_id: String) -> void:
	if not members.has(member_id):
		return
	members[member_id]["dispatch_count"] = int(members[member_id].get("dispatch_count", 0)) + 1
	_adjust_member_stress(member_id, 8)
	if member_id == "a_qing" and int(members[member_id].get("dispatch_count", 0)) > 1:
		_adjust_member_stress(member_id, 8)
	if str(members[member_id].get("status", "")) == "normal":
		members[member_id]["status"] = "tired"

func _injure_random_dispatched(dispatched_member_ids: Array[String] = []) -> void:
	var candidates: Array = dispatched_member_ids.duplicate()
	if candidates.is_empty():
		candidates = members.keys()
	for member_id in candidates:
		var id := str(member_id)
		if members.has(id) and str(members[id].get("status", "")) == "tired":
			members[id]["status"] = "injured"
			_adjust_member_stress(id, 10)
			return

func _apply_signal_reward(signal_data: Dictionary, multiplier: float = 1.0, rescue_multiplier: float = 1.0) -> void:
	var reward: Dictionary = signal_data.get("reward", {})
	for key in reward.keys():
		var active_multiplier := multiplier * (rescue_multiplier if str(key) == "rescued" else 1.0)
		resources[str(key)] = int(resources.get(str(key), 0)) + _scaled_delta(int(reward[key]), active_multiplier)

func _apply_partial_reward(signal_data: Dictionary, multiplier: float = 1.0, rescue_multiplier: float = 1.0) -> void:
	var reward: Dictionary = signal_data.get("reward", {})
	for key in reward.keys():
		var active_multiplier := multiplier * (rescue_multiplier if str(key) == "rescued" else 1.0)
		resources[str(key)] = int(resources.get(str(key), 0)) + _scaled_delta(int(reward[key]), 0.5 * active_multiplier)

func _apply_signal_failure(signal_data: Dictionary) -> void:
	var failure: Dictionary = signal_data.get("failure", {})
	for key in failure.keys():
		resources[str(key)] = max(0, int(resources.get(str(key), 0)) + int(failure[key]))

func _apply_resource_delta(delta: Dictionary) -> void:
	for key in delta.keys():
		resources[str(key)] = max(0, int(resources.get(str(key), 0)) + int(delta[key]))

func _format_resource_delta(delta: Dictionary) -> String:
	if delta.is_empty():
		return "无变化"
	var parts: Array[String] = []
	for key in delta.keys():
		var value := int(delta[key])
		if value == 0:
			continue
		parts.append("%s%+d" % [_resource_short_name(str(key)), value])
	if parts.is_empty():
		return "无变化"
	return " ".join(parts)

func _scaled_delta(value: int, multiplier: float) -> int:
	if value == 0:
		return 0
	var scaled := int(round(float(value) * multiplier))
	if value > 0:
		return max(1, scaled)
	return min(-1, scaled)

func _resource_name(key: String) -> String:
	return {
		"power": "电力",
		"food": "食物",
		"medicine": "药品",
		"fuel": "燃料",
		"parts": "零件",
		"trust": "信任",
		"influence": "影响力",
		"threat": "暴露度",
		"rescued": "救回人数"
	}.get(key, key)

func _resource_short_name(key: String) -> String:
	return {
		"power": "电",
		"food": "食",
		"medicine": "药",
		"fuel": "油",
		"parts": "件",
		"trust": "信",
		"influence": "影",
		"threat": "暴",
		"rescued": "救"
	}.get(key, key)

func _status_label(status: String) -> String:
	return {
		"normal": "正常",
		"tired": "疲惫",
		"injured": "受伤",
		"missing": "失踪"
	}.get(status, status)

func _member_status_help(status: String) -> String:
	match status:
		"tired":
			return "疲惫：仍可派遣，但准备 -8；可通过轮休、医务角或部分夜间安排恢复。"
		"injured":
			return "受伤：不可正常恢复，需医务分诊或医务角处理。"
		_:
			return ""

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path, "Texture2D"):
		return load(path) as Texture2D
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		return null
	return ImageTexture.create_from_image(image)
