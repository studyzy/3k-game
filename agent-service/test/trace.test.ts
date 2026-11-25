// 决策轨迹采集与调试面板 API 测试
import test from "node:test";
import assert from "node:assert/strict";
import type { AddressInfo } from "node:net";
import { TraceStore } from "../src/trace.ts";
import { traceStore } from "../src/trace.ts";
import { startTurn } from "../src/agent.ts";
import { toolResult } from "./fixture.ts";
import { createServer } from "../src/server.ts";
import { sampleRequest, testConfig } from "./fixture.ts";

test("TraceStore 环形缓冲 / 事件序号 / 查询 / 清空", () => {
  const s = new TraceStore(3);
  const t1 = s.create({ mode: "mock", model: "m", turn_key: "a", diffculities: 4, controlled_vstate_id: 2, legal_actions_count: 1, system_prompt: "S", user_message: "U", tools: [] });
  s.add(t1, "system", { text: "S" });
  s.add(t1, "final", { text: "done" });
  s.finish(t1, { status: "ok", elapsed_ms: 12, intent: "i" });
  assert.equal(t1.events.length, 2);
  assert.equal(t1.events[0].seq, 1);
  assert.equal(t1.events[1].seq, 2);
  assert.equal(s.get(t1.id)?.status, "ok");
  assert.equal(s.list()[0].intent, "i");
  assert.equal(s.size(), 1);

  for (let i = 0; i < 5; i++) s.create({ mode: "mock", model: "m", turn_key: "b" + i, diffculities: 4, controlled_vstate_id: 2, legal_actions_count: 1, system_prompt: "S", user_message: "U", tools: [] });
  assert.equal(s.size(), 3, "应按上限裁剪");
  assert.equal(s.list()[0].turn_key, "b4", "最新在前");
  s.clear();
  assert.equal(s.size(), 0);
});

test("stub 回合产生完整对话事件（system/user/turn/assistant/tool_call/tool_result/final）", async () => {
  traceStore.clear();
  const req = sampleRequest({ diffculities: 4 });
  const { session } = startTurn(req, { mode: "stub", config: testConfig });
  for (let i = 0; i < 10; i++) {
    const r = await session.nextAction(3000);
    if (r.type === "progress") continue;
    if (r.type !== "action") break;
    session.submitResult(r.action.seq, toolResult(r.action.seq, r.action.action));
  }
  await new Promise((r) => setTimeout(r, 50));
  const list = traceStore.list();
  assert.equal(list.length, 1);
  const t = traceStore.get(list[0].id);
  assert.ok(t);
  assert.equal(t!.status, "ok");
  assert.equal(t!.budget_used?.cache_read, 0, "stub 模式无 usage.cacheRead 时应记为 0 而不崩");
  assert.equal(t!.budget_used?.cache_write, 0);
  assert.match(t!.system_prompt, /战场指挥官/);
  assert.match(t!.user_message, /本轮次/);
  assert.ok(!t!.user_message.includes("legal_actions"), "动作清单不该进提示词");
  const types = new Set(t!.events.map((e) => e.type));
  for (const k of ["system", "user", "turn", "assistant", "tool_call", "tool_result", "final"]) {
    assert.ok(types.has(k as never), `缺少事件类型 ${k}`);
  }
  const calls = t!.events.filter((e) => e.type === "tool_call");
  assert.ok(calls.some((e) => e.tool === "move"), "应记录动作工具调用");
  const results = t!.events.filter((e) => e.type === "tool_result");
  assert.ok(results.length >= 1);
  assert.ok(Array.isArray(t!.actions), "轨迹应记录本回合的动作序列");
  assert.ok(t!.intent !== undefined);
  // 请求上下文里的工具定义也要可查：名称、说明、参数 schema 齐全
  assert.equal(t!.tools.length, 10, "战争场景应有 10 个工具");
  const names = t!.tools.map((x) => x.name);
  for (const k of ["move", "attack", "stratagem", "retreat", "end", "list_legal_actions"]) {
    assert.ok(names.includes(k), `缺少工具 ${k}`);
  }
  const move = t!.tools.find((x) => x.name === "move")!;
  assert.equal(move.label, "移动");
  assert.match(move.description, /路径/);
  assert.deepEqual((move.parameters as any).required, ["actor", "path", "reasoning"]);
  assert.doesNotThrow(() => JSON.stringify(t!.tools), "工具定义必须可序列化到 API");
});

test("错误回合也被记录（status=error + error 事件）", async () => {
  traceStore.clear();
  const { session } = startTurn(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "error" });
  await session.nextAction(2000);
  await new Promise((r) => setTimeout(r, 50));
  const t = traceStore.get(traceStore.list()[0].id);
  assert.equal(t!.status, "error");
  assert.ok(t!.events.some((e) => e.type === "error"));
});

test("调试面板 API：列表 / 详情 / 清空 / HTML", async () => {
  traceStore.clear();
  const { session } = startTurn(sampleRequest(), { mode: "stub", config: testConfig });
  for (let i = 0; i < 10; i++) {
    const r = await session.nextAction(3000);
    if (r.type === "progress") continue;
    if (r.type !== "action") break;
    session.submitResult(r.action.seq, toolResult(r.action.seq, r.action.action));
  }
  await new Promise((r) => setTimeout(r, 50));

  const server = createServer({ ...testConfig, port: 0, webDir: "dashboard" });
  await new Promise<void>((r) => server.listen(0, "127.0.0.1", r));
  const port = (server.address() as AddressInfo).port;
  const base = `http://127.0.0.1:${port}`;
  try {
    const list = await fetch(`${base}/ai/traces`).then((r) => r.json()) as any;
    assert.equal(list.total, 1);
    assert.equal(list.traces[0].mode, "stub");

    const detail = await fetch(`${base}/ai/traces/${list.traces[0].id}`).then((r) => r.json()) as any;
    assert.ok(detail.events.length > 0);
    assert.ok(detail.system_prompt.includes("战场指挥官"));
    assert.ok(detail.tools.some((x: any) => x.name === "attack"), "详情应带工具定义");

    const missing = await fetch(`${base}/ai/traces/nope`);
    assert.equal(missing.status, 404);

    const html = await fetch(`${base}/ai/dashboard`);
    assert.equal(html.status, 200);
    assert.match(html.headers.get("content-type") ?? "", /text\/html/);
    const body = await html.text();
    assert.match(body, /AI Agent 决策监控面板/);
    assert.match(body, /\/ai\/traces/);

    const cleared = await fetch(`${base}/ai/traces`, { method: "DELETE" });
    assert.equal(cleared.status, 200);
    assert.equal(traceStore.size(), 0);
  } finally {
    await new Promise<void>((r) => server.close(() => r()));
  }
});
