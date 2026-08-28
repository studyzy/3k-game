#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""存量头像批量修复入口：把「8 帧全同」的生成头像重新派生为合规表情条。

幂等策略（specs/001-fix-avatar-frames/research.md R5）:
    - 永远从每张头像的「平静-闭嘴」帧（帧 4）派生其余 7 帧，帧 4 本身不修改
    - 重跑时已合规的图重新派生结果逐像素一致 → 输出逐字节不变
    - 单张先写 .tmp 再原子替换，中断不留半帧

安全边界（FR-007）:
    - 只处理 ID 561~2562 的生成段；ID 0~560 原版段与 546（「自定义」灰占位）跳过

用法:
    python3 fix_all_frames.py --dir ../../bwdl/packed/images/actor/face/avatar          # 正式修复
    python3 fix_all_frames.py --dir <目录> --dry-run                                    # 演练只统计
    python3 fix_all_frames.py --dir <目录> --only 561 --preview /tmp/preview            # 单张修复+预览
"""
import argparse
import os
import sys

from PIL import Image

from expressions import W, H, derive_sheet

AVATAR_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "..", "..", "bwdl", "packed", "images", "actor", "face", "avatar")
FIX_RANGE = (561, 2562)   # 生成段修复范围（含端点）
WHITELIST = {546}         # 「自定义」灰占位：8 帧全同属设计，不修


def load_id(path):
    """从文件名解析武将 ID；非数字命名返回 None。"""
    name = os.path.splitext(os.path.basename(path))[0]
    try:
        return int(name)
    except ValueError:
        return None


def is_flat(img):
    """判断表情条是否 8 帧全同（待修复的标志）。"""
    frames = [img.crop((i * W, 0, i * W + W, H)).tobytes() for i in range(8)]
    return len(set(frames)) == 1


def fix_one(path, preview_dir=None, dry_run=False):
    """修复单张头像。返回 'fixed' / 'ok'（已合规）/ 'skip'（不在范围）。

    修复动作: 取帧 4 → derive_sheet 派生 8 帧 → 与原图比较 → 原子替换。
    dry_run=True 时只判断不写盘；preview_dir 给定时输出 4x 放大预览图。
    """
    aid = load_id(path)
    if aid is None or aid < FIX_RANGE[0] or aid > FIX_RANGE[1] or aid in WHITELIST:
        return "skip"
    img = Image.open(path).convert("RGB")
    if img.size != (W * 8, H):
        print(f"  [警告] {path} 尺寸 {img.size} 非 {(W * 8, H)}，跳过")
        return "skip"
    frame4 = img.crop((4 * W, 0, 5 * W, H))
    new_sheet = derive_sheet(frame4)
    if preview_dir:
        # 预览模式：无论是否已合规都导出 4x 放大图，供目检表情效果
        os.makedirs(preview_dir, exist_ok=True)
        big = new_sheet.resize((new_sheet.width * 4, new_sheet.height * 4), Image.NEAREST)
        big.save(os.path.join(preview_dir, os.path.basename(path)))
        return "preview"
    if new_sheet.tobytes() == img.tobytes():
        return "ok"  # 已合规（幂等：重跑到达此分支）
    if dry_run:
        return "fixed"
    tmp = path + ".tmp"
    new_sheet.save(tmp, "PNG")  # .tmp 扩展名无法推断格式，须显式指定
    os.replace(tmp, path)  # 原子替换，中断不留半帧
    return "fixed"


def main():
    ap = argparse.ArgumentParser(description="批量修复生成头像的八帧表情（幂等）")
    ap.add_argument("--dir", default=AVATAR_DIR, help="头像目录")
    ap.add_argument("--dry-run", action="store_true", help="只统计不写文件")
    ap.add_argument("--only", type=int, help="只处理指定 ID（配合 --preview 目检）")
    ap.add_argument("--preview", help="预览输出目录（4x 放大，不落盘修复）")
    args = ap.parse_args()

    if args.dry_run and args.preview:
        print("--dry-run 与 --preview 不可同用")
        return 2

    files = sorted(os.listdir(args.dir))
    stat = {"fixed": 0, "ok": 0, "skip": 0, "preview": 0}
    for name in files:
        if not name.endswith(".png"):
            continue
        path = os.path.join(args.dir, name)
        aid = load_id(path)
        if args.only is not None and aid != args.only:
            continue
        result = fix_one(path, preview_dir=args.preview, dry_run=args.dry_run)
        stat[result] += 1
        print(f"  {name}: {result}")
    print(f"统计: 修复 {stat['fixed']}，已合规 {stat['ok']}，"
          f"预览 {stat['preview']}，跳过 {stat['skip']}")
    if args.dry_run:
        print("（演练模式，未写入任何文件）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
