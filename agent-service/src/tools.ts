// 服务内工具注册表（服务端驱动的逐步交互）。
//
// 只读工具：读取「当前最新状态」——会话期间每次 Godot 回传结果都会替换这份状态，
// 因此 LLM 在回合内看到的 units / legal_actions 始终是最新的。
// 动作工具：不终止 loop，调用 session.emitAction 把动作交给 Godot 执行，
//           await 结果后用最新状态刷新本地视图，loop 继续让 LLM 决策下一个动作。
// end：唯一终止工具，结束本回合。
import type { AgentTool } from "@earendil-works/pi-agent-core";
import type { Budget, LegalAction, SettlementOutcome, TerrainCell, ToolName } from "./types.ts";
import type { TurnSession } from "./session.ts";
import { validateAction } from "./validate.ts";

export interface LiveState {
  units: Array<Record<string, unknown>>;
  terrain: TerrainCell[];
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

/** 候选清单最多列这么多个目标，避免长清单把上下文吃掉。 */
const MAX_CANDIDATES = 8;

/** 动作结果里回传的单位字段：只保留会变的那几项。 */
const DIFF_UNIT_FIELDS = ["id", "name", "vstate", "main", "pos", "ap", "soldiers", "hp", "status", "disabled"] as const;

/**
 * 动作结果只回变化的单位。
 * 全量回传等于每步重发一遍全部武将档案（装备/技能/attrs/exp 都是静态的），实测单步 5.7KB。
 * 这里按字段比较，只给变了的单位的可变字段；没变化的单位一个字都不回。
 */
function diffUnits(before: Array<Record<string, unknown>>, after: Array<Record<string, unknown>>) {
  const prev = new Map(before.map((u) => [u.id, u]));
  const changed: Array<Record<string, unknown>> = [];
  for (const u of after) {
    const old = prev.get(u.id);
    const fields: Record<string, unknown> = {};
    let dirty = old === undefined;
    for (const key of DIFF_UNIT_FIELDS) {
      const now = u[key];
      const was = old?.[key];
      if (JSON.stringify(now) !== JSON.stringify(was)) {
        fields[key] = now;
        dirty = true;
      }
    }
    // 兵力归零/阵亡这类消失的单位也要告诉模型（after 里已不含它）
    if (dirty) changed.push(fields);
  }
  const aliveIds = new Set(after.map((u) => u.id));
  const gone = before.filter((u) => !aliveIds.has(u.id)).map((u) => u.id);
  return gone.length > 0 ? { changed, gone } : changed;
}

/**
 * 用计结果压成紧凑 JSON（键全英文，值用中文，模型读得懂且省 token）：
 *   失败：{ success: false }
 *   命中：{ success: true, result: [{ name: "吕布", effect: "士兵-77", currentStatus: "士兵539、体力99" }] }
 * 只列真正被改变的武将，不再逐个回传 units 数组。
 */
function compactStratagem(
  s: SettlementOutcome,
  latest: Array<Record<string, unknown>>,
  loser = "",
): Record<string, unknown> {
  if (!s.ok) return { success: false };
  const result = s.effects.map((e) => {
    // 兵力/体力取回传时刻的最新值：计策扣兵可能延后落地，Godot 结算瞬间读到的是旧值
    const fresh = latest.find((u) => u.id === e.id);
    const soldiers = typeof fresh?.soldiers === "number" ? fresh.soldiers : e.soldiers;
    const hp = typeof fresh?.hp === "number" ? fresh.hp : e.hp;
    const status = Array.isArray(fresh?.status) ? (fresh.status as string[]) : e.status;
    const cur = [`士兵${soldiers}`, `体力${hp}`];
    if (status.length > 0) cur.push(`状态${status.join("/")}`);
    return { name: e.name, effect: e.note, currentStatus: cur.join("、") };
  });
  const out: Record<string, unknown> = { success: true };
  if (result.length > 0) out.result = result;
  if (loser !== "") out.loser = loser;
  return out;
}

/** 经济只回有变化的键（敌方粮草会随用计变化）。 */
function changedEconomy(before: Record<string, unknown>, after: Record<string, unknown> | undefined) {
  if (!after) return undefined;
  const fields: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(after)) {
    if (JSON.stringify(v) !== JSON.stringify(before?.[k])) fields[k] = v;
  }
  return fields;
}

