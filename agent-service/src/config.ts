// 配置与难度预算（对应设计文档 §6）
//
// 服务端驱动的逐步交互：一次 AI 回合 = 一个会话，会话内 LLM 可以连续执行多个动作。
// 超时语义是「空闲超时」：每次 Godot 回传工具结果后开始计时，
// idle_timeout_ms 内 Agent 没有产出下一个动作 → 判定 LLM 已死，Godot 回退 hard。
//
// 预算依据（真实端点 hai/deepseek-flash 实测）：整侧计划决策 3–4 轮、7–12 次工具调用、5.4–8.9s。
// 回合内单动作决策推理量较小，max_turns/max_tool_calls 按「单次 LLM 请求」计。
import type { Budget } from "./types.ts";

const IDLE_TIMEOUT_MS = 30000;

export const BUDGETS: Record<number, Budget> = {
  // max_turns / max_tool_calls 的 100 只作死循环兜底：
  // max_tool_calls 只统计动作工具（只读侦察不计数），真正的动作上限由 max_actions 控制。
  2: { max_actions: 16, max_tokens: 512, max_turns: 100, max_tool_calls: 100, lookahead: 0, allow_memory: false, idle_timeout_ms: IDLE_TIMEOUT_MS },
  3: { max_actions: 24, max_tokens: 1024, max_turns: 100, max_tool_calls: 100, lookahead: 1, allow_memory: false, idle_timeout_ms: IDLE_TIMEOUT_MS },
  4: { max_actions: 32, max_tokens: 2048, max_turns: 100, max_tool_calls: 100, lookahead: 2, allow_memory: true, idle_timeout_ms: IDLE_TIMEOUT_MS },
};

export function budgetFor(diffculities: number, overrides?: Partial<Budget>): Budget {
  const base = BUDGETS[diffculities] ?? BUDGETS[3];
  return { ...base, ...(overrides ?? {}) };
}

export interface ServiceConfig {
  port: number;
  webDir: string;
  mode: "mock" | "stub" | "pi";
  mockCase: string;
  mockSlowMs: number;
  provider: string;
  modelId: string;
  /** 自定义 OpenAI 兼容端点。为空时使用 pi-ai 内置 provider 目录。 */
  llmBaseUrl: string;
  llmModelId: string;
  llmProviderId: string;
  llmContextWindow: number;
  llmMaxTokens: number;
  /** 云存档目录：每个 ID 一个子目录，每个槽位一个 <slot>.json。 */
  saveDir: string;
  /** 单个槽位文件上限（MiB）。 */
  saveMaxMb: number;
  /** 单个云存档 ID 的总量上限（MiB）。 */
  saveTotalMb: number;
  /** 槽位文件多少天未更新后清理。 */
  saveTtlDays: number;
}

function argValue(argv: string[], name: string): string | undefined {
  const i = argv.indexOf(`--${name}`);
  return i >= 0 ? argv[i + 1] : undefined;
}

export function parseConfig(argv: string[], env: Record<string, string | undefined>): ServiceConfig {
  return {
    port: Number(argValue(argv, "port") ?? env.PORT ?? 8060),
    webDir: argValue(argv, "web-dir") ?? env.WEB_DIR ?? "../bwdl/build/web",
    mode: (argValue(argv, "mode") ?? env.K3G_AGENT_MODE ?? "mock") as ServiceConfig["mode"],
    mockCase: env.MOCK_CASE ?? "ok",
    mockSlowMs: Number(env.MOCK_SLOW_MS ?? 3000),
    provider: env.PI_PROVIDER ?? "openai",
    modelId: env.PI_MODEL ?? "gpt-4o-mini",
    // 自定义端点：LLM_API_KEY 刻意不进 ServiceConfig，避免出现在日志/health 响应里
    llmBaseUrl: (env.LLM_BASE_URL ?? "").replace(/\/+$/, ""),
    llmModelId: env.LLM_MODEL ?? "hai/deepseek-flash",
    llmProviderId: env.LLM_PROVIDER_ID ?? "ccr",
    llmContextWindow: Number(env.LLM_CONTEXT_WINDOW ?? 65536),
    llmMaxTokens: Number(env.LLM_MAX_TOKENS ?? 8192),
    saveDir: argValue(argv, "save-dir") ?? env.SAVE_DIR ?? "data/saves",
    saveMaxMb: Number(argValue(argv, "save-max-mb") ?? env.SAVE_MAX_MB ?? 32),
    saveTotalMb: Number(argValue(argv, "save-total-mb") ?? env.SAVE_TOTAL_MB ?? 2048),
    saveTtlDays: Number(argValue(argv, "save-ttl-days") ?? env.SAVE_TTL_DAYS ?? 365),
  };
}