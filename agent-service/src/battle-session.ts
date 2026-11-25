// 白兵战（Battle）回合会话。
//
// 驱动模型与战役回合会话相同，但场景/工具/提示词完全不同：
//   1. Godot 在 attack 触发白兵战时 POST /ai/battle 开启战斗会话
//   2. 服务端跑独立 agent loop：LLM 用 set_order 给每个兵种下命令、use_tactic 用计
//   3. 每个命令交给 Godot 执行，回传最新战斗状态
//   4. LLM 调 end_turn 结束**本战斗回合**的决策，交还引擎结算推进
//   5. 下一战斗回合开始时 Godot 调 resume，agent loop 继续问 LLM
//   6. 整场战斗仍是**一个会话**（Q3）
//   7. 主回合会话在此期间挂起（工具 execute 未返回，不计 Agent 空闲超时）
//
// 依据：`clBattleFight.gd` 的兵种/命令模型、`Static_Manager.TACTICS` 的计策表。
import type {
  BattlePending, BattleRequest, BattleResultPayload, BattleUnitType, RandomAnswer, RandomAsk,
} from "./types.ts";

export interface BattleOutcome {
  ok: boolean;
  outcome: string;
  turn: number;
  controlled: BattleRequest["controlled"];
  enemy: BattleRequest["enemy"];
  legal_tactics: Array<{ name: string; cost: number }>;
}

export interface BattleCommand {
  seq: number;
  kind: "order" | "tactic" | "end_turn";
}

/** 计策预估的返回形状（Godot 侧 TacticProjection 给出）。 */
export type TacticEstimate = Record<string, unknown>;

type Resolver<T> = (v: T) => void;

export class BattleSession {
  readonly id: string;
  readonly req: BattleRequest;
  readonly startedAt = Date.now();
  idleTimeoutMs: number;

  /** 待 Godot 取走的指令。 */
  private queue: BattlePending[] = [];
  /** Godot 长轮询等待者。 */
  private poller: Resolver<BattlePending> | null = null;
  /** agent loop 等待「下一战斗回合」的解析器。 */
  private resume: Resolver<boolean> | null = null;
  /**
   * 粘性标志：Godot 可能在 agent loop 注册等待者之前就调用 resume
   * （引擎结算往往比 LLM 收尾更快），这个标志保证信号不会丢。
   */
  private nextTurnPending = false;
  private turnEndedFlag = false;
  /** 已下发、等待 Godot 回传结果的指令。 */
  private readonly inflight = new Map<number, Resolver<BattleOutcome>>();

  /**
   * 只读查询（estimate_tactic）：与回合会话同一套「排队 → Godot 现算 → /estimate 回填」通道。
   * 不占指令 seq，不进 commands，不推进战局。
   */
  private askSeq = 0;
  private askBatch: RandomAsk[] = [];
  private readonly askInflight = new Map<number, { resolve: Resolver<TacticEstimate>; reject: (e: Error) => void }>();
  private readonly earlyAnswers = new Map<number, TacticEstimate>();

  readonly commands: BattleCommand[] = [];
  private seq = 0;
  private done = false;
  private doneReason = "";
  private failError: Error | null = null;

  lastActivityAt = Date.now();

  constructor(id: string, req: BattleRequest, idleTimeoutMs: number) {
    this.id = id;
    this.req = req;
    this.idleTimeoutMs = idleTimeoutMs;
  }

  get finished(): boolean { return this.done; }
  get reason(): string { return this.doneReason; }

  idleRemaining(): number {
    return this.idleTimeoutMs - (Date.now() - this.lastActivityAt);
  }

  /** Agent 仍在活动：任何工具调用（含 inspect_battlefield）都重置空闲计时。 */
  touch(): void {
    this.lastActivityAt = Date.now();
  }

  // ---------------- agent 侧：产出一条指令 ----------------
  private emit(payload: BattlePending, kind: BattleCommand["kind"]): Promise<BattleOutcome> {
    const seq = ++this.seq;
    (payload as { seq: number }).seq = seq;
    this.commands.push({ seq, kind });
    return new Promise<BattleOutcome>((resolve) => {
      this.inflight.set(seq, resolve);
      if (this.poller) {
        const p = this.poller;
        this.poller = null;
        p(payload);
        return;
      }
      this.queue.push(payload);
    });
  }

