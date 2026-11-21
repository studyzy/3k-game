# 2026-11-21 网页版云存档（单数槽位网络存档）

状态：已批准（2026-11-21）。本文是对话中批准的短设计的落盘记录，实现计划另见 `docs/superpowers/plans/`。

## 意图与 why

网页版（WebAssembly）的存档目前只落在浏览器 `IndexedDB`（Godot 3 把 `user://` 映射到 IDBFS）。换一台设备或换一个浏览器，存档就没了。目标是在保持本地存档可用的前提下，给**部分存档位**加服务器副本，并用 URL 里的一个 ID 把两者绑起来：收藏这个 URL，在任何设备打开就能接着玩。

不做账号体系。链接本身就是钥匙——拿到链接的人可读可覆盖，这是"收藏 URL 即可续玩"的必然代价，已在设计时与用户确认接受。

## 术语

- **云存档 ID**：UUID v4（36 字符），一个玩家一个，每次手动存档覆盖同一个 ID。
- **网络槽位**：显示编号为**单数**的手动槽位（`#1 #3 #5 … #51`），保存时同时写本地与服务器。
- **本地槽位**：显示编号为**双数**的手动槽位（`#0 #2 #4 … #50`），只写浏览器本地。
- **槽位号（slot）**：存档文件名里的十进制数字字符串，`0..51`，与显示编号一致。自动位（`endless` `monthly` `annualy` `defence` `paused`）与快速存档（`quick` `quick_e`）不算槽位。

## 现状（本设计依赖的事实）

- 本地存档目录：`DataManager.get_common_path() + "save/"`，web 下即 `user://sgz/save/`，文件名 `<name>.sav`，内容是 JSON 文本。
- 手动槽位合法性由 `bwdl/script/objects/clSaveDataIndex.gd` 的 `expected_save_item()` 定义：`0 <= id < SAVE_PAGE_TOTAL * 4`（`SAVE_PAGE_TOTAL = 13`，即 `0..51`）。
- 存档与读档界面：`bwdl/windows/menu/SaveLoad.gd`、`SaveLoad_Item.gd`；底部 `lblLocation` 目前显示本地存档路径。
- 读档复用现有流程串 `load_game_data|<path>`：读文件 → `parse_json` → `set_save_data` → 重建 flows → `go_to_scene`。因此云端拉下来的存档只需先落成本地 `.sav` 文件。
- `agent-service`（Node 22+，无构建步骤）已同源托管 `bwdl/build/web/`，云存档路由加在 `agent-service/src/server.ts` 即可，无跨域问题。
- 现有 `AIHttpClient.gd` 的 HTTP 用法可仿写：`Content-Type: text/plain; charset=utf-8`；`HTTPRequest` 必须挂在 `SceneManager` 下（`/root` 在场景搭建期间 busy），`SceneManager` 的 `pause_mode = 2`，暂停中仍可工作。

## 目标

1. 单数槽位保存时，本地写一份并上传到服务器；服务器返回同步结果。
2. 打开网页时 URL 带 `?save=<uuid>`，若云端有存档，弹框确认后合并到本地。
3. 首次打开（无 URL、无本地记录）自动生成 UUID 并写回 URL，用户收藏即可。
4. 界面能区分哪些槽位是网络存档，并能一键复制带 ID 的链接。
5. 本地存档与云同步解耦：网络失败不影响本地存档成功。

## 非目标

- 不做账号、登录、多 ID、多人共享。
- 不做自动存档的云同步（`endless`/`monthly`/`annualy`/`defence`/`paused`/`quick`/`quick_e` 始终纯本地）。
- 不做云端删除（`SaveLoad` 没有删除存档的入口，故不存在"本地删了云端还在"）。
- 不做冲突合并（同槽位两台设备都存 = 后写覆盖先写）。
- 不做离线队列/失败自动重试（失败只提示，下次手动存即覆盖）。
- 不把保留的本地较新槽位自动回传云端。
- 不提供 `GET /save/:id/:slot` 单槽读取（打开时一次拉整包即可）。

