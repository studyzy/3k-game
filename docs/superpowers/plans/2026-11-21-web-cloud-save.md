# 网页版云存档（单数槽位网络存档）Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 让 WebAssembly 网页版的单数手动存档位在保存时同步到 `agent-service`，并用 URL 里的 UUID 换设备恢复。

**Architecture:** 服务端在现有 `agent-service` 上新增 `PUT /save/:id/:slot` 与 `GET /save/:id`，存储为 `<SAVE_DIR>/<uuid>/<slot>.json`（一槽一文件、tmp+rename 原子写）。客户端新增 autoload `CloudSave` 负责 ID 解析、上传队列、下载合并；存档界面按槽位奇偶打「（网络）/（本地）」标记，启动时拉到云端槽位后按 `存档时间` 只合并单数槽位。

**Tech Stack:** Node 22+ 直接跑 TypeScript（无构建）、`node --test`、Godot 3.6.3 / GDScript 1.0、`HTTPRequest`、浏览器 IndexedDB（`user://`）。

**Spec:** `docs/superpowers/specs/2026-11-21-web-cloud-save-design.md`

**约定：**
- agent-service 的测试命令统一在 `agent-service/` 下执行：`npm test`（= `node --test test/*.test.ts`）。
- Godot 校验命令在仓库根执行：`make check`（headless 加载全部脚本），AI 脚本清单校验用 `cd agent-service && npm test`。
- 每个 Task 结束都提交一次，commit message 用中文、前缀 `feat(save):` / `test(save):` / `docs(save):`。

---

### Task 1: 服务端配置项

**Files:**
- Modify: `agent-service/src/config.ts:26-63`
- Modify: `agent-service/test/fixture.ts:48-61`
- Test: 现有 `agent-service/test/server.test.ts`（回归，不新增断言）

**Step 1: 给 `ServiceConfig` 加四个字段**

`agent-service/src/config.ts` 的 `interface ServiceConfig` 末尾（`llmMaxTokens: number;` 之后）追加：

```ts
  /** 云存档目录：每个 ID 一个子目录，每个槽位一个 <slot>.json。 */
  saveDir: string;
  /** 单个槽位文件上限（MiB）。 */
  saveMaxMb: number;
  /** 单个云存档 ID 的总量上限（MiB）。 */
  saveTotalMb: number;
  /** 槽位文件多少天未更新后清理。 */
  saveTtlDays: number;
```

**Step 2: `parseConfig` 读取参数与环境变量**

`parseConfig` 的 return 对象里、`llmMaxTokens` 之后追加（保持 `argValue` + env 回退的既有风格）：

```ts
    saveDir: argValue(argv, "save-dir") ?? env.SAVE_DIR ?? "data/saves",
    saveMaxMb: Number(argValue(argv, "save-max-mb") ?? env.SAVE_MAX_MB ?? 32),
    saveTotalMb: Number(argValue(argv, "save-total-mb") ?? env.SAVE_TOTAL_MB ?? 2048),
    saveTtlDays: Number(argValue(argv, "save-ttl-days") ?? env.SAVE_TTL_DAYS ?? 365),
```

**Step 3: 更新测试夹具**

`agent-service/test/fixture.ts` 的 `testConfig` 里、`llmMaxTokens: 8192,` 之后追加（默认值只为类型完整，各测试自行覆盖 `saveDir`）：

```ts
  saveDir: "data/saves",
  saveMaxMb: 32,
  saveTotalMb: 2048,
  saveTtlDays: 365,
```

**Step 4: 跑回归**

Run: `cd agent-service && npm test`
Expected: 全部通过（此刻行为未变，只是多了配置字段）。

**Step 5: Commit**

```bash
git add agent-service/src/config.ts agent-service/test/fixture.ts
git commit -m "feat(save): 云存档配置项（目录/单槽上限/单 ID 总量/TTL）"
```

---

### Task 2: 云存档文件存储模块

**Files:**
- Create: `agent-service/src/save-store.ts`
- Test: `agent-service/test/save-store.test.ts`

这个模块只做文件系统与校验，不懂 HTTP，方便单测。路由层（Task 3）只负责读 body 和拼 JSON。

**Step 1: 先写失败的测试**

Create `agent-service/test/save-store.test.ts`：

