import type { DecideRequest } from "../src/types.ts";

export function sampleRequest(overrides: Partial<DecideRequest> = {}): DecideRequest {
  return {
    state_version: 1,
    visibility: "omniscient",
    static_bundle_id: "v1",
    turn_key: "w2-d7-s1",
    controlled_vstate_id: 2,
    diffculities: 3,
    session_id: "sgz-test",
    units: [
      { id: 12, vstate: 2, pos: [8, 14], ap: 7, poker: 3, soldiers: 1200, disabled: false },
      { id: 13, vstate: 2, pos: [7, 14], ap: 5, poker: 2, soldiers: 800, disabled: false },
      { id: 31, vstate: 1, pos: [9, 15], ap: 6, poker: 2, soldiers: 900, disabled: false },
    ],
    terrain: [
      { pos: [8, 14], kind: "plain", move_cost: 1 },
      { pos: [8, 15], kind: "plain", move_cost: 1 },
      { pos: [9, 15], kind: "forest", move_cost: 2 },
    ],
    economy: { rice: 420, money: 1800, day: 7, max_days: 30, main_city_pos: [3, 9] },
    legal_actions: [
      { id: "m3", tool: "move", actor: 12, pos: [8, 15], cost: { ap: 1, poker: 0 } },
      { id: "a1", tool: "attack", actor: 12, target: 31, cost: { ap: 2 } },
      { id: "s7", tool: "stratagem", actor: 12, target: 31, skill: "火计", cost: { ap: 2, poker: 1 } },
      { id: "r2", tool: "retreat", actor: 13, city: 5, cost: {} },
      { id: "e0", tool: "end", actor: 12, cost: {} },
    ],
    ...overrides,
  };
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
