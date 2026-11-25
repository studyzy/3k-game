import type { Agent } from "@earendil-works/pi-agent-core";
import type { BattleLastPlan, BattlePlan } from "./types.ts";
import { traceStore, type DecisionTrace } from "./trace.ts";

export interface BattleSessionInit {
  battleKey: string;
  controlledActorId: number;
  enemyActorId: number;
  side: "attacker" | "defender";
  diffculities: number;
}

/**
 * 一场白兵战 = 一个 BattleSession。
 * 它只保存 Agent 对话、跨拍记忆与并发锁；不再有指令队列、poller、resume。
 */
export class BattleSession {
  readonly id: string;
  readonly init: BattleSessionInit;
  readonly createdAt = Date.now();
  readonly idleTimeoutMs: number;
  lastActivityAt = Date.now();

  tick = 0;
  inFlight = false;
  ended = false;
  endReason = "";

  memory = "";
  tokens = 0;
  lastPlan: BattlePlan | null = null;
  lastPlanResult: BattleLastPlan | null = null;

  agent: Agent | null = null;
  trace: DecisionTrace | null = null;

  constructor(id: string, init: BattleSessionInit, idleTimeoutMs = 30 * 60 * 1000) {
    this.id = id;
    this.init = init;
    this.idleTimeoutMs = idleTimeoutMs;
  }

  get finished(): boolean { return this.ended; }

  touch(): void { this.lastActivityAt = Date.now(); }

  idleRemaining(): number {
    return this.idleTimeoutMs - (Date.now() - this.lastActivityAt);
  }

  /** 同一会话同时只允许一拍。 */
  beginTick(): boolean {
    if (this.ended) return false;
    if (this.inFlight) return false;
    this.inFlight = true;
    this.touch();
    return true;
  }

  endTick(): void {
    this.inFlight = false;
    this.touch();
  }

  finish(reason: string): void {
    if (this.ended) return;
    this.ended = true;
    this.endReason = reason;
    this.touch();
  }
}

export class BattleStore {
  private items = new Map<string, BattleSession>();
  private seq = 0;

  create(init: BattleSessionInit, idleTimeoutMs = 30 * 60 * 1000): BattleSession {
    this.prune();
    this.seq += 1;
    const id = "b-" + Date.now().toString(36) + "-" + this.seq.toString(36);
    const s = new BattleSession(id, init, idleTimeoutMs);
    this.items.set(id, s);
    return s;
  }

  get(id: string): BattleSession | undefined {
    this.prune();
    return this.items.get(id);
  }

  delete(id: string): void { this.items.delete(id); }

  prune(): void {
    for (const [id, s] of this.items) {
      if (s.inFlight) continue;
      if (s.idleRemaining() > 0) continue;
      this.items.delete(id);
      const tr = s.trace;
      if (tr && tr.status === "running") {
        // 会话被 TTL 清掉时 trace 还挂着 running，dashboard 会永远显示「进行中」。
        traceStore.finish(tr, {
          status: "expired",
          elapsed_ms: Date.now() - Date.parse(tr.started_at),
          budget_used: { tokens: s.tokens, turns: s.tick, tool_calls: 0 },
        });
      }
    }
  }

  clear(): void { this.items.clear(); }
  size(): number {
    this.prune();
    return this.items.size;
  }
}

export const battleStore = new BattleStore();
