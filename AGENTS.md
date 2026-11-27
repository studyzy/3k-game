# AGENTS.md

本文件给在本仓库工作的 AI / 自动化助手看：项目有哪些部分组成、改动落在哪里、怎么自测。
它描述「当前代码事实」，与 `README.md`（面向人、偏反编译背景）和 `agent-service/README.md`（服务端细节）互补。

---

## 1. 项目是什么

把安卓游戏《霸王的大陆 GD2560》（三国志2 复刻，Godot 3.5.3 导出）反编译成可编译工程，并在其上做两件事：

1. **100% 复刻**原版数据与规则逻辑（数据表、公式、AI 行为）；
2. **接入 LLM 敌方 AI**：把战争 / 白兵战的敌方决策换成远程大模型 Agent。

- 引擎：**Godot 3.6.3**（GDScript 1.0 语法，绝不能用 Godot 4 打开/导出）。
- 主交付物：`bwdl/`（Godot 工程）。
- AI 决策服务：`agent-service/`（Node.js + TypeScript，Pi agent-core）。

---

## 2. 仓库结构

| 路径 | 说明 |
|---|---|
| `bwdl/` | 反编译后的 Godot 3.5.3 工程（脚本/场景/资源） |
| `bwdl/script/` | 框架脚本（反编译自 `.gdc`），**原则上不改**，改动集中在 `packed/` |
| `bwdl/packed/sgz_script/` | 原作者明文规则脚本（1192 个 `.gd`，带中文注释），游戏逻辑主战场 |
| `bwdl/packed/data/` | 游戏数据 JSON（武将/城市/技能/剧本…），可直接改；剧本在 `data/drama/<剧本>/` |
| `bwdl/packed/images/` | 运行时图片资源 |
| `bwdl/scene/`、`bwdl/windows/` | 场景脚本、UI 控件脚本 |
| `agent-service/` | LLM 敌方决策服务（回合会话 + 白兵战异步 tick + 云存档 + 网页托管 + 调试面板） |
| `tools/` | Python 数据流水线（人物表同步、头像生成、剧本武将分配等） |
| `docs/` | 设计文档：`plans/`（实施计划）、`superpowers/specs/`（已落地规格）、`actors_expansion/`（人物库） |
| `Makefile` | 唯一的构建/运行入口，优先用它，不要手敲长命令 |

---

## 3. 两个 AI Agent（重点）

LLM 敌方 AI 由**两套彼此独立的 Agent** 实现，协议、生命周期、回退策略都不同。
两者共用：`DataManager.ai_agent_mode` 开关、「大模型」难度、同一个服务端地址、同一个 `/ai/dashboard` 调试面板。
改其中一套**不要顺手改另一套**，除非需求明确要求。

### 3.1 总览对比

| 维度 | ① 回合制战场 Agent | ② 白兵战异步 Agent |
|---|---|---|
| 战场范围 | 大地图战争场景（`sgz_script/war/`） | 白兵战（两军对阵，`sgz_script/battle/`） |
| 决策模型 | **服务端驱动的会话循环**：LLM 调工具 → Godot 执行 → 回传 → LLM 继续，直到调 `end` | **客户端驱动的时间片**：Godot 每 3 秒推一次快照，LLM 吐一份 JSON 计划 |
| 一次交互 | 一个**整回合**（LLM 连续指挥多个武将、多个动作） | 一拍（约 3 秒）一个**增量计划** |
| 是否用工具 | 是，10 个工具（5 只读 + 4 动作 + `end`） | 否，纯 JSON 输出，无工具、无 `end_turn` |
| 服务端文件 | `src/agent.ts`、`src/session.ts`、`src/tools.ts` | `src/battle-agent.ts`、`src/battle-session.ts`、`src/battle-plan.ts` |
| Godot 文件 | `war/AI/War_AI_behavior_llm.gd`（`wab` 实现） | `battle/AI/BattleAgent.gd` |
| 挂载点 | `war/AI_control.gd:37` | `battle/Battle_Auto_Run.gd:28` |
| 回退规则 AI | `War_AI_behavior_hard.gd`（整回合剩余动作全回退） | `battle/AI/AI_Control.gd`（本场后续拍回退） |
| 超时语义 | 空闲超时 30s（服务端）／32s（Godot） | 单拍 20s（服务端）／25s（Godot） |
| 失败阈值 | 任一次失败即整回合回退 | 连续 3 次失败才回退 |

### 3.2 ① 回合制战场 Agent（war）

**服务端驱动的长轮询会话**。一个 AI 回合 = 一个服务端 `TurnSession`：

```
Godot                                    服务端
  POST /ai/turn                →  创建会话，后台跑 agent loop
  GET  /ai/turn/:id/pending    ←  取到动作（或 progress / ask / end）
  执行动作、重算状态
  POST /ai/turn/:id/result     →  把最新 units/legal_actions 回灌给 LLM
  ...                              LLM 看到结果继续决策 ...
  GET  /ai/turn/:id/pending    ←  {type:"end"} → AI_end，回合结束
```

要点：

