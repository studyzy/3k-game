# Implementation Plan: 修正生成武将头像的八帧表情

**Branch**: `001-fix-avatar-frames` | **Date**: 2026-08-28 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-fix-avatar-frames/spec.md`

## Summary

ID 561~2562 共 2002 张生成头像的 8 帧是同一张图的复制，导致对话中表情与嘴型动画完全失效。修复方案：以每张头像现有的「平静-闭嘴」帧（帧 4）为基底，按原版三国头像实证的表情规律（怒=瞪眼、喜=眯眼、哀=垂眼、张嘴=口部开口），程序化派生其余 7 帧；同时把 `avatar_composer.to_sheet()` 改为调用同一派生模块，杜绝新武将复发。容貌零改变（帧 4 不动）、幂等可重跑、只复用帧内已有颜色。

## Technical Context

**语言/版本**: Python 3.12（工具链现状；Pillow 已在用）

**主要依赖**: Pillow（既有）；测试用 stdlib `unittest`（零新依赖，符合章程决策阶梯）

**存储**: 直接读写 `bwdl/packed/images/actor/face/avatar/{ID}.png`（RGBA 256×40）

**测试**: `unittest`（`tools/avatar_gen/tests/`，headless 运行，中文注释）

**目标平台**: macOS 本地工具链（生成资产供 Godot 3.5.3 工程加载）

**项目类型**: 游戏资产修复 + 批量工具（无运行时代码改动）

**性能目标**: 全库 2002 张修复 + 校验合计 < 1 分钟（纯像素操作，单机即可）

**约束**: 帧 4 逐像素不变；幂等重跑；只复用帧内已有颜色（天然满足 64 色板）；不动 ID 0~560 与 546；不改动游戏 GDScript

**规模/范围**: 2002 张存量修复 + 1 个工具修正 + 1 个校验入口 + 单元测试

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 章程原则 | 状态 | 说明 |
|---|---|---|
| I. Godot 最佳实践 | ✅ 通过 | 不触碰游戏运行时代码与场景；资产格式保持游戏可加载（256×40 八帧条，`actor_face.gd` 既有取帧公式兼容） |
| II. 中文注释与中文文档 | ✅ 通过 | 新增工具代码/测试全部中文注释；本计划与产物全中文 |
| III. 必要测试纪律（NON-NEGOTIABLE） | ✅ 通过 | 五官检测与表情变换是核心逻辑，MUST 有单元测试：`tools/avatar_gen/tests/` 用 stdlib unittest 覆盖（合成头像fixture 验证检测定位、四种心情变换不变量、幂等性） |
| IV. 集成测试 | ✅ 通过 | 集成点为「修复流程 × 全库资产 × 游戏加载」：批量修复后跑全库合规校验（八帧全同计数=1，仅 546）+ `make check` headless 工程校验 |
| V. 简洁性与 YAGNI | ✅ 通过 | 最小 diff：复用既有 `palette_utils`/目录结构；表情变换只做行级几何操作；不做配置化、不留兼容垫片 |

无违规项。

## Project Structure

### Documentation (this feature)

```text
specs/001-fix-avatar-frames/
├── plan.md              # 本文件
├── research.md          # 阶段 0：表情规律实证与算法决策
├── data-model.md        # 阶段 1：头像资产与工具数据结构
├── quickstart.md        # 阶段 1：修复执行与验证步骤
└── checklists/
    └── requirements.md  # 规格质量检查清单（已通过）
```

### Source Code (repository root)

```text
tools/avatar_gen/
├── avatar_composer.py   # [修改] to_sheet() 改为调用 expressions 派生八帧
├── expressions.py       # [新增] 五官检测 + 四心情×两嘴型表情派生（核心逻辑）
├── fix_all_frames.py    # [新增] 存量批量修复入口（幂等，只动 561~2562）
├── check_frames.py      # [新增] 全库合规校验（报告八帧全同清单）
├── palette.txt          # [不变]
├── compose.py           # [不变] 部件拼接（单帧生成）
├── palette_utils.py     # [不变]
├── generate_all.py      # [不变] 批量生成入口（经 to_sheet 间接获得八帧能力）
└── tests/
    ├── __init__.py
    ├── test_expressions.py      # 单元测试：检测/变换/不变量/幂等
    └── test_fix_all_frames.py   # 集成测试：临时目录端到端修复+校验
```

**Structure Decision**: 全部新代码收敛在既有 `tools/avatar_gen/` 目录内，与现有工具同构（单文件脚本 + 可导入模块）；测试放 `tests/` 子目录用 unittest 发现。不新增顶层目录。

## Complexity Tracking

无违规，无需记录。
