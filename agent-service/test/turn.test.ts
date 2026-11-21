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
import { buildTools, TOOL_NAMES, ACT_TOOL_NAMES } from "../src/tools.ts";
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

test("工具注册表：4 只读 + 4 动作 + end，共 9 个；无 read/write/edit/bash", () => {
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