# AI Agent 回合提示词缓存优化与双方粮草投影 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把战争场景开场 user 消息重排为「静态身份+地图在前、逐轮变化的本轮次与两军信息在后」以命中自动前缀缓存，并补上敌方（玩家方）粮草与明确的攻守身份。

**Architecture:** Godot `StateProjection.build()` 增设 `side` 与 `economy.enemy`（敌方 rice/money），修正 `attacker_vstate`；服务端 `buildUserMessage()` 把静态段顶到单条 user 消息最前、动态段全部后置，并按 `vstate` 把 `units` 分成敌我两块。敌方粮草走现有 `economy` 整体透传路径（`build_tool_result` → `validateToolResult` → `submitResult` → `live.economy`），因此不需要新增顶层字段或改运行时状态代码。`trace` 补记 `cacheRead` 以验证缓存确实命中。

**Tech Stack:** TypeScript（Node >= 22.19.0，`node --test`）、GDScript 3.6.3（Godot 3 headless，二进制在 `.tools/`）、`@earendil-works/pi-agent-core` / `pi-ai` 1.5.2、OpenAI 兼容 Chat Completions（DeepSeek via CCR）。

**Spec:** `docs/superpowers/specs/2026-11-20-ai-agent-turn-prompt-design.md`

## Global Constraints

- 端点是 `hai/deepseek-flash` 经 CCR 走 OpenAI 兼容 `/v1/chat/completions`；DeepSeek 系是**自动前缀缓存**：按 token 前缀逐字节匹配，**不看 user 消息边界、不需要显式 `cache_control`**。
- 保持**单条 user 消息**，不拆成两条。`SYSTEM_PROMPT` 首句改为「你是战场指挥官」，白兵战 `BATTLE_SYSTEM_PROMPT` 不动。
- **反目标**：把任何逐轮变化的字段（`turn_key`、`day`、`units`、`legal_actions`、`memory`、敌方粮草）放进静态段——一个就足以让整段缓存失效。
- 敌方粮草会在回合内变化，`build_tool_result()` 每次动作回传也必须带上敌方粮草。
- `economy` 里 `rice`/`money` 是每方各自；`day`（`wf.date`）、`max_days: 30`、`main_city_pos` 是全局共享，**不能复制成两份**。
- `side` 复用白兵战 `BattleRequest.side` 已有的 `"attacker" | "defender"` 取值；提示词展示为 system 中已有的「攻方/守方」措辞，不新造词。
- **非目标**：不改工具集、不改引擎战斗逻辑、不改白兵战、不引入显式 `cache_control` 断点、不做跨会话上下文复用。
- 测试命令：`cd agent-service && node --test test/*.test.ts`；Godot 契约/语法测试依赖 `.tools/Godot_v3.6.3-stable_linux_headless.64`（已存在，未安装时才 skip）。
- 每个任务结束时单独 `git commit`；不修改与本次改动无关的文件。

## File Structure

| 文件 | 职责 |
| --- | --- |
| `bwdl/packed/sgz_script/war/AI/StateProjection.gd` | 状态投影源头：`build()` 新增 `side` 与 `economy.enemy`、修正 `attacker_vstate` |
| `agent-service/gdharness/stubs/FakeVState.gd`, `FakeWarFight.gd`, `gdharness/Main.gd` | 让 Godot 3 契约 harness 具备 `is_attacker()` / `get_enemy_vstate()` / 敌方 vstate |
| `agent-service/src/types.ts` | `TurnRequest` 增加可选 `side` |
| `agent-service/src/validate.ts` | `validateTurnRequest` 对 `side` 做可选校验，兼容旧请求体 |
| `agent-service/src/agent.ts` | `SYSTEM_PROMPT` 首句 + 锚点句；重写 `buildUserMessage()` 并导出供测试 |
| `agent-service/src/trace.ts` | `DecisionTrace.budget_used` 增加 `cache_read` / `cache_write` |
| `agent-service/test/fixture.ts` | 提供 `side` 与 `economy.enemy`；`toolResult` 携带含 enemy 的 economy |
| `agent-service/test/validate.test.ts`, `agent.test.ts`, `trace.test.ts`, `gdscript-contract.test.ts` | 各任务的断言 |

