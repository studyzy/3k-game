# CODEBUDDY.md

This file provides guidance to CodeBuddy Code when working with code in this repository.

## 项目概述

「霸王的大陆」的 Godot 4 移植版（GDScript 重写）。三国志题材策略游戏：选择君主势力，回合制内政（开垦/劝商/治水/征兵/搜索/登用）+ 战争（大地图网格移动 + 战前布阵 + 战术战斗）+ 月度事件。目标是 100% 复刻原版《三国志2 霸王的大陆》的数据与逻辑。

## 运行与测试命令

环境要求：**Godot 4.7.2**（`godot` 在 PATH 中，`project.godot` 的 `config/features` 声明了 4.7）。项目无外部构建步骤，无需安装依赖。

```bash
# 运行游戏
godot --path .

# headless 校验工程（导入资源、报告缺失/错误）
godot --headless --editor --path . --quit

# 运行单个测试场景
godot --headless --path . res://scenes/tests/test_flow.tscn
```

已提供 `Makefile`，常用命令：

```bash
make run          # 运行游戏
make check        # headless 校验工程
make test         # 逐个运行全部常规测试（遇错即停）
make test-flow    # 运行单个测试场景（test-<name>）
make test-loop    # 多回合压力测试（耗时较长）
```

测试场景位于 `scenes/tests/`，每个 `test_*.tscn` 是独立的 headless 自动化测试：`test_battle`、`test_endturn`、`test_flow`（数据层+核心流程）、`test_grid`（手动网格战斗多日循环）、`test_map`、`test_plan`、`test_prebattle`（战前布阵→战斗）、`test_scenes`（全部 UI 场景构建）、`test_war`、`test_warscene`。测试脚本在 `_ready()` 里直接跑断言并 `get_tree().quit()`，无 GUT/测试框架。

## 架构总览

**核心设计模式：数据层（RefCounted 实体）+ 全局状态（autoload 单例）+ 场景（tscn + UI 脚本）三层分离。**

数据全部由 JSON/CSV 加载到 autoload 单例的内存缓存中，游戏逻辑直接读写这些单例（而非通过信号/服务分发）。这意味着任何逻辑改动前，必须先理解"哪个单例持有该数据、被谁引用"。

### autoload 单例（`project.godot` 的 `[autoload]` 声明）

全局单例按职责分组，代码中可全局直接访问（无需显式获取节点）：

- **状态**：`GameInfo` — 全局游戏状态（年月、当前回合、玩家势力、`GameState`/`TaskType` 枚举、目标/命令状态）。`reset_game_state()` 用于新游戏。
- **数据实体**：`General`、`City`、`Country`、`Weapon`、`Alliance`、`Tactic`、`Plan`、`Unit`（在 `scripts/data/`，`class_name` 声明，`RefCounted`）。含全部数值公式（经验升级、忠诚、薪水、收入、内政效果、战力、成功率计算）。
- **缓存单例**（`scripts/cache/`）：`GeneralListCache`、`CityListCache`、`CountryListCache`、`WeaponListCache` — 持有 `xxx_dictionary`（id→对象）及势力回合顺序 `country_sequence`。带 `debut_by_years`（武将按年份登场）、武将死亡/离间/招揽判定等逻辑。
- **管理器**：`DataManager` — JSON 加载、CSV 地图/阵型解析、存档读档（`user://Saves`）、自定义武将（`user://Custom`）；`TurnManager` — 回合循环（`end_player_turn()`：AI 行动→月度推进→胜负判定）；`WarManager` / `MapManager`（A* 寻路）/ `BattleManager` — 战争与战斗；`SceneRouter` — 场景切换。
- **UI/杂项**：`TextLibrary`（中文文本）、`SoundManager`、`GameLogger`、`UITips`、`EventQueueManager`、`SoloManager`。

### 数据流（初始化/加载）

`DataManager.load_all_configs()`（或 `ensure_loaded()`）是唯一入口：
1. 读 `data/GeneralData.json` → `General.from_dict()` → `GeneralListCache`（按 `debutYear` 分"已登场/未登场"）。
2. 读 `CityData.json` / `CountryData.json` / `WeaponData.json` → 各自缓存。
3. `_initialize()` 把武将按 `debutCity` 分配到城池的官职/在野/隐居列表，建立城池-势力归属。

数据文件名与实体字段一一对应：`GeneralData.json`(185 武将) / `CityData.json`(48 城) / `CountryData.json`(3 势力) / `WeaponData.json`(32 武器)。地图为 `data/Map/<cityID>.CSV`（19×32），阵型为 `data/Formation/<name>.csv`（7×16）。**注意**：`.csv.import` 文件是 Godot 误把 CSV 当翻译文件自动生成的产物（见 `.gitignore`），CSV 实际是数据表，不是翻译文件。

### 游戏循环

`main.gd` → `select_king.tscn`（选君主）→ `global_map.tscn`（大地图）→ `city_scene.tscn`（城市内政）。玩家回合内通过 `GameInfo` 的 `TaskType` 枚举选择命令，执行后 `sub_player_order()` 扣减命令数。`TurnManager.end_player_turn()` 触发 AI 回合（`_ai_turn`）、月度推进（`add_month`：收入/起义/灾害/伤病/在野流动）与胜负判定（`_check_game_end`）。

### 场景与 UI

`scenes/`：`main.tscn`（主菜单）、`ui/`（`global_map`、`city_scene`、`select_king`、`select_general`、`pre_battle`、`battle_scene`、`war_scene`、`self_build`、`executive_panel`、`ui_end`）。每个场景配同名 `scripts/ui/*.gd` 脚本（`_ready`/`_input`/`_process` 中直接操作缓存单例）。`ui_factory.gd` 是 UI 构建辅助。

## 工程约定

- 语言为简体中文（文本、注释、日志、`show_info` 提示）。
- 所有数据经 `*_list_cache.gd` 访问，修改数据用实体自身方法（如 `City.add_gold` 自带上限钳制），勿直接改裸字段。
- 存档是完整 JSON 快照（`DataManager._dict_to_array` 把 Dictionary 转数组），新增实体字段需同步 `to_dict()`/`from_dict()` 与 `_dict_to_array`。
- 新增测试：在 `scenes/tests/` 加 `.gd`+`.tscn`，`_ready` 中打印 `[Name] 步骤` 并 `get_tree().quit()`，再补进 Makefile 的 `TESTS`。
- `.godot/` 缓存目录不入库。
