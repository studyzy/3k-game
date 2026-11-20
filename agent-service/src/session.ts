// 回合会话存储（服务端驱动逐步交互）。
//
// 一次 AI 回合 = 一个 TurnSession。服务端在后台跑 agent loop，
// 每当 LLM 调用动作工具，就产生一个 PendingAction 并在此挂起，
// 等 Godot 通过长轮询取走、执行、回传 ToolResultPayload 后，
// 用对应序号回填 Promise，让工具调用返回，agent loop 继续。
//
// 并发安全：GET pending 与 POST result 可能交错到达。
// 用「待取列表 + 等待者」双缓冲，保证一个动作只被取走一次。
import type {
  LegalAction, PendingAction, PendingResponse, TerrainCell, ToolName, ToolResultPayload, TurnRequest,
} from "./types.ts";

export interface ToolOutcome {
  ok: boolean;
  outcome: string;
  units: Array<Record<string, unknown>>;
  legal_actions: LegalAction[];
  terrain?: TerrainCell[];
  economy?: Record<string, unknown>;
}

type Waiter<T> = { resolve: (v: T) => void; reject: (e: Error) => void };

export class TurnSession {
  readonly id: string;
  readonly req: TurnRequest;
  readonly startedAt = Date.now();

  /** 已产出、尚未被 Godot 取走的动作。 */
  private queue: PendingAction[] = [];
  /** 已产出、尚未被 Godot 取走的中间进度（思考 / 只读工具）。 */
  private readonly progressQueue: Array<{ seq: number; text: string }> = [];
  /** 正在等待下一个动作的长轮询。 */
  private pollWaiter: Waiter<PendingResponse> | null = null;

  /** 已取走、等待 Godot 回传结果的工具调用。 */
  private readonly inflight = new Map<number, Waiter<ToolOutcome>>();
  /** 提前到达的结果（Godot 回传早于服务端挂起时）。 */
  private readonly earlyResults = new Map<number, ToolResultPayload>();

  readonly actions: PendingAction[] = [];
  private seq = 0;
  private progressSeq = 0;
  private done = false;
  private doneReason = "";
  private failError: Error | null = null;

  /** 距上次 Agent 活动（任何工具调用）或 Godot 回传结果的毫秒数，用于空闲超时判定。 */
  lastActivityAt = Date.now();
  idleTimeoutMs: number;

  constructor(id: string, req: TurnRequest, idleTimeoutMs: number) {
    this.id = id;
    this.req = req;
    this.idleTimeoutMs = idleTimeoutMs;
  }

  get finished(): boolean { return this.done; }
  get reason(): string { return this.doneReason; }

  /** 距离空闲超时还剩多少毫秒；<=0 表示已超时。 */
  idleRemaining(): number {
    return this.idleTimeoutMs - (Date.now() - this.lastActivityAt);
  }

  /**
   * Agent 仍在活动：任何工具调用（含只读侦察）都证明 loop 没死，
   * 重置空闲计时，避免 Godot 把「正在查询」误判成「Agent 掉线」。
   */
  touch(): void {
    this.lastActivityAt = Date.now();
  }

  /** 由工具 execute 调用：登记一个动作并挂起，直到 Godot 回传结果。 */
  emitAction(partial: {
    tool: ToolName; actor: number; id: string; action: LegalAction; reasoning: string;
  }): Promise<ToolOutcome> {
    const action: PendingAction = { seq: ++this.seq, ...partial };
    this.actions.push(action);

    return new Promise<ToolOutcome>((resolve, reject) => {
      this.inflight.set(action.seq, { resolve, reject });

      // 已有长轮询在等 → 直接交付
      if (this.pollWaiter) {
        const w = this.pollWaiter;
        this.pollWaiter = null;
        w.resolve({ type: "action", action });
        return;
      }
      this.queue.push(action);
    });
  }

  /**
   * Agent 中间进度（思考文本 / 只读工具调用）：只用于界面展示，不推进战局。
   * 有长轮询在等时立即返回，否则排队等下一次轮询。
   */
  emitProgress(text: string): void {
    const t = text.trim();
    if (t === "") return;
    this.progressQueue.push({ seq: ++this.progressSeq, text: t });
    if (this.pollWaiter) {
      const w = this.pollWaiter;
      this.pollWaiter = null;
      const p = this.progressQueue.shift()!;
      w.resolve({ type: "progress", ...p });
    }
  }

