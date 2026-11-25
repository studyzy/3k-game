// 白兵战 agent loop（独立于战争场景）。
//
// Godot 在 attack 触发白兵战后主动 POST /ai/battle 开启本会话；
// 服务端跑独立的 agent loop，提示词/场景数据/工具与战争场景完全不同。
// 1. 整个战斗 = 一个会话（Q3）。
// 2. 每个战斗回合里，LLM 用 set_order 逐兵种下命令、use_tactic 用计，
//    最后 end_turn 结束本回合，交还引擎结算。
// 3. 主回合会话在此期间挂起：工具 execute 未返回，不计 Agent 空闲超时（Q4）。
import { Agent } from "@earendil-works/pi-agent-core";
import { createModels } from "@earendil-works/pi-ai/models";
import { builtinModels } from "@earendil-works/pi-ai/providers/all";
import { fauxProvider, fauxAssistantMessage, fauxToolCall } from "@earendil-works/pi-ai/providers/faux";
import type { BattleBudget, BattleRequest } from "./types.ts";
import type { ServiceConfig } from "./config.ts";
import type { PiRuntime } from "./agent.ts";
import { ServiceError } from "./agent.ts";
import { buildBattleTools, BATTLE_TOOL_NAMES, BATTLE_READ_TOOL_NAMES, type BattleLive } from "./battle-tools.ts";
import { battleStore, type BattleSession } from "./battle-session.ts";
import { createCustomRuntime } from "./llm.ts";
import { traceStore, traceTools, type DecisionTrace } from "./trace.ts";

