# CODEBUDDY.md

This file provides guidance to CodeBuddy Code when working with code in this repository.

## 项目概述

「霸王的大陆」的 **客户端/服务器（C/S）复刻版**：三国志题材策略游戏，选君主势力，回合制内政 + 战争（大地图网格 + 战前布阵 + 战术战斗）+ 月度事件。目标是 100% 复刻原版《三国志2 霸王的大陆》的数据与逻辑。

**架构核心**：
- **Go 权威服务器**（`server/`，go-zero + WebSocket）：承载全部游戏逻辑（数值公式、内政、战争、战术战斗、月度事件、AI、随机数、结果判定）。
- **Godot 4 纯 UI 客户端**：只渲染界面 + 发指令 + 播结果，不做逻辑计算。

服务器是唯一权威，客户端无法篡改随机数/属性/资源，天然防作弊；每局独立、状态存服务器，支持跨设备与云端存档。

## 运行与测试命令

### 服务器（Go）

```bash
cd server
make run          # 启动服务器，监听 0.0.0.0:8080
make build        # 构建二进制
make test         # 运行 internal/game 全部 Go 单测
make vet          # go vet 静态检查
make tidy         # go mod tidy
make db-up        # 启动 docker MySQL（首次自动执行 db/init/*.sql 建表）
make db-down      # 停止 docker MySQL（保留数据卷）
make integration  # 端到端集成测试：起 MySQL → 编译 → 起服务 → 跑 test/integration 全流程
```

> **⚠️ 本机环境坑**：`GOROOT` 环境变量被错误指向 go1.26 模块工具链，与系统 go1.24.12 冲突。**必须用 `make ...`**（Makefile 已封装 `GOROOT=/usr/local/go GOTOOLCHAIN=local`），否则 `go build` 报 stdlib 版本不匹配。
>
> **数据库（MySQL/gorm）**：日常单测/开发默认 `InMemory=true`（不依赖 DB）。要接入 MySQL 存用户+存档：
> - 环境变量 `3k_DSN`（gorm DSN，如 `root:root@tcp(127.0.0.1:3306)/3k?charset=utf8mb4&parseTime=True&loc=Local`）设置后 `InMemory` 自动变 false（也可用 `3K_IN_MEMORY` 强制指定）。
> - `3K_LISTEN`（监听地址）、`3K_DATA_DIR`（数据目录）可覆盖默认。
> - 集成测试封装为 `make integration`，内部自动起 docker MySQL 并用随机端口 `18080`，不污染本机 8080。
> - `make integration` 可覆盖：`make integration INT_PORT=9090 MYSQL_PORT=3307`。

### 客户端（Godot）

环境要求：**Godot 4.7.2**（`godot` 在 PATH 中）。客户端启动后自动连接 `127.0.0.1:8080`。

```bash
make run          # 运行客户端
make check        # headless 校验工程（导入资源、检查脚本错误）
```

> 客户端开启"警告当错误"（`--headless` 校验时最明显）。脚本里推断为 Variant 的变量（`var x := JSON.parse_string(...)` 等）必须显式声明类型（`var x: Variant` / `: Dictionary`），否则报 parse error。
>
> 客户端逻辑测试已随逻辑迁移到 Go 删除（旧 `scenes/tests/`、`tests/` 已清理），逻辑测试见 `server/internal/game/world_test.go`。

## 架构总览

### 通信与协议

- **HTTP**（一次性动作）：`/auth/login`、`/game/new`、`/game/save`、`/game/load`。
- **WebSocket**（局内命令 + 推送）：`/game/ws`。服务器推送状态增量 `S2C_Delta`、战争/战斗步骤、回合结果。
- **登录鉴权**：接库模式下 `/auth/login` 签 token（`auth_tokens` 表存 SHA-256），WS 握手校验 `token` 查询参数，`playerId` 必须与 token 匹配。内存态/兼容旧客户端时可仅凭 `sessionId` 连接。
- **协议信封**：`{"v":1,"type":"req"|"push","seq":N,"op":<opcode>,"body":{}}`。opcode 定义在 `server/internal/ws/protocol.go`；命令表复用原版 `GameInfo.TaskType` 枚举（`C2S_*` 请求、`S2C_*` 推送）。