/**
 * 猜错动作时的反馈：按同 actor 列出它当前真正能做的事。
 * 模型看不到全量 legal_actions，靠这条消息在会话内自纠，不必回退 Godot。
 */
function candidateHint(
  legal: LegalAction[],
  units: Array<Record<string, unknown>>,
  controlled: number,
  tool: ToolName,
  params: Record<string, unknown>,
): string {
  const actor = params.actor;
  const unit = units.find((u) => u.id === actor);
  const who = `武将 ${String(actor)}`;
  if (!unit) return `没有 id 为 ${String(actor)} 的武将。`;
  if (unit.vstate !== controlled) return `${who} 不是你方武将。`;
  if (unit.disabled === true) return `${who} 已无法行动。`;

  const rows = legal.filter((a) => a.actor === actor && a.tool !== "end");
  if (rows.length === 0) return `${who} 现在没有任何合法动作（机动力/点数可能已耗尽）。`;

  const lines: string[] = [];
  const attacks = rows.filter((a) => a.tool === "attack").map((a) => a.target);
  if (attacks.length > 0) {
    lines.push(`  attack → ${attacks.slice(0, MAX_CANDIDATES).join(", ")}`);
  }
  const bySkill = new Map<string, number[]>();
  for (const a of rows) {
    if (a.tool !== "stratagem" || a.skill === undefined) continue;
    const targets = bySkill.get(a.skill) ?? [];
    if (a.target !== undefined) targets.push(a.target);
    bySkill.set(a.skill, targets);
  }
  for (const [skill, targets] of bySkill) {
    lines.push(`  stratagem ${skill} → ${targets.slice(0, MAX_CANDIDATES).join(", ")}`);
  }
  const retreat = rows.find((a) => a.tool === "retreat");
  if (retreat) lines.push(`  retreat → 城${String(retreat.city ?? "?")}`);
  if (rows.some((a) => a.tool === "move")) lines.push("  move（path 由你自己规划）");

  const what = tool === "stratagem" && params.skill !== undefined
    ? `「${String(params.skill)}」`
    : tool;
  const on = params.target !== undefined ? ` 对 ${String(params.target)}` : "";
  return `${who} 无法执行 ${what}${on}。当前可选：\n${lines.join("\n")}`;
}

/**
 * move 由 LLM 直接给路径，不经 legal_actions 候选。
 * 服务端只做结构检查（actor 存在、path 是 [x,y] 数组），
 * 可达性/占位/机动力由 Godot 逐格判断——走不动就停，结果回传。
 * 这里不发明坐标，也不替 LLM 规划。
 */
