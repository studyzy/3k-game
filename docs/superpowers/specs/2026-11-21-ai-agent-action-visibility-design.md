# 2026-11-21 AI Agent 战争提示词：动作清单退场与字段速查

状态：已批准（2026-11-21）；同日复评修正（见文末「复评修正」），待用户确认后进入实现计划。

## 意图与 why

开场 user 消息把 `legal_actions` 整块塞进「本轮次」JSON，但它有三个问题：

1. **不可读**：键是引擎内部缩写（`ap` / `poker` / `attrs`），提示词里没有一处解释。模型同时看到 system 的「火计 6」和清单里的 `cost: {ap: 2}`（`StateProjection.gd:203` 写死），两个数字互相矛盾。
2. **不精确**：用计真实消耗由 `clStratagem.get_cost_ap()` 计算，会扣掉武将装备的「计策消耗减少」（`clStratagem.gd:94-99`）。写死的 2 既不是火计的 6，也不含装备减免。
3. **冗余**：清单按「目标」展开——同一个武将的同一计策打 5 个目标就是 5 条完整记录；`end` 每个武将各一条（`StateProjection.gd:128-130`），但 `end` 结束的是整个回合。每执行一个动作，tool result 还会把 `units` + `legal_actions` 整份再回传一次（`tools.ts:191-199`）。

同时，模型要判断「谁能干什么」还缺字段：`units` 里没有计策列表，`inspect_unit` 返回的是同一份对象；也没有攻击距离；**也没有任何字段能告诉它谁是主将**——而 system 的第一条战术就是「杀敌方主将」。

目标：让这段 JSON 自解释、变短，同时不降低动作合法性保障。

## 目标 / 非目标 / 反目标

- **目标**：`legal_actions` 不再出现在提示词；`units` 自带能力与真实消耗；主将可识别；system 有字段速查；猜错动作时服务端给候选，模型当回合自纠。
- **非目标**：不改 Godot 执行路径与 `_fallback` 策略；不改战斗引擎数值；不改白兵战 `BATTLE_SYSTEM_PROMPT`；不增删工具（`list_legal_actions` 只调输出）；不引入显式 `cache_control`。
- **反目标**：把 `legal_actions` 改个名继续全量下发；把字段说明写进动态段（逐轮计费且更乱）；让模型在没有任何技能字段的情况下自己猜「谁会什么计」；给出比引擎更宽的合法性信号（例如「有退路」写成「能撤退」）。

## 现状与约束（代码事实）

- `StateProjection.build()` 返回 `legal_actions`，按 `(actor, tool, 目标)` 逐条展开；动作项带 `id`（`a`/`s`/`r`/`mv`/`e` 前缀）、`cost`、`hint`。
- 服务端 `runAction` 靠 `findAction(live.legal_actions, ...)` 定位动作，再用 `validateAction(target.id, ...)` 校验；`id` 同时下发给 Godot 的 `ActionValidator.accept_action`。
- `validateAction` 会按 `cost` 与 `unit.ap/poker` 比较（`validate.ts:131-137`）。所以把用计 `cost.ap` 从 2 改成真值 6 会让「机动力不够」在服务端就被拦下，而不是等 Godot 执行失败。
- Godot `behavior()` 在 `_execute` 返回 false 时直接 `_fallback("exec_failed:...")`，本回合剩余交给规则 AI（`War_AI_behavior_llm.gd:318-323`）。所以「模型提出非法动作」绝不能直接落到 Godot。
- 撤退的真实条件比 `get_retreat_city_id() >= 0` 严得多：`_retreat()` 还查围困、兵力/体力/受伤、剧情模式、主将是否有队友（`War_AI_behavior.gd:185-205`）。`legal_actions` 里的 retreat 项本身只是粗筛。
- `SYSTEM_PROMPT` 有 4 处依赖清单：第 40 行「legal_actions 只列 attack/stratagem/retreat」、第 73 行「开场已给全量合法动作」、第 136 行「开局看一次 list_legal_actions」、第 143 行「必须来自 legal_actions」。
- 静态段有测试断言禁止出现 `turn_key` / `day` / `legal_actions` 等键名（`agent.test.ts:105-110`），因此字段速查只能放 system，不能放地图旁。
- `units` 当前不含 `skills` / `atk_range` / `main`。
- DeepSeek 自动前缀缓存按字节匹配；system 是稳定前缀，新增速查表只付一次费用。

## 决定

**用户已确认：**

