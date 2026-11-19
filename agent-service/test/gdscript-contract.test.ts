// 跨语言端到端契约测试：Godot 3.6.3 真实运行 StateProjection / ActionValidator /
// AIHttpClient，把生成的 payload 通过真实 HTTP POST 发给 Agent 服务，
// 再验证服务返回的 plan 能被两侧校验接受。未安装 Godot 3 时自动 skip。
import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { fileURLToPath } from "node:url";
import type { AddressInfo } from "node:net";
import { validateTurnRequest, validateAction } from "../src/validate.ts";
import { startTurn } from "../src/agent.ts";
import { budgetFor } from "../src/config.ts";
import { createServer } from "../src/server.ts";
import { sampleRequest, testConfig, toolResult } from "./fixture.ts";

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, "../..");
const gdscriptDir = path.join(repo, "bwdl/packed/sgz_script/war/AI");
const harnessDir = path.join(repo, "agent-service/gdharness");
const aiDir = path.join(harnessDir, "ai");
const candidates = [
  process.env.GODOT3_BIN,
  path.join(repo, ".tools/Godot_v3.6.3-stable_linux_headless.64"),
].filter((v): v is string => typeof v === "string" && v.length > 0);
const bin = candidates.find((p) => fs.existsSync(p));

function marker(out: string, name: string): string {
  const m = out.match(new RegExp(`${name}=([^\\n]*)`));
  assert.ok(m, `缺少 ${name} 输出：\n${out.slice(-1500)}`);
  return m[1];
}

