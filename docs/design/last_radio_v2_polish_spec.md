# 《最后电台》v2 Polish Spec — 故事 / NPC / 视觉 / 章节延展

> **Status**: 草稿 v0.1 — 2026-06-22（第一次成型，4 项决策已与 solo dev 对齐）
> **范围**: v0.5（M1–M10 已发）→ v0.6 polish
> **本 spec 用途**: 当前 polish 阶段的 single source of truth。所有后续 PR 都对照本 doc，
> 跑偏 = 本 doc 没写到的 = 先回到本 doc 讨论加条目，再动代码。

## 关联文档

> 本 spec **不重复**已沉淀的设计文档，只补充 polish 阶段的"具体怎么落"。先读它们：

- [`../LAST_RADIO_V2_DESIGN.md`](../LAST_RADIO_V2_DESIGN.md) — 14 天 demo 原案，6 阶段日循环总览
- [`game_design_spec_zh.md`](game_design_spec_zh.md) — 正式版策划 V1，世界规则、4 阶段循环、4 类白天卡牌
- [`chapter_01_night_plan_zh.md`](chapter_01_night_plan_zh.md) — 第一章 10 夜节奏表（已有完整事件序列）
- [`../radio_design.md`](../radio_design.md) — 电台 dial-and-hold mini-game 机制
- [`../release_roadmap.md`](../release_roadmap.md) — M1–M10 已完成状态，M11 起从这里切

---

## 0. TL;DR

本轮 polish 解决 4 条玩家反馈：

| # | 问题 | 严重度 | 状态 | 落点 |
|---|------|------|------|------|
| ① | 白天选项顺序错位（"架高天线"出现在天线解锁前） | P1 | ✅ `c6e44d6` | day_cards 加 `requires_unlocked` 字段 |
| ② | NPC 行为反复横跳 / 视觉上跟僵尸分不清 | P0 | 🔜 M11–M12 | 接 NPC AI 进主循环 + 视觉区分 |
| ③ | 玩家分不清"我在修"和"NPC 在修" | P1 | 🔜 M12 | UI 状态条 |
| ④ | 故事线失踪（没有世界观 / 没有"为什么守体育馆"） | P0 | 🔜 M13–M14 | 4 个 hook 点 + day card body 独白化 |

> **本 spec 一旦跑偏，先回这里加条目再动代码**。决策记录见 §10。

---

## 1. 当前状态盘点（v0.5 baseline）

### 1.1 已实现（v0.5）
- 21 套件 headless 测试全绿，约 685 断言
- M1–M10 完成：i18n / 设置 / 教程 / 多存档 / 美术 BGM / Steamworks stub / 法务 / 图标 / 导出流水线 / 商店素材
- 实时夜战（NightShiftGame）：player_token 在 hotspot 间奔走、修门窗/发电机/天线
- zombie 视觉：已有 `zombie_hands_reach` / `zombie_shadow_{single,crowd,pair}` / `zombie_outside_{window,door}_{breach,approach}` 等 sprite
- 电台 dial-and-hold mini-game（night 3 起）
- 白天 3 张日卡选择 + 4 类（加固 / 搜救 / 搜刮 / 广播）

### 1.2 与原案 (`LAST_RADIO_V2_DESIGN.md`) 的偏差

| 原案 6 阶段日循环 | 当前实现 | 状态 |
|---|---|---|
| 晨间状态 | 简化为 night_report | ⚠️ 待强化（M13） |
| 调频监听 | 仅 night 3+ radio event 触发 | ⚠️ 待强化（M13 tutorial step 4） |
| 情报整理 | **砍掉** | 🔴 长期 backlog |
| 排班与派遣 | **砍掉**（改为"玩家自己跑"） | 🔴 长期 backlog |
| 广播决定 | **砍掉**（仅保留 effect 字段，无独立决策面板） | 🔴 长期 backlog |
| 夜间结算 | 实现（实时夜战） | ✅ |

