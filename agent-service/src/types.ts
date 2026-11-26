// AI Agent 敌方决策服务 · 共享类型（服务端驱动逐步交互）
// 对应 docs/plans/2026-11-18-ai-agent-enemy-design.md §5 接口契约
//
// 模型：一个 AI 回合 = 一个服务端会话。服务端跑 agent loop 驱动 LLM，
// 每次 LLM 调用动作工具时把动作挂起，等 Godot 长轮询取走执行并回传结果，
// 服务端把结果（含最新 units / legal_actions）喂回 LLM 继续思考，直到 end。

export type ToolName = "move" | "attack" | "stratagem" | "retreat" | "end";

export interface LegalAction {
  id: string;
  tool: ToolName;
  actor: number;
  target?: number;
  pos?: [number, number];
  /** move 专用：不含起点、含终点的逐格路径（每步上下左右相邻）。 */
  path?: Array<[number, number]>;
  skill?: string;
  city?: number;
  cost?: { ap?: number; poker?: number; cd?: number };
  rate?: number;
}

/** 地形格：[x, y, "地形名"]。平原不列出（默认值），米屋/装备店/医馆/太守府 也作为地形名出现。 */
export type TerrainCell = [number, number, string];

export interface Budget {
  /** 单个回合内最多允许 LLM 发起多少次动作。 */
  max_actions: number;
  max_tokens: number;
  /** 单次 LLM 请求内部的模型轮数上限。 */
  max_turns: number;
  max_tool_calls: number;
  lookahead: number;
  allow_memory: boolean;
  /**
   * 空闲超时：每天 Godot 回传结果后开始计时，
   * 该时间内 Agent 没有产出下一个动作 → 判定 LLM 已死，Godot 回退 hard。
   */
  idle_timeout_ms: number;
}

/** 开场请求：Godot 开启一个 AI 回合会话。 */
export interface TurnRequest {
  state_version: number;
  visibility: "omniscient";
  static_bundle_id: string;
  turn_key: string;
  controlled_vstate_id: number;
  /** 我方为攻方还是守方，复用白兵战 side 取值；旧请求体可缺省。 */
  side?: "attacker" | "defender";
  diffculities: number;
  session_id?: string;
  units: Array<Record<string, unknown>>;
  /** 地形：只列非平原格 [x, y, "地形名"]；未列出的格子一律是平原。整局战斗不变，只下发一次。 */
  terrain: TerrainCell[];
  economy: Record<string, unknown>;
  legal_actions: LegalAction[];
  memory?: Record<string, unknown>;
  budget?: Partial<Budget>;
  /** 标题界面「大模型」难度标记，仅用于 trace 审计 */
  ai_agent_mode?: boolean;
}

/** Godot 执行完一个动作后回传的结果。D1/D2：携带全部武将最新信息与重算后的合法动作。 */
/** Godot 回传的结算摘要：一个施术者 + 每个受影响武将的变化与当前值。 */
export interface SettlementOutcome {
  ok: boolean;
  name: string;
  caster: string;
  effects: Array<{
    id: number; name: string; note: string;
    soldiers: number; hp: number; status: string[];
  }>;
}

export interface ToolResultPayload {
  /** 是否执行成功。失败时 Godot 侧通常已决定回退，但这里仍如实回传。 */
  ok: boolean;
  /** 人类可读的结果摘要，直接进 prompt。 */
  outcome: string;
  /** 所有武将的最新状态（服务端不解析，原样喂给 LLM）。 */
  units: Array<Record<string, unknown>>;
  /** 执行后重算的合法动作。 */
  legal_actions: LegalAction[];
  /** 地形不会随战斗变化，通常不回传。 */
  terrain?: TerrainCell[];
  economy?: Record<string, unknown>;
  /** 用计结算摘要（仅 stratagem 回传）：成功与否 + 每个受影响武将的变化与当前值。 */
  stratagem?: SettlementOutcome;
  /** 白兵战结算摘要（仅 attack 回传），结构同用计，另带 loser 名字。 */
  battle?: SettlementOutcome & { loser?: string };
}

/**
 * 只读查询：模型想知道命中率与后果时，由 Godot 用引擎现算后回填。
 * 在 pending 响应里以 ask 形式下发，Godot 算完 POST 回 /estimate。
 *   - estimate_stratagem：大战场计策（actor 对 target 用 skill）
 *   - estimate_move：大战场行军（actor 走到 to，可一次给多个目标点）
 *   - estimate_tactic：白兵战战术（只用 tactic 名，施计者固定为我方主将）
 */
