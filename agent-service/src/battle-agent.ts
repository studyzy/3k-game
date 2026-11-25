// 白兵战异步 tick：一场战斗一个 Agent 会话，每拍快照进、计划出。
// 没有工具、没有 end_turn、没有长轮询；计策在客户端安全点执行。
import { Agent } from "@earendil-works/pi-agent-core";
import { builtinModels } from "@earendil-works/pi-ai/providers/all";
import type {
  BattleOpenRequest, BattlePlan, BattleSnapshotV2, BattleTickResult, BattleValidationRejected,
} from "./types.ts";
import type { ServiceConfig } from "./config.ts";
import type { PiRuntime } from "./agent.ts";
import { ServiceError } from "./agent.ts";
import { createCustomRuntime } from "./llm.ts";
import { traceStore, type DecisionTrace } from "./trace.ts";
import { battleStore, type BattleSession } from "./battle-session.ts";
import { emptyPlan, extractJson, validateBattlePlan } from "./battle-plan.ts";

const TICK_TIMEOUT_MS = 20_000;
// abort 之后最多再等这么久让 agent 自己停下来；超时说明底层 provider 不响应 abort，
// 这一拍就放弃（会话标记 stuck），否则 waitForIdle() 会永远挂住。
const ABORT_SETTLE_MS = 2_000;
const MAX_MESSAGES = 13;
// 白兵战每拍只是一份很小的 JSON 计划，600 token 足够；防止模型长篇大论拖慢 3 秒节拍。
const BATTLE_MAX_TOKENS = 600;

export const BATTLE_SYSTEM_PROMPT = [
  "你是三国策略游戏「霸王的大陆」白兵战（两军对阵）的我方指挥官。",
  "战斗是准实时的：玩家随时可能暂停、改命令、用计，引擎不会停下来等你。你每隔约 3 秒收到一次最新态势，只需要决定「要不要改命令 / 要不要用计」。",
  "",
  "## 输出（只输出 JSON，不要解释）",
  '{"orders":{"弓":"待机"},"tactic":null,"memory":"一句战略笔记","reasoning":"一句理由"}',
  "- orders 是差分：只写要改的兵种；当前命令已经合适就不要写；都不想改就返回 {}。",
  "- 命令：前进（进攻）、待机（原地防守）、后退（撤退）。",
  "- tactic：每拍最多一个，必须是 legal_tactics 里的名字；不用就 null。",
  "- tactic_status=pending 表示上一拍计策已入队、还没到安全点执行；看到 pending 不要重复下同一个计策。",
  "- memory：≤120 字，下一拍会原样回喂给你；写接下来 1-2 拍的意图。",
  "- 不要输出 end_turn，不要输出 JSON 以外的文字。",
  "",
  "## 命令的真实含义",
  "- 前进：向敌主将寻路；能打就按 近身 > 投掷 > 射箭 出手；射箭 70% 命中触发。",
  "- 待机：不移动；但射箭/投掷必发（100%）。弓兵想稳定输出就待机。",
  "- 后退：不攻击、只往己方出生侧撤；撤出场外该兵种消失。主将后退 = 整场判负。",
  "",
  "## 伤害与 C 值",
  "- 最终伤害 = 基础攻击 × 倍率 × C/100 − 免伤。C 只由攻击者体力决定：将 C=体力×2；士兵按兵力：<1500→20，<3500→40，<6000→50，<8000→70，<9000→85，<10000→95，≥10000→100。",
  "- 兵力 <3500 → C≤40，伤害只有 40%，残兵不要主动进攻。",
  "- 近身倍率：将/骑/步 1.0，象 2.2，弓 0.5；弓远射 1.0，投掷默认 0.5。武将打武将伤害 1~12，打士兵最少 1。",
  "",
  "## 射程",
  "- 弓 4（特殊 5），骑(弓) 3；近身默认 1（枪 2）。",
  "- 无强弩时，主将尽量离敌弓 5 格以上；敌开强弩则 7 格以上。",
  "- 主将身边的步/骑/象是肉盾，敌人必须先清掉它们才能贴主将。",
  "",
  "## 计策（legal_tactics 已给 cost/rate/summary）",
  "- 咒缚 3：50% 定住敌主将 3 回合，最适合敌主将后撤/在射程外。",
  "- 火矢 10：4 回合，射箭攻击 +9~15，无视 1/3 防御；兵多能持续输出才值。",
  "- 士气向上 8：4 回合，全体攻击 +5~9，士兵防御 ×1.2；持久肉搏时用。",
  "- 强弩 7：3 回合，射程 +2、射箭必发；射程 0 的兵种不受益。",
  "- 挑衅 5：敌主将接受单挑；多数接受率低，但被拒会掉敌 4 士气/10 胆。",
  "- 同一时间只存在一个战术 buff，后开覆盖先开；controlled.buffs 里已有的不要重复。",
  "",
  "## 决策顺序（每拍都可以重新评估）",
  "1. 主将体力 ≤50 或被贴脸且无反击 → 主将后退/待机，步骑填肉盾。",
  "2. 弓兵在射程内且血线健康 → 先开强弩/火矢，再让弓兵待机。",
  "3. 敌主将体力低且近战能贴身 → 步/骑/象 前进斩首。",
  "4. 敌弓能射到我方主将 → 近战前进贴脸，逼它近身（弓近身 0.5）。",
  "5. 主将回避时，用健康步/骑顶在主将前 1~2 格。",
  "6. 某兵种 hp ≤2 格（≈200）→ 后退保存；兵力 <3500 不主动进攻。",
  "",
  "## 数据口径",
  "- controlled/enemy.units[].x/y 是离对方主将最近的单位坐标；dist_to_other_main 是曼哈顿距离。",
  "- other_main_in_shoot_range 只是「射程 ≥ 距离」的近似，不含视线遮挡；实际命中以引擎为准。",
  "- 主将 = units 里 type 为「将」的那一项。",
].join("\n");

