<div align="center">

# 霸王的大陆（Godot 3.5.3 反编译工程）

**「霸王的大陆GD安卓版 GD2560.Apk」反编译得到的完整可运行 Godot 3.5.3 工程**

![Godot](https://img.shields.io/badge/Godot-3.5.3-478cbf?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-1378%20个脚本-478cbf)
![License](https://img.shields.io/badge/License-仅供学习研究-red.svg)

</div>

## 📖 简介

本仓库是把安卓游戏 **《霸王的大陆GD安卓版 GD2560.Apk》**（游戏内版本 **2.560**，一款 Godot 3.5.3 导出的三国策略游戏，游戏内项目名为 `Sgz Bwddl`，即「三国志2 霸王的大陆」复刻版）反编译、重组后的 **可编译、可运行** 的完整 Godot 工程。

> ⚠️ **版权声明**：原版《霸王的大陆》为光荣（KOEI）的版权作品，本 APK 为第三方复刻。本项目仅用于**学习研究反编译技术与游戏逻辑**，不包含任何自主创作，请勿用于任何商业用途或二次分发。

## 🗂 目录结构

| 路径 | 说明 |
|---|---|
| `bwdl/` | **反编译后的完整 Godot 3.5.3 工程**（主交付物） |
| `bwdl/script/` | 框架脚本（战斗、内政、战争、技能、数据管理） |
| `bwdl/scene/` | 各场景脚本（标题、内政、战斗、单挑、战争等） |
| `bwdl/windows/` | UI 控件脚本 |
| `bwdl/resource/` | 美术/音频/字体资源（PNG、OGG、TTF 等） |
| `bwdl/packed/data/` | 游戏数据（武将/城市/技能/装备/剧本等 JSON，可直接改） |
| `bwdl/packed/images/` | 运行时图片（909 张） |
| `bwdl/packed/sgz_script/` | 游戏规则脚本（1192 个 `.gd`，原作者明文源码，含中文注释） |
| `Godot_3.6.3.app/` | 运行本工程所需的 Godot 编辑器（macOS 版，`make setup` 自动下载到项目内，不入库） |
| `GD2560.Apk` | 原始 APK（仅反编译输入源，已不需要） |

## 🔧 内容统计

| 类型 | 数量 | 说明 |
|---|---|---|
| 框架脚本（`.gd`） | 189 | 从 `.gdc` 字节码反编译 |
| 规则脚本（`sgz_script/*.gd`） | 1192 | 原作者明文源码，本身含中文注释 |
| 场景（`.tscn`） | 117 | 文本格式 |
| 纹理（`.png`） | 909 + 909 | 工程内资源 + 运行时打包资源 |
| 音频（`.ogg`） | 55 | 从 `.oggstr` 还原 |
| 数据（`.json`） | 1204 | 武将/城市/技能/装备等，可直接修改 |
| 资源/着色器 | 24 + 2 | `.tres` / `.gdshader` 文本格式 |

## 🚀 快速开始

### 环境要求

- **Godot 3.6.3**（执行 `make setup` 下载到项目内 `Godot_3.6.3.app/`，不影响系统全局的 Godot 4）
- 注意：**不能用 Godot 4.x** 打开（脚本为 GDScript 1.0 语法，会报版本不兼容）；`make` 各目标已自动优先使用项目内的 3.6.3

### 运行方式

```bash
# 方式一：Makefile（推荐）
make run          # 运行游戏
make edit         # 打开编辑器
make check        # headless 校验工程
make clean        # 清理导入缓存

# 方式二：直接命令行
./Godot_3.6.3.app/Contents/MacOS/Godot --path bwdl
```

> 💡 这是**移动端（触摸）游戏**，桌面运行靠鼠标模拟触摸（`project.godot` 已开启 `emulate_touch_from_mouse`）。游戏存档会写到 Godot 可执行文件同级的 `sgz/` 目录。

### 网页版（WebAssembly）

```bash
make web          # 导出到 bwdl/build/web/（index.html + .js + .wasm + .pck，约 122MB）
make serve        # 起本地 HTTP 服务预览，默认 http://localhost:8060
```

- 必须通过 HTTP 访问，**不能直接双击 `index.html`**（`file://` 下浏览器禁止加载 wasm/pck）。
- 网页版存档走 `user://sgz/save/`，Godot 3 的 Web 导出把 `user://` 映射到 IndexedDB：按 origin（协议+域名+端口）隔离，清站点数据/无痕模式/换端口都会丢档。
- `bwdl/export_presets.cfg` 的各预设都带 `exclude_filter="build/*"`，否则导出产物会被打进下一次导出（web 包会从 103MB 涨到 310MB）。

## 📝 中文注释说明

本次 **2.560** 基线是 GDRE 的原始反编译产物，框架脚本未添加人工注释；此前 2.540 版本中逐文件添加的中文注释保留在 git 历史里，需要时可另行回搬。`packed/sgz_script/` 下的 1192 个规则脚本是原作者明文源码，本身自带中文注释。

## 🔬 反编译方法（可复现）

本工程使用 [GDRETools/gdsdecomp](https://github.com/GDRETools/gdsdecomp)（Godot RE Tools v2.7.4）完成：

```bash
# 1. 从 APK 恢复散装资源 + 反编译 .gdc
GDRE_tools --headless --recover=GD2560.Apk --output=bwdl

# 2. 内层 bwdl.pck 前面是「8 字节签名长度 + 512 字节 RSA 签名」，去掉 520 字节后再解包
python3 -c "from pathlib import Path; d=Path('bwdl/resource/bwdl.pck').read_bytes(); Path('/tmp/bwdl.pck').write_bytes(d[520:])"
GDRE_tools --headless --extract=/tmp/bwdl.pck --output=/tmp/bwdl_packed
cp -R /tmp/bwdl_packed/packed/. bwdl/packed/
```

该工具一次性完成：`.gdc` 字节码反编译、`project.binary` 还原、`.stex`→`.png`、`.oggstr`→`.ogg` 等资源转换。

> 📌 关于加密数据：原版游戏的数据打包在 `resource/bwdl.pck`（带 520 字节 RSA 签名头的标准 PCK）。反编译后**已把 pck 内容解包为 `res://packed/` 下的真实文件**（`data` / `images` / `sgz_script`），并修改了 `Static_Manager.gd` 跳过 pck 加载与验签。因此现在**无需加密/签名**，直接改 `packed/` 下的 JSON 或脚本即可，导出时 Godot 会明文打包。

## 📄 License

仅供学习研究使用。原版游戏版权归其原作者所有。