```ts
import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {
  writeSlot, readAll, cleanupExpired, isNetworkSlot, SaveError, idDir, assertSlot, assertId,
} from "../src/save-store.ts";

const ID = "3f2b8c1e-9d4a-4b7f-8c21-5e6a0b9d7c31";
const ID2 = "0a1b2c3d-4e5f-4a6b-8c7d-9e0f1a2b3c4d";
const LIMITS = { maxBytes: 1 << 20, maxTotalBytes: 8 << 20 };

let root: string;

before(async () => { root = await fs.mkdtemp(path.join(os.tmpdir(), "3k-saves-")); });
after(async () => { await fs.rm(root, { recursive: true, force: true }); });

test("奇数槽位才算网络存档", () => {
  assert.equal(isNetworkSlot("1"), true);
  assert.equal(isNetworkSlot("51"), true);
  assert.equal(isNetworkSlot("0"), false);
  assert.equal(isNetworkSlot("2"), false);
  assert.equal(isNetworkSlot("52"), false);
  assert.equal(isNetworkSlot("endless"), false);
});

test("writeSlot 后 readAll 取回同一份 JSON", async () => {
  const raw = JSON.stringify({ 存档时间: "2026-11-21 10:00:00", lordName: "曹操" });
  const wrote = await writeSlot({ root, id: ID, slot: "1", raw, ...LIMITS });
  assert.equal(wrote.syncedSlots, 1);
  const bundle = await readAll(root, ID);
  assert.ok(bundle);
  assert.equal(bundle.syncedSlots, 1);
  assert.equal((bundle.slots["1"] as any)["lordName"], "曹操");
});

test("没有存档的 ID 返回 null", async () => {
  assert.equal(await readAll(root, ID2), null);
});

test("覆盖一个槽位不影响另一个槽位", async () => {
  await writeSlot({ root, id: ID, slot: "3", raw: JSON.stringify({ 存档时间: "2026-11-21 11:00:00" }), ...LIMITS });
  await writeSlot({ root, id: ID, slot: "1", raw: JSON.stringify({ 存档时间: "2026-11-21 12:00:00" }), ...LIMITS });
  const bundle = await readAll(root, ID);
  assert.ok(bundle);
  assert.equal(bundle.syncedSlots, 2);
  assert.equal((bundle.slots["1"] as any)["存档时间"], "2026-11-21 12:00:00");
  assert.equal((bundle.slots["3"] as any)["存档时间"], "2026-11-21 11:00:00");
});

test("非法 UUID / 非法槽位都拒绝", async () => {
  assert.throws(() => assertId("nope"), SaveError);
  assert.throws(() => assertSlot("2"), SaveError);
  assert.throws(() => assertSlot("52"), SaveError);
  assert.throws(() => assertSlot("endless"), SaveError);
  assertSlot("1");
  assertSlot("51");
});

test("单槽超限 → 413", async () => {
  await assert.rejects(
    writeSlot({ root, id: ID2, slot: "1", raw: "x".repeat(200), maxBytes: 100, maxTotalBytes: 1000 }),
    (err: any) => err instanceof SaveError && err.status === 413,
  );
});

test("单 ID 总量超限 → 413，且不写坏已有槽位", async () => {
  const id = "11111111-2222-4333-8444-555555555555";
  await writeSlot({ root, id, slot: "1", raw: "a".repeat(60), maxBytes: 1000, maxTotalBytes: 100 });
  await assert.rejects(
    writeSlot({ root, id, slot: "3", raw: "b".repeat(60), maxBytes: 1000, maxTotalBytes: 100 }),
    (err: any) => err instanceof SaveError && err.status === 413,
  );
  const bundle = await readAll(root, id);
  assert.ok(bundle);
  assert.equal(bundle.syncedSlots, 1);
});

test("损坏文件被跳过而不是整包失败", async () => {
  const id = "22222222-3333-4444-8555-666666666666";
  await writeSlot({ root, id, slot: "5", raw: JSON.stringify({ 存档时间: "2026-11-21 09:00:00" }), ...LIMITS });
  await fs.writeFile(path.join(idDir(root, id), "7.json"), "{not json", "utf8");
  await fs.writeFile(path.join(idDir(root, id), "notes.txt"), "hello", "utf8");
  const bundle = await readAll(root, id);
  assert.ok(bundle);
  assert.equal(bundle.syncedSlots, 1);
  assert.deepEqual(Object.keys(bundle.slots), ["5"]);
});

test("TTL 清理删掉过期文件并向空目录收尸", async () => {
  const id = "33333333-4444-4555-8666-777777777777";
  await writeSlot({ root, id, slot: "1", raw: JSON.stringify({ ok: 1 }), ...LIMITS });
  const file = path.join(idDir(root, id), "1.json");
  const old = new Date(Date.now() - 400 * 86400_000);
  await fs.utimes(file, old, old);
  const removed = await cleanupExpired(root, 365);
  assert.equal(removed, 1);
  await assert.rejects(fs.stat(file));
  // 目录空了应该被删掉
  await assert.rejects(fs.stat(idDir(root, id)));
});
```

**Step 2: 跑测试确认失败**

Run: `cd agent-service && node --test test/save-store.test.ts`
Expected: FAIL，`Cannot find module '../src/save-store.ts'`。

**Step 3: 实现 `save-store.ts`**

Create `agent-service/src/save-store.ts`（完整文件）：

```ts
// 云存档文件存储：<root>/<uuid>/<slot>.json，一槽一文件。
//
// 为什么不是「一个 ID 一个 JSON」：单文件方案每次 PUT 都要读-改-写整个文件，
// 两台设备各存一个槽位会互相覆盖。分文件后每个槽位独立原子写（tmp + rename）。
import fs from "node:fs/promises";
import path from "node:path";

/** 只接受 UUID v4：crypto.randomUUID() 的产物。 */
export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
/** 手动槽位 0..51。 */
export const SLOT_RE = /^(?:0|[1-9]|[1-4][0-9]|5[01])$/;
const SLOT_FILE_RE = /^([0-9]{1,2})\.json$/;

export class SaveError extends Error {
  status: number;
  code: string;
  constructor(status: number, code: string, message: string) {
    super(message);
    this.name = "SaveError";
    this.status = status;
    this.code = code;
  }
}

/** 奇数槽位 = 网络存档（显示编号 #1 #3 … #51）。 */
export function isNetworkSlot(slot: string): boolean {
  if (!SLOT_RE.test(slot)) return false;
  return Number(slot) % 2 === 1;
}

/** 日志里只留前 8 位，避免完整 ID 进日志。 */
export function maskId(id: string): string {
  return id.length <= 8 ? "…" : id.slice(0, 8) + "…";
}

export function assertId(id: string): void {
  if (!UUID_RE.test(id)) throw new SaveError(400, "bad_id", "id must be a UUID v4");
}

export function assertSlot(slot: string): void {
  if (!SLOT_RE.test(slot)) throw new SaveError(400, "bad_slot", "slot must be 0..51");
  if (!isNetworkSlot(slot)) throw new SaveError(400, "bad_slot", "only odd slots are stored in the cloud");
}

export function idDir(root: string, id: string): string {
  return path.join(path.resolve(root), id);
}

async function dirSize(dir: string): Promise<number> {
  let names: string[] = [];
  try { names = await fs.readdir(dir); } catch { return 0; }
  let total = 0;
  for (const name of names) {
    try { total += (await fs.stat(path.join(dir, name))).size; } catch { /* 并发删除，忽略 */ }
  }
  return total;
}

async function countSlots(dir: string): Promise<number> {
  try { return (await fs.readdir(dir)).filter((n) => SLOT_FILE_RE.test(n)).length; } catch { return 0; }
}

export interface WriteSlotOptions {
  root: string;
  id: string;
  slot: string;
  raw: string;
  maxBytes: number;
  maxTotalBytes: number;
}

/** 写入或覆盖一个槽位；成功返回当前 ID 下的槽位总数与最新 mtime。 */
export async function writeSlot(opts: WriteSlotOptions): Promise<{ syncedSlots: number; updatedAt: string }> {
  const { root, id, slot, raw, maxBytes, maxTotalBytes } = opts;
  assertId(id);
  assertSlot(slot);

  const bytes = Buffer.byteLength(raw);
  if (bytes > maxBytes) throw new SaveError(413, "slot_too_large", `slot exceeds ${maxBytes} bytes`);

  const dir = idDir(root, id);
  await fs.mkdir(dir, { recursive: true });
  const target = path.join(dir, `${slot}.json`);

  let previous = 0;
  try { previous = (await fs.stat(target)).size; } catch { previous = 0; }
  const used = (await dirSize(dir)) - previous;
  if (used + bytes > maxTotalBytes) throw new SaveError(413, "id_quota_exceeded", `id exceeds ${maxTotalBytes} bytes`);

  const tmp = `${target}.${process.pid}.${Date.now()}.tmp`;
  try {
    await fs.writeFile(tmp, raw, "utf8");
    await fs.rename(tmp, target);
  } catch (err) {
    await fs.unlink(tmp).catch(() => {});
    throw err;
  }

  const stat = await fs.stat(target);
  return { syncedSlots: await countSlots(dir), updatedAt: stat.mtime.toISOString() };
}

export interface SaveBundle {
  slots: Record<string, unknown>;
  syncedSlots: number;
  updatedAt: string;
}

/** 读回一个 ID 下所有槽位；一个合法槽位都没有时返回 null。 */
export async function readAll(root: string, id: string): Promise<SaveBundle | null> {
  assertId(id);
  const dir = idDir(root, id);
  let names: string[] = [];
  try { names = await fs.readdir(dir); } catch { return null; }

  const slots: Record<string, unknown> = {};
  let newest = 0;
  for (const name of names) {
    const m = SLOT_FILE_RE.exec(name);
    if (!m) continue;
    const slot = m[1];
    const file = path.join(dir, name);
    try {
      const [raw, stat] = await Promise.all([fs.readFile(file, "utf8"), fs.stat(file)]);
      const parsed = JSON.parse(raw);
      if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
        throw new Error("not a JSON object");
      }
      slots[slot] = parsed;
      if (stat.mtimeMs > newest) newest = stat.mtimeMs;
    } catch (err) {
      console.warn(`[save] skip corrupt slot id=${maskId(id)} slot=${slot}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  const count = Object.keys(slots).length;
  if (count === 0) return null;
  return { slots, syncedSlots: count, updatedAt: new Date(newest).toISOString() };
}

