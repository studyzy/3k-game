// Godot 侧脚本静态校验：无法在本机跑 Godot 3.5.3（PATH 上只有 4.7.2），
// 因此至少验证新脚本引用的项目符号、flow 名与继承目标都真实存在。
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const bwdl = path.join(repo, "bwdl");
const aiDir = path.join(bwdl, "packed/sgz_script/war/AI");

const NEW_FILES = [
  "AIHttpClient.gd",
  "StateProjection.gd",
  "ActionValidator.gd",
  "War_AI_behavior_llm.gd",
];

function walk(dir: string, out: string[] = []): string[] {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === ".godot" || entry.name === "build") continue;
      walk(p, out);
    } else if (entry.name.endsWith(".gd")) {
      out.push(p);
    }
  }
  return out;
}

const allGd = [
  ...walk(path.join(bwdl, "script")),
  ...walk(path.join(bwdl, "packed/sgz_script")),
  ...walk(path.join(bwdl, "windows")),
  ...walk(path.join(bwdl, "scene")),
];
const allSource = allGd.map((p) => fs.readFileSync(p, "utf8")).join("\n");

const declared = new Set<string>();
for (const m of allSource.matchAll(/\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/g)) declared.add(m[1]);
for (const m of allSource.matchAll(/\bvar\s+([A-Za-z_][A-Za-z0-9_]*)/g)) declared.add(m[1]);
for (const m of allSource.matchAll(/\bconst\s+([A-Za-z_][A-Za-z0-9_]*)/g)) declared.add(m[1]);
for (const m of allSource.matchAll(/\bsignal\s+([A-Za-z_][A-Za-z0-9_]*)/g)) declared.add(m[1]);

const PROJECT_SINGLETONS = [
  "DataManager", "Global", "FlowManager", "StaticManager", "SceneManager",
  "SkillHelper", "ActorHelper", "LoadControl", "AutoLoad", "EndlessGame", "OrderHistory",
];

// 引擎内置方法（Node / Object 等），不在项目源码里声明
const ENGINE_BUILTINS = new Set([
  "get_tree", "get_node", "add_child", "has_method", "call", "connect",
  "queue_free", "get_parent", "set_process", "is_inside_tree",
]);

test("4 个新脚本与 AI_control.gd 修改均存在", () => {
  for (const f of NEW_FILES) assert.ok(fs.existsSync(path.join(aiDir, f)), `缺少 ${f}`);
  const ctrl = fs.readFileSync(path.join(bwdl, "packed/sgz_script/war/AI_control.gd"), "utf8");
  assert.match(ctrl, /War_AI_behavior_llm\.gd/);
  assert.match(ctrl, /修改：AI Agent 接入/);
});

test("新脚本引用的项目单例成员都在仓库中声明", () => {
  const missing: string[] = [];
  for (const f of NEW_FILES) {
    const src = fs.readFileSync(path.join(aiDir, f), "utf8");
    for (const singleton of PROJECT_SINGLETONS) {
      const re = new RegExp(`\\b${singleton}\\.([A-Za-z_][A-Za-z0-9_]*)`, "g");
      for (const m of src.matchAll(re)) {
        if (!declared.has(m[1]) && !ENGINE_BUILTINS.has(m[1])) {
          missing.push(`${f}: ${singleton}.${m[1]}`);
        }
      }
    }
  }
  assert.deepEqual(missing, [], `未声明的引用：\n${missing.join("\n")}`);
});

test("继承目标、父类动作函数与 flow 绑定都存在", () => {
  const llm = fs.readFileSync(path.join(aiDir, "War_AI_behavior_llm.gd"), "utf8");
  assert.match(llm, /extends "War_AI_behavior_new\.gd"/);
  assert.ok(fs.existsSync(path.join(aiDir, "War_AI_behavior_new.gd")));
  assert.ok(fs.existsSync(path.join(aiDir, "War_AI_behavior.gd")));
  for (const fn of ["_move", "_attack", "_strategem", "_retreat", "_end_action", "next_behavior_actor_round_robin"]) {
    assert.ok(declared.has(fn), `父类缺少 ${fn}`);
  }
  for (const flow of ["AI_before_ready", "AI_ready", "AI_end", "AI_turn_start"]) {
    assert.ok(allSource.includes(`bind_import_flow("${flow}"`), `flow ${flow} 未绑定`);
  }
});

test("War_AI_behavior_llm.gd 实现全部 wab 接口方法", () => {
  const llm = fs.readFileSync(path.join(aiDir, "War_AI_behavior_llm.gd"), "utf8");
  for (const fn of ["turn_start", "next_behavior_actor", "behavior", "AI_end"]) {
    assert.match(llm, new RegExp(`\\bfunc\\s+${fn}\\s*\\(`), `缺少 wab.${fn}`);
  }
  // 不覆盖 _init()：父类 War_AI_behavior.gd:_init() 必须执行以绑定 flow
  assert.doesNotMatch(llm, /\bfunc\s+_init\s*\(/);
});

test("新增脚本均标注「新增：AI Agent 接入」，修改点已标注", () => {
  for (const f of NEW_FILES) {
    const src = fs.readFileSync(path.join(aiDir, f), "utf8");
    assert.match(src, /新增：AI Agent 接入/);
  }
});

test("启用方式：只有「大模型」难度才连 Agent，不新增 diffculities 档位", () => {
  const ctrl = fs.readFileSync(path.join(bwdl, "packed/sgz_script/war/AI_control.gd"), "utf8");
  assert.match(ctrl, /if DataManager\.ai_agent_mode:/);
  assert.doesNotMatch(ctrl, /K3G_AI_MODE|ai=auto|ai=remote|JavaScript\.eval/);

  const titleGd = fs.readFileSync(path.join(bwdl, "scene/scene_title/scene_title.gd"), "utf8");
  assert.match(titleGd, /AI_AGENT_DIFFICULTY_NAME = "大模型"/);
  assert.match(titleGd, /AI_AGENT_DIFFICULTY_LEVEL = 4/);
  assert.match(titleGd, /DataManager\.ai_agent_mode = is_ai_agent/);

  const titleTscn = fs.readFileSync(path.join(bwdl, "scene/scene_title/scene_title.tscn"), "utf8");
  assert.match(titleTscn, /items = \[ "简单", "困难", "究极", "挑战", "大模型" \]/);
  assert.match(titleTscn, /margin_bottom = 527\.0/);

  const dm = fs.readFileSync(path.join(bwdl, "script/Data_Manager.gd"), "utf8");
  assert.match(dm, /var ai_agent_mode: bool = false/);
  assert.match(dm, /save_dit\["ai_agent_mode"\] = ai_agent_mode/);
  assert.match(dm, /ai_agent_mode = bool\(load_dit\["ai_agent_mode"\]\)/);

  // 既有难度数组仍是 0..4，未被扩成第 5 档
  const sm = fs.readFileSync(path.join(bwdl, "script/Static_Manager.gd"), "utf8");
  assert.match(sm, /DIFFICULTY_NAMES = \["简单", "普通", "困难", "究极", "挑战"\]/);
});
