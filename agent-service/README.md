# 全知 AI Agent 敌方决策服务（战争场景）

对应设计文档：[docs/plans/2026-11-18-ai-agent-enemy-design.md](../docs/plans/2026-11-18-ai-agent-enemy-design.md)

只接入**战争场景**（`bwdl/packed/sgz_script/war/`）：从内政发起攻击一座城市后进入的大战场，布阵完成后的逐武将移动 / 攻击 / 用计 / 撤退。内政、单挑、白兵战不接入；布阵保持规则实现。

## 决策模型：服务端驱动的回合会话

**一个 AI 回合 = 一个服务端会话**。LLM 在一个会话里连续指挥多个武将，直到自己调用 `end`：

```
Godot                             服务端
  POST /ai/turn  ───────────────→  创建 TurnSession，后台启动 agent loop
                                    LLM: move(12, [8,15])
  ←──── GET /ai/turn/:id/pending    取到动作（工具 execute 挂起等 Godot）
  执行移动 → 重算 units/legal_actions
  POST /ai/turn/:id/result ──────→  唤醒工具，把最新状态喂回 LLM
                                    LLM: attack(12 → 31)   ← 看到移动结果后决策
  ←──── GET .../pending             取到攻击
  执行攻击 → 战斗结算（胜负不确定）
  POST .../result ───────────────→  LLM 看到战斗结果
                                    LLM: attack(13 → 31)   ← 据实调整
  ...
  ←──── GET .../pending            {type:"end"} ← LLM 判定都动完了
  AI_end，回合结束
```

要点：

- **`end` 是唯一终止工具**，结束整个回合。游戏里没有「让单个武将结束行动」——某个武将机动力耗尽不影响其他人，LLM 会继续指挥还有机动力的人。
- **Godot 只提供「工具实现」**：执行动作、计算执行后状态、回传；决策全在服务端循环里。
- **战斗的胜负不确定结果**会随结果回传给 LLM，由它决定继续攻击还是改做别的。
- **空闲超时 30s**：每次 Agent 工具调用（含只读侦察）或 Godot 回传结果后重置；30s 内完全没有 Agent 活动 → 判定 LLM 已死，本回合剩余全部回退 `hard` 规则 AI。
- 等待期间显示「敌方思考中……」。

### 白兵战（两军对垒）

`attack` 触发白兵战时，Godot 主动开一个**独立的战斗会话**：新提示词、新场景数据、新工具。

| 工具 | 说明 |
|---|---|
| `inspect_battlefield` | 查看双方武将/兵力/战术值/各兵种血量与命令 |
| `set_order` | 给**一个**兵种下命令：`前进` / `待机` / `后退` |
| `use_tactic` | 用计：咒缚/挑衅/强弩/士气向上/火矢（消耗战术值） |
| `end_turn` | 结束**本战斗回合**的决策，交还引擎结算 |

**整场战斗是一个会话**（跨多个战斗回合），每回合 `end_turn` 后由引擎推进，Godot 调 `/resume` 继续问 LLM。主回合会话在此期间挂起——等待 Godot 执行不计入 Agent 空闲超时。

## 服务地址配置

游戏端连接 Agent 服务的地址**可配置**，优先级从高到低：

| 方式 | 说明 |
|---|---|
| 环境变量 `K3G_AI_AGENT_URL` | 例如 `export K3G_AI_AGENT_URL=https://ai.example.com` |
| 配置文件 `user://ai_agent.cfg` | 一行纯文本地址；代码中可调 `DataManager.save_ai_agent_config(url)` |
| 平台默认 | Web 端用当前站点 origin（同源免预检）；桌面端 `http://127.0.0.1:8060` |

地址末尾有无 `/` 都可以，会自动规范化后再拼 `/ai/turn`、`/ai/battle`。
战争场景与白兵战共用同一份配置（`DataManager.resolve_ai_agent_url()`）。

## 运行环境

