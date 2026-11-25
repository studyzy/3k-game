// 白兵战 Godot 侧契约：真实 GDScript 运行 BattleProjection / BattleAgent，
// 通过真实 HTTP 与服务端 /ai/battle + /tick 往返。未安装 Godot 3 时自动 skip。
import test from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import http from "node:http";
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
  path.join(repo, "Godot_3.6.3.app/Contents/MacOS/Godot"),
].filter((v): v is string => typeof v === "string" && v.length > 0);
const bin = candidates.find((p) => fs.existsSync(p));

const RUN_TIMEOUT_MS = 30000;

function marker(out: string, name: string): string {
  const m = out.match(new RegExp(name + "=([^\\n]*)"));
  assert.ok(m, "缺少 " + name + " 输出：\n" + out.slice(-2000));
  return m[1];
}

interface HarnessRun {
  output: () => string;
  waitFor: (name: string, timeoutMs?: number) => Promise<string>;
  exit: (timeoutMs?: number) => Promise<void>;
  kill: () => void;
}

/** 每个场景独立进程 + 独立 XDG 目录，30 秒兜底 kill。 */
function startHarness(baseUrl: string, scenario: string): HarnessRun {
  const xdg = fs.mkdtempSync(path.join(os.tmpdir(), "3k-bg-"));
  const child = spawn(bin!, ["--no-window", "--path", harnessDir], {
    cwd: repo,
    env: {
      ...process.env,
      XDG_DATA_HOME: xdg,
      XDG_CONFIG_HOME: xdg,
      K3G_AI_URL: baseUrl,
      K3G_BATTLE_SCENARIO: scenario,
    },
    stdio: ["ignore", "pipe", "pipe"],
  });
  let buf = "";
  let closed = false;
  const waiters = new Set<() => void>();

  const notify = () => {
    for (const check of [...waiters]) check();
  };
  child.stdout!.on("data", (d) => { buf += d.toString(); notify(); });
  child.stderr!.on("data", (d) => { buf += d.toString(); notify(); });
  child.on("close", () => { closed = true; notify(); });

  const killTimer = setTimeout(() => child.kill("SIGKILL"), RUN_TIMEOUT_MS);
  child.on("close", () => clearTimeout(killTimer));

  return {
    output: () => buf,
    waitFor(name: string, timeoutMs = RUN_TIMEOUT_MS): Promise<string> {
      const re = new RegExp(name + "=([^\\n]*)");
      const deadline = Date.now() + timeoutMs;
      return new Promise<string>((resolve, reject) => {
        const check = () => {
          const hit = buf.match(re);
          if (hit) {
            waiters.delete(check);
            clearInterval(timer);
            resolve(hit[1]);
            return;
          }
          if (closed) {
            waiters.delete(check);
            clearInterval(timer);
            reject(new Error("Godot 已退出但没有 " + name + "：\n" + buf.slice(-2000)));
            return;
          }
          if (Date.now() > deadline) {
            waiters.delete(check);
            clearInterval(timer);
            reject(new Error("等待 " + name + " 超时：\n" + buf.slice(-2000)));
          }
        };
        const timer = setInterval(check, 40);
        waiters.add(check);
        check();
      });
    },
    exit(timeoutMs = RUN_TIMEOUT_MS): Promise<void> {
      if (closed) return Promise.resolve();
      return new Promise<void>((resolve) => {
        const timer = setTimeout(() => { child.kill("SIGKILL"); resolve(); }, timeoutMs);
        child.once("close", () => { clearTimeout(timer); resolve(); });
      });
    },
    kill() {
      clearTimeout(killTimer);
      if (!closed) child.kill("SIGKILL");
    },
  };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** 假服务：open 200 + tick 恒为指定错误码，用于验证兜底有界。 */
async function startFailingServer(tickCode: number): Promise<{
  url: string;
  counts: { open: number; tick: number };
  close: () => Promise<void>;
}> {
  const counts = { open: 0, tick: 0 };
  const server = http.createServer((req, res) => {
    const url = req.url ?? "";
    req.on("data", () => {});
    req.on("end", () => {
      res.setHeader("content-type", "application/json");
      if (url === "/ai/battle") {
        counts.open += 1;
        res.writeHead(200);
        res.end(JSON.stringify({ battle_session_id: "s-" + counts.open }));
        return;
      }
      if (/^\/ai\/battle\/[^/]+\/tick$/.test(url)) {
        counts.tick += 1;
        res.writeHead(tickCode);
        res.end(JSON.stringify({ error: tickCode === 410 ? "session_ended" : "invalid_snapshot" }));
        return;
      }
      res.writeHead(200);
      res.end("{}");
    });
  });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as AddressInfo).port;
  return {
    url: "http://127.0.0.1:" + port + "/",
    counts,
    close: () => new Promise<void>((resolve) => {
      (server as any).closeAllConnections?.();
      server.close(() => resolve());
    }),
  };
}

