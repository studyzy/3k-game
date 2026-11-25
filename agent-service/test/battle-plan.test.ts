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

test("extractJson 跳过非 JSON 围栏，取后面 json 围栏里的对象", () => {
  const text = "```text\nhello }\n```\n```json\n{\"a\":1}\n```\n";
  assert.deepEqual(extractJson(text), { a: 1 });
});

test("合法计划：orders 差分 + 一个可用计策 + 按码点截断 memory/reasoning", () => {
  const r = validateBattlePlan({ orders: { 弓: "待机" }, tactic: "强弩", memory: "x".repeat(200) }, snapshot());
  assert.deepEqual(r.plan.orders, { 弓: "待机" });
  assert.equal(r.plan.tactic, "强弩");
  assert.equal(r.plan.memory?.length, 120);
  assert.equal(r.rejected.length, 0);

  const emoji = validateBattlePlan({ memory: "😀".repeat(200), reasoning: "🚩".repeat(250) }, snapshot());
  assert.equal(Array.from(emoji.plan.memory ?? "").length, 120);
  assert.equal(emoji.plan.memory, "😀".repeat(120));
  assert.equal(Array.from(emoji.plan.reasoning ?? "").length, 200);
  assert.equal(emoji.plan.reasoning, "🚩".repeat(200));
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

test("空字符串 tactic 视为 null；非对象计划与非法 orders 归入 plan 类拒绝", () => {
  assert.equal(validateBattlePlan({ orders: {}, tactic: "" }, snapshot()).plan.tactic, null);

  const nonObject = validateBattlePlan("x", snapshot());
  assert.deepEqual(nonObject.plan, emptyPlan());
  assert.equal(nonObject.rejected[0].kind, "plan");
  assert.match(nonObject.rejected[0].reason, /不是 JSON 对象/);

  const badOrders = validateBattlePlan({ orders: [1, 2] }, snapshot());
  assert.deepEqual(badOrders.plan, emptyPlan());
  assert.equal(badOrders.rejected[0].kind, "plan");
  assert.match(badOrders.rejected[0].reason, /orders 不是对象/);
});

test("tactic 不是字符串被拒，空字符串仍视为 null", () => {
  const r = validateBattlePlan({ tactic: 5 }, snapshot());
  assert.equal(r.plan.tactic, null);
  assert.deepEqual(r.rejected, [{ kind: "tactic", value: "5", reason: "计策不是字符串" }]);
  assert.equal(r.rejected[0].value, "5");
});

test("计策合法但战术值不足：丢弃 tactic 并给出战术值不足原因", () => {
  const snap = snapshot({
    controlled: { ...snapshot().controlled, tactic_point: 3 },
    legal_tactics: [{ name: "强弩", cost: 7, rate: 100, summary: "x" }],
  });
  const r = validateBattlePlan({ orders: {}, tactic: "强弩" }, snap);
  assert.equal(r.plan.tactic, null);
  assert.equal(r.rejected.length, 1);
  assert.equal(r.rejected[0].kind, "tactic");
  assert.ok(r.rejected[0].reason.includes("战术值不足"), r.rejected[0].reason);
});
