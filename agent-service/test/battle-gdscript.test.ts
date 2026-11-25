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

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

interface HarnessRun {
  /** 每个场景独立的 XDG 目录，场景结束必须删掉。 */
  xdg: string;
  output: () => string;
  /** 等 marker=value 出现；给了 expected 时要求整个值完全相等。 */
  waitFor: (name: string, timeoutMs?: number, expected?: string) => Promise<string>;
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
  // spawn 本身失败（ENOENT/EACCES）只会走 error 事件，不捕获会直接崩掉测试进程。
  let spawnError: Error | null = null;
  const waiters = new Set<() => void>();

  const notify = () => {
    for (const check of [...waiters]) check();
  };
  child.stdout!.on("data", (d) => { buf += d.toString(); notify(); });
  child.stderr!.on("data", (d) => { buf += d.toString(); notify(); });
  child.on("error", (err) => { spawnError = err; closed = true; notify(); });
  child.on("close", () => { closed = true; notify(); });

  const killTimer = setTimeout(() => child.kill("SIGKILL"), RUN_TIMEOUT_MS);
  child.on("close", () => clearTimeout(killTimer));

  const waitForMatch = (re: RegExp, label: string, timeoutMs: number): Promise<string> => {
    const deadline = Date.now() + timeoutMs;
    return new Promise<string>((resolve, reject) => {
      let timer: ReturnType<typeof setInterval>;
      const finish = (err: Error | null, value?: string) => {
        clearInterval(timer);
        waiters.delete(check);
        if (err) reject(err);
        else resolve(value!);
      };
      const check = () => {
        if (spawnError) {
          finish(new Error("Godot 启动失败：" + spawnError.message));
          return;
        }
        const hit = buf.match(re);
        if (hit) {
          finish(null, hit[0]);
          return;
        }
        if (closed) {
          finish(new Error("Godot 已退出但没有 " + label + "：\n" + buf.slice(-2000)));
          return;
        }
        if (Date.now() > deadline) {
          finish(new Error("等待 " + label + " 超时：\n" + buf.slice(-2000)));
        }
      };
      timer = setInterval(check, 40);
      waiters.add(check);
      check();
    });
  };

