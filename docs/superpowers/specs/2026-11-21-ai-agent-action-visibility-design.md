# 2026-11-21 AI Agent 战争提示词：动作清单退场与字段速查

状态：已批准（2026-11-21）。本文是对话中批准的短设计的落盘记录，实现计划另见 `docs/superpowers/plans/`。

## 意图与 why

开场 user 消息把 `legal_actions` 整块塞进「本轮次」JSON，但它有三个问题：

1. **不可读**：键是引擎内部缩写（`ap` / `poker` / `attrs`），提示词里没有一处解释。模型同时看到 system 的「火计 6」和清单里的 `cost: {ap: 2}`（`StateProjection.gd:203` 写死），两个数字互相矛盾。
2. **不精确**：用计真实消耗由 `clStratagem.get_cost_ap()` 计算，会扣掉武将装备的「计策消耗减少」（`clStratagem.gd:94-99`）。写死的 2 既不是火计的 6，也不含装备减免。
3. **冗余**：清单按「目标」展开——同一个武将的同一计策打 5 个目标就是 5 条完整记录；`end` 每个武将各一条（`StateProjection.gd:128-130`），但 `end` 结束的是整个回合。每执行一个动作，tool result 还会把 `units` + `legal_actions` 整份再回传一次（`tools.ts:191-199`）。

同时，模型要判断「谁能干什么」还缺字段：`units` 里没有计策列表，`inspect_unit` 返回的是同一份对象；也没有攻击距离。

目标：让这段 JSON 自解释、变短，同时不降低动作合法性保障。

## 目标 / 非目标 / 反目标

- **目标**：`legal_actions` 不再出现在提示词；`units` 自带能力与真实消耗；system 有字段速查；猜错动作时服务端给候选，模型当回合自纠。
- **非目标**：不改 Godot 执行路径与 `_fallback` 策略；不改战斗引擎数值；不改白兵战 `BATTLE_SYSTEM_PROMPT`；不删 `list_legal_actions` / `end` 工具；不引入显式 `cache_control`。
- **反目标**：把 `legal_actions` 改个名继续全量下发；把字段说明写进动态段（逐轮计费且更乱）；让模型在没有任何技能字段的情况下自己猜「谁会什么计」。

## 现状与约束（代码事实）

- `StateProjection.build()` 返回 `legal_actions`，按 `(actor, tool, 目标)` 逐条展开；动作项带 `id`（`a`/`s`/`r`/`mv`/`e` 前缀）、`cost`、`hint`。
- 服务端 `runAction` 靠 `findAction(live.legal_actions, ...)` 定位动作，再用 `validateAction(target.id, ...)` 校验；`id` 同时下发给 Godot 的 `ActionValidator.accept_action`。
- Godot `behavior()` 在 `_execute` 返回 false 时直接 `_fallback("exec_failed:...")`，本回合剩余交给规则 AI（`War_AI_behavior_llm.gd:318-323`）。所以「模型提出非法动作」绝不能直接落到 Godot。
- `SYSTEM_PROMPT` 有 4 处依赖清单：第 40 行「legal_actions 只列 attack/stratagem/retreat」、第 73 行「开场已给全量合法动作」、第 136 行「开局看一次 list_legal_actions」、第 143 行「必须来自 legal_actions」。
- 静态段有测试断言禁止出现 `turn_key` / `day` / `legal_actions` 等键名（`agent.test.ts:105-129`），因此字段速查只能放 system，不能放地图旁。
- `units` 当前不含 `skills` / `atk_range` / `retreat_city`。
- DeepSeek 自动前缀缓存按字节匹配；system 是稳定前缀，新增速查表只付一次费用。

## 决定（用户已确认）

1. `legal_actions` 从开场提示词里**完全删掉**，不做「挂到武将下」的折中。
2. 删法是「**按需查询 + 错时给候选**」：服务端仍保留清单用于校验，模型需要时调 `list_legal_actions(actor)`，猜错时返回该武将当前可选目标供其自纠。
3. **敌方 `units` 也带 `skills`**，让模型知道对手能放什么计。
4. 字段说明写进 `SYSTEM_PROMPT`，作为新增的一节。

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

本轮次 JSON 不再含 `legal_actions`；`end` 也不再作为某武将的动作出现。

## 数据契约

