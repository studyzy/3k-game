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
