import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createServer } from "../src/server.ts";
import { sampleRequest, testConfig, toolResult } from "./fixture.ts";

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
  return fetch(`${base}/ai/turn`, {
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
  assert.ok(body.budgets["4"].max_turns >= 4);
  assert.equal(body.budgets["4"].idle_timeout_ms, 30000, "空闲超时 30s");
});

test("POST /ai/turn 开会话，返回 session_id 与空闲超时", async () => {
  const res = await post(sampleRequest());
  assert.equal(res.status, 200);
  const body: any = await res.json();
  assert.ok(typeof body.session_id === "string" && body.session_id.length > 0);
  assert.equal(body.idle_timeout_ms, 30000);
  assert.ok(body.poll_timeout_ms > 0);

  // 未注册的会话 → 404
  const missing = await fetch(`${base}/ai/turn/nope/pending?wait_ms=10`);
  assert.equal(missing.status, 404);
});

test("完整回合：开会话 → 取动作 → 回传结果 → end", async () => {
  const start = await post(sampleRequest()).then((r) => r.json() as any);
  const sid = start.session_id;

  const p1 = await fetch(`${base}/ai/turn/${sid}/pending?wait_ms=3000`).then((r) => r.json() as any);
  assert.equal(p1.type, "action");
  assert.ok(p1.action.seq > 0);
  assert.ok(p1.action.action && typeof p1.action.action.id === "string");

  const posted = await fetch(`${base}/ai/turn/${sid}/result`, {
    method: "POST", headers: { "content-type": "text/plain" },
    body: JSON.stringify(toolResult(p1.action.seq, p1.action.action)),
  }).then((r) => r.json() as any);
  assert.equal(posted.ok, true);

  const done = await fetch(`${base}/ai/turn/${sid}/pending?wait_ms=3000`).then((r) => r.json() as any);
  assert.equal(done.type, "end");
});

test("回传结果缺 seq 或字段非法 → 400", async () => {
  const start = await post(sampleRequest()).then((r) => r.json() as any);
  const sid = start.session_id;
  const bad = await fetch(`${base}/ai/turn/${sid}/result`, {
    method: "POST", headers: { "content-type": "text/plain" }, body: JSON.stringify({ ok: true }),
  });
  assert.equal(bad.status, 400);
  const badBody = await fetch(`${base}/ai/turn/${sid}/result`, {
    method: "POST", headers: { "content-type": "text/plain" }, body: JSON.stringify({ seq: 1, ok: "yes" }),
  });
  assert.equal(badBody.status, 400);
});

test("x-mock-case: error / budget_exhausted / invalid", async () => {
  // 开会话本身总是 200；错误在长轮询时以 type=error 返回
  const err = await post(sampleRequest(), { "x-mock-case": "error" });
  assert.equal(err.status, 200);
  const errSid = (await err.json() as any).session_id;
  const errPoll = await fetch(`${base}/ai/turn/${errSid}/pending?wait_ms=3000`).then((r) => r.json() as any);
  assert.equal(errPoll.type, "error");

  const exhausted = await post(sampleRequest(), { "x-mock-case": "budget_exhausted" });
  assert.equal(exhausted.status, 200);
  const exSid = (await exhausted.json() as any).session_id;
  const exPoll = await fetch(`${base}/ai/turn/${exSid}/pending?wait_ms=3000`).then((r) => r.json() as any);
  assert.equal(exPoll.type, "error");
  assert.match(String(exPoll.message), /agent_budget_exhausted|预算/);

  const invalid = await post(sampleRequest(), { "x-mock-case": "invalid" });
  assert.equal(invalid.status, 200);
  const sid = (await invalid.json() as any).session_id;
  const act = await fetch(`${base}/ai/turn/${sid}/pending?wait_ms=3000`).then((r) => r.json() as any);
  assert.equal(act.type, "action");
  assert.equal(act.action.id, "__invalid__");
});

test("坏 JSON / 坏 schema 返回 400", async () => {
  assert.equal((await post("not-json")).status, 400);
  const bad = await post({ ...sampleRequest(), visibility: "partial" });
  assert.equal(bad.status, 400);
  assert.equal((await bad.json() as any).error, "bad_schema");
});

test("OPTIONS 预检返回 204", async () => {
  const res = await fetch(`${base}/ai/turn`, { method: "OPTIONS" });
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
