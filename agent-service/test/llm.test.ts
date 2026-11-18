// 自定义 OpenAI 兼容端点的配置与接线测试。
// 真实密钥只从进程环境读取，绝不写进仓库；没有 env 时真实调用测试自动 skip。
import test from "node:test";
import assert from "node:assert/strict";
import { parseConfig } from "../src/config.ts";
import { createCustomRuntime } from "../src/llm.ts";
import { decide, ServiceError } from "../src/agent.ts";
import { sampleRequest, testConfig } from "./fixture.ts";

test("parseConfig 读取 LLM_* 且密钥不进入 ServiceConfig", () => {
  const cfg = parseConfig([], {
    LLM_BASE_URL: "http://example.invalid/v1/",
    LLM_MODEL: "hai/deepseek-flash",
    LLM_PROVIDER_ID: "ccr",
    LLM_API_KEY: "secret-should-not-leak",
    LLM_CONTEXT_WINDOW: "32768",
    LLM_MAX_TOKENS: "4096",
  });
  assert.equal(cfg.llmBaseUrl, "http://example.invalid/v1");
  assert.equal(cfg.llmModelId, "hai/deepseek-flash");
  assert.equal(cfg.llmProviderId, "ccr");
  assert.equal(cfg.llmContextWindow, 32768);
  assert.equal(cfg.llmMaxTokens, 4096);
  assert.ok(!JSON.stringify(cfg).includes("secret-should-not-leak"));
});

test("createCustomRuntime 能解析自定义模型（不发网络请求）", () => {
  const rt = createCustomRuntime({
    baseUrl: "http://example.invalid/v1",
    modelId: "hai/deepseek-flash",
    apiKey: "dummy",
  });
  assert.equal(rt.modelId, "hai/deepseek-flash");
  assert.ok(rt.model);
  assert.equal(typeof rt.streamFn, "function");
});

test("pi 模式自定义端点缺少密钥时返回 503，不静默降级", async () => {
  const cfg = { ...testConfig, llmBaseUrl: "http://example.invalid/v1" };
  const savedKey = process.env.LLM_API_KEY;
  const savedPi = process.env.PI_API_KEY;
  delete process.env.LLM_API_KEY;
  delete process.env.PI_API_KEY;
  try {
    await assert.rejects(
      () => decide(sampleRequest(), { mode: "pi", config: cfg }),
      (e: unknown) => e instanceof ServiceError && e.status === 503 && e.code === "api_key_missing",
    );
  } finally {
    if (savedKey !== undefined) process.env.LLM_API_KEY = savedKey;
    if (savedPi !== undefined) process.env.PI_API_KEY = savedPi;
  }
});

test("真实端点端到端（仅当 LLM_BASE_URL + LLM_API_KEY 已在环境中配置时）", { timeout: 180000 }, async (t) => {
  const base = process.env.LLM_BASE_URL;
  const key = process.env.LLM_API_KEY ?? process.env.PI_API_KEY;
  if (!base || !key) {
    t.skip("未配置 LLM_BASE_URL / LLM_API_KEY");
    return;
  }
  const cfg = {
    ...testConfig,
    mode: "pi" as const,
    llmBaseUrl: base,
    llmModelId: process.env.LLM_MODEL ?? "hai/deepseek-flash",
  };
  // 用最小候选集降低模型输出波动，仍能验证「端点 → tool calling → submit_plan → plan」整条链路
  const req = sampleRequest({
    diffculities: 4,
    legal_actions: [
      { id: "m1", tool: "move", actor: 12, pos: [8, 15], cost: { ap: 1, poker: 0 } },
      { id: "e0", tool: "end", actor: 12, cost: {} },
    ],
  });
  const res = await decide(req, { mode: "pi", config: cfg });
  assert.equal(res.model, cfg.llmModelId);
  assert.ok(res.plan.length > 0, "真实模型应提交非空 plan");
  const ids = new Set(req.legal_actions.map((a) => a.id));
  for (const p of res.plan) assert.ok(ids.has(p.id), `模型返回了非法 id: ${p.id}`);
  assert.ok(res.budget_used.turns >= 1);
  assert.ok(res.trace.some((x) => x.tool === "submit_plan"));
});
