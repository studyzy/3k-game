// AI Agent 决策轨迹采集（供 /ai/dashboard 调试面板使用）。
// 只存内存环形缓冲，不落盘、不持久化；不记录任何密钥。
export type TraceEventType =
  | "system" | "user" | "turn" | "assistant" | "tool_call" | "tool_result"
  | "final" | "error" | "mock";

export interface TraceEvent {
  seq: number;
  at_ms: number;
  type: TraceEventType;
  turn?: number;
  tool?: string;
  text?: string;
  args?: unknown;
  result?: unknown;
  ok?: boolean;
}

export interface DecisionTrace {
  id: string;
  started_at: string;
  finished_at?: string;
  mode: "mock" | "stub" | "pi";
  model: string;
  turn_key: string;
  diffculities: number;
  ai_agent_mode?: boolean;
  controlled_vstate_id: number;
  legal_actions_count: number;
  status: "running" | "ok" | "fallback" | "error";
  error?: string;
  elapsed_ms?: number;
  budget_used?: { tokens: number; turns: number; tool_calls: number; cache_read?: number; cache_write?: number };
  system_prompt: string;
  user_message: string;
  events: TraceEvent[];
  actions?: Array<{ seq: number; tool: string; actor: number; id: string; reasoning: string }>;
  intent?: string;
}

export interface TraceSummary {
  id: string;
  started_at: string;
  mode: string;
  model: string;
  turn_key: string;
  status: string;
  elapsed_ms?: number;
  turns?: number;
  tool_calls?: number;
  events: number;
  intent?: string;
}

function summarize(t: DecisionTrace): TraceSummary {
  return {
    id: t.id,
    started_at: t.started_at,
    mode: t.mode,
    model: t.model,
    turn_key: t.turn_key,
    status: t.status,
    elapsed_ms: t.elapsed_ms,
    turns: t.budget_used?.turns,
    tool_calls: t.budget_used?.tool_calls,
    events: t.events.length,
    intent: t.intent,
  };
}

export class TraceStore {
  private items: DecisionTrace[] = [];
  private seq = 0;
  private limit: number;

  constructor(limit = 50) {
    this.limit = limit;
  }

  create(init: Pick<DecisionTrace, "mode" | "model" | "turn_key" | "diffculities" | "controlled_vstate_id" | "legal_actions_count" | "ai_agent_mode" | "system_prompt" | "user_message">): DecisionTrace {
    this.seq += 1;
    const t: DecisionTrace = {
      id: `tr-${Date.now().toString(36)}-${this.seq.toString(36)}`,
      started_at: new Date().toISOString(),
      ...init,
      status: "running",
      events: [],
    };
    this.items.unshift(t);
    if (this.items.length > this.limit) this.items.length = this.limit;
    return t;
  }

  add(t: DecisionTrace, type: TraceEventType, fields: Partial<TraceEvent> = {}): void {
    const started = Date.parse(t.started_at);
    t.events.push({
      seq: t.events.length + 1,
      at_ms: Math.max(0, Date.now() - started),
      type,
      ...fields,
    });
  }

  finish(t: DecisionTrace, fields: Partial<DecisionTrace>): void {
    t.finished_at = new Date().toISOString();
    Object.assign(t, fields);
  }

  list(limit = 50): TraceSummary[] {
    return this.items.slice(0, Math.min(limit, this.limit)).map(summarize);
  }

  get(id: string): DecisionTrace | undefined {
    return this.items.find((t) => t.id === id);
  }

  clear(): void {
    this.items = [];
  }

  size(): number {
    return this.items.length;
  }
}

export const traceStore = new TraceStore(Number(process.env.TRACE_LIMIT ?? 50));