test("Godot 白兵战 v2 快照 / tick / 计策排队", { timeout: 180000 }, async (t) => {
  if (!bin) {
    t.skip("未找到 Godot 3.6.3（设置 GODOT3_BIN）");
    return;
  }
  // 用真实脚本覆盖 harness 里的副本，保证测的是仓库代码
  for (const f of ["BattleAgent.gd", "BattleProjection.gd", "TacticProjection.gd", "BattleHttpClient.gd"]) {
    fs.copyFileSync(path.join(battleAiDir, f), path.join(harnessDir, f));
  }

  const server = createServer({ ...testConfig, port: 0, mode: "stub", webDir: harnessDir });
  await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
  const port = (server.address() as AddressInfo).port;
  // 带尾斜杠，验证客户端会规范化
  const baseUrl = "http://127.0.0.1:" + port + "/";

  try {
    await t.test("orders：v2 快照 + tick 应用前进命令", async () => {
      const h = startHarness(baseUrl, "orders");
      try {
        assert.equal((await h.waitFor("BATTLE_OPEN", 25000)).trim(), "True", "开会话失败：\n" + h.output().slice(-1500));
        assert.equal(marker(h.output(), "BATTLE_BASE").trim(), "http://127.0.0.1:" + port + "/ai/battle");
        const payload = JSON.parse(marker(h.output(), "BATTLE_PAYLOAD"));
        assert.equal(payload.battle_version, 2);
        assert.equal(payload.controlled_actor_id, 12);
        assert.equal(payload.enemy_actor_id, 31);
        assert.ok(Array.isArray(payload.legal_tactics));
        assert.ok(Array.isArray(payload.controlled.units));
        assert.ok(payload.controlled.units.length > 0);
        assert.ok(payload.controlled.units[0].x !== undefined);
        assert.ok(payload.controlled.units[0].y !== undefined);
        const calls = await h.waitFor("BATTLE_ORDER_CALLS", 20000);
        assert.ok(calls.includes("前进"), "tick 应把前进命令落到战场：" + calls);
        await h.exit(5000);
        assert.ok(!h.output().includes("BATTLE_RESULT=timeout"), "不应走到 20 秒兜底");
      } finally {
        h.kill();
      }
    });

    await t.test("tactic：强弩入队并在安全点执行", async () => {
      const h = startHarness(baseUrl, "tactic");
      try {
        assert.equal((await h.waitFor("BATTLE_TACTIC_FLOW", 25000)).trim(), "before_AI_tactic");
        const payload = JSON.parse(marker(h.output(), "BATTLE_PAYLOAD"));
        assert.equal(payload.legal_tactics[0].name, "强弩");
        assert.ok(String(payload.legal_tactics[0].summary).includes("射程"));
        await h.exit(5000);
      } finally {
        h.kill();
      }
    });

    await t.test("paused：暂停时 10 秒一拍", async () => {
      const h = startHarness(baseUrl, "paused");
      try {
        assert.equal((await h.waitFor("BATTLE_INTERVAL", 20000)).trim(), "10000");
        await h.exit(5000);
      } finally {
        h.kill();
      }
    });

    await t.test("queue_ttl：用计排队超时被拒绝", async () => {
      const h = startHarness(baseUrl, "queue_ttl");
      try {
        await h.waitFor("BATTLE_LAST_PLAN", 25000);
        await h.exit(RUN_TIMEOUT_MS);
        const plans = h.output().split("\n").filter((l) => l.startsWith("BATTLE_LAST_PLAN="));
        assert.ok(plans.length > 0, "应至少回喂一次上一拍计划：\n" + h.output().slice(-2000));
        assert.ok(
          plans.some((l) => l.includes("用计排队超时")),
          "应出现「用计排队超时」：\n" + plans.slice(-5).join("\n"),
        );
      } finally {
        h.kill();
      }
    });
  } finally {
    (server as any).closeAllConnections?.();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }

  await t.test("fallback_410：会话丢失后重开有界，最终回退本地", async () => {
    const fake = await startFailingServer(410);
    const h = startHarness(fake.url, "fallback_410");
    try {
      assert.equal((await h.waitFor("BATTLE_LOCAL", 25000)).trim(), "True", "应回退本地规则：\n" + h.output().slice(-2000));
      const atFallback = { ...fake.counts };
      // 410 风暴修复：重开有上限；回退后完全停止请求
      assert.ok(fake.counts.open <= 4, "open 次数应有界，实际 " + fake.counts.open);
      assert.ok(fake.counts.tick <= 3, "tick 次数应有界，实际 " + fake.counts.tick);
      await sleep(1000);
      assert.equal(fake.counts.open, atFallback.open, "回退后不应再有 open 请求");
      assert.equal(fake.counts.tick, atFallback.tick, "回退后不应再有 tick 请求");
      await h.exit(5000);
    } finally {
      h.kill();
      await fake.close();
    }
  });

  await t.test("fallback_422：连续 422 后回退本地", async () => {
    const fake = await startFailingServer(422);
    const h = startHarness(fake.url, "fallback_422");
    try {
      assert.equal((await h.waitFor("BATTLE_LOCAL", 28000)).trim(), "True", "应回退本地规则：\n" + h.output().slice(-2000));
      assert.equal(fake.counts.open, 1, "422 不需要重开会话");
      assert.equal(fake.counts.tick, 3, "3 次失败后回退");
      await h.exit(5000);
    } finally {
      h.kill();
      await fake.close();
    }
  });
});
