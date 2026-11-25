// 单进程同源服务：静态托管 bwdl/build/web/ + GET /ai/health + 回合会话三路由
//
// 服务端驱动的逐步交互：
//   POST /ai/turn             Godot 开启一个 AI 回合会话（后台跑 agent loop）
//   GET  /ai/turn/:id/pending 长轮询：取下一个待执行动作 / end / 空闲超时
//   POST /ai/turn/:id/result  Godot 执行完动作后回传最新状态
// 设计文档 §2.1 / §4.2。启动：node src/server.ts [--port 8060] [--mode mock|stub|pi]
import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseConfig, BUDGETS } from "./config.ts";
import {
  validateTurnRequest, validateToolResult, validateAnswers,
  validateBattleOpenRequest, validateBattleSnapshot, ValidationError,
} from "./validate.ts";
import { startTurn, ServiceError } from "./agent.ts";
import { startBattle, tickBattle, endBattle } from "./battle-agent.ts";
import { battleStore } from "./battle-session.ts";
import { traceStore } from "./trace.ts";
import { turnStore } from "./session.ts";
import { writeSlot, readAll, assertId, assertSlot, SaveError, cleanupExpired } from "./save-store.ts";

const MIME: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".wasm": "application/wasm",
  ".pck": "application/octet-stream",
  ".json": "application/json; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
};

const MAX_BODY = 1024 * 1024;

function json(res: http.ServerResponse, status: number, body: unknown): void {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    "content-type": "application/json; charset=utf-8",
    "content-length": Buffer.byteLength(data),
    "access-control-allow-origin": "*",
  });
  res.end(data);
}

async function readBody(req: http.IncomingMessage, limit = MAX_BODY): Promise<string> {
  const chunks: Buffer[] = [];
  let size = 0;
  let overflow = false;
  // 超限后继续读一小段再抛：直接 throw 会销毁请求流，客户端拿到连接重置而不是 413。
  // 但不能无上限排水，否则超大 body 会把带宽/IO 吃光。
  const drainCap = limit * 4 + 1024 * 1024;
  for await (const chunk of req) {
    const buf = Buffer.from(chunk);
    size += buf.length;
    if (size > limit) {
      overflow = true;
      if (size > drainCap) break;
      continue;
    }
    chunks.push(buf);
  }
  if (overflow) throw new ServiceError(413, "body_too_large", `request body exceeds ${limit} bytes`);
  return Buffer.concat(chunks).toString("utf8");
}

async function parseJsonBody(req: http.IncomingMessage): Promise<unknown> {
  const raw = await readBody(req);
  try {
    return JSON.parse(raw);
  } catch {
    throw new ServiceError(400, "bad_json", "body must be valid JSON");
  }
}

async function serveStatic(webDir: string, urlPath: string, res: http.ServerResponse): Promise<void> {
  const root = path.resolve(webDir);
  const rel = decodeURIComponent(urlPath === "/" ? "/index.html" : urlPath).replace(/^\/+/, "");
  const target = path.resolve(root, rel);
  if (target !== root && !target.startsWith(root + path.sep)) {
    json(res, 403, { error: "forbidden" });
    return;
  }
  try {
    const stat = await fs.stat(target);
    if (stat.isDirectory()) {
      json(res, 404, { error: "not_found" });
      return;
    }
    const data = await fs.readFile(target);
    res.writeHead(200, {
      "content-type": MIME[path.extname(target).toLowerCase()] ?? "application/octet-stream",
      "content-length": data.length,
      "cache-control": "no-cache",
    });
    res.end(data);
  } catch {
    json(res, 404, { error: "not_found", path: rel });
  }
}

