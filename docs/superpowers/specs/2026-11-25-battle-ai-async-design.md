# 2026-11-25 白兵战 AI：异步 tick 重构（战场 Agent 不变）

状态：已批准（2026-11-25）。待用户审阅本 spec 后进入实现计划。

## 意图与 why

项目里有两套互不相干的 AI Agent：

- **战场 Agent**：大地图回合制，玩家走完轮到 AI，走 `/ai/turn/:id/*` + `end` 收尾。本次**一行不动**。
- **白兵战 Agent**：进入白兵战后独立运行。白兵战是准实时的：玩家随时可以按 A 暂停、改兵种命令、随时用计；引擎不会停下来等 AI。兵种命令本身就是持久设置（`clBattleFight.set_unit_state`），不是「本回合动作」。

现在的白兵战 Agent 沿用了回合制骨架：`POST /ai/battle` 开会话 → 长轮询 `/pending` 取一条指令 → Godot 执行 → `/result` 回传 → 模型 `end_turn` → 引擎推进到下一回合后 `/resume`。这条链有三个结构性错误：

1. **凭空造出回合边界**：引擎里没有「AI 决策回合」，命令随时生效；`end_turn` 只会把步骤机改到 8（`Battle_Auto_Run.gd:358-364`），与真实战局无关。
2. **网络周期挂在 FlowManager 上**：轮询、回传、重试都靠 flow 再次驱动；一旦某个请求/回调被 flow 的忙闲挡住，整场白兵战就冻住（当前未提交版本的实际症状）。
3. **一次只执行一条指令**：服务端指令队列 + Godot 串行执行，AI 在 3 秒内无法整体调整多个兵种。

目标：把白兵战 AI 改成**旁路异步决策器**——每 3 秒读一次战场快照，返回一份「命令差分 + 至多一个计策」，客户端立即应用；引擎和玩家全程不等待 AI。

## 目标 / 非目标 / 反目标

- **目标**
  - 白兵战 AI 每 3 秒一拍；上一拍未返回则跳过，最多一个请求在飞。
  - 一场白兵战 = 一个服务端会话，从开场到结束始终是同一个 Agent 对话。
  - 计划是纯数据：`orders` 差分 + `tactic`（≤1）+ `memory`；没有 `end_turn`。
  - 计策在客户端排队，等 flow 空闲且步骤处于安全点时执行。
  - 请求周期完全不进 `FlowManager`；玩家暂停/操作不影响 AI 的发送与接收。
  - 连续 3 拍失败回退本地规则 AI，并留日志。
- **非目标**
  - **不改战场 Agent**：`war/AI/War_AI_behavior_llm.gd`、`war/AI/StratagemProjection.gd`、`war/AI/AIHttpClient.gd` 的行为、`/ai/turn/*` 路由、`agent.ts` / `session.ts` / `tools.ts`、战场提示词与工具集。
  - 不改战斗数值、伤害公式、阵型、单位行动逻辑。
  - 不让 AI 控制玩家方；不改观海模式（两边都是 AI）的既有分工。
  - 不重做战斗 UI；不新增玩家可见的「AI 思考中」常驻横幅。
- **反目标**
  - 保留 `end_turn` / `resume` 作为兼容分支。
  - 每拍新建会话或每拍重建 Agent。
  - 用长轮询或服务端主动推指令。
  - 在任意步骤直接插 `before_AI_tactic`。
  - 让本地规则 AI 和异步 Agent 同时改同一方的兵种命令。

## 现状与约束（代码事实）

### 引擎侧

