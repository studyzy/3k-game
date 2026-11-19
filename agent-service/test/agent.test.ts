import test from "node:test";
import assert from "node:assert/strict";
import { startTurn, ServiceError } from "../src/agent.ts";
import { buildTools, TOOL_NAMES, ACT_TOOL_NAMES } from "../src/tools.ts";
import { budgetFor } from "../src/config.ts";
import { TurnSession } from "../src/session.ts";
import { sampleRequest, testConfig, GODOT_IDLE_TIMEOUT_MS, toolResult } from "./fixture.ts";

function sessionFor(req = sampleRequest()) {
  const s = new TurnSession("t", req, GODOT_IDLE_TIMEOUT_MS);
  const live = { units: req.units, terrain: req.terrain, economy: req.economy, legal_actions: req.legal_actions };
  return { session: s, live, tools: buildTools(live, s, budgetFor(req.diffculities)) };
}

test("startTurn 立即返回会话 id（服务端驱动，不等 LLM）", async () => {
  const { session, budget } = startTurn(sampleRequest(), { mode: "mock", config: testConfig });
  assert.ok(session.id.length > 0);
  assert.equal(budget.idle_timeout_ms, GODOT_IDLE_TIMEOUT_MS);
});

test("mock ok：产出动作后正常结束", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "ok" });
  const r = await session.nextAction(2000);
  assert.equal(r.type, "action");
  session.submitResult(r.action.seq, toolResult(r.action.seq, r.action.action));
  const done = await session.nextAction(2000);
  assert.equal(done.type, "end");
});

test("mock error：会话失败", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "error" });
  const r = await session.nextAction(2000);
  assert.equal(r.type, "error");
});

test("mock invalid：下发非法 id，供 Godot 侧校验拒绝", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "invalid" });
  const r = await session.nextAction(2000);
  assert.equal(r.type, "action");
  assert.equal(r.action.id, "__invalid__");
});

test("mock timeout：不产出任何动作（模拟 LLM 卡死）", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "timeout" });
  const r = await session.nextAction(150);
  assert.equal(r.type, "idle_timeout");
});

test("工具注册表恰好 9 个：4 只读 + 4 动作 + end；无 read/write/edit/bash", () => {
  const { tools } = sessionFor();
  assert.deepEqual(tools.tools.map((t) => t.name), [...TOOL_NAMES]);
  assert.equal(ACT_TOOL_NAMES.length, 4);
  for (const forbidden of ["read", "write", "edit", "bash", "submit_plan"]) {
    assert.ok(!tools.tools.some((t) => t.name === forbidden), `不得包含 ${forbidden}`);
  }
});

test("动作工具：按自然参数在 legal_actions 中定位，不发明动作", async () => {
  const { session, tools } = sessionFor();
  const move: any = tools.tools.find((t) => t.name === "move");
  const p = move.execute("c1", { actor: 12, pos: [8, 15], reasoning: "靠近" });
  const got = await session.nextAction(1000);
  assert.equal(got.type, "action");
  assert.equal(got.action.id, "m3");

  session.submitResult(got.action.seq, toolResult(got.action.seq, got.action.action));
  const res = await p;
  // 工具结果回给模型的是结构化摘要（含 Godot 的 outcome 与最新状态）
  const body = JSON.parse((res.content[0] as any).text);
  assert.match(body.outcome, /move 执行完毕/, "应包含 Godot 回传的执行结果");
  assert.ok(Array.isArray(body.units), "应包含最新 units");
  assert.ok(Array.isArray(body.legal_actions), "应包含最新 legal_actions");

  // 不存在的坐标
  await assert.rejects(
    () => move.execute("c2", { actor: 12, pos: [0, 0], reasoning: "x" }),
    /没有匹配该参数的合法 move 动作/,
  );
});

test("stub 模式：一个会话内连续执行动作后 end", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "stub", config: testConfig });
  let guard = 0;
  let endSeen = false;
  while (guard++ < 10) {
    const r = await session.nextAction(3000);
    if (r.type === "end") { endSeen = true; break; }
    if (r.type !== "action") break;
    session.submitResult(r.action.seq, toolResult(r.action.seq, r.action.action));
  }
  assert.ok(endSeen, `会话应以 end 结束，实际 actions=${session.actions.length}`);
  assert.ok(session.actions.length >= 1);
});

test("ServiceError 携带状态码与错误码", () => {
  const e = new ServiceError(503, "api_key_missing", "x");
  assert.equal(e.status, 503);
  assert.equal(e.code, "api_key_missing");
});
