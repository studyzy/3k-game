# 网页版发布工具（Godot 3.6 Web + 拆包渐进加载 + COS）

把 `bwdl` 导出成 WebAssembly 网页版，拆成「核心包 / 资源包」两段异步加载，
大文件托管到腾讯云 COS，本机只发几十 KB 的外壳文件。

线上示例：`https://124.221.164.209/3k/`

## 文件

| 文件 | 作用 |
| --- | --- |
| `3k-deploy.sh` | 一键发布：导出 → 拆包 → 预压缩 → 注入外壳补丁 → 上传 COS → 同步本机 |
| `3k-pck-split.py` | 解析 `.pck` 索引，按路径规则拆成核心包 `index.pck` 与资源包 `assets.pck` |
| `3k-patch.py` | 给导出的 `index.html` 打补丁（幂等）：COS 地址、进度面板、全屏按钮、资源包后台下载 |
| `3k-panel.js` | 底部下载进度面板的 JS（被 `3k-patch.py` 内联注入） |
| `3k-fullscreen.js` | 手机端全屏按钮 / 首次手势自动全屏 / 竖屏提示的 JS（同样内联注入） |
| `3k-font-subset.py` | 字体子集化（`msyh.ttf` 18.35MB → 6.66MB，需 fonttools） |

## 用法

```bash
# 完整发布（导出 + 拆包 + 上传）
tools/web-deploy/3k-deploy.sh

# 已经导出、拆好包，只重做外壳补丁 + 上传 + 同步（改 JS 后最常用）
tools/web-deploy/3k-deploy.sh --no-split

# 只用现有 build/web，不重新导出
tools/web-deploy/3k-deploy.sh --no-export

# 不用 COS，所有文件放本机（回滚开关）
tools/web-deploy/3k-deploy.sh --local
```

依赖：

- Godot 3.6.3 编辑器 + 对应导出模板（`~/.local/share/godot/templates/3.6.3.stable`），无显示器环境靠 `xvfb-run`
- `coscmd`（Python 包，`coscmd config -a <id> -s <key> -b <bucket> -r <region>` 写 `~/.cos.conf`）
- COS 桶需配置 CORS：允许站点 origin 的 `GET,HEAD`，并 expose `Content-Length, Content-Type, Content-Encoding, Accept-Ranges`
- 对象 `index.wasm` 的 `Content-Type` 必须是 `application/wasm`，`index.pck` 需带 `Content-Encoding: gzip`（发布脚本已处理）

## 拆包与加载顺序

1. `index.wasm`（19.8MB）+ `index.pck`（77MB，gzip 后 39MB）先下载 → 引擎启动，标题画面出现
2. 外壳随后用 XHR 下载 `assets.pck`（16MB，音频 + 战斗大图），写完调 `engine.copyToFS`
3. GDScript 侧 `script/WebAssets.gd` 轮询 `window.__assetsPckReady`，到点用
   `ProjectSettings.load_resource_pack("assets.pck")` 挂载并广播 `assets_ready`
4. `Scene_Manager` 在资源未就绪时挡住非菜单场景切换，`Sound_Manager` 把 BGM 记为 pending，就绪后补播

## 改前端时的注意事项

- 进度面板 / 全屏逻辑的 JS 在 `3k-panel.js`、`3k-fullscreen.js` 里，**改完要同时把
  JS 里的 `__dlPanelVer` / `__fsVer` 和 `3k-patch.py` 里的 `PANEL_VER` / `FS_VER` 一起递增**，
  否则注入器会认为已经是最新版本而不替换。
- `engine.preloadFile()` 只在 `engine.init()` 之前把文件写进虚拟文件系统；引擎已经在跑时
  必须自己 `fetch`/XHR 拿数据再 `engine.copyToFS()`，否则 `load_resource_pack` 会返回 false。