- `clBattleFight.set_unit_state(actorId, setting)`（`bwdl/script/objects/clBattleFight.gd:679`）只改 `attacker_state` / `defender_state` 字典；随时调用都安全，下一次单位行动按新命令执行。没有「本回合命令」概念。
- `Global.load_script()` 命中缓存时会再次调用实例的 `_init()`（`bwdl/script/global.gd:648-656`）。`BattleAgent._init()` 若重置会话状态，任何一次重复加载都会清掉在飞请求与会话 id——当前卡死的已知雷区之一。
- `player_control.before_AI_tactic()`（`bwdl/packed/sgz_script/battle/player_control.gd:379`）扣战术值、触发 30008/30018 技能，然后 `confirm_AI_tactic()`（同文件 407）→ `wait_for_AI_tactic()`（`Battle_Auto_Run.gd:740`）把步骤机设成 current=8 / next=4。它原本只在步骤 7（AI 决策步）调用；在步骤 4/5/6 注入时 next=4 会回到 `check_player_action`（`Battle_Auto_Run.gd:814`）→ 步骤 2，不会跳过单位行动。**这是用计只能在安全点插入的原因。**
- `wait_for_AI_tactic` 会把 `当前武将` 之外的面板关掉（`set_view_model(-1)`）；如果玩家正开着暂停面板，直接插入会顶掉玩家 UI。
- 每个兵种可能有多个单位（`clBattleFight._init_units_for`）；`unit_position` 是格子坐标（`bwdl/script/Battle_Unit.gd:30`），`get_shoot_distance()`（同文件 687）给当前射程，`get_attack_distance()` 给近战距离。投影要按兵种聚合，并取「离对方主将最近的单位」的位置。
- 战斗 buff 存在 `War_Actor.dic_buffs`（读取入口 `get_buff`，`bwdl/script/War_Actor.gd:205-208`），每项含 `回合数`；战术 buff 的场景是「小战场」。
- 白兵战步骤机：`_process` 先跑 `_battle_ai_tick()`，再处理 flow 与步骤（`Battle_Auto_Run.gd:170-186`）。AI 的 tick 放在 flow 判断之前，才能做到「玩家操作期间也照常推进」。

### 现有白兵战接入（将被替换）

- `BattleAgent.gd`：`open` / `poll` / `flush` / `resume_turn` / `_handle_asks`，以及 `_turn_open`、`is_opening`、`has_pending_results`。
- `Battle_Auto_Run.gd`：`battle_ai_step`（313）、`battle_ai_turn_ready`（358）、`_battle_ai_tick`（366）、`battle_ai_poll_again`（382）、`battle_ai_after_flush`（387）、`battle_ai_decide`（391）、`battle_ai_fallback`（397）。
- 服务端：`server.ts:247-320` 的 `/ai/battle`、`/pending`、`/resume`、`/estimate`、`/result`；`battle-agent.ts` 的 `runBattle` / `piBattle` / `closeRound` / `closeAfterCommands`；`battle-session.ts` 的指令队列、poller、inflight、ask、`waitForNextTurn`；`battle-tools.ts` 的五个工具。

### 共享文件边界

- `server.ts`、`types.ts`、`trace.ts` 同时被战场/白兵战使用。只允许**追加**白兵战类型与路由分支；战场分支、战场类型、trace 逻辑不改。
- `bwdl/packed/sgz_script/war/AI/AIHttpClient.gd` 被两套共用。本次**不改它**；白兵战新建 `battle/AI/BattleHttpClient.gd`，从代码层面保证战场 Agent 不受影响。
- 工作区已有 `War_AI_behavior_llm.gd` / `StratagemProjection.gd` / `AIHttpClient.gd` 的未提交改动，属于战场侧/共享侧，本次不纳入、不提交。

## 决定（用户已确认）

1. 每 3 秒尝试一次 tick；上一次未返回就跳过本拍。实际间隔 = `max(3s, LLM 延迟)`。
2. 每拍最多一个计策；计策排队到安全点执行。
3. `orders` 用差分，只返回要改的兵种；空对象表示本拍不改。
4. 一场白兵战 = 一个服务端会话；Agent 对话从开场保留到结束。
5. 不做工具循环：快照自带全部决策数据与计策预估，模型一次输出 JSON 计划。
6. 玩家暂停/对话框打开时，节拍降到 10 秒；恢复后回到 3 秒。
7. 连续 3 拍失败回退本地规则 AI。

