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
  /** 我方为攻方还是守方，复用白兵战 BattleRequest.side 取值；旧请求体可缺省。 */
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

export interface BattleUnit {
  type: BattleUnitType;
  /** 当前类型总血量；<=0 表示该兵种已消失。 */
  hp: number;
  order: BattleOrder;
}

export interface BattleRequest {
  battle_version: 1;
  visibility: "omniscient";
  /** 本场战斗的稳定标识。 */
  battle_key: string;
  diffculities: number;
  /** 我方（受控方）武将 id 与敌方武将 id。 */
  controlled_actor_id: number;
  enemy_actor_id: number;
  /** 我方为攻方还是守方。 */
  side: "attacker" | "defender";
  /** 战斗回合数。 */
  turn: number;
  controlled: {
    name?: string;
    hp?: number;
    soldiers: number;
    tactic_point: number;
    units: BattleUnit[];
  };
  enemy: {
    name?: string;
    hp?: number;
    soldiers: number;
    tactic_point: number;
    units: BattleUnit[];
  };
  /** 己方可用的计策（含战术值消耗）。 */
  legal_tactics: Array<{ name: string; cost: number }>;
  budget?: Partial<BattleBudget>;
}

export interface BattleBudget {
  max_turns: number;
  max_tool_calls: number;
  max_tokens: number;
  idle_timeout_ms: number;
}

/** 白兵战待执行指令。 */
export type BattlePending =
  | { type: "order"; seq: number; unit: BattleUnitType; order: BattleOrder; reasoning: string }
  | { type: "tactic"; seq: number; tactic: string; reasoning: string }
  | { type: "end_turn"; seq: number; reasoning: string }
  | { type: "end_battle"; reason: string }
  | { type: "idle_timeout" }
  | { type: "error"; message: string };

/** Godot 回传的战斗指令执行结果。 */
export interface BattleResultPayload {
  ok: boolean;
  /** 人类可读结果。 */
  outcome: string;
  /** 执行后的最新战斗状态（同 BattleRequest 的 controlled/enemy/legal_tactics/turn）。 */
  turn: number;
  controlled: BattleRequest["controlled"];
  enemy: BattleRequest["enemy"];
  legal_tactics: Array<{ name: string; cost: number }>;
}