### 1.3 与原案 (`game_design_spec_zh.md` §0) 的对齐

- ✅ 一夜叙事 22:00–06:00，玩法时间压缩（night 1=60s, night 2=120s, night 3+=180s）
- ✅ 主角唯一可控单位
- ✅ NPC 是辅助不是直接控制（**但当前实现 NPC 完全没行为，是 dead code** — 见 §4）
- ✅ 白天有代价，不只是数值升级
- ⚠️ 后期难度：本轮不重做事件密度（属于 `chapter_01_night_plan_zh.md` 范畴）

---

## 2. 世界观 Bible（最终版）

> 本节是 polish 阶段所有叙事文本的基准。所有 day card body 独白 / cover 独白 / night report 日志 / i18n key 都要从这一节的世界观出发。

### 2.1 时空与基调

- **时间**：现代，末日爆发已 1 年。具体日期不重要，城市已被废弃。
- **地点**：城市郊区旧体育馆（室内篮球场 + 旁边储物间 / 医务角 / 仓库 / 屋顶天线）
- **基调**：**压抑但不绝望**。城市空了，但电台还活着；体育馆不是堡垒，是**临时据点**——明天可能守不住，但今晚还在。

### 2.2 主角

- **身份**：普通人。前便利店夜班 / 居民 / 工人——具体职业不锁定，留给玩家想象。
- **背景**：城市沦陷那天早上刚下夜班，回家路上发现城市没了声音。在废墟里躲了三个月，靠罐头和雨水撑过来。
- **第 0 夜前**：在体育馆地下室翻到一台老式短波电台（HAM radio），调到自动扫描模式。凌晨两点，电台收到一段破碎的人声——**Victor 在城西某楼顶，已经独自坚持了半年**。
- **性格**：不英勇，不善言辞。但有责任感——Victor 在广播里循环一句话："如果你还活着，请回应。" 主角回应了，于是有了体育馆守夜这件事。

### 2.3 Victor

- **位置**：城西某楼顶（具体位置留悬念，第 9 夜失联后玩家可能要去找）
- **状态**：独自坚持了半年。**第 9 夜失联**——电台收到噪音，没有 Victor 的声音。
- **角色**：NPC 锚。所有后续加入的人都从他的频率找来。
- **悬念**：
  - Victor 是死了，还是只是电台坏了？
  - 主角要不要在第 10 夜结束后出去找？（city map 钩子）

### 2.4 Nora（前护士）

- **来源**：第 2 夜通过 Victor 的频率找到体育馆。前学校图书馆避难，听广播循着方位找来。
- **带过来**：medicine +1
- **性格**：安静，话不多，做事稳。
- **机制定位**：默认站**右半场**，只动 `left_window` / `right_window`。

### 2.5 Elias（无线电爱好者）

- **来源**：第 3 夜。从 Victor 那里听来方位，调频能力强。
- **性格**：技术宅，话多但不讨人厌。
- **机制定位**：默认站**左半场 / 后侧**，管 `antenna` + `radio`。

### 2.6 Lily（小孩 / 高中生）

- **来源**：第 5 夜。可能独自找过来，也可能是 Nora 从外面带回来。
- **带过来**：trust +1
- **机制定位**：不参与 hotfix（太弱 / 太危险），但**在场信任加成**：所有 day card 的 trust 收益 +1。
- **弱点**：修东西慢（hotfixes 速率 -30%），如果她死了 trust 大跌。

### 2.7 Tom（前老兵）

- **来源**：第 6 夜。
- **机制定位**：会用枪，攻击力增加（可考虑 `damage_per_assault_kill` 字段）。木板消耗 -1（更省料）。
- **命运**：**第 8 夜牺牲**——留下来引开 zombie 群掩护玩家。

### 2.8 Daniel（普通人）

