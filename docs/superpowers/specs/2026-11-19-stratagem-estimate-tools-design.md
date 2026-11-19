# 计策估值工具（stratagem estimate tools）设计

- 日期：2026-11-19
- 范围：**只做计策这条线**。攻击估值（`estimate_attack`）明确不做，见「非目标」。
- 关联：[agent-service/README.md](../../../agent-service/README.md)、[StateProjection.gd](../../../bwdl/packed/sgz_script/war/AI/StateProjection.gd)、[War_AI_behavior_llm.gd](../../../bwdl/packed/sgz_script/war/AI/War_AI_behavior_llm.gd)

## 意图

「大模型」难度的敌方 AI 现在对「用计」只有两个信息源：

1. `legal_actions` 里的 `stratagem` 项——只有 `actor/target/skill/cost`，**没有命中率、没有效果**；
2. [agent.ts](../../../agent-service/src/agent.ts#L88-L113) 手写的一段计策摘要——经过核对（见附录 A），**至少 9 处与引擎不符**：距离 1 惩罚写错、笼络/伪击转杀/共杀/劫火被误归入「固定档必中」、漏掉半数技能、借露与铁索语义错误、「十面埋伏=围困」不存在。

后果：LLM 只能靠心算的错误公式赌决策，经常用错地形、对带【神佑】的目标浪费高消耗计策、用超出机动力预算的计策。

目标：**给 LLM 一套由引擎权威计算的估计值**，让它在真正发出 `stratagem` 动作前先「算账」，用数字而不是幻觉做决策。

## 为什么不用 JS 复刻公式

曾认真考虑过在 `agent-service` 里用 TS 复刻 [clStratagem.gd](../../../bwdl/script/objects/clStratagem.gd)。放弃的两条硬理由：

1. **技能运行时修正不可复刻**：`get_rate()` 内部会触发 20017/20010，`get_available_targets()` 会触发 20021/20026，`_impact_for_soldier_damage()` 会触发 20029/20011/20002/20037。123 条【光环】+ 64 条【特殊】+ 78 条【诱发】技能随时改写概率、伤害、甚至目标集合（[skill.json](../../../bwdl/packed/data/skill_system/skill.json)：1675 条技能效果，其中 1052 条【锁定】）。这些逻辑写在各 `effect_XXXX.gd` 里，读的是 `DataManager` 运行时状态。
2. **两份实现必失真**：一旦游戏更新 `skill.json`/`stratagem.json`，JS 副本要么跟不上，要么被改坏没人发现。

**结论：估值的唯一权威计算源是 Godot。** 网络延迟按「低/可忽略」假设设计，代价转移到「轮次预算」上（见「代价」）。

## 目标 / 非目标

**目标**
- 新增 2 个只读预估工具，由 Godot 真实调用 `clStratagem.gd` 的只读方法算出，回传后由 LLM 用来决策。
- 预估过程**绝不改变战斗状态**、**绝不参与 AI 回合的硬性阻塞**：预估期间链路已是 `_posting`，LLM 也会因 `await session.estimate(...)` 拿不到下一轮，**不会出现 Godot 每步都点名估值的死锁**。
- 重写 [agent.ts](../../../agent-service/src/agent.ts) 第五节的计策提示词，删掉全部错误公式，改为「先估值，再决策」的流程说明。

**非目标**
- `estimate_attack` / `estimate_move` / `estimate_retreat`——不做。攻击公式牵涉 `clBattleFight` 的伤害、命中、地形加成，技能修正面更大，等计策这条线跑通再评估。
- 白兵战（`/ai/battle`）——不动。
- 玩家侧 UI——不动。
- 给 LLM 提供「预估结果的可视化」——不做。

**反目标**（做了就算失败）
- 预估时触发任何技能副作用（例如 20017 把 `计策.ONCE.附加智力` 写进 `DataManager`，20021 把光标/可选项写进 `SceneManager`）。
- 预估占用一个动作预算 `max_actions`。
- 预估结果被缓存后与下一次真实状态不一致（例如单位移动后仍返回旧率）。

## 约束

- 预算（[config.ts](../../../agent-service/src/config.ts#L14-L18)）：`max_turns 5`、`max_tool_calls 10`、`max_actions 32`、`idle_timeout_ms 30000`。估值**必须复用现有长轮询 / `_posting` 阻塞，不另起 HTTP 通道**。
- 协议（[types.ts](../../../agent-service/src/types.ts)）：`ToolName` 目前是 `move|attack|stratagem|retreat|end`；[validate.ts](../../../agent-service/src/validate.ts#L12) 用 `TOOLS` 白名单拦截其余 tool。
- Godot 3.6.3 语法（`Global.load_script`，`PoolXXXArray`、`.format()` 无命名槽）。
- 现有约定：Godot 侧「只发状态，不做决策」（[README](../../../agent-service/README.md#L194)）——本设计新增一条渲染约定：**估算结果由 Godot 渲染成短文本，Agent 原样转交**，理由见「架构」。

## 架构与协议

### 总体形态

```
LLM ──工具调用 stratagem_forecast/scan──┐
      Agent 注册 EstimateRequest           │ 同步等 Promise
      session.nextAction 返回 type:"estimate"│
Godot 长轮询收到 → _execute 分支         │
      StateProjection.build_estimate() 只读计算
      AIHttpClient.post(/result, {ok,outcome,...})
Agent session.submitResult 唤醒 Promise ──┘
      Agent 把 Godot 渲染的文本原样塞回 LLM
```

和现有 `move`/`attack` 唯一的区别：**`/result` 不会改变 `live.units/legal_actions`**（Godot 没改状态），`tools.ts:157-160` 照旧执行但写入的是同一份状态。

### 线协议（最小增量）

**Agent → Godot**（`GET /pending` 响应新增一种 `type`）：

```jsonc
{
  "seq": 7,
  "type": "estimate",
  "estimate": {
    "id": "est_1",              // 对应 legal_actions 里一条 stratagem 的 id
    "actor": 12,
    "target": 31,
    "skill": "火计"
  }
}
```

- 只用来点问题。**扫描**复用 `tactics`（Godot 自己枚举，见下），不用跨侧传输技能列表。
- `id` 来自当前 `legal_actions`，是最小且可验证的锚（找不到 id 时 Godot 回 `ok:false`）。

**Godot → Agent**（`POST /ai/turn/:id/result`）：

```jsonc
{
  "seq": 7,
  "ok": true,
  "outcome": "火计→#31",
  "units":      [/* 原样回传，未变 */],
  "legal_actions": [/* 原样回传，未变 */],
  "economy":    {/* 原样回传 */},
  "estimate": {
    "exact": true,
    "text": "…Godot 渲染的完整中文结论，见「输出示例」…"
  }
}
```

### 只读保护

新增 `DataManager.estimating: bool = false`。`War_AI_behavior_llm._estimate()` 期间置 `true`、结算后置回。`SkillHelper.auto_trigger_skill()` 在 `DataManager.estimating == true` 时**直接返回 false**（不执行任何 effect），从而：

- 阻断 20017（`计策.ONCE.附加智力`）、20010（`战争.计策概率`）、20021（UI 光标）、20026（`计策.ONCE.距离`）、20029、20011、20002、20037；
- 阻断装备「条件」公式（`get_equip_feature_int` → `Global.execute_expression`）里可能的随机数副作用——注意这条是**已经存在**的副作用（`get_equip_feature_total("计策附加智力")` 就会跑条件公式），本设计不改它，只是让估值路径**不额外增加**触发次数；真实结算时该触发的仍会触发。

「估值时跳过技能」是**有意的近似**：估值本来就不追求 100% 复现结算。输出里用 `exact:false` + `uncertain` 明示。

### 两个工具

一个共用参数模型：`{ actor: int, target: int, skill: string }`（`scan` 只传 `actor`），`stratagem_forecast` 对应一条 `legal_actions`，`stratagem_scan` 对应全部。

**`stratagem_forecast`**——精确点问一个目标：
- Agent 校验 `(actor,target,skill)` 能在**实时** `live.legal_actions` 里找到健康、未禁用、机动力够的条目；否则抛错（与 `findAction` 同款自纠错）。
- Godot 用该条目 `id` 直接定位，调用 `StratagemExecution` 只读估算（见下），返回完整估算。
- 用途：LLM 已锁定「想用火计打 #31」，想知道精确率和伤害区间。

**`stratagem_scan`**——全盘扫一遍：
- Agent 校验 `live.legal_actions` 里有该 actor 的 stratagem 条目吗？没有直接抛错。
- Godot **自己枚举**该 actor 的全部 `get_stratagems(-1,-1,true)` × 全部 `get_available_targets()`（含被禁选目标），逐个估值，按 `期望值/ap` 排序，返回渲染好的 Top-N 文本。
- 用途：开局、换目标时一次看清「这个武将现在最值得用哪招打谁」。
- 提供的理由：LLM 只有 10 次工具调用额度，逐个 forecast 会耗尽额度；scan 一次给出全盘答案。

### 估算算法（Godot 侧新建 `StateProjection.build_estimate(wv, req)`）

复用 `player_stratagem.gd` 的真实流水线 **只读剖面**：

| 步骤 | 调用 | 只读性 |
|---|---|---|
| 定位条目 | 按 `id` 在最近一次投影的 `legal_actions` 中找 | 只读 |
| 计策对象 | `DataManager.new_stratagem_execution(actor, skill)` | ✅ 只写 `DataManager.stratagem_execution`（覆盖，不叠） |
| 目标集合 | `se.get_affected_actors(targetPos)`（含范围扩散） | 只读（需 `estimating` 跳过技能） |
| 命中率序列 | `se.get_raw_rate(targets)` / `se.get_rate(targets)`，以及 `scheme.get_rate(from, to)` 逐目标 | 只读（跳过技能） |
| 伤害序列 | 对 `impact.soldier/hp/rice/heal` 公式做 `min/max` 替换后用 `Global.count_formula_number` 求值 | 只读（跳过技能） |
| 消耗 | `scheme.get_cost_info(actor)` | 只读（跳过技能） |

范围类计策（`is_area_targeting()`，即 十面埋伏/水伏/要伏）**不参与扫描**：`StateProjection` 本来就不把它们投影为合法动作（`StateProjection.gd:196`），且 `range:0/99` 的决策语义不同，等后续单独设计。

**公式的 min/max 求值**：`impact.soldier` 里 `random(9,13)` 这种区间，用**三组替换**分别求值：
- `lower`：`random(a,b) → a`
- `average`：`random(a,b) → (a+b)/2`
- `upper`：`random(a,b) → b`

`clStratagem.get_rate()` 已含 `Global.count_formula_number` 和距离、伤神修正，直接用；impact 求值沿用真实 `count_formula_number`，替换后不再有随机项。

### 输出示例（`stratagem_forecast`，火计打 #31）

```text
【火计 → #31 徐晃】
命中率 78%（距离4、知12对9；未含技能修正，可能有 ±）
伤害区间 420 ~ 620，期望 520 兵（兵力1200，经验倍率 x1）
消耗 5 机动力（当前 7）｜CD 无
地形：目标【平原】符合【平原、树林】；我方可在原位施放
邻接修正：目标与我方【不相邻】，无【计策相邻增伤】
风险：目标无【神佑】/【潜行】/【铁索】；射程内无伏兵区
⚠ 估值未调用技能/装备条件触发，actual 可能 ±10%
结论：用计可行，期望 520 兵 / 5 机动力
```

`scan` 同理，只是不带长尾结论，只列 Top-N：

```text
【#0 张辽 全盘估值】机动力 8，可用 4 招
#1 火计 → #1 诸葛亮：率 45%，期望 210，性价比 42（推荐）
#2 落石 → #7 曹仁：率 85%，期望 180 伤体，性价比 36
…
```

### Agent 侧改动

| 文件 | 改动 |
|---|---|
| `types.ts` | 新增 `EstimateRequest`；`ToolName` **不改**（估值不当作动作枚举）；`ToolState` 加 `estimates: number` |
| `tools.ts` | 新增 `stratagem_forecast`、`stratagem_scan` 两个 `AgentTool`，`execute` 走 `session.estimate(...)`（新增方法，与 `emitAction` 对称）；`beforeToolCall` 增加 `max_estimate_calls` 计数 |
| `session.ts` | `estimate(req)`：加入 `_pending`，同 `emitAction`，但 resolve 时只把 `estimate.text` 塞回，不写 `live.units/legal_actions` |
| `config.ts` | `Budget` 加 `max_estimate_calls: 3`（难度 2/3/4 同值；可后续按难度区分） |
| `agent.ts` | 工具数组追加 2 个；`SYSTEM_PROMPT` 第五、八节重写（见下） |
| `validate.ts` | `validateToolResult` 允许 `estimate`；`checkActions` 不涉及 |

**提示词重写规则（只改计策相关的两段，攻击/粮草/撤退不动）**：

删除：距离 1≈+10 的错误说明、笼络/伪击转杀/共杀/劫火 被当作「固定档必中」、借露/铁索/十面埋伏的语义描述、手写伤害公式。

改为：
1. **流程**：本回合首次涉及计策时先 `stratagem_scan`；对候选前 2~3 项用 `stratagem_forecast` 复核；确认后发 `stratagem`，**不要**再自己算率。
2. **可信度**：`stratagem_forecast` 的 `exact:true` 表示「公式层确定」；任何 `⚠` 行都意味着有技能/装备条件可能微调，实际可与估值不同，不需要重新估。
3. **保留**依然成立的常识：知差取 `max(0,..)`、伤神减半、地形硬门槛、机动力不足会只花体力。
4. **细节**：`legal_actions` 里每条 stratagem 的 `id` 可直接用作 `forecast` 的参数，不再需要 LLM 自己拼。

## 代价

- 每回合最多 3 次估值（`max_estimate_calls`），每次一次往返。低延迟假设下估算 50ms 级别，**远小于 30s 空闲预算**。
- LLM 多花 1~2 轮工具调用（在 5 轮预算内）。如果实测频繁打满 `max_tool_calls`，可把 `max_estimate_calls` 下调到 2 或把 `max_tool_calls` 上调到 12（改 `config.ts` 一处）。
- Godot 侧多了「只读估算」分支和 `estimating` 开关，不碰任何既有结算逻辑。

## 风险与缓解

| 风险 | 缓解 |
|---|---|
| 估值期间技能被触发 | `DataManager.estimating` + `SkillHelper.auto_trigger_skill` 早返回（见「只读保护」） |
| `Session` 与动作通道互相抢占 | `session.estimate()` 复用同一串行 `_pending` 队列；预估**不是**合法动作，`state.executed`（`max_actions`）不计 |
| Godot 侧没实现 `build_estimate` 时旧版仍工作 | Agent 静默降级为「工具返回 `unavailable`」，LLM 继续按 `legal_actions` 决策；现有 81 项测试不受影响 |
| `DataManager.new_stratagem_execution` 覆盖 `stratagem_execution` | 预估期间不能与真实施计交错——`_posting` 串行保证了这点；预估结束后 `stratagem_execution` 里残留一个 `fromId==actor` 的空壳，**不影响**后续 `new_stratagem_execution`（每次都会新建） |
| 范围计策无法估 | 明确不做；`StateProjection` 本来不投影它们，LLM 无从选择 |

## 分阶段落地

1. **P1 协议 + 空壳**：`types.ts`/`validate.ts`/`session.ts`/`tools.ts` 支持 `estimate` 往返，Godot 侧 `_execute` 接 `estimate` 但只回 `{exact:false, text:"估值尚未实现"}`。用 stub 模式就地跑通，断言不自锁、不占动作预算。
2. **P2 计算器**：`StateProjection.build_estimate()` + `DataManager.estimating` + `SkillHelper` 早返回。`stratagem_forecast` 完成。
3. **P3 扫描**：`stratagem_scan` 枚举 + 排序 + Top-N 渲染；契约测试用 `gdharness` 的 Fake 计策对象覆盖。
4. **P4 提示词**：重写第五节、第八节，跑一遍 `pi` 端到端冒烟（真实端点），观察 LLM 是否**先 scan 再 forecast 再 commit**。

每一阶段的验证：
- P1：`npm test` 全绿 + 新场景「估值请求不进入 `max_actions`、不改变 `live`」。
- P2、P3：`estimate.ts` 不存在，所以断言在 **Godot 侧真算的数值**：用 `gdharness` 构造 2 个武将、1 条火计，断言渲染文本含预期命中率与伤害区间。
- P4：`pi` 模式对真实端点跑 1 个回合，检查 `traces` 里出现 `tool_call: stratagem_scan` / `stratagem_forecast`，以及回合内动作是否≥1 个。

## 附录 A：现有提示词 vs 引擎（本次要修的偏差）

| 提示词写的 | 引擎实际 | 处理 |
|---|---|---|
| 距离 1 ≈ +10、距离 3 为 0、距离 6 约 −15 | 距离 1/2/3/4/5/6 → −5/0/+5/0/−5/−10/−15 | 删（改由 forecast 给） |
| 落雷/离火/飞砂/走石/呼风/唤雨/要伏/水伏 = 100 必中 | 公式确实=100，但**要伏/水伏/十面埋伏 是范围类，不在 LLM 可见动作里** | 删 |
| 笼络/伪击转杀/共杀/劫火 = 通用档 | 笼络、空城计是特殊公式 | 删 |
| （摘要未提火箭） | `leaderOnly:1`，只能打主将 | 改由 forecast 明示 |
| 伤神 → 命中减半 ✅ | ✅ 正确 | 保留 |
| 知差取 `max(0,..)` ✅ | ✅ 正确 | 保留 |
| 借露「别指望用计」 | 借露只挡攻击/主动技能，不挡计策 | 删 |
| 十面埋伏/伏兵 = 围困 | 十面埋伏只写伏兵区域，**没有围困** | 删 |
| 计策耗 4~12 | 基础 ap 4~12，但装备【计策消耗减少】会降 | 删 |

## 附录 B：已确认的既有事实（本设计依赖）

- 核对（`StateProjection.gd` 与 `clStratagem.gd` 逐行比对）：`StateProjection._append_stratagem_actions()` 已用 `scheme.get_available_targets()` 过滤，所以 `legal_actions` 里的 stratagem 条目**本身就是合法**的（技能副作用除外）。
- `ActionValidator.accept_action`（Godot 侧）只校验 `actor/target/skill` 存在且机动力够，**不校验命中率**。
- `War_AI_Strategy._get_score_of_strategy_to()`（Local hard AI）已有同类评分公式：`效果值 × rate / cost`、远距 ÷2、近距 ×1.5。**本设计的 `scan` 排序与其同口径**，避免两套 AI 给出矛盾建议。