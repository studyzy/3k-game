// AI Agent 服务地址可配置性测试：
//   1) Godot 侧 resolve_ai_agent_url 的规范化与默认值
//   2) DataManager 的配置来源优先级（环境变量 > user:// 配置文件 > 平台默认）
import test from "node:test";
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const candidates = [
  process.env.GODOT3_BIN,
  path.join(repo, ".tools/Godot_v3.6.3-stable_linux_headless.64"),
].filter((v): v is string => typeof v === "string" && v.length > 0);
const bin = candidates.find((p) => fs.existsSync(p));

test("Godot resolve_ai_agent_url：规范化与平台默认", (t) => {
  if (!bin) {
    t.skip("未找到 Godot 3.6.3（设置 GODOT3_BIN）");
    return;
  }
  const r = spawnSync(
    bin,
    ["--no-window", "--path", path.join(repo, "bwdl"), "--script", "res://test/ai_agent_url_validate.gd"],
    { cwd: repo, encoding: "utf8", timeout: 120000, stdio: ["ignore", "pipe", "pipe"] },
  );
  const out = `${r.stdout ?? ""}\n${r.stderr ?? ""}`;
  assert.match(out, /URL_VALIDATE_RESULT=0/, `地址解析不符预期：\n${out.slice(-1500)}`);
});

test("DataManager 配置来源优先级：环境变量 > 配置文件", () => {
  const dm = fs.readFileSync(path.join(repo, "bwdl/script/Data_Manager.gd"), "utf8");
  const loadFn = dm.slice(dm.indexOf("func load_ai_agent_config"));
  const envAt = loadFn.indexOf("K3G_AI_AGENT_URL");
  const fileAt = loadFn.indexOf("AI_AGENT_CFG_PATH");
  assert.ok(envAt > 0, "应支持环境变量 K3G_AI_AGENT_URL");
  assert.ok(fileAt > 0, "应支持 user:// 配置文件");
  assert.ok(envAt < fileAt, "环境变量应优先于配置文件");

  // 两处场景都必须走统一解析，不得再硬编码地址
  const war = fs.readFileSync(path.join(repo, "bwdl/packed/sgz_script/war/AI/War_AI_behavior_llm.gd"), "utf8");
  const battle = fs.readFileSync(path.join(repo, "bwdl/packed/sgz_script/battle/AI/BattleAgent.gd"), "utf8");
  for (const [name, src, marker] of [
    ["战争场景", war, 'resolve_ai_agent_url("/ai/turn")'],
    ["白兵战", battle, 'resolve_ai_agent_url("/ai/battle")'],
  ] as const) {
    assert.ok(src.includes(marker), `${name} 应通过 DataManager.resolve_ai_agent_url 取地址`);
    assert.ok(!/127\.0\.0\.1:8060/.test(src), `${name} 不应再硬编码服务地址`);
  }
});
