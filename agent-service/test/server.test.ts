import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createServer } from "../src/server.ts";
import { turnStore } from "../src/session.ts";
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

function battleSnapshot(overrides: Record<string, unknown> = {}) {
  return {
    battle_version: 2, battle_key: "b12-b31", tick: 1, elapsed_ms: 1200,
    diffculities: 4, side: "attacker", controlled_actor_id: 12, enemy_actor_id: 31,
    turn: 1, terrain: { name: "plain", is_city: false },
    controlled: {
      name: "张辽", hp: 90, soldiers: 1200, tactic_point: 10, buffs: [],
      units: [
        { type: "将", hp: 400, count: 1, order: "待机", x: 6, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
      ],
    },
    enemy: {
      name: "高顺", hp: 88, soldiers: 900, tactic_point: 8, buffs: [],
      units: [
        { type: "将", hp: 350, count: 1, order: "待机", x: 12, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
      ],
    },
    legal_tactics: [],
    last_plan: null,
    ...overrides,
  };
}

async function openBattle(overrides: Record<string, unknown> = {}): Promise<string> {
  const res = await fetch(base + "/ai/battle", {
    method: "POST", headers: { "content-type": "text/plain" },
    body: JSON.stringify({
      battle_key: "b12-b31", controlled_actor_id: 12, enemy_actor_id: 31,
      side: "attacker", diffculities: 4, ...overrides,
    }),
  });
  assert.equal(res.status, 200);
  return (await res.json() as any).battle_session_id;
}

async function battlePost(id: string, suffix: "tick" | "end", body?: unknown) {
  return fetch(base + "/ai/battle/" + id + "/" + suffix, {
    method: "POST", headers: { "content-type": "text/plain" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

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

test("中间进度：pending 返回 progress 且会话继续可用", async () => {
  const start = await post(sampleRequest(), { "x-mock-case": "timeout" }).then((r) => r.json() as any);
  const sid = start.session_id;
  const session = turnStore.get(sid);
  assert.ok(session, "会话应存在");
  session!.emitProgress("查看粮草与经济");

  const progress = await fetch(`${base}/ai/turn/${sid}/pending?wait_ms=1000`).then((r) => r.json() as any);
  assert.equal(progress.type, "progress");
  assert.equal(progress.text, "查看粮草与经济");

  const again = await fetch(`${base}/ai/turn/${sid}/pending?wait_ms=20`).then((r) => r.json() as any);
  assert.equal(again.type, "retry");
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

test("estimate 路由：校验 answers 并把回答交回会话", async () => {
  const started = await post(sampleRequest({ diffculities: 4 }));
  const id = (await started.json()).session_id;

  // 缺 answers → 400
  const bad = await fetch(`${base}/ai/turn/${id}/estimate`, {
    method: "POST", headers: { "content-type": "text/plain" }, body: JSON.stringify({}),
  });
  assert.equal(bad.status, 400);

  const ok = await fetch(`${base}/ai/turn/${id}/estimate`, {
    method: "POST", headers: { "content-type": "text/plain" },
    body: JSON.stringify({ answers: [{ id: 999, data: { ok: true, rate: 70 } }] }),
  });
  assert.equal(ok.status, 200);
  assert.deepEqual(await ok.json(), { ok: true });

  // 未知会话 → 404
  const missing = await fetch(`${base}/ai/turn/nope/estimate`, {
    method: "POST", headers: { "content-type": "text/plain" },
    body: JSON.stringify({ answers: [{ id: 1, data: {} }] }),
  });
  assert.equal(missing.status, 404);
});

test("白兵战 tick 路由：开场 → tick → end，非法快照 422，结束 410", async () => {
  const open = await fetch(base + "/ai/battle", {
    method: "POST", headers: { "content-type": "text/plain" },
    body: JSON.stringify({
      battle_key: "b12-b31", controlled_actor_id: 12, enemy_actor_id: 31,
      side: "attacker", diffculities: 4,
    }),
  });
  assert.equal(open.status, 200);
  const id = (await open.json() as any).battle_session_id;
  assert.ok(typeof id === "string" && id.length > 0);

  const snap = {
    battle_version: 2, battle_key: "b12-b31", tick: 1, elapsed_ms: 1200,
    diffculities: 4, side: "attacker", controlled_actor_id: 12, enemy_actor_id: 31,
    turn: 1, terrain: { name: "plain", is_city: false },
    controlled: {
      name: "张辽", hp: 90, soldiers: 1200, tactic_point: 10, buffs: [],
      units: [
        { type: "将", hp: 400, count: 1, order: "待机", x: 6, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
      ],
    },
    enemy: {
      name: "高顺", hp: 88, soldiers: 900, tactic_point: 8, buffs: [],
      units: [
        { type: "将", hp: 350, count: 1, order: "待机", x: 12, y: 5, shoot_range: 0, attack_range: 1, dist_to_other_main: 6, other_main_in_shoot_range: false },
      ],
    },
    legal_tactics: [],
    last_plan: null,
  };

  const tick = await fetch(base + "/ai/battle/" + id + "/tick", {
    method: "POST", headers: { "content-type": "text/plain" }, body: JSON.stringify(snap),
  });
  assert.equal(tick.status, 200);
  const result: any = await tick.json();
  assert.equal(result.tick, 1);
  assert.deepEqual(result.plan.orders, { 将: "前进" });

  const bad = await fetch(base + "/ai/battle/" + id + "/tick", {
    method: "POST", headers: { "content-type": "text/plain" },
    body: JSON.stringify({ ...snap, battle_version: 1 }),
  });
  assert.equal(bad.status, 422);

  const ended = await fetch(base + "/ai/battle/" + id + "/end", { method: "POST" });
  assert.equal(ended.status, 200);

  const after = await fetch(base + "/ai/battle/" + id + "/tick", {
    method: "POST", headers: { "content-type": "text/plain" }, body: JSON.stringify(snap),
  });
  assert.equal(after.status, 410);
});

test("白兵战 tick：battle_key / 旧 tick / actor 不匹配 422，未知与非法 id 410", async () => {
  const id = await openBattle();
  const first = await battlePost(id, "tick", battleSnapshot());
  assert.equal(first.status, 200);

  const stale = await battlePost(id, "tick", battleSnapshot());
  assert.equal(stale.status, 422);
  const staleBody: any = await stale.json();
  assert.equal(staleBody.error, "invalid_snapshot");
  assert.equal(staleBody.detail, "stale tick");
  assert.equal(staleBody.message, undefined);

  const keyed = await battlePost(id, "tick", battleSnapshot({ tick: 2, battle_key: "other" }));
  assert.equal(keyed.status, 422);
  const keyedBody: any = await keyed.json();
  assert.equal(keyedBody.error, "invalid_snapshot");
  assert.equal(keyedBody.detail, "battle_key mismatch");
  assert.equal(keyedBody.message, undefined);

  const actor = await battlePost(id, "tick", battleSnapshot({ tick: 2, controlled_actor_id: 99 }));
  assert.equal(actor.status, 422);
  assert.equal((await actor.json() as any).detail, "actor ids do not match session");

  // 未知会话
  const missing = await battlePost("nope", "tick", battleSnapshot());
  assert.equal(missing.status, 410);
  assert.equal((await missing.json() as any).error, "session_ended");

  // 非法 percent-encoding 不能 500
  const malformed = await battlePost("%E0%A4%A", "tick", battleSnapshot());
  assert.equal(malformed.status, 410);
  assert.equal((await malformed.json() as any).error, "session_ended");

  // /end 幂等：未知 id 和坏 id 都 200
  assert.equal((await battlePost("nope", "end")).status, 200);
  const badEnd = await battlePost("%E0%A4%A", "end");
  assert.equal(badEnd.status, 200);
  assert.deepEqual(await badEnd.json(), { ok: true });
});

test("白兵战路由边界：GET /ai/battle 405，GET tick 405，pending 404", async () => {
  const open = await fetch(base + "/ai/battle");
  assert.equal(open.status, 405);

  const getTick = await fetch(base + "/ai/battle/whatever/tick");
  assert.equal(getTick.status, 405);

  const pending = await fetch(base + "/ai/battle/whatever/pending");
  assert.equal(pending.status, 404);
});
