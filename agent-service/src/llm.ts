// 自定义 OpenAI 兼容端点（/v1/chat/completions）→ pi-ai Provider。
// 用户提供的 CCR / hai 端点不在 Pi 的内置 provider 目录里，但协议是标准
// Chat Completions，因此复用 Pi 官方的 openAICompletionsApi() 实现，
// 由它负责 transcript → messages、tools、tool_calls 的转换。
import { createModels, createProvider } from "@earendil-works/pi-ai/models";
import { openAICompletionsApi } from "@earendil-works/pi-ai/api/openai-completions.lazy";

export interface CustomRuntime {
  model: unknown;
  streamFn: unknown;
  modelId: string;
}

export interface CustomLlmOptions {
  baseUrl: string;
  modelId: string;
  apiKey: string;
  providerId?: string;
  contextWindow?: number;
  maxTokens?: number;
}

export function createCustomRuntime(opts: CustomLlmOptions): CustomRuntime {
  const baseUrl = opts.baseUrl.replace(/\/+$/, "");
  const providerId = opts.providerId ?? "ccr";

  const provider = createProvider({
    id: providerId,
    name: `Custom OpenAI-compatible (${providerId})`,
    baseUrl,
    // 密钥只存在于进程环境变量，不写入任何文件 / 日志
    auth: {
      apiKey: {
        name: "LLM API key",
        resolve: async () => ({ auth: { apiKey: opts.apiKey }, source: "LLM_API_KEY" }),
      },
    },
    models: [{
      id: opts.modelId,
      name: opts.modelId,
      api: "openai-completions",
      provider: providerId,
      baseUrl,
      reasoning: false,
      input: ["text"],
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
      contextWindow: opts.contextWindow ?? 65536,
      maxTokens: opts.maxTokens ?? 8192,
      compat: {
        supportsStore: false,
        supportsDeveloperRole: false,
        maxTokensField: "max_tokens",
      },
    }],
    api: openAICompletionsApi(),
  });

  const models = createModels();
  models.setProvider(provider);
  const model = models.getModel(providerId, opts.modelId);
  if (!model) throw new Error(`无法解析自定义模型 ${providerId}/${opts.modelId}`);

  return { model, streamFn: models.streamSimple.bind(models), modelId: opts.modelId };
}