**经 recon 确认无需改动**（避免无谓 diff）：`session.ts` 的 `submitResult` 已整体透传 `economy`；`tools.ts` 的 `live.economy` 初始化与 `runAction` 刷新、`inspect_economy` 返回值都已走 `economy` 对象，敌方粮草自动可见；`server.ts` 与 `validateToolResult`、`ToolResultPayload` 无需新增字段；`build_tool_result` 已在第 51 行回传 `fresh["economy"]`，只要 `build()` 的 economy 含 `enemy`，同步自动成立。

## Review Focus

1. **敌方 War_Vstate 为 null**（`get_enemy_vstate()` 返回 null，某些剧本 `attackerWV`/`defenderWV` 缺失）→ 请求不应崩，提示词不得出现 `undefined`/`null`，敌方粮草显示「未知」。测试：Task 3 `buildUserMessage 缺 economy.enemy 时不出现 undefined`。
2. **旧请求体缺 `side` / `economy.enemy`**（旧存档、旧 fixture、直接 POST `/ai/turn`）→ 不返回 400，身份降级为「未知」仍能决策。测试：Task 2 `validateTurnRequest 接受缺 side 的旧请求体`、Task 3 `buildUserMessage 缺 side 时不出现 undefined`。
3. **静态段混入任何逐轮变化字段**→ 缓存静默失效，这是最主要的反目标。测试：Task 3 `同一场战斗连续两轮的静态段逐字节相同` 与 `静态段不含 turn_key/day/units/legal_actions/memory`。
4. **tool result 未同步敌方粮草**→ 模型在回合内连续指挥时读到过期值。测试：Task 1 `gdscript-contract` 断言 `build_tool_result` 的 economy 含 enemy；Task 2 `validateToolResult 原样透传含 enemy 的 economy` + `submitResult 后 payload.economy 一致`。
5. **`usage` 缺 `cacheRead` / 为 0 / undefined**（stub、mock、不同端点）→ trace 不应崩，记为 0。测试：Task 4 `stub 回合的 budget_used.cache_read 为 0 且 trace 状态为 ok`。

---

### Task 1: Godot 投影新增 side / 敌方粮草并补齐 harness stubs

**Files:**
- Modify: `bwdl/packed/sgz_script/war/AI/StateProjection.gd:55-127`（`build`）
- Modify: `agent-service/gdharness/stubs/FakeVState.gd`, `agent-service/gdharness/stubs/FakeWarFight.gd`, `agent-service/gdharness/Main.gd`
- Test: `agent-service/test/gdscript-contract.test.ts:78-101`
- Verify: `agent-service/test/godot3-parse.test.ts`（自动覆盖 GDScript 语法）

**Interfaces:**
- Consumes: `wv.is_attacker()`（`War_Vstate.gd:844`）、`wv.get_enemy_vstate()`（`War_Vstate.gd:458`）、`enemyWV.rice` / `.money`（`War_Vstate.gd:26`）
- Produces: `TurnRequest.side: "attacker" | "defender"`；`TurnRequest.economy.enemy: { rice: number, money: number }`（敌方不存在时省略该键）；`TurnRequest.economy.attacker_vstate` = 攻方 vstate id（不再是恒等于 `controlled_id` 的错值）；`ToolResultPayload.economy` 原样携带同一 economy

- [ ] **Step 1: 写失败测试**

在 `gdscript-contract.test.ts` 的 payload 断言块（第 78 行后）追加：

```ts
assert.ok(["attacker", "defender"].includes(payload.side), "side 必须是 attacker|defender");
assert.equal(typeof payload.economy.enemy.rice, "number", "economy.enemy.rice 必须投影");
assert.equal(typeof payload.economy.enemy.money, "number", "economy.enemy.money 必须投影");
```

并让 `Main.gd` 组装的受控方为**守方**（`wv.side = "防守方"`），追加断言 `assert.notEqual(payload.economy.attacker_vstate, payload.controlled_vstate_id, "守方时攻方 id 不应等于受控方 id")`。

- [ ] **Step 2: 运行测试验证失败**

Run: `cd agent-service && node --test test/gdscript-contract.test.ts test/godot3-parse.test.ts`
Expected: `gdscript-contract` FAIL（`payload.side` 为 undefined / `economy.enemy` 不存在）；`godot3-parse` 仍 PASS。

- [ ] **Step 3: 实现投影**

`StateProjection.gd` 的 `build()`：`var enemy = wv.get_enemy_vstate()`；`var side = "attacker" if wv.is_attacker() else "defender"`；`attacker_vstate` 改为 `controlled_id if wv.is_attacker() else (enemy.id if enemy != null else -1)`；`enemy != null` 时给 `economy` 加 `"enemy": {"rice": enemy.rice, "money": enemy.money}`；返回体顶层加 `"side": side`。`build_tool_result` 不改代码，仅更新第 40-41 行注释说明 economy 已含敌方。

