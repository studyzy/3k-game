// 回合会话测试（服务端驱动的逐步交互）。
//
// 核心语义：一个 AI 回合 = 一个会话；LLM 可在会话内连续执行多个动作；
// 每次动作交给 Godot 执行后回传结果，服务端把最新状态喂回 LLM 继续决策；
// 只有 end 结束本回合。
import test from "node:test";
import assert from "node:assert/strict";
import { startTurn, ServiceError } from "../src/agent.ts";
import { budgetFor, BUDGETS } from "../src/config.ts";
import { TurnSession, turnStore, sessionStore } from "../src/session.ts";
import { traceStore } from "../src/trace.ts";
import { buildTools, TOOL_NAMES, ACT_TOOL_NAMES, READ_TOOL_NAMES } from "../src/tools.ts";
import { scriptedModel, calls, toolCall, text, testConfig } from "./harness.ts";
import { sampleRequest, GODOT_IDLE_TIMEOUT_MS, toolResult } from "./fixture.ts";

const HIGH = sampleRequest({ diffculities: 4, session_id: "turn-high" });

function fresh() {
  turnStore.clear();
  sessionStore.clear();
  traceStore.clear();
}

/** 用脚本化模型开一个会话，返回会话与模型记录器。 */
function openWith(script: Parameters<typeof scriptedModel>[0], req = HIGH) {
  const model = scriptedModel(script);
  const { session, budget } = startTurn(req, { mode: "pi", config: testConfig, runtime: model.runtime });
  return { session, budget, model };
}

/**
 * 取会话产出的下一个动作（绕过 HTTP，直接驱动 TurnSession）。
 * 中间进度只用于界面展示，这里跳过；超时/重试/结束等其它响应原样返回。
 */
async function takeAction(session: TurnSession, waitMs = 3000) {
  for (let i = 0; i < 20; i++) {
    const r = await session.nextAction(waitMs);
    if (r.type !== "progress") return r;
  }
  throw new Error("会话持续返回进度，未产出动作");
}

test.beforeEach(fresh);

test("工具注册表：5 只读 + 4 动作 + end，共 10 个；无 read/write/edit/bash", () => {
  const req = sampleRequest();
  const session = new TurnSession("t", req, GODOT_IDLE_TIMEOUT_MS);
  const live = {
    units: req.units, terrain: req.terrain, economy: req.economy, legal_actions: req.legal_actions,
  };
  const { tools } = buildTools(live, session, budgetFor(3));
  assert.deepEqual(tools.map((t) => t.name), [...TOOL_NAMES]);
  for (const forbidden of ["read", "write", "edit", "bash", "submit_plan"]) {
    assert.ok(!tools.some((t) => t.name === forbidden), `工具表不得包含 ${forbidden}`);
  }
});

test("end 是唯一终止工具；动作工具不终止循环", () => {
  const req = sampleRequest();
  const session = new TurnSession("t", req, GODOT_IDLE_TIMEOUT_MS);
  const live = {
    units: req.units, terrain: req.terrain, economy: req.economy, legal_actions: req.legal_actions,
  };
  const { tools } = buildTools(live, session, budgetFor(3));
  const endTool = tools.find((t) => t.name === "end")!;
  // end 的工具定义参数里只有 reason
  assert.deepEqual(Object.keys(endTool.parameters.properties ?? {}), ["reason"]);
  // 动作工具在 ACT_TOOL_NAMES 内，end 不在
  assert.ok(!(ACT_TOOL_NAMES as readonly string[]).includes("end"));
});

test("会话内可以连续执行多个动作（一回合一个会话）", async () => {
  let pollCount = 0;
  const { session } = openWith((ctx) => {
    // 第 0 轮读合法动作，之后每次执行一个动作，最后 end
    if (ctx.callIndex === 0) return calls(toolCall("list_legal_actions", {}));
    if (ctx.callIndex === 1) return toolCallMove();
    if (ctx.callIndex === 2) return toolCallAttack();
    return calls(toolCall("end", { reason: "都动完了" }));
  });

  // 动作 1
  const a1 = await takeAction(session);
  assert.equal(a1.type, "action");
  session.submitResult(a1.action.seq, toolResult(a1.action.seq, a1.action.action));

  // 动作 2（同一个会话内，没有重新开会话）
  const a2 = await takeAction(session);
  assert.equal(a2.type, "action");
  assert.notEqual(a2.action.seq, a1.action.seq);
  session.submitResult(a2.action.seq, toolResult(a2.action.seq, a2.action.action));

  // end
  const done = await takeAction(session);
  assert.equal(done.type, "end");
  assert.equal(session.actions.length, 2);
  assert.equal(session.finished, true);
  pollCount++;
  assert.ok(pollCount >= 1);
});