export interface BattleOptions {
  mode: "mock" | "stub" | "pi";
  config: ServiceConfig;
  runtime?: PiRuntime;
}

function traceModel(opts: BattleOptions): string {
  if (opts.mode === "stub") return "stub";
  if (opts.mode === "mock") return "mock";
  return opts.config.llmBaseUrl ? opts.config.llmModelId : opts.config.modelId;
}

export function startBattle(req: BattleOpenRequest, opts: BattleOptions): BattleSession {
  const session = battleStore.create({
    battleKey: req.battle_key,
    controlledActorId: req.controlled_actor_id,
    enemyActorId: req.enemy_actor_id,
    side: req.side,
    diffculities: req.diffculities,
  });
  const tr = traceStore.create({
    mode: opts.mode,
    model: traceModel(opts),
    turn_key: req.battle_key,
    diffculities: req.diffculities,
    controlled_vstate_id: req.controlled_actor_id,
    legal_actions_count: 0,
    ai_agent_mode: true,
    system_prompt: BATTLE_SYSTEM_PROMPT,
    user_message: "",
    tools: [],
  });
  traceStore.add(tr, "system", { text: BATTLE_SYSTEM_PROMPT });
  session.trace = tr;
  return session;
}

/** assistant 消息的纯文本；content 可能是字符串，也可能是 [{type:"text",text}] 块数组。 */
function assistantText(m: any): string {
  const content = m?.content;
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content.map((c: any) => {
      if (typeof c === "string") return c;
      if (c?.type === "text") return String(c.text ?? "");
      return "";
    }).join("");
  }
  return "";
}

/** provider 报错或没有正文的 assistant 轮不能回放，否则下一拍必然 400，且会永久卡住。 */
function unusableAssistant(m: any): boolean {
  if (m?.role !== "assistant") return false;
  if (m.stopReason === "error") return true;
  const content = m.content;
  if (content === undefined || content === null) return true;
  if (typeof content === "string") return content.trim() === "";
  if (Array.isArray(content)) {
    if (content.length === 0) return true;
    return content.every((c: any) =>
      (typeof c === "string" && c.trim() === "") ||
      (c?.type === "text" && String(c.text ?? "").trim() === ""),
    );
  }
  return false;
}