`FakeVState.gd` 补 `var side = "防守方"`、`var enemy_wv = null`、`func is_attacker(): return side == "攻击方"`、`func is_defender(): return side == "防守方"`、`func get_enemy_vstate(): return enemy_wv`；`FakeWarFight.gd` 保持现状；`Main.gd` 创建第二个 WV（`id = 1`, `rice = 310`, `money = 900`, `side = "攻击方"`），互相设置 `enemy_wv`，受控方 `wv` 设为守方。

- [ ] **Step 4: 运行测试验证通过**

Run: `cd agent-service && node --test test/gdscript-contract.test.ts test/godot3-parse.test.ts`
Expected: 两个测试均 PASS（契约测试不 skip，Godot 二进制在 `.tools/`）。

- [ ] **Step 5: Commit**

```bash
git add bwdl/packed/sgz_script/war/AI/StateProjection.gd agent-service/gdharness agent-service/test/gdscript-contract.test.ts
git commit -m "feat(ai-agent): 投影 side 与敌方粮草，修正 attacker_vstate"
```

---

### Task 2: 服务端类型、校验与 fixture

**Files:**
- Modify: `agent-service/src/types.ts:43-61`
- Modify: `agent-service/src/validate.ts:66-81`
- Modify: `agent-service/test/fixture.ts:3-31, 53-67`
- Test: `agent-service/test/validate.test.ts:19-50`

**Interfaces:**
- Consumes: Task 1 的 `side` 与 `economy.enemy` 形状
- Produces: `TurnRequest.side?: "attacker" | "defender"`（可选，兼容旧请求体）；`validateTurnRequest(body)` 在缺 `side` 时仍返回 `TurnRequest`；`sampleRequest()` 默认带 `side: "defender"`、`economy.enemy: { rice: 310, money: 900 }`；`toolResult()` 回传的 `economy` 含 `enemy`

- [ ] **Step 1: 写失败测试**

在 `validate.test.ts` 追加：

```ts
test("validateTurnRequest 接受缺 side / 缺 economy.enemy 的旧请求体", () => {
  const old = sampleRequest();
  delete (old as any).side;
  delete (old as any).economy.enemy;
  assert.equal(validateTurnRequest(old).visibility, "omniscient");
});

test("validateToolResult 原样透传含 enemy 的 economy", () => {
  const r = validateToolResult({
    ok: true, outcome: "ok", units: [], legal_actions: [],
    economy: { rice: 400, enemy: { rice: 300, money: 900 } },
  });
  assert.deepEqual((r.economy as any).enemy, { rice: 300, money: 900 });
});
```

再加一条 `side` 非法值断言：`assert.throws(() => validateTurnRequest({ ...sampleRequest(), side: "neutral" }), ValidationError)`。

- [ ] **Step 2: 运行测试验证失败**

Run: `cd agent-service && node --test test/validate.test.ts`
Expected: 非法 `side` 未被拒绝 → FAIL（`assert.throws` 收到未抛错）；旧请求体用例此时可能已通过。

- [ ] **Step 3: 实现**

`types.ts`：`TurnRequest` 增加 `side?: "attacker" | "defender"`（与 `BattleRequest.side` 同取值）。`validate.ts`：`validateTurnRequest` 中，仅当 `body.side !== undefined` 时校验其必须是 `"attacker"` 或 `"defender"`，否则抛 `ValidationError("bad_schema", "side must be attacker|defender")`；`economy.enemy` 不做必填校验（R1/R2 兜底由提示词层负责）。`fixture.ts`：`sampleRequest()` 加 `side: "defender"` 与 `economy: { ..., enemy: { rice: 310, money: 900 } }`；`toolResult()` 增加 `economy: base.economy`（含 enemy）。

- [ ] **Step 4: 运行测试验证通过**

