<div align="center">

# 霸王的大陆（Godot 移植版）

**三国志题材经典策略游戏「霸王的大陆」的 Godot 4 开源移植版**

![Godot](https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godotengine&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue.svg)
![CI](https://github.com/studyzy/3k-game/actions/workflows/ci.yml/badge.svg)

</div>

## 📖 简介

「霸王的大陆」是光荣（KOEI）于 1992 年推出的经典三国策略游戏。本仓库是其 **Godot 4 移植版**：从 Unity 版完整移植、使用 GDScript 重写，目标为 **100% 复刻原版的数据与逻辑**——包括全部武将数值公式、内政、战争、战术战斗与月度事件系统。

> ⚠️ **版权声明**：原版《霸王的大陆》为光荣（KOEI）的版权作品。本仓库为**致敬与学习性质**的开源复刻，不包含原版任何受版权保护的素材（图像、音频、关卡数据均为本项目自行构建），仅供学习研究使用，请勿用于商业用途。

## ✨ 功能特性

- **完整数据层**：185 武将、48 城池、3 势力、32 武器，完整数值公式（经验升级、忠诚、薪水、收入、征兵、内政效果、战力计算等）
- **核心循环**：主菜单 → 选君主 → 大地图 → 城市内政 → 结束回合 → AI 行动 → 下月
- **内政系统**：开垦、劝商、治水、巡查、征兵、搜索、登用、奖赏、任命、输送
- **战争系统**：手动网格地图（19×32），部队选择/移动（A* 寻路 + 机动力）、村庄交互（武器店/粮店/医馆）、16 种计策、AI 追击、日循环、遭遇战
- **战斗系统**：战前布阵（5 种阵型，手动/自动二选一）→ 逐格战术战斗（移动、近战/弓兵攻击、伤害公式、主将阵亡/全灭判定）或 SimulatedBattle 自动结算
- **计策/战术/单挑**：16 种计策完整成功率与效果公式、6 种战术、单挑攻防/命中/招降
- **月度事件**：起义、旱灾/洪涝/蝗灾/瘟疫/骚乱、武将伤病恢复、在野武将流动
- **AI**：势力每月收税、内政、搜索登用、奖赏、征兵、输送、评估进攻
- **其它**：自建武将、4 槽位存档读档、游戏胜利/失败结算、背景音乐

## 🖥️ 运行环境

| 依赖 | 版本 |
|------|------|
| [Godot](https://godotengine.org/download) | **4.7.2**（或更新 4.x 版本） |
| 操作系统 | macOS / Windows / Linux |

## 🚀 快速开始

### 从源码运行

```bash
# 克隆仓库
git clone git@github.com:studyzy/3k-game.git
cd 3k-game

# 命令行运行（需 godot 在 PATH 中）
godot --path .

# 或用 Godot 编辑器打开 project.godot 后按 F5
```

### 使用 Makefile

```bash
make run          # 运行游戏
make check        # headless 校验工程（导入资源、检查错误）
make test         # 运行集成测试（scenes/tests/）
make test-unit    # 运行单元测试（tests/，gdUnit4）
make test-all     # 运行全部测试（集成 + 单元）
```

## 🎮 游戏玩法

公元 251 年，天下三分，群雄并起。选择一方势力，招揽贤才、内政治理、募兵征伐，最终一统天下。

- **开局**：选择剧本 → 难度 → 君主势力
- **回合制**：每月一个回合，玩家发号施令，AI 势力自动行动
- **胜利条件**：消灭或吞并所有其他势力，一统天下

## 🧪 测试

项目内置两套自动化测试，均由 GitHub Actions 在 CI 中自动运行：

### 单元测试（`tests/`，gdUnit4）

使用 [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) 框架，覆盖数据层实体与缓存单例的核心逻辑：

| 套件 | 覆盖内容 |
|------|---------|
| `test_general.gd` | 武将数值（分级/经验/HP/忠诚/计策数/带兵/战力等） |
| `test_city.gd` | 城池（数值钳制/收入/武将管理/内政） |
| `test_country.gd` | 势力（城市归属/灭亡/继承/同盟） |
| `test_plan.gd` | 计策（16 种注册表/成功率/技能影响） |
| `test_tactic.gd` | 战术（6 种注册表/战术数/战术点） |
| `test_caches.gd` | 缓存单例（相性/武将/城池/势力/回合顺序） |
| `test_weapon_alliance_unit.gd` | 武器/同盟/大地图单位 |

```bash
make test-unit   # 运行全部单元测试（生成 HTML/XML 报告到 reports/）
```

### 集成测试（`scenes/tests/`）

headless 自动化场景测试，验证核心流程：

```bash
make test        # 逐个运行全部集成测试
make test-flow   # 单场景示例：数据层+核心流程
```

## 📁 项目结构

```
├── project.godot           # Godot 工程配置（含自动加载单例）
├── Makefile                # 常用命令入口（run/check/test/test-unit/test-all）
├── assets/
│   ├── fonts/              # 中文字体（楷体）
│   ├── audio/              # 背景音乐
│   └── ui/                 # UI 图片（大地图等）
├── data/                   # 游戏数据（武将/城池/势力/武器 JSON、阵型/地图 CSV）
├── scenes/
│   ├── main.tscn           # 主菜单
│   ├── ui/                 # 各游戏界面
│   └── tests/              # headless 集成测试场景
├── scripts/
│   ├── data/               # 数据实体与全局状态（General/City/Country/GameInfo/DataManager）
│   ├── cache/              # 数据缓存单例（武将/城池/势力/武器）
│   ├── war/                # 战争系统（WarManager/MapManager A*）
│   ├── battle/             # 战斗系统（BattleManager 自动战斗）
│   └── ui/                 # UI 逻辑
├── tests/                  # gdUnit4 单元测试套件
└── addons/gdUnit4/         # 单元测试框架插件
```

## 🛠️ 开发

### 架构

**核心设计模式：数据层（RefCounted 实体）+ 全局状态（autoload 单例）+ 场景（tscn + UI 脚本）三层分离。**

- 数据全部由 JSON/CSV 加载到 autoload 单例的内存缓存，游戏逻辑直接读写这些单例
- 修改逻辑前，先理解"哪个单例持有该数据、被谁引用"

### 环境要求

- **Godot 4.7.2**（`config/features` 声明了 4.7），无需安装额外依赖

## 🤝 贡献

欢迎任何形式的贡献！请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

- 🐛 报告问题 / 💡 建议功能 → [Issues](https://github.com/studyzy/3k-game/issues)
- 🚀 提交代码 → [Pull Requests](https://github.com/studyzy/3k-game/pulls)

## 📄 许可证

本项目以 [MIT](LICENSE) 许可证开源。

> 免责声明：本移植版为学习与致敬目的开发，与光荣（KOEI）及其《霸王的大陆》无任何关联或授权。若涉及任何权利争议，请与维护者联系。
