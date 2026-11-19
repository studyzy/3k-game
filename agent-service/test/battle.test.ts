// 白兵战 Agent 测试：独立会话、独立工具、每兵种单独下命令、整场战斗一个会话。
import test from "node:test";
import assert from "node:assert/strict";
import { startBattle } from "../src/battle-agent.ts";
import { battleStore, BattleSession } from "../src/battle-session.ts";
import { buildBattleTools, BATTLE_TOOL_NAMES } from "../src/battle-tools.ts";
import { validateBattleRequest, validateBattleResult } from "../src/validate.ts";
import { scriptedModel, calls, toolCall, text } from "./harness.ts";
import { testConfig } from "./fixture.ts";
import { traceStore } from "../src/trace.ts";
import type { BattleRequest } from "../src/types.ts";

function battleReq(over: Partial<BattleRequest> = {}): BattleRequest {
  return {
    battle_version: 1,
    visibility: "omniscient",
    battle_key: "battle-1",
    diffculities: 4,
    controlled_actor_id: 12,
    enemy_actor_id: 31,
    side: "attacker",
    turn: 1,
    controlled: {
      name: "张辽", hp: 90, soldiers: 1200, tactic_point: 10,
      units: [
        { type: "将", hp: 400, order: "待机" },
        { type: "骑", hp: 300, order: "前进" },
        { type: "弓", hp: 250, order: "待机" },
        { type: "步", hp: 250, order: "前进" },
      ],
    },
    enemy: {
      name: "高顺", hp: 88, soldiers: 900, tactic_point: 8,
      units: [
        { type: "将", hp: 350, order: "待机" },
        { type: "骑", hp: 300, order: "前进" },
        { type: "弓", hp: 250, order: "待机" },
      ],
    },
    legal_tactics: [{ name: "咒缚", cost: 3 }, { name: "强弩", cost: 7 }],
    ...over,
  };
}

function result(seq: number, req: BattleRequest): Record<string, unknown> {
  return {
    seq, ok: true, outcome: "执行完成", turn: req.turn,
    controlled: req.controlled, enemy: req.enemy, legal_tactics: req.legal_tactics,
  };
}

test.beforeEach(() => { battleStore.clear(); traceStore.clear(); });

test("白兵战工具表恰好 4 个，与战争场景工具完全不同", () => {
  const req = battleReq();
  const s = new BattleSession("b", req, 30000);
  const { tools } = buildBattleTools({ turn: req.turn, controlled: req.controlled, enemy: req.enemy, legal_tactics: req.legal_tactics }, s, {
    max_turns: 6, max_tool_calls: 12, max_tokens: 1024, idle_timeout_ms: 30000,
  });
  assert.deepEqual(tools.map((t) => t.name), [...BATTLE_TOOL_NAMES]);
  // 不得混入战争场景的工具
  for (const forbidden of ["move", "attack", "stratagem", "retreat", "end", "list_legal_actions", "read", "bash"]) {
    assert.ok(!tools.some((t) => t.name === forbidden), `白兵战工具不得包含 ${forbidden}`);
  }
});

test("set_order 每个兵种单独一条指令；end_turn 是唯一终止", async () => {
  const req = battleReq();
  const { session } = startBattle(req, { mode: "mock", config: testConfig });
  const seen: string[] = [];
  for (let i = 0; i < 10; i++) {
    const c = await session.nextCommand(2000);
    if (c.type === "end_turn") { seen.push("end_turn"); break; }
    if (c.type !== "order") break;
    seen.push(`order:${c.unit}:${c.order}`);
    session.submitResult(c.seq, result(c.seq, req));
  }
  // 4 个存活兵种各一条命令 + end_turn
  assert.deepEqual(seen, [
    "order:将:前进", "order:骑:前进", "order:弓:前进", "order:步:前进", "end_turn",
  ]);
});

test("整场战斗一个会话：end_turn 只结束本战斗回合，战斗会话继续", async () => {
  const req = battleReq();
  const { session } = startBattle(req, { mode: "mock", config: testConfig });
  let sawEndTurn = false;
  for (let i = 0; i < 10; i++) {
    const c = await session.nextCommand(2000);
    if (c.type === "end_turn") { sawEndTurn = true; break; }
    if ((c as any).type === "order") session.submitResult(c.seq, result(c.seq, req));
  }
  assert.ok(sawEndTurn, "应收到本回合的 end_turn");
  // 整场战斗仍未结束：会话继续存在，等待引擎推进到下一回合
  assert.equal(session.finished, false, "end_turn 不应结束整场战斗会话");
  session.finish("战斗结束");
  assert.equal(session.finished, true);
});

