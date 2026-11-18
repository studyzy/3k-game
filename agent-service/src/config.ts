// 配置与难度预算（对应设计文档 §6）
import type { Budget } from "./types.ts";

export const BUDGETS: Record<number, Budget> = {
  2: { max_actions: 32, max_tokens: 512, max_turns: 2, max_tool_calls: 3, lookahead: 0, allow_memory: false, timeout_ms: 8000 },
  3: { max_actions: 32, max_tokens: 1024, max_turns: 4, max_tool_calls: 6, lookahead: 1, allow_memory: false, timeout_ms: 15000 },
  4: { max_actions: 32, max_tokens: 2048, max_turns: 8, max_tool_calls: 12, lookahead: 2, allow_memory: true, timeout_ms: 25000 },
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
  };
}
