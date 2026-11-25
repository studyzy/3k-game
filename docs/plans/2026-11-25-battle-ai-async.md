# 白兵战 AI 异步 tick 重构 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把白兵战 Agent 从「回合制长轮询 + end_turn」改成「每 3 秒一拍、快照进/计划出」的异步决策器；战场 Agent 一行不动。

**Architecture:** Godot 每 3 秒 POST 一次完整战场快照到同一个战斗会话；服务端同一个 Agent 连续对话，返回 JSON 计划（orders 差分 + 至多一个计策）；客户端立即应用 orders，计策排队到 flow 空闲且步骤 4/5/6/7 时执行。没有工具、没有 end_turn、没有 /pending、/result、/resume。

**Tech Stack:** TypeScript + Node 22 + node:test + pi-agent-core；Godot 3.6.3 + GDScript。

---

## 0. 执行前必读

1. **只改白兵战。** 以下文件一行不动、不 git add：
   - `bwdl/packed/sgz_script/war/AI/War_AI_behavior_llm.gd`
   - `bwdl/packed/sgz_script/war/AI/StratagemProjection.gd`
   - `bwdl/packed/sgz_script/war/AI/AIHttpClient.gd`
   - `agent-service/src/agent.ts`、`session.ts`、`tools.ts`
   - `/ai/turn/*` 的所有路由分支
2. 工作区已有上述文件的未提交改动。每次提交只 `git add` 本任务列出的文件，禁止 `git add -A`。
3. 设计依据：`docs/superpowers/specs/2026-11-25-battle-ai-async-design.md`（已提交 `a8fbd2d`）。
4. 常用命令：
   - 服务端单测：`cd agent-service && node --test test/<file>.test.ts`
   - 服务端全量：`cd agent-service && npm test`
   - GDScript 语法：`make check`
   - GDScript 契约测试：`cd agent-service && GODOT3_BIN=/Users/devinzeng/Code/studyzy/3k-game/Godot_3.6.3.app/Contents/MacOS/Godot node --test test/battle-gdscript.test.ts`
5. Godot 是 3.6.3，不是 4.x。GDScript 的 `HTTPRequest.request()` 签名是 5 个参数，第 4 个是 method(int)。

---

## 1. 文件地图

**服务端新增/重写**

| 文件 | 动作 |
| --- | --- |
| `agent-service/src/types.ts` | 替换白兵战类型段（v1 -> v2） |
| `agent-service/src/battle-plan.ts` | 新增：计划解析/校验 |
| `agent-service/src/battle-session.ts` | 重写：一场战斗一个 Agent 容器 |
| `agent-service/src/battle-agent.ts` | 重写：open/tick/end + 新提示词 |
| `agent-service/src/validate.ts` | 替换白兵战校验段 |
| `agent-service/src/server.ts` | 只替换白兵战路由分支 |
| `agent-service/src/battle-tools.ts` | 删除 |
| `agent-service/test/battle-plan.test.ts` | 新增 |
| `agent-service/test/battle-session.test.ts` | 新增 |
| `agent-service/test/battle.test.ts` | 重写 |
| `agent-service/test/server.test.ts` | 替换白兵战路由测试 |

**Godot 新增/重写**

| 文件 | 动作 |
| --- | --- |
| `bwdl/packed/sgz_script/battle/AI/BattleHttpClient.gd` | 新增：白兵战独立异步 HTTP |
| `bwdl/packed/sgz_script/battle/AI/BattleProjection.gd` | 重写：快照 v2 |
| `bwdl/packed/sgz_script/battle/AI/TacticProjection.gd` | 只加 `summary()` |
| `bwdl/packed/sgz_script/battle/AI/BattleAgent.gd` | 重写：3 秒状态机 |
| `bwdl/packed/sgz_script/battle/Battle_Auto_Run.gd` | 删 AI flow、步骤 7 拆分、attach/end |

**GDScript harness**

| 文件 | 动作 |
| --- | --- |
| `agent-service/gdharness/battle_ai/project.godot` | 加 `LoadControl` autoload |
| `agent-service/gdharness/battle_ai/Main.gd` | 重写：两套场景 |
| `agent-service/gdharness/battle_ai/stubs/DataManagerStub.gd` | 扩展 |
| `agent-service/gdharness/battle_ai/stubs/GlobalStub.gd` | 扩展 |
| `agent-service/gdharness/battle_ai/stubs/StaticManagerStub.gd` | `TACTICS` 改为 var |
| `agent-service/gdharness/battle_ai/stubs/FlowManagerStub.gd` | 加 `has_task()` |
| `agent-service/gdharness/battle_ai/stubs/SceneManagerStub.gd` | 加 `current_scene()` |
| `agent-service/gdharness/battle_ai/stubs/FakeBattleFight.gd` | 扩展 |
| `agent-service/gdharness/battle_ai/stubs/FakeWarActor.gd` | 扩展 |
| `agent-service/gdharness/battle_ai/stubs/FakeActorInfo.gd` | 扩展 |
| `agent-service/gdharness/battle_ai/stubs/FakeBattleUnit.gd` | 新增 |
| `agent-service/gdharness/battle_ai/stubs/LoadControlStub.gd` | 新增 |
| `agent-service/gdharness/battle_ai/stubs/FakeScene.gd` | 新增 |
| `agent-service/test/battle-gdscript.test.ts` | 重写 |

---

## Task 1: 服务端 v2 类型与计划校验

**Files:**
- Modify: `agent-service/src/types.ts`
- Create: `agent-service/src/battle-plan.ts`
- Test: `agent-service/test/battle-plan.test.ts`

**Step 1: 写失败测试**

创建 `agent-service/test/battle-plan.test.ts`：

```ts
import test from "node:test";
import assert from "node:assert/strict";
import { emptyPlan, extractJson, validateBattlePlan } from "../src/battle-plan.ts";
import type { BattleSnapshotV2 } from "../src/types.ts";

function snapshot(over: Partial<BattleSnapshotV2> = {}): BattleSnapshotV2 {
  return {
    battle_version: 2,
    battle_key: "b12-b31",
    tick: 1,
    elapsed_ms: 1200,
    diffculities: 4,
    side: "attacker",
    controlled_actor_id: 12,
    enemy_actor_id: 31,
    turn: 1,
    terrain: { name: "plain", is_city: false },
    controlled: {
      name: "张辽", hp: 90, soldiers: 1200, tactic_point: 10,
      buffs: [],
      units: [
        { type: "将", hp: 400, count: 1, order: "待机", x: 6, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
        { type: "弓", hp: 250, count: 2, order: "待机", x: 8, y: 3, shoot_range: 4, attack_range: 1, dist_to_other_main: 3, other_main_in_shoot_range: true },
      ],
    },
    enemy: {
      name: "高顺", hp: 88, soldiers: 900, tactic_point: 8,
      buffs: [],
      units: [
        { type: "将", hp: 350, count: 1, order: "待机", x: 12, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
      ],
    },
    legal_tactics: [{ name: "强弩", cost: 7, rate: 100, summary: "射程 +2" }],
    last_plan: null,
    ...over,
  };
}

test("extractJson 支持纯 JSON、代码围栏、前后散文与字符串里的花括号", () => {
  assert.deepEqual(extractJson('{"a":1}'), { a: 1 });
  assert.deepEqual(extractJson("好的：\n```json\n{\"a\":2}\n```\n"), { a: 2 });
  assert.deepEqual(extractJson('前言 {"a":"}"} 后语'), { a: "}" });
  assert.throws(() => extractJson("not json"));
});

test("合法计划：orders 差分 + 一个可用计策 + memory 截断", () => {
  const r = validateBattlePlan({ orders: { 弓: "待机" }, tactic: "强弩", memory: "x".repeat(200) }, snapshot());
  assert.deepEqual(r.plan.orders, { 弓: "待机" });
  assert.equal(r.plan.tactic, "强弩");
  assert.equal(r.plan.memory?.length, 120);
  assert.equal(r.rejected.length, 0);
});

test("非法兵种、已灭兵种、非法命令、非法计策、战术值不足全部被拒", () => {
  const snap = snapshot({ controlled: { ...snapshot().controlled, tactic_point: 3 } });
  const r = validateBattlePlan({
    orders: { 船: "前进", 骑: "前进", 弓: "冲锋" },
    tactic: "火矢",
  }, snap);
  assert.deepEqual(r.plan.orders, {});
  assert.equal(r.plan.tactic, null);
  assert.equal(r.rejected.length, 4);
  assert.deepEqual(r.plan, emptyPlan());
});

test("空字符串 tactic 视为 null；非对象计划返回空计划", () => {
  assert.equal(validateBattlePlan({ orders: {}, tactic: "" }, snapshot()).plan.tactic, null);
  assert.deepEqual(validateBattlePlan("x", snapshot()).plan, emptyPlan());
});
```

**Step 2: 跑测试确认失败**

```bash
cd agent-service && node --test test/battle-plan.test.ts
```

Expected: FAIL，`Cannot find module '../src/battle-plan.ts'`。

**Step 3: 改 `types.ts`**

在白兵战类型段**末尾追加**以下 v2 类型。不要重复定义 `BattleUnitType` / `BattleOrder`（旧段已有）；旧的 v1 类型先保留，Task 4 统一删除。

```ts
// ---------------------------------------------------------------------------
// 白兵战（Battle）异步 tick：一场战斗一个会话，每拍快照进、计划出
// ---------------------------------------------------------------------------

export interface BattleUnitV2 {
  type: BattleUnitType;
  /** 该兵种所有存活单位的总血量。 */
  hp: number;
  /** 存活单位数。 */
  count: number;
  order: BattleOrder;
  /** 离对方主将最近的单位的坐标。 */
  x: number;
  y: number;
  shoot_range: number;
  attack_range: number;
  dist_to_other_main: number;
  other_main_in_shoot_range: boolean;
}

export interface BattleSideV2 {
  name: string;
  hp: number;
  soldiers: number;
  tactic_point: number;
  buffs: Array<{ name: string; turns: number }>;
  units: BattleUnitV2[];
}

export interface BattleTacticOption {
  name: string;
  cost: number;
  rate: number;
  summary: string;
}

export interface BattleLastPlan {
  tick: number;
  orders: Partial<Record<BattleUnitType, BattleOrder>>;
  orders_applied: BattleUnitType[];
  orders_rejected: Array<{ unit: string; reason: string }>;
  tactic: string | null;
  tactic_status: "applied" | "pending" | "rejected" | "none";
  reason: string;
  age_ms: number;
}

export interface BattleSnapshotV2 {
  battle_version: 2;
  battle_key: string;
  tick: number;
  elapsed_ms: number;
  diffculities: number;
  side: "attacker" | "defender";
  controlled_actor_id: number;
  enemy_actor_id: number;
  turn: number;
  terrain: { name: string; is_city: boolean };
  controlled: BattleSideV2;
  enemy: BattleSideV2;
  legal_tactics: BattleTacticOption[];
  last_plan?: BattleLastPlan | null;
}

export interface BattlePlan {
  orders: Partial<Record<BattleUnitType, BattleOrder>>;
  tactic: string | null;
  memory?: string;
  reasoning?: string;
}

export interface BattleValidationRejected {
  kind: "order" | "tactic";
  value: string;
  reason: string;
}

export interface BattleTickBudget {
  max_tokens: number;
  timeout_ms: number;
}

export interface BattleOpenRequest {
  battle_key: string;
  controlled_actor_id: number;
  enemy_actor_id: number;
  side: "attacker" | "defender";
  diffculities: number;
}

export interface BattleTickResult {
  tick: number;
  plan: BattlePlan;
  rejected: BattleValidationRejected[];
  latency_ms: number;
  /** 服务端模型调用超时：客户端应计一次失败。 */
  timeout?: boolean;
}
```

旧的 `BattleRequest`、`BattleUnit`、`BattleBudget`、`BattlePending`、`BattleResultPayload` 本任务**先保留**，等 Task 4 把 `validate.ts` / `server.ts` 全部改完后统一删除，避免中途编译断裂。`RandomAsk` / `RandomAnswer` 保留（战场 `/estimate` 仍在用）。

**Step 4: 创建 `battle-plan.ts`**

```ts
import type {
  BattleOrder, BattlePlan, BattleSnapshotV2, BattleUnitType, BattleValidationRejected,
} from "./types.ts";

export const BATTLE_UNIT_TYPES: BattleUnitType[] = ["将", "骑", "象", "弓", "步"];
export const BATTLE_ORDERS: BattleOrder[] = ["前进", "待机", "后退"];

export function emptyPlan(): BattlePlan {
  return { orders: {}, tactic: null, memory: "", reasoning: "" };
}