/**
 * 裁剪对话：保留 system，丢掉失败的 assistant 轮，取最近 keep 条，再从第一条 user 开始。
 * 如果尾部以 assistant 开头，它就是没有对应提问的「孤儿回答」，必须一并丢掉。
 */
function trimMessages(messages: any[], keep: number): any[] {
  const systems = messages.filter((m) => m?.role === "system");
  const usable = messages.filter((m) => m?.role !== "system" && !unusableAssistant(m));
  const budget = Math.max(0, keep - systems.length);
  const tail = budget > 0 ? usable.slice(-budget) : [];
  let start = 0;
  while (start < tail.length && tail[start]?.role !== "user") start++;
  return [...systems, ...tail.slice(start)];
}

function ensureAgent(session: BattleSession, opts: BattleOptions): Agent | null {
  if (opts.mode !== "pi") return null;
  if (session.agent) return session.agent;
  const runtime = opts.runtime ?? realRuntime(opts.config, process.env as Record<string, string | undefined>);
  const agent = new Agent({
    initialState: {
      systemPrompt: BATTLE_SYSTEM_PROMPT,
      model: runtime.model as never,
      tools: [] as never,
    },
    streamFn: runtime.streamFn as never,
    getApiKey: runtime.getApiKey,
    finishTurn: async () => ({ action: "end" }),
    transformContext: async (messages) => trimMessages(messages as unknown as any[], MAX_MESSAGES) as never,
  });
  agent.subscribe((event: any) => {
    if (event.type === "message_end" && event.message?.role === "assistant") {
      session.tokens += Number(event.message?.usage?.totalTokens ?? 0);
    }
  });
  session.agent = agent;
  return agent;
}

function realRuntime(
  config: ServiceConfig, env: Record<string, string | undefined>,
): PiRuntime {
  if (config.llmBaseUrl) {
    const key = env.LLM_API_KEY ?? env.PI_API_KEY;
    if (!key) throw new ServiceError(503, "api_key_missing", "缺少 LLM_API_KEY / PI_API_KEY");
    return createCustomRuntime({
      baseUrl: config.llmBaseUrl,
      modelId: config.llmModelId,
      apiKey: key,
      providerId: config.llmProviderId,
      contextWindow: config.llmContextWindow,
      maxTokens: Math.min(config.llmMaxTokens, BATTLE_MAX_TOKENS),
    });
  }
  const models = builtinModels();
  const model = models.getModel(config.provider, config.modelId) ?? models.getModels(config.provider)[0];
  if (!model) throw new ServiceError(503, "model_unavailable", "无法解析模型 " + config.provider + "/" + config.modelId);
  const keyFor = (p: string) => env[p.toUpperCase().replace(/[^A-Z0-9]/g, "_") + "_API_KEY"] ?? env.PI_API_KEY;
  if (!keyFor(config.provider)) {
    throw new ServiceError(503, "api_key_missing", "缺少 " + config.provider.toUpperCase() + "_API_KEY");
  }
  return { model, streamFn: models.streamSimple.bind(models), getApiKey: keyFor, modelId: model.id };
}