- **来源**：第 5 夜加入。
- **命运**：**第 7 夜离开**——听到家人方向有声音，独自走了。伴随 day card "让他走 / 让他留"分支选择。
- **影响**：少一个辅助，但触发"我们已经失去过一个人"的叙事钩子。

### 2.9 丧尸设定

- **来源**：不明感染，城市空了。具体病毒/辐射/诅咒不锁定。
- **行为**：受声音、灯光、热源和**广播**吸引。白天分散，夜晚聚拢。
- **视觉现状**：见 §5。

### 2.10 体育馆设定

- **设施**：正门 / 后门 / 左窗 / 右窗 / 发电机 / 电台 / 天线（night 4+）/ 医务角（night 7+）/ 仓库（night 8+）
- **容纳人数**：理想 4–6 人，超出会拥挤（影响 hotfix 速率）
- **资源**：木板 / 零件 / 电池 / 药品 / 信任 / 暴露度

---

## 3. 10 夜章节表（草案 v0.1）

> 与 `chapter_01_night_plan_zh.md` §2 "总体曲线" 对齐。本表是 **新增** 的"角色来去"维度，原表的事件序列不动。

| 夜 | 主题（沿用 chapter_01_night_plan） | 来的人 | 离开/牺牲 | 关键解锁（沿用） |
|---|---|---|---|---|
| 1 | 三盏灯 | — | — | `right_window`, `victor` ally 标记 |
| 2 | 右窗的人 | **Nora** | — | `radio` |
| 3 | 接住声音 | **Elias** | — | `antenna` |
| 4 | 屋顶的线 | — | — | — |
| 5 | 白天不安全 | **Lily**, **Daniel** | — | 暴露度系统正式显示 |
| 6 | 器材通道 | **Tom** | — | `back_door` |
| 7 | 医务角的灯 | — | **Daniel** 离开（"让他走 / 让他留"day card 分支） | `storage` |
| 8 | 最后一块板 | — | **Tom** 牺牲（引开 zombie 群掩护玩家） | — |
| 9 | 有人在追信号 | — | **Victor 失联**（电台只剩噪音） | — |
| 10 | 名单 | — | — | 终局（不是 happy ending，是"又活过一晚"） |

### 3.1 与现有 chapter_01_nights.json 的对齐

- night 1 success_unlocks 当前 `["nora", "right_window"]` —— 保留。Nora 是 night 2 早上到（剧情），right_window 是 night 2 解锁的 hotspot。
- night 2 success_unlocks 当前 `["radio"]` —— 保留。
- night 3 success_unlocks 当前 `["elias", "antenna"]` —— 保留。
- **需要新增**（在 chapter_01_nights.json 的 success_unlocks 之外）：
  - night 5：`["lily", "daniel"]`
  - night 6：`["tom", "back_door"]`
  - night 7：day card 分支 "let_daniel_go" / "let_daniel_stay"
  - night 8：tom 死亡事件（NPC 列表里移除 tom，触发 trust -1）
  - night 9：victor 失联事件（radio_signal_quality 字段衰减到 0）

### 3.2 章节延展（不在本轮 polish 范围）

- 第二章设计：`docs/design/chapter_XX_*.md` 待写，触发条件 = 第一章通关。
- 长期 backlog：6 阶段日循环的"情报整理 / 排班 / 广播"模块（见 §1.2）。

---

## 4. NPC 系统（代码 + 视觉 + UI）

> 这是 **本轮 polish 最核心的工程**。当前 `NightShiftActors.gd` 是 dead code——定义了 `window_needing_help` / `elias_needing_help` 静态函数，但没有任何调用，玩家看到的"反复横跳"实际是 zombie swarm 行为。

### 4.1 AI 哲学（核心原则，不可妥协）

> **不死板但不强 AI，只是起个救急**。

- **玩家是主角**，NPC 是救火队员
- NPC 主动行为只在两种"紧急"状态下介入：`breach_timer >= 0`（已经在破）或 `value < 0.35 * max_value`（濒危）
- 其它时间 NPC 站着（idle 微动画），让玩家自己干
- 如果玩家主动来同一个 hotspot，**NPC 让位**（不抢玩家的活）

