<div align="center">

# 霸王的大陆（Godot 移植版）

**三国志题材经典策略游戏「霸王的大陆」的 Godot 4 + Go 客户端/服务器复刻版**

![Godot](https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godotengine&logoColor=white)
![Go](https://img.shields.io/badge/Go-1.24-00ADD8?logo=go&logoColor=white)
![go-zero](https://img.shields.io/badge/go--zero-1.10.3-00ADD8)
![License](https://img.shields.io/badge/License-MIT-blue.svg)
![CI](https://github.com/studyzy/3k-game/actions/workflows/ci.yml/badge.svg)

</div>

## 📖 简介

「霸王的大陆」是光荣（KOEI）于 1992 年推出的经典三国策略游戏。本项目是其 **客户端/服务器（C/S）复刻版**：

- **Go 权威服务器**（go-zero + WebSocket）：承载全部游戏逻辑——武将数值公式、内政、战争、战术战斗、月度事件、AI 决策、随机数生成与结果判定。
- **Godot 4 纯 UI 客户端**：只负责渲染界面与发送指令，不做任何逻辑计算。

目标为 **100% 复刻原版的数据与逻辑**。服务器是唯一权威，客户端无法篡改随机数/属性/资源，天然防作弊；每局独立、状态存服务器，支持跨设备与云端存档。

> ⚠️ **版权声明**：原版《霸王的大陆》为光荣（KOEI）的版权作品。本仓库为**致敬与学习性质**的开源复刻，不包含原版任何受版权保护的素材（图像、音频、关卡数据均为本项目自行构建），仅供学习研究使用，请勿用于商业用途。

## ✨ 功能特性

**服务器（`server/`，Go）**
- **完整数据层**：185 武将、48 城池、3 势力、32 武器，完整数值公式（经验升级、忠诚、薪水、收入、征兵、内政效果、战力计算等）
- **核心循环**：选君主 → 大地图 → 城市内政 → 结束回合 → AI 行动 → 月度推进
- **内政系统**：开垦、劝商、治水、巡查、征兵、搜索、登用、奖赏、任命、输送
- **战争系统**：手动网格地图（19×32）、A* 寻路 + 机动力、村庄交互、16 种计策、AI 追击、日循环、遭遇战
- **战斗系统**：5 种阵型（手动/自动）、逐格战术战斗 / SimulatedBattle 自动结算
- **计策/战术/单挑**：16 种计策完整成功率与效果公式、6 种战术、单挑攻防/命中/招降
- **月度事件**：起义、旱灾/洪涝/蝗灾/瘟疫/骚乱、伤病恢复、在野武将流动、武将登场
- **AI**：势力每月收税、内政、搜索登用、奖赏、征兵、输送、评估进攻
- **权威性**：可播种 RNG（seed 入档，可回放）、服务器唯一权威、防作弊
- **其它**：自建武将（随机服务器化）、存档落盘（JSON）、HTTP 登录/建局/存读档 + WebSocket 局内通信

**客户端（Godot）**
- 纯 UI 渲染，仅发送指令 + 播放服务器返回
- 通过 WebSocket 接收服务器推送（状态增量、战争/战斗步骤、回合结果）

## 🖥️ 运行环境

| 依赖 | 版本 |
|------|------|
| [Go](https://go.dev/dl/) | **1.24+** |
| [Godot](https://godotengine.org/download) | **4.7.2**（或更新 4.x 版本） |
| 操作系统 | macOS / Windows / Linux |

## 🚀 快速开始

### 1. 启动服务器

```bash
cd server
make run          # 或: go run ./cmd/server
# 服务器监听 0.0.0.0:8080（HTTP + WebSocket）
```

> 注意：本机若 `GOROOT` 环境变量被错误指向 go1.26 模块工具链，请用 `make build` / `make run`（Makefile 已封装 `GOROOT=/usr/local/go GOTOOLCHAIN=local`）。

### 2. 运行客户端

```bash
cd 3k-game
godot --path .    # 客户端启动后自动连接 127.0.0.1:8080
```

或用 Godot 编辑器打开 `project.godot` 后按 F5。

### HTTP 接口

| 方法 | 路径 | 作用 |
|------|------|------|
| POST | `/auth/login` | 登录（开发期 mock，返回 token） |
| POST | `/game/new` | 创建新局，返回全量快照 |
| POST | `/game/save` | 存档到服务器 |
| POST | `/game/load` | 读档 |
| GET | `/game/ws` | WebSocket 游戏长连接 |

## 🧪 测试

### 服务器单元测试（Go）

```bash
cd server
make test         # 运行 internal/game 全部单测
make vet          # go vet 静态检查
```

覆盖：数据加载、武将公式、内政命令、回合/月度、战争准备、自建武将、存档往返一致。

### 客户端校验

```bash
make check        # headless 校验工程（导入资源、检查脚本错误）
```

> 原 GDScript 逻辑测试（`scenes/tests/`、`tests/`）已随逻辑迁移到 Go 服务器删除，逻辑测试现为 `server/internal/game/world_test.go`。客户端仅保留 headless 工程校验。

## 📁 项目结构

```
├── project.godot           # Godot 工程配置（含 autoload：NetClient/Mirror/缓存）
├── Makefile                # 客户端常用命令（run/check）
├── assets/                 # 美术资源（字体/音频/UI 图片）
├── data/                   # 静态配置数据（武将/城池/势力/武器 JSON、阵型/地图 CSV）
├── scenes/                 # 场景（main 主菜单 / ui 各界面）
├── scripts/
│   ├── net/                # NetClient（HTTP+WebSocket）/ Mirror（只读镜像）★ 新增
│   └── ui/                 # UI 逻辑（发指令 + 播结果）
├── server/                 # ★ Go 服务器
│   ├── cmd/server/         # 入口（config + svc + 路由注册）
│   ├── internal/
│   │   ├── config/         # go-zero 配置
│   │   ├── types/          # HTTP DTO
│   │   ├── handler/        # HTTP handler
│   │   ├── logic/          # HTTP 业务逻辑
│   │   ├── svc/            # ServiceContext 依赖注入
│   │   ├── ws/             # WebSocket 网关/协议/session
│   │   ├── game/           # ★ 全部游戏逻辑（entities/rng 子包 + world_test.go）
│   │   └── persist/        # 存档存储
│   └── Makefile            # 服务器命令（build/run/test/vet）
└── addons/                 # Godot 插件
```

## 🛠️ 开发

### 架构（C/S）

**核心设计模式：Go 权威服务器 + Godot 纯 UI 客户端。**

- **服务器唯一权威**：全部随机数（可播种 RNG）、结果判定、AI 决策在服务器完成。客户端只读服务器下发的状态（`Mirror`），不执行任何 `randi*` 或公式。
- **通信**：HTTP 承载一次性动作（登录/建局/存读档）；WebSocket 承载局内命令与服务器推送（状态增量 `S2C_Delta`、战争/战斗步骤、回合结果）。
- **协议**：统一信封 `{"v":1,"type":"req"|"push","seq":N,"op":<opcode>,"body":{}}`；opcode 复用原版 `GameInfo.TaskType` 枚举作为命令表。
- **游戏逻辑层**（`server/internal/game/`）为纯净 Go 包，不依赖 go-zero，可用 `go test` 独立测试，为将来拆分微服务/万人演进预留。
- 修改逻辑前，先理解"服务器哪个函数处理该命令、客户端哪个场景触发它"。

### 客户端 autoload 单例

- **网络**：`NetClient`（登录/建局/存档 HTTP + WebSocket 长连接）、`Mirror`（只读状态镜像）。
- **静态数据渲染**：`DataManager`/`CityListCache`/`CountryListCache`/`GeneralListCache`/`WeaponListCache`/`TextLibrary`/`GameInfo`（仅用于读取武将名/属性/城池坐标等静态配置与枚举，不含游戏逻辑计算）。
- 本地游戏逻辑单例（`TurnManager`/`WarManager`/`BattleManager`/`MapManager`/`SoloManager`）已从 autoload 移除。

### 服务器分层（go-zero）

```
handler → logic → svc(ServiceContext) → game(World)
   │           └→ persist(存档)
   └→ ws(Gateway/Session) ─→ game(World)
```

### 环境要求

- **Go 1.24+**、**Godot 4.7.2**
- **本机坑**：若 `GOROOT` 环境变量被错误指向 go1.26 模块工具链，用 `cd server && make ...`（已封装正确的 `GOROOT`/`GOTOOLCHAIN`）。
- 开发期服务器不依赖 redis/mysql（内存态 + JSON 存档）；`Godot` 开启"警告当错误"，脚本中推断为 Variant 的变量需显式声明类型。

## 🤝 贡献

欢迎任何形式的贡献！请先阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

- 🐛 报告问题 / 💡 建议功能 → [Issues](https://github.com/studyzy/3k-game/issues)
- 🚀 提交代码 → [Pull Requests](https://github.com/studyzy/3k-game/pulls)

## 📄 许可证

本项目以 [MIT](LICENSE) 许可证开源。

> 免责声明：本移植版为学习与致敬目的开发，与光荣（KOEI）及其《霸王的大陆》无任何关联或授权。若涉及任何权利争议，请与维护者联系。