  setOrder(unit: BattleUnitType, order: "前进" | "待机" | "后退", reasoning: string) {
    return this.emit({ type: "order", seq: 0, unit, order, reasoning }, "order");
  }

  useTactic(tactic: string, reasoning: string) {
    return this.emit({ type: "tactic", seq: 0, tactic, reasoning }, "tactic");
  }

  /** 登记一次计策预估查询并挂起，直到 Godot 用引擎算完回填。 */
  askEstimate(tactic: string): Promise<TacticEstimate> {
    const ask: RandomAsk = { id: ++this.askSeq, kind: "estimate_tactic", tactic };
    this.askBatch.push(ask);
    return new Promise<TacticEstimate>((resolve, reject) => {
      this.askInflight.set(ask.id, { resolve, reject });
      const early = this.earlyAnswers.get(ask.id);
      if (early) {
        this.earlyAnswers.delete(ask.id);
        this.askInflight.delete(ask.id);
        resolve(early);
        return;
      }
      // 有轮询在等 → 连同同批查询一起交付
      if (this.poller) {
        const p = this.poller;
        this.poller = null;
        p({ type: "ask", asks: this.takeAskBatch() } as never);
      }
    });
  }

  private takeAskBatch(): RandomAsk[] {
    const asks = this.askBatch;
    this.askBatch = [];
    return asks;
  }

  /** 当前排队中的查询（随 /result 响应捎带下发，省一次长轮询往返）。 */
  pendingAsks(): RandomAsk[] {
    return this.askBatch.length > 0 ? [...this.askBatch] : [];
  }

  /**
   * Godot 回传预估结果。返回 false 表示服务端没在等这个 id
   * （响应早于登记，或会话已结束）；早到的回答会暂存、等查询来取。
   */
  submitAnswers(answers: RandomAnswer[]): boolean {
    this.lastActivityAt = Date.now();
    let touched = false;
    for (const ans of answers) {
      const waiter = this.askInflight.get(ans.id);
      if (!waiter) {
        this.earlyAnswers.set(ans.id, ans.data);
        continue;
      }
      this.askInflight.delete(ans.id);
      // 已回填的查询不必再随 /result 捎带（同一 prompt 里连续查多次会积累）
      this.askBatch = this.askBatch.filter((a) => a.id !== ans.id);
      waiter.resolve(ans.data);
      touched = true;
    }
    return touched;
  }

  /** 结束「本战斗回合」的决策（不是结束整场战斗）。 */
  endTurn(reasoning: string) {
    return this.emit({ type: "end_turn", seq: 0, reasoning }, "end_turn");
  }

  /**
   * 本回合已经交还引擎（end_turn 已下发过）。
   * 模型漏调 end_turn 时由回合收敛兜底补发，同一回合只允许一次。
   */
  get turnEnded(): boolean { return this.turnEndedFlag; }
  markTurnEnded(): void { this.turnEndedFlag = true; }

  /**
   * 会话内已经没有在途指令与待取队列。
   * 真值时说明模型这一轮既没调工具、也没结束回合就收尾了 —— 没人会再推进引擎。
   */
  get idleNoCommand(): boolean {
    return !this.done && !this.failError && this.inflight.size === 0 && this.queue.length === 0 && !this.turnEndedFlag;
  }

  get inflightCount(): number { return this.inflight.size; }
  get queuedCount(): number { return this.queue.length; }

  // ---------------- Godot 侧：取指令 ----------------
  nextCommand(maxWaitMs: number): Promise<BattlePending> {
    if (this.failError) return Promise.resolve({ type: "error", message: this.failError.message });
    if (this.done) return Promise.resolve({ type: "end_battle", reason: this.doneReason } as never);

    const queued = this.queue.shift();
    if (queued) {
      this.lastActivityAt = Date.now();
      return Promise.resolve(queued);
    }
    // 其次交付只读查询（模型要先看预估再决定用不用计）
    if (this.askBatch.length > 0) {
      this.lastActivityAt = Date.now();
      return Promise.resolve({ type: "ask", asks: this.takeAskBatch() } as never);
    }
    return new Promise<BattlePending>((resolve) => {
      const timer = setTimeout(() => {
        this.poller = null;
        if (this.failError) { resolve({ type: "error", message: this.failError.message }); return; }
        if (this.done) { resolve({ type: "end_battle", reason: this.doneReason } as never); return; }
        resolve({ type: "idle_timeout" });
      }, Math.max(0, maxWaitMs));
      this.poller = (v) => { clearTimeout(timer); resolve(v); };
    });
  }