// 白兵战系统提示词 = 从 GDScript 源码提炼的「秘籍」。
// 依据：clBattleFight.gd（胜负/命令/计策 buff 回合数）、Battle_Unit.gd（伤害与射程）、
// IBattle_Damage.gd（C 值/伤害公式）、IUnitLogic.gd（命令的引擎语义）、
// Static_Manager.TACTICS 与 player_tactic.gd（计策消耗与效果）、War_Actor.gd（单挑接受率）、
// attribute_set.json（兵种属性）。全部数值与代码一致，改数值时必须同步改这里。
export const BATTLE_SYSTEM_PROMPT = [
  "你是三国策略游戏「霸王的大陆」白兵战（两军对阵）的我方指挥官。",
  "战场由己方主将率领若干兵种组成：将、骑、象、弓、步。你每回合为每个兵种下一次命令，命令会在交还引擎后同时生效并结算。",
  "命令只有三种：前进（进攻）、待机（原地防守）、后退（撤退）。计策可选（咒缚/挑衅/强弩/士气向上/火矢），消耗战术值。",
  "",
  "## 零、怎么打（流程）",
  "1. 先调用 inspect_battlefield 看清：双方兵力/武将体力/战术值/各兵种血量/敌方当前命令/可用计策。",
  "2. 用下方「决策顺序」逐条判断：主将撤不撤 → 用不用计 → 弓兵 vs 敌主将压不压 → 其余兵种推进。",
  "   决定用不用计之前先调 estimate_tactic(tactic)：它返回战术值消耗、能否发动、命中率，以及生效后各兵种攻击/防御/射程的具体变化（咒缚给目标主将的定止回合、挑衅给接受率与拒绝代价）。只读，不消耗战术值。",
  "3. 逐兵种 set_order，必要时 use_tactic，最后 end_turn 交还引擎。场上所有兵种都动一遍，没调用的兵种会按旧命令行动。",
  "4. 不要编造不存在的兵种或计策；计策必须在 legal_tactics 里且战术值够。",
  "",
  "## 一、胜负条件（只认这几种）",
  "- 主将体力归零 / 被俘 / 阵亡 / 撤退 → 立即判负；双方同时消失则平。主将单位被带出场外也算撤退。",
  "- 双方兵力归零、主将都不在场 → 平局。",
  "- 所以：保住主将是一切的底线，干掉敌主将是最快的胜法。士兵全灭不等于输，主将还能打。",
  "",
  "## 二、命令的真实含义（决定会不会白挨打）",
  "- 前进：主动寻路向敌主将靠拢；能打就按 近身 > 投掷 > 射箭 出手；射箭 70% 命中触发；不能射箭的兵种（骑/象/步）会先移动。",
  "- 待机：不移动；但**射箭和投掷必发**（100%）。弓兵想让箭稳定打出去就选待机，代价是不前进。",
  "- 后退：永远不攻击、不射箭，只往己方出生侧后撤；撤出场外 = 该兵种消失。后退≠逃跑判负（只有主将撤退才判负）。",
  "- 因此：弓兵要射就选 待机/前进，选 后退 等于空掉它的输出；近战兵要打就别选 待机。",
  "",
  "## 三、伤害与 C 值（打满伤害的诀窍）",
  "- 最终伤害 = 基础攻击 × 倍率 × C/100 − 免伤。C 只由攻击者体力决定：",
  "  将按 体力×2 算（体力 50 即 C=100）；士兵按 兵力/100 算：兵力<1500→C=20，<3500→40，<6000→50，<8000→70，<9000→85，<10000→95，≥10000→100。",
  "  **士兵兵力低于 3500 时伤害只有 40%，被削残的兵种打人几乎没收益，优先整编/护住兵多的兵种。**",
  "- 士兵基础攻击 = 我方士气；基础防御 = 我方统/12。武将基础攻击 ≈ 武×胆/100×0.7，防御 ≈ (装备防+胆/8)/2。",
  "- 近身倍率：将/骑/步/象 1.0，象 2.2；弓近身只有 0.5（被贴脸很亏）；弓远射 1.0，投掷默认 0.5。",
  "  武将对武将的伤害上下限：最少 1 点，最多 12 点；对士兵最少 1 点。",
  "",
  "## 四、射程与安全距离",
  "- 弓 射程 4（特殊兵种可到 5），骑(弓) 3；站在射程内且无遮挡时，待机/前进的弓兵每回合稳定输出。",
  "- 近身攻击距离默认 1（带「枪」武器可 2）。",
  "- 武将的箭雨威胁：无强弩时，把己方主将保持在敌方弓兵 5 格以外；对方开了强弩则要退到 7 格外。",
  "- 主将身边的近战兵（步/骑/象）是实质护盾：敌人必须先清掉它们才能贴身打主将。",
  "",
  "## 五、计策（按性价比排序，先看清消耗与 buff 回合数）",
  "- 咒缚：3 战术值。50% 成功率（装备可加成）。命中后**敌方主将 3 回合内不能移动**（他的士兵照常前进）。",
  "  对「敌主将已后撤、或在射程外」的场面价值最高：一命中就把对方钉在原地当靶子。",
  "- 火矢（10）：4 回合。全体攻击自带火矢：射箭基础攻击 +9~15，并**无视受击士兵 1/3 防御**。兵多、能持续射/砍时才值这个价。",
  "- 士气向上（8）：4 回合。全体基础攻击 +5~9、士兵防御×1.2。兵多或要打持久肉搏时用。",
  "- 强弩（7）：3 回合。己方射程 +2、射箭必发；且守城方距离>4 时伤害不再减半。**场上射程为 0 的兵种不受益**。",
  "- 挑衅（5）：让对方主将选择是否单挑。接受率 = min((我方等级-敌等级)×2+32-敌知/10, 敌体×敌武×敌胆×(100-敌知)/100万)，",
  "  多数情况接受率很低；被拒绝反而**掉敌方 4 士气和 10 胆**，是削弱敌人士气、压主将攻击力的便宜手。",
  "  实际接受率与双方体力/武力/胆/单挑 dex 以 estimate_tactic(\"挑衅\") 为准。",
  "- 我方已在本回合用过一次战术 buff 后，对方可以再开新 buff 覆盖掉（同一天只能存在一个），别把好计策浪费在残局。",
  "",
  "## 六、决策顺序（每回合照这个顺序过一遍）",
  "1. 【主将生死】我方主将 体力 ≤ 50 或兵力明显劣势、且没有反击手段 → 主将 set_order(将, 后退/待机)，优先保命。",
  "2. 【火力启动】本回合若有至少 1 个弓兵血线健康且敌主将/敌弓兵在射程内 → 先开强弩或火矢，再下令弓兵。",
  "3. 【斩首】敌主将体力低（尤其 ≤ 12）且我方近战能贴身 → 所有步/骑/象 前进压向敌主将，一次性打死，直接判胜。",
  "4. 【压制弓兵】敌方弓兵血量高、又在能射到我方主将的位置 → 近战兵前进贴脸逼它换近身（它的近身倍率只有 0.5）。",
  "5. 【填肉盾】我方主将回避/必须待机时，用健康的步/骑 顶在主将前面 1~2 格，吸收近身攻击。",
  "6. 【保血】某兵种血量 ≤ 2 格（≈200）→ 后退保存，避免被单次打死；兵力 < 3500 的兵种不安排主动进攻。",
  "7. 全部安排完 → end_turn。",
  "",
  "## 七、红线",
  "- 只下 legal 命令：单位必须是 controlled.units 里 hp>0 的兵种；计策必须是 legal_tactics 里的。",
  "- 听从上面的经验但以实时数据为准：血量、射程、地形遮挡以 inspect_battlefield / 工具回传为准。",
  "- reasoning 只写一句理由，不写诗、不寒暄。",
].join("\n");