## 反目标

- 不能因为云同步失败而让本地存档失败或卡住 UI。
- 不能因为一次上传而覆盖同一 ID 下的其它槽位。
- 不能让浏览器本地存档路径、`SaveDataIndex` 的结构发生不兼容变化（旧存档必须还能读）。

## 设计

### 1. ID 与 URL

启动时按顺序决定当前 ID：

1. URL 里有 `?save=<合法 UUID>` → 用它。
2. 否则本地 `user://sgz/cloud_id.txt` 有合法 UUID → 用它，并 `history.replaceState` 把参数补回 URL。
3. 否则浏览器支持时 `crypto.randomUUID()` 生成（不支持则自建 v4），写入本地并补回 URL。

- 参数名固定 `save`。
- 回写 URL 用 `URLSearchParams` 设置 `save` 后 `history.replaceState`，保留原有其它参数；不改 origin、不产生历史记录。
- ID 只存在本地文件与 URL 里；服务端只做格式校验，不校验归属。

### 2. 槽位分区

| 槽位 | 本地 `.sav` | 上传 |
|---|---|---|
| `#1 #3 … #51`（单数） | 写 | 写成功后上传该槽位 |
| `#0 #2 … #50`（双数） | 写 | 不上传 |
| 自动位 / 快速存档 | 写 | 不上传 |

判定：`int(slot) % 2 == 1`，且 `slot` 必须通过 `expected_save_item()`。

### 3. 服务端

新增路由（`agent-service/src/server.ts`）：

| 方法 | 路径 | 行为 |
|---|---|---|
| `PUT` | `/save/:id/:slot` | 写入/覆盖该 ID 的该槽位 |
| `GET` | `/save/:id` | 返回该 ID 下全部槽位；一个都没有 → `404` |
| `OPTIONS` | 以上 | 预检，`allow-methods` 增加 `PUT` |

写入响应：`{ "ok": true, "slot": "1", "syncedSlots": 3, "updatedAt": "2026-11-21T12:34:56.000Z" }`，`syncedSlots` 为该 ID 当前槽位文件数。

读取响应：

```json
{
  "id": "3f2b…",
  "updatedAt": "2026-11-21T12:34:56.000Z",
  "slots": { "1": { "存档时间": "…", "...": "…" }, "3": { } }
}
```

`slots` 的值为存档 JSON 原对象（不是字符串套娃），键为槽位号字符串。

**存储布局**：`<SAVE_DIR>/<uuid>/<slot>.json`，一槽一文件。

选一槽一文件而不是"一 ID 一个 JSON"的理由：单文件方案下每次 `PUT` 都要读-改-写整个文件，两台设备各存一个槽位会互相覆盖；分文件后每个槽位独立原子写，互不干扰。

**校验**（任一不满足 → `400`）：

- `id` 匹配 UUID v4 正则；不匹配返回 `400`（不是 404，避免被当作存在性探测以外的语义）。
- `slot` 必须匹配 `^(?:[0-9]|[1-4][0-9]|5[01])$` 且为奇数，否则 `400`。
- Body 能被 `JSON.parse` 解析为对象，否则 `400`。
- Body 长度 ≤ `SAVE_MAX_MB`（默认 32MiB），超出 `413`。
- 该 ID 目录写入后总大小 > `SAVE_TOTAL_MB`（默认 2048）→ `413`。

**落盘**：写到 `<slot>.json.tmp` → `fs.rename` 覆盖。目录不存在先 `mkdir -p`。

**读取**：`readdir` 目录，只认 `^[0-9]{1,2}\.json$`，逐个读取并 `JSON.parse`；`skipped` 掉非法/损坏文件并记一条日志。`updatedAt` 取所有文件中最大的 `mtime`。空目录或不存在 → `404`。

**TTL 清理**：进程启动时与每 6 小时一次，扫描 `SAVE_DIR` 下各 ID 目录，删除 `mtime` 早于 `SAVE_TTL_DAYS`（默认 365）的槽位文件；目录空了就删目录。清理失败只记日志，不影响服务。

