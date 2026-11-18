import test from "node:test";
import assert from "node:assert/strict";
import { SessionStore, sessionStore } from "../src/session.ts";
import { decide } from "../src/agent.ts";
import { sampleRequest, testConfig } from "./fixture.ts";
import type { DecideResponse } from "../src/types.ts";

function fakeResponse(intent: string): DecideResponse {
  return {
    plan: [{ id: "m3", order: 1 }],
    intent,
    model: "test",
    elapsed_ms: 1,
    budget_used: { tokens: 0, turns: 1, tool_calls: 1 },
    trace: [],
  };
}

test("SessionStore 按 session_id 隔离并累计回合", () => {
  const s = new SessionStore();
  assert.equal(s.get("a"), null);
  s.update("a", fakeResponse("先削兵"));
  s.update("a", fakeResponse("再包抄"));
  const rec: any = s.get("a");
  assert.equal(rec.intent, "再包抄");
  assert.equal(rec.last_plan_result, "1/1 已提交");
  assert.equal(rec.turns, 2);
  assert.equal(s.get("b"), null);
  assert.equal(s.size(), 1);
});

test("SessionStore TTL 清理", async () => {
  const s = new SessionStore(5);
  s.update("x", fakeResponse("x"));
  assert.ok(s.get("x"));
  await new Promise((r) => setTimeout(r, 15));
  assert.equal(s.get("x"), null);
  assert.equal(s.size(), 0);
});

test("diffculities=4 的 stub 决策写入跨回合记忆，3 不写", async () => {
  sessionStore.clear();
  await decide(sampleRequest({ diffculities: 3, session_id: "sgz-low" }), { mode: "stub", config: testConfig });
  assert.equal(sessionStore.get("sgz-low"), null);

  await decide(sampleRequest({ diffculities: 4, session_id: "sgz-high" }), { mode: "stub", config: testConfig });
  const rec: any = sessionStore.get("sgz-high");
  assert.ok(rec, "高难度应写入会话记忆");
  assert.ok(rec.intent.length > 0);
  assert.equal(rec.turns, 1);
  sessionStore.clear();
});
