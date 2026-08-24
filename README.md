# 霸王的大陆 - Godot 移植版

三国志题材经典策略游戏「霸王的大陆」的 Godot 4 移植版，从 Unity 版完整移植（GDScript 重写）。

## 运行环境

- **Godot 4.7.2**（或更新 4.x 版本）
- macOS / Windows / Linux 均可

## 运行方式

```bash
# 使用命令行（需 godot 在 PATH 中）
godot --path .

# 或用 Godot 编辑器打开 project.godot 后按 F5
```

## 游戏简介

公元 251 年，天下三分，群雄并起。选择一方势力，招揽贤才、内政治理、募兵征伐，最终一统天下。

- 开局：选择剧本 → 难度 → 君主势力
- 回合制：每月一个回合，玩家发号施令，AI 势力自动行动
- 内政：开垦、劝商、治水、巡查、征兵、搜索、登用、奖赏、任命
- 战争：大地图网格移动部队（A* 寻路）、战前布阵（5 种阵型）、自动战斗结算
- 其它：自建武将、4 槽位存档读档、胜负结算

## 项目结构

```
project.godot           # Godot 工程配置（含自动加载单例）
assets/
  fonts/                # 中文字体（楷体）
  audio/                # 背景音乐
  ui/                   # UI 图片（大地图等）
data/                   # 游戏数据（武将/城池/势力/武器 JSON、阵型/地图 CSV）
scenes/
  main.tscn             # 主菜单
  ui/                   # 各游戏界面
  tests/                # headless 自动化测试场景
scripts/
  data/                 # 数据实体与全局状态（General/City/Country/GameInfo/DataManager）
  cache/                # 数据缓存单例（武将/城池/势力/武器）
  war/                  # 战争系统（WarManager/MapManager A*）
  battle/               # 战斗系统（BattleManager 自动战斗）
  ui/                   # UI 逻辑
  sound_manager.gd      # 音频
  turn_manager.gd       # 回合管理
```

## 已实现功能

- **数据层**：185 武将、48 城池、3 势力、32 武器，完整数值公式（经验升级、忠诚、薪水、收入、征兵、内政效果、战力计算等）
- **核心循环**：主菜单 → 选君主 → 大地图 → 城市内政 → 结束回合 → AI 行动 → 下月
- **战争系统**：手动网格地图（19×32），部队选择/移动（A* 寻路 + 机动力）、村庄交互（武器店/粮店/医馆）、16 种计策施放、AI 追击、日循环、遭遇战
- **战斗系统**：战前布阵（5 种阵型，手动/自动战斗二选一）→ 逐格战术战斗（部队移动、近战/弓兵远程攻击、伤害公式、主将阵亡/全灭判定）或 SimulatedBattle 自动结算，城市归属转移
- **计策/战术/单挑**：16 种计策（火攻/陷阱/虚兵/要击/乱水/劫粮/共杀/伪击转杀/烧粮/落石/连环/伏兵/水攻/箭雨/劫火/奇门遁甲）完整成功率与效果公式；6 种战术；单挑攻防/命中/招降
- **月度事件**：起义、旱灾/洪涝/蝗灾/瘟疫/骚乱、武将伤病恢复、在野武将流动
- **AI**：势力每月收税、内政（开垦/劝商/巡查）、搜索登用、奖赏、征兵、输送、评估进攻、攻打玩家时进入战争场景
- **其它**：自建武将、存档读档、游戏胜利/失败结算、背景音乐

## 测试

项目内置 headless 自动化测试（`scenes/tests/`），运行：

```bash
godot --headless --path . res://scenes/tests/test_flow.tscn      # 数据层+核心流程
godot --headless --path . res://scenes/tests/test_scenes.tscn    # 全部 UI 场景构建
godot --headless --path . res://scenes/tests/test_war.tscn       # 战争结算（胜/败）
godot --headless --path . res://scenes/tests/test_grid.tscn      # 手动网格战斗多日循环
godot --headless --path . res://scenes/tests/test_prebattle.tscn # 战前布阵→战斗
godot --headless --path . res://scenes/tests/test_loop.tscn      # 多回合压力测试
```