Run: `cd agent-service && node --test test/validate.test.ts`
Expected: PASS。再跑 `cd agent-service && node --test test/agent.test.ts test/turn.test.ts test/scenarios.test.ts` 确认 fixture 变更未破坏既有测试，Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add agent-service/src/types.ts agent-service/src/validate.ts agent-service/test/fixture.ts agent-service/test/validate.test.ts
git commit -m "feat(ai-agent): 服务端接受 side 与敌方粮草，兼容旧请求体"
```

---

### Task 3: 重写 SYSTEM_PROMPT 与 buildUserMessage（核心）

**Files:**
- Modify: `agent-service/src/agent.ts:30-33`（SYSTEM_PROMPT 首句）、`:337-356`（`buildUserMessage`）、`:472`（导出）
- Test: `agent-service/test/agent.test.ts`, `agent-service/test/trace.test.ts:47`

**Interfaces:**
- Consumes: `TurnRequest.side?`、`TurnRequest.economy.enemy?`、Task 2 的 fixture
- Produces: `export function buildUserMessage(req: TurnRequest, memory: Record<string, unknown> | null): string`；`SYSTEM_PROMPT` 首句为「你是战场指挥官。你指挥 controlled_vstate_id 这一方，对手是玩家方。」；消息结构为单条 user，静态段（身份 + `terrain`）在 `──` 分界之前，动态段（本轮次 / 敌方 / 我方 / 行动指令）在之后

- [ ] **Step 1: 写失败测试**

在 `agent.test.ts` 追加（导入 `buildUserMessage`）：

```ts
test("同一场战斗连续两轮的静态段逐字节相同", () => {
  const a = buildUserMessage(sampleRequest({ turn_key: "w2-d7-s1" }), null);
  const b = buildUserMessage(sampleRequest({ turn_key: "w2-d8-s2", memory: { note: "x" } }), { note: "x" });
  const cut = (s: string) => s.slice(0, s.indexOf("──"));
  assert.equal(cut(a), cut(b), "静态段不得随回合变化");
  assert.ok(!/turn_key|legal_actions|"units"|"memory"|"day"/.test(cut(a)), "静态段不得含动态键");
});