function toolCallMove() {
  return calls(toolCall("move", { actor: 12, path: [[8, 15]], reasoning: "推进" }));
}
function toolCallAttack() {
  return calls(toolCall("attack", { actor: 12, target: 31, reasoning: "趁势进攻" }));
}

test("工具结果里的最新 legal_actions 会刷新，影响下一个动作的可用性", async () => {
  const { session } = openWith((ctx) => {
    if (ctx.callIndex === 0) return toolCallMove();
    // 执行后再要一次合法动作，应看到 Godot 回传的新集合
    if (ctx.callIndex === 1) return calls(toolCall("list_legal_actions", {}));
    if (ctx.callIndex === 2) {
      assert.ok(
        ctx.lastToolResults.some((t) => t.includes("attack") && t.includes('"target":31')),
        `模型应看到刷新后的合法动作，实际：${ctx.lastToolResults.join("|").slice(0, 300)}`,
      );
      return calls(toolCall("end", { reason: "只剩这一手" }));
    }
    return calls(toolCall("end", { reason: "兜底" }));
  });

  const a1 = await takeAction(session);
  assert.equal(a1.type, "action");
  session.submitResult(a1.action.seq, {
    seq: a1.action.seq,
    ok: true,
    outcome: "移动完成",
    units: sampleRequest().units,
    legal_actions: [{ id: "a9", tool: "attack", actor: 12, target: 31, cost: { ap: 4 } }],
  });

  const done = await takeAction(session);
  assert.equal(done.type, "end");
});

test("动作结果只回变化的单位与最小字段，不再重发全部武将档案", async () => {
  const { session } = openWith((ctx) => {
    if (ctx.callIndex === 0) return toolCallMove();
    if (ctx.callIndex === 1) {
      const joined = ctx.lastToolResults.join("\n");
      assert.ok(!joined.includes("黄鬃"), "静态装备不该重复回传");
      assert.ok(!joined.includes("attrs"), "属性不该重复回传");
      assert.ok(joined.includes('"ap":13') || joined.includes('"ap": 13') || joined.includes("13"), "变化的机动力要回传");
      return calls(toolCall("end", { reason: "看完" }));
    }
    return calls(toolCall("end", { reason: "兜底" }));
  });

  const a1 = await takeAction(session);
  assert.equal(a1.type, "action");
  const moved = sampleRequest().units.map((u) => (u.id === 12 ? { ...u, pos: [8, 15], ap: 13 } : u));
  session.submitResult(a1.action.seq, {
    seq: a1.action.seq,
    ok: true,
    outcome: "移动完成",
    units: moved,
    legal_actions: [{ id: "a9", tool: "attack", actor: 12, target: 31, cost: { ap: 4 } }],
  });

  const done = await takeAction(session);
  assert.equal(done.type, "end");
});

test("用计结果拼成中文：命中/失败 + 每个受影响武将的变化与当前值", async () => {
  const { session } = openWith((ctx) => {
    if (ctx.callIndex === 0) {
      return calls(toolCall("stratagem", { actor: 12, target: 31, skill: "火计", reasoning: "【模式:磨盘】削兵" }));
    }
    if (ctx.callIndex === 1) {
      const joined = ctx.lastToolResults.join("\n");
      // 紧凑 JSON：success + result 数组，键全英文
      assert.match(joined, /"success":true/);
      assert.match(joined, /"name":"曹操"/);
      assert.match(joined, /"effect":"兵力下降124"/);
      // 兵力/体力/状态取回传 units 里的最新值（样本曹操 soldiers 900、hp 50、status 迟滞:3）
      assert.match(joined, /"currentStatus":"士兵900、体力50、状态迟滞:3"/);
      assert.ok(!joined.includes('"units"'), "用计结果不该再回 units 数组");
      return calls(toolCall("end", { reason: "打完" }));
    }
    return calls(toolCall("end", { reason: "兜底" }));
  });

  const a1 = await takeAction(session);
  assert.equal(a1.type, "action", JSON.stringify(a1));
  session.submitResult(a1.action.seq, {
    seq: a1.action.seq,
    ok: true,
    outcome: "用计火计→#31",
    units: sampleRequest().units,
    legal_actions: [],
    stratagem: {
      ok: true,
      name: "火计",
      caster: "张飞",
      effects: [{ id: 31, name: "曹操", note: "兵力下降124", soldiers: 776, hp: 50, status: ["迟滞:2"] }],
    },
  } as never);

  const done = await takeAction(session);
  assert.equal(done.type, "end");
});