/** 删除 mtime 早于 ttlDays 的槽位文件，并删掉空 ID 目录；返回删除的文件数。 */
export async function cleanupExpired(root: string, ttlDays: number, now = Date.now()): Promise<number> {
  const cutoff = now - ttlDays * 86400_000;
  let entries: string[] = [];
  try { entries = await fs.readdir(root); } catch { return 0; }

  let removed = 0;
  for (const name of entries) {
    const dir = path.join(root, name);
    let files: string[] = [];
    try { files = await fs.readdir(dir); } catch { continue; }
    for (const f of files) {
      const file = path.join(dir, f);
      try {
        const stat = await fs.stat(file);
        if (stat.isFile() && stat.mtimeMs < cutoff) {
          await fs.unlink(file);
          removed++;
        }
      } catch { /* 已删除 */ }
    }
    // 目录空了就收尸；非空会抛 ENOTEMPTY，忽略
    try { await fs.rmdir(dir); } catch { /* 非空或已删除 */ }
  }
  return removed;
}
```

**Step 4: 跑测试确认通过**

Run: `cd agent-service && node --test test/save-store.test.ts`
Expected: PASS，9 个测试全绿（`skip corrupt slot` 会打印一条 stderr 警告，属正常）。

**Step 5: Commit**

```bash
git add agent-service/src/save-store.ts agent-service/test/save-store.test.ts
git commit -m "feat(save): 云存档文件存储（一槽一文件/原子写/配额/TTL）"
```

---

### Task 3: HTTP 路由与端到端测试

**Files:**
- Modify: `agent-service/src/server.ts:34`（`readBody` 上限参数化）、`:98-105`（OPTIONS）、`:280` 之前（新增存档路由）、`:286-293`（错误分支）、`:298-304`（启动清理）
- Test: `agent-service/test/save.test.ts`

**Step 1: 先写失败的 HTTP 测试**

Create `agent-service/test/save.test.ts`：

```ts
import test, { before, after } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { createServer } from "../src/server.ts";
import { testConfig } from "./fixture.ts";

const ID = "3f2b8c1e-9d4a-4b7f-8c21-5e6a0b9d7c31";
const SAVE = { 存档时间: "2026-11-21 10:00:00", lordName: "曹操", year: 200, month: 3 };

let server: http.Server;
let base: string;
let tmpDir: string;
let saveDir: string;

before(async () => {
  tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), "3k-saveweb-"));
  saveDir = path.join(tmpDir, "saves");
  await fs.writeFile(path.join(tmpDir, "index.html"), "<html>3k</html>");
  server = createServer({ ...testConfig, webDir: tmpDir, saveDir, saveMaxMb: 1, saveTotalMb: 2 });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const addr = server.address();
  assert.ok(addr && typeof addr === "object");
  base = `http://127.0.0.1:${addr.port}`;
});

after(async () => {
  await new Promise<void>((resolve) => server.close(() => resolve()));
  await fs.rm(tmpDir, { recursive: true, force: true });
});

function put(id: string, slot: string, body: unknown) {
  return fetch(`${base}/save/${id}/${slot}`, {
    method: "PUT",
    headers: { "content-type": "text/plain; charset=utf-8" },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

test("没有存档时 GET 返回 404", async () => {
  const res = await fetch(`${base}/save/${ID}`);
  assert.equal(res.status, 404);
});

test("PUT 单槽 → 200 且 GET 能取回", async () => {
  const res = await put(ID, "1", SAVE);
  assert.equal(res.status, 200);
  const body: any = await res.json();
  assert.equal(body.ok, true);
  assert.equal(body.slot, "1");
  assert.equal(body.syncedSlots, 1);

  const got = await fetch(`${base}/save/${ID}`).then((r) => r.json() as any);
  assert.equal(got.syncedSlots, 1);
  assert.equal(got.slots["1"].lordName, "曹操");
});

test("写另一个槽位不会覆盖已有槽位", async () => {
  await put(ID, "3", { ...SAVE, 存档时间: "2026-11-21 11:00:00" });
  const got = await fetch(`${base}/save/${ID}`).then((r) => r.json() as any);
  assert.equal(got.syncedSlots, 2);
  assert.equal(got.slots["1"].存档时间, "2026-11-21 10:00:00");
  assert.equal(got.slots["3"].存档时间, "2026-11-21 11:00:00");
});

test("非法 UUID / 双数槽位 / 越界槽位 → 400", async () => {
  assert.equal((await put("nope", "1", SAVE)).status, 400);
  assert.equal((await put(ID, "0", SAVE)).status, 400);
  assert.equal((await put(ID, "2", SAVE)).status, 400);
  assert.equal((await put(ID, "52", SAVE)).status, 400);
  assert.equal((await put(ID, "abc", SAVE)).status, 400);
});

test("非 JSON / 数组 / null → 400", async () => {
  assert.equal((await put(ID, "5", "{not json")).status, 400);
  assert.equal((await put(ID, "5", "[1,2]")).status, 400);
  assert.equal((await put(ID, "5", "null")).status, 400);
});

test("单槽超过 saveMaxMb → 413", async () => {
  const huge = "x".repeat(1024 * 1024 + 10);
  assert.equal((await put(ID, "7", huge)).status, 413);
});

test("目录里的坏文件不影响 GET", async () => {
  const dir = path.join(saveDir, ID);
  await fs.writeFile(path.join(dir, "9.json"), "broken", "utf8");
  await fs.writeFile(path.join(dir, "readme.txt"), "x", "utf8");
  const res = await fetch(`${base}/save/${ID}`);
  assert.equal(res.status, 200);
  const got: any = await res.json();
  assert.equal(got.slots["9"], undefined);
});

test("OPTIONS 允许 PUT", async () => {
  const res = await fetch(`${base}/save/${ID}/1`, { method: "OPTIONS" });
  assert.equal(res.status, 204);
  assert.match(String(res.headers.get("access-control-allow-methods")), /PUT/);
});

test("静态资源不受影响", async () => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  assert.match(await res.text(), /3k/);
});
```

注意：`saveMaxMb: 1` 同时是「单槽上限 1MiB」和「单 ID 总量 2MiB」，上面的用例都在这个范围内。测试共用同一个 ID，靠执行顺序累积槽位；`node --test` 单文件内是顺序执行的，不要拆成多个文件。

**Step 2: 跑测试确认失败**

Run: `cd agent-service && node --test test/save.test.ts`
Expected: FAIL，`GET /save/:id` 落到静态托管后返回 404 或 `not_found`，PUT 用例全部失败。

**Step 3: `readBody` 支持独立上限**

`agent-service/src/server.ts` 第 34 行下方、`readBody` 改为：

```ts
async function readBody(req: http.IncomingMessage, limit = MAX_BODY): Promise<string> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    const buf = Buffer.from(chunk);
    size += buf.length;
    if (size > limit) throw new ServiceError(413, "body_too_large", `request body exceeds ${limit} bytes`);
    chunks.push(buf);
  }
  return Buffer.concat(chunks).toString("utf8");
}
```

AI 路由继续走默认 `MAX_BODY = 1MiB`，不要改它。

**Step 4: OPTIONS 增加 PUT**

第 101 行：

```ts
          "access-control-allow-methods": "GET,POST,PUT,OPTIONS",