  // ---------------- Godot 侧：回传结果 ----------------
  submitResult(seq: number, payload: BattleResultPayload): void {
    this.lastActivityAt = Date.now();
    const r = this.inflight.get(seq);
    if (!r) return;
    this.inflight.delete(seq);
    r({
      ok: payload.ok,
      outcome: payload.outcome,
      turn: payload.turn,
      controlled: payload.controlled,
      enemy: payload.enemy,
      legal_tactics: payload.legal_tactics,
    });
  }

  // ---------------- 战斗回合屏障 ----------------
  /** 引擎结算完毕、进入下一个战斗回合：唤醒 agent loop（信号可早到）。 */
  resumeNextTurn(): void {
    this.lastActivityAt = Date.now();
    const r = this.resume;
    if (r) {
      this.resume = null;
      r(true);
      return;
    }
    // agent loop 还没开始等：记下来，等它来取
    this.nextTurnPending = true;
  }

  /** agent loop 等待下一战斗回合；超时或战斗结束返回 false。 */
  waitForNextTurn(maxWaitMs: number): Promise<boolean> {
    if (this.done) return Promise.resolve(false);
    // 早到的 resume 信号立即消费
    if (this.nextTurnPending) {
      this.nextTurnPending = false;
      this.turnEndedFlag = false;
      return Promise.resolve(true);
    }
    return new Promise<boolean>((resolve) => {
      const timer = setTimeout(() => {
        this.resume = null;
        resolve(false);
      }, Math.max(0, maxWaitMs));
      this.resume = (v) => { clearTimeout(timer); if (v) this.turnEndedFlag = false; resolve(v); };
    });
  }

  // ---------------- 终态 ----------------
  /** 战斗真正结束（分出胜负 / 撤退 / 主将阵亡）。 */
  finish(reason: string): void {
    if (this.done) return;
    this.done = true;
    this.doneReason = reason;
    if (this.poller) {
      const p = this.poller;
      this.poller = null;
      p({ type: "end_battle", reason } as never);
    }
    const r = this.resume;
    this.resume = null;
    if (r) r(false);
  }

  fail(err: Error): void {
    this.failError = err;
    for (const [, w] of this.askInflight) w.reject(err);
    this.askInflight.clear();
    this.askBatch = [];
    for (const [seq, r] of this.inflight) {
      r({
        ok: false, outcome: err.message, turn: this.req.turn,
        controlled: this.req.controlled, enemy: this.req.enemy, legal_tactics: this.req.legal_tactics,
      });
      this.inflight.delete(seq);
    }
    if (this.poller) {
      const p = this.poller;
      this.poller = null;
      p({ type: "error", message: err.message });
    }
    const r = this.resume;
    this.resume = null;
    if (r) r(false);
  }
}

export class BattleStore {
  private map = new Map<string, BattleSession>();
  private seq = 0;
  private ttlMs: number;

  constructor(ttlMs = 30 * 60 * 1000) {
    this.ttlMs = ttlMs;
  }

  create(req: BattleRequest, idleTimeoutMs: number): BattleSession {
    this.cleanup();
    const id = `battle-${Date.now().toString(36)}-${(++this.seq).toString(36)}`;
    const s = new BattleSession(id, req, idleTimeoutMs);
    this.map.set(id, s);
    return s;
  }

  get(id: string): BattleSession | undefined { return this.map.get(id); }
  delete(id: string): void { this.map.delete(id); }

  size(): number { this.cleanup(); return this.map.size; }
  clear(): void { this.map.clear(); }

  cleanup(): void {
    const now = Date.now();
    for (const [k, v] of this.map) {
      if (v.finished || now - v.startedAt > this.ttlMs) this.map.delete(k);
    }
  }
}

export const battleStore = new BattleStore();