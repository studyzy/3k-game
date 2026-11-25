// Godot 3.6.3 headless 运行时校验：强制 load() 全部 AI Agent 脚本并扫描日志。
// 未安装 Godot 3 时自动 skip（GODOT3_BIN 或 .tools/ 下二进制）。
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

const AI_SCRIPT_RE = /packed\/sgz_script\/war\/AI\/|war\/AI_control\.gd|test\/ai_agent_validate\.gd/;

test("Godot 3.6.3 headless 解析 AI Agent 脚本（无 Parse Error）", (t) => {
  if (!bin) {
    t.skip("未找到 Godot 3.6.3（设置 GODOT3_BIN 或运行 make setup）");
    return;
  }
  const r = spawnSync(
    bin,
    ["--no-window", "--path", path.join(repo, "bwdl"), "--script", "res://test/ai_agent_validate.gd"],
    { cwd: repo, encoding: "utf8", timeout: 180000, stdio: ["ignore", "pipe", "pipe"] },
  );
  const out = `${r.stdout ?? ""}\n${r.stderr ?? ""}`;

  assert.match(out, /AI_VALIDATE_RESULT=0/, `脚本 load 失败：\n${out.slice(-2000)}`);
  // 统计个数跟随 ai_agent_validate.gd 的清单，避免新增脚本时此处漏改
  const validateScript = fs.readFileSync(path.join(repo, "bwdl/test/ai_agent_validate.gd"), "utf8");
  const expected = (validateScript.match(/"res:\/\/[^"]+\.gd"/g) ?? []).length;
  const okCount = (out.match(/AI_VALIDATE OK/g) ?? []).length;
  assert.equal(okCount, expected, `期望 ${expected} 个脚本全部 load 成功，实际 ${okCount}`);

  // load() 在存在 Parse Error 时仍可能返回 GDScript 对象，因此必须扫日志。
  // 错误头行（含 Parse Error）与定位行（含脚本路径）是分开的两行，必须按块匹配：
  // 逐行过滤会同时漏掉两行（头行无路径、定位行无 Parse Error 字样）。
  const lines = out.split("\n");
  const aiParseErrors: string[] = [];
  for (let i = 0; i < lines.length; i++) {
    if (!/Parse Error/.test(lines[i])) continue;
    const block = lines.slice(i, i + 4).join("\n");
    if (AI_SCRIPT_RE.test(block)) aiParseErrors.push(block);
  }
  assert.deepEqual(aiParseErrors, [], `AI Agent 脚本存在解析错误：\n${aiParseErrors.join("\n---\n")}`);

  // 附带确认工程自带 make check 的等价命令不含 SCRIPT ERROR 解析错误
  const check = spawnSync(
    bin,
    ["--no-window", "--path", path.join(repo, "bwdl"), "--editor", "--quit"],
    { cwd: repo, encoding: "utf8", timeout: 300000, stdio: ["ignore", "pipe", "pipe"] },
  );
  const checkOut = `${check.stdout ?? ""}\n${check.stderr ?? ""}`;
  const checkParse = checkOut.split("\n").filter((line) => /SCRIPT ERROR: Parse Error/.test(line));
  assert.deepEqual(checkParse, [], `工程存在脚本解析错误：\n${checkParse.join("\n")}`);
});
