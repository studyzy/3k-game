// 全知 AI Agent 敌方决策服务 · 共享类型
// 对应 docs/plans/2026-11-18-ai-agent-enemy-design.md §5 接口契约

export type ToolName = "move" | "attack" | "stratagem" | "retreat" | "end";

export interface LegalAction {
  id: string;
  tool: ToolName;
  actor: number;
  target?: number;
  pos?: [number, number];
  skill?: string;
  city?: number;
  cost?: { ap?: number; poker?: number; cd?: number };
  rate?: number;
}

export interface Budget {
  max_actions: number;
  max_tokens: number;
  max_turns: number;
  max_tool_calls: number;
  lookahead: number;
  allow_memory: boolean;
  timeout_ms: number;
}

export interface DecideRequest {
  state_version: number;
  visibility: "omniscient";
  static_bundle_id: string;
  turn_key: string;
  controlled_vstate_id: number;
  diffculities: number;
  session_id?: string;
  units: Array<Record<string, unknown>>;
  terrain: Array<Record<string, unknown>>;
  economy: Record<string, unknown>;
  legal_actions: LegalAction[];
  memory?: Record<string, unknown>;
  budget?: Partial<Budget>;
  /** 标题界面「大模型」难度标记，仅用于 trace 审计 */
  ai_agent_mode?: boolean;
}

export interface PlanItem {
  id: string;
  order: number;
}

export interface DecideResponse {
  plan: PlanItem[];
  intent: string;
  counterplay?: string;
  model: string;
  elapsed_ms: number;
  budget_used: { tokens: number; turns: number; tool_calls: number };
  trace: Array<{ turn: number; tool: string; ok: boolean }>;
}