- **`end` 是唯一终止工具**。没有「单个武将结束行动」，机动力耗尽的武将只是不再可指挥，LLM 继续指挥其他人。
- **Godot 只做「工具实现」**：开会话、取动作、执行、算执行后状态、回传。所有决策在服务端循环里。
- **只读查询链路**：LLM 可调只读工具（`inspect_*`、`list_legal_actions`、`estimate_stratagem` 等）。需要引擎算数的（用计命中率/伤兵预估）会以 `{type:"ask", asks:[…]}` 下发，Godot 算完 `POST /ai/turn/:id/estimate` 回传。**`_on_polled` 必须处理 `ask` 分支**，漏掉会直接降级本地 AI。
- **界面进度**：模型思考文本与只读侦察以 `{type:"progress"}` 下发，Godot 显示在战争界面底部黄色消息区，不占决策预算、不需要回传。
- **预算**（`src/config.ts` 的 `BUDGETS`，按 `diffculities` 取档）：`max_actions` 16/24/32，`max_turns`/`max_tool_calls` 各 100 仅作死循环兜底，`idle_timeout_ms` 恒 30s。
- **超时常量两侧联动**：`src/config.ts` 的 `BUDGETS.idle_timeout_ms` 与 `War_AI_behavior_llm.gd` 的 `POLL_TIMEOUT_SEC`（20s）／服务端 30s 须保持「服务端恒早于 Godot 返回」。`test/scenarios.test.ts` 有断言。
- **提示词**：`src/agent.ts` 中 `PROMPT_ROLE / PROMPT_STRATEGY / PROMPT_TACTICS / PROMPT_RULES / PROMPT_OUTPUT` 五段拼接，见 `docs/plans/2026-11-26-war-ai-prompt-optimize-design.md`。

### 3.3 ② 白兵战异步 Agent（battle）

白兵战是**准实时**的：玩家随时暂停、改命令、用计，引擎不会等 AI。

- 一场战斗 = 一个 `BattleSession`，同一对话上下文从开场维持到结束（只保留 system + 最近若干拍）。
- Godot 每 **3 秒**一拍 `POST /ai/battle/:id/tick`（上一拍未返回就跳过该拍）；暂停态（暂停面板 / 对话框 / `view_model >= 0`）降为 **10 秒**一拍。
- 模型一次输出一份 JSON：`{orders:{兵种:命令}, tactic:名字|null, memory, reasoning}`。
  - `orders` 是**差分**：只写要改的兵种，不想改就 `{}`；命令取值 `前进/待机/后退`（即 `BattleOrder`）。
  - `tactic` 每拍至多一个，必须是快照里 `legal_tactics` 中的名字。
  - `memory` 由服务端保存，下一拍原样回喂（模型的跨拍短期记忆）。
- **Godot 立即应用 `orders`**；`tactic` 排队到 flow 空闲且处于安全步骤时才执行（`AI战术武将`/`AI战术名称` 两个 env 键延迟取值，避免玩家暂停改当前武将后错施）。
- **无工具、无长轮询、无 `end_turn`**。会话结束靠 `POST /ai/battle/:id/end`，或 `battle_over` / 单挑往返等路径由 `BattleAgent` 自己收尾；结算期须用 `_closed` 防止给已分胜负的战斗重开会话。
- **失败处理**：连续 3 次（`MAX_ERRORS`）失败 → 本场后续回退 `AI_Control.gd`；单拍服务端超时 20s（`TICK_TIMEOUT_MS`），Godot 请求超时 25s（`REQUEST_TIMEOUT_SEC`）。
- **快照**：`BattleProjection.gd` 生成 v2 快照（双方兵种血量/数量/命令、与敌主将距离、射程、buff、`legal_tactics`、上一拍计划回执 `last_plan`）。
- **提示词**：`src/battle-agent.ts` 的 `BATTLE_SYSTEM_PROMPT`，含命令真实含义、伤害与 C 值、射程、计策说明、决策顺序。`BATTLE_MAX_TOKENS` 600。

### 3.4 共同约定

- **开关**：只有在标题界面选中「大模型」难度时 `DataManager.ai_agent_mode = true`，两套 Agent 才启用；其他难度**零网络请求**。「大模型」不新增 `diffculities` 档位（数组按下标取值会越界），复用挑战档(4)参数。
- **地址**：环境变量 `K3G_AI_AGENT_URL` > `user://ai_agent.cfg` > 平台默认（Web 用同源 origin，桌面 `http://127.0.0.1:8060`），统一由 `DataManager.resolve_ai_agent_url()` 解析。
- **服务不可用 / 超时 / 非法输出 → 静默回退本地规则 AI**，绝不阻塞玩家。
- **服务端边界**：只返回选择，不实现任何游戏公式、不判 RNG/命中/伤害、不改状态、不访问宿主文件。
- **调试面板** `GET /ai/dashboard`（`/ai/traces` 配套）显示两套 Agent 每步完整对话、工具调用、最终计划。**无鉴权**，仅本机/内网使用。

---

## 4. 常用命令

