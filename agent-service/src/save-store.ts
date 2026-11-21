// 云存档文件存储：<root>/<uuid>/<slot>.json，一槽一文件。
//
// 为什么不是「一个 ID 一个 JSON」：单文件方案每次 PUT 都要读-改-写整个文件，
// 两台设备各存一个槽位会互相覆盖。分文件后每个槽位独立原子写（tmp + rename）。
import fs from "node:fs/promises";
import type { Dirent } from "node:fs";
import { randomBytes } from "node:crypto";
import path from "node:path";

/** 只接受小写 UUID v4：crypto.randomUUID() 的产物。大小写会变成两个目录，故不忽略大小写。 */
export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
/** 手动槽位 0..51。 */
export const SLOT_RE = /^(?:0|[1-9]|[1-4][0-9]|5[01])$/;
export const SLOT_FILE_RE = /^([0-9]{1,2})\.json$/;

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
  if (!UUID_RE.test(id)) throw new SaveError(400, "bad_id", "id must be a lowercase UUID v4");
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
    // 崩溃残留的 tmp 不该永久占配额
    if (name.endsWith(".tmp")) continue;
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
  // 配额是软限制：并发写不同槽位时可能短暂超出，单机自用场景接受，不做按 ID 串行化。
  if (used + bytes > maxTotalBytes) throw new SaveError(413, "id_quota_exceeded", `id exceeds ${maxTotalBytes} bytes`);

  // 随机后缀避免同一毫秒内两次写同一槽位撞名（tmp 会互相覆盖/删除）。
  const tmp = `${target}.${process.pid}.${Date.now()}.${randomBytes(6).toString("hex")}.tmp`;
  try {
    await fs.writeFile(tmp, raw, "utf8");
    await fs.rename(tmp, target);
  } catch (err) {
    await fs.unlink(tmp).catch(() => {});
    throw err;
  }

  // rename 成功后文件仍可能被并发清理删掉；此时退化为当前时间，不让成功写入报错。
  let updatedAt: string;
  try {
    updatedAt = (await fs.stat(target)).mtime.toISOString();
  } catch {
    updatedAt = new Date().toISOString();
  }
  return { syncedSlots: await countSlots(dir), updatedAt };
}

export interface SaveBundle {
  slots: Record<string, unknown>;
  syncedSlots: number;
  updatedAt: string;
}

/** 整包读取上限：一次响应最多拼这么多字节，避免大配额把进程内存打爆。 */
export const MAX_BUNDLE_BYTES = 64 * 1024 * 1024;

/** 读回一个 ID 下所有槽位；一个合法槽位都没有时返回 null。 */
export async function readAll(
  root: string,
  id: string,
  maxBundleBytes = MAX_BUNDLE_BYTES,
): Promise<SaveBundle | null> {
  assertId(id);
  const dir = idDir(root, id);
  let names: string[] = [];
  try { names = await fs.readdir(dir); } catch { return null; }

  // 第一遍只 stat 累加大小：整包超限立刻 413，不把任何槽位读进内存。
  const files: { slot: string; file: string; mtimeMs: number }[] = [];
  let totalBytes = 0;
  for (const name of names) {
    const m = SLOT_FILE_RE.exec(name);
    if (!m) continue;
    const file = path.join(dir, name);
    let size = 0;
    let mtimeMs = 0;
    try {
      const stat = await fs.stat(file);
      size = stat.size;
      mtimeMs = stat.mtimeMs;
    } catch { continue; /* 并发删除 */ }
    totalBytes += size;
    if (totalBytes > maxBundleBytes) {
      throw new SaveError(413, "bundle_too_large", `bundle exceeds ${maxBundleBytes} bytes`);
    }
    files.push({ slot: m[1], file, mtimeMs });
  }

  // 第二遍才逐个 JSON.parse；单个文件损坏只跳过该槽位。
  const slots: Record<string, unknown> = {};
  let newest = 0;
  for (const { slot, file, mtimeMs } of files) {
    try {
      const parsed = JSON.parse(await fs.readFile(file, "utf8"));
      if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
        throw new Error("not a JSON object");
      }
      slots[slot] = parsed;
      if (mtimeMs > newest) newest = mtimeMs;
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
  let entries: Dirent[] = [];
  try { entries = await fs.readdir(root, { withFileTypes: true }); } catch { return 0; }

  let removed = 0;
  for (const entry of entries) {
    // 只处理 UUID 目录：跳过符号链接、杂项文件和非法名字，避免清理跑到 root 之外。
    if (!entry.isDirectory() || !UUID_RE.test(entry.name)) continue;
    const dir = path.join(root, entry.name);
    let files: Dirent[] = [];
    try { files = await fs.readdir(dir, { withFileTypes: true }); } catch { continue; }
    for (const f of files) {
      if (!f.isFile() || !SLOT_FILE_RE.test(f.name)) continue;
      const file = path.join(dir, f.name);
      try {
        const stat = await fs.stat(file);
        if (stat.mtimeMs < cutoff) {
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