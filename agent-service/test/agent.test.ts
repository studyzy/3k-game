import test from "node:test";
import assert from "node:assert/strict";
import { startTurn, ServiceError, buildUserMessage } from "../src/agent.ts";
import { buildTools, TOOL_NAMES, ACT_TOOL_NAMES } from "../src/tools.ts";
import { budgetFor } from "../src/config.ts";
import { TurnSession } from "../src/session.ts";
import { sampleRequest, testConfig, GODOT_IDLE_TIMEOUT_MS, toolResult } from "./fixture.ts";

function sessionFor(req = sampleRequest()) {
  const s = new TurnSession("t", req, GODOT_IDLE_TIMEOUT_MS);
  const live = { units: req.units, terrain: req.terrain, economy: req.economy, legal_actions: req.legal_actions };
  return { session: s, live, tools: buildTools(live, s, budgetFor(req.diffculities)) };
}

test("startTurn 立即返回会话 id（服务端驱动，不等 LLM）", async () => {
  const { session, budget } = startTurn(sampleRequest(), { mode: "mock", config: testConfig });
  assert.ok(session.id.length > 0);
  assert.equal(budget.idle_timeout_ms, GODOT_IDLE_TIMEOUT_MS);
});

test("mock ok：产出动作后正常结束", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "ok" });
  const r = await session.nextAction(2000);
  assert.equal(r.type, "action");
  session.submitResult(r.action.seq, toolResult(r.action.seq, r.action.action));
  const done = await session.nextAction(2000);
  assert.equal(done.type, "end");
});

test("mock error：会话失败", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "error" });
  const r = await session.nextAction(2000);
  assert.equal(r.type, "error");
});

test("mock invalid：下发非法 id，供 Godot 侧校验拒绝", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "invalid" });
  const r = await session.nextAction(2000);
  assert.equal(r.type, "action");
  assert.equal(r.action.id, "__invalid__");
});

test("mock timeout：不产出任何动作（模拟 LLM 卡死）", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "mock", config: testConfig, mockCase: "timeout" });
  const r = await session.nextAction(150);
  assert.equal(r.type, "idle_timeout");
});

test("工具注册表恰好 9 个：4 只读 + 4 动作 + end；无 read/write/edit/bash", () => {
  const { tools } = sessionFor();
  assert.deepEqual(tools.tools.map((t) => t.name), [...TOOL_NAMES]);
  assert.equal(ACT_TOOL_NAMES.length, 4);
  for (const forbidden of ["read", "write", "edit", "bash", "submit_plan"]) {
    assert.ok(!tools.tools.some((t) => t.name === forbidden), `不得包含 ${forbidden}`);
  }
});

test("动作工具：move 直接用 LLM 给的 path，attack 等按 legal_actions 定位", async () => {
  const { session, tools } = sessionFor();
  const move: any = tools.tools.find((t) => t.name === "move");
  const p = move.execute("c1", { actor: 12, path: [[8, 15]], reasoning: "靠近" });
  const got = await session.nextAction(1000);
  assert.equal(got.type, "action");
  // move 不再按 legal_actions 的 id 查找，直接用路径
  assert.equal(got.action.tool, "move");
  assert.deepEqual(got.action.action.path, [[8, 15]]);

  session.submitResult(got.action.seq, toolResult(got.action.seq, got.action.action));
  const res = await p;
  // 工具结果回给模型的是结构化摘要（含 Godot 的 outcome 与最新状态）
  const body = JSON.parse((res.content[0] as any).text);
  assert.match(body.outcome, /move 执行完毕/, "应包含 Godot 回传的执行结果");
  assert.ok(Array.isArray(body.units), "应包含最新 units");
  assert.ok(Array.isArray(body.legal_actions), "应包含最新 legal_actions");

  // 缺 path / path 结构错误 → 工具层拒绝
  await assert.rejects(() => move.execute("c2", { actor: 12, reasoning: "x" }), /非空 path/);
  await assert.rejects(
    () => move.execute("c3", { actor: 12, path: [[8]], reasoning: "x" }),
    /必须是 \[x, y\]/,
  );
});

test("stub 模式：一个会话内连续执行动作后 end", async () => {
  const { session } = startTurn(sampleRequest(), { mode: "stub", config: testConfig });
  let guard = 0;
  let endSeen = false;
  while (guard++ < 10) {
    const r = await session.nextAction(3000);
    if (r.type === "end") { endSeen = true; break; }
    if (r.type === "progress") continue;
    if (r.type !== "action") break;
    session.submitResult(r.action.seq, toolResult(r.action.seq, r.action.action));
  }
  assert.ok(endSeen, `会话应以 end 结束，实际 actions=${session.actions.length}`);
  assert.ok(session.actions.length >= 1);
});

