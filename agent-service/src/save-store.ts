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