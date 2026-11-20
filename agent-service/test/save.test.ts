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
  // saveMaxMb 故意与 MAX_BODY(1MiB) 不同，才能区分「单槽上限」与「传输层默认上限」
  server = createServer({ ...testConfig, webDir: tmpDir, saveDir, saveMaxMb: 2, saveTotalMb: 8 });
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

function assertIsoDate(value: unknown): void {
  assert.equal(typeof value, "string");
  assert.ok(!Number.isNaN(Date.parse(value as string)), `not a parseable date: ${String(value)}`);
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
  assertIsoDate(body.updatedAt);

  const got = await fetch(`${base}/save/${ID}`).then((r) => r.json() as any);
  assert.equal(got.id, ID);
  assertIsoDate(got.updatedAt);
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
  const badId = await put("nope", "1", SAVE);
  assert.equal(badId.status, 400);
  assert.equal((await badId.json() as any).error, "bad_id");

  for (const slot of ["0", "2", "52", "abc"]) {
    const res = await put(ID, slot, SAVE);
    assert.equal(res.status, 400);
    assert.equal((await res.json() as any).error, "bad_slot");
  }
});

test("非法百分号编码 → 400 而不是 500", async () => {
  const badId = await fetch(`${base}/save/%E0%A4%A/1`, {
    method: "PUT",
    headers: { "content-type": "text/plain; charset=utf-8" },
    body: JSON.stringify(SAVE),
  });
  assert.equal(badId.status, 400);
  assert.equal((await badId.json() as any).error, "bad_id");

  const badSlot = await put(ID, "%E0%A4%A", SAVE);
  assert.equal(badSlot.status, 400);
  assert.equal((await badSlot.json() as any).error, "bad_slot");
});

test("非 JSON / 数组 / null → 400", async () => {
  for (const body of ["{not json", "[1,2]", "null"]) {
    const res = await put(ID, "5", body);
    assert.equal(res.status, 400);
    assert.equal((await res.json() as any).error, "bad_json");
  }
});

test("目录里的坏文件不影响 GET", async () => {
  const dir = path.join(saveDir, ID);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, "9.json"), "broken", "utf8");
  await fs.writeFile(path.join(dir, "readme.txt"), "x", "utf8");
  const res = await fetch(`${base}/save/${ID}`);
  assert.equal(res.status, 200);
  const got: any = await res.json();
  assert.equal(got.syncedSlots, 2);
  assert.ok(got.slots["1"]);
  assert.ok(got.slots["3"]);
  assert.equal(got.slots["9"], undefined);
});

test("单槽大小按 saveMaxMb 而非 MAX_BODY：1.5 MiB 通过，2.5 MiB 拒绝", async () => {
  // 独立 ID：前一个用例在 ID 目录里留了坏文件 9.json，会被 countSlots 计入槽位数
  const ID2 = "8c4d2e6a-1b3f-4a9c-9e7d-2f5b6c8a0d13";
  // 1.5 MiB < saveMaxMb(2MiB)，但 > MAX_BODY(1MiB)：能过说明用了独立上限
  const ok = await put(ID2, "11", { 存档时间: "2026-11-21 10:00:00", blob: "x".repeat(1572864 - 128) });
  assert.equal(ok.status, 200);
  assert.equal((await ok.json() as any).syncedSlots, 1);

  // 2.5 MiB > saveMaxMb(2MiB)
  const huge = await put(ID2, "13", { 存档时间: "2026-11-21 10:00:00", blob: "x".repeat(2621440 - 128) });
  assert.equal(huge.status, 413);
});

test("方法不对 → 405", async () => {
  const bundle = await fetch(`${base}/save/${ID}`, { method: "POST" });
  assert.equal(bundle.status, 405);
  assert.equal((await bundle.json() as any).error, "method_not_allowed");

  const slot = await fetch(`${base}/save/${ID}/1`, { method: "POST" });
  assert.equal(slot.status, 405);
  assert.equal((await slot.json() as any).error, "method_not_allowed");
});

test("OPTIONS 允许 PUT", async () => {
  const res = await fetch(`${base}/save/${ID}/1`, { method: "OPTIONS" });
  assert.equal(res.status, 204);
  assert.match(String(res.headers.get("access-control-allow-methods")), /PUT/);
});

test("AI 路由仍受 MAX_BODY(1MiB) 限制", async () => {
  const res = await fetch(`${base}/ai/turn`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ x: "x".repeat(1.2 * 1024 * 1024) }),
  });
  assert.equal(res.status, 413);
});

test("静态资源不受影响", async () => {
  const res = await fetch(`${base}/`);
  assert.equal(res.status, 200);
  assert.match(await res.text(), /3k/);
});