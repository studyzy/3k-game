// 服务内工具注册表（服务端驱动的逐步交互）。
//
// 只读工具：读取「当前最新状态」——会话期间每次 Godot 回传结果都会替换这份状态，
// 因此 LLM 在回合内看到的 units / legal_actions 始终是最新的。
// 动作工具：不终止 loop，调用 session.emitAction 把动作交给 Godot 执行，
//           await 结果后用最新状态刷新本地视图，loop 继续让 LLM 决策下一个动作。
// end：唯一终止工具，结束本回合。
import type { AgentTool } from "@earendil-works/pi-agent-core";
import type { Budget, LegalAction, ToolName } from "./types.ts";
import type { TurnSession } from "./session.ts";
import { validateAction } from "./validate.ts";

export interface LiveState {
  units: Array<Record<string, unknown>>;
  terrain: Array<Record<string, unknown>>;
  economy: Record<string, unknown>;
  legal_actions: LegalAction[];
}

export interface ToolState {
  ended?: { reason: string };
  /** 本回合已成功执行的动作数。 */
  executed: number;
}

function text(value: unknown): string {
  return typeof value === "string" ? value : JSON.stringify(value);
}

function result(value: unknown, details: Record<string, unknown> = {}) {
  return { content: [{ type: "text" as const, text: text(value) }], details };
}

/** 从 legal_actions 中按自然参数定位动作。 */
function findAction(
  legal: LegalAction[], tool: ToolName, params: Record<string, unknown>,
): LegalAction | undefined {
  return legal.find((a) => {
    if (a.tool !== tool || a.actor !== params.actor) return false;
    if (tool === "move") {
      if (!Array.isArray(params.pos) || !Array.isArray(a.pos)) return false;
      const p = params.pos as number[];
      return a.pos[0] === p[0] && a.pos[1] === p[1];
    }
    if (tool === "attack" || tool === "stratagem") {
      if (a.target !== params.target) return false;
      if (tool === "stratagem" && params.skill !== undefined && a.skill !== params.skill) return false;
      return true;
    }
    // retreat / end 只看 actor
    return true;
  });
}

