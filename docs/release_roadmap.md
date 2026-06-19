# Release Roadmap — Last Radio: 旧体育馆守夜

> Target: Steam · 18 RMB · 中英双语 · 章节小品 · solo dev
> Status: 进入发布准备(原 296/296 测试在 `tools/` 维持)

## Scope cut

为「做完整了再说」,主动砍掉以下通常 indie 小品不需要的东西,集中精力把核心体验打磨好:

| 不做 | 原因 |
|---|---|
| 配音 | 18 RMB 撑不起配音预算,文字+字幕足够 |
| NG+ / Hard Mode / Endless | 一次性通关小品 |
| Modding / Creative Workshop | 没用户基数 |
| Switch / 手游移植 | 没这个分发渠道 |
| 复杂手柄重映射 | 只做基础 Xbox / PS 按键映射 |
| DLC 框架 | 第二章先规划,等第一章卖得动再启动 |
| 速通 / 排行榜 | 小品不需要 |
| 多人 | 体量不适合 |

## 6 周 ~ 10 个里程碑

### M1 — i18n 框架 + 中英字符串(预计 2-3 天)
- 抽 `tr(key, args)` 全局函数
- 加 `data/i18n/en.json`,结构对齐 `zh.json`
- 加 `set_locale()` / `get_locale()`,语言选择存到 `user://settings.json`
- 全文搜索硬编码中文字符串,逐步替换成 `tr("...")`

### M2 — 设置 + 暂停 + 退出(预计 2 天)
- 新场景 `scenes/SettingsMenu.tscn`,可调:音量 / 语言 / 窗口模式 / 帧率上限
- ESC 暂停 overlay(在 `NightShiftGame` 上加 pause 层)
- 退出确认对话框
- 所有用户输入走新的设置值

### M3 — 教程夜(预计 1-2 天)
- 第一夜加 3 步引导:移动 → 修复 → 调电台
- 半透明引导气泡 + 键盘提示 + 「下一步」按钮
- 完成后跳过本引导(存档记录 `tutorial_done: true`)

### M4 — 多存档槽 + 云存档(预计 2 天)
- 存档 schema v3,加 `slot_id` 字段
- Cover 屏显示 3 个存档槽位(空 / 占用 + 摘要)
- 「开始新游戏」要求先选槽
- Steamworks `ISteamRemoteStorage` 接入,自动云同步

### M5 — 美术 / BGM 收口(预计 3-4 天)
- 用 matrix MCP AI 生成缺失的 window / radio / antenna / back_door 状态图 + 角色 portrait
- 生成 4-5 首 BGM:cover / day / night_early / night_late / final(可用 AI music)
- 替换现有的 procedural music fallback

### M6 — Steam 集成(预计 2-3 天)
- 接入 GodotSteam 或 Steamworks GDExtension
- 8-12 个成就:`FirstNight` / `PerfectRepair` / `RadioVictor` / `AllAlliesJoin` / `NoBreachTenNights` / `NightClearFast` 等
- 云存档、Rich Presence(显示「旧体育馆守夜 · 第 N 夜」)
- Steam 输入系统支持基础手柄

### M7 — 法务 / 合规(预计 1 天)
- `LICENSE`(MIT)
- `PRIVACY.md`(GDPR / CCPA 模板)
- `THIRD_PARTY.md`(Godot + 字体 + 任何素材的 attribution)
- IARC 年龄分级问卷(填完出评级标签)

### M8 — 应用图标 / Splash / 窗口(预计 1 天)
- 主图标(256x256 / 512x512 / 多种尺寸)+ 商店 capsule
- Splash 启动画面
- 窗口模式切换(全屏 / 无边框 / 窗口)
- 分辨率缩放

### M9 — 导出预设 + 构建流水线(预计 2 天)
- Windows / Mac / Linux 三套 export preset
- `tools/build_release.ps1`:跑测试 → 切 release → 出包 → 校验
- 版本号 + changelog 模板

### M10 — 商店素材 + 预告片(预计 3-4 天)
- 商店描述(中文 + 英文,短 + 长)
- 6-10 张截图(从 `last_radio_screens/` 选 + 局部加文案)
- 1 分钟预告片(用 ffmpeg 串截图 + 字幕 + BGM,无需视频编辑工具)
- Capsule images(header / main / small / library hero)
- 商店 Tag、分类、价格、本地化

## Launch checklist (M10 完成后)

- [ ] Beta 测试 1 周(steam key 分发给 5-10 个外部玩家)
- [ ] 收集反馈 → 修关键 bug
- [ ] 商店页定稿
- [ ] 设置 release date,默认不可见
- [ ] 发售前 1 周:可见但不可购买 → 进 wishlist 转化
- [ ] 发售当天:可见可购买
- [ ] Day-1 patch 准备好(处理 beta 阶段发现的 P0 bug)
- [ ] 监控 1 周:reviews / crash reports

## 已知风险

| 风险 | 缓解 |
|---|---|
| 美术 AI 生成质量不达标 | 多次迭代 + 备选:用现有 placeholder 美术上架,后期免费更新补 |
| BGM AI 生成不达预期 | 同上,fallback 到纯程序化 SFX |
| Steamworks 集成卡住 | 备用:GodotSteam addon 是社区方案,出问题可切到官方 Steam SDK GDExtension |
| Solo 一个人时间不够 | 主动砍 feature(已在 Scope cut 里),优先级按 Steam 商店硬性要求排 |
| i18n 字符串迁移遗漏 | 用 todowrite 跟踪 hardcoded 字符串清单,每改一个勾一个 |

## 仓库约定

- 主分支 `main`(默认),所有 PR 都往这里合
- 每个 M 完成后打 tag `v0.x-m{N}-done`
- 测试在 `tools/`,每个新功能都要带测试
- 美术 / 音频资源统一放 `assets/final/` 下,程序化 fallback 放 `assets/fallback/`
- 文档更新:`docs/release_roadmap.md`(本文件)同步状态

## 当前进度

| M | 状态 |
|---|---|
| M1 i18n | 进行中(下一步开始) |
| M2 设置/暂停 | 待 M1 完成 |
| M3 教程夜 | 待 M2 完成 |
| M4 多存档 + 云 | 待 M3 完成 |
| M5 美术 + BGM | 待 M4 完成(可与 M6 并行) |
| M6 Steam 集成 | 待 M4 完成 |
| M7 法务 | 任何时候可做 |
| M8 图标 / Splash | 任何时候可做 |
| M9 构建流水线 | 任何时候可做 |
| M10 商店素材 | 收尾阶段 |

## 立即开始:M1 i18n