## 协议

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/ai/battle` | 开场。body：`{battle_key, controlled_actor_id, enemy_actor_id, side, diffculities}`。返回 `{battle_session_id}` |
| POST | `/ai/battle/:id/tick` | 一拍。body = 快照 v2。同步返回 `{tick, plan, latency_ms, usage}` |
| POST | `/ai/battle/:id/end` | 结束会话；fire-and-forget。返回 `{ok:true}` |

删除：`/pending`、`/result`、`/resume`、`/estimate`。

错误：

- `409 tick_in_progress`：同一会话已有一拍在跑（客户端串行，理论上不会发生；服务端防御）。客户端计一次失败，连续 3 次回退。
- `410 session_ended`：会话已结束或 TTL 过期。客户端重开会话，累计 3 次重开仍失败则回退本地 AI。
- `422 invalid_snapshot`：版本/兵种/字段不合法，附 `detail`。客户端记一次失败，连续 3 次回退。
- HTTP 200 但计划解析失败：不算失败，返回空计划；客户端照常进入下一拍。

单拍服务端超时 20 秒；客户端 HTTP 超时 25 秒。服务端超时后 `agent.abort()` 并返回空计划，战斗继续，下一拍重来。

## 数据契约

### 快照 v2（Godot → 服务端）

```json
{
  "battle_version": 2,
  "battle_key": "b12-b34",
  "tick": 7,
  "elapsed_ms": 18400,
  "diffculities": 3,
  "side": "defender",
  "controlled_actor_id": 34,
  "enemy_actor_id": 12,
  "turn": 3,
  "terrain": { "name": "plain", "is_city": false },
  "controlled": {
    "name": "张三",
    "hp": 78,
    "soldiers": 4200,
    "tactic_point": 9,
    "buffs": [{ "name": "火矢", "turns": 2 }],
    "units": [
      { "type": "将", "hp": 78, "count": 1, "order": "待机",
        "x": 7, "y": 5, "shoot_range": 0, "attack_range": 1,
        "dist_to_other_main": 6, "other_main_in_shoot_range": false },
      { "type": "弓", "hp": 260, "count": 3, "order": "待机",
        "x": 8, "y": 3, "shoot_range": 4, "attack_range": 1,
        "dist_to_other_main": 3, "other_main_in_shoot_range": true }
    ]
  },
  "enemy": {
    "name": "李四", "hp": 64, "soldiers": 3100, "tactic_point": 4, "buffs": [],
    "units": [
      { "type": "将", "hp": 64, "count": 1, "order": "前进",
        "x": 12, "y": 5, "shoot_range": 0, "attack_range": 1,
        "dist_to_other_main": 6, "other_main_in_shoot_range": false },
      { "type": "弓", "hp": 180, "count": 2, "order": "待机",
        "x": 11, "y": 4, "shoot_range": 4, "attack_range": 1,
        "dist_to_other_main": 4, "other_main_in_shoot_range": true }
    ]
  },
  "legal_tactics": [
    { "name": "强弩", "cost": 7, "rate": 100,
      "summary": "射程 +2、射箭必发；2 个弓兵受益" }
  ],
  "last_plan": {
    "tick": 6,
    "orders": { "弓": "待机" },
    "orders_applied": ["弓"],
    "orders_rejected": [],
    "tactic": "咒缚",
    "tactic_status": "rejected",
    "reason": "咒缚已生效，重复使用被拒",
    "age_ms": 3200
  }
}
```

口径：

- `units[].hp` 是该兵种所有存活单位的总血量；`count` 是存活单位数；`x/y` 取离对方主将最近的那个单位。
- `dist_to_other_main` 是曼哈顿距离（`Global.get_distance`），`other_main_in_shoot_range` 是「该单位射程 ≥ 距离」的近似判断，不含视线遮挡；提示词必须说明这一点。
- `buffs` 只列 `回合数 > 0` 且 `StaticManager.get_buff(name).get_scene() == "小战场"` 的 buff。
- `legal_tactics` 只列 `available == true` 的计策；每项给 `cost` / `rate` / 一行 `summary`，不塞完整 `impacts`。
- `last_plan` 由客户端回传真实执行结果，不是模型的自我声明。`tactic_status` 取 `applied` / `pending` / `rejected` / `none`：`pending` 表示已入队、还没到安全点；模型看到 `pending` 不要重复下同一个计策。

### 计划（服务端 → Godot）

```json
{
  "orders": { "弓": "待机", "步": "前进" },
  "tactic": "强弩",
  "memory": "敌弓已进射程，先强弩压一轮，主将保持后排",
  "reasoning": "敌弓 3 格内，步压上去贴脸"
}
```

校验规则（服务端与客户端各做一遍）：

- `orders` 的键必须是 `将/骑/象/弓/步`，值必须是 `前进/待机/后退`；只接受快照里 `hp > 0` 的兵种；非法项丢弃并记入下一拍的 `orders_rejected`。
- `tactic` 为 `null`（空字符串按 `null` 处理）或 `legal_tactics` 中的名字；每拍最多一个。
- `memory` ≤ 120 字符；`reasoning` ≤ 200 字符。
- 模型输出必须是纯 JSON；允许外层 ```json 代码块，服务端剥离后再解析。