export function battleBudgetFor(req: BattleRequest): BattleBudget {
  const base = req.budget ?? {};
  return {
    max_turns: base.max_turns ?? 6,
    max_tool_calls: base.max_tool_calls ?? 12,
    max_tokens: base.max_tokens ?? 1024,
    idle_timeout_ms: base.idle_timeout_ms ?? 30000,
  };
}

export interface BattleOptions {
  mode: "mock" | "stub" | "pi";
  config: ServiceConfig;
  runtime?: PiRuntime;
}

/** 开启一场白兵战会话，后台跑 agent loop。 */
export function startBattle(req: BattleRequest, opts: BattleOptions): { session: BattleSession; budget: BattleBudget } {
  const budget = battleBudgetFor(req);
  const session = battleStore.create(req, budget.idle_timeout_ms);

  const tr = traceStore.create({
    mode: opts.mode,
    model: opts.mode === "stub" ? "faux-1" : (opts.config.llmBaseUrl ? opts.config.llmModelId : opts.config.modelId),
    turn_key: req.battle_key,
    diffculities: req.diffculities,
    controlled_vstate_id: req.controlled_actor_id,
    legal_actions_count: req.legal_tactics.length,
    ai_agent_mode: true,
    system_prompt: BATTLE_SYSTEM_PROMPT,
    user_message: "",
    tools: [],
  });
  traceStore.add(tr, "system", { text: BATTLE_SYSTEM_PROMPT });

  void runBattle(session, budget, opts, tr).catch(() => { /* 错误已写入 session/trace */ });
  return { session, budget };
}

async function runBattle(
  session: BattleSession, budget: BattleBudget, opts: BattleOptions, tr: DecisionTrace,
): Promise<void> {
  const req = session.req;
  const t0 = Date.now();
  const live: BattleLive = {
    turn: req.turn,
    controlled: req.controlled,
    enemy: req.enemy,
    legal_tactics: req.legal_tactics,
  };
  const userMessage = buildBattleUserMessage(req);
  tr.user_message = userMessage;
  traceStore.add(tr, "user", { text: userMessage });

  try {
    if (opts.mode === "mock") {
      traceStore.add(tr, "mock", { text: "mock 白兵战（无 LLM 对话）" });
      await mockBattle(session, req);
      return;
    }
    await piBattle(session, budget, opts, tr, live, userMessage);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    traceStore.add(tr, "error", { text: message, ok: false });
    traceStore.finish(tr, { status: "error", error: message, elapsed_ms: Date.now() - t0 });
    session.fail(err instanceof Error ? err : new Error(message));
  }
}

