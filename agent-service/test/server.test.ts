import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createServer } from "../src/server.ts";
import { sampleRequest, testConfig } from "./fixture.ts";

let server: http.Server;
let base: string;
let tmpDir: string;

before(async () => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "3k-web-"));
  await fs.writeFile(path.join(tmpDir, "index.html"), "<html>3k</html>");
  server = createServer({ ...testConfig, webDir: tmpDir });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const addr = server.address();
  assert.ok(addr && typeof addr === "object");
  base = `http://127.0.0.1:${addr.port}`;
});

after(async () => {
  await new Promise<void>((resolve) => server.close(() => resolve()));
  await fs.rm(tmpDir, { recursive: true, force: true });
});

async function post(body: unknown, headers: Record<string, string> = {}) {
  return fetch(`${base}/ai/decide`, {
    method: "POST",
    headers: { "content-type": "text/plain; charset=utf-8", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

test("GET /ai/health 返回预算表", async () => {
  const res = await fetch(`${base}/ai/health`);
  assert.equal(res.status, 200);
  const body: any = await res.json();
  assert.equal(body.ok, true);
  assert.equal(body.mode, "mock");
  assert.ok(body.budgets["4"].max_turns === 8);
});

test("POST /ai/decide 同源 text/plain 返回合法计划", async () => {
  const res = await post(sampleRequest());
  assert.equal(res.status, 200);
  const body: any = await res.json();
  assert.ok(Array.isArray(body.plan) && body.plan.length > 0);
  assert.equal(body.model, "mock");
  assert.ok(Array.isArray(body.trace));
});

test("x-mock-case: error / budget_exhausted / invalid", async () => {
  const err = await post(sampleRequest(), { "x-mock-case": "error" });
  assert.equal(err.status, 500);
  assert.equal((await err.json() as any).error, "mock_error");

  const exhausted = await post(sampleRequest(), { "x-mock-case": "budget_exhausted" });
  assert.equal(exhausted.status, 422);
  assert.equal((await exhausted.json() as any).error, "agent_budget_exhausted");

  const invalid = await post(sampleRequest(), { "x-mock-case": "invalid" });
  assert.equal(invalid.status, 200);
  assert.equal((await invalid.json() as any).plan[0].id, "__invalid__");
});

test("坏 JSON / 坏 schema 返回 400", async () => {
  assert.equal((await post("not-json")).status, 400);
  const bad = await post({ ...sampleRequest(), visibility: "partial" });
  assert.equal(bad.status, 400);
  assert.equal((await bad.json() as any).error, "bad_schema");
});

test("OPTIONS 预检返回 204", async () => {
  const res = await fetch(`${base}/ai/decide`, { method: "OPTIONS" });
  assert.equal(res.status, 204);
});

test("静态托管：index.html 可读，路径穿越被拒绝，缺失文件 404", async () => {
  const ok = await fetch(`${base}/`);
  assert.equal(ok.status, 200);
  assert.equal(await ok.text(), "<html>3k</html>");

  const traversal = await fetch(`${base}/%2e%2e%2fpackage.json`);
  assert.equal(traversal.status, 403);

  const missing = await fetch(`${base}/nope.pck`);
  assert.equal(missing.status, 404);
});