test("ServiceError 携带状态码与错误码", () => {
  const e = new ServiceError(503, "api_key_missing", "x");
  assert.equal(e.status, 503);
  assert.equal(e.code, "api_key_missing");
});

test("同一场战斗连续两轮的静态段逐字节相同", () => {
  const a = buildUserMessage(sampleRequest({ turn_key: "w2-d7-s1" }), null);
  const b = buildUserMessage(sampleRequest({ turn_key: "w2-d8-s2", memory: { note: "x" } }), { note: "x" });
  const cut = (s: string) => s.slice(0, s.indexOf("──"));
  assert.equal(cut(a), cut(b), "静态段不得随回合变化");
  assert.ok(!/turn_key|legal_actions|"units"|"memory"|"day"/.test(cut(a)), "静态段不得含动态键");
});

test("buildUserMessage 缺 side / 缺 economy.enemy 时不出现 undefined", () => {
  const req = sampleRequest();
  delete (req as any).side;
  delete (req as any).economy.enemy;
  const msg = buildUserMessage(req, null);
  assert.ok(!msg.includes("undefined"), "不得把缺失字段渲染成 undefined");
  assert.ok(msg.includes("未知"), "缺失的敌方粮草应显示为未知");
});

test("开场消息按敌我分组，动态字段在分界之后", () => {
  const msg = buildUserMessage(sampleRequest(), null);
  const cut = msg.indexOf("──");
  assert.ok(cut > 0, "必须有静态/动态分界");
  const staticPart = msg.slice(0, cut);
  const dynamicPart = msg.slice(cut);
  assert.ok(!staticPart.includes("turn_key"), "静态段不得含 turn_key");
  assert.ok(dynamicPart.includes("turn_key"), "turn_key 必须在动态段");
  assert.ok(dynamicPart.includes("legal_actions"), "legal_actions 必须在动态段");
  const enemyIdx = msg.indexOf("敌方：");
  const ownIdx = msg.indexOf("我方：");
  assert.ok(enemyIdx > cut && ownIdx > enemyIdx, "敌方/我方块必须在动态段且按顺序");
  const enemyBlock = msg.slice(enemyIdx, ownIdx);
  const ownBlock = msg.slice(ownIdx);
  assert.ok(enemyBlock.includes('"id":31'), "敌方块应含 vstate=1 的武将 31");
  assert.ok(!enemyBlock.includes('"id":12'), "敌方块不得含己方武将 12");
  assert.ok(ownBlock.includes('"id":12') && ownBlock.includes('"id":13'), "我方块应含 12/13");
  assert.ok(!ownBlock.includes('"id":31'), "我方块不得含敌方武将 31");
});

test("开场消息包含武将姓名", () => {
  const msg = buildUserMessage(sampleRequest(), null);
  assert.ok(msg.includes("张飞"), "我方武将姓名应出现在消息里");
  assert.ok(msg.includes("曹操"), "敌方武将姓名应出现在消息里");
});

test("开场消息包含武将全量属性、装备与状态", () => {
  const msg = buildUserMessage(sampleRequest(), null);
  for (const key of ["attrs", "体", "武", "知", "德", "政", "忠", "统", "胆", "hp_max", "ap_max", "level", "exp", "equips", "武器", "防具", "道具", "坐骑", "equip_briefs", "status", "terrain_at"]) {
    assert.ok(msg.includes(key), `开场消息应含 ${key}`);
  }
});

test("动作工具结果同步最新敌方粮草到摘要、live 与 inspect_economy", async () => {
  const { session, live, tools } = sessionFor();
  const move: any = tools.tools.find((t) => t.name === "move");
  const p = move.execute("c1", { actor: 12, path: [[8, 15]], reasoning: "同步敌方粮草" });
  const got = await session.nextAction(1000);
  assert.equal(got.type, "action");
  // 与开场值不同，才能验证「刷新」而不是「碰巧相同」
  const changed = {
    ...toolResult(got.action.seq, got.action.action),
    economy: { rice: 400, enemy: { rice: 250, money: 700 } },
  };
  session.submitResult(got.action.seq, changed);
  const res = await p;
  const body = JSON.parse((res.content[0] as any).text);
  assert.deepEqual(body.economy?.enemy, { rice: 250, money: 700 }, "工具结果摘要必须带最新敌方粮草");
  assert.deepEqual((live.economy as any).enemy, { rice: 250, money: 700 }, "live.economy 必须刷新");
  const econ: any = tools.tools.find((t) => t.name === "inspect_economy");
  const r = await econ.execute("c2", {});
  assert.deepEqual(JSON.parse((r.content[0] as any).text).enemy, { rice: 250, money: 700 }, "inspect_economy 必须返回最新敌方粮草");
});