1. `legal_actions` 从开场提示词里**完全删掉**，不做「挂到武将下」的折中。
2. 删法是「**按需查询 + 错时给候选**」：服务端仍保留清单用于校验，模型需要时调 `list_legal_actions(actor)`，猜错时返回该武将当前可选目标供其自纠。
3. **敌方 `units` 也带 `skills`**，让模型知道对手能放什么计。
4. 字段说明写进 `SYSTEM_PROMPT`，作为新增的一节。

**复评新增（本次待确认）：**

5. `units` 增加 `main: true` 标识主将。否则「杀主将」这条最高优先级战术无法执行。
6. 技能消耗键名用 `ap_cost`，不叫 `ap`——unit 的 `ap` 是剩余机动力，同名会制造新的歧义。
7. **不提供 `retreat_city` 字段**（原设计有）。`get_retreat_city_id()` 只代表「有退路」，不代表「能撤退」；把它放进 units 会让模型误判，进而触发 `exec_failed` 回退。撤退仍按 system 规则判断，不确定时查 `list_legal_actions(actor, tool="retreat")`。

## 消息形状

改后（`──` 仍是静态/动态分界）：

```
[system] …原规则… + 新增「十、字段速查（JSON 键的意思）」

[user]
你是守方。
战场地图：{ terrain: [...] }          ┐ 一场战斗内逐字节不变
──────────────────────────────────┘
本轮次：{ turn_key, controlled_vstate_id, day, max_days,
        main_city_pos, diffculities, memory }
敌方：{ units: [...], rice, money }
我方：{ units: [...], rice, money }
请你进行行动。
```

本轮次 JSON 不再含 `legal_actions`。`end` 仍留在服务端的清单里（见下），但不会出现在提示词。

## 数据契约

| 位置 | 改动 |
| --- | --- |
| `StateProjection.gd` unit 投影 | 可行动单位（`not disabled and has_position()`）增加 `skills: [{"name": "火计", "ap_cost": 6}]`（来自 `wa.get_stratagems()`，`ap_cost` 用 `scheme.get_cost_ap(actorId)`）、`atk_range`（`wa.get_attack_distance()`）、`main`（`wa.get_main_actor_id() == wa.actorId`）。`disabled` 或无位置的单位给 `skills: []`，`main` 照常输出。双方都带。 |
| `StateProjection.gd:_append_stratagem_actions` | `cost` 改为 `{"ap": scheme.get_cost_ap(wa.actorId)}`；引擎用计不扣点数，去掉 `poker`。 |
| `StateProjection.build()` | `legal_actions` 照旧生成并下发——它退为服务端的校验数据，不再进提示词。**不要删掉每个武将的 `end` 项**：`validateTurnRequest` 要求 `legal_actions` 非空（`validate.ts:79-80`），全员卡死时全靠它兜底。 |
| `agent.ts:buildUserMessage` | 动态 JSON 删 `legal_actions` 键。 |
| `tools.ts:runAction` | 动作结果摘要删 `legal_actions`；`units`/`economy`/`outcome` 保留。 |
| `tools.ts:list_legal_actions` | 保留按需查询，**默认只返回我方**；输出裁掉 `id` 与 `end` 行，只留 `tool/actor/target/skill/city/cost`。 |
| `tools.ts:findAction` 失败路径 | 错误文案改为「该武将当前可选」的候选清单（见下）。 |
| `agent-service/README.md` | 第 150 行 `StateProjection` 说明、第 190 行「`move` 路径：`legal_actions` 带逐格 `path`」（已过时）、第 273 行「找不到即抛错」同步为新口径。 |

`skills` 口径：`get_stratagems()` 已过滤未习得、冷却中、模式不符与攻方不能用的空城计，但**不过滤机动力是否够**。所以 `ap_cost` 是单价，够不够看 unit 的 `ap`；地形与目标合法性仍由引擎在执行时判定。`skills` 回答的是「这人会什么、每项花多少」，不承诺「此刻一定放得出」。

## 猜错时的反馈

`findAction` 找不到匹配项时，不再只抛一句「没有匹配的合法动作」，而是按同 `actor` + 同 `tool` 列出候选：

```
19 无法对 53 使用「火计」。19 当前可选：
  attack → 53
  stratagem 火计 → 53, 54
  retreat → 城3
```

分支要求：

- actor 不是我方 / 已阵亡 / 不在 units：明确说「19 不是你方武将」或「19 已无法行动」，不要输出空的「当前可选：」。
- 该 actor 有动作但该 tool 没有：只列其它 tool 的可行项，例如「19 现在不能攻击（距离不够），可以：stratagem 火计 → 53」。
- 候选截断到前 8 个目标，避免长清单把上下文吃掉。