test("用计失败时只回一句失败，不回单位列表", async () => {
  const { session } = openWith((ctx) => {
    if (ctx.callIndex === 0) {
      return calls(toolCall("stratagem", { actor: 12, target: 31, skill: "火计", reasoning: "【模式:磨盘】削兵" }));
    }
    if (ctx.callIndex === 1) {
      const joined = ctx.lastToolResults.join("\n");
      assert.match(joined, /\{"success":false\}/);
      return calls(toolCall("end", { reason: "没打中" }));
    }
    return calls(toolCall("end", { reason: "兜底" }));
  });

  const a1 = await takeAction(session);
  session.submitResult(a1.action.seq, {
    seq: a1.action.seq,
    ok: true,
    outcome: "用计火计→#31",
    units: sampleRequest().units,
    legal_actions: [],
    stratagem: { ok: false, name: "火计", caster: "张飞", effects: [] },
  } as never);

  const done = await takeAction(session);
  assert.equal(done.type, "end");
});

test("list_legal_actions 只列我方、不含 end、不带内部 id", async () => {
  const { session } = openWith((ctx) => {
    if (ctx.callIndex === 0) return calls(toolCall("list_legal_actions", {}));
    if (ctx.callIndex === 1) {
      const joined = ctx.lastToolResults.join("\n");
      assert.ok(joined.includes("attack"), "应列出我方攻击");
      assert.ok(!joined.includes('"tool":"end"'), "end 不是武将动作，不应出现在清单");
      assert.ok(!joined.includes('"id"'), "id 是服务端句柄，不暴露给模型");
      return calls(toolCall("end", { reason: "看完" }));
    }
    return calls(toolCall("end", { reason: "x" }));
  });
  const r = await takeAction(session);
  assert.equal(r.type, "end");
});

test("猜错目标时返回该武将当前可选的动作，模型可在会话内自纠", async () => {
  let hint = "";
  const { session } = openWith((ctx) => {
    if (ctx.callIndex === 0) {
      return calls(toolCall("stratagem", { actor: 12, target: 99, skill: "火计", reasoning: "打 99" }));
    }
    if (ctx.callIndex === 1) {
      hint = ctx.lastToolResults.join("\n");
      return calls(toolCall("end", { reason: "改打 31" }));
    }
    return calls(toolCall("end", { reason: "结束" }));
  });

  const r = await takeAction(session);
  assert.equal(r.type, "end");
  assert.ok(hint.includes("当前可选"), `应返回候选清单，实际：${hint.slice(0, 300)}`);
  assert.ok(hint.includes("stratagem 火计"), "候选里应有该武将能用的计策");
  assert.ok(hint.includes("attack"), "候选里应有攻击目标");
});

test("模型只回文本不给动作：会话以 error 结束（不能伪造成回合正常结束）", async () => {
  const { session } = openWith(() => text("我在想……"));
  const r = await takeAction(session, 500);
  assert.equal(r.type, "error", "模型既没动作也没 end，必须走失败路径");
});

test("LLM 卡死（不返回任何东西）：轮询到点返回 idle_timeout", async () => {
  // 模型永不 resolve，模拟端点挂起
  const hanging = scriptedModel(() => new Promise(() => {}) as never);
  const { session } = startTurn(HIGH, { mode: "pi", config: testConfig, runtime: hanging.runtime });
  const r = await takeAction(session, 150);
  assert.equal(r.type, "idle_timeout", "单次轮询到点无动作应返回 idle_timeout");
  // 会话级空闲预算仍是完整 30s（轮询超时 ≠ 会话超时）
  assert.ok(session.idleRemaining() > 0, "单次轮询到点不应消耗整个会话的空闲预算");
});