/** 从模型输出里取第一个平衡的 JSON 对象；支持代码围栏与前后散文。 */
export function extractJson(text: string): unknown {
  let s = String(text ?? "").trim();
  const fence = /```(?:json)?\s*([\s\S]*?)```/i.exec(s);
  if (fence) s = fence[1].trim();
  const start = s.indexOf("{");
  if (start < 0) throw new Error("no JSON object");
  let depth = 0;
  let inStr = false;
  let esc = false;
  for (let i = start; i < s.length; i++) {
    const ch = s[i];
    if (inStr) {
      if (esc) esc = false;
      else if (ch === "\\") esc = true;
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '"') { inStr = true; continue; }
    if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) return JSON.parse(s.slice(start, i + 1));
    }
  }
  throw new Error("unbalanced JSON object");
}

export function validateBattlePlan(
  raw: unknown, snapshot: BattleSnapshotV2,
): { plan: BattlePlan; rejected: BattleValidationRejected[] } {
  const rejected: BattleValidationRejected[] = [];
  const plan = emptyPlan();
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    rejected.push({ kind: "order", value: "", reason: "计划不是 JSON 对象" });
    return { plan, rejected };
  }
  const o = raw as Record<string, unknown>;
  const alive = new Set(snapshot.controlled.units.filter((u) => u.hp > 0).map((u) => u.type));

  if (o.orders !== undefined) {
    if (typeof o.orders !== "object" || o.orders === null || Array.isArray(o.orders)) {
      rejected.push({ kind: "order", value: String(o.orders), reason: "orders 不是对象" });
    } else {
      for (const [unit, order] of Object.entries(o.orders as Record<string, unknown>)) {
        if (!BATTLE_UNIT_TYPES.includes(unit as BattleUnitType)) {
          rejected.push({ kind: "order", value: unit, reason: "未知兵种" });
          continue;
        }
        if (!alive.has(unit as BattleUnitType)) {
          rejected.push({ kind: "order", value: unit, reason: "该兵种已灭" });
          continue;
        }
        if (typeof order !== "string" || !BATTLE_ORDERS.includes(order as BattleOrder)) {
          rejected.push({ kind: "order", value: unit + ":" + String(order), reason: "未知命令" });
          continue;
        }
        plan.orders[unit as BattleUnitType] = order as BattleOrder;
      }
    }
  }

  if (typeof o.tactic === "string" && o.tactic.trim() !== "") {
    const tactic = o.tactic.trim();
    const legal = snapshot.legal_tactics.find((t) => t.name === tactic);
    if (!legal) {
      rejected.push({ kind: "tactic", value: tactic, reason: "不在可用计策中" });
    } else if (legal.cost > snapshot.controlled.tactic_point) {
      rejected.push({ kind: "tactic", value: tactic, reason: "战术值不足" });
    } else {
      plan.tactic = tactic;
    }
  }

  if (typeof o.memory === "string") plan.memory = o.memory.slice(0, 120);
  if (typeof o.reasoning === "string") plan.reasoning = o.reasoning.slice(0, 200);
  return { plan, rejected };
}
```

**Step 5: 跑测试确认通过**

```bash
cd agent-service && node --test test/battle-plan.test.ts
```

Expected: PASS，5 个测试全绿。

**Step 6: 提交**

```bash
git add agent-service/src/types.ts agent-service/src/battle-plan.ts agent-service/test/battle-plan.test.ts
git commit -m "feat(battle): 白兵战 v2 快照与计划校验"
```

---

## Task 2: 战斗会话容器

**Files:**
- Modify: `agent-service/src/battle-session.ts`（整文件重写）
- Test: `agent-service/test/battle-session.test.ts`

**Step 1: 写失败测试**

```ts
import test from "node:test";
import assert from "node:assert/strict";
import { BattleSession, BattleStore } from "../src/battle-session.ts";

const init = {
  battleKey: "b12-b31",
  controlledActorId: 12,
  enemyActorId: 31,
  side: "attacker" as const,
  diffculities: 4,
};

test("create/get/delete/clear", () => {
  const store = new BattleStore();
  const s = store.create(init);
  assert.ok(s.id.length > 0);
  assert.equal(store.get(s.id), s);
  assert.equal(store.size(), 1);
  store.delete(s.id);
  assert.equal(store.get(s.id), undefined);
  store.clear();
});

test("beginTick 是互斥的，endTick 释放", () => {
  const s = new BattleSession("b", init, 1000);
  assert.equal(s.beginTick(), true);
  assert.equal(s.beginTick(), false);
  s.endTick();
  assert.equal(s.beginTick(), true);
});

test("idleRemaining 与 prune 按空闲时间清理", () => {
  const store = new BattleStore();
  const s = store.create(init, 10);
  s.lastActivityAt = Date.now() - 100;
  assert.equal(store.get(s.id), undefined);
});

test("finish 幂等", () => {
  const s = new BattleSession("b", init);
  s.finish("x");
  s.finish("y");
  assert.equal(s.finished, true);
  assert.equal(s.endReason, "x");
});
```

**Step 2: 跑测试确认失败**

```bash
cd agent-service && node --test test/battle-session.test.ts
```

Expected: FAIL，`BattleStore` 未导出 / 构造签名不符。

**Step 3: 重写 `battle-session.ts`**

```ts
import type { Agent } from "@earendil-works/pi-agent-core";
import type { BattleLastPlan, BattlePlan } from "./types.ts";
import type { DecisionTrace } from "./trace.ts";

export interface BattleSessionInit {
  battleKey: string;
  controlledActorId: number;
  enemyActorId: number;
  side: "attacker" | "defender";
  diffculities: number;
}

/**
 * 一场白兵战 = 一个 BattleSession。
 * 它只保存 Agent 对话、跨拍记忆与并发锁；不再有指令队列、poller、resume。
 */
export class BattleSession {
  readonly id: string;
  readonly init: BattleSessionInit;
  readonly createdAt = Date.now();
  readonly idleTimeoutMs: number;
  lastActivityAt = Date.now();

  tick = 0;
  inFlight = false;
  ended = false;
  endReason = "";

  memory = "";
  tokens = 0;
  lastPlan: BattlePlan | null = null;
  lastPlanResult: BattleLastPlan | null = null;

  agent: Agent | null = null;
  trace: DecisionTrace | null = null;

  constructor(id: string, init: BattleSessionInit, idleTimeoutMs = 30 * 60 * 1000) {
    this.id = id;
    this.init = init;
    this.idleTimeoutMs = idleTimeoutMs;
  }

  get finished(): boolean { return this.ended; }

  touch(): void { this.lastActivityAt = Date.now(); }

  idleRemaining(): number {
    return this.idleTimeoutMs - (Date.now() - this.lastActivityAt);
  }

  /** 同一会话同时只允许一拍。 */
  beginTick(): boolean {
    if (this.inFlight) return false;
    this.inFlight = true;
    this.touch();
    return true;
  }

  endTick(): void {
    this.inFlight = false;
    this.touch();
  }

  finish(reason: string): void {
    if (this.ended) return;
    this.ended = true;
    this.endReason = reason;
    this.touch();
  }
}

export class BattleStore {
  private items = new Map<string, BattleSession>();
  private seq = 0;

  create(init: BattleSessionInit, idleTimeoutMs = 30 * 60 * 1000): BattleSession {
    this.prune();
    this.seq += 1;
    const id = "b-" + Date.now().toString(36) + "-" + this.seq.toString(36);
    const s = new BattleSession(id, init, idleTimeoutMs);
    this.items.set(id, s);
    return s;
  }

  get(id: string): BattleSession | undefined {
    this.prune();
    return this.items.get(id);
  }

  delete(id: string): void { this.items.delete(id); }

  prune(): void {
    for (const [id, s] of this.items) {
      if (s.idleRemaining() <= 0) this.items.delete(id);
    }
  }

  clear(): void { this.items.clear(); }
  size(): number { return this.items.size; }
}

export const battleStore = new BattleStore();
```

**Step 4: 跑测试确认通过**

```bash
cd agent-service && node --test test/battle-session.test.ts
```

Expected: PASS，4 个测试全绿。

**Step 5: 提交**

```bash
git add agent-service/src/battle-session.ts agent-service/test/battle-session.test.ts
git commit -m "refactor(battle): 白兵战会话改为一场战斗一个 Agent 容器"
```

---

## Task 3: 异步 tick 决策与提示词

**Files:**
- Modify: `agent-service/src/battle-agent.ts`（整文件重写）
- Test: `agent-service/test/battle.test.ts`（整文件重写）

> 本任务与 Task 4 必须连续完成。Task 4 之前 `server.ts` 仍在用旧的 `startBattle` 解构返回值，`npm test` 会失败，属预期；本任务只跑 `battle.test.ts`。

**Step 1: 写失败测试**

```ts
import test from "node:test";
import assert from "node:assert/strict";
import { startBattle, tickBattle, endBattle } from "../src/battle-agent.ts";
import { battleStore } from "../src/battle-session.ts";
import { traceStore } from "../src/trace.ts";
import { scriptedModel, text } from "./harness.ts";
import { testConfig } from "./fixture.ts";
import type { BattleOpenRequest, BattleSnapshotV2 } from "../src/types.ts";

const openReq: BattleOpenRequest = {
  battle_key: "b12-b31",
  controlled_actor_id: 12,
  enemy_actor_id: 31,
  side: "attacker",
  diffculities: 4,
};

