// 服务内只读工具注册表（设计文档 §4.3）。
// 全部工具只读取本次请求带来的不可变状态快照，纯内存计算；
// 不访问文件系统 / 进程 / 网络 / Godot / 存档，不返回 RNG 或伤害判定。
import type { AgentTool } from "@earendil-works/pi-agent-core";
import type { Budget, DecideRequest, LegalAction, PlanItem } from "./types.ts";
import { validatePlan } from "./validate.ts";

export interface ToolState {
  submitted?: { plan: PlanItem[]; intent: string; counterplay?: string };
}

function text(value: unknown): string {
  return typeof value === "string" ? value : JSON.stringify(value);
}

function result(value: unknown, details: Record<string, unknown> = {}) {
  return { content: [{ type: "text" as const, text: text(value) }], details };
}

export function buildTools(req: DecideRequest, budget: Budget): {
  tools: AgentTool<any>[];
  state: ToolState;
} {
  const state: ToolState = {};
  const legal: LegalAction[] = req.legal_actions;

  const list_legal_actions: AgentTool<any> = {
    name: "list_legal_actions",
    label: "列出合法动作",
    description: "列出本次回合可执行的合法动作候选（含消耗）。可按 actor 或 tool 过滤。",
    parameters: {
      type: "object",
      properties: {
        actor: { type: "number", description: "只列出该武将的动作" },
        tool: { type: "string", enum: ["move", "attack", "stratagem", "retreat", "end"] },
      },
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const rows = legal.filter(
        (a) => (params.actor === undefined || a.actor === params.actor) &&
               (params.tool === undefined || a.tool === params.tool),
      );
      return result(rows, { count: rows.length });
    },
  };

  const inspect_unit: AgentTool<any> = {
    name: "inspect_unit",
    label: "查看单位",
    description: "按 id 查看一个单位的全量属性（只读）。",
    parameters: {
      type: "object",
      properties: { id: { type: "number" } },
      required: ["id"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const unit = req.units.find((u) => u.id === params.id);
      if (!unit) throw new Error(`unit ${params.id} not found`);
      return result(unit);
    },
  };

  const inspect_terrain: AgentTool<any> = {
    name: "inspect_terrain",
    label: "查看地形",
    description: "按坐标查看地形类型与移动消耗（只读）。",
    parameters: {
      type: "object",
      properties: {
        pos: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2 },
      },
      required: ["pos"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const [x, y] = params.pos as number[];
      const rows = req.terrain.filter((t) => Array.isArray(t.pos) && t.pos[0] === x && t.pos[1] === y);
      return result(rows, { count: rows.length });
    },
  };

  const inspect_economy: AgentTool<any> = {
    name: "inspect_economy",
    label: "查看经济与回合",
    description: "查看粮草、金钱、当前日、上限、城门与太守府坐标（只读）。",
    parameters: { type: "object", properties: {}, additionalProperties: false },
    execute: async () => result(req.economy),
  };

  const estimate_plan: AgentTool<any> = {
    name: "estimate_plan",
    label: "估算计划消耗",
    description: "按给定 id 顺序累加机动力/点数消耗，标出超预算项。纯计算，不调 LLM、不判 RNG、不执行动作。",
    parameters: {
      type: "object",
      properties: {
        ids: { type: "array", items: { type: "string", enum: legal.map((a) => a.id) } },
      },
      required: ["ids"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const byId = new Map(legal.map((a) => [a.id, a]));
      const spent = new Map<number, { ap: number; poker: number }>();
      const over: string[] = [];
      for (const id of params.ids as string[]) {
        const a = byId.get(id);
        if (!a) throw new Error(`unknown action id: ${id}`);
        const cur = spent.get(a.actor) ?? { ap: 0, poker: 0 };
        cur.ap += a.cost?.ap ?? 0;
        cur.poker += a.cost?.poker ?? 0;
        spent.set(a.actor, cur);
        const unit = req.units.find((u) => u.id === a.actor);
        if (unit && ((typeof unit.ap === "number" && cur.ap > unit.ap) ||
                     (typeof unit.poker === "number" && cur.poker > unit.poker))) {
          over.push(id);
        }
      }
      return result({ spent: Object.fromEntries(spent), over_budget: over }, { over_budget: over });
    },
  };

  // 终止工具：其 JSON Schema 本身就是结构化输出约束，plan[].id 用本次 legal_actions 枚举限定。
  const submit_plan: AgentTool<any> = {
    name: "submit_plan",
    label: "提交最终计划",
    description: "提交本回合整侧联合计划并结束推理。必须从 legal_actions 中选 id 并排序，不得发明动作或参数。",
    parameters: {
      type: "object",
      properties: {
        plan: {
          type: "array",
          maxItems: budget.max_actions,
          items: {
            type: "object",
            properties: {
              id: { type: "string", enum: legal.map((a) => a.id) },
              order: { type: "integer", minimum: 1 },
            },
            required: ["id"],
            additionalProperties: false,
          },
        },
        intent: { type: "string" },
        counterplay: { type: "string" },
      },
      required: ["plan", "intent"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const plan = validatePlan(params.plan, req, budget);
      state.submitted = {
        plan,
        intent: typeof params.intent === "string" ? params.intent : "",
        counterplay: typeof params.counterplay === "string" ? params.counterplay : undefined,
      };
      return { ...result({ accepted: plan.length, ids: plan.map((p) => p.id) }, { plan }), terminate: true };
    },
  };

  return {
    tools: [list_legal_actions, inspect_unit, inspect_terrain, inspect_economy, estimate_plan, submit_plan],
    state,
  };
}

export const READ_ONLY_TOOL_NAMES = [
  "list_legal_actions", "inspect_unit", "inspect_terrain", "inspect_economy", "estimate_plan", "submit_plan",
] as const;