```bash
# Godot 工程
make setup        # 下载项目内 Godot 3.6.3（已在本仓库 Godot_3.6.3.app/）
make import       # headless 导入资源（改了资源/新增文件后需要）
make run          # 运行游戏
make edit         # 打开编辑器
make check        # headless 校验（--editor --quit，不保证抓到语法错，见下）
make build        # 导出 macOS app
make web          # 导出 WebAssembly 到 bwdl/build/web/
make serve        # 纯静态预览网页版
make serve-agent  # 用 agent-service 托管网页版（含云存档 / AI Agent）
make apk          # 导出 Android release APK

# 决策服务
cd agent-service
npm --cache ../.npm-cache install --ignore-scripts   # 首次（本机 npm 默认缓存只读）
npm start                                            # 默认 mode=mock, port=8060
node --env-file=.env src/server.ts                   # 真实 LLM（K3G_AGENT_MODE=pi）
npm test                                             # 单测 + 集成 + GDScript 契约
```

### 校验脚本语法（可靠做法）

`make check`（`--editor --quit`）会在资源扫描完成前中止，**不保证**发现语法错。单文件校验用：

```bash
godot --no-window --path bwdl --check-only -s res://packed/sgz_script/war/AI/War_AI_behavior_llm.gd
```

项目自带大量 clEquip / clVState / Static_Manager 循环引用的 Parse Error 噪音（反编译既有），要区分噪音与真实错误。

`agent-service` 侧的 `test/godot3-parse.test.ts` / `test/gdscript-contract.test.ts` 会用 Godot 3.6.3 headless 真正 `load()` AI 相关脚本并通过真实 HTTP 跑契约，未装 Godot 时自动 skip。

---

## 5. 改动落点速查

| 需求 | 改哪里 |
|---|---|
| 战场 Agent 决策/提示词 | `agent-service/src/agent.ts`（工具在 `tools.ts`，会话在 `session.ts`） |
| 白兵战 Agent 决策/提示词 | `agent-service/src/battle-agent.ts`（计划解析/校验在 `battle-plan.ts`） |
| 难度预算、超时 | `agent-service/src/config.ts`（`BUDGETS`）+ 对应 Godot 侧常量，**必须同步** |
| 战争侧工具执行/状态投影 | `war/AI/StateProjection.gd`、`ActionValidator.gd`、`StratagemProjection.gd` |
| 白兵战快照内容 | `battle/AI/BattleProjection.gd`、`TacticProjection.gd` |
| 白兵战 tick 状态机 | `battle/AI/BattleAgent.gd`、`BattleHttpClient.gd` |
| 游戏规则/公式 | `bwdl/packed/sgz_script/{war,battle,affiars,...}/` |
| 武将/城市/剧本数据 | `bwdl/packed/data/`，剧本专属在 `data/drama/<剧本>/` |
| 人物库与头像 | `tools/sync_actors.py`、`tools/avatar_gen/`、`tools/scenario_roster/`（详见 `docs/actors_expansion/`） |

---

## 6. 工程约定与坑

- **GDScript 1.0 语法**：不能用 Godot 4 的 `@onready`、类型化 lambda、`PackedByteArray.slice` 等写法；`HTTPRequest.request()` 在 3.x 中第 4 参是 `method`、请求体是第 5 参（曾踩）。
- **`Global.load_script` 有缓存**：命中缓存会重放成员初始化并重跑 `_init()`，所以 `BattleAgent.gd` 的成员状态保不住，靠 `tick()` 自愈绑会话。
- **不要改 `diffculities` 数组长度**：大量规则数组按下标取值；「大模型」复用挑战档参数 + `ai_agent_mode` 标记。
- **导出**：`export_presets.cfg` 是 ConfigFile 格式，注释符是 `;` 不是 `#`；`include_filter="*.json, *.pck"` 必须保留，否则裸 JSON/PCK 不进包、装机闪退；各预设带 `exclude_filter="build/*"`。
- **资源导入标记**：`bwdl/.import-complete`（在 `.import` 目录外），`make check` 会删它强制重导入。
- **两侧契约必须成对修改**：任何 Godot ↔ 服务端的字段/路由/超时改动，都要同时改 `src/validate.ts`（或对应校验器）与 Godot 侧发送/解析，并跑 `npm test`（含 `test/gdscript-contract.test.ts`）。
- **密钥**：`agent-service/.env` 已被 gitignore，绝不要提交真实 `LLM_API_KEY`。
- **数据类改动要可重跑**：`tools/` 下脚本应幂等，改完用对应校验脚本核对（如 `tools/scenario_roster/check.py`）。

---

## 7. 主要文档索引

| 文档 | 内容 |
|---|---|
| `agent-service/README.md` | 服务端完整说明：协议、配置、模式、测试、容器化 |
| `docs/plans/2026-11-25-battle-ai-async.md` | 白兵战异步 tick 重构 |
| `docs/plans/2026-11-26-war-ai-prompt-optimize-design.md` | 战场 Agent 提示词重构 |
| `docs/superpowers/specs/2026-11-19-stratagem-estimate-tools-design.md` | 用计预估只读查询 |
| `docs/superpowers/specs/2026-11-21-web-cloud-save-design.md` | 云存档 |
| `docs/actors_expansion/` | 人物库跨朝代扩展明细 |
