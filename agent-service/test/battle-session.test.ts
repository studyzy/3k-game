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
test("finish 后 beginTick 返回 false", () => {
  const s = new BattleSession("b", init, 1000);
  s.finish("done");
  assert.equal(s.beginTick(), false);
  assert.equal(s.inFlight, false);
});

test("size() 会先 prune 过期会话", () => {
  const store = new BattleStore();
  const s = store.create(init, 10);
  s.lastActivityAt = Date.now() - 100;
  assert.equal(store.size(), 0);
});

test("clear 后 size 为 0", () => {
  const store = new BattleStore();
  store.create(init);
  store.create(init);
  assert.equal(store.size(), 2);
  store.clear();
  assert.equal(store.size(), 0);
});

test("活跃会话 touch 后可继续 get 到", () => {
  const store = new BattleStore();
  const s = store.create(init, 10);
  s.touch();
  assert.equal(store.get(s.id), s);
});

test("两个会话共存且 id 唯一", () => {
  const store = new BattleStore();
  const a = store.create(init);
  const b = store.create(init);
  assert.notEqual(a.id, b.id);
  assert.equal(store.size(), 2);
});