test("会话空闲超时时钟在 Godot 回传结果后重置", async () => {
  const { session } = openWith((ctx) => (ctx.callIndex === 0 ? toolCallMove() : calls(toolCall("end", { reason: "x" }))));
  const a1 = await takeAction(session);
  assert.equal(a1.type, "action");
  const before = session.idleRemaining();
  await new Promise((r) => setTimeout(r, 50));
  session.submitResult(a1.action.seq, toolResult(a1.action.seq, a1.action.action));
  const after = session.idleRemaining();
  assert.ok(after >= before, `回传结果后空闲计时应重置：before=${before} after=${after}`);
});

test("反应式：Godot 提前回传的结果按 seq 精确匹配，不会串线", async () => {
  const { session } = openWith((ctx) => {
    if (ctx.callIndex === 0) return toolCallMove();
    if (ctx.callIndex === 1) return toolCallAttack();
    return calls(toolCall("end", { reason: "x" }));
  });
  const a1 = await takeAction(session);
  assert.equal(a1.type, "action");
  // 用错误的 seq 回传：应被当作早到结果暂存，不唤醒 a1
  session.submitResult(a1.action.seq + 99, toolResult(a1.action.seq + 99, null));
  // 正确 seq 才唤醒
  session.submitResult(a1.action.seq, toolResult(a1.action.seq, a1.action.action));
  const a2 = await takeAction(session);
  assert.equal(a2.type, "action");
  assert.equal(a2.action.seq, a1.action.seq + 1);
});

test("max_actions 预算：超出后 loop 终止，会话结束", async () => {
  const req = sampleRequest({ diffculities: 4, budget: { max_actions: 2 } });
  const { session } = openWith(
    (ctx) => (ctx.callIndex < 10 ? toolCallMove() : calls(toolCall("end", { reason: "x" }))),
    req,
  );
  for (let i = 0; i < 2; i++) {
    const r = await takeAction(session);
    assert.equal(r.type, "action");
    session.submitResult(r.action.seq, toolResult(r.action.seq, r.action.action));
  }
  // 预算耗尽：loop 被截断，没有 end → 失败路径
  const done = await takeAction(session);
  assert.ok(done.type === "error" || done.type === "end", `预算耗尽应终止会话，实际 ${done.type}`);
  assert.ok(session.actions.length <= 2, `实际执行 ${session.actions.length} 个动作，超出预算`);
});

test("只读工具不占 max_tool_calls：批量侦察后仍能执行动作", async () => {
  // 复现真实战局：模型先一口气 inspect 十几个单位，预算不应被侦察吃光。
  const req = sampleRequest({ diffculities: 4, budget: { max_tool_calls: 2 } });
  const { session } = openWith((ctx) => {
    if (ctx.callIndex === 0) {
      return calls(...Array.from({ length: 12 }, () => toolCall("list_legal_actions", {})));
    }
    if (ctx.callIndex === 1) return toolCallMove();
    return calls(toolCall("end", { reason: "都动完了" }));
  }, req);

  const a1 = await takeAction(session);
  assert.equal(a1.type, "action", "只读调用不应耗尽工具预算");
  session.submitResult(a1.action.seq, toolResult(a1.action.seq, a1.action.action));
  const done = await takeAction(session);
  assert.equal(done.type, "end");
  assert.equal(session.actions.length, 1);
});

test("只读工具调用会重置空闲计时（Agent 还在查询不算掉线）", async () => {
  // 模型先想 120ms 再查一次（空闲预算 200ms）：查询必须把剩余时间重置回满，
  // 否则 Godot 会把「正在侦察」误判成「Agent 已死」。
  const req = sampleRequest({ diffculities: 4, budget: { idle_timeout_ms: 200 } });
  let observed = -1;
  const holder: { session?: TurnSession } = {};
  const { session } = openWith(async (ctx) => {
    if (ctx.callIndex === 0) {
      await new Promise((r) => setTimeout(r, 120));
      return calls(toolCall("list_legal_actions", {}));
    }
    if (ctx.callIndex === 1) {
      observed = holder.session!.idleRemaining();
      return toolCallMove();
    }
    return calls(toolCall("end", { reason: "x" }));
  }, req);
  holder.session = session;

  const a1 = await takeAction(session, 3000);
  assert.equal(a1.type, "action", "只读工具调用后不应被判空闲超时");
  assert.ok(observed >= 150, `只读工具调用应重置空闲计时，实际剩余 ${observed}ms`);
  session.submitResult(a1.action.seq, toolResult(a1.action.seq, a1.action.action));
  const done = await takeAction(session, 3000);
  assert.equal(done.type, "end");
});