### 4.2 行为规则（4 条具体规则）

1. **触发条件**：仅当 `(breach_timer >= 0)` 或 `(value < 0.35 * max_value)` 时，NPC 重评目标
2. **软锁定**：选目标后 `_npc_commit_timer = 2.0s` 倒计时。期间不重评。倒计时归零或目标已修好 90% 才重新决策
3. **不抢玩家**：每帧检查 `player_target_id == npc_target`，相等则 NPC 让位回 idle
4. **移动 cooldown**：从当前位置到目标 hotspot 1.5s 才能到位，期间不能换目标（避免瞬移式抖动）

### 4.3 视觉资产需求

| 角色 | sprite 需求 | 调色 |
|---|---|---|
| Nora | idle 2 帧 + walk 4 方向 × 4 帧 | 暖色（白大褂灰 / 暗黄头巾） |
| Elias | idle 2 帧 + walk 4 方向 × 4 帧 | 冷色（深蓝夹克 / 耳机） |
| Lily | idle 2 帧（无需 walk，固定位置） | 浅色（破旧卫衣） |
| Tom | idle 2 帧 + walk 4 方向 × 4 帧 | 暗色（迷彩 / 老兵夹克） |

文件命名：`assets/final/night_shift/npc_{nora,elias,lily,tom}.png` + `.import`

### 4.4 UI 状态条

- 顶部新增 NPC 状态条（radio_panel 上方或紧邻）
- 每行格式：`{头像} {名字} → {hotspot_label} {状态文字}`
- 状态文字：`救急中` / `赶路中` / `待命` / `信任告急`（信任<2 时）
- 状态条在 ally 未加入时隐藏

### 4.5 数据 schema（NightShiftGame 状态扩展）

```gdscript
# 加入到现有 allies dict 旁边
var npc_state: Dictionary = {}  # npc_id -> {pos, target, commit_timer, walk_timer}

# 示例：night 2 Nora 加入后
npc_state["nora"] = {
    "pos": Vector2(800, 360),       # 默认右半场
    "target": "",                    # 当前 hotspot_id，空 = 待命
    "commit_timer": 0.0,            # 软锁定倒计时
    "walk_timer": 0.0,              # 移动 cooldown
    "speed": 180.0,                  # 比 player 略慢（player=220）
}
```

### 4.6 与 `NightShiftActors.gd` (dead code) 的对接

- 当前 `window_needing_help` / `elias_needing_help` 静态函数 → 重构为 instance method `NightShiftActors.decide_target(npc_id, hotspots, ...)` 返回 `String`（hotspot_id 或 ""）
- 新增 `_tick_npcs(delta)` 调用时机：`NightShiftGame._update_night` 里，在 `_update_player_movement` 之后
- 重评周期：每 0.2s 一次（不是每帧），避免抖动

### 4.7 测试用例（新增）

`tools/npc_ai_test.gd`：覆盖 4 条规则的边界条件
- breach_timer=0.5 时 NPC 应该介入（即使 value 没到 35%）
- 玩家走到 NPC 目标时 NPC 应该让位
- 软锁定 2s 期间 NPC 不重评（即使新 hotspot 濒危）
- 移动 cooldown 1.5s 期间 NPC 不瞬移

---

## 5. Zombie 视觉强化

### 5.1 现状盘点

已有 sprite（`assets/final/night_shift/`）：

| sprite | 用途 |
|---|---|
| `zombie_hands_reach.png` | 手抓门/窗的特写 |
| `zombie_shadow_single.png` | 单个 zombie 影子（assault 预警） |
| `zombie_shadow_pair.png` | 两个 zombie 影子 |
| `zombie_shadow_crowd.png` | 群体 zombie 影子 |
| `zombie_outside_window_breach.png` | 窗外 zombie 破窗 |
| `zombie_outside_window_approach.png` | 窗外 zombie 靠近 |
| `zombie_outside_door_breach.png` | 门外 zombie 破门 |
| `zombie_outside_door_approach.png` | 门外 zombie 靠近 |

