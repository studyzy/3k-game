# 2026-11-20 AI Agent 回合提示词缓存优化与双方粮草投影

状态：已批准（2026-11-20）。本文是对话中批准的短设计的落盘记录，实现计划另见 `docs/superpowers/plans/`。

## 意图与 why

战争场景 AI 每开一个回合都会新建 `Agent`、重新发一遍全量态势。其中 system 提示词（`agent.ts` 的 `SYSTEM_PROMPT`，约 115 行规则）与战场地图在一场战斗内逐字节不变，但地图被埋在开场 JSON 中段、`turn_key` 之后，自动前缀缓存在那里断开，地图那部分（32×20 的非平原格，约一两千 token）每轮都要重新计价。

顺带发现一个决策盲点：system 里写着「任一方粮归零即判负」「守方打法：拖到攻方粮尽」，但开场 `economy` 只投影受控方一份粮草，模型从来没见过敌方粮草，胜负规则里最关键的变量是盲的。

两件事一起做：

1. 把静态内容顶到 prompt 最前面，让地图进入可缓存前缀，降低每轮费用。
2. 补上敌方（玩家方）粮草，并明确身份（攻方/守方）。

成功标准：静态段逐轮字节一致；`cacheRead` 可观测可验证；模型能读到双方粮草；现有回合流程与测试不回归。

## 目标 / 非目标 / 反目标

- **目标**：静态前缀命中自动缓存；双方粮草可见；身份明确；不改规则数值。
- **非目标**：不改工具集、不改引擎战斗逻辑、不改白兵战、不引入显式 `cache_control` 断点、不做跨会话上下文复用。
- **反目标**：把任何逐轮变化的字段（`turn_key`、`day`、`units`、`legal_actions`、`memory`、敌方粮草）放进静态段——一个就足以让整段缓存失效；敌方粮草只在开场给一次而不在 tool result 同步——模型会在回合内读到过期值。

## 约束

- 端点是 `hai/deepseek-flash` 经 CCR 走 OpenAI 兼容 `/v1/chat/completions`（`config.ts` 默认值）。DeepSeek 系是**自动前缀缓存**：按 token 前缀逐字节匹配，**不看 user 消息边界、不需要显式 `cache_control`**。因此保持单条 user 消息即可。
- pi-ai 的 `convertMessages` 不会合并连续 user 消息；`Agent.prompt(AgentMessage[])` 支持批量，但本设计不用。
- pi-ai 的 `usage` 已解析 `cacheRead`（DeepSeek 的 `prompt_cache_hit_tokens`），当前 `traceStore` 只记 `totalTokens`，缓存命中数被丢掉了。
- 动作 tool result 追加在对话末尾，不影响前缀，无需为它调整缓存策略。
- **身份不能由服务端现有字段推出**：`StateProjection.gd:107` 的 `attacker_vstate` 恒等于 `controlled_id`（错值/占位）。真实身份在 Godot：`wv.is_attacker()`（基于 `War_Vstate.side`，`War_Vstate.gd:844`）；对方对象由 `wv.get_enemy_vstate()` 返回（`War_Vstate.gd:458`）；`War_Vstate.rice` / `.money` 是公开 `int`（`War_Vstate.gd:26`）；`clWarFight.gd:25/27` 的 `attackerWV` / `defenderWV` 可作兜底。
- **`economy` 不能整块复制成两份**：`rice` / `money` 是每方各自；`day`（`wf.date`）、`max_days: 30`、`main_city_pos` 是全局共享。
- **敌方粮草会在回合内变化**：`War_Vstate.gd:660/701` 有跨方粮草机制（「战争夺米转金」会动 `enemyWV.money`），加上粮草每日按兵力扣减。所以 `build_tool_result()` 每次动作回传也必须带上敌方粮草。

## Approaches

1. **拆成两条 user 消息**（原始提议）：第一条固定放身份+地图，第二条放态势+行动指令。**未选**——自动前缀缓存不认消息边界，拆开没有额外收益，只是多一层结构；若上游换成需要显式 `cache_control` 的 Claude 系，拆两条也不够（pi-ai 的断点只打在 system / 最后一个 tool / 最后一条消息，不在第一条 user 末尾）。
2. **A：单条消息重排 + 只分组现有数据**：静态段前置、动态段后置，敌方不带粮草。改动最小。**未选**——保留决策盲点，而引擎侧补粮草成本极低。
3. **B：单条消息重排 + 敌我各带粮草**（**选定**）：多一处 Godot 投影和一个贯穿字段，但顺手修盲点与 `attacker_vstate` 错值。选它的理由是 `wv.get_enemy_vstate()` 一行就能拿到对方 rice/money，成本远低于收益。

