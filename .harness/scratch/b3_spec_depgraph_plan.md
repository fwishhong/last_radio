# B3 Plan — Spec Dependency Graph Tool

> **状态** (2026-07-06):plan 锁定,开干。
> **Branch**:`feat/b3-spec-depgraph`(基于 `master` @ `b2f3eea`)
> **Owner**:harness (Mavis) hand-on,延续 B1/B2 直接撸的模式

---

## 1. 动机

`docs/design/last_radio_v2_polish_spec.md` 现在 578 行,14+ 章节,每个章节踩的 `.gd` / `.tscn` / `.json` / i18n key / PNG / test / capture 都分散在章节正文里。

后面 B4-B7 写实现的时候,dev session 要先手动 grep 章节 → 找文件清单 → 跟 `scripts/` / `data/` / `tools/` 实际存在对一遍 → 才能下手。

**B3 把这个手动活儿自动化**:扫一遍 spec,输出每个 §N.M 节的依赖图 + 与磁盘实况对账。

## 2. 范围

### In scope
- `tools/spec_depgraph.gd` — SceneTree 工具,headless 跑,接受 `--spec` 参数(默认 polish spec),输出 stdout 表格 + 写 `.harness/scratch/polish_depgraph.json`
- `tools/spec_depgraph_test.gd` — 自测,fixture spec(写在测试文件内)+ 解析正确性 assertion

### Out of scope
- 不动 `docs/release_roadmap.md`(orchestrator 专属)
- 不动 `data/` JSON(纯文本 spec 解析,不碰游戏数据)
- 不动 polish spec 本身(只读)
- 不写 capture 脚本(无视觉产出)
- 不接 canonical headless gate(这是 meta-tool,不是 gameplay behavior — 跟 `night_shift_data_probe.gd` 同样的定位)

## 3. 解析规则(spec 章节 → 依赖类别)

### 3.1 章节切分
- 切到 `##` / `###` / `####` 三级标题,每节保留完整正文
- 章节 ID = header 文本(如 `4.5 数据 schema (NightShiftGame 状态扩展)`)

### 3.2 依赖类别
每个节正文里抓以下 6 类引用:

| 类别 | 匹配规则 | 示例 |
|---|---|---|
| `scripts` | 反引号包 `.gd` 路径,或裸名出现在 `KNOWN_SCRIPTS` 列表 | `NightShiftGame.gd`, `NightShiftActors.gd`, `BaseScreen`, `TutorialOverlay` |
| `scenes` | 反引号包 `.tscn` 路径 | `NightShiftGame.tscn` |
| `data` | 反引号包 `.json`(只匹配 `data/` 下),含 day_cards / chapter_01_nights / signals / resources / i18n | `data/day_cards.json`, `data/night_shift/chapter_01_nights.json` |
| `i18n` | 反引号包 snake_case 标识符 + 在 `KNOWN_I18N_PREFIXES` 内 | `cover_monologue_line1`, `report_victor_log_5` |
| `assets` | 反引号包 `.png` / `.tres` / `.res` / `.import`,或 `assets/` 子路径 | `zombie_hands_reach.png`, `npc_{nora,elias}.png` |
| `tests` | 章节标题或正文含 `新增`,且引用 `tools/*_test.gd` 或 `tools/capture_*.gd` 文件名 | `tools/npc_ai_test.gd`, `capture_npc_status_bar.gd` |

### 3.3 KNOWN_SCRIPTS / KNOWN_I18N_PREFIXES

启动时从 `scripts/` 实读 + `data/i18n/zh.json` 实读:
- `KNOWN_SCRIPTS = scripts/*.gd`(去掉 `.gd` 后缀的 basename)
- `KNOWN_I18N_PREFIXES = 所有 `i18n_<...>`, `cover_<...>`, `tut_<...>`, `report_<...>`, `npc_<...>`, `log_<...>`, `survivor_<...>`(取唯一前缀)

这样新加脚本 / 新加 i18n key 时,工具自动跟随,不需要维护黑名单。

### 3.4 去重 + 排序
- 同类别内字符串去重,字母序
- 跨章节同引用,在 JSON 里用 `ref_count`,在表格里只列一次

## 4. 输出格式

### 4.1 stdout(人类读)
```
=== Spec Dependency Graph: docs/design/last_radio_v2_polish_spec.md ===

§0 TL;DR  (line 22-31)
   scripts:   —
   scenes:    —
   data:      —
   i18n:      —
   assets:    —
   tests:     —