function buildMoveAction(params: Record<string, unknown>): LegalAction {
  const actor = params.actor;
  if (typeof actor !== "number") throw new Error("move 需要 actor（武将 id）");
  const path = params.path;
  if (!Array.isArray(path) || path.length === 0) {
    throw new Error("move 需要非空 path（[[x,y], ...]，不含起点，每步上下左右一格）");
  }
  for (const step of path) {
    if (!Array.isArray(step) || step.length !== 2 ||
        typeof step[0] !== "number" || typeof step[1] !== "number") {
      throw new Error("move.path 每项必须是 [x, y]");
    }
  }
  // id 只用于会话内追踪（Godot 不再按 id 查候选）
  return { id: `move-${actor}-${path.length}`, tool: "move", actor, path: path as Array<[number, number]> };
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
    description: "列出你方武将当前可执行的合法动作（只列我方，不含 end；每执行一个动作后刷新）。不确定谁能打谁/能用什么计时用它。",
    parameters: {
      type: "object",
      properties: {
        actor: { type: "number", description: "只列出该武将的动作" },
        tool: { type: "string", enum: ["move", "attack", "stratagem", "retreat"] },
      },
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const controlled = session.req.controlled_vstate_id;
      const mine = new Set(
        live.units.filter((u) => u.vstate === controlled).map((u) => u.id as number),
      );
      const rows = live.legal_actions
        .filter((a) => a.tool !== "end" && mine.has(a.actor))
        .filter(
          (a) => (params.actor === undefined || a.actor === params.actor) &&
                 (params.tool === undefined || a.tool === params.tool),
        )
        // id 是服务端内部句柄，模型用 actor/target/skill 表达动作即可。
        .map((a) => {
          const row: Record<string, unknown> = { tool: a.tool, actor: a.actor };
          if (a.target !== undefined) row.target = a.target;
          if (a.skill !== undefined) row.skill = a.skill;
          if (a.city !== undefined) row.city = a.city;
          if (a.cost !== undefined) row.cost = a.cost;
          return row;
        });
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

  const inspect_economy: AgentTool<any> = {
    name: "inspect_economy",
    label: "查看经济与回合",
    description: "兜底只读查询：粮草、金钱、当前日、天数上限、太守府坐标。开场消息与动作结果已含全部经济信息，通常不需要调用。",
    parameters: { type: "object", properties: {}, additionalProperties: false },
    execute: async () => result(live.economy),
  };

  // 只读：用计预估。由 Godot 用引擎现算，服务端只做搬运。
  // Godot 只回一段文字结论（命中率 + 中计后的结果），逐目标明细不进模型上下文。
  const estimate_stratagem: AgentTool<any> = {
    name: "estimate_stratagem",
    label: "预估用计",
    description: [
      "预估某个武将用某个计策打某个目标的命中率与命中后的结果（只读，不消耗机动力、不推进战局）。",
      "返回一句话：命中率、耗机动力，以及中计后各目标会损多少兵/伤多少体/扣多少米/附加什么状态；",
      "返回的损失量就是这一计实际会造成的损失（引擎已按同一组随机数算好，结算时不会再变）。",
      "想用计但拿不准划不划算时先调它；确定要用再调 stratagem。",
    ].join(""),
    parameters: {
      type: "object",
      properties: {
        actor: { type: "number", description: "施术武将 id" },
        target: { type: "number", description: "目标武将 id" },
        skill: { type: "string", description: "计策名，必须是 legal_actions 里出现过的 skill" },
      },
      required: ["actor", "target", "skill"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const data = await session.askEstimate(
        Number(params.actor), Number(params.target), String(params.skill),
      );
      const text = typeof data.summary === "string" ? data.summary : "";
      if (text === "") return result(data, { ok: data.ok === true });
      return result(text, { ok: data.ok === true });
    },
  };

  const estimate_move: AgentTool<any> = {
    name: "estimate_move",
    label: "预估算路",
    description: [
      "只读：估算某个武将走到目标格的最少格数、需要多少机动力、以及最短路径（不消耗机动力、不推进战局）。",
      "to 可以一次给多个目标点（如三个城门 + 太守府），一次拿到全部结论；有可达的会按机动力消耗从小到大排好。",
      "算不通就用它：判断哪个城门离敌人最近（主攻门）、我能不能走过去、要走几格花多少机。",
      "只给格数、机动力与「几天到」，不给逐格路线；move 的 path 要自己按相邻格规划（A* 的连边含斜向，照抄会走不动）。",
    ].join(""),
    parameters: {
      type: "object",
      properties: {
        actor: { type: "number", description: "武将 id" },
        to: {
          type: "array",
          description: "目标格列表 [[x,y], ...]",
          minItems: 1,
          items: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2 },
        },
      },
      required: ["actor", "to"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const to = (params.to as number[][]).map((p) => [Number(p[0]), Number(p[1])] as [number, number]);
      const data = await session.askMove(Number(params.actor), to);
      // Godot 侧把文字结论放在 summary；取不到就直接把原始回答给模型，别让它看到空结果
      const summary = typeof data.summary === "string" && data.summary !== "" ? data.summary : "";
      if (summary === "") {
        return result(`估算失败（引擎没有返回结论）：${text(data)}`, { ok: false, raw: data });
      }
      return result(summary, { ok: data.ok !== false, routes: data.routes });
    },
  };

  // 批量行军预估：守方判「敌人先打哪个门」要挨个看敌将，逐个调 estimate_move
  // 每次都占一个工具轮次（一趟长轮询）。这里一次把所有敌将和全部城门发给 Godot 合并算完。
  // free=true：忽略其他武将阻挡，只算「理论上几天能到」——远处的敌将现在被自己人挡着，
  // 不等于它后天到不了。查我方武将（要照着 path 走）仍用 estimate_move。
  const estimate_moves: AgentTool<any> = {
    name: "estimate_moves",
    label: "批量预估算路",
    description: [
      "只读：一次估算多个武将到同一组目标格的行程。每个武将只回「最便宜的那个目标」一行（几格、多少机、几天到），不回全部目标，也不给逐格路线。",
      "口径与 estimate_move 相同（我方可动 / 敌方按「下轮可动」），但忽略其他武将的阻挡——",
      "只回答「理论上几天能到」，用来判断敌方主攻门、谁最先威胁太守府，不必逐个调 estimate_move。",
    ].join(""),
    parameters: {
      type: "object",
      properties: {
        actors: {
          type: "array",
          description: "武将 id 列表（敌方武将都从开场消息里拿）",
          minItems: 1,
          items: { type: "number" },
        },
        to: {
          type: "array",
          description: "目标格列表 [[x,y], ...]",
          minItems: 1,
          items: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2 },
        },
      },
      required: ["actors", "to"],
      additionalProperties: false,
    },
    execute: async (_id, params) => {
      const actors = (params.actors as number[]).map((a) => Number(a));
      const to = (params.to as number[][]).map((p) => [Number(p[0]), Number(p[1])] as [number, number]);
      const answers = await session.askMoves(actors, to);
      const lines: string[] = [];
      for (const data of answers) {
        const summary = typeof data.summary === "string" ? data.summary : "";
        if (summary !== "") lines.push(summary);
      }
      if (lines.length === 0) return result("估算失败（引擎没有返回结论）", { ok: false, raw: answers });
      return result(lines.join("\n"), { ok: true });
    },
  };

  // ---------------- 动作工具：交给 Godot 执行，await 结果 ----------------
  /**
   * 执行一个动作：
   *  1. move 由 LLM 自己给路径，直接交给 Godot 逐格执行（Godot 走不动就停，
   *     并把实际到达的位置回传）；其余动作在最新 legal_actions 中定位。
   *  2. 交给 Godot（长轮询取走）
   *  3. 等结果回来后刷新 live，把最新 units / legal_actions 摘要回给 LLM
   * 注意：不设置 terminate，loop 继续，让 LLM 决定下一个动作。
   */
  async function runAction(tool: Exclude<ToolName, "end">, params: Record<string, unknown>) {
    let action: LegalAction;
    if (tool === "move") {
      action = buildMoveAction(params);
    } else {
      const target = findAction(live.legal_actions, tool, params);
      if (!target) {
        throw new Error(candidateHint(
          live.legal_actions, live.units, session.req.controlled_vstate_id, tool, params,
        ));
      }
      action = validateAction(target.id, {
        controlled_vstate_id: session.req.controlled_vstate_id,
        units: live.units,
        legal_actions: live.legal_actions,
      } as never, budget);
    }

    const reasoning = typeof params.reasoning === "string" ? params.reasoning : "";
    state.executed++;

    const outcome = await session.emitAction({
      tool, actor: action.actor, id: action.id, action, reasoning,
    });

    // 刷新本地视图：Godot 已算好执行后的 units / legal_actions
    const prevUnits = live.units;
    const prevEconomy = live.economy;
    live.units = outcome.units;
    live.legal_actions = outcome.legal_actions;
    if (outcome.terrain) live.terrain = outcome.terrain;
    if (outcome.economy) live.economy = outcome.economy;

    const economy = changedEconomy(prevEconomy, outcome.economy);

    // 用计 / 白兵战：Godot 已把结算整理成「成功与否 + 每个受影响武将的变化」，
    // 压成 {success, result:[{name, effect, currentStatus}]} 回给模型，不必再回 units 数组。
    // 当前兵力/体力用回传的 units 里的最新值（结算瞬间读到的可能还是旧值）。
    if (tool === "stratagem" && outcome.stratagem) {
      return result(compactStratagem(outcome.stratagem, outcome.units), { action, ok: outcome.ok });
    }
    if (tool === "attack" && outcome.battle) {
      return result(compactStratagem(outcome.battle, outcome.units, outcome.battle.loser ?? ""), { action, ok: outcome.ok });
    }

    // 其余动作只回「有变化」的单位与最小字段：完整档案（装备/技能/attrs/exp）开场已经给全，
    // 每步全量回传会把上下文塞满（实测单步约 5.7KB，一回合 12 步），还会淹没真正变化的 ap/兵力。
    const summary = {
      ok: outcome.ok,
      outcome: outcome.outcome,
      units: diffUnits(prevUnits, outcome.units),
      // 敌方粮草会在回合内变化（夺米转金等），摘要里同步最新值避免模型读到过期数据。
      economy,
      hint: "继续决定下一个动作；动作结果已含最新合法动作，同一武将本回合不要再调 list_legal_actions。全部武将与机动力都无事可做时调用 end。",
    };
    return result(summary, { action, ok: outcome.ok });
  }

  const ACT_PROPS = { reasoning: { type: "string", description: "本动作的决策理由" } };

  const move: AgentTool<any> = {
    name: "move",
    label: "移动",
    description: [
      "让一个武将按你规划的路径逐格移动并立即执行，返回执行后的战场状态。",
      "path 是从当前位置的下一格开始、依次相邻的坐标，最后一格是目的地；不含起点。",
      "只能上下左右走一格，不能斜走。Godot 会逐格走、逐格扣机动力；",
      "遇到墙、其他武将或机动力不足会停在那一格，结果里会告诉你实际走到哪、扣了多少。",
    ].join(""),
    parameters: {
      type: "object",
      properties: {
        actor: { type: "number", description: "武将 id" },
        path: {
          type: "array",
          description: "逐格路径 [[x,y], ...]，不含起点，每步上下左右相邻一格，最后一格是目的地",
          minItems: 1,
          items: { type: "array", items: { type: "number" }, minItems: 2, maxItems: 2 },
        },
        ...ACT_PROPS,
      },
      required: ["actor", "path", "reasoning"],
      additionalProperties: false,
    },
    execute: async (_id, params) => runAction("move", params),
  };

  const attack: AgentTool<any> = {
    name: "attack",
    label: "攻击",
    description: [
      "让一个武将攻击相邻的敌方武将并立即结算白兵战（胜负不确定），之后可以继续调用其它动作。",
      "返回结构与 stratagem 相同，另多一个 loser：",
      '  · {"success": true, "result": [{"name":"吕布","effect":"战损兵力312","currentStatus":"士兵900、体力99"}, ...], "loser": "吕布"}',
      "      name 武将姓名 / effect 本场战损 / currentStatus 战后当前值；双方都会列出来。",
      '  · loser：战败方姓名；双方都还在打或未分胜负时没有这个键。',
      "看 effect 和 currentStatus 就能判断这一仗是赚是亏，不必再 inspect_unit 查这两个人。",
    ].join("\n"),
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
    description: [
      "让一个武将对目标发动计策并立即结算（机动力当场扣掉，无论中不中），之后可以继续调用其它动作。",
      "返回的是结算结论，不是战场全量快照（其余武将没变化就不要再看它们了）：",
      '  · {"success": false} —— 计策没命中，什么都没发生（机动力已扣）。',
      '  · {"success": true, "result": [...]} —— 命中。result 每个元素是一个被改变的武将：',
      '      name          武将姓名，如 "吕布"；只列真正被改变的，没变的武将不出现。',
      '      effect        发生了什么，如 "兵力下降124"、"体力下降9"、"免伤30"、"获得状态"。',
      '      currentStatus 结算后该武将的当前值，如 "士兵539、体力99、状态迟滞:2"。',
      '  · result 为空表示命中但没造成任何效果（如对方免疫）。',
      "需要判断「再打一次还值不值」时，用 currentStatus 里的士兵数，不要再去 inspect_unit 查同一个武将。",
    ].join("\n"),
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
    tools: [
      list_legal_actions, inspect_unit, inspect_economy, estimate_stratagem, estimate_move, estimate_moves,
      move, attack, stratagem, retreat, end,
    ],
    state,
  };
}

export const TOOL_NAMES = [
  "list_legal_actions", "inspect_unit", "inspect_economy", "estimate_stratagem", "estimate_move",
  "estimate_moves", "move", "attack", "stratagem", "retreat", "end",
] as const;

/** 会交给 Godot 执行的工具（不含 end）。 */
export const ACT_TOOL_NAMES = ["move", "attack", "stratagem", "retreat"] as const;

/** 只读侦察工具：查询当前状态，不推进战局，不占 max_tool_calls 预算。 */
export const READ_TOOL_NAMES = [
  "list_legal_actions", "inspect_unit", "inspect_economy", "estimate_stratagem", "estimate_move",
  "estimate_moves",
] as const;
