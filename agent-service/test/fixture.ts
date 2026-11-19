import type { LegalAction, TurnRequest } from "../src/types.ts";

/** 界面可见的武将全量信息（除头像与字），与 StateProjection.gd 的 unit 形状一致。 */
const unitExtras = {
  ap_max: 19,
  hp_max: 60,
  level: 2,
  exp: 2000,
  attrs: { 体: 51, 武: 30, 知: 72, 德: 49, 政: 78, 忠: 76, 统: 34, 胆: 54 },
  equips: { 武器: "短剑", 防具: "纶巾", 道具: "兵书", 坐骑: "黄鬃" },
  equip_briefs: { 武器: "短剑，攻：12，重：3", 防具: "防：4，重：1", 道具: "兵书", 坐骑: "马力：5，机动：2" },
  status: ["迟滞:3"],
  terrain_at: "平原",
};

export function sampleRequest(overrides: Partial<TurnRequest> = {}): TurnRequest {
  return {
    state_version: 1,
    visibility: "omniscient",
    static_bundle_id: "v1",
    turn_key: "w2-d7-s1",
    controlled_vstate_id: 2,
    side: "defender",
    diffculities: 3,
    session_id: "sgz-test",
    units: [
      { id: 12, name: "张飞", vstate: 2, pos: [8, 14], ap: 7, poker: 3, soldiers: 1200, disabled: false, ...unitExtras },
      { id: 13, name: "赵云", vstate: 2, pos: [7, 14], ap: 5, poker: 2, soldiers: 800, disabled: false, ...unitExtras },
      { id: 31, name: "曹操", vstate: 1, pos: [9, 15], ap: 6, poker: 2, soldiers: 900, disabled: false, ...unitExtras },
    ],
    // 地形只列非平原格：[x, y, "地形名"]
    terrain: [
      [9, 15, "树林"],
      [10, 15, "米屋"],
    ],
    economy: { rice: 420, money: 1800, day: 7, max_days: 30, main_city_pos: [3, 9], enemy: { rice: 310, money: 900 } },
    // move 不再由 Godot 出候选（路径由 LLM 规划，直接给 path）
    legal_actions: [
      { id: "a1", tool: "attack", actor: 12, target: 31, cost: { ap: 2 } },
      { id: "s7", tool: "stratagem", actor: 12, target: 31, skill: "火计", cost: { ap: 2, poker: 1 } },
      { id: "r2", tool: "retreat", actor: 13, city: 5, cost: {} },
      { id: "e0", tool: "end", actor: 12, cost: {} },
    ],
    ...overrides,
  } as TurnRequest;
}

export const testConfig = {
  port: 0,
  webDir: "../bwdl/build/web",
  mode: "mock" as const,
  mockCase: "ok",
  mockSlowMs: 30,
  provider: "openai",
  modelId: "gpt-4o-mini",
  llmBaseUrl: "",
  llmModelId: "hai/deepseek-flash",
  llmProviderId: "ccr",
  llmContextWindow: 65536,
  llmMaxTokens: 8192,
};

/** 与 bwdl/packed/sgz_script/war/AI/War_AI_behavior_llm.gd 的空闲超时对齐（毫秒）。 */
export const GODOT_IDLE_TIMEOUT_MS = 30000;

/** 构造 Godot 回传的工具结果（执行后状态）。 */
export function toolResult(
  seq: number,
  action: LegalAction | null,
  units?: Array<Record<string, unknown>>,
  legal?: LegalAction[],
): Record<string, unknown> {
  const base = sampleRequest();
  return {
    seq,
    ok: true,
    outcome: action ? `${action.tool} 执行完毕` : "无动作",
    units: units ?? base.units,
    legal_actions: legal ?? base.legal_actions,
    economy: base.economy,
  };
}

/** 一个必定会返回动作的假 Godot 驱动：轮询 → 回传 → 直到 end。 */
export async function driveTurn(
  sessionId: string,
  baseUrl: string,
  opts: { maxActions?: number; onAction?: (a: any) => void } = {},
): Promise<{ actions: any[]; endReason: string }> {
  const max = opts.maxActions ?? 20;
  const actions: any[] = [];
  for (let i = 0; i < max; i++) {
    const r = await fetch(`${baseUrl}/ai/turn/${sessionId}/pending?wait_ms=5000`).then((x) => x.json());
    if (r.type === "end") return { actions, endReason: String(r.reason ?? "") };
    if (r.type === "idle_timeout") return { actions, endReason: "__idle_timeout__" };
    if (r.type === "error") return { actions, endReason: "__error__:" + r.message };
    if (r.type === "retry") continue;
    actions.push(r.action);
    opts.onAction?.(r.action);
    await fetch(`${baseUrl}/ai/turn/${sessionId}/result`, {
      method: "POST",
      headers: { "content-type": "text/plain" },
      body: JSON.stringify(toolResult(r.action.seq, r.action.action)),
    });
  }
  return { actions, endReason: "__max_reached__" };
}