模型在同一会话里改参数重试即可。因为服务端先用清单拦截，非法动作**不会**下发到 Godot，也就不会触发 `exec_failed` 回退。这是本方案不碰执行路径的前提。

## 提示词改动

新增 `## 十、字段速查（JSON 键的意思）`，覆盖：

- 顶层：`turn_key`（回合标识，仅用于日志，不要据此推理）、`controlled_vstate_id`（你指挥的阵营）、`day` / `max_days`、`main_city_pos`（太守府）、`diffculities`（0–4：简单/普通/困难/究极/挑战；「大模型」难度复用 4）、`memory.{intent,last_action,turns}`。
- `units[]`：`vstate` 阵营、`ap`/`ap_max` 机动力（剩余/上限）、`poker` 点数、`soldiers` 兵力、`troops` 军种、`hp`/`hp_max`、`power` 武、`wisdom` 知、`attrs` 体/武/知/德/政/忠/统/胆（`体` 为体力向上取整，与 `hp` 同源）、`level`/`exp`、`equips`（装备名）与 `equip_briefs`（装备效果）、`status`（人偶、迟滞:2 等）、`terrain_at` 当前地形、`disabled` 不可行动、`main` 是否主将、`skills` 可用计策及单价 `ap_cost`、`atk_range` 攻击距离。
- `economy`：`rice`/`money` 各归各阵营，`day`/`max_days` 全局。

改写 4 处旧表述：

| 原句 | 改为 |
| --- | --- |
| 「legal_actions 只列 attack/stratagem/retreat；没有 move 不代表不能移动」 | 「提示词不预先列动作；移动永远由你按地图规划，attack/stratagem/retreat 只要合法即可提交」 |
| 「开场已经给了全量单位、地形、合法动作与经济」 | 「开场已经给了全量单位、地形与经济」 |
| 「开局看一次 list_legal_actions」 | 「不确定某个武将能打谁/能用什么计时，再 `list_legal_actions(actor=…)`」 |
| 「attack/stratagem/retreat 必须来自 legal_actions」 | 「目标必须真实存在且符合规则；不确定就先查；猜错时服务端会返回候选」 |

## 验证

- `agent.test.ts`：user message 与动作结果摘要都不含 `legal_actions`；双方 unit 带 `skills`/`main`；静态段连续两轮逐字节一致；`──` 分界仍成立。**需改现有断言 `agent.test.ts:130`（它当前要求动态段包含 `legal_actions`）**，并在 `agent.test.ts:150` 的键列表补 `skills`/`atk_range`/`main`。
- `gdscript-contract.test.ts`：`skills[].ap_cost` 等于 `get_cost_ap`；`atk_range`/`main` 形状正确；`legal_actions` 仍在请求体里（服务端依赖）。
- `turn.test.ts`：`findAction` 失败文案含候选目标；`list_legal_actions` 默认不返回敌方动作。
- 手工：`pi` 模式跑一场，确认 `cacheRead` 非零、单步 token 低于改动前。

## 风险

- 模型可能不查清单就盲试 —— 由候选反馈兜底，最坏多一轮工具调用。
- 不提供 `retreat_city` 意味着模型只能按 system 的撤退规则自行判断；好在撤退是低频动作，查一次 `list_legal_actions` 的成本低于给错信号导致整回合回退。
- `skills` 让双方 `units` 变长，但移除逐目标清单与每步回传后，总量仍应下降；以手工 token 对比为准。

## 留给 builder

- `skills` 是否再加 `targeting`（是否需要指定目标）——默认不加，按实测 token 决定。
- 候选文案的最终措辞与中文/英文一致性（现有 `validateAction` 的错误是英文），实现时统一。

## 复评修正（2026-11-21）

对照代码复评后改了三处，均已在正文生效：

| 原设计 | 问题 | 修正 |
| --- | --- | --- |
| `retreat_city` 只在我方可撤时出现 | `get_retreat_city_id() >= 0` 只说明有退路；`_retreat()` 还查围困、兵力/体力/受伤、剧情模式、主将队友，粗信号会把模型推进 `exec_failed` 回退 | 删除该字段，撤退走 `list_legal_actions` / 规则判断 |
| `skills[].ap` | unit 已有 `ap`=剩余机动力，同名不同义 | 改名 `ap_cost` |
| 未提及主将 | system 首要战术是杀主将，但 units 无法识别主将 | 增加 `main: true` |

另外补齐：`end` 项为何必须保留、候选为空的分支、`validateAction` 会用真值 cost 拦截、README 与既有测试断言的同步点。原「留给 builder」里的 `list_legal_actions` 默认范围与候选上限已直接定为「默认只我方」「最多 8 个」。