  /**
   * Godot 长轮询：等到下一个动作 / 会话结束 / 空闲超时。
   * maxWaitMs 是本次轮询最多挂多久（服务端侧上限），到点无动作返回 idle_timeout，
   * 由调用方结合 idleRemaining() 判断是继续轮询还是回退。
   */
  nextAction(maxWaitMs: number): Promise<PendingResponse> {
    if (this.failError) return Promise.resolve({ type: "error", message: this.failError.message });
    if (this.done) return Promise.resolve({ type: "end", reason: this.doneReason });

    // 先交付中间进度，保持「思考 → 动作」的展示顺序；
    // 进度不占决策预算，也不要求 Godot 回传结果。
    const progress = this.progressQueue.shift();
    if (progress) {
      return Promise.resolve({ type: "progress", ...progress });
    }

    const queued = this.queue.shift();
    if (queued) {
      this.lastActivityAt = Date.now();
      return Promise.resolve({ type: "action", action: queued });
    }

    return new Promise<PendingResponse>((resolve) => {
      const timer = setTimeout(() => {
        if (this.pollWaiter) this.pollWaiter = null;
        if (this.failError) { resolve({ type: "error", message: this.failError.message }); return; }
        if (this.done) { resolve({ type: "end", reason: this.doneReason }); return; }
        resolve({ type: "idle_timeout" });
      }, Math.max(0, maxWaitMs));

      this.pollWaiter = {
        resolve: (v) => { clearTimeout(timer); resolve(v); },
        reject: (e) => { clearTimeout(timer); resolve({ type: "error", message: e.message }); },
      };
    });
  }

  /** Godot 回传执行结果：唤醒对应挂起的工具调用。 */
  submitResult(seq: number, payload: ToolResultPayload): boolean {
    this.lastActivityAt = Date.now();
    const waiter = this.inflight.get(seq);
    if (!waiter) {
      // 结果早于服务端登记（极少见），暂存
      this.earlyResults.set(seq, payload);
      return false;
    }
    this.inflight.delete(seq);
    waiter.resolve({
      ok: payload.ok,
      outcome: payload.outcome,
      units: payload.units,
      legal_actions: payload.legal_actions,
      terrain: payload.terrain,
      economy: payload.economy,
    });
    return true;
  }

  /** 取走早到结果（工具挂起时先检查）。 */
  takeEarly(seq: number): ToolResultPayload | undefined {
    const v = this.earlyResults.get(seq);
    if (v) this.earlyResults.delete(seq);
    return v;
  }

  /** 会话正常结束（LLM 调用 end，或机动力全部耗尽）。 */
  finish(reason: string): void {
    if (this.done) return;
    this.done = true;
    this.doneReason = reason;
    if (this.pollWaiter) {
      const w = this.pollWaiter;
      this.pollWaiter = null;
      w.resolve({ type: "end", reason });
    }
  }

  /** 会话异常结束（模型报错 / 预算耗尽 / 超时）：让所有挂起的工具调用失败。 */
  fail(err: Error): void {
    this.failError = err;
    for (const [, w] of this.inflight) w.reject(err);
    this.inflight.clear();
    if (this.pollWaiter) {
      const w = this.pollWaiter;
      this.pollWaiter = null;
      w.resolve({ type: "error", message: err.message });
    }
  }
}

export class TurnStore {
  private map = new Map<string, TurnSession>();
  private seq = 0;
  private ttlMs: number;

  constructor(ttlMs = 30 * 60 * 1000) {
    this.ttlMs = ttlMs;
  }

  create(req: TurnRequest, idleTimeoutMs: number): TurnSession {
    this.cleanup();
    const id = `turn-${Date.now().toString(36)}-${(++this.seq).toString(36)}`;
    const s = new TurnSession(id, req, idleTimeoutMs);
    this.map.set(id, s);
    return s;
  }

  get(id: string): TurnSession | undefined {
    return this.map.get(id);
  }

  delete(id: string): void {
    this.map.delete(id);
  }

  size(): number {
    this.cleanup();
    return this.map.size;
  }

  clear(): void {
    this.map.clear();
  }

  cleanup(): void {
    const now = Date.now();
    for (const [k, v] of this.map) {
      if (v.finished || now - v.startedAt > this.ttlMs) this.map.delete(k);
    }
  }
}

export const turnStore = new TurnStore();

// ---------------------------------------------------------------------------
// 跨回合记忆（保留原有能力）
// ---------------------------------------------------------------------------
export interface SessionRecord {
  intent: string;
  last_action: string;
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
    return { intent: rec.intent, last_action: rec.last_action, turns: rec.turns };
  }

  update(sessionId: string | undefined, intent: string, lastAction: string): void {
    if (!sessionId) return;
    const prev = this.map.get(sessionId);
    this.map.set(sessionId, {
      intent,
      last_action: lastAction,
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