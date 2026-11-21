import test from "node:test";
import assert from "node:assert/strict";
import { validateTurnRequest, validateAction, validateToolResult, ValidationError } from "../src/validate.ts";
import { budgetFor } from "../src/config.ts";
import { sampleRequest } from "./fixture.ts";
import type { TurnRequest } from "../src/types.ts";

const budget = budgetFor(3);
const live = (over: Partial<{ controlled_vstate_id: number; units: any[]; legal_actions: any[] }> = {}) => {
  const req = sampleRequest();
  return {
    controlled_vstate_id: req.controlled_vstate_id,
    units: req.units,
    legal_actions: req.legal_actions,
    ...over,
  };
};

test("validateTurnRequest 接受合法全知请求", () => {
  const req = validateTurnRequest(sampleRequest());
  assert.equal(req.visibility, "omniscient");
  assert.equal(req.legal_actions.length, 4);
});

test("validateTurnRequest 拒绝非全知 / 缺字段 / 重复 id / 未知 tool", () => {
  assert.throws(() => validateTurnRequest({ ...sampleRequest(), visibility: "partial" }), ValidationError);
  assert.throws(() => validateTurnRequest({ ...sampleRequest(), legal_actions: [] }), ValidationError);
  assert.throws(
    () => validateTurnRequest({ ...sampleRequest(), legal_actions: [{ id: "x", tool: "move", actor: 12 }, { id: "x", tool: "end", actor: 12 }] }),
    ValidationError,
  );
  assert.throws(
    () => validateTurnRequest({ ...sampleRequest(), legal_actions: [{ id: "x", tool: "teleport", actor: 12 }] }),
    ValidationError,
  );
});

test("validateToolResult 接受合法执行结果，拒绝缺字段", () => {
  const ok = validateToolResult({
    ok: true, outcome: "移动完成",
    units: sampleRequest().units, legal_actions: sampleRequest().legal_actions,
  });
  assert.equal(ok.ok, true);
  assert.throws(() => validateToolResult({ ok: true, units: [], legal_actions: [] }), /outcome/);
  assert.throws(() => validateToolResult({ ok: "yes", outcome: "x", units: [], legal_actions: [] }), /ok must be boolean/);
  assert.throws(
    () => validateToolResult({ ok: true, outcome: "x", units: "nope", legal_actions: [] }),
    /units must be an array/,
  );
});

test("validateAction 接受合法动作并返回副本（move 已不走此路径）", () => {
  const action = validateAction("a1", live(), budget);
  assert.equal(action.id, "a1");
  assert.equal(action.tool, "attack");
  assert.equal(action.target, 31);
  assert.notEqual(action, sampleRequest().legal_actions[0], "必须返回副本");
  // move 已由 LLM 直接给 path，不再经 legal_actions 查找
  assert.throws(() => validateAction("m3", live(), budget), /unknown action id/);
});

test("validateAction 拒绝未知 id / 非受控武将 / 禁用武将", () => {
  assert.throws(() => validateAction("nope", live(), budget), /unknown action id/);
  assert.throws(() => validateAction(undefined, live(), budget), /non-empty string/);

  const req = sampleRequest();
  const enemy: TurnRequest = {
    ...req,
    legal_actions: [...req.legal_actions, { id: "x1", tool: "end", actor: 31, cost: {} }],
  };
  assert.throws(
    () => validateAction("x1", live({ legal_actions: enemy.legal_actions }), budget),
    /not controlled by vstate/,
  );

  const disabled = req.units.map((u) => (u.id === 12 ? { ...u, disabled: true } : u));
  assert.throws(() => validateAction("a1", live({ units: disabled }), budget), /disabled/);
});

test("validateAction 拒绝超出机动力 / 点数的动作", () => {
  const req = sampleRequest();
  const poorAp = req.units.map((u) => (u.id === 12 ? { ...u, ap: 0 } : u));
  assert.throws(() => validateAction("a1", live({ units: poorAp }), budget), /exceeds action_point/);

  // 计策消耗取引擎真值（火计 6 点），不足即拒
  const poorStratagemAp = req.units.map((u) => (u.id === 12 ? { ...u, ap: 5 } : u));
  assert.throws(
    () => validateAction("s7", live({ units: poorStratagemAp }), budget),
    /exceeds action_point/,
  );

  // 用计不扣 poker：poker=0 仍能放火计
  const noPoker = req.units.map((u) => (u.id === 12 ? { ...u, poker: 0 } : u));
  assert.equal(validateAction("s7", live({ units: noPoker }), budget).tool, "stratagem");
});

test("validateTurnRequest 接受缺 side / 缺 economy.enemy 的旧请求体", () => {
  const old = sampleRequest();
  delete (old as any).side;
  delete (old as any).economy.enemy;
  assert.equal(validateTurnRequest(old).visibility, "omniscient");
});

test("validateToolResult 原样透传含 enemy 的 economy", () => {
  const r = validateToolResult({
    ok: true, outcome: "ok", units: [], legal_actions: [],
    economy: { rice: 400, enemy: { rice: 300, money: 900 } },
  });
  assert.deepEqual((r.economy as any).enemy, { rice: 300, money: 900 });
});

test("validateTurnRequest 拒绝非法 side", () => {
  assert.throws(
    () => validateTurnRequest({ ...sampleRequest(), side: "neutral" }),
    ValidationError,
  );
});