> 现有 sprite 已经覆盖**所有 assault 状态**。本轮不增加新 sprite，只做**区分强化**。

### 5.2 强化方向

1. **tint 处理**：在 `_redraw_enemy_visuals` 里给 zombie sprite 加 `modulate = Color(0.6, 0.8, 0.6, 1.0)`（偏绿/苍白）。让玩家一眼看出"不是人"。
2. **jitter 动画**：zombie token 渲染时加 ±2 像素随机偏移（每帧重新随机），营造"踉跄"质感。
3. **绘制层级**：`enemy_layer` 改为比 `npc_layer` 更深的颜色/更低的亮度。即使 NPC 和 zombie 在同一 hotspot 附近，玩家也能区分。

### 5.3 与 NPC 视觉的对比标准

| 特征 | zombie | NPC |
|---|---|---|
| 颜色 | 偏绿 / 苍白 | 正常肤色 + 角色调色（见 §4.3） |
| 运动 | 抖动 ±2 像素 | 平稳 walk 帧动画 |
| 行为 | 朝 hotspot 冲，到位后压 value | 救火（见 §4.2） |
| 视觉效果 | shadow / hands（已经有） | sprite + 头顶状态条（待加） |

---

## 6. 4 个 Hook 点具体落点

### 6.1 Cover 屏

**当前实现**：`scripts/BaseScreen.gd` 的 cover 屏直接显示题图 + "Begin Watch" 按钮。

**目标实现**：

1. 开屏黑屏淡入独白（3 秒）
   ```
   zh: "一年前的某个夜班，城市没了声音。\n三个月后，体育馆还在。我们还在。\n——Victor 在广播里循环的话"
   en: "A year ago, on a night shift, the city went silent.\nThree months on — the gym is still here. We still are.\n— Victor's loop broadcast"
   ```
2. 独白下方按钮：
   - `cover_btn_continue`（接旧存档，显示在已有存档时）
   - `cover_btn_new`（新存档）
3. 背景音乐：`music_cover`（已有）+ 旧电台电流噪声 loop（新增 BGM 待办）

**新增 i18n keys**：
- `cover_monologue_line1`
- `cover_monologue_line2`
- `cover_monologue_attribution`

### 6.2 Tutorial Step 4：调到 Victor 的频道

**当前实现**：tutorial 3 步（移动 → 修复 → 电台）。

**目标实现**：新增第 4 步"调到 Victor 的频道"

- 屏幕角落一个老式旋钮 UI（`Panel` + `HSlider` 模拟）
- 玩家手动把频率调到 7.085 MHz（HAM 短波常用）
- 调到对的频率后 Victor 的人声播 3 秒：「撑住。我看到你的信号了。」
- 频率调错时显示「频率噪音…」+ jitter 反馈
- 这一步只在 night 1 触发，跳过存档 `tutorial_done_step4: true`

**新增 i18n keys**：
- `tut_step4_title` = "调到 Victor 的频道" / "Tune to Victor's Frequency"
- `tut_step4_desc` = "把旋钮旋到 7.085 MHz。" / "Turn the dial to 7.085 MHz."
- `tut_step4_victor_line` = "撑住。我看到你的信号了。" / "Hold on. I see your signal."
- `tut_step4_static_noise` = "频率噪音…" / "Static noise..."

### 6.3 Day Card Body 独白化

**当前实现**：25 张 day card 的 `body` 字段是功能性短句（如 "门更耐撞。"）。

**目标实现**：每张卡的 body 改为"主角视角"独白（zh 先）。