### 服务器分层（go-zero 最佳实践）

```
server/
├── cmd/server/main.go      # 入口：config + svc + registerHTTPRoutes/registerWSGateway
└── internal/
    ├── config/             # go-zero 配置
    ├── types/              # HTTP DTO（Login/NewGame/SaveGame/LoadGame 请求响应）
    ├── handler/            # HTTP handler（httpx.OkJson，只做解析+调logic+写响应）
    ├── logic/              # HTTP 业务逻辑（Login/CreateGame/SaveGame/LoadGame/ResolveSession）
    ├── svc/                # ServiceContext（依赖注入 + Session 管理 + GetSession）
    ├── ws/                 # WebSocket：protocol/session/gateway/handler（DefaultHandler 分发 C2S）
    ├── game/               # ★ 全部游戏逻辑（纯净 Go 包，不依赖 go-zero）
    │   ├── world.go        # WorldState 权威状态聚合
    │   ├── entities/       # General/City/Country/Weapon/Alliance/Troop/Unit + worldref
    │   ├── rng/            # 可播种 RNG（单会话确定性）
    │   ├── turn.go         # EndPlayerTurn/AI回合/月度事件
    │   ├── execute.go      # ExecuteTask 命令分发（全内政/外交命令）
    │   ├── war.go + map.go # 战争状态机 + A* 寻路
    │   ├── battle.go + tactic.go  # 战术战斗 + 6 战术
    │   ├── plan.go         # 16 计策（rate/result 全公式）
    │   ├── solo.go         # 单挑
    │   ├── cache.go        # 离间/招揽/登用/君主死亡继承
    │   ├── selfbuild.go    # 自建武将（随机服务器化）
    │   ├── serialize.go    # 序列化（存档）+ 补齐 4 缺口
    │   └── loader.go/text.go/config.go/gameinfo.go
    └── persist/            # 存档存储（JSON 文件 saves/<player>/<slot>.json）
```

**调用链**：`handler → logic → svc → game(World)`，`ws` 也直接驱动 `game(World)`。

### 客户端（Godot）autoload 单例

- **网络**：`NetClient`（HTTP 登录/建局/存档 + WebSocket 长连接，`server_push` 信号）、`Mirror`（只读状态镜像：`apply_delta`/`apply_war`）。
- **静态数据渲染**：`DataManager`/`CityListCache`/`CountryListCache`/`GeneralListCache`/`WeaponListCache`/`TextLibrary`/`GameInfo` —— 仅用于读取武将名/属性/城池坐标等静态配置与枚举，**不含游戏逻辑计算**。
- **已移除的本地逻辑单例**：`TurnManager`/`WarManager`/`BattleManager`/`MapManager`/`SoloManager`（逻辑已迁移到服务器，不再 autoload）。
- **命令触发**：UI 场景通过 `NetClient.send(C2S_*)` 发指令，监听 `NetClient.server_push` 收结果。如 `executive_panel.gd` 发 `C2S_EXECUTE_TASK`、`war_scene.gd` 发 `C2S_WAR_*`。

### 数据流

**服务器权威**：客户端只读 `Mirror`（服务器 `S2C_Delta` 增量更新），**不执行任何 `randi*` 或公式**。静态配置（`data/*.json`）客户端本地加载用于渲染，服务器 `server/data/` 持有同样数据用于权威计算。

## 工程约定

- 语言为简体中文（文本、注释、日志、`show_info` 提示）。
- **服务器是唯一写入方**，客户端任何字段都不允许写回（防作弊）。
- 随机数统一走 `World.Rng`（可播种），保证单会话顺序确定性、可回放。新增随机逻辑必须用 `w.Rng.*`，不要用 Go 全局 `rand`。
- 存档是完整 JSON 快照（`World.Serialize/Deserialize`），新增实体字段需同步序列化；注意原版 4 处存档缺口（City 4武将数组/Country allianceList/WarBattle状态/GameInfo字段）已补齐。
- 新增服务器逻辑：在 `server/internal/game/` 加文件 + 写 `world_test.go` 单测（`make test`）。
- 客户端 UI 改动：加中文注释、显式类型声明、用 `NetClient`/`Mirror` 而非本地逻辑。
- `.godot/` 缓存目录不入库。