## 客户端设计

### 新文件：`battle/AI/BattleHttpClient.gd`

- 独立于 `war/AI/AIHttpClient.gd`，不共享队列、不共享实例。
- 同一时刻只允许一个请求在飞；`post()` 在忙时返回 false，由调用方下一拍重试。
- 回调签名 `(result, code, body)`，主线程执行。
- `_init()` 幂等：不因为重复初始化清掉在飞请求。
- 只提供白兵战需要的 `post` / `cancel` / `is_pending`，不实现排队。
- 不再每拍闪「敌方思考中……」；`_show_tips` / `_reset_tips` 与 `_tips_shown` 一并删除。

### 重写：`battle/AI/BattleAgent.gd`

状态：

```
OFF(0) → OPENING(1) → ACTIVE(2) → FALLBACK(3)
```

字段：

- `_session_id`、`_actor_id`、`_tick_no`、`_last_plan`、`_memory`
- `_opening`、`_in_flight`、`_next_tick_at`、`_errors`、`_tactic_queue`、`_tactic_busy`
- `_started_ms`、`_last_plan_at`

`_init()` 不保证幂等：`Global.load_script` 命中缓存会先重放成员初始化再调 `_init()`（Godot 3 实测），会话/在飞请求/队列都会被清空。因此 `tick()` 发现 `_actor_id < 0` 时要重新 `attach()` 并按需重开会话；同一场战斗内不要重复 `load_script`。

公开方法：

- `attach(bf)`：在 `battle_run_start` 时选 AI 方（`controlNo < 0` 的第一方），存 `_actor_id`；不建会话。
- `tick()`：每帧调用。`_process` 在 `FlowManager.has_task()` 之前调用它。
- `get_actor_id()` / `is_local()` / `is_managed(actorId)`。
- `end_battle()`：先 `cancel()` 掉在飞的 tick，再 POST `/end`（fire-and-forget），清状态。

`tick()` 顺序：

1. 不在白兵战场景 / `DataManager.battle_run == false` / `bf == null` → `end_battle()` 并返回。
2. 若 `_actor_id` 未定 → `attach`。
3. 若 `_local` → 返回（步骤 7 已交给规则 AI）。
4. 若 `_session_id == ""` → `open()`（异步，置 `_opening`），本帧返回；`open` 回调成功时置 ACTIVE、`_next_tick_at = now`，失败走计数。
5. 若有待执行计策 → `_try_execute_tactic()`（见下）。
6. 若 `_in_flight` 或 `_opening` → 返回。
7. `now < _next_tick_at` → 返回。
8. 组快照；空且我方武将仍在 → 回退；武将已亡/战斗已结束 → `end_battle()`。
9. `_in_flight = true`；POST `/tick`。
10. 回调 HTTP 200：`_in_flight = false`；解析计划 → 应用 → `_next_tick_at = now + interval`；`_errors = 0`（计划为空/JSON 解析失败也算成功，不计回退）。
11. 回调传输失败/超时/410：`_in_flight = false`；`_errors++`；`_next_tick_at = now + interval`；`_errors >= 3` → `_fallback()`。410 先重开会话一次，再走计数。