function buildBattleUserMessage(req: BattleRequest): string {
  return [
    "白兵战开始。以下是我方与敌方的初始态势。",
    "请先 inspect_battlefield，然后逐兵种 set_order 下命令，最后 end_turn。",
    "",
    "```json",
    JSON.stringify({
      battle_key: req.battle_key,
      side: req.side,
      turn: req.turn,
      controlled: req.controlled,
      enemy: req.enemy,
      legal_tactics: req.legal_tactics,
    }),
    "```",
  ].join("\n");
}

async function mockBattle(session: BattleSession, req: BattleRequest): Promise<void> {
  // 确定性：给每个存活兵种下「前进」，然后结束
  for (const u of req.controlled.units) {
    if (u.hp <= 0) continue;
    await session.setOrder(u.type, "前进", "mock");
  }
  await session.endTurn("mock 结束");
}

function createStubRuntime(req: BattleRequest): PiRuntime {
  const faux = fauxProvider();
  const models = createModels();
  models.setProvider(faux.provider);
  const alive = req.controlled.units.filter((u) => u.hp > 0);
  // faux 的响应是「全局队列」，跨 prompt 不重置；固定条数的脚本会让
  // 第 2 个战斗回合从上一回合中间继续读，导致兵种错位。
  // 因此每次模型调用前重新投喂本轮要用的回复（一个兵种一条，最后 end_turn）。
  const origStream = models.streamSimple.bind(models);
  let idx = 0;
  const dynamicStream = (model: unknown, context: any, opts?: unknown) => {
    const u = idx < alive.length ? alive[idx++] : null;
    const reply = u
      ? fauxAssistantMessage(fauxToolCall("set_order", { unit: u.type, order: "前进", reasoning: "stub" }), { stopReason: "toolUse" })
      : fauxAssistantMessage(fauxToolCall("end_turn", { reasoning: "stub 结束" }), { stopReason: "toolUse" });
    if (!u) idx = 0; // 本回合结束，下一回合从头开始
    faux.setResponses([reply]);
    return (origStream as any)(model, context, opts);
  };
  return { model: faux.getModel(), streamFn: dynamicStream as never, modelId: "faux-1" };
}

function realRuntime(config: ServiceConfig, env: Record<string, string | undefined>): PiRuntime {
  if (config.llmBaseUrl) {
    const key = env.LLM_API_KEY ?? env.PI_API_KEY;
    if (!key) throw new ServiceError(503, "api_key_missing", "缺少 LLM_API_KEY / PI_API_KEY");
    return createCustomRuntime({
      baseUrl: config.llmBaseUrl,
      modelId: config.llmModelId,
      apiKey: key,
      providerId: config.llmProviderId,
      contextWindow: config.llmContextWindow,
      maxTokens: config.llmMaxTokens,
    });
  }
  const models = builtinModels();
  const model = models.getModel(config.provider, config.modelId) ?? models.getModels(config.provider)[0];
  if (!model) throw new ServiceError(503, "model_unavailable", `无法解析模型 ${config.provider}/${config.modelId}`);
  const keyFor = (p: string) => env[`${p.toUpperCase().replace(/[^A-Z0-9]/g, "_")}_API_KEY`] ?? env.PI_API_KEY;
  if (!keyFor(config.provider)) throw new ServiceError(503, "api_key_missing", `缺少 ${config.provider.toUpperCase()}_API_KEY`);
  return { model, streamFn: models.streamSimple.bind(models), getApiKey: keyFor, modelId: model.id };
}