test("脚本化模型：move/attack 等战役工具不可用，只能下命令与用计", async () => {
  const model = scriptedModel((ctx) => {
    if (ctx.callIndex === 0) return calls(toolCall("inspect_battlefield", {}));
    if (ctx.callIndex === 1) return calls(toolCall("set_order", { unit: "将", order: "前进", reasoning: "主将突进" }));
    if (ctx.callIndex === 2) return calls(toolCall("set_order", { unit: "弓", order: "待机", reasoning: "弓兵压阵" }));
    if (ctx.callIndex === 3) return calls(toolCall("use_tactic", { tactic: "咒缚", reasoning: "锁住敌将" }));
    return calls(toolCall("end_turn", { reasoning: "本回合完成" }));
  });
  const req = battleReq();
  const { session } = startBattle(req, { mode: "pi", config: testConfig, runtime: model.runtime });

  const kinds: string[] = [];
  for (let i = 0; i < 10; i++) {
    const c = await session.nextCommand(3000);
    if (c.type === "idle_timeout" || c.type === "error") break;
    kinds.push(c.type === "order" ? `order:${c.unit}:${c.order}` : c.type === "tactic" ? `tactic:${c.tactic}` : "end_turn");
    if (c.type === "end_turn") break;
    session.submitResult(c.seq, result(c.seq, req));
  }
  assert.deepEqual(kinds, ["order:将:前进", "order:弓:待机", "tactic:咒缚", "end_turn"]);

  // 模型看到的工具声明必须是白兵战工具
  const firstTools = model.requests[0].tools;
  assert.deepEqual(firstTools, [...BATTLE_TOOL_NAMES]);
});

test("模型不给 end_turn：本回合等待超时，Godot 收到 idle_timeout 后回退", async () => {
  const model = scriptedModel(() => text("我在想……"));
  const { session } = startBattle(battleReq(), { mode: "pi", config: testConfig, runtime: model.runtime });
  // 模型只回文本 → agent loop 无指令产出 → 轮询到点
  const r = await session.nextCommand(300);
  assert.equal(r.type, "idle_timeout");
  assert.ok(!session.finished, "战斗会话本身不该因为一次空转就结束");
});

test("非法兵种 / 战术值不足被工具层拒绝", async () => {
  const req = battleReq({ legal_tactics: [{ name: "火矢", cost: 10 }] });
  const s = new BattleSession("b", req, 30000);
  const live = { turn: req.turn, controlled: req.controlled, enemy: req.enemy, legal_tactics: req.legal_tactics };
  const { tools } = buildBattleTools(live, s, {
    max_turns: 6, max_tool_calls: 12, max_tokens: 1024, idle_timeout_ms: 30000,
  });
  const setOrder: any = tools.find((t) => t.name === "set_order");
  await assert.rejects(
    () => setOrder.execute("c", { unit: "象", order: "前进", reasoning: "x" }),
    /没有「象」这个兵种/,
  );
  const useTactic: any = tools.find((t) => t.name === "use_tactic");
  // 战术值 10，火矢 10 → 刚好够；改成 8 后应不足
  live.controlled = { ...live.controlled, tactic_point: 8 };
  await assert.rejects(
    () => useTactic.execute("c", { tactic: "火矢", reasoning: "x" }),
    /战术值不足/,
  );
  await assert.rejects(
    () => useTactic.execute("c", { tactic: "咒缚", reasoning: "x" }),
    /不在可用计策中/,
  );
});

test("validateBattleRequest / validateBattleResult 拒绝非法结构", () => {
  assert.ok(validateBattleRequest(battleReq()));
  assert.throws(() => validateBattleRequest({ ...battleReq(), side: "flank" }), /side must be/);
  assert.throws(
    () => validateBattleRequest({ ...battleReq(), controlled: { ...battleReq().controlled, units: [{ type: "船", hp: 1 }] } }),
    /unknown battle unit type/,
  );
  assert.ok(validateBattleResult({
    ok: true, outcome: "x", turn: 1, controlled: battleReq().controlled, enemy: battleReq().enemy,
  }));
  assert.throws(() => validateBattleResult({ ok: true, outcome: "x" }), /turn must be a number/);
});

test("整场战斗一个会话：多战斗回合连续下命令，会话全程存活", async () => {
  const req = battleReq();
  // 用脚本化模型（按调用序动态回复）而不是 stub 固定条数脚本：
  // faux 的响应队列跨 prompt 不重置，不适合验证多回合。
  const model = scriptedModel((ctx) => {
    // 每回合 4 个存活兵种各一条 set_order，然后 end_turn
    const slot = ctx.callIndex % 5;
    if (slot < 4) {
      const types = ["将", "骑", "弓", "步"] as const;
      return calls(toolCall("set_order", { unit: types[slot], order: "前进", reasoning: `t${slot}` }));
    }
    return calls(toolCall("end_turn", { reasoning: "本回合完成" }));
  });
  const { session } = startBattle(req, { mode: "pi", config: testConfig, runtime: model.runtime });

  for (const turn of [1, 2, 3]) {
    if (turn > 1) {
      req.turn = turn;
      session.resumeNextTurn();
      await new Promise((r) => setTimeout(r, 100));
    }
    let sawEnd = false;
    for (let i = 0; i < 8; i++) {
      const c = await session.nextCommand(4000);
      if (c.type === "idle_timeout" || c.type === "error") break;
      if (c.type === "end_turn") { sawEnd = true; break; }
      if (c.type === "order") session.submitResult(c.seq, result(c.seq, req));
    }
    assert.ok(sawEnd, `第 ${turn} 战斗回合应以 end_turn 结束`);
    assert.equal(session.finished, false, `第 ${turn} 回合后整场战斗会话应继续`);
  }
  session.finish("战斗结束");
  assert.equal(session.finished, true);
});

test("resume 信号早到不会丢失（粘性标志）", async () => {
  const req = battleReq();
  const { session } = startBattle(req, { mode: "mock", config: testConfig });
  // 引擎比 agent loop 先推进到下一回合
  session.resumeNextTurn();
  const more = await session.waitForNextTurn(500);
  assert.equal(more, true, "早到的 resume 应被 waitForNextTurn 消费");
  session.finish("x");
});