**示例**：
| card id | 当前 body | 目标 body |
|---|---|---|
| `door_reinforce` | 门更耐撞。 | 我把板子钉在前门，想起 Victor 说过的话——"你守的每个门都是信号"。 |
| `signal_battery` | 停电时天线掉线速度降低。 | 停电时信号最弱。Elias 让我多备一组电池给天线。 |
| `nora_kit` | Nora 处理医务和窗户更快。 | Nora 打开药箱，手指在标签上滑过。她没说话，但她记得每一种药的用法。 |
| `victor_cache` | 按 Victor 的坐标找到零件，仓库压力降低。 | Victor 在广播里提过这个坐标。风很大，但我找到了。 |
| `keep_silent` | 暴露度降低，可能错过外部回应。 | 今晚不广播。听一会儿，让城市自己说话。 |

**详细 25 张重写**：见 §7 i18n 清单。

### 6.4 Night Report 日志化

**当前实现**：`report_section_status` 等模板化的字段统计。

**目标实现**：每夜 report 改为"日志片段"，3 行结构：

1. **当夜事件**（动态生成，基于 success_unlocks / breaches / day card effects）
   - 例：「右窗撑住了。黎明前补了一次压。」
2. **幸存者状态**（基于 allies dict 变化）
   - 例：「Lily 加入。Daniel 在门口犹豫。」 / 「Tom 没回来。」
3. **Victor 破碎广播**（按 night_index 抽预录片段，i18n key `report_victor_log_N`，N=1..10）
   - 例：night 1 = 「城西第七街楼顶。如果你们能听到，请回应。」
   - 例：night 9 = 「[杂音] ……Victor，你还在吗？ ……[杂音]」
   - 例：night 10 = 「不管今晚怎样，明早我都在这频段。」

**新增 i18n keys**：
- `report_victor_log_1` ... `report_victor_log_10`
- `report_survivors_joined` = "加入" / "Joined"
- `report_survivors_left` = "离开" / "Left"
- `report_survivors_lost` = "牺牲" / "Lost"

---

## 7. 新增 i18n Key 清单

### 7.1 Cover (3 keys)
- `cover_monologue_line1`
- `cover_monologue_line2`
- `cover_monologue_attribution`

### 7.2 Tutorial Step 4 (4 keys)
- `tut_step4_title`
- `tut_step4_desc`
- `tut_step4_victor_line`
- `tut_step4_static_noise`

### 7.3 Night Report (13 keys)
- `report_victor_log_1` ... `report_victor_log_10` (10 keys)
- `report_survivors_joined`
- `report_survivors_left`
- `report_survivors_lost`

### 7.4 Day Card Body 独白化
- 25 张卡的 `body` 字段全部重写（zh 先）
- en 翻译 backlog（不影响 M14 验收）

### 7.5 NPC UI (4 keys)
- `npc_status_emergency` = "救急中" / "Responding"
- `npc_status_walking` = "赶路中" / "En route"
- `npc_status_idle` = "待命" / "Standing by"
- `npc_status_low_trust` = "信任告急" / "Trust critical"

### 7.6 NPC Join 通知 (8 keys，按角色)
- `log_ally_join_nora`
- `log_ally_join_elias`
- `log_ally_join_lily`
- `log_ally_join_tom`
- `log_ally_left_daniel`
- `log_ally_lost_tom`
- `log_victor_lost`

### 7.7 Survivor 档案（M13-15 阶段用，先列）
- `survivor_nora_brief`
- `survivor_elias_brief`
- `survivor_lily_brief`
- `survivor_tom_brief`
- `survivor_daniel_brief`
- `survivor_victor_brief`

---

## 8. 验收标准

### 8.1 21 套件 headless 测试矩阵（必须全绿）

保留 v0.5 的 21 套件（见 `AGENTS.md` "Testing instructions" 段），新增：

