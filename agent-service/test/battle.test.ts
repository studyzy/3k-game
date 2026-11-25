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

test("provider 报错：tick 抛 502 llm_error，而不是当成成功", async () => {
  const model = scriptedModel(() => text('{"orders":{},"tactic":null}'), { throwOnCall: 0 });
  const s = startBattle(openReq, { mode: "pi", config: testConfig, runtime: model.runtime });
  await assert.rejects(
    () => tickBattle(s, snapshot(), { mode: "pi", config: testConfig, runtime: model.runtime }),
    (err: any) => err.status === 502 && err.code === "llm_error",
  );
  assert.equal(s.inFlight, false, "抛错后必须释放 tick 锁");
});

test("memory 跨拍回喂：第 2 拍能看到第 1 拍的战斗笔记", async () => {
  const model = scriptedModel((ctx) => text(
    ctx.callIndex === 0
      ? '{"orders":{},"tactic":null,"memory":"压弓","reasoning":"先压住弓兵"}'
      : '{"orders":{},"tactic":null}',
  ));
  const s = startBattle(openReq, { mode: "pi", config: testConfig, runtime: model.runtime });
  const r1 = await tickBattle(s, snapshot(), { mode: "pi", config: testConfig, runtime: model.runtime });
  assert.equal(r1.plan.memory, "压弓");
  await tickBattle(s, snapshot({ tick: 2 }), { mode: "pi", config: testConfig, runtime: model.runtime });
  assert.ok(model.requests[1].userMessage.includes("你的战斗笔记：压弓"));
});

test("空计划：orders 为空对象且不产生 rejected", async () => {
  const model = scriptedModel(() => text('{"orders":{},"tactic":null}'));
  const s = startBattle(openReq, { mode: "pi", config: testConfig, runtime: model.runtime });
  const r = await tickBattle(s, snapshot(), { mode: "pi", config: testConfig, runtime: model.runtime });
  assert.deepEqual(r.plan.orders, {});
  assert.equal(r.rejected.length, 0);
});

test("裁剪后的对话：system 打头，第一条非 system 是 user", async () => {
  const model = scriptedModel(() => text('{"orders":{},"tactic":null}'));
  const s = startBattle(openReq, { mode: "pi", config: testConfig, runtime: model.runtime });
  for (let i = 0; i < 8; i++) {
    await tickBattle(s, snapshot({ tick: i + 1 }), { mode: "pi", config: testConfig, runtime: model.runtime });
  }
  const messages = model.requests[7].messages;
  assert.ok(messages.length <= 13, "总长度不超过 13");
  assert.equal(messages[0].role, "system");
  const firstOther = messages.find((m) => m.role !== "system");
  assert.equal(firstOther?.role, "user", "第一条非 system 必须是 user，不能是孤儿 assistant");
});

test("usage：pi 模式每拍返回本拍 token 消耗", async () => {
  const model = scriptedModel(() => text('{"orders":{},"tactic":null}'));
  const s = startBattle(openReq, { mode: "pi", config: testConfig, runtime: model.runtime });
  const r = await tickBattle(s, snapshot(), { mode: "pi", config: testConfig, runtime: model.runtime });
  assert.ok(r.usage, "必须带 usage");
  assert.ok(r.usage.tokens > 0, "真实调用过模型就必须有 token 消耗");
});