test("动作工具仍计入 max_tool_calls：超出后 loop 终止", async () => {
  const req = sampleRequest({ diffculities: 4, budget: { max_tool_calls: 1 } });
  const { session } = openWith(
    (ctx) => (ctx.callIndex < 5 ? toolCallMove() : calls(toolCall("end", { reason: "x" }))),
    req,
  );
  const a1 = await takeAction(session);
  assert.equal(a1.type, "action");
  session.submitResult(a1.action.seq, toolResult(a1.action.seq, a1.action.action));
  const done = await takeAction(session);
  assert.equal(done.type, "error", "第 2 个动作超出 max_tool_calls，且未调用 end，应走失败路径");
  assert.equal(session.actions.length, 1);
});

test("模型报错：会话以 error 结束，挂起的工具调用被拒绝", async () => {
  const model = scriptedModel(() => text("x"), { throwOnCall: 0 });
  const { session } = startTurn(HIGH, { mode: "pi", config: testConfig, runtime: model.runtime });
  const r = await takeAction(session, 2000);
  assert.equal(r.type, "error");
});

test("预算：空闲超时统一 30s，与 Godot 侧一致", () => {
  for (const diff of [2, 3, 4]) {
    assert.equal(BUDGETS[diff].idle_timeout_ms, GODOT_IDLE_TIMEOUT_MS, `难度 ${diff} 空闲超时不一致`);
    assert.ok(BUDGETS[diff].max_actions >= 16);
    assert.ok(BUDGETS[diff].max_turns >= 4);
  }
});
// ---------------------------------------------------------------------------
// estimate_stratagem（用计预估）：只读查询，走 ask 通道由 Godot 现算
// ---------------------------------------------------------------------------
test("estimate_stratagem：以 ask 下发查询，回答后作为工具结果喂回模型，不产生动作", async () => {
  // 先预估、再 end：按轮次脚本化模型回复
  const script = ({ callIndex }: any) => (callIndex === 0
    ? calls(toolCall("estimate_stratagem", { actor: 12, target: 31, skill: "火计" }, "e1"))
    : calls(toolCall("end", { reason: "评估完不用计" })));
  const { session } = openWith(script);

  // 进度（"预估用计 …"）先到，随后才是查询本身
  let ask: any = null;
  for (let i = 0; i < 10; i++) {
    const r = await session.nextAction(3000);
    if (r.type === "ask") { ask = r; break; }
    assert.equal(r.type, "progress", `期望 ask，实际 ${JSON.stringify(r)}`);
  }
  assert.ok(ask, "未收到用计预估查询");
  assert.equal(ask.asks[0].kind, "estimate_stratagem");
  assert.equal(ask.asks[0].actor, 12);
  assert.equal(ask.asks[0].skill, "火计");

  // Godot 回传引擎算好的预估
  assert.ok(session.submitAnswers([{ id: ask.asks[0].id, data: { ok: true, rate: 70 } }]));

  // 模型继续调用 end：全程没有动作被下发
  const end = await session.nextAction(3000);
  assert.equal(end.type, "end");
  assert.equal(end.reason, "评估完不用计");
  assert.equal(session.actions.length, 0);
});

test("estimate_move：下发多个目标点，回答后作为工具结果喂回模型，不产生动作", async () => {
  const script = ({ callIndex }: any) => (callIndex === 0
    ? calls(toolCall("estimate_move", { actor: 12, to: [[15, 10], [17, 8]] }, "m1"))
    : calls(toolCall("end", { reason: "算完路了" })));
  const { session } = openWith(script);

  let ask: any = null;
  for (let i = 0; i < 10; i++) {
    const r = await session.nextAction(3000);
    if (r.type === "ask") { ask = r; break; }
    assert.equal(r.type, "progress", `期望 ask，实际 ${JSON.stringify(r)}`);
  }
  assert.ok(ask, "未收到行军预估查询");
  const q = ask.asks[0];
  assert.equal(q.kind, "estimate_move");
  assert.equal(q.actor, 12);
  assert.deepEqual(q.to, [[15, 10], [17, 8]]);

  // Godot 算完回传（同 estimate_stratagem，只有 summary 文字会被模型读到）
  assert.ok(session.submitAnswers([{ id: q.id, data: { ok: true, summary: "荀谌 → [15,10] 5 格，18 机（剩 19 机，够）" } }]));

  const end = await session.nextAction(3000);
  assert.equal(end.type, "end");
  assert.equal(session.actions.length, 0);
});

