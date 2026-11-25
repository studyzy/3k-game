// 请求与动作校验。与设计文档 §3.6 的 Godot 侧 ActionValidator 同规则。
// 服务侧预校验 + Godot 侧二次校验 = 双防线；任一侧拒绝都会回退 hard 规则 AI。
import type { Budget, LegalAction, RandomAnswer, ToolName, TurnRequest } from "./types.ts";

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

/** 地形投影格式：[x, y, "地形名"]，只列非平原格（未列出即平原）。 */
function checkTerrain(terrain: unknown): void {
  if (!Array.isArray(terrain)) throw new ValidationError("bad_schema", "terrain must be an array");
  for (const cell of terrain) {
    if (!Array.isArray(cell) || cell.length !== 3 ||
        typeof cell[0] !== "number" || typeof cell[1] !== "number" ||
        typeof cell[2] !== "string" || cell[2].length === 0) {
      throw new ValidationError("bad_schema", "terrain entries must be [x, y, \"地形名\"]");
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
  if (body.side !== undefined && body.side !== "attacker" && body.side !== "defender") {
    throw new ValidationError("bad_schema", "side must be attacker|defender");
  }
  if (!Array.isArray(body.units)) throw new ValidationError("bad_schema", "units must be an array");
  checkTerrain(body.terrain);
  if (!isObject(body.economy)) throw new ValidationError("bad_schema", "economy must be an object");
  if (!Array.isArray(body.legal_actions) || body.legal_actions.length === 0) {
    throw new ValidationError("bad_schema", "legal_actions must be a non-empty array");
  }
  checkActions(body.legal_actions, "legal_actions");
  return body as unknown as TurnRequest;
}

export function validateAnswers(body: unknown): RandomAnswer[] {
  if (!isObject(body)) throw new ValidationError("bad_json", "body must be a JSON object");
  if (!Array.isArray(body.answers) || body.answers.length === 0) {
    throw new ValidationError("bad_schema", "answers must be a non-empty array");
  }
  const ret: RandomAnswer[] = [];
  for (const raw of body.answers as unknown[]) {
    if (!isObject(raw)) throw new ValidationError("bad_schema", "answers entries must be objects");
    if (typeof raw.id !== "number") throw new ValidationError("bad_schema", "answers[].id must be a number");
    if (raw.data === undefined) throw new ValidationError("bad_schema", "answers[].data required");
    ret.push({ id: raw.id, data: isObject(raw.data) ? raw.data : { value: raw.data } });
  }
  return ret;
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
  if (body.terrain !== undefined) checkTerrain(body.terrain);
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
// 白兵战校验：开场请求 + 每拍快照（v2）
// ---------------------------------------------------------------------------
const BATTLE_UNIT_TYPES = ["将", "骑", "象", "弓", "步"];
const BATTLE_ORDERS = ["前进", "待机", "后退"];
const BATTLE_TACTIC_STATUS = ["applied", "pending", "rejected", "none"];

// 上限：/tick 的 body 最大 1MiB，若不截断，超长字符串会原样进提示词（成本/延迟爆炸）。
const MAX_BATTLE_KEY = 80;
const MAX_SIDE_NAME = 80;
const MAX_BUFF_NAME = 40;
const MAX_UNITS = 8;
const MAX_LEGAL_TACTICS = 8;
const MAX_TACTIC_NAME = 20;
const MAX_TACTIC_SUMMARY = 200;
const MAX_REJECTED_ORDERS = 10;
const MAX_REJECT_TEXT = 200;

export function validateBattleOpenRequest(
  body: unknown,
): import("./types.ts").BattleOpenRequest {
  if (!isObject(body)) throw new ValidationError("bad_json", "body must be a JSON object");
  if (typeof body.battle_key !== "string" || body.battle_key.length === 0) {
    throw new ValidationError("bad_schema", "battle_key required");
  }
  if (body.battle_key.length > MAX_BATTLE_KEY) {
    throw new ValidationError("bad_schema", "battle_key too long");
  }
  if (typeof body.controlled_actor_id !== "number") {
    throw new ValidationError("bad_schema", "controlled_actor_id required");
  }
  if (typeof body.enemy_actor_id !== "number") {
    throw new ValidationError("bad_schema", "enemy_actor_id required");
  }
  if (body.side !== "attacker" && body.side !== "defender") {
    throw new ValidationError("bad_schema", "side must be attacker|defender");
  }
  if (typeof body.diffculities !== "number") {
    throw new ValidationError("bad_schema", "diffculities must be a number");
  }
  return body as never;
}

function checkBattleUnitV2(u: unknown, label: string): void {
  if (!isObject(u)) throw new ValidationError("bad_schema", label + " must be an object");
  if (!BATTLE_UNIT_TYPES.includes(u.type as string)) {
    throw new ValidationError("bad_schema", "unknown battle unit type: " + String(u.type));
  }
  for (const k of ["hp", "count", "x", "y", "shoot_range", "attack_range", "dist_to_other_main"]) {
    if (typeof u[k] !== "number") {
      throw new ValidationError("bad_schema", label + "." + k + " must be a number");
    }
  }
  if (typeof u.order !== "string" || !BATTLE_ORDERS.includes(u.order)) {
    throw new ValidationError("bad_schema", label + ".order invalid");
  }
  if (typeof u.other_main_in_shoot_range !== "boolean") {
    throw new ValidationError("bad_schema", label + ".other_main_in_shoot_range must be boolean");
  }
}

function checkBattleSideV2(side: unknown, label: string): void {
  if (!isObject(side)) throw new ValidationError("bad_schema", label + " must be an object");
  if (typeof side.name !== "string") throw new ValidationError("bad_schema", label + ".name required");
  if (side.name.length > MAX_SIDE_NAME) throw new ValidationError("bad_schema", label + ".name too long");
  for (const k of ["hp", "soldiers", "tactic_point"]) {
    if (typeof side[k] !== "number") throw new ValidationError("bad_schema", label + "." + k + " must be a number");
  }
  if (!Array.isArray(side.buffs)) throw new ValidationError("bad_schema", label + ".buffs must be an array");
  for (const b of side.buffs as unknown[]) {
    if (!isObject(b) || typeof b.name !== "string" || typeof b.turns !== "number") {
      throw new ValidationError("bad_schema", label + ".buffs entries need name and turns");
    }
    if (b.name.length > MAX_BUFF_NAME) throw new ValidationError("bad_schema", label + ".buffs[].name too long");
  }
  if (!Array.isArray(side.units)) throw new ValidationError("bad_schema", label + ".units must be an array");
  if (side.units.length > MAX_UNITS) throw new ValidationError("bad_schema", label + ".units too many entries");
  for (const u of side.units as unknown[]) checkBattleUnitV2(u, label + ".units[]");
}

/** 上一拍计划：Godot 原样回喂，字段全都要校验，避免超长/畸形值进提示词。 */
function checkBattleLastPlan(lp: unknown): void {
  if (!isObject(lp)) throw new ValidationError("bad_schema", "last_plan must be an object");
  if (typeof lp.tick !== "number") throw new ValidationError("bad_schema", "last_plan.tick must be a number");
  if (lp.orders !== undefined) {
    if (!isObject(lp.orders)) throw new ValidationError("bad_schema", "last_plan.orders must be an object");
    for (const [unit, order] of Object.entries(lp.orders)) {
      if (!BATTLE_UNIT_TYPES.includes(unit)) {
        throw new ValidationError("bad_schema", "last_plan.orders has unknown unit: " + unit);
      }
      if (!BATTLE_ORDERS.includes(order as string)) {
        throw new ValidationError("bad_schema", "last_plan.orders[" + unit + "] invalid");
      }
    }
  }
  if (!Array.isArray(lp.orders_applied)) {
    throw new ValidationError("bad_schema", "last_plan.orders_applied must be an array");
  }
  for (const u of lp.orders_applied as unknown[]) {
    if (typeof u !== "string") throw new ValidationError("bad_schema", "last_plan.orders_applied entries must be strings");
  }
  if (!Array.isArray(lp.orders_rejected)) {
    throw new ValidationError("bad_schema", "last_plan.orders_rejected must be an array");
  }
  if (lp.orders_rejected.length > MAX_REJECTED_ORDERS) {
    throw new ValidationError("bad_schema", "last_plan.orders_rejected too many entries");
  }
  for (const r of lp.orders_rejected as unknown[]) {
    if (!isObject(r) || typeof r.unit !== "string" || typeof r.reason !== "string") {
      throw new ValidationError("bad_schema", "last_plan.orders_rejected entries need unit and reason");
    }
    if (r.unit.length > MAX_REJECT_TEXT || r.reason.length > MAX_REJECT_TEXT) {
      throw new ValidationError("bad_schema", "last_plan.orders_rejected text too long");
    }
  }
  if (lp.tactic !== null && (typeof lp.tactic !== "string" || lp.tactic.length > 40)) {
    throw new ValidationError("bad_schema", "last_plan.tactic must be null or a short string");
  }
  if (typeof lp.tactic_status !== "string" || !BATTLE_TACTIC_STATUS.includes(lp.tactic_status)) {
    throw new ValidationError("bad_schema", "last_plan.tactic_status invalid");
  }
  if (typeof lp.reason !== "string" || lp.reason.length > MAX_REJECT_TEXT) {
    throw new ValidationError("bad_schema", "last_plan.reason must be a short string");
  }
  if (typeof lp.age_ms !== "number") throw new ValidationError("bad_schema", "last_plan.age_ms must be a number");
}

export function validateBattleSnapshot(
  body: unknown,
): import("./types.ts").BattleSnapshotV2 {
  if (!isObject(body)) throw new ValidationError("bad_json", "body must be a JSON object");
  if (body.battle_version !== 2) throw new ValidationError("bad_schema", "battle_version must be 2");
  if (typeof body.battle_key !== "string" || body.battle_key.length === 0) {
    throw new ValidationError("bad_schema", "battle_key required");
  }
  if (body.battle_key.length > MAX_BATTLE_KEY) {
    throw new ValidationError("bad_schema", "battle_key too long");
  }
  if (typeof body.tick !== "number" || body.tick <= 0) {
    throw new ValidationError("bad_schema", "tick must be a positive number");
  }
  if (typeof body.elapsed_ms !== "number") throw new ValidationError("bad_schema", "elapsed_ms must be a number");
  if (typeof body.diffculities !== "number") throw new ValidationError("bad_schema", "diffculities must be a number");
  if (body.side !== "attacker" && body.side !== "defender") {
    throw new ValidationError("bad_schema", "side must be attacker|defender");
  }
  if (typeof body.controlled_actor_id !== "number") {
    throw new ValidationError("bad_schema", "controlled_actor_id required");
  }
  if (typeof body.enemy_actor_id !== "number") {
    throw new ValidationError("bad_schema", "enemy_actor_id required");
  }
  if (typeof body.turn !== "number") throw new ValidationError("bad_schema", "turn must be a number");
  if (!isObject(body.terrain) || typeof body.terrain.name !== "string" || typeof body.terrain.is_city !== "boolean") {
    throw new ValidationError("bad_schema", "terrain needs name and is_city");
  }
  checkBattleSideV2(body.controlled, "controlled");
  checkBattleSideV2(body.enemy, "enemy");
  if (!Array.isArray(body.legal_tactics)) {
    throw new ValidationError("bad_schema", "legal_tactics must be an array");
  }
  if (body.legal_tactics.length > MAX_LEGAL_TACTICS) {
    throw new ValidationError("bad_schema", "legal_tactics too many entries");
  }
  for (const t of body.legal_tactics as unknown[]) {
    if (!isObject(t) || typeof t.name !== "string" || typeof t.cost !== "number" ||
        typeof t.rate !== "number" || typeof t.summary !== "string") {
      throw new ValidationError("bad_schema", "legal_tactics entries need name/cost/rate/summary");
    }
    if (t.name.length > MAX_TACTIC_NAME) throw new ValidationError("bad_schema", "legal_tactics[].name too long");
    if (t.summary.length > MAX_TACTIC_SUMMARY) throw new ValidationError("bad_schema", "legal_tactics[].summary too long");
  }
  if (body.last_plan !== undefined && body.last_plan !== null) {
    checkBattleLastPlan(body.last_plan);
  }
  return body as never;
}
