# 武将头像生成器（程序化部件组合，非 AIGC）

从已有 561 名三国人物头像中提取部件，程序化拼出**风格 100% 同源**的新头像，用于给扩展人物（ID ≥ 561）批量补头像。

## 原理

### 两段拼接

每张头像（32×40，256×40 八帧条中的一帧）拆成两段：

```
┌─────────────┐
│  头发段      │  ← 来自头像 A（冠 / 盔 / 发髻）
│  (0 ~ 发际线) │
├─────────────┤
│  脸到脚      │  ← 来自头像 B（脸 + 胡子 + 衣领，完整）
│  (发际线~40) │
└─────────────┘
```

- 发际线自动检测：连续 3 行每行 ≥ 6 个肤色像素（跳过浅色头饰）。
- 头发段高度上限 **12 行**（30%），避免发髻过厚压缩脸部。
- 脸到脚段从 B 的「发际线~40」缩放到目标高度，自适应不同发际线、避免越界。
- 胡子来自同一个头像 B，天然不会「胡子叠胡子」。

### 主色板映射

拼接后用游戏主色板（`palette.txt`，64 色，从 561 张原图提取）做最近色映射，**不用独立中位切分**（后者会把肤色和白色混合成浅色、脸发白）。

### 角色分类

按能力值自动归三类：

| 类型 | 判据 |
|---|---|
| 女性 female | 性别 = 女 |
| 武将 warrior | 武 − 政 ≥ 20 |
| 文官 official | 政 − 武 ≥ 20 |
| 其余 | 武 ≥ 政 归武将，否则归文官 |

阈值 `THRESHOLD = 20` 定义在 `avatar_composer.py`。

## 文件说明

| 文件 | 作用 |
|---|---|
| `avatar_composer.py` | 通用生成方法 + 分类逻辑（对外主入口） |
| `compose.py` | 两段拼接核心 + 发际线检测 |
| `expressions.py` | 五官检测 + 八帧表情派生（4 心情 × 2 嘴型） |
| `fix_all_frames.py` | 存量批量修复入口（幂等，只动生成段） |
| `check_frames.py` | 全库合规校验（八帧全同清单/尺寸异常/缺文件） |
| `palette_utils.py` | 中位切分、主色板映射 |
| `generate_all.py` | 批量生成脚本（按 ID 做随机种子） |
| `extract.py` | 从 `packed/images/actor/face/avatar/` 抽取参考帧 + 生成主色板 |
| `palette.txt` | 游戏主色板（64 色） |
| `reference/` | 561 张三国参考帧（32×40 单帧），compose 的数据源 |
| `tests/` | 单元 + 集成测试（stdlib unittest，合成 fixture 不依赖真实资产） |

## 八帧表情条格式

游戏对话头像按「4 心情 × 2 嘴型」取帧（`actor_face.gd:100`）：

```
帧序: [怒闭, 怒张, 喜闭, 喜张, 平闭, 平张, 哀闭, 哀张]
帧 x = mood*2*32 + mouthFlag*32    mood: 0怒 1喜 2平(默认) 3哀
```

`to_sheet()` / `fix_all_frames.py` 都通过 `expressions.derive_sheet()` 从「平静-闭嘴」帧派生八帧：
怒=瞪眼（眼区增高）、喜=眯眼（眼区压扁）、哀=垂眼（眼区下移）、张嘴=嘴线中段清空后下方开口。
派生只用帧内已有颜色，天然满足 64 色板约束；帧 4 永不修改，重跑幂等。

## 批量修复与校验（存量头像）

```bash
cd tools/avatar_gen
# 全库校验：报告八帧全同清单 / 尺寸异常 / 缺文件（违规时退出码非 0）
python3 check_frames.py --dir ../../bwdl/packed/images/actor/face/avatar

# 批量修复（幂等可重跑；只处理 ID 561~2562，跳过原版段与 546 灰占位）
python3 fix_all_frames.py --dir ../../bwdl/packed/images/actor/face/avatar --dry-run  # 演练
python3 fix_all_frames.py --dir ../../bwdl/packed/images/actor/face/avatar            # 正式
python3 fix_all_frames.py --only 566 --preview /tmp/preview                           # 单张 4x 预览

# 跑测试
cd tests && python3 -m unittest test_expressions test_fix_all_frames -v
```

## 快速开始

### 1. 作为库调用（生成单个）

```python
import sys
sys.path.insert(0, "tools/avatar_gen")
from avatar_composer import generate_warrior, generate_official, generate_female, to_sheet

frame = generate_warrior()        # 32×40 单帧，RGB
frame = generate_official(seed=42)   # 指定种子可复现
frame = generate_female()
sheet = to_sheet(frame)           # 铺成 256×40 八帧表情条
sheet.save("xxx.png")
```

### 2. 批量生成（给扩展人物补头像）

```bash
# 预览前 10 个（输出到 preview/）
python3 tools/avatar_gen/generate_all.py --out tools/avatar_gen/preview --limit 10

# 正式生成全部 ID ≥ 561 的头像
python3 tools/avatar_gen/generate_all.py --out bwdl/packed/images/actor/face/avatar/
```

`generate_all.py` 用 **ID 作为随机种子**，保证每个武将的头像固定、可复现。

## 新增人物后生成头像

完整流程（游戏侧）：

1. `packed/data/actors.json` 加一条记录（新 ID）；
2. 放一张 256×40 八帧图到 `packed/images/actor/face/avatar/{ID}.png` —— 用上面批量脚本生成即可；
3. `make import` 重新导入资源。

## 关键参数

| 参数 | 位置 | 值 | 说明 |
|---|---|---|---|
| `THRESHOLD` | avatar_composer.py | 20 | 武/政差值分类阈值 |
| 头发段上限 | compose.py `min(face_top, 12)` | 12 行 | 发髻过厚时截断 |
| 主色板 | palette.txt | 64 色 | extract.py 从原图提取 |

## 依赖数据重建

`reference/` 和 `palette.txt` 若丢失，可重新生成：

```bash
python3 tools/avatar_gen/extract.py
```

它会从 `packed/images/actor/face/avatar/` 抽取每张头像的第 4 帧（静态闭嘴帧）到 `reference/`，并统计生成 `palette.txt`。