export type RandomAsk =
  | { id: number; kind: "estimate_stratagem"; actor: number; target: number; skill: string }
  | { id: number; kind: "estimate_move"; actor: number; to: Array<[number, number]>; free?: boolean }
  | { id: number; kind: "estimate_tactic"; tactic: string };

/** Godot 对只读查询的回答（结构由 Godot 的 StratagemProjection 给出）。 */
export interface RandomAnswer {
  id: number;
  data: Record<string, unknown>;
}

/** 待 Godot 执行的动作。 */
export interface PendingAction {
  seq: number;
  tool: ToolName;
  actor: number;
  /** 动作 id（来自 legal_actions）。 */
  id: string;
  /** 完整动作参数，供 Godot 落地。 */
  action: LegalAction;
  /** LLM 给出的理由。 */
  reasoning: string;
}

/** 长轮询结果。 */
export type PendingResponse =
  | { type: "action"; action: PendingAction }
  /** Agent 的中间进度（思考文本 / 只读工具调用），只用于界面展示，不需要 Godot 执行。 */
  | { type: "progress"; seq: number; text: string }
  /** 只读查询：Godot 算完把结果 POST 到 /ai/turn/:id/estimate，不推进战局。 */
  | { type: "ask"; asks: RandomAsk[] }
  | { type: "end"; reason: string }
  | { type: "end_battle"; reason: string }
  | { type: "idle_timeout" }
  | { type: "error"; message: string };
// ---------------------------------------------------------------------------
// 白兵战（Battle）会话：两个武将带兵对垒，独立 Agent，独立提示词/场景/Tools
// ---------------------------------------------------------------------------

/** 白兵战兵种键（`clBattleFight.get_attacker_unit_types` 确认）。 */
export type BattleUnitType = "将" | "骑" | "象" | "弓" | "步";

/** 白兵战命令（`AI_Control.gd` 确认）。 */
export type BattleOrder = "前进" | "待机" | "后退";

// ---------------------------------------------------------------------------
// 白兵战（Battle）异步 tick：一场战斗一个会话，每拍快照进、计划出
// ---------------------------------------------------------------------------

export interface BattleUnitV2 {
  type: BattleUnitType;
  /** 该兵种所有存活单位的总血量。 */
  hp: number;
  /** 存活单位数。 */
  count: number;
  order: BattleOrder;
  /** 离对方主将最近的单位的坐标。 */
  x: number;
  y: number;
  shoot_range: number;
  attack_range: number;
  dist_to_other_main: number;
  other_main_in_shoot_range: boolean;
}

export interface BattleSideV2 {
  name: string;
  hp: number;
  soldiers: number;
  tactic_point: number;
  buffs: Array<{ name: string; turns: number }>;
  units: BattleUnitV2[];
}

export interface BattleTacticOption {
  name: string;
  cost: number;
  rate: number;
  summary: string;
}

export interface BattleLastPlan {
  tick: number;
  orders: Partial<Record<BattleUnitType, BattleOrder>>;
  orders_applied: BattleUnitType[];
  orders_rejected: Array<{ unit: string; reason: string }>;
  tactic: string | null;
  tactic_status: "applied" | "pending" | "rejected" | "none";
  reason: string;
  age_ms: number;
}

export interface BattleSnapshotV2 {
  battle_version: 2;
  battle_key: string;
  tick: number;
  elapsed_ms: number;
  diffculities: number;
  side: "attacker" | "defender";
  controlled_actor_id: number;
  enemy_actor_id: number;
  turn: number;
  terrain: { name: string; is_city: boolean };
  controlled: BattleSideV2;
  enemy: BattleSideV2;
  legal_tactics: BattleTacticOption[];
  last_plan?: BattleLastPlan | null;
}

export interface BattlePlan {
  orders: Partial<Record<BattleUnitType, BattleOrder>>;
  tactic: string | null;
  memory?: string;
  reasoning?: string;
}

export interface BattleValidationRejected {
  kind: "order" | "tactic" | "plan";
  value: string;
  reason: string;
}

export interface BattleTickBudget {
  max_tokens: number;
  timeout_ms: number;
}

export interface BattleOpenRequest {
  battle_key: string;
  controlled_actor_id: number;
  enemy_actor_id: number;
  side: "attacker" | "defender";
  diffculities: number;
}

export interface BattleTickResult {
  tick: number;
  plan: BattlePlan;
  rejected: BattleValidationRejected[];
  latency_ms: number;
  /** 服务端模型调用超时：客户端应计一次失败。 */
  timeout?: boolean;
  /** 本拍实际消耗的模型 token（模型未调用时为 0）。 */
  usage?: { tokens: number };
}