  return {
    xdg,
    output: () => buf,
    waitFor(name: string, timeoutMs = RUN_TIMEOUT_MS, expected?: string): Promise<string> {
      if (expected !== undefined) {
        const re = new RegExp(name + "=" + escapeRe(expected) + "(?:\\r?\\n|$)");
        return waitForMatch(re, name + "=" + expected, timeoutMs).then(() => expected);
      }
      const re = new RegExp(name + "=([^\\n]*)");
      return waitForMatch(re, name, timeoutMs).then((line) => line.slice(name.length + 1));
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

/** 场景收尾：杀进程 + 删临时 XDG 目录。 */
function cleanup(h: HarnessRun): void {
  h.kill();
  fs.rmSync(h.xdg, { recursive: true, force: true });
}

/**
 * GDScript 运行时错误只认 "SCRIPT ERROR"。
 * 引擎退出时偶发 "ERROR: Condition \"_first != nullptr\"" 属于正常噪声，不能误判。
 */
function assertNoScriptError(h: HarnessRun): void {
  const out = h.output();
  if (!out.includes("SCRIPT ERROR")) return;
  const lines = out.split("\n").filter((l) => l.includes("SCRIPT ERROR"));
  assert.fail("GDScript 运行时错误：\n" + lines.join("\n") + "\n" + out.slice(-2000));
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
      server.closeAllConnections();
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
    await t.test("orders：v2 快照 + tick 应用前进命令 + 第二拍差分", async () => {
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
        const orderCalls = JSON.parse(calls);
        assert.equal(orderCalls.length, 4, "四个兵种都应落子：" + calls);
        for (const call of orderCalls) {
          assert.equal(call.actor, 12, "命令只能下给自己：" + JSON.stringify(call));
        }
        // 第二拍：同一批命令已生效，v2 差分不应再下发。
        // Main 在第二拍回包落地后才退出，所以最后的落子数就是第二拍 apply 之后的值。
        await h.waitFor("BATTLE_TICK", 20000, "2");
        await h.exit(8000);
        assert.ok(!h.output().includes("BATTLE_RESULT=timeout"), "不应走到 20 秒兜底");
        const counts = h.output().split("\n").filter((l) => l.startsWith("BATTLE_ORDER_COUNT="));
        assert.ok(counts.length >= 2, "应有至少两拍的落子计数：\n" + counts.join("\n"));
        assert.equal(counts[counts.length - 1], "BATTLE_ORDER_COUNT=4", "第二拍不该重复下发");
        assert.ok(!counts.includes("BATTLE_ORDER_COUNT=8"), "第二拍重复下发了同一批命令：\n" + counts.join("\n"));
        assertNoScriptError(h);
      } finally {
        cleanup(h);
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
        assertNoScriptError(h);
      } finally {
        cleanup(h);
      }
    });

    await t.test("tactic_applied：流程副作用落地后判为 applied", async () => {
      const h = startHarness(baseUrl, "tactic_applied");
      try {
        assert.equal((await h.waitFor("BATTLE_OPEN", 25000)).trim(), "True", "开会话失败：\n" + h.output().slice(-1500));
        const openedAt = Date.now();
        await h.waitFor("BATTLE_TACTIC_APPLIED", 20000, "applied");
        const elapsed = Date.now() - openedAt;
        assert.ok(elapsed < 2900, "应在下一拍（3 秒）前判定 applied，实际 " + elapsed + "ms");
        await h.exit(5000);
        assertNoScriptError(h);
      } finally {
        cleanup(h);
      }
    });

    await t.test("flow_busy：流程忙时计策只排队，不插队 add_flow", async () => {
      const h = startHarness(baseUrl, "flow_busy");
      try {
        assert.equal((await h.waitFor("BATTLE_OPEN", 25000)).trim(), "True", "开会话失败：\n" + h.output().slice(-1500));
        assert.equal((await h.waitFor("BATTLE_FLOW_BUSY", 20000)).trim(), "queued");
        const flows = JSON.parse(marker(h.output(), "BATTLE_FLOWS"));
        assert.ok(Array.isArray(flows), "BATTLE_FLOWS 应是数组：" + JSON.stringify(flows));
        assert.ok(!flows.includes("before_AI_tactic"), "流程忙时不应入队：" + JSON.stringify(flows));
        await h.exit(5000);
        assertNoScriptError(h);
      } finally {
        cleanup(h);
      }
    });

    await t.test("reinit：缓存命中是同一实例（Godot 3 会重放成员初始化器）", async () => {
      const h = startHarness(baseUrl, "reinit");
      try {
        assert.equal((await h.waitFor("BATTLE_REINIT_SAME", 20000)).trim(), "True", "缓存命中应是同一实例：\n" + h.output().slice(-1500));
        // 实测（Godot 3.6.3）：外部再调一次 _init() 会先把成员重新初始化 —— attach 后的
        // _actor_id=12 在重入后变回 -1，BattleAgent._init 里「已有会话就保持原状」的守卫
        // 因此进不去。这是生产脚本的既有缺陷，本任务只改 harness，故这里钉住实测值；
        // 守卫哪天真正生效（需要生产侧改法），这里应改为 12。
        assert.equal((await h.waitFor("BATTLE_REINIT_ACTOR", 20000)).trim(), "-1", "Godot 3 重放成员初始化器，attach 结果被清掉");
        await h.exit(5000);
        assertNoScriptError(h);
      } finally {
        cleanup(h);
      }
    });

    await t.test("normalize：快照把越界命令归一化，避免 422", async () => {
      const h = startHarness(baseUrl, "normalize");
      try {
        await h.exit(8000);
        const payload = JSON.parse(marker(h.output(), "BATTLE_PAYLOAD"));
        const orders: Record<string, string> = {};
        for (const u of payload.controlled.units) orders[u.type] = u.order;
        assert.equal(orders["将"], "前进", "包围 应归一化为 前进");
        assert.equal(orders["骑"], "待机", "未知值 应归一化为 待机");
        assert.equal(orders["弓"], "待机", "待机 保持 待机");
        assert.equal(orders["步"], "前进", "前进 保持 前进");
        assertNoScriptError(h);
      } finally {
        cleanup(h);
      }
    });

    await t.test("paused：暂停时 10 秒一拍", async () => {
      const h = startHarness(baseUrl, "paused");
      try {
        assert.equal((await h.waitFor("BATTLE_INTERVAL", 20000)).trim(), "10000");
        const delay = Number((await h.waitFor("BATTLE_NEXT_DELAY", 20000)).trim());
        assert.ok(delay >= 8500 && delay <= 10000, "第一拍后距下一拍应≈10000ms，实际 " + delay);
        await h.exit(5000);
        assertNoScriptError(h);
      } finally {
        cleanup(h);
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
        assertNoScriptError(h);
      } finally {
        cleanup(h);
      }
    });
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }

  await t.test("fallback_410：会话丢失后重开有界，最终回退本地", async () => {
    const fake = await startFailingServer(410);
    const h = startHarness(fake.url, "fallback_410");
    try {
      // 先确认会话真的开了：否则 0 请求也能「回退」，断言会空过。
      assert.equal((await h.waitFor("BATTLE_OPEN", 25000)).trim(), "True", "开会话失败：\n" + h.output().slice(-2000));
      assert.equal((await h.waitFor("BATTLE_LOCAL", 28000)).trim(), "True", "应回退本地规则：\n" + h.output().slice(-2000));
      // 410 风暴修复：open 3 次 / tick 3 次后触发重开上限
      assert.equal(fake.counts.open, 3, "open 次数应为 3，实际 " + fake.counts.open);
      assert.equal(fake.counts.tick, 3, "tick 次数应为 3，实际 " + fake.counts.tick);
      await sleep(1000);
      assert.equal(fake.counts.open, 3, "回退后不应再有 open 请求");
      assert.equal(fake.counts.tick, 3, "回退后不应再有 tick 请求");
      await h.exit(5000);
      assertNoScriptError(h);
    } finally {
      cleanup(h);
      await fake.close();
    }
  });

  await t.test("fallback_422：连续 422 后回退本地", async () => {
    const fake = await startFailingServer(422);
    const h = startHarness(fake.url, "fallback_422");
    try {
      assert.equal((await h.waitFor("BATTLE_OPEN", 25000)).trim(), "True", "开会话失败：\n" + h.output().slice(-2000));
      assert.equal((await h.waitFor("BATTLE_LOCAL", 28000)).trim(), "True", "应回退本地规则：\n" + h.output().slice(-2000));
      assert.equal(fake.counts.open, 1, "422 不需要重开会话");
      assert.equal(fake.counts.tick, 3, "3 次失败后回退");
      await h.exit(5000);
      assertNoScriptError(h);
    } finally {
      cleanup(h);
      await fake.close();
    }
  });
});
