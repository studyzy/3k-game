import test from "node:test";
import assert from "node:assert/strict";
import { parseConfig } from "../src/config.ts";

test("非法数值配置回退默认值", () => {
  const cfg = parseConfig([], { SAVE_MAX_MB: "abc", SAVE_TOTAL_MB: "0", SAVE_TTL_DAYS: "-3" });
  assert.equal(cfg.saveMaxMb, 32);
  assert.equal(cfg.saveTotalMb, 2048);
  assert.equal(cfg.saveTtlDays, 365);
});

test("合法数值配置生效", () => {
  const cfg = parseConfig([], { SAVE_MAX_MB: "8" });
  assert.equal(cfg.saveMaxMb, 8);
});