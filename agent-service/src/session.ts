// 跨回合会话记忆（设计文档 §4.5）。
// 说明：pi-durable 是独立的 Harness（自带 Conversation/Task 模型，且标注 Experimental），
// 引入它会替换而非补充当前已验证的 pi-agent-core agent loop，违反 YAGNI。
// 这里只保留设计真正需要的部分：按 session_id 隔离的 intent / 上回合结果 / 回合数。
import type { DecideResponse } from "./types.ts";

export interface SessionRecord {
  intent: string;
  last_plan_result: string;
  turns: number;
  updated_at: number;
}

export class SessionStore {
  private map = new Map<string, SessionRecord>();
  private ttlMs: number;

  constructor(ttlMs = 30 * 60 * 1000) {
    this.ttlMs = ttlMs;
  }

  size(): number {
    this.cleanup();
    return this.map.size;
  }

  clear(): void {
    this.map.clear();
  }

  get(sessionId: string | undefined): Record<string, unknown> | null {
    if (!sessionId) return null;
    this.cleanup();
    const rec = this.map.get(sessionId);
    if (!rec) return null;
    return {
      intent: rec.intent,
      last_plan_result: rec.last_plan_result,
      turns: rec.turns,
    };
  }

  update(sessionId: string | undefined, res: DecideResponse): void {
    if (!sessionId) return;
    const prev = this.map.get(sessionId);
    this.map.set(sessionId, {
      intent: res.intent,
      last_plan_result: `${res.plan.length}/${res.plan.length} 已提交`,
      turns: (prev?.turns ?? 0) + 1,
      updated_at: Date.now(),
    });
  }

  cleanup(): void {
    const now = Date.now();
    for (const [k, v] of this.map) {
      if (now - v.updated_at > this.ttlMs) this.map.delete(k);
    }
  }
}

export const sessionStore = new SessionStore();