export function buildTools(
  live: LiveState,
  session: TurnSession,
  budget: Budget,
): { tools: AgentTool<any>[]; state: ToolState } {
  const state: ToolState = { executed: 0 };

  // ---------------- 只读工具：读 live（每步刷新） ----------------
  const list_legal_actions: AgentTool<any> = {
    name: "list_legal_actions",
    label: "列出合法动作",
    description: "列出当前可执行的合法动作候选（含消耗）。每执行一个动作后都会刷新。可按 actor 或 tool 过滤。",
    parameters: {
      type: "object",
      properties: {
        actor: { type: "number", description: "只列出该武将的动作" },
        tool: { type: "string", enum: ["move", "attack", "stratagem", "retreat", "end"] },
      },
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const rows = live.legal_actions.filter(
        (a) => (params.actor === undefined || a.actor === params.actor) &&
               (params.tool === undefined || a.tool === params.tool),
      );
      return result(rows, { count: rows.length });
    },
  };

  const inspect_unit: AgentTool<any> = {
    name: "inspect_unit",
    label: "查看单位",
    description: "按 id 查看一个单位的最新属性（只读）。",
    parameters: {
      type: "object",
      properties: { id: { type: "number" } },
      required: ["id"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const unit = live.units.find((u) => u.id === params.id);
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
      const rows = live.terrain.filter((t) => Array.isArray(t.pos) && t.pos[0] === x && t.pos[1] === y);
      return result(rows, { count: rows.length });
    },
  };

  const inspect_economy: AgentTool<any> = {
    name: "inspect_economy",
    label: "查看经济与回合",
    description: "查看粮草、金钱、当前日、上限、城门与太守府坐标（只读）。",
    parameters: { type: "object", properties: {}, additionalProperties: false },
    execute: async () => result(live.economy),
  };

  // ---------------- 动作工具：交给 Godot 执行，await 结果 ----------------
  /**
   * 执行一个动作：
   *  1. 在最新 legal_actions 中定位
   *  2. 交给 Godot（长轮询取走）
   *  3. 等结果回来后刷新 live，把最新 units / legal_actions 摘要回给 LLM
   * 注意：不设置 terminate，loop 继续，让 LLM 决定下一个动作。
   */
  async function runAction(tool: Exclude<ToolName, "end">, params: Record<string, unknown>) {
    const target = findAction(live.legal_actions, tool, params);
    if (!target) {
      throw new Error(`没有匹配该参数的合法 ${tool} 动作（请先 list_legal_actions 确认）`);
    }
    const action = validateAction(target.id, {
      controlled_vstate_id: session.req.controlled_vstate_id,
      units: live.units,
      legal_actions: live.legal_actions,
    } as never, budget);

    const reasoning = typeof params.reasoning === "string" ? params.reasoning : "";
    state.executed++;

    const outcome = await session.emitAction({
      tool, actor: action.actor, id: action.id, action, reasoning,
    });

    // 刷新本地视图：Godot 已算好执行后的 units / legal_actions
    live.units = outcome.units;
    live.legal_actions = outcome.legal_actions;
    if (outcome.terrain) live.terrain = outcome.terrain;
    if (outcome.economy) live.economy = outcome.economy;

    const summary = {
      ok: outcome.ok,
      outcome: outcome.outcome,
      units: outcome.units,
      legal_actions: outcome.legal_actions,
      hint: "继续决定下一个动作；全部武将与机动力都无事可做时调用 end。",
    };
    return result(summary, { action, ok: outcome.ok });
  }

  const ACT_PROPS = { reasoning: { type: "string", description: "本动作的决策理由" } };

  const move: AgentTool<any> = {
    name: "move",
    label: "移动",
    description: "让一个武将移动到指定坐标并立即执行，返回执行后的战场状态。执行后可以继续调用其它动作。",
    parameters: {
      type: "object",
      properties: {
        actor: { type: "number" },
        pos: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2 },
        ...ACT_PROPS,
      },
      required: ["actor", "pos", "reasoning"],
      additionalProperties: false,
    },
    execute: async (_id, params) => runAction("move", params),
  };

  const attack: AgentTool<any> = {
    name: "attack",
    label: "攻击",
    description: "让一个武将攻击一个敌方武将并立即结算（胜负不确定）。返回结算后的战场状态，可以继续调用其它动作。",
    parameters: {
      type: "object",
      properties: { actor: { type: "number" }, target: { type: "number" }, ...ACT_PROPS },
      required: ["actor", "target", "reasoning"],
      additionalProperties: false,
    },
    execute: async (_id, params) => runAction("attack", params),
  };

  const stratagem: AgentTool<any> = {
    name: "stratagem",
    label: "用计",
    description: "让一个武将对目标发动计策并立即结算。返回结算后的战场状态，可以继续调用其它动作。",
    parameters: {
      type: "object",
      properties: {
        actor: { type: "number" }, target: { type: "number" },
        skill: { type: "string", description: "计策名，必须是 legal_actions 里出现过的 skill" },
        ...ACT_PROPS,
      },
      required: ["actor", "target", "skill", "reasoning"],
      additionalProperties: false,
    },
    execute: async (_id, params) => runAction("stratagem", params),
  };

  const retreat: AgentTool<any> = {
    name: "retreat",
    label: "撤退",
    description: "让一个武将撤退到城中并立即执行。返回执行后的战场状态，可以继续调用其它动作。",
    parameters: {
      type: "object",
      properties: { actor: { type: "number" }, ...ACT_PROPS },
      required: ["actor", "reasoning"],
      additionalProperties: false,
    },
    execute: async (_id, params) => runAction("retreat", params),
  };

  // ---------------- 唯一终止工具 ----------------
  const end: AgentTool<any> = {
    name: "end",
    label: "结束本方回合",
    description: [
      "结束本方整个 AI 回合，本回合不再行动。",
      "只在「所有武将都没事可做」或「所有武将机动力/点数都耗尽」时调用。",
      "注意：这不是让某个武将停止行动——游戏里没有单武将结束行动的机制，",
      "某个武将动不了不影响其他武将继续行动。",
    ].join(""),
    parameters: {
      type: "object",
      properties: { reason: { type: "string", description: "为什么结束本回合" } },
      required: ["reason"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const reason = typeof params.reason === "string" ? params.reason : "agent 判定无可行动";
      state.ended = { reason };
      return { ...result({ ended: true, reason }), terminate: true };
    },
  };

  return {
    tools: [list_legal_actions, inspect_unit, inspect_terrain, inspect_economy, move, attack, stratagem, retreat, end],
    state,
  };
}

export const TOOL_NAMES = [
  "list_legal_actions", "inspect_unit", "inspect_terrain", "inspect_economy",
  "move", "attack", "stratagem", "retreat", "end",
] as const;

/** 会交给 Godot 执行的工具（不含 end）。 */
export const ACT_TOOL_NAMES = ["move", "attack", "stratagem", "retreat"] as const;