```

**Step 5: 新增路由**

顶部 import 追加：

```ts
import { writeSlot, readAll, assertId, assertSlot, SaveError } from "./save-store.ts";
```

在 `if (req.method === "GET" || req.method === "HEAD") {`（静态托管兜底）**之前**插入：

```ts
      // ---- 云存档：PUT 单槽 / GET 整包 ----
      const saveMatch = /^\/save\/([^/]+)(?:\/([^/]+))?$/.exec(url.pathname);
      if (saveMatch) {
        const id = decodeURIComponent(saveMatch[1]);
        const slot = saveMatch[2] === undefined ? null : decodeURIComponent(saveMatch[2]);

        if (slot === null) {
          if (req.method !== "GET") { json(res, 405, { error: "method_not_allowed" }); return; }
          const bundle = await readAll(config.saveDir, id);
          if (!bundle) { json(res, 404, { error: "not_found" }); return; }
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
```

**Step 6: 错误分支认 `SaveError`**

catch 里，`ServiceError` 分支之后追加：

```ts
      } else if (err instanceof SaveError) {
        json(res, err.status, { error: err.code, message: err.message });
```

**Step 7: 启动时清理过期存档**

`agent-service/src/server.ts` 末尾 `if (invokedDirectly) { ... }` 改为：

```ts
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
```

import 行补上 `cleanupExpired`。

**Step 8: 跑全部 Node 测试**

Run: `cd agent-service && npm test`
Expected: PASS。`save.test.ts` 9 个用例 + 既有 `server.test.ts` / `save-store.test.ts` 全绿。

**Step 9: Commit**

```bash
git add agent-service/src/server.ts agent-service/test/save.test.ts
git commit -m "feat(save): PUT /save/:id/:slot 与 GET /save/:id 路由"
```

---

### Task 4: 客户端 `CloudSave` autoload

**Files:**
- Create: `bwdl/script/Cloud_Save.gd`
- Modify: `bwdl/project.godot:216-232`（autoload 清单末尾）
- Create: `bwdl/test/cloud_save_validate.gd`
- Modify: `bwdl/test/ai_agent_validate.gd:14-24`（脚本清单加一行）

**测试说明：** Godot 侧没有单测框架，本仓库的既有做法是「headless 里 `load()` 脚本 + 断言纯函数」。`Cloud_Save.gd` 因此把可验证的逻辑写成不依赖树的实例方法（`is_network_slot` / `is_valid_uuid` / `is_newer`），校验脚本 `new()` 一个实例直接调。

**Step 1: 先写失败的校验脚本**

Create `bwdl/test/cloud_save_validate.gd`：

```gdscript
# ==============================================================================
# 文件：test/cloud_save_validate.gd
# 说明：headless 下校验 Cloud_Save.gd 可加载，并断言槽位/UUID/时间比较三个纯函数。
# 用法：
#   Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl \
#       --script res://test/cloud_save_validate.gd
# ==============================================================================
extends SceneTree

func _init():
	var bad = 0
	var script = load("res://script/Cloud_Save.gd")
	if script == null:
		print("CLOUD_SAVE FAIL load")
		print("CLOUD_SAVE_RESULT=1")
		quit()
		return

	var inst = script.new()

	var slot_cases = [
		["0", false], ["1", true], ["2", false], ["3", true], ["51", true],
		["52", false], ["01", false], ["endless", false], ["", false],
	]
	for c in slot_cases:
		var got = inst.is_network_slot(c[0])
		if got != c[1]:
			print("CLOUD_SAVE FAIL slot ", c[0], " got=", got, " want=", c[1])
			bad += 1

	if not inst.is_valid_uuid("3f2b8c1e-9d4a-4b7f-8c21-5e6a0b9d7c31"):
		print("CLOUD_SAVE FAIL uuid 合法值被判非法")
		bad += 1
	for v in ["", "nope", "3f2b8c1e-9d4a-4b7f-8c21", "3f2b8c1e-9d4a-1b7f-8c21-5e6a0b9d7c31"]:
		if inst.is_valid_uuid(v):
			print("CLOUD_SAVE FAIL uuid 非法值被判合法: ", v)
			bad += 1

	if not inst.is_newer("2026-11-21 10:00:00", "2026-11-20 23:59:59"):
		print("CLOUD_SAVE FAIL is_newer 云端较新")
		bad += 1
	if inst.is_newer("2026-11-20 10:00:00", "2026-11-21 10:00:00"):
		print("CLOUD_SAVE FAIL is_newer 本地较新")
		bad += 1
	if not inst.is_newer("2026-11-21 10:00:00", ""):
		print("CLOUD_SAVE FAIL is_newer 本地为空")
		bad += 1
	if inst.is_newer("", "2026-11-21 10:00:00"):
		print("CLOUD_SAVE FAIL is_newer 云端为空")
		bad += 1

	inst.free()
	print("CLOUD_SAVE_RESULT=", bad)
	quit()
```

**Step 2: 跑一次确认失败**

Run: `Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl --script res://test/cloud_save_validate.gd`
Expected: `CLOUD_SAVE FAIL load` + `CLOUD_SAVE_RESULT=1`（文件还不存在）。

**Step 3: 实现 `Cloud_Save.gd`**

Create `bwdl/script/Cloud_Save.gd`（完整文件）：

```gdscript
# ==============================================================================
# 新增：云存档（网页版）
# 文件：script/Cloud_Save.gd
# 说明：负责 URL 里的云存档 ID、单槽上传、整包下载与合并。
#       仅在 HTML5 导出下启用；桌面/安卓上所有入口都是空操作。
#       设计：docs/superpowers/specs/2026-11-21-web-cloud-save-design.md
# ==============================================================================
extends Node

const ID_FILE = "user://sgz/cloud_id.txt"
const HTTP_TIMEOUT = 30
const SLOT_MIN = 0
const SLOT_MAX = 51

var enabled := false
var cloud_id := ""
var synced_slots := 0

var _http: HTTPRequest = null
var _busy := false
var _current := {}
var _pending := {}
var _get_owner: Object = null
var _get_method := ""

func _ready() -> void:
	enabled = is_web()
	return

func is_web() -> bool:
	return OS.get_name() == "HTML5"

# ---- 纯逻辑（headless 可验证） ----

func is_valid_uuid(value: String) -> bool:
	var re = RegEx.new()
	re.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
	return re.search(value) != null

# 显示编号为奇数的手动槽位才是网络存档，且必须落在 0..51。
func is_network_slot(slot: String) -> bool:
	if not slot.is_valid_integer():
		return false
	if str(int(slot)) != slot:
		return false
	var n = int(slot)
	return n >= SLOT_MIN and n <= SLOT_MAX and n % 2 == 1

# "YYYY-MM-DD HH:MM:SS" 定长格式，字符串比较即时间比较；空串视为最旧。
func is_newer(remote: String, local: String) -> bool:
	if remote == "":
		return false
	if local == "":
		return true
	return remote > local

# ---- ID 与 URL ----

func ensure_id() -> String:
	if not enabled:
		return ""
	var from_url = _id_from_url()
	if from_url != "":
		cloud_id = from_url
		_write_id(cloud_id)
		return cloud_id
	var stored = Global.get_file_text(ID_FILE).strip_edges()
	if is_valid_uuid(stored):
		cloud_id = stored
		_replace_url_id(cloud_id)
		return cloud_id
	cloud_id = _new_uuid()
	_write_id(cloud_id)
	_replace_url_id(cloud_id)
	return cloud_id

func _id_from_url() -> String:
	if not enabled:
		return ""
	var value = String(JavaScript.eval(
		"(function(){try{var v=new URLSearchParams(location.search).get('save');return v?v:'';}catch(e){return '';}})()", true))
	return value if is_valid_uuid(value) else ""

func _replace_url_id(value: String) -> void:
	if not enabled:
		return
	# 用 URLSearchParams 回写，保留 URL 上的其它查询参数
	JavaScript.eval(
		"(function(){try{var u=new URLSearchParams(location.search);u.set('save','%s');history.replaceState(null,'',location.pathname+'?'+u.toString()+location.hash);}catch(e){}})()" % value, true)
	return

func _new_uuid() -> String:
	if enabled:
		var v = String(JavaScript.eval(
			"(function(){try{if(window.crypto&&crypto.randomUUID){return crypto.randomUUID();}}catch(e){}return '';})()", true))
		if is_valid_uuid(v):
			return v
	return _fallback_uuid()

# crypto.randomUUID 需要安全上下文（https/localhost），局域网 http 下用这个兜底。
func _fallback_uuid() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var hex = "0123456789abcdef"
	var parts = []
	for group in [8, 4, 4, 4, 12]:
		var s = ""
		for i in group:
			s += hex[rng.randi_range(0, 15)]
		parts.append(s)
	var seg2 = "4" + parts[1].substr(1)
	var seg3 = "89ab"[rng.randi_range(0, 3)] + parts[2].substr(1)
	return "%s-%s-%s-%s-%s" % [parts[0], seg2, seg3, parts[3], parts[4]]

func _write_id(value: String) -> void:
	var dir = Directory.new()
	if not dir.dir_exists("user://sgz"):
		dir.make_dir_recursive("user://sgz")
	Global.save_file_text(ID_FILE, value)
	return

# ---- 上传 / 下载队列 ----

func begin_session(owner: Object, method: String) -> void:
	if not enabled:
		return
	if ensure_id() == "":
		return
	_get_owner = owner
	_get_method = method
	_enqueue({"kind": "get"})
	return

func upload_slot(slot: String, save_path: String) -> void:
	if not enabled or cloud_id == "":
		return
	if not is_network_slot(slot):
		return
	_enqueue({"kind": "put", "slot": slot, "path": save_path})
	return

func _enqueue(action: Dictionary) -> void:
	# 只保留最后一次待办：上传途中又存了一次档，前一份已经过时
	_pending = action
	if _busy:
		return
	_start_next()
	return

func _start_next() -> void:
	if _pending.empty():
		_busy = false
		return
	var action = _pending
	_pending = {}
	_busy = true
	_current = action
	if str(action["kind"]) == "get":
		_request_get()
	else:
		_request_put(action)
	return

func _request_get() -> void:
	if not _ensure_http():
		_finish_get({"ok": false, "slots": {}, "total": 0, "error": "http_unavailable"})
		return
	var url = _base_url() + "/save/" + cloud_id
	var err = _http.request(url, PoolStringArray(["Cache-Control: no-cache"]), true, HTTPClient.METHOD_GET, "")
	if err != OK:
		_finish_get({"ok": false, "slots": {}, "total": 0, "error": "request_failed"})
	return

func _request_put(action: Dictionary) -> void:
	var text = ""
	if _ensure_http():
		text = Global.get_file_text(action["path"])
	if text == "":
		SceneManager.show_system_notice("本地已保存，云端同步失败")
		_finish_put()
		return
	var url = _base_url() + "/save/" + cloud_id + "/" + str(action["slot"])
	var err = _http.request(url, PoolStringArray(["Content-Type: text/plain; charset=utf-8"]), true, HTTPClient.METHOD_PUT, text)
	if err != OK:
		SceneManager.show_system_notice("本地已保存，云端同步失败")
		_finish_put()
	return

func _finish_put() -> void:
	_busy = false
	_current = {}
	_start_next()
	return

func _finish_get(result: Dictionary) -> void:
	_busy = false
	_current = {}
	if _get_owner != null and _get_method != "" and _get_owner.has_method(_get_method):
		_get_owner.call(_get_method, result)
	_get_owner = null
	_get_method = ""
	_start_next()
	return

func _ensure_http() -> bool:
	if _http == null:
		_http = HTTPRequest.new()
		_http.connect("request_completed", self, "_on_completed")
		# 与 AIHttpClient 同因：/root 在场景搭建期间 busy，挂到已就绪的 SceneManager 下
		SceneManager.add_child(_http)
	if not _http.is_inside_tree():
		return false
	_http.timeout = HTTP_TIMEOUT
	return true

func _base_url() -> String:
	if not enabled:
		return ""
	return String(JavaScript.eval("window.location.origin", true))

func _on_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
	if not _busy:
		return
	var text = body.get_string_from_utf8()
	if str(_current.get("kind", "")) == "get":
		_handle_get(result, response_code, text)
		return
	_handle_put(result, response_code, text)
	return

func _handle_get(result: int, code: int, text: String) -> void:
	if result != 0:
		_finish_get({"ok": false, "slots": {}, "total": 0, "error": "network"})
		return
	if code == 404:
		synced_slots = 0
		_finish_get({"ok": true, "slots": {}, "total": 0, "error": ""})
		return
	var data = parse_json(text)
	if code != 200 or typeof(data) != TYPE_DICTIONARY:
		_finish_get({"ok": false, "slots": {}, "total": 0, "error": "bad_response"})
		return
	var slots = Global.dic_val(data, "slots", {})
	if typeof(slots) != TYPE_DICTIONARY:
		slots = {}
	var total = int(Global.dic_val(data, "syncedSlots", slots.size()))
	synced_slots = total
	_finish_get({"ok": true, "slots": slots, "total": total, "error": ""})
	return

func _handle_put(result: int, code: int, text: String) -> void:
	if result == 0 and code == 200:
		var data = parse_json(text)
		if typeof(data) == TYPE_DICTIONARY:
			synced_slots = int(Global.dic_val(data, "syncedSlots", synced_slots))
		SceneManager.show_system_notice("网络存档已同步（共{0}个）".format([synced_slots]))
	else:
		SceneManager.show_system_notice("本地已保存，云端同步失败")
	_finish_put()
	return

# ---- 合并 / 展示 ----

# 只处理单数槽位；云端较新才覆盖本地，覆盖前把旧档留成 .sav.bak。
func merge_into_local(slots: Dictionary) -> Dictionary:
	var dir_path = DataManager.get_common_path() + "save/"
	var d = Directory.new()
	if not d.dir_exists(dir_path):
		d.make_dir_recursive(dir_path)

	var total = 0
	var restored = 0
	var kept = 0
	for key in slots.keys():
		var slot = str(key)
		if not is_network_slot(slot):
			continue
		var data = slots[key]
		if typeof(data) != TYPE_DICTIONARY:
			continue
		total += 1
		var remote_time = str(Global.dic_val(data, "存档时间", ""))
		var path = dir_path + slot + ".sav"
		var local_text = Global.get_file_text(path)
		var local_time = ""
		if local_text != "":
			var local_data = parse_json(local_text)
			if typeof(local_data) == TYPE_DICTIONARY:
				local_time = str(Global.dic_val(local_data, "存档时间", ""))
		if local_text == "" or is_newer(remote_time, local_time):
			if local_text != "":
				Global.save_file_text(path + ".bak", local_text)
			Global.save_file_text(path, JSON.print(data))
			StaticManager.saveIdx.update_save_index(slot)
			restored += 1
		else:
			kept += 1
	return {"total": total, "restored": restored, "kept": kept}

func get_synced_count() -> int:
	return synced_slots

func copy_link() -> void:
	if not enabled:
		return
	var url = String(JavaScript.eval("location.href", true))
	var ok = String(JavaScript.eval(
		"(function(){try{if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(location.href);return '1';}}catch(e){}return '0';})()", true))
	if ok == "1":
		SceneManager.show_system_notice("链接已复制")
		return
	# 非安全上下文（局域网 http）拿不到 clipboard，退化成手动复制
	SceneManager.confirm("请手动复制下面的链接：\n" + url, null, "", Vector2(420, 260), "知道了", "关闭")
	return
```

**Step 4: 注册 autoload**

`bwdl/project.godot` 的 `[autoload]` 段末尾（`OrderHistory=...` 之后）追加：

```
CloudSave="*res://script/Cloud_Save.gd"
```

放在最后：`Cloud_Save._ready()` 不一定依赖别的单例，但 `_ensure_http()` 要用 `SceneManager`，排在 `SceneManager` 之后最稳。

**Step 5: 把校验脚本加进清单**

`bwdl/test/ai_agent_validate.gd` 的 `paths` 数组末尾追加：

```gdscript
		# 云存档
		"res://script/Cloud_Save.gd",
```

`agent-service/test/godot3-parse.test.ts` 的期望条数是从这份清单里正则数出来的，不用改测试。

**Step 6: 跑校验**

Run:
```bash
Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl --script res://test/cloud_save_validate.gd
Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl --script res://test/ai_agent_validate.gd
```
Expected: 第一条 `CLOUD_SAVE_RESULT=0`；第二条 `AI_VALIDATE_RESULT=0` 且包含 `AI_VALIDATE OK res://script/Cloud_Save.gd`。

**Step 7: Commit**

```bash
git add bwdl/script/Cloud_Save.gd bwdl/test/cloud_save_validate.gd bwdl/test/ai_agent_validate.gd bwdl/project.godot
git commit -m "feat(save): CloudSave autoload（ID/上传队列/下载合并/复制链接）"
```

---

### Task 5: 存档槽位标记与上传触发

**Files:**
- Modify: `bwdl/windows/menu/SaveLoad_Item.gd:30-38`（标题）、`:126-131`（保存后）
- Test: 无自动化 UI 测试；靠 Task 7 的 headless 校验与手动验证

**Step 1: 标题加「（网络）/（本地）」**

`refresh_data()` 里第 36-38 行：

```gdscript
	var slot_tag = ""
	if CloudSave.is_web() and save_item_name.is_valid_integer():
		slot_tag = "（网络）" if CloudSave.is_network_slot(save_item_name) else "（本地）"
	var head_point = "[color=yellow]存档点:{0}{1} [/color]".format([
		save_item_desc, slot_tag
	])
```

注意条件里的 `save_item_name.is_valid_integer()`：自动存档位的名字是 `endless`/`monthly` 等，不能被打成「（本地）」。

**Step 2: 保存后按槽位分流**

`saved_data_confirmed`（实际函数名 `save_data_confirmed`，第 126-131 行）改为：

```gdscript
func save_data_confirmed() -> void :
	DataManager.set_env("saveSlot", save_item_desc)
	save_path = DataManager.save_game_data(save_item_name)
	refresh_data()
	get_parent().emit_signal("saved")
	if not save_item_name.is_valid_integer():
		return
	if CloudSave.is_network_slot(save_item_name):
		CloudSave.upload_slot(save_item_name, save_path)
		return
	SceneManager.show_system_notice("已保存到本地（双数槽位）")
	return
```

`CloudSave.enabled == false`（桌面/安卓）时 `upload_slot` 直接返回，所以这段不需要平台判断；双数槽位的提示也只在网页版有意义，但桌面版显示「已保存到本地（双数槽位）」并不算错，保持简单。

**Step 3: 校验语法**

Run: `Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl --editor --quit`
Expected: 退出码 0，无 `Parse Error`（`--editor --quit` 会编译全部脚本）。

**Step 4: Commit**

```bash
git add bwdl/windows/menu/SaveLoad_Item.gd
git commit -m "feat(save): 槽位标题标注网络/本地并在保存单数槽位时上传"
```

---

### Task 6: 存档界面底部云存档状态与复制链接

**Files:**
- Modify: `bwdl/windows/menu/SaveLoad.gd:13-19`（节点引用）、`:21-42`（`_ready`）、`:78-81`（`item_saved`）
- Test: 手动验证（见 Step 5）

**Step 1: 增加按钮引用与初始化**

`SaveLoad.gd` 顶部 `onready var btnNext = ...` 之后加：

```gdscript
var btnCopyLink: Button = null
```

`_ready()` 里 `init_data(StaticManager.saveIdx.page)` **之前**插入：

```gdscript
	_setup_cloud_footer()
```

**Step 2: 新增三个函数**

`SaveLoad.gd` 末尾（`reset_layout_portrait()` 之后）追加：

```gdscript
func _setup_cloud_footer() -> void :
	if not CloudSave.is_web():
		return
	btnCopyLink = Button.new()
	btnCopyLink.text = "复制链接"
	btnCopyLink.rect_position = Vector2(770, 58)
	btnCopyLink.rect_min_size = Vector2(160, 44)
	btnCopyLink.connect("pressed", self, "_on_btnCopyLink_pressed")
	$gc / footer.add_child(btnCopyLink)
	refresh_cloud_footer()
	return

func refresh_cloud_footer() -> void :
	if not CloudSave.is_web():
		return
	lblLocation.text = "云存档：已同步 {0} 个网络存档位".format([CloudSave.get_synced_count()])
	return

func _on_btnCopyLink_pressed() -> void :
	CloudSave.copy_link()
	return
```

坐标是横屏 1024×600 下的估计值，`lblLocation` 的 `rect_min_size` 是 924×40、`margin_left = 50`，按钮放在它右侧的空白处。竖屏时按钮会偏出屏幕——可接受（底部第二行只作提示），若实现时想更稳，可改成在 `reset_layout_landscape()` / `reset_layout_portrait()` 里各设一次位置。

**Step 3: 存档后刷新计数**

`item_saved(i)` 改为：

```gdscript
func item_saved(i: int) -> void :
	cursor_index = i
	cursor_change()
	refresh_cloud_footer()
	return
```

上传是异步的，按钮上的数字会在响应回来后下一次刷新（切页或再存一次）才更新；不要在这里 `yield` 等网络。

**Step 4: 校验语法**

Run: `Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl --editor --quit`
Expected: 退出码 0，无 `Parse Error`。

**Step 5: 手动验证（网页版）**

```bash
make web
cd agent-service && PORT=8060 WEB_DIR="$(cd ../bwdl/build/web && pwd)" node src/server.ts
```

浏览器打开 `http://localhost:8060/`（必须是 localhost 或 https，否则 `crypto.randomUUID` 与 clipboard 都不可用）：

1. 地址栏自动出现 `?save=<uuid>`；刷新后 ID 不变。
2. 开局 → 存档到 `#1`：提示「网络存档已同步（共1个）」，`agent-service/data/saves/<uuid>/1.json` 出现。
3. 存到 `#0`：提示「已保存到本地（双数槽位）」，服务器目录不变。
4. 槽位标题分别显示 `存档点:#1（网络）` / `存档点:#0（本地）`。
5. 点「复制链接」，剪贴板拿到带 `save=` 的地址。

桌面版（`make run`）不应出现「复制链接」按钮，槽位标题也不应带后缀。

**Step 6: Commit**

```bash
git add bwdl/windows/menu/SaveLoad.gd
git commit -m "feat(save): 存档面板显示云存档同步数并支持复制链接"
```

---

### Task 7: 启动时拉取并合并云端存档

**Files:**
- Modify: `bwdl/scene/scene_open/scene_open.gd:8-23`（`_ready`）、`:31-44`（输入守卫），文件末尾追加回调

**Step 1: `_ready` 发起拉取**

`scene_open.gd` 的 `_ready()` 中，`$HTTPRequest.request(...)` 之前插入：

```gdscript
	CloudSave.begin_session(self, "_on_cloud_fetched")
```

**Step 2: 输入守卫**

`_on_key_event()` 开头插入：

```gdscript
	if SceneManager.popuped or SceneManager.Quit.visible:
		return
```

（`SceneManager.Quit` 在 `Scene_Manager.gd:15` 已是常驻子节点，任何时候都能取到。）

**Step 3: 新增回调**

文件末尾追加：

```gdscript
func _on_cloud_fetched(result: Dictionary) -> void :
	if not result.get("ok", false):
		return
	var slots = result.get("slots", {})
	if typeof(slots) != TYPE_DICTIONARY or slots.empty():
		return
	var merged = CloudSave.merge_into_local(slots)
	var total = int(merged["total"])
	if total <= 0:
		return
	var msg = "云端发现{0}个网络存档位，已恢复{1}个，保留本地较新{2}个。\n是否打开读档列表？".format([
		total, int(merged["restored"]), int(merged["kept"])
	])
	SceneManager.confirm(msg, self, "_on_cloud_merge_confirmed", Vector2(420, 240), "打开", "取消")
	return

func _on_cloud_merge_confirmed() -> void :
	# 等确认框真正关闭再开菜单：show_menu() 在 popuped 时会直接 return
	yield(get_tree(), "idle_frame")
	SceneManager.Quit.show_menu()
	SceneManager.Quit._on_btnLoadGame_pressed()
	return
```

`show_menu()` 会把 `get_tree().paused` 置 true，`pnlSaveLoad` 在 `Quit.tscn`（`pause_mode = 2`）下仍会处理输入；退出面板走 `Quit._on_btnBackToGame_pressed()` 恢复。

**Step 4: 校验语法**

Run: `Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl --editor --quit`
Expected: 退出码 0，无 `Parse Error`。

**Step 5: Commit**

```bash
git add bwdl/scene/scene_open/scene_open.gd
git commit -m "feat(save): 开场读取云端存档并按存档时间合并单数槽位"
```

---

### Task 8: 启动命令与部署

**Files:**
- Modify: `Makefile:157-172`（web 段落之后加 `serve-agent`）
- Modify: `agent-service/Dockerfile:22-30`
- Modify: `agent-service/README.md`（新增「云存档」一节）
- Verify: `.gitignore:65` 的 `data/` 已覆盖 `agent-service/data/`

**Step 1: Makefile 增 `serve-agent`**

在 `serve:` 目标之后追加（`WEB_DIR` 是相对仓库根的路径，agent-service 要 `cd` 进去，所以必须转绝对路径）：

```make
.PHONY: serve-agent
serve-agent: ## 用 agent-service 托管网页版（含云存档，默认 8060 端口）
	@if [ ! -f "$(WEB_DIR)/index.html" ]; then echo "错误: 还没有网页版产物，先执行 make web"; exit 1; fi
	@echo "==> http://localhost:$(WEB_PORT)/ （云存档已启用，Ctrl+C 停止）"
	cd agent-service && PORT=$(WEB_PORT) WEB_DIR="$(abspath $(WEB_DIR))" node src/server.ts
```

顶部用法注释里补一行 `#   - serve-agent 用 agent-service 托管网页版（云存档）`。

**Step 2: Dockerfile 的可写存档目录**

`agent-service/Dockerfile` 的 `ENV` 块加 `SAVE_DIR=/app/data/saves`，并在切换用户前建好目录：

```dockerfile
ENV NODE_ENV=production \
    PORT=8060 \
    WEB_DIR=/app/web \
    K3G_AGENT_MODE=mock \
    SAVE_DIR=/app/data/saves

RUN mkdir -p /app/data/saves && chown -R node:node /app/data
```

文件头部的运行示例补上挂载（只读根文件系统下不挂就是只读）：

```
#         -v "$PWD/agent-service/data:/app/data" \
```

**Step 3: README 补一节**

`agent-service/README.md` 追加：

- 两条路由：`PUT /save/:id/:slot`（只接受奇数槽位 1/3/…/51）、`GET /save/:id`。
- 配置：`SAVE_DIR` / `SAVE_MAX_MB`（32）/ `SAVE_TOTAL_MB`（2048）/ `SAVE_TTL_DAYS`（365）。
- 部署必须挂可写卷到 `/app/data`。
- 网页版必须由本服务托管才有云存档；`make serve` 的 python 静态服务只有本地存档。
- 非 HTTPS（除 localhost）时 `crypto.randomUUID` 与 `navigator.clipboard` 不可用：ID 会退化为本地生成，复制链接退化为弹框显示 URL。

**Step 4: 确认存档目录不入库**

Run: `git check-ignore -v agent-service/data/saves/x.json`
Expected: 命中 `.gitignore` 里的 `data/` 规则。若没有命中，再补 `agent-service/data/`。

**Step 5: 跑 `make help` 与语法检查**

Run: `make help | grep serve-agent`
Expected: 出现 `serve-agent` 一行，无 Makefile 语法错误。

**Step 6: Commit**

```bash
git add Makefile agent-service/Dockerfile agent-service/README.md
git commit -m "docs(save): serve-agent 启动命令与云存档部署说明"
```

---

### Task 9: 全量回归与端到端验收

**Files:** 无改动（只验证）

**Step 1: Node 全量**

Run: `cd agent-service && npm test`
Expected: 全部通过；Godot 相关用例若因 `GODOT3_BIN` 未设而 skip，不算失败，但要单独跑下面两条。

**Step 2: Godot 全量校验**

Run:
```bash
Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl --script res://test/cloud_save_validate.gd
Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl --script res://test/ai_agent_validate.gd
Godot_3.6.3.app/Contents/MacOS/Godot --no-window --path bwdl --editor --quit 2>&1 | grep -i "parse error"
```
Expected: `CLOUD_SAVE_RESULT=0`、`AI_VALIDATE_RESULT=0`、最后一条无输出。

**Step 3: 端到端（同一台机器两个浏览器）**

```bash
make web && make serve-agent
```

1. 浏览器 A 打开 `http://localhost:8060/`，URL 带 `?save=<uuid>`；存档到 `#1` 与 `#3`。
2. 复制链接（或直接抄 URL），浏览器 B 无痕窗口打开。
3. 弹框「云端发现2个网络存档位，已恢复2个，保留本地较新0个」→ 点「打开」→ 读档列表里 `#1`、`#3` 可读。
4. 浏览器 B 存 `#1`（更新），回到浏览器 A 刷新：A 的 `#1` 被覆盖、`#3` 不变；`1.sav.bak` 出现在 `user://sgz/save/`。
5. 停掉服务端再存 `#1`：提示「本地已保存，云端同步失败」，本地存档仍可用。

**Step 4: 最终提交**

```bash
git status --short
```
Expected: 干净。若有调试残留（临时 `.gd`、日志）清掉再提交。

---

## 执行方式

用户已选定 **Subagent-Driven**：每个 Task 由一个新的 subagent 执行，Task 之间做一次 review；全部完成后走 `requesting-code-review` 做一次整体代码评审，再按评审结论优化。

## 已知风险（实现时留意）

1. `SceneManager.Quit.show_menu()` 在 `popuped == true` 时直接 return；合并确认框关闭与 `idle_frame` 之间的时序若在真机上仍撞上，就把 `_on_cloud_merge_confirmed` 改成重试两次再放弃。
2. `pnlSaveLoad` 是 `Quit` 的子节点，`Quit` 自身默认隐藏；从 `scene_open` 打开必须走 `show_menu()`，不能只调 `_on_btnLoadGame_pressed()`。
3. `HTTPRequest` 的 `request()` 第 4 参是 `HTTPClient.METHOD_PUT`；Godot 3 没有 `HTTPRequest.put()` 之类的糖。
4. 服务端 `saveMaxMb` 既作单槽上限又参与单 ID 总量换算，测试里设成 1 时总量只有 2MiB，别在大 body 用例后又写大文件。
5. `merge_into_local()` 写文件用的是 `Global.save_file_text`（末尾会加换行），读回时 `JSON.parse` 仍成立，但 `.sav.bak` 与原文件字节数会差 1——这是既有的存档写法，不要试图「修」它。