§4 NPC 系统 (line 174-258)
   scripts:   BaseScreen.gd, I18n.gd, NightShiftActors.gd, NightShiftGame.gd, TutorialOverlay.gd
   scenes:    NightShiftGame.tscn
   data:      —
   i18n:      log_ally_join_nora, log_ally_join_elias, log_ally_join_lily, npc_status_idle, npc_status_walking
   assets:    character_nora.png, character_elias.png, nora_walk/*.png, elias_walk/*.png
   tests:     npc_ai_test.gd
   captures:  capture_npc_sprite_idle.gd, capture_npc_status_bar.gd, capture_zombie_vs_npc.gd
```

### 4.2 JSON(机器读)
写到 `.harness/scratch/polish_depgraph.json`:
```json
{
  "spec_path": "docs/design/last_radio_v2_polish_spec.md",
  "generated_at": "2026-07-06T...",
  "section_count": 16,
  "sections": [
    {
      "id": "§0 TL;DR",
      "line": 22,
      "scripts": [],
      "scenes": [],
      "data": [],
      "i18n": [],
      "assets": [],
      "tests": [],
      "captures": []
    },
    {
      "id": "§4 NPC 系统",
      "line": 174,
      "scripts": ["BaseScreen.gd", "NightShiftActors.gd", "NightShiftGame.gd", "TutorialOverlay.gd"],
      "scenes": ["NightShiftGame.tscn"],
      "i18n": ["log_ally_join_nora", ...],
      "assets": ["character_nora.png", ...],
      "tests": ["npc_ai_test.gd"],
      "captures": ["capture_npc_sprite_idle.gd", "capture_npc_status_bar.gd", "capture_zombie_vs_npc.gd"]
    }
  ],
  "cross_ref": {
    "scripts_orphan": ["RefScript.gd"],         // spec 引了但 scripts/ 里没有
    "scripts_ghost": ["OldRefactored.gd"],     // scripts/ 里有但 spec 没引
    "i18n_keys_unused_in_spec": ["old_key_1"], // zh.json 有但 spec 没引
    "tests_uncovered_sections": ["§0"],        // spec 章节没有任何 test ref(可能漏)
    "tests_no_spec_ref": ["old_test.gd"]       // tools/ 里有 test 但 spec 没引
  }
}
```

### 4.3 Cross-reference 输出
- **scripts_orphan**:spec 反引号引用 / 出现在 KNOWN_SCRIPTS 列表的脚本名,但 `scripts/` 实际找不到 → 可能 spec 描述了一个还没建的脚本(预警)
- **scripts_ghost**:`scripts/` 里有但 spec 没引的脚本(可能不需要,只是预警)
- **i18n_keys_unused_in_spec**:`data/i18n/zh.json` 里有但 spec 没引的 key(可能是其他地方的,也可能 spec 漏了)
- **tests_no_spec_ref**:tools/ 里 test 但 spec 没引(类似 ghost)

## 5. Acceptance bar

1. `tools/spec_depgraph.gd --help` 跑通,显示 usage
2. 不带参数跑,默认读 polish spec,stdout 表格 + JSON 都生成
3. `tools/spec_depgraph_test.gd` headless 全绿(fixture spec 解析准确性 assertion)
4. 在 polish spec 上跑,JSON 文件落到 `.harness/scratch/polish_depgraph.json`,stdout 表格显示所有章节
5. `git diff master` 只动 `tools/spec_depgraph.gd` + `tools/spec_depgraph_test.gd` + `.harness/scratch/b3_spec_depgraph_plan.md`(可选)+ `.harness/memory/b3_depgraph_tool.md`(使用说明)
6. 22-suite canonical headless gate 保持全绿(B3 不在 gate 内,但跑一遍确认没踩别人)

## 6. 不踩的坑

- **`&&`**:严格走 `and` 关键字(ampersand_lint_test 保护)
- **UTF-8**:所有 file IO 走 Read/Write/Edit tool 或 GDScript `FileAccess` UTF-8,禁 PowerShell `Get-Content | Set-Content`
- **branch hygiene**:`feat/b3-spec-depgraph`,不直推 master
- **commit message**:conventional commits,`feat(tooling): M15 polish B3 — spec dependency graph tool`
- **PR body**:含 B3 工具的 sample 输出(跑一次 polish spec 抓的)+ acceptance 勾选

## 7. 不接 gate 的理由(写在 PR body)

- B3 是 meta-tool,不验证任何 gameplay 行为
- 跟 `tools/night_shift_data_probe.gd` / `tools/audit_night_shift_assets.gd` 同级(都是 ad-hoc 工具)
- 但 `spec_depgraph_test.gd` 本身要 headless 跑通,因为它验证 fixture 解析逻辑
- 这样未来如果 spec 改了格式,可以单独跑 `spec_depgraph_test.gd` 检查 depgraph tool 自己有没有坏