// 白兵战工具注册表。
//
// 与战争场景的工具完全独立：场景是「两个武将带兵对垒」，操作是
//   - 给某个兵种下达前进/待机/后退（Q2：每兵种一个设置）
//   - 使用计策（Static_Manager.TACTICS：咒缚/挑衅/强弩/士气向上/火矢）
//   - 结束本回合决策
// 依据 `clBattleFight.gd`（兵种键/状态）与 `AI_Control.gd`（命令取值）。
import type { AgentTool } from "@earendil-works/pi-agent-core";
import type { BattleBudget, BattleUnitType } from "./types.ts";
import type { BattleSession } from "./battle-session.ts";

export interface BattleLive {
  turn: number;
  controlled: {
    name?: string; hp?: number; soldiers: number; tactic_point: number;
    units: Array<{ type: BattleUnitType; hp: number; order: string }>;
  };
  enemy: {
    name?: string; hp?: number; soldiers: number; tactic_point: number;
    units: Array<{ type: BattleUnitType; hp: number; order: string }>;
  };
  legal_tactics: Array<{ name: string; cost: number }>;
}

function text(value: unknown): string {
  return typeof value === "string" ? value : JSON.stringify(value);
}

function result(value: unknown, details: Record<string, unknown> = {}) {
  return { content: [{ type: "text" as const, text: text(value) }], details };
}

/** 每个战斗回合最多下多少条命令：Godot 一次只执行回传一条，无限下会让回合永远不结束。 */
const MAX_COMMANDS_PER_TURN = 12;

const ORDERS = ["前进", "待机", "后退"] as const;

/** 回合级的命令计数：每个战斗回合重置（引擎推进到下一回合时）。 */
export interface BattleToolState {
  ended?: { reason: string };
  commands: number;
}

export function buildBattleTools(
  live: BattleLive,
  session: BattleSession,
  budget: BattleBudget,
): { tools: AgentTool<any>[]; state: BattleToolState } {
  const state: BattleToolState = { commands: 0 };

  const inspect_battlefield: AgentTool<any> = {
    name: "inspect_battlefield",
    label: "查看战场",
    description: "查看当前白兵战的完整态势：双方武将、兵力、战术值、各兵种血量与当前命令、可用计策。",
    parameters: { type: "object", properties: {}, additionalProperties: false },
    execute: async () => result({
      turn: live.turn,
      controlled: live.controlled,
      enemy: live.enemy,
      legal_tactics: live.legal_tactics,
    }),
  };

  // Q2：每个兵种一个设置工具（一次改一个兵种的命令）
  const set_order: AgentTool<any> = {
    name: "set_order",
    label: "设置兵种命令",
    description: "给一个兵种下达命令并立即生效。前进=进攻，待机=原地防守，后退=撤退。可对多个兵种分别调用。",
    parameters: {
      type: "object",
      properties: {
        unit: { type: "string", enum: ["将", "骑", "象", "弓", "步"], description: "兵种" },
        order: { type: "string", enum: [...ORDERS], description: "命令" },
        reasoning: { type: "string", description: "下达该命令的理由" },
      },
      required: ["unit", "order", "reasoning"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const unit = params.unit as BattleUnitType;
      const exists = live.controlled.units.some((u) => u.type === unit && u.hp > 0);
      if (!exists) throw new Error(`我方没有「${unit}」这个兵种（或已全灭）`);
      const reasoning = typeof params.reasoning === "string" ? params.reasoning : "";
      const out = await session.setOrder(unit, params.order, reasoning);
      applyState(out);
      countCommand();
      return result({
        ok: out.ok, outcome: out.outcome, turn: out.turn,
        controlled: out.controlled, enemy: out.enemy,
        hint: commandHint(),
      }, { ok: out.ok });
    },
  };

  const use_tactic: AgentTool<any> = {
    name: "use_tactic",
    label: "使用计策",
    description: "使用一个计策并立即结算。计策及消耗见 inspect_battlefield 的 legal_tactics。",
    parameters: {
      type: "object",
      properties: {
        tactic: { type: "string", description: "计策名（必须是 legal_tactics 之一）" },
        reasoning: { type: "string", description: "使用的理由" },
      },
      required: ["tactic", "reasoning"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const tactic = String(params.tactic);
      const legal = live.legal_tactics.find((t) => t.name === tactic);
      if (!legal) throw new Error(`「${tactic}」不在可用计策中`);
      if (legal.cost > live.controlled.tactic_point) {
        throw new Error(`战术值不足：需要 ${legal.cost}，当前 ${live.controlled.tactic_point}`);
      }
      const reasoning = typeof params.reasoning === "string" ? params.reasoning : "";
      const out = await session.useTactic(tactic, reasoning);
      applyState(out);
      countCommand();
      return result({
        ok: out.ok, outcome: out.outcome, turn: out.turn,
        controlled: out.controlled, enemy: out.enemy, legal_tactics: out.legal_tactics,
        hint: commandHint(),
      }, { ok: out.ok });
    },
  };

  // 唯一终止工具：结束本回合让引擎结算出兵推进
  const end_turn: AgentTool<any> = {
    name: "end_turn",
    label: "结束本回合",
    description: "结束本白兵战回合的决策，交还引擎按你下达的命令结算推进。下一回合会再问你。",
    parameters: {
      type: "object",
      properties: { reasoning: { type: "string" } },
      required: ["reasoning"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const reasoning = typeof params.reasoning === "string" ? params.reasoning : "本回合决策完成";
      state.ended = { reason: reasoning };
      state.commands = 0;
      session.markTurnEnded();
      // 不等待 Godot：end_turn 是把控制权交还引擎，不需要再看到执行结果。
      // 用 fire-and-forget 登记指令，返回值立即给出并 terminate。
      void session.endTurn(reasoning).catch(() => {});
      return { ...result({ ended: true, outcome: "本回合决策完成，交还引擎结算" }), terminate: true };
    },
  };

  /**
   * 记录一条命令；到达上限就替模型收起本回合。
   * 不设上限时模型会「忘了 end_turn」一路下命令，而 Godot 一次只回传一条，
   * 回合永远到不了收敛点，整场白兵战卡死。
   */
  function countCommand(): void {
    state.commands += 1;
    if (state.commands < MAX_COMMANDS_PER_TURN) return;
    state.ended = { reason: "本回合命令数已达上限" };
    session.markTurnEnded();
    void session.endTurn("本回合命令数已达上限，收尾结算").catch(() => { /* 引擎已离开本回合时忽略 */ });
  }

  function commandHint(): string {
    if (state.ended) return "本回合命令数已达上限，将直接交还引擎结算。";
    return `可继续给其它兵种下命令、用计（本回合已下 ${state.commands} 条），或调用 end_turn 结束本回合决策。`;
  }

  function applyState(out: { turn: number; controlled: BattleLive["controlled"]; enemy: BattleLive["enemy"]; legal_tactics: BattleLive["legal_tactics"] }) {
    live.turn = out.turn;
    live.controlled = out.controlled;
    live.enemy = out.enemy;
    live.legal_tactics = out.legal_tactics;
  }

  return { tools: [inspect_battlefield, set_order, use_tactic, end_turn], state };
}

export const BATTLE_TOOL_NAMES = ["inspect_battlefield", "set_order", "use_tactic", "end_turn"] as const;