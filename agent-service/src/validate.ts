// 请求与动作校验。与设计文档 §3.6 的 Godot 侧 ActionValidator 同规则。
// 服务侧预校验 + Godot 侧二次校验 = 双防线；任一侧拒绝都会回退 hard 规则 AI。
import type { Budget, LegalAction, ToolName, TurnRequest } from "./types.ts";

export class ValidationError extends Error {
  public code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = "ValidationError";
    this.code = code;
  }
}

const TOOLS: ToolName[] = ["move", "attack", "stratagem", "retreat", "end"];

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function checkActions(actions: unknown, label: string): void {
  if (!Array.isArray(actions)) throw new ValidationError("bad_schema", `${label} must be an array`);
  const seen = new Set<string>();
  for (const raw of actions) {
    if (!isObject(raw)) throw new ValidationError("bad_schema", `${label} entries must be objects`);
    if (typeof raw.id !== "string" || raw.id.length === 0) {
      throw new ValidationError("bad_schema", `${label} action id required`);
    }
    if (seen.has(raw.id)) throw new ValidationError("bad_schema", `duplicate legal action id: ${raw.id}`);
    seen.add(raw.id);
    if (!TOOLS.includes(raw.tool as ToolName)) {
      throw new ValidationError("bad_schema", `unknown tool: ${String(raw.tool)}`);
    }
    if (typeof raw.actor !== "number") throw new ValidationError("bad_schema", `${label} action actor required`);
    if (raw.tool === "move" && raw.path !== undefined) {
      if (!Array.isArray(raw.path) || raw.path.length === 0) {
        throw new ValidationError("bad_schema", `${label} move.path must be a non-empty array`);
      }
      let prev: [number, number] | null = null;
      for (const step of raw.path as unknown[]) {
        if (!Array.isArray(step) || step.length !== 2 ||
            typeof step[0] !== "number" || typeof step[1] !== "number") {
          throw new ValidationError("bad_schema", `${label} move.path entries must be [x,y]`);
        }
        const cur = step as [number, number];
        if (prev && Math.abs(cur[0] - prev[0]) + Math.abs(cur[1] - prev[1]) !== 1) {
          throw new ValidationError("bad_schema", "move.path must be 4-neighbour steps (no diagonals)");
        }
        prev = cur;
      }
    }
  }
}

/** 校验开场请求（一个 AI 回合的初始状态）。 */
export function validateTurnRequest(body: unknown): TurnRequest {
  if (!isObject(body)) throw new ValidationError("bad_json", "body must be a JSON object");
  if (body.state_version !== 1) throw new ValidationError("bad_schema", "state_version must be 1");
  if (body.visibility !== "omniscient") throw new ValidationError("bad_schema", "visibility must be omniscient");
  if (typeof body.turn_key !== "string" || body.turn_key.length === 0) throw new ValidationError("bad_schema", "turn_key required");
  if (typeof body.controlled_vstate_id !== "number") throw new ValidationError("bad_schema", "controlled_vstate_id required");
  if (!Array.isArray(body.units)) throw new ValidationError("bad_schema", "units must be an array");
  if (!Array.isArray(body.terrain)) throw new ValidationError("bad_schema", "terrain must be an array");
  if (!isObject(body.economy)) throw new ValidationError("bad_schema", "economy must be an object");
  if (!Array.isArray(body.legal_actions) || body.legal_actions.length === 0) {
    throw new ValidationError("bad_schema", "legal_actions must be a non-empty array");
  }
  checkActions(body.legal_actions, "legal_actions");
  return body as unknown as TurnRequest;
}

/** 校验 Godot 回传的工具执行结果。 */
export function validateToolResult(body: unknown): {
  ok: boolean;
  outcome: string;
  units: Array<Record<string, unknown>>;
  legal_actions: LegalAction[];
  terrain?: Array<Record<string, unknown>>;
  economy?: Record<string, unknown>;
} {
  if (!isObject(body)) throw new ValidationError("bad_json", "body must be a JSON object");
  if (typeof body.ok !== "boolean") throw new ValidationError("bad_schema", "ok must be boolean");
  if (typeof body.outcome !== "string") throw new ValidationError("bad_schema", "outcome must be a string");
  if (!Array.isArray(body.units)) throw new ValidationError("bad_schema", "units must be an array");
  if (!Array.isArray(body.legal_actions)) throw new ValidationError("bad_schema", "legal_actions must be an array");
  checkActions(body.legal_actions, "legal_actions");
  if (body.terrain !== undefined && !Array.isArray(body.terrain)) {
    throw new ValidationError("bad_schema", "terrain must be an array when present");
  }
  if (body.economy !== undefined && !isObject(body.economy)) {
    throw new ValidationError("bad_schema", "economy must be an object when present");
  }
  return body as never;
}