**日志**：对外日志里 ID 只打印前 8 位 + `…`，不打印完整 URL。

**类型/Content-Type**：请求与响应都用 `text/plain; charset=utf-8` 的 body，内容本身是 JSON 文本；与现有 `AIHttpClient` 的写法一致。

### 4. 客户端 `Cloud_Save`（新增 autoload）

`bwdl/script/Cloud_Save.gd`，在 `project.godot` 注册为 autoload，名字 `CloudSave`。

- 仅在 `OS.get_name() == "HTML5"` 时启用；其它平台 `enabled = false`，所有方法直接返回（保证桌面版与安卓构建不被牵连）。`JavaScript` 单例只在 HTML5 导出里存在，因此必须在调用前就用平台名判掉。
- `HTTPRequest` 节点在首次请求时创建为 **`SceneManager` 的子节点**（照 `AIHttpClient._ensure_http()` 的注释：`/root` 在场景搭建期间 busy），并显式设 `pause_mode = Node.PAUSE_MODE_PROCESS`——存档菜单会暂停整棵树，不设它上传要等玩家关菜单才推进。
- 对外接口：
  - `ensure_id()` — 执行上面"ID 与 URL"三步，返回当前 ID。
  - `upload_slot(slot: String, save_path: String) -> void` — 读本地 `.sav` 文本，`PUT /save/<id>/<slot>`。
  - `begin_session(owner, method_name) -> void` — `GET /save/<id>`，结果以 `{ ok, slots, total, error }` 回调。
  - `get_synced_count() -> int` — 最近一次成功响应里的 `syncedSlots`（或 `begin_session` 的槽位数）。
  - `copy_link()` — 见界面一节。
- 串行化：同一时刻只有一个 `HTTPRequest` 在飞。待上传按**槽位**排队（`pending[slot] = path`），同一槽位重复保存只保留最新一份，不同槽位各自保留一次；GET 优先于 PUT。上传成功/失败都用 `SceneManager.show_system_notice` 提示。
- 超时 30 秒（存档可能较大）。

### 5. 保存流程

`SaveLoad_Item.save_data_confirmed()` 现有逻辑不变：`DataManager.set_env("saveSlot", …)` → `DataManager.save_game_data(name)` → `refresh_data()` → `emit_signal("saved")`。

追加：若该 `save_item_desc` 是网络槽位，调用 `CloudSave.upload_slot(desc, save_path)`。

提示语（存完立刻显示，不阻塞面板）：

- 网络槽位成功：`网络存档已同步（共 N 个）`
- 网络槽位失败：`本地已保存，云端同步失败`
- 本地槽位：`已保存到本地（双数槽位）`

### 6. 启动与合并

挂点：`bwdl/scene/scene_open/scene_open.gd` 的 `_ready`，在 `if not StaticManager.game_init_done:` 块内调用 `CloudSave.begin_session()`——每个进程只拉一次；回到标题不重复合并。响应迟到时若 `model_view != 0`（玩家已开局）则直接丢弃，不合并也不弹框。

- `404` → 云端还没有存档，静默继续（不弹框）。
- 网络错误/超时 → 静默继续，不打断开局，只在控制台记一条。
- 有 `slots` → 逐个槽位比较：

  1. 每个槽位把云端 JSON 与本地 `user://sgz/save/<slot>.sav` 比较，取 `存档时间`（格式 `YYYY-MM-DD HH:MM:SS`，字符串可直接比大小）。本地不存在 → 恢复；本地存在且云端更新 → 覆盖（写入前把旧文件备份为 `<slot>.sav.bak.<存档时间去冒号>`，避免下次恢复把上一份备份冲掉；备份失败则不覆盖）；本地更新或相同 → 保留本地。
  2. 双数槽位即使云端混进来也不处理（服务端已经拒绝写入，这里是第二道闸）。
  3. 合并完逐个 `StaticManager.saveIdx.update_save_index(slot)` 清缓存，让读档列表看到新文件。