async function piBattle(
  session: BattleSession, budget: BattleBudget, opts: BattleOptions,
  tr: DecisionTrace, live: BattleLive, userMessage: string,
): Promise<void> {
  const runtime = opts.mode === "stub"
    ? createStubRuntime(session.req)
    : opts.runtime ?? realRuntime(opts.config, process.env as Record<string, string | undefined>);

  const { tools, state } = buildBattleTools(live, session, budget);
  // 工具定义也是请求上下文的一部分，随轨迹一起展示（mock 模式没有工具）。
  tr.tools = traceTools(tools);
  const counters = { turns: 0, toolCalls: 0, tokens: 0 };
  // 本段 loop 内出现过什么工具：acted = 下发过动作（set_order/use_tactic/end_turn），
  // inspected = 只侦察过。都不在 turn_start 重置——pi 的 turn 会切到「侦察后的下一轮」，
  // 重置会把刚侦察过的状态抹掉，导致侦察完就被当成空转收尾。
  const turn = {
    acted: false,
    inspected: false,
    reset() { this.acted = false; this.inspected = false; },
    noteTool(name: string) {
      if ((BATTLE_READ_TOOL_NAMES as readonly string[]).includes(name)) this.inspected = true;
      else this.acted = true;
    },
  };
  /** 一轮 prompt 的起点：清掉上一段 loop 留下的标记。 */
  const resetTurn = () => {
    turn.reset();
    counters.turns = 0;
  };
  const t0 = Date.now();

  /** 一个战斗回合的收敛：模型收尾后本回合必须有一条 end_turn 交还引擎，否则 Godot 只能等到空闲超时。 */
  const closeRound = () => {
    if (session.finished || session.turnEnded) return;
    traceStore.add(tr, "tool_call", { tool: "end_turn", text: "模型未结束回合，服务端补发以推进引擎" });
    session.markTurnEnded();
    void session.endTurn("本回合决策结束").catch(() => { /* 引擎已离开本回合时忽略 */ });
  };

  /**
   * 下发过至少一条命令、却从没调 end_turn 就收尾了。
   * 此刻可能还有在途指令（Godot 一次只回传一条），所以先等「没有在途 + 没有待取」，
   * 再补 end_turn；否则引擎会把下一条命令排在补发的 end_turn 之后。
   * 真等不到（引擎那边的命令已经回传完）就在终点兜底。
   */
  const closeAfterCommands = async () => {
    if (session.finished || session.turnEnded) return;
    const deadline = Date.now() + budget.idle_timeout_ms;
    while (session.inflightCount > 0 || session.queuedCount > 0) {
      if (session.finished || session.turnEnded) return;
      if (Date.now() > deadline) break;
      await new Promise((r) => setTimeout(r, 20));
    }
    closeRound();
  };

  const agent = new Agent({
    initialState: { systemPrompt: BATTLE_SYSTEM_PROMPT, model: runtime.model as never, tools: tools as never },
    streamFn: runtime.streamFn as never,
    getApiKey: runtime.getApiKey,
    toolExecution: "sequential",
    beforeToolCall: async ({ toolCall }) => {
      // 任何工具调用（含 inspect_battlefield）都说明 Agent 还活着，重置空闲计时。
      session.touch();
      // 只读侦察与用计预估是决策前提，不占工具预算；只有下令/用计/结束回合计数。
      if ((BATTLE_READ_TOOL_NAMES as readonly string[]).includes(toolCall.name)) return undefined;
      counters.toolCalls++;
      if (counters.toolCalls > budget.max_tool_calls) {
        return { block: true, reason: "max_tool_calls exceeded", terminate: true };
      }
      return undefined;
    },
    // 不在 afterToolCall 里 terminate：那会让 loop 在同一次 prompt 内
    // 继续请求模型，把下一战斗回合的指令提前消耗掉。
    // 回合收敛统一交给 finishTurn。
    afterToolCall: async () => undefined,
    finishTurn: async () => {
      // end_turn 的 terminate 只结束本轮工具批次，loop 会继续问模型；
      // 模型随后往往再答一句「已结束」并被当成新一轮。这里统一收敛。
      if (state.ended) return { action: "end" };
      // 单次 prompt 内的轮数上限：死循环兜底，别让模型无限追问下去。
      if (counters.turns >= budget.max_turns) return { action: "end" };
      // 模型这一轮只「说」不动手：收敛，别对死胡同反复请求。
      // 但本段 loop 侦察过战场时不能收敛 —— 侦察结果还没回到模型，
      // loop 会带着它再问一次，提前收尾会让模型拿到缩水回合的机会全部丢掉。
      if (!turn.acted && !turn.inspected) return { action: "end" };
      // 模型下了令没调 end_turn：交给 prompt 返回后补发，
      // 避免在工具仍未返回时抢占「没有在途指令」的判断。
      return undefined;
    },
    // 注意：counters.turns 在每个战斗回合开始时重置，
    // 因此 max_turns 约束的是「单次 prompt 内的轮数」，不会跨回合累积。
  });

  agent.subscribe((event: any) => {
    if (event.type === "turn_start") {
      counters.turns++;
      traceStore.add(tr, "turn", { turn: counters.turns, text: `白兵战第 ${counters.turns} 轮` });
    }
    if (event.type === "message_end" && event.message?.role === "assistant") {
      counters.tokens += Number(event.message?.usage?.totalTokens ?? 0);
      const blocks: any[] = event.message.content ?? [];
      const txt = blocks.filter((c) => c.type === "text").map((c) => c.text).join("").trim();
      const calls = blocks.filter((c) => c.type === "toolCall");
      for (const c of calls) turn.noteTool(String(c.name));
      traceStore.add(tr, "assistant", {
        turn: counters.turns,
        text: txt || (calls.length ? `（调用 ${calls.map((c) => c.name).join(", ")}）` : ""),
        args: calls.length ? calls.map((c) => ({ id: c.id, name: c.name, arguments: c.arguments })) : undefined,
      });
    }
    if (event.type === "tool_execution_start") {
      traceStore.add(tr, "tool_call", { turn: counters.turns, tool: String(event.toolName ?? "") });
    }
    if (event.type === "tool_execution_end") {
      const r = event.result ?? {};
      traceStore.add(tr, "tool_result", {
        turn: counters.turns,
        tool: String(event.toolName ?? ""),
        text: (r.content ?? []).map((c: any) => c.text ?? "").join(""),
        ok: !event.isError,
      });
    }
  });

  // 整场战斗 = 一个会话（Q3）：每个战斗回合跑一轮 agent loop，
  // end_turn 后交还引擎结算，Godot 推进到下一战斗回合时继续。
  resetTurn();
  await agent.prompt(userMessage);
  // 模型收尾时没给 end_turn（下完令忘了结束）：
  // end_turn 只由工具产出，没人补发 Godot 会一直轮询到空闲超时，整场白兵战卡死。
  await closeAfterCommands();

  let battleTurn = 1;
  while (!session.finished && battleTurn < 30) {
    const more = await session.waitForNextTurn(budget.idle_timeout_ms);
    if (!more || session.finished) break;
    battleTurn++;
    state.ended = undefined;
    state.commands = 0;
    // 预算是「单个战斗回合」的额度：每回合重置轮数与调用次数，
    // 否则多回合战斗会在中途被总预算截断。
    counters.toolCalls = 0;
    resetTurn();
    traceStore.add(tr, "turn", { turn: battleTurn, text: `白兵战第 ${battleTurn} 回合` });
    await agent.prompt(`白兵战第 ${battleTurn} 回合开始，请重新给各兵种下令。`);
    await closeAfterCommands();
  }

  if (!session.finished) {
    const err = new ServiceError(422, "battle_turn_limit", "白兵战回合数超限或引擎未推进");
    traceStore.finish(tr, {
      status: "error", error: err.message, model: runtime.modelId,
      elapsed_ms: Date.now() - t0,
      budget_used: { tokens: counters.tokens, turns: counters.turns, tool_calls: counters.toolCalls },
    });
    session.fail(err);
    return;
  }
  traceStore.finish(tr, {
    status: "ok", model: runtime.modelId, elapsed_ms: Date.now() - t0,
    budget_used: { tokens: counters.tokens, turns: counters.turns, tool_calls: counters.toolCalls },
  });
}

export { BATTLE_TOOL_NAMES };