节拍：`interval = 3000`；检测到玩家暂停（`scene.battle_state.visible` 或 `SceneManager.actor_dialog.visible`）时 `interval = 10000`。

应用计划：

- `orders`：逐项与 `bf.get_units_state(_actor_id, type)` 比较；只把真正变化的项合并成一次 `bf.set_unit_state(_actor_id, diff)`。全部无变化则不发调用。
- `tactic`：非空且队列为空时入队，带 `expires_at = now + 8000`；`last_plan.tactic_status = "pending"`。
- 服务端返回的 `rejected`（服务端校验丢弃的兵种/计策）要与客户端本地拒绝合并，写进 `last_plan.orders_rejected` / `reason`。
- 计策真正执行后把 `_last_plan.tactic_status` 改为 `applied`；被拒/过期改为 `rejected` 并写 `reason`。
- 记录 `_last_plan`（含 applied/rejected 与 `age_ms`；`age_ms` 在每次组快照时现算），供下一拍快照回传。

计策安全点（`_try_execute_tactic`）：

1. 队列为空 / `_tactic_busy` / 已过期 → 返回或丢弃。
2. `FlowManager.has_task()` 必须为 false。
3. 当前步骤 ∈ `[4, 5, 6, 7]`（`get_current_step()`）。
4. `LoadControl.get_view_model() < 0`，且 `scene.battle_state.visible == false`，且没有玩家对话框。
5. 二次校验：`wa.battle_tactic_point >= cost`、`wa.can_use_tactic()`、同名 buff 未生效、`挑衅` 未被 `solo_disabled()` 禁用。
6. 执行：`DataManager.set_env("当前武将", _actor_id)`、`DataManager.set_env("值", tactic)`、`FlowManager.add_flow("before_AI_tactic")`；`_tactic_busy = true`。
7. `_tactic_busy` 在 flow 回到空闲且步骤回到 2/4/5/6 时清除；超过 10 秒强制清除并记失败。

### 改动：`battle/Battle_Auto_Run.gd`

- 删除 `battle_ai_step / battle_ai_turn_ready / _battle_ai_tick / battle_ai_poll_again / battle_ai_after_flush / battle_ai_decide / battle_ai_fallback` 及对应 `bind_import_flow`。
- `_process` 保留一次 `battle_agent.tick()`，位置不变（flow 判断之前）。
- `battle_run_start` 调用 `battle_agent.attach(bf)`（如果 `battle_agent != null`）。
- 步骤 7 拆分：
  - 对每个 `controlNo < 0` 的 `wa`：
    - `think_about_surrend` 照旧；
    - 若 `battle_agent.is_managed(wa.actorId) and not battle_agent.is_local()`：**跳过** `think_about_order` 和 `think_about_tactic`；
    - 否则照旧执行 `think_about_order` / `think_about_tactic`；
    - `think_about_active_skill` 照旧（主动技不交给 LLM）。
  - 这样 Agent 接管期间，唯一改命令的是 Agent；回退后立即恢复本地 AI。
- `battle_over` / `check_battle_need_over` 的结束分支调用 `battle_agent.end_battle()`。

### 重写：`battle/AI/BattleProjection.gd`

