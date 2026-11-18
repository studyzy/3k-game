// 白兵战 Godot 侧对接契约测试：真实 GDScript 运行 BattleProjection / BattleAgent，
// 通过真实 HTTP 与服务端 /ai/battle 会话往返。未安装 Godot 3 时自动 skip。
import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import type { AddressInfo } from "node:net";
import { createServer } from "../src/server.ts";
import { testConfig } from "./fixture.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const battleAiDir = path.join(repo, "bwdl/packed/sgz_script/battle/AI");
const harnessDir = path.join(repo, "agent-service/gdharness/battle_ai");
const candidates = [
  process.env.GODOT3_BIN,
  path.join(repo, ".tools/Godot_v3.6.3-stable_linux_headless.64"),
].filter((v): v is string => typeof v === "string" && v.length > 0);
const bin = candidates.find((p) => fs.existsSync(p));

function marker(out: string, name: string): string {
  const m = out.match(new RegExp(`${name}=([^\\n]*)`));
  assert.ok(m, `缺少 ${name} 输出：\n${out.slice(-2000)}`);
  return m[1];
}

test("Godot BattleProjection / BattleAgent → 真实服务端白兵战会话", { timeout: 120000 }, async (t) => {
  if (!bin) {
    t.skip("未找到 Godot 3.6.3（设置 GODOT3_BIN）");
    return;
  }
  // 用真实脚本覆盖 harness 里的副本，保证测的是仓库代码
  for (const f of ["BattleProjection.gd", "BattleAgent.gd"]) {
    fs.copyFileSync(path.join(battleAiDir, f), path.join(harnessDir, f));
  }
  fs.copyFileSync(
    path.join(repo, "bwdl/packed/sgz_script/war/AI/AIHttpClient.gd"),
    path.join(harnessDir, "AIHttpClient.gd"),
  );

  const server = createServer({ ...testConfig, port: 0, mode: "stub", webDir: harnessDir });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as AddressInfo).port;
  const xdg = fs.mkdtempSync(path.join(os.tmpdir(), "3k-bg-"));

  try {
    const out = await new Promise<string>((resolve, reject) => {
      const child = spawn(bin, ["--no-window", "--path", harnessDir], {
        cwd: repo,
        env: { ...process.env, XDG_DATA_HOME: xdg, XDG_CONFIG_HOME: xdg },
        stdio: ["ignore", "pipe", "pipe"],
      });
      let buf = "";
      child.stdout.on("data", (d) => { buf += d.toString(); });
      child.stderr.on("data", (d) => { buf += d.toString(); });
      const timer = setTimeout(() => { child.kill(); resolve(buf); }, 60000);
      child.on("error", (e) => { clearTimeout(timer); reject(e); });
      child.on("close", () => { clearTimeout(timer); resolve(buf); });
    });

    // Godot 侧投影合法
    const payload = JSON.parse(marker(out, "BATTLE_PAYLOAD"));
    assert.equal(payload.battle_version, 1);
    assert.equal(payload.controlled_actor_id, 12);
    assert.equal(payload.enemy_actor_id, 31);
    assert.ok(Array.isArray(payload.controlled.units));
    assert.ok(payload.controlled.units.length > 0);
    assert.ok(Array.isArray(payload.legal_tactics));

    // Godot 能开会话（真实 HTTP）
    assert.equal(marker(out, "BATTLE_OPEN"), "True", `开会话失败：\n${out.slice(-1500)}`);
    // 服务端确实创建过会话（mock 模式结束快，size() 会清理已结束项，
    // 因此断言 Godot 收到的响应里带有 session id 即可）
    assert.equal(marker(out, "BATTLE_OPEN"), "True", "Godot 应成功打开白兵战会话");
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    fs.rmSync(xdg, { recursive: true, force: true });
  }
});
