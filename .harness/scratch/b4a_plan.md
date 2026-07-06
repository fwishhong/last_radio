# B4a — §4.4 NPC UI 状态条 — close-out plan

> **状态** (2026-07-06):plan 锁定,开干。

---

## 范围

实现 polish spec §4.4 — 顶部 NPC UI 状态条:
- 每行 `{portrait} {名字} → {hotspot_label} {状态文字}`
- 4 个状态:`救急中` / `赶路中` / `待命` / `信任告急`(全局 trust<2 时)
- ally 未加入时隐藏

## 文件

- 新 `scripts/NpcStatusBar.gd` — `Control` 节点,`refresh(allies, npc_state, trust)` 是单一入口
- 新 `tools/npc_ai_status_test.gd` — 17 个 assertion,7 TC groups
- 改 `scripts/NightShiftGame.gd` — 新增 `npc_status_bar` 字段 + 接入 `_tick_npcs` 末尾
- 改 `data/i18n/{zh,en}.json` — 加 4 个 `npc_status_*` keys
- 改 `AGENTS.md` — canonical gate 20 → 21
- 改 `CHANGELOG.md` + `docs/release_roadmap.md`

## 设计要点

1. **NpcStatusBar 是个纯 View** — 不持有 Timer,不直接读 `allies` / `npc_state`,只接受外部传参 refresh。这样 `_tick_npcs` 是单一 refresh 触发点(0.2s cadence),不会额外 tick。
2. **状态优先级**(per polish spec §4.4):
   - `trust < 2` → `信任告急`(覆盖其他,全行统一)
   - `target != ""` AND `walk_timer <= 0` → `救急中`
   - `target != ""` AND `walk_timer > 0` → `赶路中`
   - `target == ""` → `待命`
3. **每行结构**:Panel (240×40) + TextureRect (portrait) + Label (name) + Label (status)
4. **隐藏规则**:`refresh` 时 allies 中没有 true 的或 npc_state 没对应条目 → `visible = false`
5. **i18n-aware**:`I18n.set_locale("en")` 后会自动切到 en 文本(test TC6 验证)
6. **Survivor brief fallback**:在没有 `survivor_<id>_brief` 的 zh/en locale 下(目前缺,B4b 才补),用 plain English name 兜底
7. **Portrait fallback**:没有 `portrait_<id>.png` 时(Lily / Tom 没到位),用 _npc_color 染色 + 不显示图片
8. **Stale row teardown**:ally 离开 rotation 时,自动 queue_free 旧 Panel

## 验收

- `tools/npc_ai_status_test.gd` headless 17/17 PASS
- 21-suite canonical gate 21/21 PASS(原 20 + 新 1)
- polish spec §4.4 acceptance:状态条存在 + 4 个状态正确 + ally 隐藏
- 跟 M11 NPC AI 兼容:`_tick_npcs` 末尾 refresh → bar 跟 NPC 状态同步

## 不接 M15 预工作

B4a 只接 polish spec §4.4,不做:
- lily / daniel / tom 的 npc_state init(那是 B4a-bridge 或 B5 的事)
- chapter_01_nights.json 改动
- 任何 art 生成(lily / tom portrait 留给 M15 art pass)
- M11.5 audio init(M11.5 已 done)