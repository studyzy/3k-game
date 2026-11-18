// 单进程同源服务：静态托管 bwdl/build/web/ + GET /ai/health + POST /ai/decide
// 设计文档 §2.1 / §4.2。启动：node src/server.ts [--port 8060] [--mode mock|stub|pi]
import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseConfig, BUDGETS } from "./config.ts";
import { validateRequest, ValidationError } from "./validate.ts";
import { decide, ServiceError } from "./agent.ts";
import { traceStore } from "./trace.ts";

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

async function readBody(req: http.IncomingMessage): Promise<string> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    const buf = Buffer.from(chunk);
    size += buf.length;
    if (size > MAX_BODY) throw new ServiceError(413, "body_too_large", "request body exceeds 1 MiB");
    chunks.push(buf);
  }
  return Buffer.concat(chunks).toString("utf8");
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
          "access-control-allow-methods": "GET,POST,OPTIONS",
          "access-control-allow-headers": "content-type,x-mock-case",
        });
        res.end();
        return;
      }

      if (url.pathname === "/ai/health") {
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

      if (url.pathname === "/ai/decide") {
        if (req.method !== "POST") {
          json(res, 405, { error: "method_not_allowed" });
          return;
        }
        const raw = await readBody(req);
        let body: unknown;
        try {
          body = JSON.parse(raw);
        } catch {
          json(res, 400, { error: "bad_json" });
          return;
        }
        const request = validateRequest(body);
        const mockCase = req.headers["x-mock-case"] as string | undefined;
        const response = await decide(request, { mode: config.mode, config, mockCase });
        json(res, 200, response);
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
    console.log(`[3k-war-agent] mode=${config.mode} http://localhost:${config.port}/ webDir=${config.webDir}`);
  });
}
