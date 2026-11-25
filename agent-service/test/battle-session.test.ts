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