- Node.js **≥ 22.19**（Pi 硬要求），本机实测 v24.11.1
- 依赖 [Pi（earendil-works/pi）](https://raw.githubusercontent.com/badlogic/pi-mono/main/README.md) 1.5.2，MIT，精确版本锁定在 `package-lock.json`
- 本机 npm 默认缓存目录只读，安装时需指定可写缓存：`npm --cache ../.npm-cache install --ignore-scripts`

## 启动

```bash
cd agent-service
npm --cache ../.npm-cache install --ignore-scripts   # 首次
npm start                                            # 默认 mode=mock, port=8060
# 或
node src/server.ts --mode stub --port 8060 --web-dir ../bwdl/build/web
```

服务同源提供：

| 路径 | 作用 |
|---|---|
| `GET /` | 静态托管 `bwdl/build/web/`（`index.html` / `.js` / `.wasm` / `.pck`，MIME 正确） |
| `GET /ai/health` | 探活 + 返回难度预算表 |
| `POST /ai/turn` | 开启一个 AI 回合会话，返回 `session_id` |
| `GET /ai/turn/:id/pending` | 长轮询取下一个待执行动作 / `end` / `idle_timeout` |
| `POST /ai/turn/:id/result` | 回传执行结果（最新 `units` + `legal_actions`） |
| `POST /ai/battle` | 白兵战：开启战斗会话（独立 Agent / 提示词 / 工具） |
| `GET /ai/battle/:id/pending` | 白兵战：长轮询取指令（`order`/`tactic`/`end_turn`） |
| `POST /ai/battle/:id/result` | 白兵战：回传执行后的战斗态势 |
| `POST /ai/battle/:id/resume` | 白兵战：引擎推进到下一战斗回合 |

`make serve` 的 `python3 -m http.server` 保留作纯离线对照；`make web` 导出产物由本服务托管即可同源。

## 三种模式

| `--mode` | 说明 | 是否需要 LLM key |
|---|---|---|
| `mock`（默认） | P0′ 确定性五态响应，验证会话驱动与回退链路 | 否 |
| `stub` | **真实 `pi-agent-core` agent loop** + Pi 官方 `fauxProvider` 脚本 LLM，验证工具注册表 / 会话内多动作 / `end` 终止 | 否 |
| `pi` | 真实模型：优先自定义 OpenAI 兼容端点（`LLM_BASE_URL`），否则回退 `pi-ai` `builtinModels()` | 是 |

## 配置真实 LLM（自定义 OpenAI 兼容端点）

`pi` 模式支持任意 `/v1/chat/completions` 端点。用 [llm.ts](src/llm.ts) 的 `createProvider` + Pi 官方 `openAICompletionsApi()` 构造自定义 provider —— 模型名不在 Pi 内置目录里也能用，tool calling 由 Pi 官方实现处理。

```
cp .env.example .env      # .env 已被 .gitignore 忽略，切勿提交
# 编辑 .env 填入真实值
node --env-file=.env src/server.ts
```

| 变量 | 说明 |
|---|---|
| `LLM_BASE_URL` | 端点根，如 `http://host:3456/v1`（末尾 `/v1` 保留，Pi 会拼 `/chat/completions`） |
| `LLM_MODEL` | 模型 ID，如 `hai/deepseek-flash` |
| `LLM_API_KEY` | Bearer 密钥，**只从进程环境读取**，不写入 `ServiceConfig`、日志或 `/ai/health` |
| `LLM_PROVIDER_ID` | 自定义 provider 标识，默认 `ccr` |
| `LLM_CONTEXT_WINDOW` / `LLM_MAX_TOKENS` | 模型能力声明，默认 65536 / 8192 |
| `K3G_AGENT_MODE` | `mock` / `stub` / `pi` |

未设 `LLM_BASE_URL` 时回退到 Pi 内置 provider 目录（`PI_PROVIDER` + `PI_MODEL` + `${PROVIDER}_API_KEY`）。缺密钥时 `pi` 模式返回 503 `api_key_missing`，**不静默降级**。

> 端点必须支持 `tools` / `tool_calls`——`pi-agent-core` 的 agent loop 依赖模型主动调用工具；**只有 `end` 会终止回合**。

其他环境变量：

```
K3G_AGENT_MODE=mock|stub|pi      # 同 --mode
PORT=8060
WEB_DIR=../bwdl/build/web
MOCK_CASE=ok|slow|error|invalid|timeout|budget_exhausted
MOCK_SLOW_MS=3000
PI_PROVIDER=openai               # 仅回退路径
PI_MODEL=gpt-4o-mini
OPENAI_API_KEY=...               # 仅回退路径，或 PI_API_KEY
```

`mock` 下可用请求头 `x-mock-case` 覆盖 `MOCK_CASE`，对应设计文档附录 C 五态。

## Godot 侧

4 个新脚本位于 `bwdl/packed/sgz_script/war/AI/`，通过 `Global.load_script` 的 `mod_path` 加载，不改反编译 `.gdc` 框架：

| 文件 | 职责 |
|---|---|
| `War_AI_behavior_llm.gd` | `wab` 实现：开会话 / 长轮询 / 执行 / 回传 / 回退 `hard` |
| `battle/AI/BattleProjection.gd` | 白兵战态势投影（兵种/命令/计策） |
| `battle/AI/BattleAgent.gd` | 白兵战会话驱动（开战会话 / 长轮询 / 执行指令 / 回传） |
| `StateProjection.gd` | 全知去噪状态 + `legal_actions` |
| `AIHttpClient.gd` | `HTTPRequest` 异步封装 |
| `ActionValidator.gd` | 单动作二次校验（双防线） |

`war/AI_control.gd` 仅在 `DataManager.ai_agent_mode == true` 时加载 LLM `wab`。该标记由**标题界面新增的「大模型」难度**设置（[scene_title.gd](../bwdl/scene/scene_title/scene_title.gd) / [scene_title.tscn](../bwdl/scene/scene_title/scene_title.tscn)），并随存档持久化（[Data_Manager.gd](../bwdl/script/Data_Manager.gd)）。选其他难度一律零网络请求。

> 「大模型」不新增 `diffculities` 数值档位（该值被大量规则数组按下标取值，新增会越界），复用挑战档(4) 的规则参数与最高 Agent 预算，只把战争层决策器换成远程 Agent。`AI_auto_embattle`（布阵）未改动。

## 监控面板（调试用）

**http://\<host\>:8060/ai/dashboard**

同源面板，显示每次 AI 决策的**完整对话动作**：System Prompt、战场 User JSON、逐轮 assistant 文本、每次 `tool_call` 的参数、每次 `tool_result` 的返回、最终 `plan` / `intent` / `counterplay`，以及状态、耗时、轮次、token 数。左侧列表按时间倒序，2 秒自动刷新（可关闭），支持清空。

| 路径 | 作用 |
|---|---|
| `GET /ai/dashboard` | 面板 HTML（单文件，内联 CSS/JS，[dashboard/index.html](dashboard/index.html)） |
| `GET /ai/traces` | 轨迹摘要列表 + 总数 / 上限 |
| `GET /ai/traces/:id` | 单条完整轨迹（含所有事件） |
| `DELETE /ai/traces` | 清空 |

轨迹存于进程内存环形缓冲（[src/trace.ts](src/trace.ts)，默认 50 条，`TRACE_LIMIT` 可调），**不落盘、不持久化、不记录任何密钥**。所有展示内容按纯文本渲染（HTML 转义），避免战场里的可编辑文本注入面板 DOM。

> ⚠️ 面板与 `/ai/traces` 目前**无鉴权**，会显示完整战场状态与模型输出。仅用于本机/内网调试；若要部署到公网，请自行加访问控制或反代白名单。

## 测试

```bash
npm test        # 81 项：单元 + 集成（agent loop 场景矩阵 / 服务契约 / 难度预算对齐 / pi 端点 / 并发）/ GDScript 静态引用 / Godot 3.6.3 运行时解析 / 跨语言端到端契约

# 带真实端点跑（最后一项端到端测试仅在 LLM_BASE_URL + LLM_API_KEY 存在时启用，否则 skip）
LLM_BASE_URL=... LLM_API_KEY=... LLM_MODEL=... npm test
```

覆盖：

- 服务侧 `validateTurnRequest` / `validateAction` / `validateToolResult` 与 Godot 侧 `ActionValidator.accept_action` 同规则
- 工具注册表恰好 9 个：4 只读 + 4 动作 + `end`；**不含 read/write/edit/bash**，有回归断言
- 白兵战工具表恰好 4 个，与战役工具完全不重叠；`set_order` 按兵种单独设置
- 白兵战多回合：3 个战斗回合连续下命令，会话全程存活（防 `max_tool_calls` 跨回合累加回归）
- `move` 路径：`legal_actions` 带逐格 `path`，服务端与 Godot 双侧校验无斜向移动
- `stub` 模式端到端跑通 `pi-agent-core`：会话内读动作 → 执行 → `end`
- HTTP 五态（ok / error / budget_exhausted / invalid / 静态路径穿越）
- GDScript 静态校验：项目单例引用、flow 绑定、继承目标、`wab` 接口方法、注释标注

### 集成测试（`test/agent-loop.test.ts` / `test/scenarios.test.ts`）

`test/harness.ts` 提供脚本化模型：注入 `decide({ runtime })` 后，**agent loop、工具、钩子、预算、校验、轨迹全是生产代码**，只有「模型输出」这一层被替换，因此不需要真实端点或外网就能复现各种 agent 行为。

| 场景 | 断言要点 |
|---|---|
| 首轮直接给动作 | 1 turn / 1 tool call，动作工具之后不再请求模型 |
| 多轮工具 | 后一轮模型能看到前一轮 `tool_result` |
| 非法动作自纠错 | 拒绝原因回传给模型，模型改给合法动作后成功 |
| 只回文本不给动作 | 422 `agent_budget_exhausted`，轨迹记为 error |
| 死循环（永远回只读工具） | 恰好在 `max_turns`（100）处收敛 |
| 推理中模型报错 | 不产生伪成功动作，`status=error` |
| `max_tool_calls` | 只统计动作工具；超出那次被 `beforeToolCall` 拦下（`ok:false`）。只读侦察不计数 |
| 跨回合记忆 | 难度 4 第二次请求带上上一回合 `intent` / `turns` |
| 多侧并发 | 两个决策同时进行，`action` / `intent` / 会话记忆互不串线 |
| `history` 回灌 | 上一轮动作与结果进入本次 user message，模型据实调整 |
| 难度预算 × Godot 超时 | 服务端 `timeout_ms`（30s）严格早于 Godot `TIMEOUT_SEC`（32s），两侧常量同步 |
| 端点挂起 | 服务端在 `budget.timeout_ms` 内返回 504 `agent_timeout`（不挂到连接超时） |
| pi 端点故障 / 缺密钥 | 非 200 且不带 `action`；缺密钥 503 `api_key_missing`，不静默降级 |
| pi 端点端到端 | 假 `/v1/chat/completions` 走真实 `createCustomRuntime`，校验 9 个工具声明与 `tool` 消息回灌 |
| 用户可编辑文本注入 | 指令注入载荷不改变决策，面板不内联轨迹 |

**逐步交互的预算**：每次决策只定一个动作，推理量远小于整侧计划，故三档为 `max_turns` 100/100/100、`max_tool_calls` 100/100/100（只统计动作工具，只读侦察不占预算，两个 100 都只作死循环兜底，实际节奏受 30s 空闲超时约束）；超时是**每动作独立 30s**（不是回合总预算），Godot 客户端 32s，服务端恒早 2s 返回 `504 agent_timeout`。回合内动作序列由 Godot 用 `history` 回传，服务端无状态。

> 两侧超时常量必须同步修改：`agent-service/src/config.ts` 的 `BUDGETS` 与 `bwdl/packed/sgz_script/war/AI/War_AI_behavior_llm.gd` 的 `TIMEOUT_SEC`，`test/scenarios.test.ts` 会断言两者差 ≥1s。

## Godot 3.6.3 运行时校验

已在 `../.tools/` 下载 Godot 3.6.3 Linux headless（不入库）：

```bash
make check GODOT="$PWD/.tools/Godot_v3.6.3-stable_linux_headless.64"
.tools/Godot_v3.6.3-stable_linux_headless.64 --no-window --path bwdl \
    --script res://test/ai_agent_validate.gd
```

`npm test` 中的 `test/godot3-parse.test.ts` 会自动调用该二进制（也可用 `GODOT3_BIN` 指定），强制 `load()` 五个 AI 相关脚本并扫描日志中的 Parse Error；未安装时自动 skip。另有一个 `make check` 等价的 `--editor --quit` 检查。校验脚本位于 `bwdl/test/ai_agent_validate.gd`。

**实测结果**：`make check` exit 0、零 `SCRIPT ERROR: Parse Error`；五个脚本全部 `load()` 成功。校验过程中发现并修复了 `AIHttpClient.gd` 的 `HTTPRequest.request()` 参数顺序错误（Godot 3.5 第 4 参是 `method`，请求体是第 5 参）。

## 跨回合记忆

`diffculities=4` 时按 `session_id` 保存 `intent` / 上回合计划结果 / 回合数（`src/session.ts`，TTL 30 分钟），并在下一次请求的 `memory` 字段注入。2/3 档不写记忆。

> 设计文档写的是 `pi-durable`，实测它是**独立的 Harness**（自带 Conversation/Task 模型，标注 Experimental），引入会替换而非补充已验证的 `pi-agent-core` agent loop。按 YAGNI 保留设计真正需要的轻量会话状态，不引入该依赖重写。

## 容器化

```bash
docker build -t 3k-war-agent agent-service/
docker run --rm --read-only --tmpfs /tmp -p 8060:8060 \
  -v "$PWD/bwdl/build/web:/app/web:ro" \
  -e K3G_AGENT_MODE=mock \
  3k-war-agent
```

非 root 运行、只读根文件系统、web 资源只读挂载；出站白名单由外层网络策略控制（`--network=none` 可用于 mock/stub，`pi` 模式需放行 LLM provider）。

已实测：`docker build` 成功；`docker run --rm --read-only --tmpfs /tmp -p 8060:8060` 下 `/ai/health` 返回 200。构建时统一 `chmod a+rX /app/src`，避免宿主机源文件 600 权限导致容器内非 root 用户读不到 `.ts`。

## 隔离 Godot 3 harness

`gdharness/` 是一个最小 Godot 3.6 工程（桩化 autoload 与战场对象），`test/gdscript-contract.test.ts` 会：

1. 从 `bwdl/packed/sgz_script/war/AI/` 复制当前真实脚本到 `gdharness/ai/`（该目录已 gitignore，避免副本漂移）
2. 启动同进程 mock 服务，用 Godot 3.6.3 headless 运行 `StateProjection.gd` / `ActionValidator.gd` / `AIHttpClient.gd`
3. 把 Godot 生成的 payload 通过**真实 HTTP POST** 发给服务，断言 `AI_HTTP_RESULT=0_200`
4. 用两侧校验器分别校验返回的 `plan[]`

未安装 Godot 3 时该测试自动 skip（`GODOT3_BIN` 可指定二进制）。

> `static_bundle_id` 目前是常量 `v1`，按 YAGNI 有意不做静态数据装载：全知去噪投影只发送运行时派生状态，请求中本来就不含静态 JSON。

## 已验证的 §11 待定项

| 待定项 | 结论 |
|---|---|
| `pi-agent-core` 能否只挂自定义工具、完全禁用内置工具 | ✅ `pi-agent-core` 包内不含任何内置工具（read/write/edit/bash 在 `pi-durable/dist/tools/`，本服务未导入）；`initialState.tools` 完全由调用方提供，实测只有 4 个只读 + 5 个动作工具 |
| 动作工具能否限定到本次 `legal_actions` | ✅ 按 `{actor,pos/target}` 在 `legal_actions` 中查找，找不到即抛错回灌模型自纠错；另由服务 `validateAction` + Godot `ActionValidator.accept_action` 双重兜底 |
| Godot 3.6.3 headless 能否解析新增脚本 | ✅ `make check` + `load()` 校验通过，零 Parse Error；修复 1 处 `HTTPRequest.request` 参数顺序错误 |

## 边界

- 服务**只返回选择**，不实现任何游戏公式、不判 RNG/命中/伤害、不改状态、不访问宿主文件/进程/网络
- Godot ↔ 服务每回合 **1 次** HTTP；服务内部 `pi-agent-core` 多步工具调用不产生额外浏览器往返
- 在线 AI 仅在「大模型」难度开启，服务不可用 / 超时 / 非法 → 静默回退 `War_AI_behavior_hard.gd`
