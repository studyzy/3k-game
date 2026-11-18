// 跨语言端到端契约测试：Godot 3.6.3 真实运行 StateProjection / ActionValidator /
// AIHttpClient，把生成的 payload 通过真实 HTTP POST 发给 Agent 服务，
// 再验证服务返回的 plan 能被两侧校验接受。未安装 Godot 3 时自动 skip。
import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import type { AddressInfo } from "node:net";
import { validateRequest, validatePlan } from "../src/validate.ts";
import { decide, ServiceError } from "../src/agent.ts";
import { budgetFor } from "../src/config.ts";
import { createServer } from "../src/server.ts";
import { sampleRequest, testConfig } from "./fixture.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const gdscriptDir = path.join(repo, "bwdl/packed/sgz_script/war/AI");
const harnessDir = path.join(repo, "agent-service/gdharness");
const aiDir = path.join(harnessDir, "ai");
const candidates = [
  process.env.GODOT3_BIN,
  path.join(repo, ".tools/Godot_v3.6.3-stable_linux_headless.64"),
].filter((v): v is string => typeof v === "string" && v.length > 0);
const bin = candidates.find((p) => fs.existsSync(p));

function marker(out: string, name: string): string {
  const m = out.match(new RegExp(`${name}=([^\\n]*)`));
  assert.ok(m, `缺少 ${name} 输出：\n${out.slice(-1500)}`);
  return m[1];
}

test("Godot 3.6.3 → HTTP → Agent 服务 全链路契约", async (t) => {
  if (!bin) {
    t.skip("未找到 Godot 3.6.3（设置 GODOT3_BIN）");
    return;
  }
  fs.mkdirSync(aiDir, { recursive: true });
  for (const f of ["StateProjection.gd", "ActionValidator.gd", "AIHttpClient.gd"]) {
    fs.copyFileSync(path.join(gdscriptDir, f), path.join(aiDir, f));
  }

  const server = createServer({ ...testConfig, port: 0, webDir: harnessDir });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as AddressInfo).port;
  const xdg = fs.mkdtempSync(path.join(os.tmpdir(), "3k-godot-home-"));

  try {
    // 必须用异步 spawn：spawnSync 会阻塞 Node 事件循环，
    // 导致同进程内的 mock HTTP 服务无法响应 Godot 的请求（实测 result=12 超时）。
    const out = await new Promise<string>((resolve, reject) => {
      const child = spawn(bin, ["--no-window", "--path", harnessDir], {
        cwd: repo,
        env: {
          ...process.env,
          XDG_DATA_HOME: xdg,
          AI_HTTP_URL: `http://127.0.0.1:${port}/ai/decide`,
        },
        stdio: ["ignore", "pipe", "pipe"],
      });
      let buf = "";
      child.stdout.on("data", (d) => { buf += d.toString(); });
      child.stderr.on("data", (d) => { buf += d.toString(); });
      const timer = setTimeout(() => { child.kill(); reject(new Error("Godot harness timeout")); }, 120000);
      child.on("error", (e) => { clearTimeout(timer); reject(e); });
      child.on("close", () => { clearTimeout(timer); resolve(buf); });
    });

    assert.equal(marker(out, "AI_ACCEPT_GOOD"), "True");
    assert.equal(marker(out, "AI_REJECT_BAD"), "True");
    assert.equal(marker(out, "AI_HTTP_START"), "True");
    assert.equal(marker(out, "AI_HTTP_RESULT"), "0_200", `GDScript HTTP 调用失败：\n${out.slice(-1500)}`);

    const payload = JSON.parse(marker(out, "AI_PAYLOAD"));
    const req = validateRequest(payload);
    assert.equal(req.visibility, "omniscient");
    assert.ok(req.legal_actions.length > 0);
    assert.equal(new Set(req.legal_actions.map((a) => a.id)).size, req.legal_actions.length);
    for (const key of ["battle_fight", "battle_units", "flows_history_list", "common_variable", "secret_mood"]) {
      assert.ok(!(key in payload), `payload 不应包含 ${key}`);
    }

    // Godot 侧 normalize 结果 → 服务侧 validatePlan
    const normalized = JSON.parse(marker(out, "AI_NORMALIZED"));
    assert.ok(normalized.length > 0);
    assert.equal(
      validatePlan(normalized.map((a: any) => ({ id: a.id, order: a.order })), req, budgetFor(req.diffculities)).length,
      normalized.length,
    );

    // 真实 HTTP 响应 → 服务侧 validatePlan
    const body = JSON.parse(marker(out, "AI_HTTP_BODY"));
    assert.ok(Array.isArray(body.plan) && body.plan.length > 0);
    assert.equal(validatePlan(body.plan, req, budgetFor(req.diffculities)).length, body.plan.length);

    // 同一 payload 交给 mock 决策也必须合法
    const res = await decide(req, { mode: "mock", config: testConfig, mockCase: "ok" });
    assert.equal(validatePlan(res.plan, req, budgetFor(req.diffculities)).length, res.plan.length);
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    fs.rmSync(xdg, { recursive: true, force: true });
  }
});

test("pi 模式在模型不可解析时返回 503，不会静默降级", async () => {
  const badConfig = { ...testConfig, provider: "__none__", modelId: "__none__" };
  await assert.rejects(
    () => decide(sampleRequest(), { mode: "pi", config: badConfig }),
    (e: unknown) => e instanceof ServiceError && e.status === 503 && e.code === "model_unavailable",
  );
});
