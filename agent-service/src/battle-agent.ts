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
import { buildBattleTools, BATTLE_TOOL_NAMES, type BattleLive } from "./battle-tools.ts";
import { battleStore, type BattleSession } from "./battle-session.ts";
import { createCustomRuntime } from "./llm.ts";
import { traceStore, type DecisionTrace } from "./trace.ts";

export const BATTLE_SYSTEM_PROMPT = [
  "你是三国策略游戏「霸王的大陆」白兵战（两军对阵）的我方指挥官。",
  "战场由己方主将率领若干兵种组成：将（主将）、骑、象、弓、步。每回合你为每个兵种下令。",
  "命令只有三种：前进（进攻）、待机（原地防守）、后退（撤退）。",
  "你也可以使用计策（咒缚/挑衅/强弩/士气向上/火矢），消耗战术值。",
  "【做法】先用 inspect_battlefield 看清态势，然后逐兵种调用 set_order 下命令，",
  "必要时 use_tactic 用计。所有命令下完后调用 end_turn 交还引擎结算推进。",
  "你会收到每次操作后的最新战场数据，请据此调整。不要编造不存在的兵种或计策。",
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
  const counters = { turns: 0, toolCalls: 0, tokens: 0 };
  const t0 = Date.now();

  const agent = new Agent({
    initialState: { systemPrompt: BATTLE_SYSTEM_PROMPT, model: runtime.model as never, tools: tools as never },
    streamFn: runtime.streamFn as never,
    getApiKey: runtime.getApiKey,
    toolExecution: "sequential",
    beforeToolCall: async () => {
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
      if (state.ended) return { action: "end" };
      if (counters.turns >= budget.max_turns) return { action: "end" };
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
  counters.turns = 0;
  await agent.prompt(userMessage);

  let battleTurn = 1;
  while (!session.finished && battleTurn < 30) {
    const more = await session.waitForNextTurn(budget.idle_timeout_ms);
    if (!more || session.finished) break;
    battleTurn++;
    state.ended = undefined;
    // 预算是「单个战斗回合」的额度：每回合重置轮数与调用次数，
    // 否则多回合战斗会在中途被总预算截断。
    counters.turns = 0;
    counters.toolCalls = 0;
    traceStore.add(tr, "turn", { turn: battleTurn, text: `白兵战第 ${battleTurn} 回合` });
    await agent.prompt(`白兵战第 ${battleTurn} 回合开始，请重新给各兵种下令。`);
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