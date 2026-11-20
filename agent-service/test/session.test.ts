import test from "node:test";
import assert from "node:assert/strict";
import { SessionStore, sessionStore, TurnSession, TurnStore } from "../src/session.ts";
import { sampleRequest, GODOT_IDLE_TIMEOUT_MS } from "./fixture.ts";

test("SessionStore 按 session_id 隔离并累计回合", () => {
  const s = new SessionStore();
  assert.equal(s.get("a"), null);
  s.update("a", "先削兵", "move 12");
  s.update("a", "再包抄", "attack 13");
  const rec: any = s.get("a");
  assert.equal(rec.intent, "再包抄");
  assert.equal(rec.last_action, "attack 13");
  assert.equal(rec.turns, 2);
  assert.equal(s.get("b"), null);
  assert.equal(s.size(), 1);
});

test("SessionStore TTL 清理", async () => {
  const s = new SessionStore(5);
  s.update("x", "x", "m");
  assert.ok(s.get("x"));
  await new Promise((r) => setTimeout(r, 15));
  assert.equal(s.get("x"), null);
  assert.equal(s.size(), 0);
});

test("TurnStore 创建 / 查询 / 删除 / 清理已结束会话", () => {
  const store = new TurnStore();
  const a = store.create(sampleRequest(), GODOT_IDLE_TIMEOUT_MS);
  assert.equal(store.get(a.id), a);
  assert.equal(store.size(), 1);

  a.finish("done");
  // 已结束的会话在 cleanup 时被回收
  assert.equal(store.size(), 0);

  const b = store.create(sampleRequest(), GODOT_IDLE_TIMEOUT_MS);
  store.delete(b.id);
  assert.equal(store.get(b.id), undefined);
});

test("TurnSession：动作序号递增，结果按 seq 精确回填", async () => {
  const s = new TurnSession("t", sampleRequest(), GODOT_IDLE_TIMEOUT_MS);
  const p1 = s.emitAction({
    tool: "move", actor: 12, id: "m3",
    action: { id: "m3", tool: "move", actor: 12, pos: [8, 15] }, reasoning: "r1",
  });
  const got1 = await s.nextAction(1000);
  assert.equal(got1.type, "action");
  assert.equal(got1.action.seq, 1);

  s.submitResult(1, {
    ok: true, outcome: "移动完成", units: [], legal_actions: [],
  });
  const out1 = await p1;
  assert.equal(out1.ok, true);
  assert.equal(out1.outcome, "移动完成");
});

test("TurnSession：结束会让等待中的轮询立刻返回 end", async () => {
  const s = new TurnSession("t", sampleRequest(), GODOT_IDLE_TIMEOUT_MS);
  const pending = s.nextAction(5000);
  s.finish("agent 调用 end");
  const r = await pending;
  assert.equal(r.type, "end");
  assert.equal((r as any).reason, "agent 调用 end");
});

test("TurnSession：失败会拒绝挂起的工具调用", async () => {
  const s = new TurnSession("t", sampleRequest(), GODOT_IDLE_TIMEOUT_MS);
  const p = s.emitAction({
    tool: "move", actor: 12, id: "m3",
    action: { id: "m3", tool: "move", actor: 12, pos: [8, 15] }, reasoning: "r",
  });
  void s.nextAction(1000);
  s.fail(new Error("模型崩了"));
  await assert.rejects(() => p, /模型崩了/);
});

test("TurnSession：中间进度可立即唤醒等待中的轮询", async () => {
  const s = new TurnSession("t", sampleRequest(), GODOT_IDLE_TIMEOUT_MS);
  const pending = s.nextAction(5000);
  s.emitProgress("查看粮草与经济");
  const r = await pending;
  assert.equal(r.type, "progress");
  assert.equal((r as any).text, "查看粮草与经济");
});

test("TurnSession：进度先于动作下发，动作仍需回传结果", async () => {
  const s = new TurnSession("t", sampleRequest(), GODOT_IDLE_TIMEOUT_MS);
  s.emitProgress("先侦察");
  s.emitAction({
    tool: "move", actor: 12, id: "m3",
    action: { id: "m3", tool: "move", actor: 12, pos: [8, 15] }, reasoning: "r",
  });

  const first = await s.nextAction(1000);
  assert.equal(first.type, "progress");
  assert.equal((first as any).text, "先侦察");

  const second = await s.nextAction(1000);
  assert.equal(second.type, "action");
  assert.equal((second as any).action.seq, 1);
  s.submitResult(1, { ok: true, outcome: "ok", units: [], legal_actions: [] });
});

test("sessionStore 单例可用", () => {
  sessionStore.clear();
  sessionStore.update("z", "i", "a");
  assert.ok(sessionStore.get("z"));
  sessionStore.clear();
});