test("Godot 3.6.3 → HTTP → Agent 服务 全链路契约", async (t) => {
  if (!bin) {
    t.skip("未找到 Godot 3.6.3（设置 GODOT3_BIN）");
    return;
  }
  fs.mkdirSync(aiDir, { recursive: true });
  for (const f of ["StateProjection.gd", "ActionValidator.gd", "AIHttpClient.gd"]) {
    fs.copyFileSync(path.join(gdscriptDir, f), path.join(aiDir, f));
  }

  const server = createServer({ ...testConfig, port: 0, webDir: harnessDir });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as AddressInfo).port;
  const xdg = fs.mkdtempSync(path.join(os.tmpdir(), "3k-godot-home-"));

  try {
    // 必须用异步 spawn：spawnSync 会阻塞 Node 事件循环，
    // 导致同进程内的 mock HTTP 服务无法响应 Godot 的请求（实测 result=12 超时）。
    const out = await new Promise<string>((resolve, reject) => {
      const child = spawn(bin, ["--no-window", "--path", harnessDir], {
        cwd: repo,
        env: {
          ...process.env,
          XDG_DATA_HOME: xdg,
          AI_HTTP_URL: `http://127.0.0.1:${port}/ai/turn`,
          AI_HTTP_BASE: `http://127.0.0.1:${port}/ai/turn`,
        },
        stdio: ["ignore", "pipe", "pipe"],
      });
      let buf = "";
      child.stdout.on("data", (d) => { buf += d.toString(); });
      child.stderr.on("data", (d) => { buf += d.toString(); });
      const timer = setTimeout(() => { child.kill(); reject(new Error("Godot harness timeout")); }, 120000);
      child.on("error", (e) => { clearTimeout(timer); reject(e); });
      child.on("close", () => { clearTimeout(timer); resolve(buf); });
    });

    assert.equal(marker(out, "AI_ACCEPT_GOOD"), "True");
    assert.equal(marker(out, "AI_REJECT_BAD"), "True");
    assert.equal(marker(out, "AI_REJECT_DUP"), "True", "已在 history 中执行过的动作应被拒绝");
    assert.equal(marker(out, "AI_HTTP_START"), "True");
    assert.equal(marker(out, "AI_HTTP_RESULT"), "0_200", `GDScript HTTP 调用失败：\n${out.slice(-1500)}`);

    const payload = JSON.parse(marker(out, "AI_PAYLOAD"));
    const req = validateTurnRequest(payload);
    assert.ok(["attacker", "defender"].includes(payload.side), "side 必须是 attacker|defender");
    assert.equal(typeof payload.economy.enemy.rice, "number", "economy.enemy.rice 必须投影");
    assert.equal(typeof payload.economy.enemy.money, "number", "economy.enemy.money 必须投影");
    assert.notEqual(payload.economy.attacker_vstate, payload.controlled_vstate_id, "守方时攻方 id 不应等于受控方 id");
    assert.equal(req.visibility, "omniscient");
    assert.ok(req.legal_actions.length > 0);
    assert.equal(new Set(req.legal_actions.map((a) => a.id)).size, req.legal_actions.length);
    for (const key of ["battle_fight", "battle_units", "flows_history_list", "common_variable", "secret_mood"]) {
      assert.ok(!(key in payload), `payload 不应包含 ${key}`);
    }

    // 地形投影格式：[x, y, "地形名"]，只列非平原格（FakeMap 里定义了 3 个非平原格）
    const inBounds = req.terrain.filter((c) => c[2] !== "不可进入");
    assert.deepEqual(inBounds, [
      [3, 4, "河流"],
      [9, 15, "树林"],
      [10, 15, "米屋"],
    ], "terrain 只列非平原格，且按行优先（y 小在前）排列");
    // 引擎 is_valid_position 只认 y < 19，最后一行整行不可进入，必须显式标出来
    const blocked = req.terrain.filter((c) => c[2] === "不可进入");
    assert.equal(blocked.length, 32, "不可进入的一行应有 32 格");
    assert.ok(blocked.every((c) => c[1] === 19), "只有 y=19 这一行不可进入");
    // 军种决定行军消耗，必须随单位一起投影
    for (const u of req.units) {
      assert.ok(["平", "山", "水", "仙"].includes(String(u.troops)), `unit ${u.id} 缺 troops 军种`);
    }

    // Godot 侧 accept_action 结果 → 服务侧 validateAction 同规则
    const accepted = JSON.parse(marker(out, "AI_NORMALIZED"));
    assert.ok(accepted.id, "Godot 侧应接受一个合法动作");
    assert.equal(
      validateAction(accepted.id, {
        controlled_vstate_id: req.controlled_vstate_id,
        units: req.units,
        legal_actions: req.legal_actions,
      }, budgetFor(req.diffculities)).id,
      accepted.id,
    );

    // 真实 GDScript → 真实服务：开会话
    const opened = JSON.parse(marker(out, "AI_HTTP_BODY"));
    assert.ok(typeof opened.session_id === "string", "服务应返回 session_id");

    // 真实 GDScript 长轮询拿到动作
    assert.equal(marker(out, "AI_POLL_RESULT"), "0_200", `GDScript 长轮询失败：\n${out.slice(-1500)}`);
    const pending = JSON.parse(marker(out, "AI_POLL_BODY"));
    assert.equal(pending.type, "action", `长轮询应返回动作，实际 ${JSON.stringify(pending)}`);
    assert.ok(pending.action && typeof pending.action.id === "string");

    // 该动作能被服务侧同规则校验
    assert.equal(
      validateAction(pending.action.id, {
        controlled_vstate_id: req.controlled_vstate_id,
        units: req.units,
        legal_actions: req.legal_actions,
      }, budgetFor(req.diffculities)).id,
      pending.action.id,
    );

    // 同一 payload 交给服务端会话也必须产出合法动作
    const { session } = startTurn(req, { mode: "mock", config: testConfig, mockCase: "ok" });
    const produced = await session.nextAction(3000);
    assert.equal(produced.type, "action");
    assert.ok(
      validateAction(produced.action.id, {
        controlled_vstate_id: req.controlled_vstate_id,
        units: req.units,
        legal_actions: req.legal_actions,
      }, budgetFor(req.diffculities)),
    );
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    fs.rmSync(xdg, { recursive: true, force: true });
  }
});
