---

description: "Task list for feature implementation"
---

# Tasks: 修正生成武将头像的八帧表情

**Input**: Design documents from `/specs/001-fix-avatar-frames/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Per constitution (Principles III/IV), tasks touching core game logic (formulas, state machines, data parsing, saves) MUST include unit tests; tasks touching data loading, scene flow, save I/O, or shared-script contracts MUST include integration tests. 本功能的核心逻辑 = 五官检测与表情派生（`expressions.py`），MUST 有单元测试；修复/校验工具链 MUST 有集成测试。

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

本功能全部代码位于既有工具目录 `tools/avatar_gen/`，测试在 `tools/avatar_gen/tests/`；不新增顶层目录。

<!-- 任务依据 plan.md 结构与 research.md 决策。真实资产路径：bwdl/packed/images/actor/face/avatar/ -->

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: 测试目录就绪

- [x] T001 创建测试包 `tools/avatar_gen/tests/__init__.py`（空文件，中文文件头注释说明用途）

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 五官检测与表情派生核心模块——所有用户故事的共同前置

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T002 [P] 在 `tools/avatar_gen/tests/test_expressions.py` 实现合成头像 fixture：提供 `make_face(eye_top, eye_bottom, mouth_y, has_beard=False)` 帮助函数，在 32×40 画布上画肤色底、双黑眼簇（x 6~10 / 21~25）、1 行嘴线，返回 PIL Image；全部中文注释（research.md R7）
- [x] T003 在 `tools/avatar_gen/expressions.py` 实现 `locate_features(frame4)` 五官检测：暗色判定（r+g+b<180）、眼区（行 12~24 暗色峰值行上下扩展）、嘴线（眼底线+2~行 33 找宽 3~12 暗横段）、兜底嘴位=眼底线+3、胡须遮挡判定（兜底位置 5×14 窗口暗色占比>0.6 → mouth_visible=False）；参数与算法严格按 data-model.md 实体 2（research.md R3 实测：眼 100% 命中、嘴 88.6%+兜底）
- [x] T004 在 `tools/avatar_gen/tests/test_expressions.py` 添加 `locate_features` 单元测试：标准脸定位正确、无嘴线时兜底到位、胡须遮挡返回 mouth_visible=False、坐标越界安全
- [x] T005 在 `tools/avatar_gen/expressions.py` 实现 `derive_frames(frame4)` 与 `derive_sheet(frame4)`：以帧 4 为基，行级几何变换派生 7 帧——怒（帧 0/1）眼区增高 1px（瞪眼）、喜（帧 2/3）眼区压扁至 1px（眯眼）、哀（帧 6/7）眼区整体下移 1px（垂眼）、张嘴帧（1/3/5/7）嘴线中段替换为 2 行高深色开口（开口色取嘴区周边最暗色，只用帧内已有颜色）；mouth_visible=False 时张嘴帧=闭嘴帧；新像素只复用帧内颜色（research.md R2/R4）

**Checkpoint**: expressions.py 可独立导入使用，`python3 -m unittest discover -s tools/avatar_gen/tests` 全绿

---

## Phase 3: User Story 1 - 对话表情随剧情变化 (Priority: P1) 🎯 MVP

**Goal**: 存量 2002 张生成头像具备 4 心情表情，帧 4 容貌零改变

**Independent Test**: `check_frames.py` 报告八帧全同数下降 + 抽样预览图目视四种表情

### Tests for User Story 1 (MUST per constitution Principles III/IV if tasks touch core logic or cross-script contracts) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [x] T006 [P] [US1] 在 `tools/avatar_gen/tests/test_fix_all_frames.py` 写集成测试（先于实现）：临时目录中放合成 256×40 全同头像 → 跑修复入口 → 断言帧 4 逐像素不变、8 帧互异、重跑第二次输出逐字节不变（幂等）、ID≤560 与 546 不被修改
- [x] T007 [P] [US1] 在 `tools/avatar_gen/tests/test_expressions.py` 添加派生不变量单元测试：同心情闭/张两帧仅嘴区（眼底线+1~+5，x 6~26）有差异、四种心情眼区形态可区分（怒眼高>平眼高、喜眼高<平眼高）、派生图所有颜色 ⊆ 帧原色集合

### Implementation for User Story 1

- [x] T008 [US1] 在 `tools/avatar_gen/fix_all_frames.py` 实现批量修复入口：`--dir <avatar目录> --dry-run --only <ID> --preview <输出目录>`；只处理 561~2562、跳过 546 与原版段；单张先写 `.tmp` 再原子替换；输出修复/跳过统计；文件头中文注释说明幂等策略（research.md R5）
- [x] T009 [US1] 在 `tools/avatar_gen/avatar_composer.py` 修正 `to_sheet()`：从「同一帧复制 8 次」改为调用 `expressions.derive_sheet(frame)`，签名与调用方（generate_all.py）不变，杜绝新武将复发（FR-009）
- [x] T010 [US1] 对真实资产执行批量修复：先 `--dry-run` 确认范围 2002 张，再正式运行 `python3 tools/avatar_gen/fix_all_frames.py --dir bwdl/packed/images/actor/face/avatar`，记录统计输出（FR-001）

**Checkpoint**: US1 完成——2002 张具备四心情表情，帧 4 零改变，测试全绿

---

## Phase 4: User Story 2 - 说话嘴型动画正常 (Priority: P2)

**Goal**: 全库可一键校验合规，嘴型帧差异可验证

**Independent Test**: `check_frames.py` 全库运行报告全同清单与缺失文件

### Tests for User Story 2 (MUST per constitution Principles III/IV if tasks touch core logic or cross-script contracts) ⚠️

- [x] T011 [P] [US2] 在 `tools/avatar_gen/tests/test_fix_all_frames.py` 添加校验工具测试：构造全同图/合规图/错误尺寸图/缺文件场景，断言 `check_frames` 清单与退出码正确、546 白名单生效

### Implementation for User Story 2

- [x] T012 [US2] 在 `tools/avatar_gen/check_frames.py` 实现全库合规校验：扫描目录报告「八帧全同」清单、非 256×40 尺寸异常、actors.json 有记录但缺文件的 ID（如 2563）、546 列入白名单；违规时退出码非 0（FR-008）
- [x] T013 [US2] 运行验收：`python3 tools/avatar_gen/check_frames.py --dir bwdl/packed/images/actor/face/avatar`（预期全同仅 546、退出码 0、报告缺失 2563），并在仓库根目录跑 `make check` 确认游戏加载无新增报错（FR-010）

**Checkpoint**: US1 + US2 均可独立验证通过

---

## Phase 5: User Story 3 - 风格与原版统一 (Priority: P3)

**Goal**: 派生画风与原版惯例一致，抽样目检通过

**Independent Test**: 导出修复后样张 4x 拼图与原版并排对比目检

### Implementation for User Story 3

- [x] T014 [US3] 用 `fix_all_frames.py --only <ID> --preview` 导出 6 张代表性样张（含胡须遮挡型如 566、女将、文官各 1+）的 4x 放大拼图到 `/tmp/avatar_preview`，对照原版（ID 0 刘备）目检四心情方向一致性（怒瞪/喜眯/哀垂）与嘴型自然度，记录目检结论（FR-005）
- [x] T015 [US3] 防复发验证：`python3 tools/avatar_gen/generate_all.py --start 561 --limit 2 --out tools/avatar_gen/preview/` 生成新样张，`check_frames.py --dir tools/avatar_gen/preview` 确认新产出直接合规（FR-009 闭环）

**Checkpoint**: 全部用户故事独立可用

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: 文档与交接收尾

- [x] T016 [P] 更新 `tools/avatar_gen/README.md`：新增 expressions.py 说明了帧序契约（4 心情 × 2 嘴型）、fix/check 用法、幂等策略；同步 `bwdl/packed/data/README.md`「十一、添加武将」节中头像规格描述（256×40 八帧表情条不再允许全同帧）
- [x] T017 运行 `specs/001-fix-avatar-frames/quickstart.md` 全流程一遍做最终验证（测试→校验→修复→复验→make check）

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 无依赖，最先执行
- **Foundational (Phase 2)**: 依赖 T001；T002 可与 T003 并行起步；T003→T004；T005 依赖 T003
- **US1 (Phase 3)**: 依赖 Phase 2 完成；T006/T007 测试先行（[P]，针对即将实现的接口写，先红后绿）；T008 依赖 T005；T009 依赖 T005；T010 依赖 T008+T009
- **US2 (Phase 4)**: T011 依赖 T006（复用 fixture）；T012 依赖 T005（需要「全同」判定知识，但文件独立可与 US1 并行）；T013 依赖 T010+T012
- **US3 (Phase 5)**: 依赖 T010（修复已落盘）；T014/T015 可并行
- **Polish (Phase 6)**: 依赖全部故事完成

### User Story Dependencies

- **US1 (P1)**: 基础就绪即可开工，不依赖其他故事 → MVP
- **US2 (P2)**: 校验工具实现可并入 US1 后串行，也可与 T008 并行（不同文件）
- **US3 (P3)**: 依赖 US1 的修复结果（抽样目检对象是修复后资产）

### Within Each User Story

- 测试先写（先失败）→ 实现 → 验证
- 入口工具 → 真实资产执行 → 校验收口

### Parallel Opportunities

- T002 与 T003（不同文件）
- T006 与 T007（不同测试文件，接口已约定）
- T011 与 T012 前置部分；T014 与 T015

---

## Parallel Example: User Story 1

```bash
# 两个测试文件可同时编写（接口按 data-model.md 约定）:
Task: "T006 集成测试 in tools/avatar_gen/tests/test_fix_all_frames.py"
Task: "T007 派生不变量测试 in tools/avatar_gen/tests/test_expressions.py"

# 实现完成后并行执行验收:
Task: "T010 批量修复真实资产"
Task: "T012 check_frames.py 实现"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup（T001）
2. Complete Phase 2: Foundational（T002~T005，CRITICAL - blocks all stories）
3. Complete Phase 3: User Story 1（T006~T010）
4. **STOP and VALIDATE**: `check_frames` 尚未存在时用临时脚本验证八帧互异 + 帧 4 不变
5. 此时游戏内扩展武将已具备四心情表情（核心价值已交付）

### Incremental Delivery

1. 基础 + US1 → 表情生效（MVP!）
2. + US2 → 一键校验 + make check 收口
3. + US3 → 目检 + 防复发闭环
4. Polish → 文档同步，后续维护者可直接沿用

### Single Developer Strategy

按 T001→T002→T003→T004→T005→T006→T007→T008→T009→T010→T011→T012→T013→T014→T015→T016→T017 顺序执行即可，串行无阻塞。

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- 每个「执行类」任务（T010/T013/T014/T015）是操作而非写码，完成后须把输出统计/目检结论记录回任务描述或 quickstart 对应步骤
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