| 新增套件 | 覆盖 |
|---|---|
| `tools/npc_ai_test.gd` | NPC 4 条行为规则 + 软锁定 + 不抢玩家 + 移动 cooldown |
| `tools/tutorial_step4_test.gd` | 旋钮调到 7.085 触发 Victor 语音 + 调错显示噪音 |
| `tools/cover_monologue_test.gd` | cover 独白三行 + 按钮在已有存档时切换 |
| `tools/night_report_log_test.gd` | 10 夜 victor_log_N 正确抽取 + 幸存者状态动态生成 |

### 8.2 视觉验收 capture 脚本清单

| capture 脚本 | 截图用途 |
|---|---|
| `tools/capture_npc_sprite_idle.gd` | Nora/Elias/Lily/Tom idle 帧 |
| `tools/capture_npc_status_bar.gd` | 顶部 NPC 状态条各种状态 |
| `tools/capture_zombie_vs_npc.gd` | 同屏 zombie + NPC 对比，玩家一眼能区分 |
| `tools/capture_cover_monologue.gd` | cover 屏独白三行 |
| `tools/capture_tutorial_step4.gd` | 旋钮 UI |
| `tools/capture_night_report_log.gd` | night 1 / 5 / 9 / 10 的报告对比 |

### 8.3 玩家 walkthrough checklist

solo dev 自测（M11–M15 全部落地后）：
- [ ] night 1 完成 cover 独白 + tutorial step 4 调到 Victor 频道
- [ ] night 2 Nora 加入，看到 sprite + 状态条
- [ ] night 3 Elias 加入 + antenna 修复
- [ ] night 5 Lily / Daniel 加入，信任明显提升
- [ ] night 6 Tom 加入，背包省木板
- [ ] night 7 触发 Daniel 离开 day card 分支（"让他走 / 让他留"）
- [ ] night 8 Tom 牺牲，看到 trust -1 提示
- [ ] night 9 Victor 失联，电台只剩噪音
- [ ] night 10 通关，看到 Victor 的最后广播片段

---

## 9. 路线图（M11–M15）

> 替换 `release_roadmap.md` 的"立即开始"部分。

### M11 — NPC 系统接入主循环（预计 2 天）

- 接 `NightShiftActors` 进 `_update_night`
- 加 `_tick_npcs(delta)` 每 0.2s 重评
- 软锁定 + 不抢玩家 + 移动 cooldown
- `tools/npc_ai_test.gd`
- **PR 范围**：~300 行 GDScript

### M12 — NPC sprite + 视觉区分（预计 1 天）

- 生成 `npc_{nora,elias,lily,tom}.png`（用 matrix MCP 或现有素材重切）
- 加 `npc_layer` 节点（在 enemy_layer 上方）
- 顶部 NPC 状态条
- zombie tint + jitter
- `tools/capture_npc_sprite_idle.gd` + `capture_npc_status_bar.gd` + `capture_zombie_vs_npc.gd`
- **PR 范围**：~200 行 GDScript + 4-8 张 sprite

### M13 — Cover / Tutorial Step 4 / Night Report Hook（预计 2 天）

- Cover 屏独白三行（BaseScreen.gd）
- Tutorial step 4 旋钮 + Victor 语音
- Night report 日志化（victor_log_N + 幸存者状态）
- 13 个新 i18n key（中英双语同步）
- 3 个新 capture + 3 个新 test
- **PR 范围**：~400 行 GDScript + i18n

### M14 — Day Card Body 独白化（预计 1 天）

- 25 张卡的 body 重写（zh 先，en backlog）
- **PR 范围**：~25 行 JSON 编辑 + 25 行 i18n 校对

### M15 — 章节延展：角色来去 + Victor 失联（预计 2 天）

- `chapter_01_nights.json` 加入 lily / daniel / tom 的 success_unlocks
- night 5 / 7 / 8 / 9 的 day_cards 加对应分支卡
- Victor 失联事件（night 9 radio_signal_quality 衰减）
- `tools/capture_night_report_log.gd`（10 夜对比）
- **PR 范围**：~200 行 JSON + 100 行 GDScript

### 累计 PR 总规模