/** 校验服务端选中的单个动作，作用于「当前最新状态」。 */
export function validateAction(
  id: unknown,
  live: {
    controlled_vstate_id: number;
    units: Array<Record<string, unknown>>;
    legal_actions: LegalAction[];
  },
  _budget: Budget,
): LegalAction {
  if (typeof id !== "string" || id.length === 0) {
    throw new ValidationError("invalid_action", "action id must be a non-empty string");
  }
  const action = live.legal_actions.find((a) => a.id === id);
  if (!action) throw new ValidationError("invalid_action", `unknown action id: ${id}`);

  const unit = live.units.find((u) => u.id === action.actor);
  if (!unit) throw new ValidationError("invalid_action", `actor ${action.actor} not in units`);
  if (unit.vstate !== live.controlled_vstate_id) {
    throw new ValidationError("invalid_action", `actor ${action.actor} is not controlled by vstate ${live.controlled_vstate_id}`);
  }
  if (unit.disabled === true) throw new ValidationError("invalid_action", `actor ${action.actor} is disabled`);

  const cost = action.cost ?? {};
  if (typeof unit.ap === "number" && (cost.ap ?? 0) > unit.ap) {
    throw new ValidationError("invalid_action", `actor ${action.actor} exceeds action_point`);
  }
  if (typeof unit.poker === "number" && (cost.poker ?? 0) > unit.poker) {
    throw new ValidationError("invalid_action", `actor ${action.actor} exceeds poker_point`);
  }

  return { ...action };
}
// ---------------------------------------------------------------------------
// 白兵战校验
// ---------------------------------------------------------------------------
const BATTLE_UNIT_TYPES = ["将", "骑", "象", "弓", "步"];
const BATTLE_ORDERS = ["前进", "待机", "后退"];

function checkBattleSide(side: unknown, label: string): void {
  if (!isObject(side)) throw new ValidationError("bad_schema", `${label} must be an object`);
  if (typeof side.soldiers !== "number") throw new ValidationError("bad_schema", `${label}.soldiers must be a number`);
  if (typeof side.tactic_point !== "number") throw new ValidationError("bad_schema", `${label}.tactic_point must be a number`);
  if (!Array.isArray(side.units)) throw new ValidationError("bad_schema", `${label}.units must be an array`);
  for (const u of side.units as unknown[]) {
    if (!isObject(u)) throw new ValidationError("bad_schema", `${label}.units entries must be objects`);
    if (!BATTLE_UNIT_TYPES.includes(u.type as string)) {
      throw new ValidationError("bad_schema", `unknown battle unit type: ${String(u.type)}`);
    }
    if (typeof u.hp !== "number") throw new ValidationError("bad_schema", `${label}.units[].hp must be a number`);
  }
}

/** 校验白兵战开场请求。 */
export function validateBattleRequest(body: unknown): import("./types.ts").BattleRequest {
  if (!isObject(body)) throw new ValidationError("bad_json", "body must be a JSON object");
  if (body.battle_version !== 1) throw new ValidationError("bad_schema", "battle_version must be 1");
  if (body.visibility !== "omniscient") throw new ValidationError("bad_schema", "visibility must be omniscient");
  if (typeof body.battle_key !== "string" || body.battle_key.length === 0) {
    throw new ValidationError("bad_schema", "battle_key required");
  }
  if (typeof body.controlled_actor_id !== "number") throw new ValidationError("bad_schema", "controlled_actor_id required");
  if (typeof body.enemy_actor_id !== "number") throw new ValidationError("bad_schema", "enemy_actor_id required");
  if (body.side !== "attacker" && body.side !== "defender") throw new ValidationError("bad_schema", "side must be attacker|defender");
  if (typeof body.turn !== "number") throw new ValidationError("bad_schema", "turn must be a number");
  checkBattleSide(body.controlled, "controlled");
  checkBattleSide(body.enemy, "enemy");
  if (!Array.isArray(body.legal_tactics)) throw new ValidationError("bad_schema", "legal_tactics must be an array");
  for (const t of body.legal_tactics as unknown[]) {
    if (!isObject(t)) throw new ValidationError("bad_schema", "legal_tactics entries must be objects");
    if (typeof t.name !== "string" || typeof t.cost !== "number") {
      throw new ValidationError("bad_schema", "legal_tactics entries need name and cost");
    }
  }
  return body as never;
}

/** 校验 Godot 回传的白兵战指令结果。 */
export function validateBattleResult(body: unknown): import("./types.ts").BattleResultPayload {
  if (!isObject(body)) throw new ValidationError("bad_json", "body must be a JSON object");
  if (typeof body.ok !== "boolean") throw new ValidationError("bad_schema", "ok must be boolean");
  if (typeof body.outcome !== "string") throw new ValidationError("bad_schema", "outcome must be a string");
  if (typeof body.turn !== "number") throw new ValidationError("bad_schema", "turn must be a number");
  checkBattleSide(body.controlled, "controlled");
  checkBattleSide(body.enemy, "enemy");
  return body as never;
}

export { BATTLE_ORDERS, BATTLE_UNIT_TYPES };
