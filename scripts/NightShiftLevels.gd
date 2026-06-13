extends RefCounted

class_name NightShiftLevels

const LEVELS := [
	{
		"title": "第一夜：三盏灯",
		"briefing": "教学夜只守正门、左窗和发电机。活到天亮，Nora 会留下。",
		"story_intro": "白天，你把临时电接进旧体育馆。看台下面躲着二十七个人，所有人都盯着三处还亮着的地方：正门、左窗、发电机。Nora 没有进屋，她说如果你撑到天亮，她就信这里不是又一个会熄灭的地方。",
		"night_goal": "只守住正门、左窗、发电机。学会移动、修复和判断先后。",
		"story_start": [
			"第一夜开始。体育馆只剩三盏灯：门边、窗边、发电机。",
			"窗外的 Nora 没有求救，只隔着木板说：让我看看你们能不能撑住。"
		],
		"story_beats": [
			{"id": "first_hit", "at_ratio": 0.18, "text": "正门响第一下时，看台下有人咬住袖口，没有哭出声。"},
			{"id": "nora_window", "at_ratio": 0.50, "text": "左窗外有手电光晃了一下。Nora 还在外面，她没有走。"},
			{"id": "promise", "at_ratio": 0.78, "text": "天快亮前，Nora 敲了三下窗框：别开门，我自己找侧门。"}
		],
		"success_report": "天亮时，Nora 从器材间侧门进来，袖子被铁丝割开。她把一把弯钉子倒在值班桌上。\n她没有说谢谢，只说：下一夜，窗归我看。",
		"failure_report": "灯灭时，Nora 还在窗外。她最后一次敲窗，不是求你开门，是提醒里面的人别出声。",
		"duration": 90.0,
		"choices": [
			{"id": "start", "title": "开始第一夜", "body": "不做升级，直接上夜班。"}
		]
	},
	{
		"title": "第二夜：右窗的人",
		"briefing": "右窗加入。Nora 会帮你盯最危险的窗。",
		"story_intro": "白天，Nora 帮你把左窗的血迹刮掉。她指向右侧更衣室：那里睡着孩子和老人，窗一响，他们就醒一次。你们守的不是窗，是窗后那些不敢呼吸的人。",
		"night_goal": "右窗加入压力。学会让 Nora 分担窗口危机。",
		"story_start": [
			"第二夜开始。Nora 把袖口缠紧，站在右窗和人群之间。",
			"她说：如果我跑错了，你就喊我名字。"
		],
		"story_beats": [
			{"id": "right_window", "at_ratio": 0.18, "text": "右窗铁框轻响，Nora 先看了一眼睡着的孩子，才冲过去。"},
			{"id": "answer", "at_ratio": 0.50, "text": "撞击停顿的几秒里，孩子问她天亮后会不会有掌声。Nora 说会。"},
			{"id": "trust", "at_ratio": 0.78, "text": "左右两扇窗轮流发响，但人群没有再乱跑。他们开始相信值班台。"}
		],
		"success_report": "右窗守住了。早上，那个孩子把一枚哨子塞给 Nora，说下次窗响就先叫她。\nNora 把哨子挂在脖子上，笑得很轻。",
		"failure_report": "右窗后面的铺位被冷风掀开。Nora 一直喊名字，直到没有人再回应。",
		"duration": 115.0,
		"choices": [
			{"id": "door_reinforce", "title": "加固正门", "body": "正门更耐撞，破防前多撑一会儿。"},
			{"id": "window_brace", "title": "补窗板", "body": "左右窗更结实，Nora 修窗更快。"},
			{"id": "battery_buffer", "title": "接备用电瓶", "body": "发电机更不容易彻底断电。"}
		]
	},
	{
		"title": "第三夜：接住声音",
		"briefing": "电台加入。接通电台后，Elias 会找到体育馆。",
		"story_intro": "白天，电台第一次吐出完整名字：Elias Reed。他说自己带着工具，能修天线，能修发电机，只要你们给他一个亮着的坐标。另一个更远的声音只留下呼号：Victor Hale。",
		"night_goal": "电台加入。门窗和电力会逼你在接听与抢修之间取舍。",
		"story_start": [
			"第三夜开始。电台波形像一根快断的线。",
			"Elias 在杂音里重复：别关灯，我能顺着亮点过去。"
		],
		"story_beats": [
			{"id": "radio", "at_ratio": 0.18, "text": "电台亮起时，Nora 没有回头。她只说：接住他，我看窗。"},
			{"id": "victor", "at_ratio": 0.50, "text": "Victor 插进频道：我听见体育馆了。别问我在哪，先活到天亮。"},
			{"id": "elias_close", "at_ratio": 0.78, "text": "Elias 的呼吸声越来越近。他说如果敲门声是三短一长，那就是我。"}
		],
		"success_report": "Elias 在天亮前敲响侧门，怀里抱着一捆湿透的线缆。\nVictor 没有现身，只在频道另一端说：好，地图上又多了一盏灯。",
		"failure_report": "电台最后一次亮起时，Elias 还在报坐标。你没能回过去，频道里只剩 Victor 一遍遍念旧体育馆的名字。",
		"duration": 125.0,
		"choices": [
			{"id": "generator_tune", "title": "检修发电机", "body": "发电机掉电更慢，停电后更容易拉回。"},
			{"id": "radio_booster", "title": "架高天线", "body": "电台呼叫持续更久，也更容易接通。"},
			{"id": "workbench", "title": "整理工具台", "body": "值班员修理和操作速度小幅提高。"}
		]
	},
	{
		"title": "第四夜：屋顶的线",
		"briefing": "天线加入。信号不能断，否则电台会变成杂音。",
		"story_intro": "Elias 白天爬上看台顶，手指被铁丝勒出血。Victor 的声音第一次清楚起来：我看见你们的灯了。那句话让全馆的人安静了很久。",
		"night_goal": "天线加入。电台呼叫前，先别让信号断掉。",
		"story_start": [
			"第四夜开始。屋顶的风把天线吹得像一根快断的弦。",
			"Elias 盯着信号条说：只要它还跳，外面就知道我们活着。"
		],
		"story_beats": [
			{"id": "antenna", "at_ratio": 0.18, "text": "天线一沉，Victor 的声音立刻变远：体育馆，别掉下去。"},
			{"id": "route", "at_ratio": 0.50, "text": "Victor 报出一串街名。他说那不是路，是人们还能互相找到的办法。"},
			{"id": "island", "at_ratio": 0.78, "text": "Elias 把耳机压在耳侧，轻声说：我听见他了。我们不是孤岛。"}
		],
		"success_report": "屋顶天线撑住了。Victor 把第一条安全路线交给旧体育馆，陌生人开始按你们的灯光行走。",
		"failure_report": "天线断线后，体育馆像从地图上被擦掉。Elias 一直调频，手指停不下来。",
		"duration": 135.0,
		"choices": [
			{"id": "antenna_anchor", "title": "固定天线", "body": "天线掉线更慢，呼叫更不容易丢。"},
			{"id": "storage", "title": "整理储物间", "body": "木板封堵更久，扔木板冷却更短。"},
			{"id": "medbay", "title": "设医务角", "body": "同伴夜里更稳，自动处理速度提高。"}
		]
	},
	{
		"title": "第五夜：器材通道",
		"briefing": "后门加入。它离发电机最近，失守会拖垮电力。",
		"story_intro": "Victor 说补给会从器材通道那边来。傍晚你们发现后门上有新抓痕，像有人也听懂了这条路。Nora 没说话，只把孩子的铺位往里挪。",
		"night_goal": "后门加入防线。它靠近电力区，不能放任。",
		"story_start": [
			"第五夜开始。后门外传来铁链拖地声，发电机就在它身后。",
			"Victor 低声提醒：那条通道以前能救人，今晚也可能害死你们。"
		],
		"story_beats": [
			{"id": "back_door", "at_ratio": 0.18, "text": "后门第一次被顶响。Elias 抬头看发电机，像听见自己的心跳。"},
			{"id": "cache", "at_ratio": 0.50, "text": "Victor 报出绿色物资箱的位置：我送不到门口，只能把路留给你们。"},
			{"id": "cold", "at_ratio": 0.78, "text": "通道里卷进冷风。Nora 把最近的孩子抱远，说：别看那边。"}
		],
		"success_report": "器材通道守住了。白天，你们在 Victor 标出的地方找到药、线缆和一张纸条：给后来还亮着的人。",
		"failure_report": "后门失守后，发电机区先暗下去。Victor 在远处一遍遍问有没有人撤出来，没有人敢回答。",
		"duration": 145.0,
		"choices": [
			{"id": "back_door_bar", "title": "横闩后门", "body": "后门更耐撞，第一次冲击来得更慢。"},
			{"id": "generator_cage", "title": "围住发电机", "body": "后门告急时发电机掉压少一点。"},
			{"id": "runner_path", "title": "清出通道", "body": "值班员移动速度提高。"}
		]
	},
	{
		"title": "第六夜：医务角的灯",
		"briefing": "医务角加入。处理它不会立刻失败，但会抢走关键时间。",
		"story_intro": "Nora 带回一名发烧的女孩，给她讲旧体育馆以前办过比赛。女孩问天亮后会不会有掌声。Nora 说会，但她看向你的时候没有笑。",
		"night_goal": "医务角会告急。门窗不会等你，伤员也不会。",
		"story_start": [
			"第六夜开始。医务角的小灯亮着，Nora 的影子挡在女孩和冷风之间。",
			"她对你说：门窗我会盯，但那盏灯也不能灭。"
		],
		"story_beats": [
			{"id": "medbay", "at_ratio": 0.18, "text": "医务角传来压住的咳嗽声。Nora 的脚步停了一下，又冲向窗边。"},
			{"id": "song", "at_ratio": 0.50, "text": "女孩醒了，哼着听不清的曲子。撞击停顿的一秒，体育馆像真的安静过。"},
			{"id": "promise", "at_ratio": 0.78, "text": "Nora 把药箱推到你看得见的位置：如果我跑开，你替我看她一眼。"}
		],
		"success_report": "医务角的灯没灭。天亮时，女孩问 Nora 有没有听见掌声。\nNora 说听见了，其实那只是大家终于敢呼吸。",
		"failure_report": "医务角的灯暗下去后，Nora 再也没抬头看窗。门还在响，但体育馆里少了一点声音。",
		"duration": 150.0,
		"choices": [
			{"id": "medbay_lamp", "title": "接医务灯", "body": "医务角告急更少，同伴处理更稳。"},
			{"id": "nora_kit", "title": "整理药箱", "body": "Nora 修窗和处理医务角更快。"},
			{"id": "quiet_hours", "title": "安排静默", "body": "前半夜随机干扰减少。"}
		]
	},
	{
		"title": "第七夜：最后一块板",
		"briefing": "储物间加入。木板不够，扔木板要算准。",
		"story_intro": "储物间只剩半堆木板。Victor 的物资箱里有钉子、胶带和一张清单，最后一行写着：别把最后一块板留给自己。",
		"night_goal": "储物间会告急。提前处理能保住应急封堵。",
		"story_start": [
			"第七夜开始。储物间的木板少得能数清，每一块都像一段时间。",
			"Victor 在频道里说：我也快数到最后一块了。"
		],
		"story_beats": [
			{"id": "shortage", "at_ratio": 0.18, "text": "储物间传来倒塌声。Nora 没骂人，只把短板一块块挑出来。"},
			{"id": "photo", "at_ratio": 0.50, "text": "物资箱夹层里有旧照片，背面写着：给下一处还亮着的地方。"},
			{"id": "last_board", "at_ratio": 0.78, "text": "最后一阵撞击前，Elias 递给你一块板：这不是木头，是一分钟。"}
		],
		"success_report": "木板不够用，但你们把每一块都用在该用的地方。\n白天，Victor 听见你们报平安，只说：好，我那边也再撑一夜。",
		"failure_report": "储物间空了，门窗还在响。Victor 的清单被风卷起，像一份没来得及完成的遗嘱。",
		"duration": 155.0,
		"choices": [
			{"id": "salvage_planks", "title": "拆看台木板", "body": "扔木板冷却恢复，储物间更稳定。"},
			{"id": "double_brace", "title": "双层窗撑", "body": "左右窗被临时封住时撑得更久。"},
			{"id": "victor_cache", "title": "标记物资箱", "body": "储物间告急后恢复更快。"}
		]
	},
	{
		"title": "第八夜：灯越亮，影越多",
		"briefing": "不加新地点。所有系统会交替施压，后段不会再空。",
		"story_intro": "白天又来了两队人，都是跟着旧体育馆的灯走来的。灯救了他们，也把更远处的黑影引向看台外。Victor 沉默了很久，说：今晚你们会被看见。",
		"night_goal": "守住已开放的所有地点。压力会分波次压到黎明前。",
		"story_start": [
			"第八夜开始。看台下第一次坐满了人，连呼吸声都像潮水。",
			"Victor 说：别让他们听见你们害怕。"
		],
		"story_beats": [
			{"id": "crowd", "at_ratio": 0.18, "text": "正门和窗同时发响。有人想帮忙，Nora 把人按回去：让值班员跑。"},
			{"id": "home", "at_ratio": 0.50, "text": "一个老人把自己的毯子铺在医务角旁边，说这里终于像个能过夜的地方。"},
			{"id": "stand", "at_ratio": 0.78, "text": "Elias 把电台音量推高，让所有人听见外面还有回应。"}
		],
		"success_report": "第八夜以后，旧体育馆不再只是避难点。\n人们开始把这里叫作灯塔，Victor 在频道另一端说：那就别让灯灭。",
		"failure_report": "灯光引来了人，也引来了更重的黑暗。体育馆没能把他们都留下，频道里第一次出现长久空白。",
		"duration": 160.0,
		"choices": [
			{"id": "floodlights", "title": "接应急灯", "body": "停电时仍有弱光，门窗压力上升少一点。"},
			{"id": "second_plank", "title": "预切木板", "body": "扔木板冷却进一步缩短。"},
			{"id": "command_routine", "title": "分工口令", "body": "Elias 可在空档帮发电机，Nora 继续盯窗。"}
		]
	},
	{
		"title": "第九夜：有人在追信号",
		"briefing": "电和信号会互相拖累。Victor 的位置开始暴露。",
		"story_intro": "Elias 发现有人在反向追踪你们的频率。Victor 说没关系，他把自己的电台开得更亮一点，声音却比前几夜轻。",
		"night_goal": "发电机和天线要一起保住。停电会拖垮信号。",
		"story_start": [
			"第九夜开始。电压和信号绑在一起，任何一次停电都会把体育馆拖进沉默。",
			"Victor 没有报路线，只报一句：如果我断线，继续向东听。"
		],
		"story_beats": [
			{"id": "signal", "at_ratio": 0.18, "text": "天线信号突然下坠。Elias 听见另一组频段扫过来，脸色变得很白。"},
			{"id": "victor_exposed", "at_ratio": 0.50, "text": "Victor 承认他的位置暴露了。他笑了一下：老电台本来就该替新电台挨噪声。"},
			{"id": "names", "at_ratio": 0.78, "text": "Nora 让所有人记住 Victor 的呼号：别等失去以后才学会叫一个人的名字。"}
		],
		"success_report": "电和信号没有一起断掉。Victor 的频道越来越远，但他仍把最后几条坐标交给 Elias。\n他说：明晚你们只管亮着。",
		"failure_report": "停电吞掉了信号，也吞掉了 Victor 留下的坐标。Elias 摘下耳机时，手还停在调频旋钮上。",
		"duration": 165.0,
		"choices": [
			{"id": "signal_battery", "title": "信号电瓶", "body": "停电时天线掉线速度降低。"},
			{"id": "cable_route", "title": "重走线缆", "body": "天线和电台修复更快。"},
			{"id": "elias_tools", "title": "给 Elias 工具", "body": "Elias 自动处理电台/天线更快。"}
		]
	},
	{
		"title": "第十夜：名单",
		"briefing": "最终夜。所有地点都会被压到黎明前，Victor 会用自己的电台引开追踪。",
		"story_intro": "最后一夜前，Victor 把自己的频道接到最大功率。他没有说计划，只让 Elias 抄下名单：Nora、Elias、旧体育馆、所有还在灯下的人。",
		"night_goal": "守住门、窗、后门、电力、天线和电台，撑到天亮。",
		"story_start": [
			"第十夜开始。体育馆外的声音从四面压上来，像整座城市都在撞门。",
			"Victor 的频道亮得刺耳。他说：今晚我在外面替你们叫名字。"
		],
		"story_beats": [
			{"id": "broadcast", "at_ratio": 0.18, "text": "Victor 开始一遍遍播报体育馆坐标和名单。他把自己的台开成更亮的靶子。"},
			{"id": "sacrifice", "at_ratio": 0.50, "text": "追踪信号转向 Victor。Elias 听懂了，声音发抖：他在把它们从体育馆引走。"},
			{"id": "last_call", "at_ratio": 0.78, "text": "Victor 最后一次呼叫：Nora 守窗，Elias 守频，你守灯。然后他的频道只剩黎明前的底噪。"}
		],
		"success_report": "天亮了。体育馆还在，电台还亮着。\nVictor Hale 的频道没有再回来，但他留下的坐标被后来的人接住。Nora 站在窗边，Elias 守着频率，你们把他的名字写进值班记录第一行。",
		"failure_report": "最终夜没能撑到天亮。Victor 把追踪信号引走时，体育馆的灯先一步熄了。频道里只剩他一遍遍叫你们的名字。",
		"duration": 180.0,
		"choices": [
			{"id": "final_barricade", "title": "最后路障", "body": "所有门窗初始更稳。"},
			{"id": "all_hands", "title": "全员分工", "body": "Nora 和 Elias 自动处理速度提高。"},
			{"id": "radio_beacon", "title": "开信标", "body": "最终夜电台呼叫窗口更长。"}
		]
	}
]


static func get_level(index: int) -> Dictionary:
	return LEVELS[clamp(index, 0, LEVELS.size() - 1)] as Dictionary

static func count() -> int:
	return LEVELS.size()