test("estimate_moves：多个武将一次查询合并成一趟 ask，逐将结论按序回给模型", async () => {
  const script = ({ callIndex }: any) => (callIndex === 0
    ? calls(toolCall("estimate_moves", { actors: [12, 13], to: [[15, 10], [19, 10]] }, "m1"))
    : calls(toolCall("end", { reason: "算完敌情" })));
  const { session } = openWith(script);

  let ask: any = null;
  for (let i = 0; i < 10; i++) {
    const r = await session.nextAction(3000);
    if (r.type === "ask") { ask = r; break; }
    assert.equal(r.type, "progress", `期望 ask，实际 ${JSON.stringify(r)}`);
  }
  assert.ok(ask, "未收到批量预估查询");
  // 两个武将合并成同一批下发，一次长轮询拿全
  assert.equal(ask.asks.length, 2);
  assert.deepEqual(ask.asks.map((q: any) => q.actor), [12, 13]);
  assert.equal(ask.asks[0].free, true, "批量预估忽略阻挡，走 free 口径");
  assert.deepEqual(ask.asks[0].to, [[15, 10], [19, 10]]);

  assert.ok(session.submitAnswers([
    { id: ask.asks[0].id, data: { ok: true, summary: "吕布 → [15,10] 7 格，26 机（下轮可动 25 机，不够）" } },
    { id: ask.asks[1].id, data: { ok: true, summary: "高顺 → [19,10] 9 格，33 机（下轮可动 22 机，不够）" } },
  ]));

  const end = await session.nextAction(3000);
  assert.equal(end.type, "end");
  assert.equal(session.actions.length, 0);
});

test("estimate_stratagem：响应后到的回答也能对上（earlyAnswers）", async () => {
  const session = new TurnSession("t", sampleRequest(), GODOT_IDLE_TIMEOUT_MS);
  const pending = session.askEstimate(12, 31, "火计");
  const ask = await session.nextAction(1000);
  assert.equal(ask.type, "ask");
  // Godot 先回、服务端后登记
  session.submitAnswers([{ id: ask.asks[0].id + 100, data: { ok: true, rate: 1 } }]);
  session.submitAnswers([{ id: ask.asks[0].id, data: { ok: true, rate: 65, raw_rate: 60 } }]);
  const data = await pending;
  assert.equal(data.rate, 65);
});

test("estimate_stratagem 不占动作预算（只读）", async () => {
  assert.ok((READ_TOOL_NAMES as readonly string[]).includes("estimate_stratagem"));
  assert.ok(!(ACT_TOOL_NAMES as readonly string[]).includes("estimate_stratagem"));
});