- 弹框（`SceneManager.confirm`）：
  `云端发现 N 个网络存档位，已恢复 X 个，保留本地较新 Y 个。是否打开读档列表？`
  确认 → 打开读档面板；取消 → 正常进入开场流程。
- 弹框期间屏蔽 `scene_open._on_key_event()` 的 `EMU_START`（新增 `if SceneManager.popuped: return`），避免两套输入同时生效。
- 读档仍由用户自己点槽位，不自动开局——云端存档可能不是玩家此刻想玩的。

### 7. 界面

- `SaveLoad_Item.refresh_data()`：标题由 `存档点:#N` 改为 `存档点:#N（网络）` / `（本地）`。判断同槽位规则；在非 HTML5 平台不显示后缀（桌面版没有云同步，显示会误导）。
- `SaveLoad.tscn` 底部 `gc/footer/lblLocation` 文本改为：`云存档：已同步 N 个网络存档位 · [复制链接]`。用 `RichTextLabel` 的 `meta_clicked` 做可点文字，或在其右侧加一个 `Button`——实现计划里定，spec 只要求"可点击"。
- `copy_link()`：优先 `JavaScript.eval("navigator.clipboard.writeText(location.href)")`；`navigator.clipboard` 在非安全上下文（非 HTTPS / 非 localhost）不可用，失败则弹 `SceneManager.confirm` 显示完整 URL 让用户手动复制。成功后 `show_system_notice("链接已复制")`。
- 非 HTML5 平台：隐藏"复制链接"，底部仍显示原有本地存档路径。

## 约束

- Godot 3.6.3 / GDScript 1.0：`onready var`、无 `@export`、`PoolStringArray`、`File`/`Directory`，不能用 4.x API。
- `agent-service` 无构建步骤（Node 直接跑 TS），新增代码必须保持"`node src/server.ts` 就能起"。
- 存档路由的 body 上限必须独立于 AI 路由现有的 `MAX_BODY = 1MiB`，不能把 AI 路由的上限放大。
- 部署是 Docker 只读根文件系统，云存档目录必须是可写卷（`-v <host>:/app/data`），默认 `SAVE_DIR=/app/data/saves`。
- 网页版必须由 `agent-service` 托管才有云存档；`make serve` 的 `python3 -m http.server` 只有本地存档（需要在 README 里写清）。

## 失败模式与取舍

| 情况 | 行为 |
|---|---|
| 上传失败/超时 | 本地已成功；提示"本地已保存，云端同步失败" |
| 打开时 GET 失败 | 静默继续，用本地存档 |
| 云端包里有坏文件 | 服务端跳过并记日志；客户端只处理能解析的槽位 |
| 两台设备同时存同一槽位 | 后写覆盖先写（用户已知） |
| 两台设备同时存不同槽位 | 互不影响（一槽一文件） |
| 用户清了浏览器数据 | 本地 ID 丢失，但收藏的 URL 还在；打开后按 URL 重建本地 ID，再从云端恢复网络槽位 |

## 安全

- ID 是 UUID v4，不可枚举；但链接泄露 = 存档可读可覆盖，这是设计接受的取舍（用户明确选择，不做账号）。
- 路径穿越：`id` 用严格 UUID 正则、`slot` 用严格数字正则校验后才拼路径；不接受 `..`、`/`、空串。
- 请求体大小限制 + 每 ID 总量限制，防止单个 ID 打满磁盘。
- 整包 GET 一次最多拼 64MiB（`MAX_BUNDLE_BYTES`），超出返回 413：配额上限允许 832MiB 时，全量读入足以打爆进程内存。
- 日志 ID 脱敏。
- 不做速率限制（单机自用服务，`agent-service` 本来也没做）。若以后公网高暴露，再补。

## 配置项（`agent-service/src/config.ts`）