| 位置 | 改动 |
| --- | --- |
| `StateProjection.gd` unit 投影 | 双方 unit 增加 `skills: [{ "name": "火计", "ap": 6 }]`（来自 `wa.get_stratagems()`，`ap` 用 `scheme.get_cost_ap(actorId)`）与 `atk_range`（`wa.get_attack_distance()`）。`retreat_city` 只给我方（`get_retreat_city_id() >= 0` 时才有该键）。 |
| `StateProjection.gd:_append_stratagem_actions` | `cost` 改为 `{"ap": scheme.get_cost_ap(wa.actorId)}`；引擎用计不扣点数，去掉 `poker`。 |
| `StateProjection.build()` | `legal_actions` 照旧生成并下发——它退为服务端的校验数据，不再进提示词。 |
| `agent.ts:buildUserMessage` | 动态 JSON 删 `legal_actions` 键。 |
| `tools.ts:runAction` | 动作结果摘要删 `legal_actions`；`units`/`economy`/`outcome` 保留。 |
| `tools.ts:list_legal_actions` | 保留按需查询；输出裁掉 `id` 与 `end` 行，只留 `tool/actor/target/skill/city/cost`。 |
| `tools.ts:findAction` 失败路径 | 错误文案改为「该武将当前可选」的候选清单（见下）。 |

`skills` 口径：`get_stratagems()` 已过滤未习得、冷却中、模式不符与攻方不能用的空城计；地形与目标合法性仍由引擎在执行时判定。因此 `skills` 回答的是「这人会什么、花多少」，不承诺「此刻一定放得出」。

## 猜错时的反馈

`findAction` 找不到匹配项时，不再只抛一句「没有匹配的合法动作」，而是按同 `actor` + 同 `tool` 列出候选：

```
19 无法对 53 使用「火计」。19 当前可选：
  attack → 53
  stratagem 火计 → 53, 54
  retreat → 城3
```

模型在同一会话里改参数重试即可。因为服务端先用清单拦截，非法动作**不会**下发到 Godot，也就不会触发 `exec_failed` 回退。这是本方案不碰执行路径的前提。

## 提示词改动

新增 `## 十、字段速查（JSON 键的意思）`，覆盖：

- 顶层：`turn_key`（回合标识，仅用于日志，不要据此推理）、`controlled_vstate_id`（你指挥的阵营）、`day` / `max_days`、`main_city_pos`（太守府）、`diffculities`（0–4：简单/普通/困难/究极/挑战；「大模型」难度复用 4）、`memory.{intent,last_action,turns}`。
- `units[]`：`vstate` 阵营、`ap`/`ap_max` 机动力、`poker` 点数、`soldiers` 兵力、`troops` 军种、`hp`/`hp_max`、`power` 武、`wisdom` 知、`attrs` 体/武/知/德/政/忠/统/胆、`level`/`exp`、`equips`（装备名）与 `equip_briefs`（装备效果）、`status`（人偶、迟滞:2 等）、`terrain_at` 当前地形、`disabled` 不可行动、`skills` 可用计策及耗机、`atk_range` 攻击距离、`retreat_city` 撤退城（仅我方、可撤时才有）。
- `economy`：`rice`/`money` 各归各阵营，`day`/`max_days` 全局。

改写 4 处旧表述：

| 原句 | 改为 |
| --- | --- |
| 「legal_actions 只列 attack/stratagem/retreat；没有 move 不代表不能移动」 | 「提示词不预先列动作；移动永远由你按地图规划，attack/stratagem/retreat 只要合法即可提交」 |
| 「开场已经给了全量单位、地形、合法动作与经济」 | 「开场已经给了全量单位、地形与经济」 |
| 「开局看一次 list_legal_actions」 | 「不确定某个武将能打谁/能用什么计时，再 `list_legal_actions(actor=…)`」 |
| 「attack/stratagem/retreat 必须来自 legal_actions」 | 「目标必须真实存在且符合规则；不确定就先查；猜错时服务端会返回候选」 |

## 验证

- `agent.test.ts`：user message 与动作结果摘要都不含 `legal_actions`；我方/敌方 unit 带 `skills`；静态段连续两轮逐字节一致；`──` 分界仍成立。
- `gdscript-contract.test.ts`：`skills[].ap` 等于 `get_cost_ap`；`atk_range` / `retreat_city` 形状正确；`legal_actions` 仍在请求体里（服务端依赖）。
- `tools.test.ts`（或等价）：`findAction` 失败文案含候选目标。
- 手工：`pi` 模式跑一场，确认 `cacheRead` 非零、单步 token 低于改动前。

## 风险

- 模型可能不查清单就盲试 —— 由候选反馈兜底，最坏多一轮工具调用。
- 遗留的粗筛不精确（如 retreat 只校验有撤退城，真实条件更严）在改动前就存在，本方案不扩大也不修复。
- `skills` 让双方 `units` 变长，但移除逐目标清单与每步回传后，总量仍应下降；以手工 token 对比为准。

## 留给 builder

- `skills` 是否给 `ap` 之外再加 `targeting`（是否需要目标才可选）——按实测 token 决定，默认不加。
- `list_legal_actions` 是否默认只返回我方；建议默认只返回我方，避免模型把敌方动作当自己的。
- 候选文案的具体措辞与截断上限（目标很多时只列前 N 个）。