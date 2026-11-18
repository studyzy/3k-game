import test from "node:test";
import assert from "node:assert/strict";
import { validateRequest, validatePlan, ValidationError } from "../src/validate.ts";
import { budgetFor } from "../src/config.ts";
import { sampleRequest } from "./fixture.ts";
import type { DecideRequest } from "../src/types.ts";

const budget = budgetFor(3);

test("validateRequest 接受合法全知请求", () => {
  const req = validateRequest(sampleRequest());
  assert.equal(req.visibility, "omniscient");
  assert.equal(req.legal_actions.length, 5);
});

test("validateRequest 拒绝非全知 / 缺字段 / 重复 id / 未知 tool", () => {
  assert.throws(() => validateRequest({ ...sampleRequest(), visibility: "partial" }), ValidationError);
  assert.throws(() => validateRequest({ ...sampleRequest(), legal_actions: [] }), ValidationError);
  assert.throws(
    () => validateRequest({ ...sampleRequest(), legal_actions: [{ id: "x", tool: "move", actor: 12 }, { id: "x", tool: "end", actor: 12 }] }),
    ValidationError,
  );
  assert.throws(
    () => validateRequest({ ...sampleRequest(), legal_actions: [{ id: "x", tool: "teleport", actor: 12 }] }),
    ValidationError,
  );
});

test("validatePlan 接受合法计划并归一化 order", () => {
  const req = sampleRequest();
  const plan = validatePlan([{ id: "m3" }, { id: "a1" }], req, budget);
  assert.deepEqual(plan, [{ id: "m3", order: 1 }, { id: "a1", order: 2 }]);
});

test("validatePlan 拒绝未知 id / 重复 id / 非受控武将 / 超预算", () => {
  const req = sampleRequest();
  assert.throws(() => validatePlan([{ id: "nope" }], req, budget), ValidationError);
  assert.throws(() => validatePlan([{ id: "m3" }, { id: "m3" }], req, budget), ValidationError);
  assert.throws(
    () => {
      const bad: DecideRequest = {
        ...req,
        legal_actions: [...req.legal_actions, { id: "x1", tool: "end", actor: 31, cost: {} }],
      };
      return validatePlan([{ id: "x1" }], bad, budget);
    },
    ValidationError,
  );
  assert.throws(
    () => {
      const poor: DecideRequest = { ...req, units: req.units.map((u) => u.id === 12 ? { ...u, ap: 1 } : u) };
      return validatePlan([{ id: "m3" }, { id: "a1" }, { id: "s7" }], poor, budget);
    },
    ValidationError,
  );
});

test("validatePlan 拒绝空计划与超长计划", () => {
  const req = sampleRequest();
  assert.throws(() => validatePlan([], req, budget), ValidationError);
  assert.throws(() => validatePlan(Array.from({ length: 40 }, () => ({ id: "e0" })), req, { ...budget, max_actions: 32 }), ValidationError);
});
