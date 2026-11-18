# AI 敌方 Agent · 「兵书」系统提示词设计（A 方案：纯提示词）

日期：2026-11-18
状态：待批准
范围：`agent-service/src/agent.ts` 的 `SYSTEM_PROMPT` 一处

---

## 1. 意图与理由

敌方指挥官的「大脑」目前是 `SYSTEM_PROMPT` 的 10 行纪律说明：它只保证不违规，不理解胜负。
目标是让 LLM 掌握战争规则、克制关系、各类攻击与用计的胜率判断，从而**赢得更多、损失更少**。

本版（A 方案）只改提示词，不改数据视图、不改 GDScript、不重建网页包。

## 2. 目标 / 非目标 / 反面目标

**目标**
- 提示词里写清：胜负条件、机动力经济、白兵战力估算、攻击目标优先级、计策命中率与伤害、
  地形硬门槛、buff 克制链、粮草与天数、撤退时机、回合行动顺序。
- 所有数字与规则**可追溯到引擎源码**（见 §6 出处表），不写臆造数值。

**非目标（本版不做）**
- 不向 `legal_actions` / `units` 注入引擎真值（那是 B 方案）。
- 不新增工具、不改接口字段、不改预算（`max_tool_calls` 仍为 10）。
- 不追求覆盖技能系统（`effect_20xxx.gd` 数百个技能），只覆盖通用规则与常见克制。

**反面目标（即使能跑也算失败）**
- 提示词给出与游戏不符的数值，导致 LLM 按错的数据决策。
- 提示词长到挤占 `max_tool_calls`，或让每回合成本显著上升却无收益。

## 3. 约束（LLM 实际能看到什么）

数据视图的边界，决定了提示词必须迁就它：

| 真实机制 | LLM 看到的信息 | 提示词如何迁就 |
|---|---|---|
| 攻击机动力默认为 4（技能/装备可改） | `legal_actions` 里 `attack.cost.ap` **恒为 4** | 按 4 算，并说明「技能可能改」 |
| 攻击射程默认为 1 | 投影按 `get_attack_distance()` 粗筛 | 说明「默认贴脸，只有技能加远」 |
| 单位有 统/武/胆/智/兵种 | 只有 `hp/power(武)/wisdom/soldiers/ap/poker` | 士气用 `武力` 估算，明说是估算 |
| 地形是整张 32×19 | 只投影单位周围 5×5（上限 64 格） | 提示词写死「地形是全图的，但你看不到远处」 |
| 计策耗 4~12 机 | `stratagem.cost` 投影写死 `ap:2, poker:1` | 提示词明确纠正为真实区间 |
| 计策命中 / 伤害由引擎算 | 完全不可见 | 提示词给出公式 + 让 LLM 实测 `strategy.rate` |
| 移动可达半径 6 | 可选格被截断为最多 24 个 | 提示词说明「远目标靠分段移」 |

## 4. 方案比较与选择

| 方案 | 做法 | 取舍 |
|---|---|---|
| **A（选定）** | 扩充 `SYSTEM_PROMPT` 为兵书 | 零改动、快；部分知识只能是「估算」 |
| B | 投影层附 `attack_ap`/`hit_rate`/`expected_damage` | 真值、可算；要改 GDScript + 类型契约 + 重建 |
| C | 服务端静态 JSON 包 + 只读工具 | Godot 不动；多一层设施 |

选择 A 的理由：用户明确要求「把秘籍作为系统提示词写给 LLM」；A 最快验证「LLM 是否变聪明」，
若效果不足再升级到 B，B 的设计不受 A 影响。

## 5. 提示词结构（已在 `agent.ts` 落地）

保留原有 8 行行为纪律（工具用法、end 语义、不得发明 id），其后追加九节兵书：