## 决定与判断

**用户决定：**

- 不拆消息，保持单条 user；单条内部顺序为「先地图，后本轮次信息 + 两军信息」。
- system 首句由「你是三国策略游戏「霸王的大陆」战争场景的敌方指挥官。」改为「你是战场指挥官。」
- 两军都带粮草（Approach B）。

**以下为我的判断（builder 可复核，非用户已同意项）：**

- `side` 复用白兵战 `BattleRequest.side` 已有的 `"attacker" | "defender"` 取值；提示词展示为 system 中已有的「攻方/守方」措辞，不新造「攻城方/守城方」。
- system 只换首句并加一句锚点（「你指挥 `controlled_vstate_id` 这一方，对手是玩家方」），给通篇「我方/敌方」一个指代基准；其余条件式规则不改。
- 白兵战 `BATTLE_SYSTEM_PROMPT` 不动（它没有地图与粮草，格式不适用）。
- 敌方块只放 rice/money；公共项（day / max_days / main_city_pos）留在「本轮次信息」。
- `cacheRead` 观测一起补，否则无法验证省钱。
- 静态段与动态段用一行文字分界，不用多个 JSON 代码块（减少分隔符与引导句的 token）。

## 消息形状

单条 user 消息，`──` 是可缓存静态段与动态段的分界：

```
[system] 你是战场指挥官。你指挥 controlled_vstate_id 这一方，对手是玩家方。
         …其余规则原样不动…

[user]
你是攻方/守方。                       ┐
战场地图 { terrain: [...] }          ┘ 静态段：一场战斗内逐字节不变
─────────────────────────────────
本轮次 { turn_key, day, max_days, main_city_pos,
        diffculities, legal_actions, memory }
敌方   { units: [vstate ≠ controlled], rice, money }
我方   { units: [vstate = controlled], rice, money }
请你进行行动。
```

`turn_key` / `day` / `units` / `legal_actions` / `memory` / 敌方粮草全部在分界之后。`terrain` 由 `StateProjection._build_terrain` 按固定 y→x 顺序输出、地图整局不变，保证逐轮字节一致。

## 改动落点

| 文件 | 改动 |
| --- | --- |
| `bwdl/packed/sgz_script/war/AI/StateProjection.gd` | `build()` 新增 `side`（`wv.is_attacker()`）与敌方 rice/money（`wv.get_enemy_vstate()`），修正 `attacker_vstate` 错值；`build_tool_result()` 同步带敌方粮草 |
| `agent-service/src/types.ts` | `TurnRequest` 新增 `side` 与敌方经济字段；`ToolResultPayload` 同步 |
| `agent-service/src/validate.ts` | 新增字段的校验与可选性 |
| `agent-service/src/agent.ts` | `SYSTEM_PROMPT` 首句 + 锚点句；重写 `buildUserMessage()`（静态段/动态段、按敌我分组） |
| `agent-service/src/tools.ts` | `LiveState` / `inspect_economy` 与 tool result 同步敌方粮草 |
| `agent-service/src/trace.ts` | 记录 `usage.cacheRead` / `cacheWrite` |
| 测试 | `fixture.ts`、`gdscript-contract.test.ts`、`validate.test.ts`、`agent.test.ts`、`llm.test.ts`、`trace.test.ts` 等涉及请求体与 user_message 内容的断言 |

规模：小改动，逻辑不复杂、无新概念、无新依赖；但新增字段贯穿 Godot → types → validate → prompt → tools → 测试，约 6–8 个文件、每处都很薄。

## 留给 builder

- 字段命名与可选性：新增字段对旧请求体 / 旧 fixture 的兼容策略。
- `get_enemy_vstate()` 返回 `null` 时的兜底（某些剧本 `attackerWV` / `defenderWV` 可能为 null）。
- 具体测试断言与静态段字节一致性的验证方式。

## 验证

- `agent-service` 全量测试通过（`agent.test.ts` / `gdscript-contract.test.ts` / `validate.test.ts` / `llm.test.ts` / `trace.test.ts` / `scenarios.test.ts`）。
- Godot 侧契约测试确认 `side`、双方粮草与修正后的 `attacker_vstate` 形状。
- 单测断言 `buildUserMessage` 输出中静态段不含 `turn_key` / `day` / `units` 等变化字段；连续两轮同一场战斗生成的静态段字节相同。
- 手工跑一轮 `pi` 模式，从 trace 读到非零 `cacheRead`，确认缓存确实命中；对比改动前后每轮 input token。
