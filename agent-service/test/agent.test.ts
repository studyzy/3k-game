import test from "node:test";
import assert from "node:assert/strict";
import { decide, ServiceError } from "../src/agent.ts";
import { buildTools, READ_ONLY_TOOL_NAMES } from "../src/tools.ts";
import { budgetFor } from "../src/config.ts";
import { sampleRequest, testConfig } from "./fixture.ts";

test("mock ok 返回合法计划", async () => {
  const req = sampleRequest();
  const res = await decide(req, { mode: "mock", config: testConfig, mockCase: "ok" });
  assert.ok(res.plan.length > 0);
  const ids = new Set(req.legal_actions.map((a) => a.id));
  for (const p of res.plan) assert.ok(ids.has(p.id));
});

test("mock slow 延迟后仍返回合法计划", async () => {
  const t0 = Date.now();
  const res = await decide(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "slow" });
  assert.ok(Date.now() - t0 >= testConfig.mockSlowMs);
  assert.ok(res.plan.length > 0);
});

test("mock error / budget_exhausted 抛 ServiceError", async () => {
  await assert.rejects(
    () => decide(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "error" }),
    (e: unknown) => e instanceof ServiceError && e.status === 500 && e.code === "mock_error",
  );
  await assert.rejects(
    () => decide(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "budget_exhausted" }),
    (e: unknown) => e instanceof ServiceError && e.status === 422 && e.code === "agent_budget_exhausted",
  );
});

test("mock invalid 故意返回非法 id（供 Godot 侧 ActionValidator 整批拒绝）", async () => {
  const res = await decide(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "invalid" });
  assert.equal(res.plan[0].id, "__invalid__");
});

test("工具注册表只有 6 个只读工具，submit_plan 的 id 用本次 legal_actions 枚举限定", () => {
  const req = sampleRequest();
  const { tools } = buildTools(req, budgetFor(3));
  assert.deepEqual(tools.map((t) => t.name), [...READ_ONLY_TOOL_NAMES]);
  const submit: any = tools.find((t) => t.name === "submit_plan");
  const enumIds = submit.parameters.properties.plan.items.properties.id.enum;
  assert.deepEqual(enumIds, req.legal_actions.map((a) => a.id));
});

test("只读工具不写状态：estimate_plan 与 submit_plan 不修改请求", async () => {
  const req = sampleRequest();
  const snapshot = JSON.stringify(req);
  const { tools, state } = buildTools(req, budgetFor(3));
  const estimate: any = tools.find((t) => t.name === "estimate_plan");
  const r = await estimate.execute("c1", { ids: ["m3", "a1"] });
  assert.equal(r.details.over_budget.length, 0);
  assert.equal(JSON.stringify(req), snapshot);
  assert.equal(state.submitted, undefined);
});

test("submit_plan 非法 id 被 validatePlan 拒绝（服务侧预校验）", async () => {
  const req = sampleRequest();
  const { tools } = buildTools(req, budgetFor(3));
  const submit: any = tools.find((t) => t.name === "submit_plan");
  await assert.rejects(
    () => submit.execute("c1", { plan: [{ id: "bogus", order: 1 }], intent: "x" }),
    /unknown action id/,
  );
});

test("stub 模式跑通 Pi agent loop：多步工具调用 + submit_plan 终止", async () => {
  const req = sampleRequest();
  const res = await decide(req, { mode: "stub", config: testConfig });
  assert.equal(res.model, "faux-1");
  assert.equal(res.budget_used.turns, 2);
  assert.equal(res.budget_used.tool_calls, 2);
  assert.deepEqual(res.trace.map((t) => t.tool), ["estimate_plan", "submit_plan"]);
  const ids = new Set(req.legal_actions.map((a) => a.id));
  for (const p of res.plan) assert.ok(ids.has(p.id));
  assert.equal(res.plan[0].order, 1);
  assert.ok(res.intent.length > 0);
});