1. 胜负条件（攻/守各自的败因、粮草、机动力上限、兵力阈值）
2. 机动力经济（攻击 4、移动 3~6、工具预算）
3. 白兵战（战力估算式、兵力 0 秒杀、败方损失）
4. 攻击目标优先级（主将 > 太守府定胜负 > 主力 > 兵损）
5. 计策（命中率公式、伤害公式、地形硬门槛、buff 克制链）
6. 粮草（攻方限时、守方续航、买米阈值）
7. 撤退（三种合法情形、健康守将撤退＝自毁）
8. 回合节奏（看预算 → 定目标 → 行动顺序）
9. 红线（合法候选复核、结果以引擎为准）

## 6. 规则出处（供后续核对）

| 规则 | 出处 |
|---|---|
| 攻方 30 日 / 粮尽判负 | `bwdl/packed/sgz_script/war/war_auto_run.gd:316-336`（剧本 `天数上限` 可覆盖） |
| 守方败因含 LoseCity（站上太守府） | `bwdl/script/War_Vstate.gd:430-437` |
| **只有主将撤退才判负** | `bwdl/packed/sgz_script/war/player_retreat.gd:74-79` |
| 每日粮耗 soldiers/250 | `bwdl/script/War_Vstate.gd:952` |
| 攻击消耗默认 4 | `bwdl/packed/sgz_script/war/IWar_Attack.gd:124` |
| 攻击射程默认 1 | `bwdl/script/War_Actor.gd:1514` |
| 机动力上限 clamp(...,13,25) | `bwdl/script/War_Actor.gd:561` |
| 白兵战力估算 | `bwdl/packed/sgz_script/war/AI/War_AI_Battle.gd:23` |
| 士气系数表 50~80 | `bwdl/script/War_Actor.gd:1022` |
| 战术值 = 知×13/100 | `bwdl/script/War_Actor.gd:807` |
| 计策命中率**三档**（通用 19 个 / 固定 100 的 9 个 / 空城计·笼络特殊） | `bwdl/packed/data/skill_system/stratagem.json` formula 字段 |
| 命中的 `max(0, 知差)` 与伤神减半 | `bwdl/script/objects/clStratagem.gd:573, 616-619` |
| 计策伤害与兵力缩放 | `bwdl/script/objects/clStratagem.gd:625-682` |
| weakenedTerrian 仅对声明它的计策生效 | `bwdl/script/objects/clStratagem.gd:661-665` |
| 计策地形门槛 / 扩展目标 | `bwdl/script/objects/clStratagem.gd:375-460` |
| buff 克制（八阵/定止/潜行/借露/神佑/铁索/疲兵…） | `bwdl/packed/data/skill_system/buff.json` |
| 撤退条件（≤200 可撤；>200 需 hp≤15 且受伤） | `bwdl/packed/sgz_script/war/AI/War_AI_behavior.gd:184-229` |
| **兵力 0 且带【避免白刃战】才会被俘/斩** | `bwdl/packed/sgz_script/war/player_attack.gd:195-210` |
| 撤退损 10% 兵 / 10% 粮 | `clBattleFight.gd:395-437` |
| 买米阈值 = 武将数×4×8 | `bwdl/packed/sgz_script/war/AI/War_AI_behavior.gd:480` |

## 7. 验证

- `npm test`（agent-service）：68 通过 / 0 失败 / 1 原有跳过；`SYSTEM_PROMPT` 无测试依赖。
- 模块可加载：`import('./src/agent.ts')` 成功。
- **独立事实复核**：曾派独立审阅代理逐条比对源码，修正了 5 处事实错误
  （计策命中率被当成单一公式、`知差`未取 max(0)、"任何武将撤退即判负"、兵力 0 必杀的前提说反、撤退条件表述错误）。
- 效果验证留待真实对局（`diffculities=4` + 大模型难度），对比 A/B 组胜率与单位交换比。

## 8. 留给构建者

- 提示词措辞与分节可微调。
- 若实测发现 LLM 被「工具预算」卡住，可在 A 内部加一句「只读工具最多调用 1~2 次」。
- 升级到 B 方案的触发条件：A 上线后 A/B 组胜率差 < 10%。