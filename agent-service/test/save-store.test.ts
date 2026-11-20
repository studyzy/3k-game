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
  await writeSlot({ root, id, slot: "1", raw: JSON.stringify({ a: "a".repeat(60) }), maxBytes: 1000, maxTotalBytes: 100 });
  await assert.rejects(
    writeSlot({ root, id, slot: "3", raw: JSON.stringify({ b: "b".repeat(60) }), maxBytes: 1000, maxTotalBytes: 100 }),
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
  await assert.rejects(fs.stat(idDir(root, id)));
});