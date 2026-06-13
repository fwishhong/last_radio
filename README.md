# 最后电台 Demo

末日电台基地经营原型。当前主入口是 v0.4 的电台控场塔防切片：白天选择监听信号，夜晚调频到不同路线，用电台技能改变战场并守住广播塔。

旧版 7 天卡片原型和 v0.2 调频派遣原型仍保留，但不再作为主场景。

当前 v0.4 的核心方向：

- 三夜战役：每天选择 1 个信号，信号改变当夜风险、资源和幸存者路线。
- 电台控场：先选择北桥、南门或维修通道频段，再释放干扰、诱导、安抚广播、过载脉冲。
- 塔防取舍：6 个固定建造点，设施包含旧式机炮、铁栅路障、中继器、诱饵喇叭。
- 敌人反制：感染者、奔跑者、嚎叫者、装甲感染者需要不同处理，暴露度会追加压力。
- 废土战术屏：写实灯塔基地作为主战场，叠加路线预警、频段高亮、广播波、生命条、设施等级和电台频谱 UI。

## 运行

```powershell
& ..\Godot_v4.6.3-stable_win64_console.exe --path . --quit
& ..\Godot_v4.6.3-stable_win64.exe --path .
```

自动烟测：

```powershell
& ..\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/defense_smoke_test.gd
& ..\Godot_v4.6.3-stable_win64_console.exe --headless --path . --script res://tools/v2_smoke_test.gd
```

截图检查：

```powershell
& ..\Godot_v4.6.3-stable_win64_console.exe --path . --script res://tools/capture_defense_gui.gd
```

截图脚本需要可用渲染后端；纯 `--headless` 环境下会显式失败，避免保存空图或脏帧。

## 结构

- `scenes/DefenseGame.tscn`：v0.4 主场景，三夜电台控场塔防。
- `scripts/DefenseGame.gd`：战役状态、路线频段、建造、敌人、无线电技能、反馈特效和结算。
- `data/defense_campaign.json`：三夜信号选择、波次、奖励。
- `data/defense_radio_actions.json`：四个电台控场技能。
- `data/defense_facilities.json` / `data/defense_units.json`：防线设施和敌人定义。
- `tools/defense_smoke_test.gd`：覆盖三夜战役、电台调频、技能、掉落、救援和结算。