/** 成功返回 true；abort 后 agent 在 ms 内仍未停下则返回 false。 */
async function waitIdleWithin(agent: Agent, ms: number): Promise<boolean> {
  let timer: ReturnType<typeof setTimeout> | null = null;
  const late = new Promise<boolean>((resolve) => {
    timer = setTimeout(() => resolve(false), ms);
  });
  try {
    return await Promise.race([
      agent.waitForIdle().then(() => true, () => true),
      late,
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
}

async function promptWithTimeout(
  agent: Agent, message: string, timeoutMs: number,
): Promise<{ kind: "done" } | { kind: "timeout"; stuck: boolean }> {
  let aborted = false;
  let timer: ReturnType<typeof setTimeout> | null = null;
  const timeout = new Promise<{ kind: "timeout" }>((resolve) => {
    timer = setTimeout(() => {
      aborted = true;
      agent.abort();
      resolve({ kind: "timeout" });
    }, timeoutMs);
    (timer as any).unref?.();
  });
  const done = agent.prompt(message)
    .then(() => ({ kind: "done" as const }))
    .catch((err) => {
      if (aborted) return { kind: "timeout" as const };
      throw err;
    });
  try {
    const result = await Promise.race([done, timeout]);
    if (result.kind === "timeout") {
      // 有的 provider 不响应 abort；等不到 agent 空闲就判定 stuck，绝不无限等待。
      const idle = await waitIdleWithin(agent, ABORT_SETTLE_MS);
      return { kind: "timeout", stuck: !idle };
    }
    return result;
  } finally {
    if (timer) clearTimeout(timer);
  }
}

function lastAssistantMessage(agent: Agent): any | null {
  const messages: any[] = (agent.state.messages ?? []) as any[];
  for (let i = messages.length - 1; i >= 0; i--) {
    if (messages[i]?.role === "assistant") return messages[i];
  }
  return null;
}

function lastAssistantText(agent: Agent): string {
  return assistantText(lastAssistantMessage(agent));
}

// stub 仅用于测试：挑第一个合法计策以覆盖客户端排队逻辑。
function stubPlan(snapshot: BattleSnapshotV2): BattlePlan {
  const orders: Record<string, string> = {};
  for (const u of snapshot.controlled.units) {
    if (u.hp > 0) orders[u.type] = "前进";
  }
  return {
    orders: orders as never,
    tactic: snapshot.legal_tactics[0]?.name ?? null,
    memory: "stub",
    reasoning: "stub",
  };
}

function buildUserMessage(session: BattleSession, snapshot: BattleSnapshotV2): string {
  const last = snapshot.last_plan;
  const summary = last
    ? JSON.stringify({
        tick: last.tick, orders: last.orders, orders_applied: last.orders_applied,
        orders_rejected: last.orders_rejected, tactic: last.tactic,
        tactic_status: last.tactic_status, reason: last.reason, age_ms: last.age_ms,
      })
    : "（这是第一拍，还没有上一拍计划）";
  return [
    "第 " + session.tick + " 拍，距上拍 " + (last?.age_ms ?? 0) + "ms。战场第 " + snapshot.turn + " 回合，已进行 " + snapshot.elapsed_ms + "ms。",
    "上一拍你的计划与执行结果：" + summary,
    "你的战斗笔记：" + (session.memory || "（空）"),
    "最新态势（JSON）：",
    JSON.stringify(snapshot),
    "只输出 JSON 计划。",
  ].join("\n");
}

function recordTick(
  trace: DecisionTrace | null, session: BattleSession, rawText: string,
  rejected: BattleValidationRejected[], latency: number, ok: boolean,
): void {
  if (!trace) return;
  // 记录模型原文而不是解析后的计划：解析失败 / 截断时才看得出模型到底回了什么。
  traceStore.add(trace, "assistant", { text: rawText, turn: session.tick });
  traceStore.add(trace, "turn", {
    turn: session.tick,
    text: "tick=" + session.tick + " latency=" + latency + "ms rejected=" + rejected.length,
    ok,
  });
}

export async function tickBattle(
  session: BattleSession, snapshot: BattleSnapshotV2, opts: BattleOptions,
): Promise<BattleTickResult> {
  if (session.ended) throw new ServiceError(410, "session_ended", "战斗会话已结束");
  if (!session.beginTick()) throw new ServiceError(409, "tick_in_progress", "上一拍尚未结束");

  const t0 = Date.now();
  const tokensBefore = session.tokens;
  session.tick += 1;
  session.lastPlanResult = snapshot.last_plan ?? null;
  const usage = () => ({ tokens: Math.max(0, session.tokens - tokensBefore) });

  try {
    if (opts.mode !== "pi") {
      const plan = stubPlan(snapshot);
      session.lastPlan = plan;
      recordTick(session.trace, session, JSON.stringify(plan), [], Date.now() - t0, true);
      return {
        tick: session.tick, plan, rejected: [], latency_ms: Date.now() - t0, usage: usage(),
      };
    }

    const agent = ensureAgent(session, opts);
    if (!agent) throw new ServiceError(500, "agent_missing", "Agent 未初始化");
    const userMessage = buildUserMessage(session, snapshot);
    if (session.trace) {
      session.trace.user_message = userMessage;
      traceStore.add(session.trace, "user", { text: userMessage, turn: session.tick });
    }

    const outcome = await promptWithTimeout(agent, userMessage, TICK_TIMEOUT_MS);
    if (outcome.kind === "timeout") {
      const plan = emptyPlan();
      session.lastPlan = plan;
      // provider 不响应 abort：这一拍的 agent 已经不可再用，结束会话让下一拍回 410，
      // 客户端收到 410 会重新 /open 一场，不会继续对着卡死的会话发请求。
      if (outcome.stuck) session.finish("stuck");
      if (session.trace) {
        traceStore.add(session.trace, "error", {
          text: outcome.stuck ? "tick timeout (agent stuck, session closed)" : "tick timeout",
          ok: false, turn: session.tick,
        });
      }
      recordTick(session.trace, session, "", [], Date.now() - t0, false);
      return {
        tick: session.tick, plan, rejected: [], latency_ms: Date.now() - t0, timeout: true, usage: usage(),
      };
    }

    const last = lastAssistantMessage(agent);
    const providerError = last && (last.stopReason === "error" || last.errorMessage)
      ? String(last.errorMessage ?? "模型返回 stopReason=error")
      : "";
    if (providerError) {
      // pi 把流错误变成一条 stopReason=error 的 assistant 消息并让 prompt() 正常 resolve，
      // 这里必须显式失败，否则会把「模型报错」当成「本拍不改命令」的成功。
      if (session.trace) {
        traceStore.add(session.trace, "error", {
          text: "llm_error: " + providerError, ok: false, turn: session.tick,
        });
      }
      throw new ServiceError(502, "llm_error", providerError);
    }

    const rawText = lastAssistantText(agent);
    let plan = emptyPlan();
    let rejected: BattleValidationRejected[] = [];
    try {
      const raw = extractJson(rawText);
      const checked = validateBattlePlan(raw, snapshot);
      plan = checked.plan;
      rejected = checked.rejected;
    } catch (err) {
      rejected = [{ kind: "order", value: "", reason: "无效 JSON：" + (err as Error).message }];
      if (session.trace) {
        traceStore.add(session.trace, "error", {
          text: "invalid plan: " + (err as Error).message, ok: false, turn: session.tick,
        });
      }
    }

    // validateBattlePlan 已按码点截断 memory(120) / reasoning(200)，这里不再切，
    // 二次 slice 会把 emoji 的代理对切成半个。
    if (plan.memory && plan.memory.trim() !== "") session.memory = plan.memory.trim();
    session.lastPlan = plan;
    recordTick(session.trace, session, rawText, rejected, Date.now() - t0, true);
    return {
      tick: session.tick, plan, rejected, latency_ms: Date.now() - t0, usage: usage(),
    };
  } finally {
    session.endTick();
  }
}

export function endBattle(session: BattleSession): void {
  if (!session.finished) session.finish("ended");
  const tr = session.trace;
  if (tr && tr.status === "running") {
    traceStore.finish(tr, {
      status: "ok",
      elapsed_ms: Date.now() - Date.parse(tr.started_at),
      budget_used: { tokens: session.tokens, turns: session.tick, tool_calls: 0 },
    });
  }
  // 不立即 delete：会话保留 ended 标记，/tick 才能回 410；TTL 到期由 battleStore.prune() 清理。
}
