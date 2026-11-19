// 服务级集成测试：真实 HTTP + 真实回合会话，覆盖部署形态下的各种场景。
//   - Godot 请求投影（text/plain、全知视图、用户可编辑文本注入、AI 门控字段）
//   - 空闲超时与 Godot 侧对齐
//   - pi 模式自定义 OpenAI 兼容端点：真实 createRuntime + 工具调用流转写、端点故障
//   - 多会话并发隔离、轨迹面板、断连中止
import test from "node:test";
import assert from "node:assert/strict";
import { budgetFor } from "../src/config.ts";
import { startTurn } from "../src/agent.ts";
import { GODOT_IDLE_TIMEOUT_MS, toolResult } from "./fixture.ts";
import { sessionStore, turnStore } from "../src/session.ts";
import { traceStore } from "../src/trace.ts";
import {
  godotLikeRequest, INJECTION_PAYLOAD, postTurn,
  sampleRequest, startFakeModelEndpoint, startServer, testConfig,
  withApiKey, calls, toolCall,
} from "./harness.ts";

test.beforeEach(() => {
  sessionStore.clear();
  turnStore.clear();
  traceStore.clear();
});

/** 驱动一个真实 HTTP 回合直到结束，返回动作序列与结束原因。 */
async function drive(base: string, sessionId: string, max = 10) {
  const actions: any[] = [];
  for (let i = 0; i < max; i++) {
    const r = await fetch(`${base}/ai/turn/${sessionId}/pending?wait_ms=5000`).then((x) => x.json()) as any;
    if (r.type !== "action") return { actions, end: r };
    actions.push(r.action);
    await fetch(`${base}/ai/turn/${sessionId}/result`, {
      method: "POST",
      headers: { "content-type": "text/plain" },
      body: JSON.stringify(toolResult(r.action.seq, r.action.action)),
    });
  }
  throw new Error("回合未在预期动作数内结束");
}

test("空闲超时与 Godot 侧常量一致（30s）", () => {
  for (const diff of [2, 3, 4]) {
    assert.equal(budgetFor(diff).idle_timeout_ms, GODOT_IDLE_TIMEOUT_MS, `难度 ${diff} 不一致`);
  }
});

test("Godot 视图请求经真实 HTTP 往返：开会话成功、动作来自 legal_actions", async (t) => {
  const server = await startServer();
  t.after(() => server.close());
  const req = godotLikeRequest();
  const res = await postTurn(server.base, req);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("access-control-allow-origin"), "*");
  assert.ok(res.body.session_id);

  const { actions, end } = await drive(server.base, res.body.session_id);
  assert.equal(end.type, "end");
  const ids = new Set(req.legal_actions.map((a) => a.id));
  for (const a of actions) assert.ok(ids.has(a.id), `动作 ${a.id} 不在 legal_actions 中`);
});

test("用户可编辑文本里的指令注入不会改变决策，也不会原样进调试面板", async (t) => {
  const server = await startServer({ mode: "stub" });
  t.after(() => server.close());
  const req = godotLikeRequest();
  assert.ok(JSON.stringify(req).includes("</script>"), "夹具应带 HTML 注入载荷");

  const res = await postTurn(server.base, req);
  assert.equal(res.status, 200);
  await drive(server.base, res.body.session_id);

  const traces = await fetch(server.url("/ai/traces")).then((r) => r.json()) as any;
  const detail = await fetch(server.url(`/ai/traces/${traces.traces[0].id}`)).then((r) => r.json()) as any;
  assert.ok(detail.user_message.includes("</script>"), "审计轨迹应保留原始输入");
  const page = await fetch(server.url("/ai/dashboard")).then((r) => r.text());
  assert.ok(!page.includes(INJECTION_PAYLOAD), "面板是静态单文件，不应把轨迹内联进 HTML");
});

test("ai_agent_mode=false 的请求同样能开会话（门控在客户端）", async (t) => {
  const server = await startServer();
  t.after(() => server.close());
  const req = sampleRequest({ ai_agent_mode: false, diffculities: 2 });
  const res = await postTurn(server.base, req);
  assert.equal(res.status, 200);
  await drive(server.base, res.body.session_id);
  const traces = await fetch(server.url("/ai/traces")).then((r) => r.json()) as any;
  const detail = await fetch(server.url(`/ai/traces/${traces.traces[0].id}`)).then((r) => r.json()) as any;
  assert.equal(detail.ai_agent_mode, false);
});

test("LLM 卡死：长轮询到点返回 idle_timeout，Godot 据此回退", async (t) => {
  const server = await startServer({ mode: "mock", mockCase: "timeout" });
  t.after(() => server.close());
  const res = await postTurn(server.base, sampleRequest({ diffculities: 4, budget: { idle_timeout_ms: 300 } }));
  const sid = res.body.session_id;

  // 第一次轮询到点（服务端侧上限），若已超出空闲预算则回 idle_timeout
  const seen = new Set<string>();
  for (let i = 0; i < 5; i++) {
    const r = await fetch(`${server.base}/ai/turn/${sid}/pending?wait_ms=200`).then((x) => x.json()) as any;
    seen.add(r.type);
    if (r.type === "idle_timeout" || r.type === "error") break;
  }
  assert.ok(
    seen.has("idle_timeout") || seen.has("error"),
    `空闲超时后应给出 idle_timeout/error，实际 ${JSON.stringify([...seen])}`,
  );
});