- 约 1000–1200 行 GDScript
- 约 200 行 JSON（data + i18n）
- 约 8–12 张 sprite
- 4 个新 test 套件
- 6 个新 capture 脚本

**预计总工时**：8 天（M11 = 2, M12 = 1, M13 = 2, M14 = 1, M15 = 2）

---

## 10. 决策记录

> 本节是本 spec 的"宪法层"——任何后续 PR 改动跟这些决策冲突的，必须先回到本 spec 改决策，再动代码。

| 决策 | 日期 | 状态 | 内容 |
|---|---|---|---|
| D1 | 2026-06-22 | ✅ 用户确认 | 世界观 = 丧尸末日 + 普通主角 + 体育馆 + 电台 |
| D2 | 2026-06-22 | ✅ 用户确认 | 主角 = 普通人，前便利店夜班背景 |
| D3 | 2026-06-22 | ✅ 用户确认 | NPC 通过广播陆续加入 |
| D4 | 2026-06-22 | ✅ 用户确认 | 10 夜只是开始，后续章节可扩展 |
| D5 | 2026-06-22 | ✅ 用户确认 | 跑掉 / 牺牲 / 坚持 都有 |
| D6 | 2026-06-22 | ✅ 用户确认 | Victor 失联在 night 9（不是 night 10） |
| D7 | 2026-06-22 | ✅ 用户确认 | Tutorial step 4 是 mini-game（手动调频到 7.085），不是过场 |
| D8 | 2026-06-22 | ✅ 用户确认 | Day card body 改独白，先 zh，en backlog |
| D9 | 2026-06-22 | ✅ 用户确认 | ① day card 顺序 → B 路线（requires_unlocked 字段） |
| D10 | 2026-06-22 | ✅ 用户确认 | NPC AI 哲学 = "不死板但不强 AI，只是起个救急" |
| D11 | 2026-06-22 | ⚠️ 用户疑似确认 | NPC 误读实际是 zombie swarm 行为（代码已验证：NPC 是 dead code，僵尸在动） |

### 10.1 仍在讨论

- **night 5 / 7 / 8 / 9 的具体 day card 分支内容** —— 待 M15 落地时再细化
- **city map（Victor 失联后玩家出体育馆找 Victor）** —— M15+ 之外，属于章节外延展，本轮不做
- **6 阶段日循环的"情报整理 / 排班 / 广播"模块** —— 长期 backlog，第二章再考虑

---

## 附录 A. 现有 zombie sprite 清单

见 `assets/final/night_shift/zombie_*.png`：

- `zombie_hands_reach.png` — 手抓特写
- `zombie_shadow_single.png` — 单个影子
- `zombie_shadow_pair.png` — 双个影子
- `zombie_shadow_crowd.png` — 群体影子
- `zombie_outside_window_breach.png` — 窗外破窗
- `zombie_outside_window_approach.png` — 窗外靠近
- `zombie_outside_door_breach.png` — 门外破门
- `zombie_outside_door_approach.png` — 门外靠近

> 已覆盖所有 assault 状态。M12 只做区分强化（tint + jitter），不增加新 sprite。

## 附录 B. i18n Key 增量总表

合计本轮新增 ~50 个 i18n key（zh 必须同步，en 可分批）。

| 类别 | 数量 | 状态 |
|---|---|---|
| Cover | 3 | 🔜 M13 |
| Tutorial Step 4 | 4 | 🔜 M13 |
| Night Report Victor Log | 10 | 🔜 M13 |
| Night Report 幸存者状态 | 3 | 🔜 M13 |
| Day Card Body 独白 | 25 | 🔜 M14 |
| NPC UI 状态 | 4 | 🔜 M12 |
| NPC Join/Left/Lost 通知 | 7 | 🔜 M12 / M15 |
| Survivor 档案 | 6 | 🔜 M15 |

---

> **Spec v0.1 终。下一步：等用户 review → 拍板 → 进 M11。**