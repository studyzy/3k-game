# Quickstart: 修正生成武将头像的八帧表情

前置：Python 3.12 + Pillow（已就绪），位于仓库任意目录（脚本内用绝对/相对仓库路径）。

## 1. 跑单元与集成测试

```bash
cd tools/avatar_gen
python3 -m unittest discover -s tests -v
```

预期：全部通过（五官检测定位、四心情变换不变量、幂等性、端到端修复+校验）。

## 2. 修复前校验（确认现状）

```bash
cd tools/avatar_gen
python3 check_frames.py --dir ../../bwdl/packed/images/actor/face/avatar
```

预期报告：八帧全同 2002 张（561~2562）+ 546 白名单 + 缺文件 2563。

## 3. 预览单张效果（可选，肉眼验收表情）

```bash
python3 fix_all_frames.py --dir ../../bwdl/packed/images/actor/face/avatar --only 561 --preview /tmp/avatar_preview
```

打开 `/tmp/avatar_preview/561.png`（4x 放大拼接图）：8 帧应有瞪眼/眯眼/平静/垂眼 × 闭嘴/张嘴变化。

## 4. 批量修复（先演练后落盘）

```bash
# 演练：只统计，不写文件
python3 fix_all_frames.py --dir ../../bwdl/packed/images/actor/face/avatar --dry-run

# 正式修复 2002 张（幂等，可中断重跑）
python3 fix_all_frames.py --dir ../../bwdl/packed/images/actor/face/avatar
```

预期输出统计：修复 2002、跳过原版段 561、跳过 546。

## 5. 修复后校验（验收）

```bash
python3 check_frames.py --dir ../../bwdl/packed/images/actor/face/avatar
```

预期：八帧全同仅剩 546（白名单），退出码 0；报告缺文件 2563（已知边缘项）。

## 6. 游戏加载校验

```bash
make check   # 仓库根目录，Godot headless 工程校验
```

预期：无新增报错。

## 7. 游戏内验收（人工，可选）

`make run` 进游戏，触发扩展武将对话（如搜索命令的报告）：表情应随好坏消息变化，说话时嘴部开合。

## 8. 防复发验证

```bash
python3 generate_all.py --start 561 --limit 2 --out preview/
python3 check_frames.py --dir preview
```

预期：新生成的头像直接合规（八帧互异）。