- `build(bf, actorId, tick, lastPlan, elapsedMs)` → 快照 v2。
- `build_result` 删除（不再有逐条指令回传）。
- 辅助：`_side_state`、`_unit_infos`、`_buffs`、`_legal_tactics`、`_terrain`。
- `_unit_infos`：按 `bf.get_attacker_unit_types()` / `bf.get_defender_unit_types()` 的兵种列表聚合，只统计 `leaderId == actorId` 且未 `disabled` 的单位；`hp` 求和、`count` 计数；取离对方主将最近的一个单位作为 `x/y/shoot_range/attack_range` 代表。某兵种 `hp == 0` 即全灭。
- `_legal_tactics`：对每个 `StaticManager.TACTICS` 调 `TacticProjection.estimate`，只保留 `available`，用新增的 `TacticProjection.summary()` 压成一行。

### 改动：`battle/AI/TacticProjection.gd`

- 保留 `estimate(actorId, tactic)`。
- 新增 `summary(estimate) -> String`：
  - 咒缚：「命中率 X%；敌主将定止 N 回合」
  - 挑衅：「接受率 X%；拒绝则敌士气 -4、胆 -10」
  - 强弩：「射程 +2、射箭必发；N 个弓兵受益」
  - 士气向上：「全体攻击 +5~9、士兵防御 ×1.2；N 回合」
  - 火矢：「射箭攻击 +9~15、无视 1/3 防御；N 回合」
- 不足/不可用时返回 `available=false` 与原因，不进 `legal_tactics`。

## 服务端设计

### 重写：`battle-session.ts`

`BattleSession` 从「指令队列 + 长轮询」退化为「一场战斗的 Agent 容器」：

- `id`、`battleKey`、`controlledActorId`、`enemyActorId`、`side`、`createdAt`、`lastActivityAt`
- `agent: Agent`、`trace: DecisionTrace`
- `tick: number`、`inFlight: boolean`
- `memory: string`（上一拍计划里的 `memory`）
- `lastPlan: BattlePlan | null`、`lastPlanResult: BattleLastPlan | null`
- `ended: boolean`
- `tickLock`：`inFlight` 的互斥；同一会话并发 tick 直接 409。
- TTL 30 分钟；`battleStore.prune()` 清理过期会话。

删除：`queue`、`poller`、`resume`、`nextTurnPending`、`turnEndedFlag`、`inflight`、`askBatch`、`askInflight`、`earlyAnswers`、`commands`、`waitForNextTurn`、`submitAnswers`、`markTurnEnded`。

### 重写：`battle-agent.ts`

- `startBattle(req, opts)`：只创建会话与 trace，不跑 LLM。
- `tickBattle(session, snapshot, opts)`：
  1. 校验快照（版本 2、actor 匹配、兵种合法）。
  2. 组 user 消息：本拍序号、距上拍时间、上一拍计划与真实执行结果、`memory`、快照 JSON。
  3. `agent.prompt(userMessage)`，20 秒超时；超时 `agent.abort()`，并 `await agent.waitForIdle()` 后再清 `inFlight`；半截 assistant 消息不存 `lastPlan`，返回空计划。
  4. 取最后一条 assistant 文本 → 剥代码块 → `JSON.parse` → 校验 → 存 `lastPlan`；`memory` 非空时覆盖，空字符串保留上一拍笔记，超 120 字截断。
  5. 追加 trace（user / assistant / tick 元数据），`session.tick++`、`lastActivityAt = now`，返回计划。
- `endBattle(session)`：幂等；`traceStore.finish`，标记 `ended`。TTL 清理时同样 finish，状态记 `expired`。
- 失败：JSON 解析失败返回空计划（非法条目进 `rejected`，不抛错）；不重试，下一拍模型会在对话里看到错误提示。

Agent 构造：

```ts
new Agent({
  initialState: { systemPrompt: BATTLE_SYSTEM_PROMPT, model, tools: [] },
  streamFn,
  finishTurn: async () => ({ action: "end" }),
  transformContext: async (messages) => keepSystemAndLastN(messages, 13),
})
```

- 没有工具，`finishTurn` 一轮即收。
- `transformContext` 保留 system + 最近 6 拍（13 条消息）；跨拍战略靠 `memory`。
- 每拍上限 600 tokens（服务端常量）；没有工具调用，不需要轮数/工具预算。

