# 末日电台 Demo

《末日电台：旧体育馆守夜》原型，当前主方向是 **第一章 10 夜守夜**。

## 方向

- 玩家是旧体育馆避难点的值班员，夜晚亲自在场地上奔走守住门窗、电力、电台、天线和避难者。
- 白天做有代价的生存决策（加固 / 搜救 / 搜刮 / 广播），夜晚用唯一的在场主角承担这些决策的后果。
- 完整 10 夜战役，含 Nora、Elias、Victor 三条剧情线。

详细策划见 `docs/design/game_design_spec_zh.md` 与 `docs/design/chapter_01_night_plan_zh.md`。

## 运行

Godot 4.3 工程，主入口 `scenes/NightShiftGame.tscn`。(docs 早期提到 4.6.3,
实际本机验证用的是 4.3-stable,文件 / API 都兼容。)

```powershell
# Windows 引擎路径
& "C:\Users\Administrator\godot_console.exe" --path .
# 或
& "D:\迅雷下载\Godot_v4.3-stable_win64.exe" --path .
```

## 验证

```powershell
# 用本机真实路径——这里以 C:\Users\Administrator\godot_console.exe 为例
# (D:\迅雷下载\Godot_v4.3-stable_win64.exe 也兼容，已在本机验证)
$exe = "C:\Users\Administrator\godot_console.exe"

# Headless 测试套（11 个，~340 个断言，全部 PASS）
foreach ($t in @(
    "save_test","sfx_test","flow_integration_test","night_shift_basic_test",
    "night_shift_data_validate","hotspot_dot_test","day_effects_test",
    "late_hotspot_enemy_test","night_report_stats_test","radio_contact_test",
    "night_shift_full_flow_test","signal_catalog_test"
)) {
    & $exe --headless --path . --script "res://tools/$t.gd"
}

# 视觉捕获（不带 --headless——需要渲染后端）
& $exe --path . --script res://tools/capture_night_shift_screens.gd
& $exe --path . --script res://tools/capture_smoke_test.gd
```

历史脚本（v0.5 时代，引用已移除的 `_debug_*` API）已归档为
`tools/_archived_*.gd`，每个都加了 SKIP banner 和对应的现行替代。

## Godot AI MCP（实验性）

工程已装 `godot-ai` editor plugin，启用后通过 `http://127.0.0.1:8000/mcp` 暴露 120+ 个 Godot 操作（场景、节点、UI、动画、物理、音频等）。

使用步骤：

1. 打开 Godot editor（不能 headless）
2. Project > Project Settings > Plugins 启用 **Godot AI**
3. Dock 面板会出现 "Godot AI"，按 Configure all 配置客户端
4. Mavis 已注册 `godot-ai` MCP server，会自动连

**注意**：plugin 启动时依赖 `uv`（Python 包管理器），首次启用会自动安装依赖。

## 结构

- `scenes/NightShiftGame.tscn` — 主场景（只挂脚本，UI 在脚本里 build）
- `scripts/NightShiftGame.gd` — 主控脚本（数据驱动薄主控，状态机）
- `scripts/NightShiftData.gd` — 读 `data/night_shift/*.json` 数据
- `scripts/NightShiftLevels.gd` — 第一章 10 夜剧情文本与节奏常量
- `scripts/NightShiftArt.gd` — 资源映射（热点状态、卡牌图标、事件插画、告警）
- `scripts/NightShiftSave.gd` — 存档（v2 schema，向后兼容 v1）
- `scripts/NightShiftDayEffects.gd` — 白天卡牌 → 夜晚参数聚合器
- `scripts/NightShiftSfx.gd` — 程序化 SFX（beep / alarm / chord / static / breath）
- `scripts/HotspotDot.gd` — 圆形热点绘制（条 + 攻击环 + breach 光晕）
- `data/night_shift/{resources,day_cards,chapter_01_nights,signals}.json` — 正式数据
- `docs/radio_design.md` — 电台频道扫描机制与奖励钩子文档
- `assets/final/night_shift/` — 已集成的最终美术（待补：window / radio / antenna / back_door / portrait）

## 当前状态（2026-06-18）

- 主脚本从零重写，数据驱动，状态机：cover → day → night → night_report → final
- 第一章 10 夜全部端到端跑通（`night_shift_full_flow_test.gd` 67/67）
- 电台 mini-game：3 频道拨盘（Victor / Elias / 干扰），调对频道 3 秒 = 1 次接通
- 奖励钩子：成功接通 +1 信任 / 错过窗口 +1 暴露 / 错台（干扰）+0.5 暴露
- 失守可视化：assault 触发时屏幕外圈刷 2-4 红点敌人，朝热点爬行
- 失败夜报告屏带数据区块（坚持时间 / 修复时长 / 失守次数 / 事件触发 / 电台接通 / 资源快照）
- 存档 schema v3（增加 `tutorial_done`），向前兼容 v1/v2
- 16 个测试套件，~514 个断言，全部 PASS
- 美术：window / radio / antenna / back_door 全套状态图已就位，icon + splash 已生成
- 音乐：cover / day / night_early / night_late / final / ambience 全套 BGM 就位
- 多存档槽：3 个槽位
- 中英双语：所有 UI / 资源 / 卡牌 / 夜故事 / 报告文案
- 教程夜：第一夜三步引导（移动 → 修复 → 守到天亮）
- 设置菜单：音量 / 语言 / 全屏 / 退出确认 / 暂停