export function createServer(config = parseConfig(process.argv.slice(2), process.env as Record<string, string | undefined>)) {
  return http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url ?? "/", "http://localhost");

      if (req.method === "OPTIONS") {
        res.writeHead(204, {
          "access-control-allow-origin": "*",
          "access-control-allow-methods": "GET,POST,PUT,OPTIONS",
          "access-control-allow-headers": "content-type,x-mock-case",
        });
        res.end();
        return;
      }

      if (url.pathname === "/ai/health") {
        // 探活/预算表：禁止缓存，避免浏览器或反向代理把探活结果固化
        res.setHeader("cache-control", "no-store");
        json(res, 200, { ok: true, mode: config.mode, bundle: "v1", node: ">=22.19", budgets: BUDGETS });
        return;
      }

      // ---- 调试面板：决策轨迹 API ----
      if (url.pathname === "/ai/traces") {
        if (req.method === "DELETE") {
          traceStore.clear();
          json(res, 200, { ok: true });
          return;
        }
        if (req.method === "GET") {
          json(res, 200, { traces: traceStore.list(), total: traceStore.size(), limit: Number(process.env.TRACE_LIMIT ?? 50) });
          return;
        }
        json(res, 405, { error: "method_not_allowed" });
        return;
      }

      if (url.pathname.startsWith("/ai/traces/")) {
        const id = decodeURIComponent(url.pathname.slice("/ai/traces/".length));
        const t = traceStore.get(id);
        if (!t) {
          json(res, 404, { error: "not_found" });
          return;
        }
        json(res, 200, t);
        return;
      }

      if (url.pathname === "/ai/dashboard" || url.pathname === "/ai/dashboard/") {
        const htmlPath = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../dashboard/index.html");
        try {
          const html = await fs.readFile(htmlPath, "utf8");
          const data = Buffer.from(html, "utf8");
          res.writeHead(200, {
            "content-type": "text/html; charset=utf-8",
            "content-length": data.length,
            "cache-control": "no-cache",
          });
          res.end(data);
        } catch {
          json(res, 500, { error: "dashboard_missing", path: htmlPath });
        }
        return;
      }

      // ---- 回合会话：开启 ----
      if (url.pathname === "/ai/turn") {
        if (req.method !== "POST") { json(res, 405, { error: "method_not_allowed" }); return; }
        const body = await parseJsonBody(req);
        const request = validateTurnRequest(body);
        const mockCase = req.headers["x-mock-case"] as string | undefined;
        const { session, budget } = startTurn(request, { mode: config.mode, config, mockCase });
        json(res, 200, {
          session_id: session.id,
          idle_timeout_ms: budget.idle_timeout_ms,
          poll_timeout_ms: Math.min(budget.idle_timeout_ms, 15000),
        });
        return;
      }

      // ---- 回合会话：长轮询取动作 ----
      if (url.pathname.startsWith("/ai/turn/") && url.pathname.endsWith("/pending")) {
        const id = decodeURIComponent(url.pathname.slice("/ai/turn/".length, -"/pending".length));
        const session = turnStore.get(id);
        if (!session) { json(res, 404, { error: "session_not_found" }); return; }
        const cap = Number(url.searchParams.get("wait_ms") ?? 15000);
        const wait = Math.max(0, Math.min(cap, session.idleRemaining()));
        const r = await session.nextAction(wait);
        if (r.type === "action") { json(res, 200, r); return; }
        if (r.type === "progress") { json(res, 200, r); return; }
        if (r.type === "ask") {
          console.log(`[diag] pending->ask sid=${id} asks=${JSON.stringify(r.asks)}`);
          json(res, 200, r); return;
        }
        if (r.type === "end") { json(res, 200, r); turnStore.delete(id); return; }
        if (r.type === "error") { json(res, 200, r); turnStore.delete(id); return; }
        // 本次轮询到点仍无动作：若已超出空闲预算，回传 idle_timeout 让 Godot 回退
        if (session.idleRemaining() <= 0) {
          json(res, 200, { type: "idle_timeout" });
          session.fail(new ServiceError(504, "agent_idle_timeout", "agent 空闲超时"));
          turnStore.delete(id);
          return;
        }
        // 否则让 Godot 重新挂起
        json(res, 200, { type: "retry" });
        return;
      }

      // ---- 回合会话：回传执行结果 ----
      if (url.pathname.startsWith("/ai/turn/") && url.pathname.endsWith("/result")) {
        if (req.method !== "POST") { json(res, 405, { error: "method_not_allowed" }); return; }
        const id = decodeURIComponent(url.pathname.slice("/ai/turn/".length, -"/result".length));
        const session = turnStore.get(id);
        if (!session) { json(res, 404, { error: "session_not_found" }); return; }
        const body = await parseJsonBody(req);
        const seq = Number((body as Record<string, unknown>)?.seq);
        if (!Number.isInteger(seq) || seq <= 0) {
          json(res, 400, { error: "bad_schema", message: "seq required" });
          return;
        }
        const payload = validateToolResult(body);
        session.submitResult(seq, payload);
        // 服务端若正在等「用计预估」，顺带把查询带回去（省一次长轮询往返）
        json(res, 200, { ok: true, sid: id, estimates: session.pendingAsks() });
        return;
      }

      // ---- 回合会话：回传只读查询结果（用计预估） ----
      if (url.pathname.startsWith("/ai/turn/") && url.pathname.endsWith("/estimate")) {
        if (req.method !== "POST") { json(res, 405, { error: "method_not_allowed" }); return; }
        const id = decodeURIComponent(url.pathname.slice("/ai/turn/".length, -"/estimate".length));
        const session = turnStore.get(id);
        if (!session) { json(res, 404, { error: "session_not_found" }); return; }
        const body = await parseJsonBody(req);
        const answers = validateAnswers(body);
        console.log(`[diag] estimate<-godot sid=${id} answers=${JSON.stringify(answers).slice(0, 400)}`);
        const touched = session.submitAnswers(answers);
        console.log(`[diag] estimate resolved touched=${touched} inflight=${(session as any).askInflight?.size ?? "?"}`);
        json(res, 200, { ok: true });
        return;
      }

      // ---- 白兵战会话：异步 tick ----
      if (url.pathname === "/ai/battle") {
        if (req.method !== "POST") { json(res, 405, { error: "method_not_allowed" }); return; }
        const body = await parseJsonBody(req);
        const request = validateBattleOpenRequest(body);
        const session = startBattle(request, { mode: config.mode, config });
        json(res, 200, { battle_session_id: session.id });
        return;
      }

      if (url.pathname.startsWith("/ai/battle/") && url.pathname.endsWith("/tick")) {
        if (req.method !== "POST") { json(res, 405, { error: "method_not_allowed" }); return; }
        const id = decodeURIComponent(url.pathname.slice("/ai/battle/".length, -"/tick".length));
        const session = battleStore.get(id);
        if (!session) { json(res, 404, { error: "session_not_found" }); return; }
        const body = await parseJsonBody(req);
        let snapshot: ReturnType<typeof validateBattleSnapshot>;
        try {
          snapshot = validateBattleSnapshot(body);
        } catch (err) {
          json(res, 422, { error: "invalid_snapshot", message: err instanceof Error ? err.message : String(err) });
          return;
        }
        if (snapshot.controlled_actor_id !== session.init.controlledActorId ||
            snapshot.enemy_actor_id !== session.init.enemyActorId) {
          json(res, 422, { error: "invalid_snapshot", message: "actor ids do not match session" });
          return;
        }
        const result = await tickBattle(session, snapshot, { mode: config.mode, config });
        json(res, 200, result);
        return;
      }

      if (url.pathname.startsWith("/ai/battle/") && url.pathname.endsWith("/end")) {
        if (req.method !== "POST") { json(res, 405, { error: "method_not_allowed" }); return; }
        const id = decodeURIComponent(url.pathname.slice("/ai/battle/".length, -"/end".length));
        const session = battleStore.get(id);
        if (session) endBattle(session);
        json(res, 200, { ok: true });
        return;
      }

      // ---- 云存档：PUT 单槽 / GET 整包 ----
      const saveMatch = /^\/save\/([^/]+)(?:\/([^/]+))?$/.exec(url.pathname);
      if (saveMatch) {
        let id: string;
        try {
          id = decodeURIComponent(saveMatch[1]);
        } catch {
          throw new SaveError(400, "bad_id", "id is not valid percent-encoding");
        }
        let slot: string | null = null;
        if (saveMatch[2] !== undefined) {
          try {
            slot = decodeURIComponent(saveMatch[2]);
          } catch {
            throw new SaveError(400, "bad_slot", "slot is not valid percent-encoding");
          }
        }

        if (slot === null) {
          if (req.method !== "GET") { json(res, 405, { error: "method_not_allowed" }); return; }
          const bundle = await readAll(config.saveDir, id);
          if (!bundle) { json(res, 404, { error: "not_found" }); return; }
          // 存档属于玩家数据，禁止中间层缓存
          res.setHeader("cache-control", "no-store");
          json(res, 200, {
            id, updatedAt: bundle.updatedAt, syncedSlots: bundle.syncedSlots, slots: bundle.slots,
          });
          return;
        }

        if (req.method !== "PUT") { json(res, 405, { error: "method_not_allowed" }); return; }
        // 先校验再读 body：非法槽位不该先吃掉 32MiB 的上传
        assertId(id);
        assertSlot(slot);
        const limitBytes = config.saveMaxMb * 1024 * 1024;
        const raw = await readBody(req, limitBytes);
        let parsed: unknown;
        try {
          parsed = JSON.parse(raw);
        } catch {
          throw new SaveError(400, "bad_json", "body must be valid JSON");
        }
        if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
          throw new SaveError(400, "bad_json", "body must be a JSON object");
        }
        const result = await writeSlot({
          root: config.saveDir, id, slot, raw,
          maxBytes: limitBytes,
          maxTotalBytes: config.saveTotalMb * 1024 * 1024,
        });
        json(res, 200, { ok: true, slot, ...result });
        return;
      }

      if (req.method === "GET" || req.method === "HEAD") {
        await serveStatic(config.webDir, url.pathname, res);
        return;
      }

      json(res, 404, { error: "not_found" });
    } catch (err) {
      if (err instanceof ValidationError) {
        json(res, 400, { error: err.code, message: err.message });
      } else if (err instanceof ServiceError) {
        json(res, err.status, { error: err.code, message: err.message });
      } else if (err instanceof SaveError) {
        json(res, err.status, { error: err.code, message: err.message });
      } else {
        json(res, 500, { error: "internal_error", message: err instanceof Error ? err.message : String(err) });
      }
    }
  });
}

const invokedDirectly = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (invokedDirectly) {
  const config = parseConfig(process.argv.slice(2), process.env as Record<string, string | undefined>);
  createServer(config).listen(config.port, () => {
    console.log(`[3k-war-agent] mode=${config.mode} http://localhost:${config.port}/ webDir=${config.webDir} saveDir=${config.saveDir}`);
  });
  const runCleanup = () => {
    cleanupExpired(config.saveDir, config.saveTtlDays)
      .then((n) => { if (n > 0) console.log(`[save] cleanup removed ${n} expired slot(s)`); })
      .catch((err) => console.warn(`[save] cleanup failed: ${err instanceof Error ? err.message : String(err)}`));
  };
  void runCleanup();
  setInterval(runCleanup, 6 * 3600_000).unref();
}