| 名称 | 参数 | 环境变量 | 默认 |
|---|---|---|---|
| 存档目录 | `--save-dir` | `SAVE_DIR` | `<repo>/agent-service/data/saves`（Docker 内 `/app/data/saves`） |
| 单槽上限 | `--save-max-mb` | `SAVE_MAX_MB` | `32` |
| 单 ID 总量 | `--save-total-mb` | `SAVE_TOTAL_MB` | `2048` |
| TTL 天数 | `--save-ttl-days` | `SAVE_TTL_DAYS` | `365` |

`.gitignore` 需覆盖 `agent-service/data/`。

## 测试计划

**Node**（`agent-service/test/save.test.ts`，沿用 `test/server.test.ts` 的 `mkdtemp` + `listen(0)` 模式）：

- 首次 `GET` → 404。
- `PUT` 一个槽位 → 200，`syncedSlots = 1`；`GET` 能取回同样的 JSON。
- 连续 `PUT` 两个槽位 → `GET` 返回两个；再 `PUT` 覆盖第一个，第二个不受影响。
- 非法 UUID → 400；双数槽位 `0`/`2` → 400；`52`、`99`、`1.5`、`abc` → 400。
- Body 非 JSON / 是 JSON 数组 / 是 `null` → 400。
- Body 超过 `saveMaxMb` → 413；总量超 `saveTotalMb` → 413。
- 存档目录里放一个坏 `.json` 与一个随机文件名 → `GET` 跳过它们且不 500。
- TTL：构造 `mtime` 超期的文件，触发清理后文件消失、空目录被删。
- `OPTIONS /save/x/1` 返回的 `allow-methods` 含 `PUT`。

**Godot**：

- 新增 `bwdl/test/cloud_save_validate.gd`（headless 下 `Cloud_Save.gd` 可加载、`enabled == false`、槽位奇偶判定正确），并加入 `bwdl/test/ai_agent_validate.gd` 的脚本清单。
- `agent-service/test/gdscript-refs.test.ts` 会自动覆盖新脚本引用的单例成员；新增成员必须确实存在于声明处。

## 部署影响

- `Makefile` 增 `serve-agent` 目标：`node agent-service/src/server.ts --web-dir bwdl/build/web`。
- `agent-service/Dockerfile` 增加 `ENV SAVE_DIR=/app/data/saves`；`docker run` 必须挂可写卷到 `/app/data`，否则 `PUT` 失败（只读根文件系统）。
- `agent-service/README` 补两条路由、四个配置项、"没有 HTTPS 时复制链接会退化为手动复制"。

## 决定与判断

**用户决定：**

- 场景是"自己多设备/换浏览器续玩"，不是分享。
- 一个固定云存档 ID，每次手动存档覆盖同一 ID。
- 仅手动存档同步；自动存档不联网。
- 带 ID 打开时弹框确认后读取，取消则正常开局。
- 复用现有 `agent-service`（方案 A），不新建服务。
- 用 GUID/UUID 做 ID；新开游戏时 URL 里就带随机 ID，收藏 URL 即可换浏览器续玩。
- 单数槽位 = 网络存档，双数槽位 = 本地存储；按**显示编号**划分。
- **每次上传只上传该槽位本身**，不打包全部单数槽位。

**以下为我的判断（builder 可复核，非用户已同意项）：**

- 存储用"一槽一文件"而不是"一 ID 一个 JSON"：避免读-改-写导致的跨槽位覆盖。
- 写接口 `PUT /save/:id/:slot`、读接口 `GET /save/:id` 一次返回整包：写要窄、读要省请求。
- 合并按 `存档时间` 字符串比大小（格式固定，可直接比较），不做时钟偏移校正。
- 覆盖前把本地旧档备份成 `.sav.bak.<存档时间>`，给一次反悔机会（固定名会被下一次恢复冲掉）。
- 合并后不自动进游戏，只问"是否打开读档列表"。
- 非 HTML5 平台不显示"（网络）/（本地）"后缀与复制链接，避免误导。
- 失败不做自动重试与离线队列：状态复杂度换不来多少收益，手动再存一次即可覆盖。
- 非安全上下文复制失败时退化为显示 URL 手动复制，而不是静默失败。