import type {
  BattleOrder, BattlePlan, BattleSnapshotV2, BattleUnitType, BattleValidationRejected,
} from "./types.ts";

// Task 4 的 validate.ts 应 import 这里，不要再定义一份
export const BATTLE_UNIT_TYPES: BattleUnitType[] = ["将", "骑", "象", "弓", "步"];
// Task 4 的 validate.ts 应 import 这里，不要再定义一份
export const BATTLE_ORDERS: BattleOrder[] = ["前进", "待机", "后退"];

export function emptyPlan(): BattlePlan {
  return { orders: {}, tactic: null, memory: "", reasoning: "" };
}

/** 取 s 中第一个花括号平衡的对象字面量文本（字符串内的括号不计）；没有或不平衡返回 null。 */
function balancedObjectText(s: string): string | null {
  const start = s.indexOf("{");
  if (start < 0) return null;
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
      if (depth === 0) return s.slice(start, i + 1);
    }
  }
  return null;
}

/** 平衡对象文本能 JSON.parse 就返回解析结果，否则返回 undefined（JSON.parse 不会产出 undefined）。 */
function tryParseObject(s: string): unknown {
  const text = balancedObjectText(s);
  if (text === null) return undefined;
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

/**
 * 从模型输出里取第一个可解析的 JSON 对象：逐个尝试全部代码围栏（可能先给非 JSON 围栏），
 * 都不成再退回整段文本的平衡花括号扫描；支持前后散文与字符串里的花括号。
 */
export function extractJson(text: string): unknown {
  const s = String(text ?? "").trim();
  for (const m of s.matchAll(/```[a-zA-Z]*\s*([\s\S]*?)```/g)) {
    const parsed = tryParseObject(m[1]);
    if (parsed !== undefined) return parsed;
  }
  const whole = tryParseObject(s);
  if (whole !== undefined) return whole;
  if (s.indexOf("{") < 0) throw new Error("no JSON object");
  throw new Error("unbalanced JSON object");
}

/** 按 Unicode 码点截断，避免把 emoji 的代理对切成半个。 */
function truncate(s: string, n: number): string {
  return Array.from(s).slice(0, n).join("");
}

/**
 * 校验模型给出的计划：非法条目丢弃并计入 rejected，合法条目保留，本函数不抛异常。
 */
export function validateBattlePlan(
  raw: unknown, snapshot: BattleSnapshotV2,
): { plan: BattlePlan; rejected: BattleValidationRejected[] } {
  const rejected: BattleValidationRejected[] = [];
  const plan = emptyPlan();
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    rejected.push({ kind: "plan", value: "", reason: "计划不是 JSON 对象" });
    return { plan, rejected };
  }
  const o = raw as Record<string, unknown>;
  const alive = new Set(snapshot.controlled.units.filter((u) => u.hp > 0).map((u) => u.type));

  if (o.orders !== undefined) {
    if (typeof o.orders !== "object" || o.orders === null || Array.isArray(o.orders)) {
      rejected.push({ kind: "plan", value: String(o.orders), reason: "orders 不是对象" });
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

  if (o.tactic !== undefined && o.tactic !== null && typeof o.tactic !== "string") {
    rejected.push({ kind: "tactic", value: String(o.tactic), reason: "计策不是字符串" });
  } else if (typeof o.tactic === "string" && o.tactic.trim() !== "") {
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

  if (typeof o.memory === "string") plan.memory = truncate(o.memory, 120);
  if (typeof o.reasoning === "string") plan.reasoning = truncate(o.reasoning, 200);
  return { plan, rejected };
}