### 新文件：`battle-plan.ts`

- `BattlePlan` 类型与 `validateBattlePlan(plan, snapshot)`。
- `extractJson(text)`：剥离 ```json 围栏、取第一个平衡的 JSON 对象。
- 校验失败返回 `{plan: emptyPlan(), rejected: [...]}`，不抛 500。

### 改：`types.ts`

只追加白兵战类型：

- `BattleSnapshotV2`、`BattleSideV2`、`BattleUnitV2`、`BattleTacticOption`、`BattleLastPlan`
- `BattlePlan`、`BattleTickResult`
- `BattleOpenRequest`、`BattleTickBudget`

只删除只被白兵战使用的旧类型：`BattlePending`、`BattleResultPayload`、`BattleBudget`。
战场类型（`TurnRequest` 等）不动。

### 改：`server.ts`

- `/ai/battle`：校验 `BattleOpenRequest`，创建会话，返回 id。
- `/ai/battle/:id/tick`：读 body、校验、调 `tickBattle`、返回结果。
- `/ai/battle/:id/end`：调 `endBattle`，返回 ok。
- 删除 `/pending`、`/resume`、`/estimate`、`/result` 分支。
- `/ai/turn/*` 分支一行不动。

## 提示词改动

`BATTLE_SYSTEM_PROMPT` 整体重写，保留现有「秘籍」里仍然正确的数值与战术，但删掉所有回合制表述。结构：

1. **你是白兵战指挥官，不是回合制玩家。** 战斗持续进行，玩家随时可以改命令；你每约 3 秒收到一次最新态势。
2. **命令是持续设置。** `orders` 只写要改的兵种；当前已合适的不要重复；无变化返回空对象。
3. **计策**：每拍最多一个；`legal_tactics` 已给消耗、命中率、一行效果；`controlled.buffs` 里已有的不要重复；战术值不够不要选。
4. **保主将**：主将体力低/被贴脸时优先后退或填肉盾；主将后退=判负，只在最后手段用。
5. **决策优先级**：保主将 → 火力启动（强弩/火矢）→ 斩首 → 压制敌弓 → 填肉盾 → 保残血兵种。沿用现有 prompt 的顺序，但改成「每拍都可以重新评估」。
6. **数值速查**：命令语义、C 值、近身/射击倍率、射程、五个计策的效果与消耗。压缩到 1.5–2KB，避免每拍付长前缀费用。
7. **输出契约**：只输出 JSON，字段名与示例；`memory` 写一句战略笔记；不要 `end_turn`，不要解释文字。
8. **距离口径**：`dist_to_other_main` 是曼哈顿距离，`other_main_in_shoot_range` 不含视线遮挡；实际命中以引擎为准。

每拍 user 消息（`snapshot` 以 JSON 文本原样嵌入）：

```
第 {tick} 拍，距上拍 {dt}ms。战场第 {turn} 回合，已进行 {elapsed_ms}ms。
上一拍你的计划：{orders, tactic}；执行结果：{orders_applied/rejected, tactic_status, reason}。
你的战斗笔记：{memory}
最新态势（JSON）：
{snapshot}
只输出 JSON 计划。
```

## 删除清单

- Godot：`BattleAgent` 的 `poll` / `flush` / `resume_turn` / `_handle_asks` / `_on_polled` / `_on_flushed` / `_on_resumed` / `_queue_result` / `_turn_open` / `is_opening` / `has_pending_results`；`Battle_Auto_Run` 的 7 个 `battle_ai_*` flow；`BattleProjection.build_result`。
- 服务端：`battle-tools.ts` 整个文件；`battle-session` 的队列/轮询/ask/resume；`battle-agent` 的 `runBattle` / `piBattle` / `closeRound` / `closeAfterCommands` / `mockBattle` / `createStubRuntime`。`mode: "mock" | "stub"` 改为在 `tickBattle` 里直接返回确定性计划（存活兵种全部「前进」，无计策），不调用 LLM；只有 `mode: "pi"` 走 Agent。
- 路由：`/pending`、`/result`、`/resume`、`/estimate`。
- 提示词：所有 `end_turn`、`回合结束`、`交还引擎结算`、`逐兵种 set_order` 的旧表述。

## 验证

### 服务端单测

- `battle.test.ts` 重写：
  - 开场 → tick 返回合法计划；同一会话并发 tick → 409。
  - 空计划（`orders:{}`、`tactic:null`）合法。
  - 非法兵种/命令/计策被过滤，下一拍 `last_plan.orders_rejected` 可见。
  - 战术值不足的计策被拒。
  - 模型输出非 JSON → 空计划 + 错误标记，不 500。
  - `/end` 后 tick → 410。
  - 对话裁剪：第 8 拍后消息数不超过 13。
- `server.test.ts`：白兵战路由改测 `/tick` / `/end`；战场 `/ai/turn/*` 断言不动。
- `battle-gdscript.test.ts` + `gdharness/battle_ai`：
  - 更新为 v2 快照：断言 `battle_version == 2`、`units[].x/y`、`legal_tactics[].summary`。
  - 用 stub 服务端跑 `open → tick`，断言 Godot 收到计划并调用 `set_unit_state`（FakeBattleFight 记录调用）。
  - 计策排队逻辑用 FakeFlowManager 断言：flow 忙时不执行，空闲且步骤 4 时执行一次。
- `ai-url.test.ts`：保留 `resolve_ai_agent_url("/ai/battle")` 断言。
- `gdscript-refs.test.ts`：若引用了被删函数，同步更新。

### 手动验收

1. 大模型难度进白兵战：AI 在态势变化后 ≤5 秒内改命令；连续无变化时日志显示空计划。
2. 玩家按 A 暂停、改命令、用计：AI 请求照常收发，不卡、不抢、不顶掉面板。
3. 全场日志无 `end_turn` / `resume` / `pending` / `result`。
4. 用计只在 flow 空闲 + 步骤 4/5/6/7 执行；重复 buff / 战术值不足被拒，下一拍 `last_plan` 显示原因。
5. 断网/服务端停掉：3 拍后回退本地 AI，日志有 `[BattleAI] fallback`。
6. trace dashboard 一场战斗一条 trace，每拍一组 user/assistant。

## 风险与边界

- **LLM 延迟**：3–10 秒是常态；实际决策间隔 = `max(3s, 延迟)`。靠单次 JSON、短快照、600 max_tokens 压延迟。
- **用计步骤机**：安全点判断依赖 `get_current_step()` 与 `FlowManager.has_task()`；实现时必须用真实战斗验证 4/5/6/7 四个点，尤其是玩家暂停恢复后的第一帧。
- **费用**：一场 2 分钟战斗约 40 次调用；暂停降频是主要省钱手段。若仍偏高，后续可加「态势签名未变则跳过 LLM」，但不在本次范围。
- **观海模式**：两边都是 AI 时仍只给一方开 Agent，另一方走本地规则 AI；这是现状，不在本次范围。
- **会话 TTL**：30 分钟对单场白兵战足够；异常退出后重进会新建会话，旧会话由 TTL 清理。
- **共享文件**：`server.ts` / `types.ts` / `trace.ts` 只做追加；任何需要改战场分支的冲动都视为越界，停下来重新评估。

## 实施顺序（细节留给 plan）

1. 服务端：新类型 + `battle-plan.ts` + `battle-session.ts` + `battle-agent.ts` + 路由 + 单测。
2. Godot：`BattleHttpClient` + `BattleProjection` v2 + `TacticProjection.summary`。
3. Godot：`BattleAgent` 状态机 + `Battle_Auto_Run` 接线与步骤 7 拆分。
4. GDScript harness 与契约测试更新。
5. 真机手动验收，按上面的 6 条逐项过。
