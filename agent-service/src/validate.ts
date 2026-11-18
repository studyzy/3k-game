// 请求与 plan 校验。与设计文档 §3.6 的 Godot 侧 ActionValidator 同规则。
// 服务侧预校验 + Godot 侧二次校验 = 双防线；任一侧拒绝都回退 hard 规则 AI。
import type { Budget, DecideRequest, LegalAction, PlanItem, ToolName } from "./types.ts";

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

export function validateRequest(body: unknown): DecideRequest {
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

  const seen = new Set<string>();
  for (const raw of body.legal_actions as unknown[]) {
    if (!isObject(raw)) throw new ValidationError("bad_schema", "legal_actions entries must be objects");
    if (typeof raw.id !== "string" || raw.id.length === 0) throw new ValidationError("bad_schema", "legal action id required");
    if (seen.has(raw.id)) throw new ValidationError("bad_schema", `duplicate legal action id: ${raw.id}`);
    seen.add(raw.id);
    if (!TOOLS.includes(raw.tool as ToolName)) throw new ValidationError("bad_schema", `unknown tool: ${String(raw.tool)}`);
    if (typeof raw.actor !== "number") throw new ValidationError("bad_schema", "legal action actor required");
  }

  return body as unknown as DecideRequest;
}

/** 校验 agent 提交的 plan；返回按 order 归一化的副本。任一非法即整批拒绝。 */
export function validatePlan(plan: unknown, req: DecideRequest, budget: Budget): PlanItem[] {
  if (!Array.isArray(plan)) throw new ValidationError("invalid_plan", "plan must be an array");
  if (plan.length === 0) throw new ValidationError("invalid_plan", "plan must not be empty");
  if (plan.length > budget.max_actions) throw new ValidationError("invalid_plan", "plan exceeds max_actions");

  const byId = new Map<string, LegalAction>(req.legal_actions.map((a) => [a.id, a]));
  const unitById = new Map<number, Record<string, unknown>>();
  for (const u of req.units) {
    if (typeof u.id === "number") unitById.set(u.id, u);
  }

  const usedIds = new Set<string>();
  const spent = new Map<number, { ap: number; poker: number }>();
  const out: PlanItem[] = [];

  for (let i = 0; i < plan.length; i++) {
    const raw = plan[i];
    if (!isObject(raw) || typeof raw.id !== "string") {
      throw new ValidationError("invalid_plan", `plan[${i}] must have a string id`);
    }
    const action = byId.get(raw.id);
    if (!action) throw new ValidationError("invalid_plan", `unknown action id: ${raw.id}`);
    if (usedIds.has(raw.id)) throw new ValidationError("invalid_plan", `duplicate action id: ${raw.id}`);
    usedIds.add(raw.id);

    const unit = unitById.get(action.actor);
    if (!unit) throw new ValidationError("invalid_plan", `actor ${action.actor} not in units`);
    if (unit.vstate !== req.controlled_vstate_id) {
      throw new ValidationError("invalid_plan", `actor ${action.actor} is not controlled by vstate ${req.controlled_vstate_id}`);
    }
    if (unit.disabled === true) throw new ValidationError("invalid_plan", `actor ${action.actor} is disabled`);

    const cost = action.cost ?? {};
    const prev = spent.get(action.actor) ?? { ap: 0, poker: 0 };
    const ap = prev.ap + (cost.ap ?? 0);
    const poker = prev.poker + (cost.poker ?? 0);
    if (typeof unit.ap === "number" && ap > unit.ap) {
      throw new ValidationError("invalid_plan", `actor ${action.actor} exceeds action_point`);
    }
    if (typeof unit.poker === "number" && poker > unit.poker) {
      throw new ValidationError("invalid_plan", `actor ${action.actor} exceeds poker_point`);
    }
    spent.set(action.actor, { ap, poker });

    out.push({ id: action.id, order: typeof raw.order === "number" ? raw.order : i + 1 });
  }

  return out;
}