// 系统提示词的事实锚点：防止重构时把引擎规则改错。
// 每条都对应一处曾被写错、或容易被误读的引擎行为，改动前先回查 bwdl/ 源码。
test("SYSTEM_PROMPT 结构与易错规则锚点", async () => {
  const { SYSTEM_PROMPT } = await import("../src/agent.ts");
  // trace.test 依赖这句判定「这是战争提示词」
  assert.match(SYSTEM_PROMPT, /战场指挥官/);
  // 计策射程逐计不同，6 只是上限；模型看不到射程字段，必须查 legal_actions
  assert.match(SYSTEM_PROMPT, /射程因计而异/);
  assert.match(SYSTEM_PROMPT, /按动作结果里带回的合法动作确认/);
  // 城墙街区隔墙打不到（IWar_Attack 排除 + 城墙阻断路径），不能建议「远程隔墙消耗」
  assert.doesNotMatch(SYSTEM_PROMPT, /远程隔墙消耗/);
  // 守方站城格会被强制转弓、锁「守城门」阵（clBattleFight._get_special_units_transforms）
  assert.match(SYSTEM_PROMPT, /强制当弓箭手/);
  assert.match(SYSTEM_PROMPT, /守城门/);
  // 城墙格之间不连通，不能建议沿城墙横移
  assert.doesNotMatch(SYSTEM_PROMPT, /沿城墙横移消耗/);
  assert.match(SYSTEM_PROMPT, /不要指望「沿城墙横移」/);
  // 城门耐久等不可观测字段不得写进判定条件
  assert.match(SYSTEM_PROMPT, /看不到城门耐久/);
  assert.doesNotMatch(SYSTEM_PROMPT, /城门耐久跌破/);
  // 攻方推进只按可观测状态触发
  assert.match(SYSTEM_PROMPT, /开场兵力 × 60%/);
  // reasoning 是工具必填参数，不能与「不要输出额外解释」混为一谈
  assert.match(SYSTEM_PROMPT, /\【模式:斩首\|强攻\|磨盘\】/);
  assert.match(SYSTEM_PROMPT, /除工具参数里的 reasoning 外/);
  // 守方：主攻门判定 + 守府优先于守门 + 进城后留一人堵门
  assert.match(SYSTEM_PROMPT, /算主攻门/);
  assert.match(SYSTEM_PROMPT, /太守府的绝对优先级/);
  assert.match(SYSTEM_PROMPT, /只守主攻门/);
  assert.match(SYSTEM_PROMPT, /留 1 个有兵的武将堵住那扇门/);
  assert.match(SYSTEM_PROMPT, /站在太守府\*\*相邻格\*\*/);
  // 站位是收益而不是「移动铺垫」；走不到就别走
  assert.match(SYSTEM_PROMPT, /站位本身就是收益，不是「移动铺垫」/);
  assert.match(SYSTEM_PROMPT, /不代表不该去/);
  assert.match(SYSTEM_PROMPT, /本回合就走能走的那一段/);
  // 主攻门按公式判定
  assert.match(SYSTEM_PROMPT, /第一步：算主攻门 \+ 算「谁先到」/);
  assert.match(SYSTEM_PROMPT, /estimate_move/);
  assert.match(SYSTEM_PROMPT, /每回合都要重算，不许沿用上回合结论/);
  assert.match(SYSTEM_PROMPT, /站在非主攻门的城门格上不算守好/);
  // 已经站在错误的城门上也要改走主攻门；本回合到不了不是不出发的理由
  assert.match(SYSTEM_PROMPT, /立刻改走主攻门/);
  assert.match(SYSTEM_PROMPT, /「本回合到不了」从来不是不出发的理由/);
  assert.match(SYSTEM_PROMPT, /晚 1 天也必须去/);
  // 「不够」只表示本回合走不到，不是不用去；按天数比谁先到
  assert.match(SYSTEM_PROMPT, /比天数，不比单回合/);
  assert.match(SYSTEM_PROMPT, /「不够」不是「不用去」/);
  assert.match(SYSTEM_PROMPT, /分两天走完全正常/);
  // 站门必须是本格：斜邻/门前平地白兵战不生成城门单位
  assert.match(SYSTEM_PROMPT, /必须是 terrain_at 为「城门」的那一格/);
  assert.match(SYSTEM_PROMPT, /斜着相邻、隔一格、站在门前平地上/);
  // 主将可临时让开太守府（build_layer 独立判定，与地形无关）
  assert.match(SYSTEM_PROMPT, /太守府格可以被临时让开/);
  assert.match(SYSTEM_PROMPT, /先挪开一格/);
  // 可达路线，不按直线格数
  assert.match(SYSTEM_PROMPT, /别心算直线格数/);
  // 判敌情用批量预估一次算完，不许挨个调 estimate_move
  assert.match(SYSTEM_PROMPT, /判敌情用 estimate_moves 一次算完/);
  assert.match(SYSTEM_PROMPT, /estimate_moves\(actors=\[全部敌将\], to=\[全部城门格\]\)/);
  assert.match(SYSTEM_PROMPT, /移动被挡就重算/);
  // 预判下一轮贴上来就先占位
  assert.match(SYSTEM_PROMPT, /预判下一轮 → 本回合先把位置占好/);
  assert.match(SYSTEM_PROMPT, /宁可少放一次计，也要站好位/);
});

