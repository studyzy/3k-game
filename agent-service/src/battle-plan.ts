import type {
  BattleOrder, BattlePlan, BattleSnapshotV2, BattleUnitType, BattleValidationRejected,
} from "./types.ts";

export const BATTLE_UNIT_TYPES: BattleUnitType[] = ["将", "骑", "象", "弓", "步"];
export const BATTLE_ORDERS: BattleOrder[] = ["前进", "待机", "后退"];

export function emptyPlan(): BattlePlan {
  return { orders: {}, tactic: null, memory: "", reasoning: "" };
}

/** 从模型输出里取第一个平衡的 JSON 对象；支持代码围栏与前后散文。 */
export function extractJson(text: string): unknown {
  let s = String(text ?? "").trim();
  const fence = /```(?:json)?\s*([\s\S]*?)```/i.exec(s);
  if (fence) s = fence[1].trim();
  const start = s.indexOf("{");
  if (start < 0) throw new Error("no JSON object");
  let depth = 0;
  let inStr = false;
  let esc = false;
  for (let i = start; i < s.length; i++) {
    const ch = s[i];
    if (inStr) {
      if (esc) esc = false;
      else if (ch === "\\") esc = true;
      else if (ch === '"') inStr = false;
      continue;
    }
    if (ch === '"') { inStr = true; continue; }
    if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) return JSON.parse(s.slice(start, i + 1));
    }
  }
  throw new Error("unbalanced JSON object");
}

export function validateBattlePlan(
  raw: unknown, snapshot: BattleSnapshotV2,
): { plan: BattlePlan; rejected: BattleValidationRejected[] } {
  const rejected: BattleValidationRejected[] = [];
  const plan = emptyPlan();
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    rejected.push({ kind: "order", value: "", reason: "计划不是 JSON 对象" });
    return { plan, rejected };
  }
  const o = raw as Record<string, unknown>;
  const alive = new Set(snapshot.controlled.units.filter((u) => u.hp > 0).map((u) => u.type));

  if (o.orders !== undefined) {
    if (typeof o.orders !== "object" || o.orders === null || Array.isArray(o.orders)) {
      rejected.push({ kind: "order", value: String(o.orders), reason: "orders 不是对象" });
    } else {
      for (const [unit, order] of Object.entries(o.orders as Record<string, unknown>)) {
        if (!BATTLE_UNIT_TYPES.includes(unit as BattleUnitType)) {
          rejected.push({ kind: "order", value: unit, reason: "未知兵种" });
          continue;
        }
        if (!alive.has(unit as BattleUnitType)) {
          rejected.push({ kind: "order", value: unit, reason: "该兵种已灭" });
          continue;
        }
        if (typeof order !== "string" || !BATTLE_ORDERS.includes(order as BattleOrder)) {
          rejected.push({ kind: "order", value: unit + ":" + String(order), reason: "未知命令" });
          continue;
        }
        plan.orders[unit as BattleUnitType] = order as BattleOrder;
      }
    }
  }

  if (typeof o.tactic === "string" && o.tactic.trim() !== "") {
    const tactic = o.tactic.trim();
    const legal = snapshot.legal_tactics.find((t) => t.name === tactic);
    if (!legal) {
      rejected.push({ kind: "tactic", value: tactic, reason: "不在可用计策中" });
    } else if (legal.cost > snapshot.controlled.tactic_point) {
      rejected.push({ kind: "tactic", value: tactic, reason: "战术值不足" });
    } else {
      plan.tactic = tactic;
    }
  }

  if (typeof o.memory === "string") plan.memory = o.memory.slice(0, 120);
  if (typeof o.reasoning === "string") plan.reasoning = o.reasoning.slice(0, 200);
  return { plan, rejected };
}