test("pi 模式故障：端点 500 → 会话以 error 结束，Godot 回退", async (t) => {
  const endpoint = await startFakeModelEndpoint(() => ({ text: "x" }), { status: 500 });
  t.after(() => endpoint.close());
  const restore = withApiKey();
  t.after(restore);
  const server = await startServer({ mode: "pi", llmBaseUrl: endpoint.baseUrl, llmModelId: "fake-model" });
  t.after(() => server.close());

  const res = await postTurn(server.base, sampleRequest({ diffculities: 4 }));
  const r = await fetch(`${server.base}/ai/turn/${res.body.session_id}/pending?wait_ms=5000`).then((x) => x.json()) as any;
  assert.equal(r.type, "error");
});

test("pi 模式缺密钥 → 会话以 error 结束，不静默降级到 mock", async (t) => {
  const saved = process.env.LLM_API_KEY;
  delete process.env.LLM_API_KEY;
  t.after(() => { if (saved !== undefined) process.env.LLM_API_KEY = saved; });
  const server = await startServer({ mode: "pi", llmBaseUrl: "http://127.0.0.1:1/v1", llmModelId: "m" });
  t.after(() => server.close());
  const res = await postTurn(server.base, sampleRequest({ diffculities: 4 }));
  const r = await fetch(`${server.base}/ai/turn/${res.body.session_id}/pending?wait_ms=5000`).then((x) => x.json()) as any;
  assert.equal(r.type, "error");
  assert.match(String(r.message), /缺少 LLM_API_KEY/);
});

test("pi 模式端到端：工具声明齐全、tool 消息回灌、回合内可执行多个动作", async (t) => {
  const endpoint = await startFakeModelEndpoint((ctx) => {
    if (ctx.callIndex === 0) return calls(toolCall("inspect_economy", {}), toolCall("list_legal_actions", {}));
    if (ctx.callIndex === 1) return calls(toolCall("move", { actor: 12, pos: [8, 15], reasoning: "推进" }));
    return calls(toolCall("end", { reason: "打完了" }));
  });
  t.after(() => endpoint.close());
  const restore = withApiKey();
  t.after(restore);
  const server = await startServer({ mode: "pi", llmBaseUrl: endpoint.baseUrl, llmModelId: "fake-model" });
  t.after(() => server.close());

  const req = sampleRequest({ diffculities: 4 });
  const res = await postTurn(server.base, req);
  assert.equal(res.status, 200);
  const { actions, end } = await drive(server.base, res.body.session_id);
  assert.equal(end.type, "end");
  assert.equal(actions.length, 1);
  assert.equal(actions[0].tool, "move");

  const firstTools = (endpoint.requests[0].tools ?? []).map((x: any) => x.function.name);
  assert.deepEqual(firstTools, [
    "list_legal_actions", "inspect_unit", "inspect_terrain", "inspect_economy",
    "move", "attack", "stratagem", "retreat", "end",
  ]);
  const second = endpoint.requests[1].messages ?? [];
  assert.ok(second.some((m: any) => m.role === "tool"), "第二次请求应包含 tool 结果");
});

test("多会话并发：两个回合交错执行，动作与轨迹互不污染", async (t) => {
  const server = await startServer();
  t.after(() => server.close());
  const a = sampleRequest({ session_id: "sess-A", diffculities: 4, turn_key: "A-1" });
  const b = sampleRequest({ session_id: "sess-B", diffculities: 4, turn_key: "B-1" });
  const [ra, rb] = await Promise.all([postTurn(server.base, a), postTurn(server.base, b)]);
  assert.notEqual(ra.body.session_id, rb.body.session_id);

  const [da, db] = await Promise.all([
    drive(server.base, ra.body.session_id),
    drive(server.base, rb.body.session_id),
  ]);
  assert.equal(da.end.type, "end");
  assert.equal(db.end.type, "end");
  assert.equal(traceStore.size(), 2, "两次回合应各有一条轨迹");
});

test("会话未注册 → 404；/ai/turn 非 POST → 405", async (t) => {
  const server = await startServer();
  t.after(() => server.close());
  assert.equal((await fetch(server.url("/ai/turn/nope/pending"))).status, 404);
  assert.equal((await fetch(server.url("/ai/turn/nope/result"), { method: "POST", body: "{}" })).status, 404);
  assert.equal((await fetch(server.url("/ai/turn"))).status, 405);
});

test("坏 JSON / 坏 schema 返回 400", async (t) => {
  const server = await startServer();
  t.after(() => server.close());
  assert.equal((await postTurn(server.base, "not-json")).status, 400);
  const bad = await postTurn(server.base, { ...sampleRequest(), visibility: "partial" });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, "bad_schema");
});

test("startTurn 对 pi 模式的模型不可解析抛 503 语义（会话以 error 结束）", async () => {
  const badConfig = { ...testConfig, provider: "__none__", modelId: "__none__" };
  const { session } = startTurn(sampleRequest(), { mode: "pi", config: badConfig });
  const r = await session.nextAction(2000);
  assert.equal(r.type, "error");
  assert.match(String(r.message), /model_unavailable|无法解析/);
});