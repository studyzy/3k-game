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