function snapshot(over: Partial<BattleSnapshotV2> = {}): BattleSnapshotV2 {
  return {
    battle_version: 2,
    battle_key: "b12-b31",
    tick: 1,
    elapsed_ms: 1200,
    diffculities: 4,
    side: "attacker",
    controlled_actor_id: 12,
    enemy_actor_id: 31,
    turn: 1,
    terrain: { name: "plain", is_city: false },
    controlled: {
      name: "张辽", hp: 90, soldiers: 1200, tactic_point: 10, buffs: [],
      units: [
        { type: "将", hp: 400, count: 1, order: "待机", x: 6, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
        { type: "弓", hp: 250, count: 2, order: "待机", x: 8, y: 3, shoot_range: 4, attack_range: 1, dist_to_other_main: 3, other_main_in_shoot_range: true },
      ],
    },
    enemy: {
      name: "高顺", hp: 88, soldiers: 900, tactic_point: 8, buffs: [],
      units: [
        { type: "将", hp: 350, count: 1, order: "待机", x: 12, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
      ],
    },
    legal_tactics: [{ name: "强弩", cost: 7, rate: 100, summary: "射程 +2" }],
    last_plan: null,
    ...over,
  };
}

test.beforeEach(() => { battleStore.clear(); traceStore.clear(); });

test("stub 模式返回确定性计划：存活兵种全部前进", async () => {
  const s = startBattle(openReq, { mode: "stub", config: testConfig });
  const r = await tickBattle(s, snapshot(), { mode: "stub", config: testConfig });
  assert.equal(r.tick, 1);
  assert.deepEqual(r.plan.orders, { 将: "前进", 弓: "前进" });
  assert.equal(r.plan.tactic, "强弩", "stub 会挑第一个合法计策");
  assert.equal(s.lastPlan?.orders["弓"], "前进");
});

test("pi 模式：模型输出 JSON 计划，memory 被保存", async () => {
  const model = scriptedModel(() => text('{"orders":{"弓":"待机"},"tactic":null,"memory":"压弓","reasoning":"测试"}'));
  const s = startBattle(openReq, { mode: "pi", config: testConfig, runtime: model.runtime });
  const r = await tickBattle(s, snapshot(), { mode: "pi", config: testConfig, runtime: model.runtime });
  assert.deepEqual(r.plan.orders, { 弓: "待机" });
  assert.equal(r.plan.tactic, null);
  assert.equal(s.memory, "压弓");
  assert.equal(model.requests[0].tools.length, 0, "白兵战不再给模型任何工具");
  assert.ok(model.requests[0].systemPrompt.includes("每隔约 3 秒"));
  assert.ok(model.requests[0].userMessage.includes("第 1 拍"));
});

test("非 JSON / 非法计策：返回空计划并记录 rejected，不抛 500", async () => {
  const badJson = scriptedModel(() => text("不是 JSON"));
  const s1 = startBattle(openReq, { mode: "pi", config: testConfig, runtime: badJson.runtime });
  const r1 = await tickBattle(s1, snapshot(), { mode: "pi", config: testConfig, runtime: badJson.runtime });
  assert.deepEqual(r1.plan.orders, {});
  assert.equal(r1.rejected.length, 1);

  const badTactic = scriptedModel(() => text('{"orders":{},"tactic":"火计"}'));
  const s2 = startBattle(openReq, { mode: "pi", config: testConfig, runtime: badTactic.runtime });
  const r2 = await tickBattle(s2, snapshot(), { mode: "pi", config: testConfig, runtime: badTactic.runtime });
  assert.equal(r2.plan.tactic, null);
  assert.equal(r2.rejected[0].kind, "tactic");
});

test("同一会话并发 tick → 409；结束会话后 tick → 410", async () => {
  const s = startBattle(openReq, { mode: "stub", config: testConfig });
  s.beginTick();
  await assert.rejects(
    () => tickBattle(s, snapshot(), { mode: "stub", config: testConfig }),
    (err: any) => err.status === 409 && err.code === "tick_in_progress",
  );
  s.endTick();

  endBattle(s);
  await assert.rejects(
    () => tickBattle(s, snapshot(), { mode: "stub", config: testConfig }),
    (err: any) => err.status === 410 && err.code === "session_ended",
  );
});

test("对话裁剪：第 8 拍仍不超过 13 条消息", async () => {
  const model = scriptedModel(() => text('{"orders":{},"tactic":null}'));
  const s = startBattle(openReq, { mode: "pi", config: testConfig, runtime: model.runtime });
  for (let i = 0; i < 8; i++) {
    await tickBattle(s, snapshot({ tick: i + 1 }), { mode: "pi", config: testConfig, runtime: model.runtime });
  }
  assert.ok(model.requests[7].messages.length <= 13, "system + 最近 6 拍");
  assert.equal(s.trace?.events.some((e) => e.type === "user"), true);
  assert.equal(s.trace?.events.some((e) => e.type === "assistant"), true);
});
```

**Step 2: 跑测试确认失败**

```bash
cd agent-service && node --test test/battle.test.ts
```

Expected: FAIL，`tickBattle` / `endBattle` 未导出。

**Step 3: 重写 `battle-agent.ts`**

```ts
// 白兵战异步 tick：一场战斗一个 Agent 会话，每拍快照进、计划出。
// 没有工具、没有 end_turn、没有长轮询；计策在客户端安全点执行。
import { Agent } from "@earendil-works/pi-agent-core";
import { builtinModels } from "@earendil-works/pi-ai/providers/all";
import type {
  BattleOpenRequest, BattlePlan, BattleSnapshotV2, BattleTickResult, BattleValidationRejected,
} from "./types.ts";
import type { ServiceConfig } from "./config.ts";
import type { PiRuntime } from "./agent.ts";
import { ServiceError } from "./agent.ts";
import { createCustomRuntime } from "./llm.ts";
import { traceStore, type DecisionTrace } from "./trace.ts";
import { battleStore, type BattleSession } from "./battle-session.ts";
import { emptyPlan, extractJson, validateBattlePlan } from "./battle-plan.ts";

const TICK_TIMEOUT_MS = 20_000;
const MAX_MESSAGES = 13;

export const BATTLE_SYSTEM_PROMPT = [
  "你是三国策略游戏「霸王的大陆」白兵战（两军对阵）的我方指挥官。",
  "战斗是准实时的：玩家随时可能暂停、改命令、用计，引擎不会停下来等你。你每隔约 3 秒收到一次最新态势，只需要决定「要不要改命令 / 要不要用计」。",
  "",
  "## 输出（只输出 JSON，不要解释）",
  '{"orders":{"弓":"待机"},"tactic":null,"memory":"一句战略笔记","reasoning":"一句理由"}',
  "- orders 是差分：只写要改的兵种；当前命令已经合适就不要写；都不想改就返回 {}。",
  "- 命令：前进（进攻）、待机（原地防守）、后退（撤退）。",
  "- tactic：每拍最多一个，必须是 legal_tactics 里的名字；不用就 null。",
  "- memory：≤120 字，下一拍会原样回喂给你；写接下来 1-2 拍的意图。",
  "- 不要输出 end_turn，不要输出 JSON 以外的文字。",
  "",
  "## 命令的真实含义",
  "- 前进：向敌主将寻路；能打就按 近身 > 投掷 > 射箭 出手；射箭 70% 命中触发。",
  "- 待机：不移动；但射箭/投掷必发（100%）。弓兵想稳定输出就待机。",
  "- 后退：不攻击、只往己方出生侧撤；撤出场外该兵种消失。主将后退 = 整场判负。",
  "",
  "## 伤害与 C 值",
  "- 最终伤害 = 基础攻击 × 倍率 × C/100 − 免伤。C 只由攻击者体力决定：将 C=体力×2；士兵按兵力：<1500→20，<3500→40，<6000→50，<8000→70，<9000→85，<10000→95，≥10000→100。",
  "- 士兵兵力 <3500 时伤害只有 40%，残兵不要主动进攻。",
  "- 近身倍率：将/骑/步 1.0，象 2.2，弓 0.5；弓远射 1.0，投掷默认 0.5。武将打武将伤害 1~12，打士兵最少 1。",
  "",
  "## 射程",
  "- 弓 4（特殊 5），骑(弓) 3；近身默认 1（枪 2）。",
  "- 无强弩时，主将尽量离敌弓 5 格以上；敌开强弩则 7 格以上。",
  "- 主将身边的步/骑/象是肉盾，敌人必须先清掉它们才能贴主将。",
  "",
  "## 计策（legal_tactics 已给 cost/rate/summary）",
  "- 咒缚 3：50% 定住敌主将 3 回合，最适合敌主将后撤/在射程外。",
  "- 火矢 10：4 回合，射箭攻击 +9~15，无视 1/3 防御；兵多能持续输出才值。",
  "- 士气向上 8：4 回合，全体攻击 +5~9，士兵防御 ×1.2；持久肉搏时用。",
  "- 强弩 7：3 回合，射程 +2、射箭必发；射程 0 的兵种不受益。",
  "- 挑衅 5：敌主将接受单挑；多数接受率低，但被拒会掉敌 4 士气/10 胆。",
  "- 同一时间只存在一个战术 buff，后开覆盖先开；controlled.buffs 里已有的不要重复。",
  "",
  "## 决策顺序（每拍都可以重新评估）",
  "1. 主将体力 ≤50 或被贴脸且无反击 → 主将后退/待机，步骑填肉盾。",
  "2. 弓兵在射程内且血线健康 → 先开强弩/火矢，再让弓兵待机。",
  "3. 敌主将体力低且近战能贴身 → 步/骑/象 前进斩首。",
  "4. 敌弓能射到我方主将 → 近战前进贴脸，逼它近身（弓近身 0.5）。",
  "5. 主将回避时，用健康步/骑顶在主将前 1~2 格。",
  "6. 某兵种 hp ≤2 格（≈200）→ 后退保存；兵力 <3500 不主动进攻。",
  "",
  "## 数据口径",
  "- controlled/enemy.units[].x/y 是离对方主将最近的单位坐标；dist_to_other_main 是曼哈顿距离。",
  "- other_main_in_shoot_range 只是「射程 ≥ 距离」的近似，不含视线遮挡；实际命中以引擎为准。",
  "- 主将 = units 里 type 为「将」的那一项。",
].join("\n");

export interface BattleOptions {
  mode: "mock" | "stub" | "pi";
  config: ServiceConfig;
  runtime?: PiRuntime;
}

function traceModel(opts: BattleOptions): string {
  if (opts.mode === "stub") return "stub";
  if (opts.mode === "mock") return "mock";
  return opts.config.llmBaseUrl ? opts.config.llmModelId : opts.config.modelId;
}

export function startBattle(req: BattleOpenRequest, opts: BattleOptions): BattleSession {
  const session = battleStore.create({
    battleKey: req.battle_key,
    controlledActorId: req.controlled_actor_id,
    enemyActorId: req.enemy_actor_id,
    side: req.side,
    diffculities: req.diffculities,
  });
  const tr = traceStore.create({
    mode: opts.mode,
    model: traceModel(opts),
    turn_key: req.battle_key,
    diffculities: req.diffculities,
    controlled_vstate_id: req.controlled_actor_id,
    legal_actions_count: 0,
    ai_agent_mode: true,
    system_prompt: BATTLE_SYSTEM_PROMPT,
    user_message: "",
    tools: [],
  });
  traceStore.add(tr, "system", { text: BATTLE_SYSTEM_PROMPT });
  session.trace = tr;
  return session;
}

function trimMessages(messages: any[], keep: number): any[] {
  if (messages.length <= keep) return messages;
  let systemEnd = -1;
  for (let i = 0; i < messages.length; i++) {
    if (messages[i]?.role === "system") systemEnd = i;
  }
  const head = systemEnd >= 0 ? messages.slice(0, systemEnd + 1) : [];
  const tailKeep = Math.max(1, keep - head.length);
  return [...head, ...messages.slice(-tailKeep)];
}

function ensureAgent(session: BattleSession, opts: BattleOptions): Agent | null {
  if (opts.mode !== "pi") return null;
  if (session.agent) return session.agent;
  const runtime = opts.runtime ?? realRuntime(opts.config, process.env as Record<string, string | undefined>);
  const agent = new Agent({
    initialState: {
      systemPrompt: BATTLE_SYSTEM_PROMPT,
      model: runtime.model as never,
      tools: [] as never,
    },
    streamFn: runtime.streamFn as never,
    getApiKey: runtime.getApiKey,
    finishTurn: async () => ({ action: "end" }),
    transformContext: async (messages) => trimMessages(messages as unknown as any[], MAX_MESSAGES) as never,
  });
  agent.subscribe((event: any) => {
    if (event.type === "message_end" && event.message?.role === "assistant") {
      session.tokens += Number(event.message?.usage?.totalTokens ?? 0);
    }
  });
  session.agent = agent;
  return agent;
}

function realRuntime(
  config: ServiceConfig, env: Record<string, string | undefined>,
): PiRuntime {
  if (config.llmBaseUrl) {
    const key = env.LLM_API_KEY ?? env.PI_API_KEY;
    if (!key) throw new ServiceError(503, "api_key_missing", "缺少 LLM_API_KEY / PI_API_KEY");
    return createCustomRuntime({
      baseUrl: config.llmBaseUrl,
      modelId: config.llmModelId,
      apiKey: key,
      providerId: config.llmProviderId,
      contextWindow: config.llmContextWindow,
      maxTokens: config.llmMaxTokens,
    });
  }
  const models = builtinModels();
  const model = models.getModel(config.provider, config.modelId) ?? models.getModels(config.provider)[0];
  if (!model) throw new ServiceError(503, "model_unavailable", "无法解析模型 " + config.provider + "/" + config.modelId);
  const keyFor = (p: string) => env[p.toUpperCase().replace(/[^A-Z0-9]/g, "_") + "_API_KEY"] ?? env.PI_API_KEY;
  if (!keyFor(config.provider)) {
    throw new ServiceError(503, "api_key_missing", "缺少 " + config.provider.toUpperCase() + "_API_KEY");
  }
  return { model, streamFn: models.streamSimple.bind(models), getApiKey: keyFor, modelId: model.id };
}

async function promptWithTimeout(
  agent: Agent, message: string, timeoutMs: number,
): Promise<{ kind: "done" } | { kind: "timeout" }> {
  let aborted = false;
  let timer: ReturnType<typeof setTimeout> | null = null;
  const timeout = new Promise<{ kind: "timeout" }>((resolve) => {
    timer = setTimeout(() => {
      aborted = true;
      agent.abort();
      resolve({ kind: "timeout" });
    }, timeoutMs);
    (timer as any).unref?.();
  });
  const done = agent.prompt(message)
    .then(() => ({ kind: "done" as const }))
    .catch((err) => {
      if (aborted) return { kind: "timeout" as const };
      throw err;
    });
  try {
    const result = await Promise.race([done, timeout]);
    if (result.kind === "timeout") await agent.waitForIdle().catch(() => undefined);
    return result;
  } finally {
    if (timer) clearTimeout(timer);
  }
}

function lastAssistantText(agent: Agent): string {
  const messages: any[] = (agent.state.messages ?? []) as any[];
  for (let i = messages.length - 1; i >= 0; i--) {
    const m = messages[i];
    if (m?.role !== "assistant") continue;
    const content = m.content;
    if (typeof content === "string") return content;
    if (Array.isArray(content)) {
      return content.map((c: any) => {
        if (typeof c === "string") return c;
        if (c?.type === "text") return String(c.text ?? "");
        return "";
      }).join("");
    }
  }
  return "";
}

function stubPlan(snapshot: BattleSnapshotV2): BattlePlan {
  const orders: Record<string, string> = {};
  for (const u of snapshot.controlled.units) {
    if (u.hp > 0) orders[u.type] = "前进";
  }
  return {
    orders: orders as never,
    tactic: snapshot.legal_tactics[0]?.name ?? null,
    memory: "stub",
    reasoning: "stub",
  };
}

function buildUserMessage(session: BattleSession, snapshot: BattleSnapshotV2): string {
  const last = snapshot.last_plan;
  const summary = last
    ? JSON.stringify({
        tick: last.tick, orders: last.orders, orders_applied: last.orders_applied,
        orders_rejected: last.orders_rejected, tactic: last.tactic,
        tactic_status: last.tactic_status, reason: last.reason, age_ms: last.age_ms,
      })
    : "（这是第一拍，还没有上一拍计划）";
  return [
    "第 " + session.tick + " 拍，距上拍 " + (last?.age_ms ?? 0) + "ms。战场第 " + snapshot.turn + " 回合，已进行 " + snapshot.elapsed_ms + "ms。",
    "上一拍你的计划与执行结果：" + summary,
    "你的战斗笔记：" + (session.memory || "（空）"),
    "最新态势（JSON）：",
    JSON.stringify(snapshot),
    "只输出 JSON 计划。",
  ].join("\n");
}

function recordTick(
  trace: DecisionTrace | null, session: BattleSession, plan: BattlePlan,
  rejected: BattleValidationRejected[], latency: number,
): void {
  if (!trace) return;
  traceStore.add(trace, "assistant", { text: JSON.stringify(plan), turn: session.tick });
  traceStore.add(trace, "turn", {
    turn: session.tick,
    text: "tick=" + session.tick + " latency=" + latency + "ms rejected=" + rejected.length,
    ok: true,
  });
}

export async function tickBattle(
  session: BattleSession, snapshot: BattleSnapshotV2, opts: BattleOptions,
): Promise<BattleTickResult> {
  if (session.ended) throw new ServiceError(410, "session_ended", "战斗会话已结束");
  if (!session.beginTick()) throw new ServiceError(409, "tick_in_progress", "上一拍尚未结束");

  const t0 = Date.now();
  session.tick += 1;
  session.lastPlanResult = snapshot.last_plan ?? null;

  try {
    if (opts.mode !== "pi") {
      const plan = stubPlan(snapshot);
      session.lastPlan = plan;
      recordTick(session.trace, session, plan, [], Date.now() - t0);
      return {
        tick: session.tick, plan, rejected: [], latency_ms: Date.now() - t0,
      };
    }

    const agent = ensureAgent(session, opts);
    if (!agent) throw new ServiceError(500, "agent_missing", "Agent 未初始化");
    const userMessage = buildUserMessage(session, snapshot);
    if (session.trace) traceStore.add(session.trace, "user", { text: userMessage, turn: session.tick });

    const outcome = await promptWithTimeout(agent, userMessage, TICK_TIMEOUT_MS);
    if (outcome.kind === "timeout") {
      const plan = emptyPlan();
      session.lastPlan = plan;
      if (session.trace) traceStore.add(session.trace, "error", { text: "tick timeout", ok: false, turn: session.tick });
      recordTick(session.trace, session, plan, [], Date.now() - t0);
      return {
        tick: session.tick, plan, rejected: [], latency_ms: Date.now() - t0, timeout: true,
      };
    }

    let plan = emptyPlan();
    let rejected: BattleValidationRejected[] = [];
    try {
      const raw = extractJson(lastAssistantText(agent));
      const checked = validateBattlePlan(raw, snapshot);
      plan = checked.plan;
      rejected = checked.rejected;
    } catch (err) {
      rejected = [{ kind: "order", value: "", reason: "无效 JSON：" + (err as Error).message }];
      if (session.trace) {
        traceStore.add(session.trace, "error", {
          text: "invalid plan: " + (err as Error).message, ok: false, turn: session.tick,
        });
      }
    }

    if (plan.memory && plan.memory.trim() !== "") session.memory = plan.memory.trim().slice(0, 120);
    if (plan.reasoning) plan.reasoning = plan.reasoning.slice(0, 200);
    session.lastPlan = plan;
    recordTick(session.trace, session, plan, rejected, Date.now() - t0);
    return {
      tick: session.tick, plan, rejected, latency_ms: Date.now() - t0,
    };
  } finally {
    session.endTick();
  }
}

export function endBattle(session: BattleSession): void {
  if (!session.finished) session.finish("ended");
  const tr = session.trace;
  if (tr && tr.status === "running") {
    traceStore.finish(tr, {
      status: "ok",
      elapsed_ms: Date.now() - Date.parse(tr.started_at),
      budget_used: { tokens: session.tokens, turns: session.tick, tool_calls: 0 },
    });
  }
  // 不立即 delete：会话保留 ended 标记，/tick 才能回 410；TTL 到期由 battleStore.prune() 清理。
}
```

**Step 4: 跑测试确认通过**

```bash
cd agent-service && node --test test/battle.test.ts
```

Expected: PASS，5 个测试全绿。

**Step 5: 提交**

```bash
git add agent-service/src/battle-agent.ts agent-service/test/battle.test.ts
git commit -m "feat(battle): 白兵战 3 秒异步 tick 决策"
```

---

## Task 4: 校验与 HTTP 路由

**Files:**
- Modify: `agent-service/src/validate.ts`
- Modify: `agent-service/src/server.ts`
- Test: `agent-service/test/server.test.ts`

**Step 1: 写失败测试**

把 `agent-service/test/server.test.ts` 末尾的「白兵战 estimate 路由」测试整段替换为：

```ts
test("白兵战 tick 路由：开场 → tick → end，非法快照 422，结束 410", async () => {
  const open = await fetch(base + "/ai/battle", {
    method: "POST", headers: { "content-type": "text/plain" },
    body: JSON.stringify({
      battle_key: "b12-b31", controlled_actor_id: 12, enemy_actor_id: 31,
      side: "attacker", diffculities: 4,
    }),
  });
  assert.equal(open.status, 200);
  const id = (await open.json() as any).battle_session_id;
  assert.ok(typeof id === "string" && id.length > 0);

  const snap = {
    battle_version: 2, battle_key: "b12-b31", tick: 1, elapsed_ms: 1200,
    diffculities: 4, side: "attacker", controlled_actor_id: 12, enemy_actor_id: 31,
    turn: 1, terrain: { name: "plain", is_city: false },
    controlled: {
      name: "张辽", hp: 90, soldiers: 1200, tactic_point: 10, buffs: [],
      units: [
        { type: "将", hp: 400, count: 1, order: "待机", x: 6, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
      ],
    },
    enemy: {
      name: "高顺", hp: 88, soldiers: 900, tactic_point: 8, buffs: [],
      units: [
        { type: "将", hp: 350, count: 1, order: "待机", x: 12, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
      ],
    },
    legal_tactics: [],
    last_plan: null,
  };

  const tick = await fetch(base + "/ai/battle/" + id + "/tick", {
    method: "POST", headers: { "content-type": "text/plain" }, body: JSON.stringify(snap),
  });
  assert.equal(tick.status, 200);
  const result: any = await tick.json();
  assert.equal(result.tick, 1);
  assert.deepEqual(result.plan.orders, { 将: "前进" });

  const bad = await fetch(base + "/ai/battle/" + id + "/tick", {
    method: "POST", headers: { "content-type": "text/plain" },
    body: JSON.stringify({ ...snap, battle_version: 1 }),
  });
  assert.equal(bad.status, 422);

  const ended = await fetch(base + "/ai/battle/" + id + "/end", { method: "POST" });
  assert.equal(ended.status, 200);

  const after = await fetch(base + "/ai/battle/" + id + "/tick", {
    method: "POST", headers: { "content-type": "text/plain" }, body: JSON.stringify(snap),
  });
  assert.equal(after.status, 410);
});
```

**Step 2: 跑测试确认失败**

```bash
cd agent-service && node --test test/server.test.ts
```

Expected: FAIL，`/ai/battle/:id/tick` 404 或断言失败。

**Step 3: 改 `validate.ts`**

删除 `validateBattleRequest`、`validateBattleResult`、`validateBattleEstimates`，把白兵战段替换为：

```ts
const BATTLE_UNIT_TYPES = ["将", "骑", "象", "弓", "步"];
const BATTLE_ORDERS = ["前进", "待机", "后退"];

export function validateBattleOpenRequest(
  body: unknown,
): import("./types.ts").BattleOpenRequest {
  if (!isObject(body)) throw new ValidationError("bad_json", "body must be a JSON object");
  if (typeof body.battle_key !== "string" || body.battle_key.length === 0) {
    throw new ValidationError("bad_schema", "battle_key required");
  }
  if (typeof body.controlled_actor_id !== "number") {
    throw new ValidationError("bad_schema", "controlled_actor_id required");
  }
  if (typeof body.enemy_actor_id !== "number") {
    throw new ValidationError("bad_schema", "enemy_actor_id required");
  }
  if (body.side !== "attacker" && body.side !== "defender") {
    throw new ValidationError("bad_schema", "side must be attacker|defender");
  }
  if (typeof body.diffculities !== "number") {
    throw new ValidationError("bad_schema", "diffculities must be a number");
  }
  return body as never;
}

function checkBattleUnitV2(u: unknown, label: string): void {
  if (!isObject(u)) throw new ValidationError("bad_schema", label + " must be an object");
  if (!BATTLE_UNIT_TYPES.includes(u.type as string)) {
    throw new ValidationError("bad_schema", "unknown battle unit type: " + String(u.type));
  }
  for (const k of ["hp", "count", "x", "y", "shoot_range", "attack_range", "dist_to_other_main"]) {
    if (typeof u[k] !== "number") {
      throw new ValidationError("bad_schema", label + "." + k + " must be a number");
    }
  }
  if (typeof u.order !== "string" || !BATTLE_ORDERS.includes(u.order)) {
    throw new ValidationError("bad_schema", label + ".order invalid");
  }
  if (typeof u.other_main_in_shoot_range !== "boolean") {
    throw new ValidationError("bad_schema", label + ".other_main_in_shoot_range must be boolean");
  }
}

function checkBattleSideV2(side: unknown, label: string): void {
  if (!isObject(side)) throw new ValidationError("bad_schema", label + " must be an object");
  if (typeof side.name !== "string") throw new ValidationError("bad_schema", label + ".name required");
  for (const k of ["hp", "soldiers", "tactic_point"]) {
    if (typeof side[k] !== "number") throw new ValidationError("bad_schema", label + "." + k + " must be a number");
  }
  if (!Array.isArray(side.buffs)) throw new ValidationError("bad_schema", label + ".buffs must be an array");
  for (const b of side.buffs as unknown[]) {
    if (!isObject(b) || typeof b.name !== "string" || typeof b.turns !== "number") {
      throw new ValidationError("bad_schema", label + ".buffs entries need name and turns");
    }
  }
  if (!Array.isArray(side.units)) throw new ValidationError("bad_schema", label + ".units must be an array");
  for (const u of side.units as unknown[]) checkBattleUnitV2(u, label + ".units[]");
}

export function validateBattleSnapshot(
  body: unknown,
): import("./types.ts").BattleSnapshotV2 {
  if (!isObject(body)) throw new ValidationError("bad_json", "body must be a JSON object");
  if (body.battle_version !== 2) throw new ValidationError("bad_schema", "battle_version must be 2");
  if (typeof body.battle_key !== "string" || body.battle_key.length === 0) {
    throw new ValidationError("bad_schema", "battle_key required");
  }
  if (typeof body.tick !== "number" || body.tick <= 0) {
    throw new ValidationError("bad_schema", "tick must be a positive number");
  }
  if (typeof body.elapsed_ms !== "number") throw new ValidationError("bad_schema", "elapsed_ms must be a number");
  if (typeof body.diffculities !== "number") throw new ValidationError("bad_schema", "diffculities must be a number");
  if (body.side !== "attacker" && body.side !== "defender") {
    throw new ValidationError("bad_schema", "side must be attacker|defender");
  }
  if (typeof body.controlled_actor_id !== "number") {
    throw new ValidationError("bad_schema", "controlled_actor_id required");
  }
  if (typeof body.enemy_actor_id !== "number") {
    throw new ValidationError("bad_schema", "enemy_actor_id required");
  }
  if (typeof body.turn !== "number") throw new ValidationError("bad_schema", "turn must be a number");
  if (!isObject(body.terrain) || typeof body.terrain.name !== "string" || typeof body.terrain.is_city !== "boolean") {
    throw new ValidationError("bad_schema", "terrain needs name and is_city");
  }
  checkBattleSideV2(body.controlled, "controlled");
  checkBattleSideV2(body.enemy, "enemy");
  if (!Array.isArray(body.legal_tactics)) {
    throw new ValidationError("bad_schema", "legal_tactics must be an array");
  }
  for (const t of body.legal_tactics as unknown[]) {
    if (!isObject(t) || typeof t.name !== "string" || typeof t.cost !== "number" ||
        typeof t.rate !== "number" || typeof t.summary !== "string") {
      throw new ValidationError("bad_schema", "legal_tactics entries need name/cost/rate/summary");
    }
  }
  if (body.last_plan !== undefined && body.last_plan !== null) {
    if (!isObject(body.last_plan)) throw new ValidationError("bad_schema", "last_plan must be an object");
  }
  return body as never;
}
```

**Step 4: 改 `server.ts`**

顶部 import 改为：

```ts
import {
  validateTurnRequest, validateToolResult, validateAnswers,
  validateBattleOpenRequest, validateBattleSnapshot, ValidationError,
} from "./validate.ts";
import { startBattle, tickBattle, endBattle } from "./battle-agent.ts";
```

把 `server.ts` 里从 `// ---- 白兵战会话（独立 Agent / 提示词 / 工具） ----` 到 `// ---- 云存档` 之前的整段（`/ai/battle`、`/pending`、`/resume`、`/estimate`、`/result`）替换为：

```ts
      // ---- 白兵战会话：异步 tick ----
      if (url.pathname === "/ai/battle") {
        if (req.method !== "POST") { json(res, 405, { error: "method_not_allowed" }); return; }
        const body = await parseJsonBody(req);
        const request = validateBattleOpenRequest(body);
        const session = startBattle(request, { mode: config.mode, config });
        json(res, 200, { battle_session_id: session.id });
        return;
      }

      if (url.pathname.startsWith("/ai/battle/") && url.pathname.endsWith("/tick")) {
        if (req.method !== "POST") { json(res, 405, { error: "method_not_allowed" }); return; }
        const id = decodeURIComponent(url.pathname.slice("/ai/battle/".length, -"/tick".length));
        const session = battleStore.get(id);
        if (!session) { json(res, 404, { error: "session_not_found" }); return; }
        const body = await parseJsonBody(req);
        let snapshot: ReturnType<typeof validateBattleSnapshot>;
        try {
          snapshot = validateBattleSnapshot(body);
        } catch (err) {
          json(res, 422, { error: "invalid_snapshot", message: err instanceof Error ? err.message : String(err) });
          return;
        }
        if (snapshot.controlled_actor_id !== session.init.controlledActorId ||
            snapshot.enemy_actor_id !== session.init.enemyActorId) {
          json(res, 422, { error: "invalid_snapshot", message: "actor ids do not match session" });
          return;
        }
        const result = await tickBattle(session, snapshot, { mode: config.mode, config });
        json(res, 200, result);
        return;
      }

      if (url.pathname.startsWith("/ai/battle/") && url.pathname.endsWith("/end")) {
        if (req.method !== "POST") { json(res, 405, { error: "method_not_allowed" }); return; }
        const id = decodeURIComponent(url.pathname.slice("/ai/battle/".length, -"/end".length));
        const session = battleStore.get(id);
        if (session) endBattle(session);
        json(res, 200, { ok: true });
        return;
      }
```

注意：`ServiceError` 的 409/410 会被外层 catch 转成对应状态码，无需在路由里单独处理。

改完 `server.ts` 后，删除 `types.ts` 里旧的 `BattleRequest`、`BattleUnit`、`BattleBudget`、`BattlePending`、`BattleResultPayload`，并确认没有残留引用：

```bash
cd agent-service && grep -rn "BattleRequest\|BattleBudget\|BattlePending\|BattleResultPayload" src test --include=*.ts
```

Expected: 无输出。

**Step 5: 跑测试确认通过**

```bash
cd agent-service && node --test test/server.test.ts
```

Expected: PASS；原有 `/ai/turn` 断言全部保留并通过。

**Step 6: 提交**

```bash
git add agent-service/src/validate.ts agent-service/src/server.ts agent-service/test/server.test.ts
git commit -m "feat(battle): 白兵战 tick/end 路由"
```

---

## Task 5: 删除旧工具与旧指令通道

**Files:**
- Delete: `agent-service/src/battle-tools.ts`
- Verify: `agent-service/test/gdscript-refs.test.ts`、`ai-url.test.ts`

**Step 1: 删除文件**

```bash
git rm agent-service/src/battle-tools.ts
```

**Step 2: 静态检查残留引用**

```bash
cd agent-service && grep -rn "battle-tools\\|BATTLE_TOOL_NAMES\\|BATTLE_READ_TOOL_NAMES" src test --include=*.ts
```

Expected: 只剩历史注释或战场 `/ai/turn` 的合法引用；不得再有 `battle-tools` import。

**Step 3: 跑已更新的服务端测试**

```bash
cd agent-service && node --test test/battle-plan.test.ts test/battle-session.test.ts test/battle.test.ts test/server.test.ts test/ai-url.test.ts test/gdscript-refs.test.ts
```

Expected: 全部通过。`battle-gdscript.test.ts` 是 Task 10 的事，这里不跑。

**Step 4: 提交**

```bash
git add agent-service/src/battle-tools.ts
git commit -m "chore(battle): 移除白兵战指令队列与工具集"
```

---

## Task 6: 白兵战独立 HTTP 客户端

**Files:**
- Create: `bwdl/packed/sgz_script/battle/AI/BattleHttpClient.gd`

**Step 1: 写文件**

```gdscript
# 白兵战专用异步 HTTP 客户端。
# 与 war/AI/AIHttpClient.gd 完全独立：不排队、不共享实例，避免影响战场 Agent。
extends Resource

var _http: HTTPRequest = null
var _owner: Object = null
var _owner_method: String = ""
var _pending: bool = false

func _init() -> void:
	# Global.load_script 命中缓存会再次调用 _init()；有请求在飞时保持原状。
	if _pending:
		return
	_owner = null
	_owner_method = ""
	return

func is_pending() -> bool:
	return _pending

func post(url: String, body_text: String, owner: Object, method: String, timeout_sec: int = 25) -> bool:
	if _pending:
		return false
	if not _ensure_http(timeout_sec):
		return false
	_owner = owner
	_owner_method = method
	_pending = true
	DataManager.ai_debug_log("B_HTTP POST " + url + " body=" + body_text.substr(0, 200), true)
	var err = _http.request(
		url,
		PoolStringArray(["Content-Type: text/plain; charset=utf-8"]),
		true,
		HTTPClient.METHOD_POST,
		body_text
	)
	if err != OK:
		_pending = false
		_owner = null
		_owner_method = ""
		DataManager.ai_debug_log("B_HTTP start failed err={0}".format([err]), true)
		return false
	return true

func cancel() -> void:
	if _http != null:
		_http.cancel_request()
	_pending = false
	_owner = null
	_owner_method = ""
	return

func _ensure_http(timeout_sec: int) -> bool:
	if _http == null:
		_http = HTTPRequest.new()
		_http.use_threads = false
		_http.connect("request_completed", self, "_on_completed")
		SceneManager.add_child(_http)
	if not _http.is_inside_tree():
		if _http.get_parent() != null:
			_http.get_parent().remove_child(_http)
		SceneManager.add_child(_http)
	if not _http.is_inside_tree():
		return false
	_http.timeout = timeout_sec
	return true

func _on_completed(result: int, response_code: int, _headers: PoolStringArray, body: PoolByteArray) -> void:
	if not _pending:
		return
	_pending = false
	var owner = _owner
	var method = _owner_method
	_owner = null
	_owner_method = ""
	DataManager.ai_debug_log("B_HTTP DONE result={0} code={1}".format([result, response_code]), true)
	if owner != null and is_instance_valid(owner) and owner.has_method(method):
		owner.call(method, result, response_code, body)
	return
```

**Step 2: 语法检查**

```bash
make check
```

Expected: 无脚本解析错误。

**Step 3: 提交**

```bash
git add bwdl/packed/sgz_script/battle/AI/BattleHttpClient.gd
git commit -m "feat(battle): 新增白兵战独立 HTTP 客户端"
```

---

## Task 7: 快照 v2 与计策摘要

**Files:**
- Modify: `bwdl/packed/sgz_script/battle/AI/BattleProjection.gd`（整文件重写）
- Modify: `bwdl/packed/sgz_script/battle/AI/TacticProjection.gd`（只加 `summary`）

**Step 1: 重写 `BattleProjection.gd`**

```gdscript
# 白兵战态势投影 v2：一场战斗每拍一份快照。
# 只读：不改战局、不触发技能、不消耗战术值。
extends Resource

const UNIT_TYPES = ["将", "骑", "象", "弓", "步"]

var _tactics = null

func _init() -> void:
	_tactics = null
	return

func _ensure_tactics():
	if _tactics == null:
		_tactics = Global.load_script(DataManager.mod_path + "sgz_script/battle/AI/TacticProjection.gd")
	return _tactics

func build(bf, actorId: int, tick: int, lastPlan, elapsedMs: int) -> Dictionary:
	if bf == null:
		return {}
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return {}
	var enemy = wa.get_battle_enemy_war_actor()
	if enemy == null:
		return {}
	var enemyId = enemy.actorId
	var payload = {
		"battle_version": 2,
		"battle_key": "b{0}-b{1}".format([bf.get_attacker_id(), bf.get_defender_id()]),
		"tick": int(tick),
		"elapsed_ms": int(elapsedMs),
		"diffculities": DataManager.diffculities,
		"side": "attacker" if actorId == bf.get_attacker_id() else "defender",
		"controlled_actor_id": actorId,
		"enemy_actor_id": enemyId,
		"turn": int(bf.turns()),
		"terrain": _terrain(bf),
		"controlled": _side_state(bf, actorId, enemyId),
		"enemy": _side_state(bf, enemyId, actorId),
		"legal_tactics": _legal_tactics(wa),
	}
	if lastPlan != null:
		payload["last_plan"] = lastPlan
	return payload

func _terrain(bf) -> Dictionary:
	return {
		"name": str(bf.get_terrian()),
		"is_city": bool(bf.is_terrian_city()),
	}

func _side_state(bf, actorId: int, otherId: int) -> Dictionary:
	var wa = DataManager.get_war_actor(actorId)
	var actor = wa.actor() if wa != null else null
	var otherMain = _main_unit(bf, otherId)
	var otherPos = otherMain.unit_position if otherMain != null else Vector2(-10, -10)
	var unitTypes = bf.get_defender_unit_types()
	if actorId == bf.get_attacker_id():
		unitTypes = bf.get_attacker_unit_types()
	var states = bf.get_units_states(actorId)
	var units = []
	for ut in unitTypes:
		units.append(_unit_info(bf, actorId, str(ut), otherPos, states))
	return {
		"name": actor.get_name() if actor != null else "",
		"hp": int(actor.get_hp()) if actor != null else 0,
		"soldiers": int(bf.get_battle_sodiers(actorId)),
		"tactic_point": int(wa.battle_tactic_point) if wa != null else 0,
		"buffs": _buffs(wa),
		"units": units,
	}

func _main_unit(bf, actorId: int):
	for bu in DataManager.battle_units:
		if bu == null or bu.disabled:
			continue
		if bu.leaderId != actorId:
			continue
		if bu.get_unit_type() == "将":
			return bu
	return null

func _unit_info(bf, actorId: int, ut: String, otherPos: Vector2, states: Dictionary) -> Dictionary:
	var count = 0
	var best = null
	var bestDist = 999999
	for bu in DataManager.battle_units:
		if bu == null or bu.disabled:
			continue
		if bu.leaderId != actorId or bu.get_unit_type() != ut:
			continue
		count += 1
		var d = Global.get_distance(bu.unit_position, otherPos)
		if d < bestDist:
			bestDist = d
			best = bu
	var pos = best.unit_position if best != null else Vector2(-10, -10)
	var shootRange = int(best.get_shoot_distance()) if best != null else 0
	var attackRange = int(best.get_attack_distance()) if best != null else 1
	var dist = Global.get_distance(pos, otherPos) if best != null else 999
	return {
		"type": ut,
		"hp": int(DataManager.battle_unit_type_hp(actorId, ut)),
		"count": count,
		"order": str(states[ut]) if states.has(ut) else "前进",
		"x": int(pos.x),
		"y": int(pos.y),
		"shoot_range": shootRange,
		"attack_range": attackRange,
		"dist_to_other_main": dist,
		"other_main_in_shoot_range": bool(best != null and shootRange > 0 and dist <= shootRange),
	}

func _buffs(wa) -> Array:
	var ret = []
	if wa == null:
		return ret
	for name in wa.dic_buffs.keys():
		var b = wa.dic_buffs[name]
		var turns = int(b.get("回合数", 0))
		if turns <= 0:
			continue
		var info = StaticManager.get_buff(str(name))
		if info == null or info.get_scene() != "小战场":
			continue
		ret.append({"name": str(name), "turns": turns})
	return ret

func _legal_tactics(wa) -> Array:
	var ret = []
	if wa == null:
		return ret
	var tp = _ensure_tactics()
	if tp == null:
		return ret
	for name in StaticManager.TACTICS.keys():
		var est = tp.estimate(wa.actorId, str(name))
		if typeof(est) != TYPE_DICTIONARY or not est.get("available", false):
			continue
		ret.append({
			"name": str(name),
			"cost": int(est.get("cost", 0)),
			"rate": int(est.get("rate", 100)),
			"summary": str(tp.summary(est)),
		})
	return ret
```

**Step 2: 在 `TacticProjection.gd` 末尾加 `summary`**

在 `func estimate(...)` 之后、文件末尾之前插入：

```gdscript
# 一行摘要：给快照用，避免把完整 impacts 塞进每拍请求。
func summary(est: Dictionary) -> String:
	var tactic = str(est.get("tactic", ""))
	var cost = int(est.get("cost", 0))
	var rate = int(est.get("rate", 100))
	match tactic:
		"咒缚":
			var turns = 3
			for row in est.get("impacts", []):
				if typeof(row) == TYPE_DICTIONARY and row.get("kind") == "buff":
					turns = int(row.get("turns", 3))
			return "命中率 {0}%；敌主将定止 {1} 回合".format([rate, turns])
		"挑衅":
			return "接受率 {0}%；拒绝则敌士气 -4、胆 -10".format([rate])
		"强弩":
			var n = 0
			for row in est.get("impacts", []):
				if typeof(row) != TYPE_DICTIONARY or row.get("kind") != "buff":
					continue
				for u in row.get("units", []):
					if typeof(u) == TYPE_DICTIONARY and u.get("benefits", false):
						n += 1
			return "射程 +2、射箭必发；{0} 个弓兵受益".format([n])
		"士气向上":
			return "全体攻击 +5~9、士兵防御 ×1.2"
		"火矢":
			return "射箭攻击 +9~15、无视 1/3 防御"
	return "消耗 {0}，命中率 {1}%".format([cost, rate])
```

**Step 3: 语法检查**

```bash
make check
```

Expected: 无解析错误。

**Step 4: 提交**

```bash
git add bwdl/packed/sgz_script/battle/AI/BattleProjection.gd bwdl/packed/sgz_script/battle/AI/TacticProjection.gd
git commit -m "feat(battle): 白兵战态势投影 v2"
```

---

## Task 8: 3 秒异步状态机

**Files:**
- Modify: `bwdl/packed/sgz_script/battle/AI/BattleAgent.gd`（整文件重写）

**Step 1: 重写 `BattleAgent.gd`**

```gdscript
# 白兵战异步 AI：每 3 秒一拍，快照进、计划出。
# 请求周期完全不进 FlowManager；只把「用计」排队到安全点执行。
extends Resource

const TICK_INTERVAL_MS := 3000
const PAUSED_TICK_INTERVAL_MS := 10000
const MAX_ERRORS := 3
const TACTIC_TTL_MS := 8000
const REQUEST_TIMEOUT_SEC := 25
const CURRENT_STEP_KEY := "白兵战-当前步骤"

var _projection = null
var _tactics = null
var _http = null

var _session_id := ""
var _actor_id := -1
var _tick := 0
var _in_flight := false
var _opening := false
var _local := false
var _errors := 0
var _next_tick_at := 0
var _started_ms := 0
var _last_plan = null
var _last_plan_at := 0
var _memory := ""
var _tactic_queue = null
var _tactic_busy := false
var _tactic_sent_at := 0
var _request_kind := ""

func _init() -> void:
	# Global.load_script 命中缓存会再次调用 _init()；已有会话时保持原状。
	if _actor_id >= 0:
		return
	_reset()
	return

func _reset() -> void:
	_session_id = ""
	_actor_id = -1
	_tick = 0
	_in_flight = false
	_opening = false
	_local = false
	_errors = 0
	_next_tick_at = 0
	_started_ms = 0
	_last_plan = null
	_last_plan_at = 0
	_memory = ""
	_tactic_queue = null
	_tactic_busy = false
	_tactic_sent_at = 0
	_request_kind = ""
	return

func _ensure() -> void:
	if _projection == null:
		_projection = Global.load_script(DataManager.mod_path + "sgz_script/battle/AI/BattleProjection.gd")
	if _tactics == null:
		_tactics = Global.load_script(DataManager.mod_path + "sgz_script/battle/AI/TacticProjection.gd")
	if _http == null:
		_http = Global.load_script(DataManager.mod_path + "sgz_script/battle/AI/BattleHttpClient.gd")
	return

func _base() -> String:
	return DataManager.resolve_ai_agent_url("/ai/battle")

func attach(bf) -> void:
	if _actor_id >= 0 or bf == null:
		return
	for wa in [bf.get_attacker(), bf.get_defender()]:
		if wa == null or wa.disabled:
			continue
		if wa.get_controlNo() < 0:
			_actor_id = wa.actorId
			_started_ms = OS.get_ticks_msec()
			DataManager.ai_debug_log("B_ATTACH actor={0}".format([_actor_id]), true)
			return
	_local = true
	return

func get_actor_id() -> int:
	return _actor_id

func get_session_id() -> String:
	return _session_id

func is_local() -> bool:
	return _local

func is_managed(actorId: int) -> bool:
	return _actor_id >= 0 and actorId == _actor_id

func is_busy() -> bool:
	return _in_flight or _opening

func tick() -> void:
	var bf = DataManager.get_current_battle_fight()
	if bf == null or not DataManager.battle_run:
		end_battle()
		return
	if _actor_id < 0:
		attach(bf)
	if _local or _actor_id < 0:
		return
	_ensure()
	_try_execute_tactic(bf)
	if _in_flight or _opening:
		return
	var now = OS.get_ticks_msec()
	if now < _next_tick_at:
		return
	if _session_id == "":
		_open(bf)
		return
	_send_tick(bf)
	return

func _enemy_id(bf) -> int:
	var wa = DataManager.get_war_actor(_actor_id)
	if wa == null:
		return -1
	var enemy = wa.get_battle_enemy_war_actor()
	return enemy.actorId if enemy != null else -1

func _open(bf) -> void:
	var payload = {
		"battle_key": "b{0}-b{1}".format([bf.get_attacker_id(), bf.get_defender_id()]),
		"controlled_actor_id": _actor_id,
		"enemy_actor_id": _enemy_id(bf),
		"side": "attacker" if _actor_id == bf.get_attacker_id() else "defender",
		"diffculities": DataManager.diffculities,
	}
	_opening = true
	_request_kind = "open"
	var ok = _http.post(_base(), to_json(payload), self, "_on_open", REQUEST_TIMEOUT_SEC)
	if not ok:
		_opening = false
		_request_kind = ""
		_fail("open_post")
	return

func _on_open(result: int, code: int, body: PoolByteArray) -> void:
	if _request_kind != "open":
		return
	_opening = false
	_request_kind = ""
	if result != 0 or code != 200:
		_fail("open_http_{0}".format([code]))
		return
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY or not reply.has("battle_session_id"):
		_fail("open_bad_json")
		return
	_session_id = str(reply["battle_session_id"])
	_errors = 0
	_next_tick_at = OS.get_ticks_msec()
	DataManager.ai_debug_log("B_OPEN sid=" + _session_id, true)
	DataManager.game_trace("[BattleAI] session " + _session_id)
	return

func _send_tick(bf) -> void:
	_tick += 1
	if _last_plan != null:
		_last_plan["age_ms"] = OS.get_ticks_msec() - _last_plan_at
	var snapshot = _projection.build(bf, _actor_id, _tick, _last_plan, OS.get_ticks_msec() - _started_ms)
	if snapshot.empty():
		end_battle()
		return
	_in_flight = true
	_request_kind = "tick"
	var url = "{0}/{1}/tick".format([_base(), _session_id])
	var ok = _http.post(url, to_json(snapshot), self, "_on_tick", REQUEST_TIMEOUT_SEC)
	if not ok:
		_in_flight = false
		_request_kind = ""
		_fail("tick_post")
	return

func _on_tick(result: int, code: int, body: PoolByteArray) -> void:
	if _request_kind != "tick":
		return
	_in_flight = false
	_request_kind = ""
	if result != 0 or code == 0:
		_fail("tick_transport")
		return
	if code == 409:
		_next_tick_at = OS.get_ticks_msec() + _interval()
		return
	if code == 410:
		_session_id = ""
		_errors += 1
		_next_tick_at = OS.get_ticks_msec()
		if _errors >= MAX_ERRORS:
			_fallback("session_ended")
		return
	if code != 200:
		_fail("tick_http_{0}".format([code]))
		return
	var reply = parse_json(body.get_string_from_utf8())
	if typeof(reply) != TYPE_DICTIONARY or typeof(reply.get("plan")) != TYPE_DICTIONARY:
		_errors = 0
		_next_tick_at = OS.get_ticks_msec() + _interval()
		return
	if bool(reply.get("timeout", false)):
		_errors += 1
	else:
		_errors = 0
	_tick = int(reply.get("tick", _tick))
	_apply_plan(reply["plan"], reply.get("rejected", []), _tick)
	_next_tick_at = OS.get_ticks_msec() + _interval()
	if _errors >= MAX_ERRORS:
		_fallback("tick_timeout")
	return

func _apply_plan(plan: Dictionary, rejected, plan_tick: int) -> void:
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	var orders = plan.get("orders", {})
	if typeof(orders) != TYPE_DICTIONARY:
		orders = {}
	var diff = {}
	var applied = []
	var local_rejected = []
	for unit in orders.keys():
		var order = str(orders[unit])
		if not str(unit) in ["将", "骑", "象", "弓", "步"] or not order in ["前进", "待机", "后退"]:
			local_rejected.append({"unit": str(unit), "reason": "非法兵种或命令"})
			continue
		if DataManager.battle_unit_type_hp(_actor_id, str(unit)) <= 0:
			local_rejected.append({"unit": str(unit), "reason": "该兵种已灭"})
			continue
		if bf.get_units_state(_actor_id, str(unit)) != order:
			diff[unit] = order
			applied.append(str(unit))
	if typeof(rejected) == TYPE_ARRAY:
		for r in rejected:
			if typeof(r) == TYPE_DICTIONARY:
				local_rejected.append({
					"unit": str(r.get("value", r.get("unit", ""))),
					"reason": str(r.get("reason", "")),
				})
	if not diff.empty():
		bf.set_unit_state(_actor_id, diff)
	_last_plan = {
		"tick": plan_tick,
		"orders": orders,
		"orders_applied": applied,
		"orders_rejected": local_rejected,
		"tactic": null,
		"tactic_status": "none",
		"reason": "",
		"age_ms": 0,
	}
	var tactic = ""
	if plan.get("tactic") != null:
		tactic = str(plan.get("tactic", "")).strip_edges()
	if tactic != "":
		_queue_tactic(tactic, plan_tick)
	var mem = plan.get("memory", "")
	if typeof(mem) == TYPE_STRING and str(mem).strip_edges() != "":
		_memory = str(mem).strip_edges().substr(0, 120)
	_last_plan_at = OS.get_ticks_msec()
	DataManager.ai_debug_log("B_PLAN tick={0} orders={1} tactic={2}".format([
		plan_tick, to_json(orders), tactic,
	]), true)
	return

func _queue_tactic(tactic: String, plan_tick: int) -> void:
	_last_plan["tactic"] = tactic
	if _tactic_queue != null:
		_last_plan["tactic_status"] = "pending"
		_last_plan["reason"] = "上一计策还在队列中"
		return
	var wa = DataManager.get_war_actor(_actor_id)
	if wa == null:
		_reject_tactic(tactic, "取不到武将")
		return
	if not StaticManager.TACTICS.has(tactic):
		_reject_tactic(tactic, "不是白兵战战术")
		return
	var iTactic = Global.load_script(DataManager.mod_path + "sgz_script/battle/ITactic.gd")
	var cost = iTactic.get_tactic_cost(wa, tactic)
	if cost > int(wa.battle_tactic_point):
		_reject_tactic(tactic, "战术值不足")
		return
	if int(wa.get_buff(tactic)["回合数"]) > 0:
		_reject_tactic(tactic, "同名战术已生效")
		return
	_tactic_queue = {
		"tactic": tactic,
		"expires_at": OS.get_ticks_msec() + TACTIC_TTL_MS,
		"plan_tick": plan_tick,
	}
	_last_plan["tactic_status"] = "pending"
	return

func _reject_tactic(tactic: String, reason: String) -> void:
	_last_plan["tactic"] = tactic
	_last_plan["tactic_status"] = "rejected"
	_last_plan["reason"] = reason
	return

func _try_execute_tactic(bf) -> void:
	if _tactic_queue == null:
		return
	if _tactic_busy:
		if OS.get_ticks_msec() - _tactic_sent_at > 10000:
			_tactic_busy = false
		return
	if OS.get_ticks_msec() > int(_tactic_queue["expires_at"]):
		_last_plan["tactic_status"] = "rejected"
		_last_plan["reason"] = "用计排队超时"
		_tactic_queue = null
		return
	if FlowManager.has_task():
		return
	if not int(DataManager.get_env_int(CURRENT_STEP_KEY, 0)) in [4, 5, 6, 7]:
		return
	var scene = SceneManager.current_scene()
	if scene != null:
		if scene.battle_state.visible:
			return
		if scene.actor_dialog != null and scene.actor_dialog.visible:
			return
	if LoadControl.get_view_model() >= 0:
		return
	var tactic = str(_tactic_queue["tactic"])
	var wa = DataManager.get_war_actor(_actor_id)
	if wa == null:
		_last_plan["tactic_status"] = "rejected"
		_last_plan["reason"] = "取不到武将"
		_tactic_queue = null
		return
	if int(wa.get_buff(tactic)["回合数"]) > 0:
		_last_plan["tactic_status"] = "rejected"
		_last_plan["reason"] = "同名战术已生效"
		_tactic_queue = null
		return
	DataManager.set_env("当前武将", _actor_id)
	DataManager.set_env("值", tactic)
	_tactic_busy = true
	_tactic_sent_at = OS.get_ticks_msec()
	_tactic_queue = null
	_last_plan["tactic_status"] = "applied"
	_last_plan["reason"] = ""
	FlowManager.add_flow("before_AI_tactic")
	DataManager.ai_debug_log("B_TACTIC " + tactic, true)
	return

func _interval() -> int:
	var scene = SceneManager.current_scene()
	if scene != null:
		if scene.battle_state.visible:
			return PAUSED_TICK_INTERVAL_MS
		if scene.actor_dialog != null and scene.actor_dialog.visible:
			return PAUSED_TICK_INTERVAL_MS
	if LoadControl.get_view_model() >= 0:
		return PAUSED_TICK_INTERVAL_MS
	return TICK_INTERVAL_MS

func _fail(reason: String) -> void:
	_errors += 1
	_next_tick_at = OS.get_ticks_msec() + _interval()
	DataManager.ai_debug_log("B_TICK FAIL {0} errors={1}".format([reason, _errors]), true)
	if _errors >= MAX_ERRORS:
		_fallback(reason)
	return

func _fallback(reason: String) -> void:
	_local = true
	_in_flight = false
	_opening = false
	_tactic_queue = null
	_tactic_busy = false
	DataManager.ai_debug_log("B_FALLBACK reason=" + reason, true)
	DataManager.game_trace("[BattleAI] fallback to local: " + reason)
	return

func _on_ended(_result: int, _code: int, _body: PoolByteArray) -> void:
	return

func end_battle() -> void:
	if _http != null:
		_local = true
		_http.cancel()
	if _session_id != "" and _http != null:
		var url = "{0}/{1}/end".format([_base(), _session_id])
		_http.post(url, "{}", self, "_on_ended", REQUEST_TIMEOUT_SEC)
	_reset()
	return
```

**Step 2: 语法检查**

```bash
make check
```

Expected: 无解析错误。

**Step 3: 提交**

```bash
git add bwdl/packed/sgz_script/battle/AI/BattleAgent.gd
git commit -m "feat(battle): 白兵战异步决策状态机"
```

---

## Task 9: 接线 Battle_Auto_Run 与步骤 7

**Files:**
- Modify: `bwdl/packed/sgz_script/battle/Battle_Auto_Run.gd`

**Step 1: 删除 AI flow 绑定**

在 `_init()` 里删除以下 5 行（保留 `battle_agent` 变量的加载）：

```gdscript
		FlowManager.bind_import_flow("battle_ai_decide", self)
		FlowManager.bind_import_flow("battle_ai_poll_again", self)
		FlowManager.bind_import_flow("battle_ai_after_flush", self)
		FlowManager.bind_import_flow("battle_ai_turn_ready", self)
		FlowManager.bind_import_flow("battle_ai_fallback", self)
```

**Step 2: `battle_run_start` 加 attach**

在 `bf.ready_to_start()` 之后插入：

```gdscript
	if battle_agent != null:
		battle_agent.attach(bf)
```

**Step 3: `_process` 换成 tick**

把：

```gdscript
	# 白兵战是准实时的：玩家随时可以暂停调兵种、用计，AI 必须并行推进。
	# 因此 AI 的轮询/回传不挂在 flow 队列与步骤机上，每帧单独驱动一次
	# （只发 HTTP、只读状态，不改战局；真正执行指令仍走 flow，受下面的等待条件约束）。
	_battle_ai_tick()
```

替换为：

```gdscript
	# 白兵战是准实时的：AI 的请求周期不挂在 flow 上，每帧单独推进。
	if battle_agent != null:
		battle_agent.tick()
```

**Step 4: 步骤 7 拆分**

把 `match currentStep:` 的 `7:` 分支整段替换为：

```gdscript
		7:#AI行为
			for wa in [bf.get_attacker(), bf.get_defender()]:
				if wa == null or wa.disabled:
					continue
				if wa.get_controlNo() >= 0:
					continue
				#玩家被包围不开放投降
				if ai_control.think_about_surrend(wa.actorId):
					set_next_step(6)
					return;#投降
				var managed = battle_agent != null \
					and battle_agent.is_managed(wa.actorId) \
					and not battle_agent.is_local()
				if not managed:
					#前进后退状态更改
					var changed = ai_control.think_about_order(wa.actorId)
					bf.set_unit_state(wa.actorId, changed)
				# 尝试发动主动技（不交给 LLM）
				if ai_control.think_about_active_skill(wa.actorId):
					FlowManager.add_flow("wait_AI_active_skill")
					wait_for_AI_active_skill()
					return
				if managed:
					continue
				var considerTactic = false
				# 检查敌人状态
				var enemy = wa.get_battle_enemy_war_actor()
				if enemy == null:
					continue
				var enemyChoice = bf.get_units_state(enemy.actorId, "将")
				if DataManager.diffculities >= 3 \
					and enemyChoice == "后退" \
					and wa.actorId == bf.get_defender_id():
					# 究极守方，攻方后退，尝试战术
					considerTactic = true
				elif bf.turns() > 1:
					considerTactic = true
				if considerTactic and ai_control.think_about_tactic(wa.actorId):
					DataManager.common_variable["当前武将"] = wa.actorId
					FlowManager.add_flow("before_AI_tactic")
					return
			set_next_step(8)
```

**Step 5: 删除旧编排函数**

删除 `Battle_Auto_Run.gd` 里从 `# 修改：AI Agent 接入（白兵战）的编排` 到 `func battle_ai_fallback()` 结束的整段，包括：

- `battle_ai_step`
- `battle_ai_turn_ready`
- `_battle_ai_tick`
- `battle_ai_poll_again`
- `battle_ai_after_flush`
- `battle_ai_decide`
- `battle_ai_fallback`

同时删除 `var _ai_step_sig = ""`。

**Step 6: 结束收尾**

在 `battle_over()` 里 `bf.battle_over()` 之前插入：

```gdscript
	if battle_agent != null:
		battle_agent.end_battle()
```

在 `check_battle_need_over()` 里，`var loser = bf.get_loser()` 之后的「无失败者」分支和「有失败者」分支都插入一次：

```gdscript
	if battle_agent != null:
		battle_agent.end_battle()
```

（`end_battle()` 可重复调用，第二次会因 `_session_id == ""` 直接返回。）

**Step 7: 语法检查 + 静态引用检查**

```bash
make check
cd agent-service && node --test test/ai-url.test.ts test/gdscript-refs.test.ts
```

Expected: `make check` 无解析错误；`ai-url.test.ts` 仍断言 `BattleAgent.gd` 含 `resolve_ai_agent_url("/ai/battle")`；`gdscript-refs.test.ts` 不引用已删除函数。

**Step 8: 提交**

```bash
git add bwdl/packed/sgz_script/battle/Battle_Auto_Run.gd
git commit -m "refactor(battle): 白兵战接线步骤 7 与结束收尾"
```

---

## Task 10: GDScript 契约 harness

**Files:**
- Modify: `agent-service/gdharness/battle_ai/project.godot`
- Modify: `agent-service/gdharness/battle_ai/Main.gd`
- Modify: `agent-service/gdharness/battle_ai/stubs/*.gd`
- Create: `agent-service/gdharness/battle_ai/stubs/FakeBattleUnit.gd`
- Create: `agent-service/gdharness/battle_ai/stubs/LoadControlStub.gd`
- Create: `agent-service/gdharness/battle_ai/stubs/FakeScene.gd`
- Modify: `agent-service/test/battle-gdscript.test.ts`

**Step 1: 扩展 `project.godot`**

在 `[autoload]` 末尾加：

```ini
LoadControl="*res://stubs/LoadControlStub.gd"
```

**Step 2: 新增三个 stub**

`stubs/FakeBattleUnit.gd`：

```gdscript
extends Resource

var leaderId = 12
var disabled = false
var unit_position = Vector2(0, 0)
var _type = "将"
var _hp = 100
var _shoot = 0
var _attack = 1

func get_unit_type(): return _type
func get_hp(include_disabled: bool = false): return _hp
func get_shoot_distance(): return _shoot
func get_attack_distance(): return _attack
```

`stubs/LoadControlStub.gd`：

```gdscript
extends Node

func get_view_model() -> int:
	return -1
```

`stubs/FakeScene.gd`：

```gdscript
extends Node

var SCENE_ID = 30000
var bgm = false
var battle_state = null
var actor_dialog = null

func _init() -> void:
	battle_state = Control.new()
	battle_state.visible = false
	actor_dialog = Control.new()
	actor_dialog.visible = false
	return
```

**Step 3: 扩展 `DataManagerStub.gd`**

```gdscript
extends Node

var diffculities = 4
var ai_agent_mode = true
var mod_path = ""
var battle = null
var war_actor = null
var war_actor_enemy = null
var battle_units = []
var battle_run = true
var env = {}
var traces = []

func get_current_battle_fight(): return battle
func get_war_actor(id):
	if war_actor != null and id == war_actor.actorId:
		return war_actor
	if war_actor_enemy != null and id == war_actor_enemy.actorId:
		return war_actor_enemy
	return null
func game_trace(msg): traces.append(str(msg))
func ai_debug_log(msg: String, always: bool = false): pass
func set_env(k, v): env[k] = v
func unset_env(k): env.erase(k)
func get_env_int(k, d=0): return int(env.get(k, d))
func get_env_str(k, d=""): return str(env.get(k, d))

func battle_unit_type_hp(actorId, type_name):
	var total = 0
	for bu in battle_units:
		if bu.disabled or bu.leaderId != actorId or bu.get_unit_type() != type_name:
			continue
		total += bu.get_hp()
	return total

func get_battle_unit_by_position(pos):
	for bu in battle_units:
		if bu.unit_position == pos:
			return bu
	return null

var ai_agent_base_url = ""
func resolve_ai_agent_url(path):
	var base = ai_agent_base_url
	if base == "":
		base = "http://127.0.0.1:8060"
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	return base + path
```

**Step 4: 扩展 `GlobalStub.gd`**

```gdscript
extends Node

var iTactic = null

func load_script(path):
	var file = str(path).get_file()
	if file == "ITactic.gd":
		return iTactic
	var p = "res://" + file
	if ResourceLoader.exists(p):
		return load(p).new()
	return null

func get_distance(a, b) -> int:
	return int(abs(a.x - b.x)) + int(abs(a.y - b.y))
```

**Step 5: 扩展 `StaticManagerStub.gd`**

```gdscript
extends Node

# 可变：orders 场景用空表，tactic 场景由 Main.gd 注入「强弩」
var TACTICS = {}

func get_buff(_name):
	return BuffInfo.new()

class BuffInfo:
	func get_scene(): return "小战场"
```

**Step 6: `FlowManagerStub.gd` 加 `has_task()`**

```gdscript
extends Node

var flows = []

func bind_import_flow(name, obj): pass
func add_flow(flow, instant=false): flows.append(str(flow))
func has_task(): return false
```

**Step 7: `SceneManagerStub.gd` 加 `current_scene()`**

```gdscript
extends Node

var tips = ""
var _scene = null

func show_special_tips(msg): tips = str(msg)
func reset_tips(): tips = ""

func current_scene():
	if _scene == null:
		_scene = load("res://stubs/FakeScene.gd").new()
	return _scene
```

**Step 8: 扩展 `FakeBattleFight.gd`**

```gdscript
extends Resource

var order_calls = []
var _states = {"将": "待机", "骑": "待机", "弓": "待机", "步": "待机"}
var _turn = 1

func get_attacker_id(): return 12
func get_defender_id(): return 31
func get_attacker(): return DataManager.get_war_actor(12)
func get_defender(): return DataManager.get_war_actor(31)
func turns(): return _turn
func get_terrian(): return "plain"
func is_terrian_city(): return false

func get_attacker_unit_types(): return ["将", "骑", "弓", "步"]
func get_defender_unit_types(): return ["将", "弓"]
func get_battle_sodiers(actorId, a=false, b=true): return 1200 if actorId == 12 else 900
func get_units_states(actorId): return _states.duplicate(true)
func get_units_state(actorId, ut): return str(_states.get(ut, "前进"))

func set_unit_state(actorId, setting):
	for k in setting:
		_states[k] = setting[k]
		order_calls.append({"actor": actorId, "unit": k, "order": setting[k]})
	return

func battle_units(actorId):
	var ret = []
	for bu in DataManager.battle_units:
		if bu.leaderId == actorId and not bu.disabled:
			ret.append(bu)
	return ret

func bump_turn(): _turn += 1
```

**Step 9: 扩展 `FakeWarActor.gd`、`FakeActorInfo.gd` 与 `ITacticStub.gd`**

`FakeWarActor.gd`：

```gdscript
extends Resource

var actorId = 12
var battle_tactic_point = 12
var dic_buffs = {}
var disabled = false
var _enemy = null
var _info = null

func get_battle_enemy_war_actor(): return _enemy
func actor(): return _info
func get_controlNo(): return -1
func get_buff(name): return dic_buffs.get(name, {"回合数": 0})
func can_use_tactic(): return true
func continuous_tactic_on(_basicOnly=false): return false
func get_solo_accept_rate(_from): return 0
```

`FakeActorInfo.gd`：

```gdscript
extends Node

func get_name(): return "张辽"
func get_hp(): return 90
func get_equip_feature_total(_name): return 0
func get_equip_feature_max(_name): return 0
```

`ITacticStub.gd` 整文件替换为（补上 `TacticProjection.estimate` 会调用、但原 stub 缺的两个方法）：

```gdscript
extends Resource

const COSTS = {"咒缚": 3, "挑衅": 5, "强弩": 7, "士气向上": 8, "火矢": 10}

func get_tactic_cost(wa, tactic):
	if COSTS.has(tactic):
		return COSTS[tactic]
	return 0

func get_tactic_description(_actorId, tactic):
	return tactic

func get_stop_tactic_rate(_actorId):
	return 50
```

**Step 10: 重写 `Main.gd`**

```gdscript
extends Node

var _agent = null
var _bf = null
var _done = false
var _printed_open = false
var _scenario = "orders"

func _ready():
	_scenario = OS.get_environment("K3G_BATTLE_SCENARIO")
	if _scenario == "":
		_scenario = "orders"
	if _scenario == "tactic":
		StaticManager.TACTICS = {"强弩": {"消耗": 7}}
		DataManager.env["白兵战-当前步骤"] = 4

	var BF = load("res://stubs/FakeBattleFight.gd")
	var WA = load("res://stubs/FakeWarActor.gd")
	var Info = load("res://stubs/FakeActorInfo.gd")
	var BU = load("res://stubs/FakeBattleUnit.gd")

	_bf = BF.new()
	var mine = WA.new(); mine.actorId = 12; mine._info = Info.new()
	var foe = WA.new(); foe.actorId = 31; foe._info = Info.new(); foe._enemy = mine
	mine._enemy = foe
	DataManager.war_actor = mine
	DataManager.war_actor_enemy = foe
	DataManager.battle = _bf
	DataManager.battle_run = true
	Global.iTactic = load("res://stubs/ITacticStub.gd").new()

	DataManager.battle_units = []
	var specs = [
		{"id": 12, "type": "将", "pos": Vector2(6, 5), "hp": 90, "shoot": 0},
		{"id": 12, "type": "骑", "pos": Vector2(8, 5), "hp": 80, "shoot": 0},
		{"id": 12, "type": "弓", "pos": Vector2(8, 3), "hp": 60, "shoot": 4},
		{"id": 12, "type": "步", "pos": Vector2(7, 4), "hp": 70, "shoot": 0},
		{"id": 31, "type": "将", "pos": Vector2(12, 5), "hp": 88, "shoot": 0},
		{"id": 31, "type": "弓", "pos": Vector2(11, 4), "hp": 50, "shoot": 4},
	]
	for s in specs:
		var bu = BU.new()
		bu.leaderId = int(s["id"])
		bu.unit_position = s["pos"]
		bu._type = str(s["type"])
		bu._hp = int(s["hp"])
		bu._shoot = int(s["shoot"])
		DataManager.battle_units.append(bu)

	var env_url = OS.get_environment("K3G_AI_URL")
	if env_url != "":
		DataManager.ai_agent_base_url = env_url
	print("BATTLE_BASE=", DataManager.resolve_ai_agent_url("/ai/battle"))

	var proj = load("res://BattleProjection.gd").new()
	print("BATTLE_PAYLOAD=", to_json(proj.build(_bf, 12, 1, null, 0)))

	_agent = load("res://BattleAgent.gd").new()
	_agent.attach(_bf)
	_agent.tick()

	var timer = Timer.new()
	timer.wait_time = 15
	timer.one_shot = true
	add_child(timer)
	timer.connect("timeout", self, "_on_timeout")
	timer.start()
	return

func _process(_delta):
	if _done or _agent == null:
		return
	_agent.tick()
	if not _printed_open and _agent.get_session_id() != "":
		_printed_open = true
		print("BATTLE_OPEN=True")
	if _bf.order_calls.size() > 0:
		print("BATTLE_ORDER_CALLS=", to_json(_bf.order_calls))
		if _scenario != "tactic" or FlowManager.flows.has("before_AI_tactic"):
			if _scenario == "tactic":
				print("BATTLE_TACTIC_FLOW=before_AI_tactic")
			_done = true
			get_tree().quit()
	return

func _on_timeout():
	if not _done:
		print("BATTLE_RESULT=timeout")
		get_tree().quit()
	return
```

**Step 11: 重写 `battle-gdscript.test.ts`**

```ts
// 白兵战 Godot 侧契约：真实 GDScript 运行 BattleProjection / BattleAgent，
// 通过真实 HTTP 与服务端 /ai/battle + /tick 往返。未安装 Godot 3 时自动 skip。
import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import type { AddressInfo } from "node:net";
import { createServer } from "../src/server.ts";
import { testConfig } from "./fixture.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const battleAiDir = path.join(repo, "bwdl/packed/sgz_script/battle/AI");
const harnessDir = path.join(repo, "agent-service/gdharness/battle_ai");
const candidates = [
  process.env.GODOT3_BIN,
  path.join(repo, ".tools/Godot_v3.6.3-stable_linux_headless.64"),
  path.join(repo, "Godot_3.6.3.app/Contents/MacOS/Godot"),
].filter((v): v is string => typeof v === "string" && v.length > 0);
const bin = candidates.find((p) => fs.existsSync(p));

function marker(out: string, name: string): string {
  const m = out.match(new RegExp(name + "=([^\\n]*)"));
  assert.ok(m, "缺少 " + name + " 输出：\\n" + out.slice(-2000));
  return m[1];
}

async function runHarness(port: number, scenario: string): Promise<string> {
  const xdg = fs.mkdtempSync(path.join(os.tmpdir(), "3k-bg-"));
  try {
    return await new Promise<string>((resolve, reject) => {
      const child = spawn(bin!, ["--no-window", "--path", harnessDir], {
        cwd: repo,
        env: {
          ...process.env,
          XDG_DATA_HOME: xdg,
          XDG_CONFIG_HOME: xdg,
          K3G_AI_URL: "http://127.0.0.1:" + port + "/",
          K3G_BATTLE_SCENARIO: scenario,
        },
        stdio: ["ignore", "pipe", "pipe"],
      });
      let buf = "";
      child.stdout.on("data", (d) => { buf += d.toString(); });
      child.stderr.on("data", (d) => { buf += d.toString(); });
      const timer = setTimeout(() => { child.kill(); resolve(buf); }, 30000);
      child.on("error", (e) => { clearTimeout(timer); reject(e); });
      child.on("close", () => { clearTimeout(timer); resolve(buf); });
    });
  } finally {
    fs.rmSync(xdg, { recursive: true, force: true });
  }
}

test("Godot 白兵战 v2 快照 / tick / 计策排队", { timeout: 120000 }, async (t) => {
  if (!bin) {
    t.skip("未找到 Godot 3.6.3（设置 GODOT3_BIN）");
    return;
  }
  for (const f of ["BattleProjection.gd", "BattleAgent.gd", "TacticProjection.gd", "BattleHttpClient.gd"]) {
    fs.copyFileSync(path.join(battleAiDir, f), path.join(harnessDir, f));
  }

  const server = createServer({ ...testConfig, port: 0, mode: "stub", webDir: harnessDir });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as AddressInfo).port;

  try {
    const ordersOut = await runHarness(port, "orders");
    assert.equal(marker(ordersOut, "BATTLE_BASE").trim(), "http://127.0.0.1:" + port + "/ai/battle");
    const payload = JSON.parse(marker(ordersOut, "BATTLE_PAYLOAD"));
    assert.equal(payload.battle_version, 2);
    assert.equal(payload.controlled_actor_id, 12);
    assert.equal(payload.enemy_actor_id, 31);
    assert.ok(Array.isArray(payload.controlled.units));
    assert.ok(payload.controlled.units.length > 0);
    assert.ok(payload.controlled.units[0].x !== undefined);
    assert.equal(marker(ordersOut, "BATTLE_OPEN"), "True", "开会话失败：\\n" + ordersOut.slice(-1500));
    assert.ok(marker(ordersOut, "BATTLE_ORDER_CALLS").includes("前进"));

    const tacticOut = await runHarness(port, "tactic");
    const tacticPayload = JSON.parse(marker(tacticOut, "BATTLE_PAYLOAD"));
    assert.equal(tacticPayload.legal_tactics[0].name, "强弩");
    assert.ok(String(tacticPayload.legal_tactics[0].summary).includes("射程"));
    assert.equal(marker(tacticOut, "BATTLE_TACTIC_FLOW"), "before_AI_tactic");
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
});
```

**Step 12: 跑契约测试**

```bash
cd agent-service && GODOT3_BIN=/Users/devinzeng/Code/studyzy/3k-game/Godot_3.6.3.app/Contents/MacOS/Godot node --test test/battle-gdscript.test.ts
```

Expected: PASS，两条场景都通过。若失败：
- `BATTLE_PAYLOAD` 缺字段 → 检查 `BattleProjection.gd` 与 stub。
- `BATTLE_OPEN` 未打印 → 检查 `BattleHttpClient` 是否挂到 `SceneManager`，以及 `/ai/battle` 是否返回 id。
- `BATTLE_ORDER_CALLS` 为空 → 检查 `_states` 初始值是否是「待机」，stub 计划是「前进」。

**Step 13: 提交**

```bash
git add agent-service/gdharness/battle_ai agent-service/test/battle-gdscript.test.ts
git commit -m "test(battle): 更新 GDScript 契约 harness"
```

---

## Task 11: 文档与全量验收

**Files:**
- Modify: `agent-service/README.md`

**Step 1: 更新 README 白兵战段落**

把第 38-49 行的白兵战说明替换为：

```markdown
### 白兵战（两军对垒，异步 tick）

白兵战是准实时的：玩家随时可以暂停、改命令、用计，引擎不会等 AI。

- 一场战斗 = 一个服务端会话，同一个 Agent 从开场对话到结束。
- Godot 每 3 秒（上一次没回就跳过）POST 一次战场快照到 /ai/battle/:id/tick。
- 模型一次输出 JSON 计划：orders 差分 + 至多一个 tactic + memory。
- Godot 立即应用 orders；tactic 排队到 flow 空闲且步骤 4/5/6/7 时执行。
- 没有工具、没有 end_turn；连续 3 拍失败回退本地规则 AI。
```

把第 89-92 行的接口表替换为：

```markdown
| POST /ai/battle | 白兵战：开启战斗会话 |
| POST /ai/battle/:id/tick | 白兵战：提交快照，返回本拍计划 |
| POST /ai/battle/:id/end | 白兵战：结束会话 |
```

把第 187-188 行的文件说明改为：

```markdown
| battle/AI/BattleProjection.gd | 白兵战快照 v2（位置/距离/buff/计策摘要） |
| battle/AI/BattleAgent.gd | 白兵战 3 秒异步状态机（tick / 应用计划 / 用计排队） |
```

把第 229-230 行的测试说明改为：

```markdown
- 白兵战不再有工具表；计划是纯 JSON，服务端单测覆盖 orders 差分、计策校验与并发锁
- 白兵战多拍：连续 8 拍仍是一个会话，对话裁剪到 system + 最近 6 拍
```

**Step 2: 全量测试**

```bash
cd agent-service && npm test
cd /Users/devinzeng/Code/studyzy/3k-game && make check
```

Expected: `npm test` 全绿（Godot 契约测试带 `GODOT3_BIN` 时也通过）；`make check` 无解析错误。

**Step 3: 手动验收**

1. `make serve-agent`，浏览器进大模型难度白兵战。
2. 观察服务端日志：每 3 秒一次 `/tick`；态势不变时计划是空 orders。
3. 玩家按 A 暂停、改命令、用计；AI 请求照常，面板不被顶掉。
4. 用计日志只在 `before_AI_tactic` 前后出现，且同一 buff 不重复。
5. 断网/停服务端：3 拍后 `[BattleAI] fallback to local`。
6. trace dashboard：一场战斗一条 trace，每拍一组 user/assistant。

**Step 4: 提交**

```bash
git add agent-service/README.md
git commit -m "docs(battle): 更新白兵战接口说明与验收"
```

---

## 验收清单（全部打勾才算完成）

- [ ] `cd agent-service && npm test` 全绿。
- [ ] `make check` 无脚本解析错误。
- [ ] GDScript 契约测试两条场景（orders / tactic）通过。
- [ ] 运行时日志无 `end_turn` / `resume` / `/pending` / `/result`。
- [ ] 玩家暂停、改命令、用计期间，AI 的 tick 不阻塞、不抢 flow。
- [ ] 用计只在步骤 4/5/6/7 且 flow 空闲时执行；重复 buff 被拒。
- [ ] 连续 3 拍失败回退本地 AI。
- [ ] 战场 Agent 相关文件没有出现在任何本次提交的 `git diff` 里。

---

## 执行交接

Plan complete and saved to `docs/plans/2026-11-25-battle-ai-async.md`. 两种执行方式：

1. **Subagent-Driven（本会话）** — 每个任务派一个新 subagent，任务间做代码审查，迭代快。
2. **Parallel Session（新会话）** — 用 executing-plans 在新会话里按批次执行，带检查点。

选哪种？
