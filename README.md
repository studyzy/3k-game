<div align="center">

# 霸王的大陆（Godot 3.5.3 反编译工程）

**「霸王的大陆GD安卓版 2540.Apk」反编译得到的完整可运行 Godot 3.5.3 工程**

![Godot](https://img.shields.io/badge/Godot-3.5.3-478cbf?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-1378%20个脚本-478cbf)
![License](https://img.shields.io/badge/License-仅供学习研究-red.svg)

</div>

## 📖 简介

本仓库是把安卓游戏 **《霸王的大陆GD安卓版 2540.Apk》**（一款 Godot 3.5.3 导出的三国策略游戏，游戏内项目名为 `Sgz Bwddl`，即「三国志2 霸王的大陆」复刻版）反编译、重组后的 **可编译、可运行** 的完整 Godot 工程。

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
| `bwdl/packed/images/` | 运行时图片（2207 张） |
| `bwdl/packed/sgz_script/` | 游戏规则脚本（1189 个 `.gd`，原作者明文源码，含中文注释） |
| `Godot_3.5.3.app/` | 运行本工程所需的 Godot 3.5.3 编辑器（macOS 版） |
| `霸王的大陆GD安卓版 2540.Apk` | 原始 APK（仅反编译输入源，已不需要） |

## 🔧 内容统计

| 类型 | 数量 | 说明 |
|---|---|---|
| 框架脚本（`.gd`） | 189 | 从 `.gdc` 字节码反编译，已加中文注释 |
| 规则脚本（`sgz_script/*.gd`） | 1189 | 原作者明文源码，本身含中文注释 |
| 场景（`.tscn`） | 117 | 文本格式 |
| 纹理（`.png`） | 920 + 2207 | 工程内资源 + 运行时打包资源 |
| 音频（`.ogg`） | 55 | 从 `.oggstr` 还原 |
| 数据（`.json`） | 1200 | 武将/城市/技能/装备等，可直接修改 |
| 资源/着色器 | 24 + 2 | `.tres` / `.gdshader` 文本格式 |

## 🚀 快速开始

### 环境要求

- **Godot 3.5.3**（本仓库已自带 macOS 版 `Godot_3.5.3.app`）
- 注意：**不能用 Godot 4.x** 打开（脚本为 GDScript 1.0 语法，会报版本不兼容）

### 运行方式

```bash
# 方式一：Makefile（推荐）
make run          # 运行游戏
make edit         # 打开编辑器
make check        # headless 校验工程
make clean        # 清理导入缓存

# 方式二：直接命令行
./Godot_3.5.3.app/Contents/MacOS/Godot --path bwdl
```

> 💡 这是**移动端（触摸）游戏**，桌面运行靠鼠标模拟触摸（`project.godot` 已开启 `emulate_touch_from_mouse`）。游戏存档会写到 Godot 可执行文件同级的 `sgz/` 目录。

## 📝 中文注释说明

反编译得到的代码全部添加了中文注释：

- **全部 189 个脚本**：文件头注释，说明该脚本职责。
- **核心逻辑文件**：逐段详细注释，含关键公式推导，例如：
  - `script/Flow_Manager.gd` — 流程字符串调度系统
  - `script/objects/clSoloFight.gd` — 单挑与劝降查表公式
  - `script/affair/clDevelopCommand.gd` — 开发收益公式（土地/产业/人口/防灾）
  - `script/affair/clSearchCommand.gd` — 搜索/招募的相性距离判定
  - `script/affair/clPolicyCommand.gd` — 六种外交政策的成功率公式
  - `script/objects/clCity.gd` — 城市属性、连接、攻击范围、叛乱概率
  - `script/objects/clBattleFight.gd` — 战斗结束判定、撤退损失
  - `script/Battle_Unit.gd` — 白兵战伤害计算（刀/枪/剑修正、斧加成、格挡、回血）

## 🔬 反编译方法（可复现）

本工程使用 [GDRETools/gdsdecomp](https://github.com/GDRETools/gdsdecomp)（Godot RE Tools v2.6.4）完成：

```bash
gdre_tools --headless --recover="霸王的大陆GD安卓版 2540.Apk" --output=bwdl
```

该工具一次性完成：`.gdc` 字节码反编译、`project.binary` 还原、`.stex`→`.png`、`.oggstr`→`.ogg` 等资源转换。

> 📌 关于加密数据：原版游戏的数据打包在 `resource/bwdl.pck`（带 520 字节 RSA 签名头的标准 PCK）。反编译后**已把 pck 内容解包为 `res://packed/` 下的真实文件**（`data` / `images` / `sgz_script`），并修改了 `Static_Manager.gd` 跳过 pck 加载与验签。因此现在**无需加密/签名**，直接改 `packed/` 下的 JSON 或脚本即可，导出时 Godot 会明文打包。

## 📄 License

仅供学习研究使用。原版游戏版权归其原作者所有。