test("buildUserMessage 缺 side / 缺 economy.enemy 时不出现 undefined", () => {
  const req = sampleRequest();
  delete (req as any).side;
  delete (req as any).economy.enemy;
  const msg = buildUserMessage(req, null);
  assert.ok(!msg.includes("undefined"), "不得把缺失字段渲染成 undefined");
  assert.ok(msg.includes("未知"), "缺失的敌方粮草应显示为未知");
});
```

再加 `敌方/我方分组` 断言：敌方块含 `vstate: 1` 的单位 id `31`、我方块含 `12`/`13`，且 `turn_key`/`legal_actions` 出现在分界之后。把 `trace.test.ts:47` 的 `/霸王的大陆/` 断言改为 `/战场指挥官/`。

- [ ] **Step 2: 运行测试验证失败**

Run: `cd agent-service && node --test test/agent.test.ts test/trace.test.ts`
Expected: FAIL（`buildUserMessage` 未导出 / 无 `──` 分界 / 静态段含 `turn_key`）。

- [ ] **Step 3: 实现**

`SYSTEM_PROMPT` 首句替换为「你是战场指挥官。你指挥 controlled_vstate_id 这一方，对手是玩家方。」，其余 114 行规则**原样不动**。

`buildUserMessage(req, memory)` 加 `export`，按 spec 的消息形状拼接单个字符串：静态段 = 「你是攻方/守方。」（`side` 缺失时「身份未知」）+ 「战场地图：」+ `JSON.stringify({ terrain: req.terrain })`；一行 `──` 分界；动态段 = 「本轮次：」+ `JSON.stringify({ turn_key, day, max_days, main_city_pos, diffculities, legal_actions, memory: {...} })`（从 `req.economy` 取公共项）、「敌方：」+ `JSON.stringify({ units: 敌方武将, rice, money })`、「我方：」+ `JSON.stringify({ units: 我方武将, rice, money })`（从 `req.economy` 取 rice/money）、末尾「请你进行行动。」。敌我按 `u.vstate !== req.controlled_vstate_id` 分组。`economy.enemy` 非对象时 rice/money 用字符串 `"未知"`，不得渲染 `undefined` 或 `null`。`terrain` 只出现在静态段，动态段不重复。

- [ ] **Step 4: 运行测试验证通过**

Run: `cd agent-service && node --test test/agent.test.ts test/trace.test.ts test/llm.test.ts`
Expected: 全部 PASS。

- [ ] **Step 5: Commit**

```bash
git add agent-service/src/agent.ts agent-service/test/agent.test.ts agent-service/test/trace.test.ts
git commit -m "feat(ai-agent): 开场消息静态段前置并按敌我分组，system 改为战场指挥官"
```

---

### Task 4: 缓存命中观测

**Files:**
- Modify: `agent-service/src/trace.ts:33`（`budget_used`）
- Modify: `agent-service/src/agent.ts:371`（counters）、`:409-411`（subscribe 累加）、`:449` 与 `:465`（`traceStore.finish`）
- Test: `agent-service/test/trace.test.ts:32-50`

**Interfaces:**
- Consumes: `AssistantMessage.usage.cacheRead` / `cacheWrite`（pi-ai 已解析，DeepSeek 的 `prompt_cache_hit_tokens`）
- Produces: `DecisionTrace.budget_used?: { tokens: number; turns: number; tool_calls: number; cache_read: number; cache_write: number }`；`piTurn` 的 `counters` 累加两个字段，`traceStore.finish` 两条路径都写出

- [ ] **Step 1: 写失败测试**

在 `trace.test.ts` 的 stub 回合用例里追加：

```ts
assert.equal(t!.budget_used?.cache_read, 0, "stub 模式无 usage.cacheRead 时应记为 0 而不崩");
assert.equal(t!.budget_used?.cache_write, 0);
```

- [ ] **Step 2: 运行测试验证失败**

Run: `cd agent-service && node --test test/trace.test.ts`
Expected: FAIL（`cache_read` 为 undefined）。

- [ ] **Step 3: 实现**

`trace.ts`：`budget_used` 类型增加 `cache_read: number; cache_write: number`（`TraceSummary` 不变）。`agent.ts`：`counters` 初始化加 `cacheRead: 0, cacheWrite: 0`；`message_end` 分支在 `counters.tokens` 旁累加 `Number(event.message?.usage?.cacheRead ?? 0)` 与 `cacheWrite`；两处 `traceStore.finish` 的 `budget_used` 对象带上这两个值。白兵战 `battle-agent.ts` 的 `counters` 不动，其 `traceStore.finish` 不传新字段（保持可选兼容）。

- [ ] **Step 4: 运行测试验证通过**

Run: `cd agent-service && node --test test/trace.test.ts`
Expected: PASS。

- [ ] **Step 5: Commit**

```bash
git add agent-service/src/trace.ts agent-service/src/agent.ts agent-service/test/trace.test.ts
git commit -m "feat(ai-agent): trace 记录 prompt cache 命中 token"
```

---

## Final Verification

- [ ] `cd agent-service && node --test test/*.test.ts` 全部 PASS（含 `gdscript-contract.test.ts` 与 `godot3-parse.test.ts` 不 skip）。
- [ ] `make check` 或 `node --test` 确认 GDScript 无 Parse Error（`bwdl/test/ai_agent_validate.gd` 清单含 `StateProjection.gd`）。
- [ ] 手工以 `mode=pi` 跑同一场战斗至少两轮，从 `/ai/traces` 读到第二轮 `budget_used.cache_read > 0`，并对比改动前后每轮 input token 下降；这是「降费用」唯一的实证。
- [ ] 手工确认 `inspect_economy` 工具返回里带 `enemy`，且一次动作执行后工具结果摘要中的 economy 也带 `enemy`（Review Focus #4）。

## Self-Review

1. **Spec coverage**：意图/成功标准 → Task 3、Final Verification；Approach B（双方粮草）→ Task 1/2；单条消息不拆 → Task 3；system 首句 → Task 3；白兵战不动 → 各任务 Files 均未列 `battle-agent.ts`；约束「敌方粮草回合内同步」→ Task 1 + Final Verification；「economy 不复制两份」→ Task 1 只加 `enemy` 子对象、Task 3 公共项留本轮次；`cacheRead` 可观测 → Task 4。无缺口。
2. **Step scan**：每个实现步骤都给出确切签名/字段/取值与文件位置，未给函数体；测试步骤给出断言代码与 spec 的确切值（`side`、`enemy`、分界符 `──`）。无 TBD。
3. **Type consistency**：`side: "attacker" | "defender"` 在 Task 1（GDScript 产出）、Task 2（TS 类型/校验/fixture）、Task 3（提示词展示）一致；`economy.enemy` 在 Task 1/2/3 一致；`cache_read`/`cache_write` 在 Task 4 的 `counters`、`budget_used`、测试断言一致。
4. **Review Focus**：R1 → Task 3 第二条测试；R2 → Task 2 第一条测试 + Task 3；R3 → Task 3 第一条测试；R4 → Task 1 契约断言 + Task 2 第二条测试 + Final Verification；R5 → Task 4。五条均有归属测试。
5. **Proportion**：计划以签名、字段名、断言为主，无实现代码体；长度与 spec 相当。
