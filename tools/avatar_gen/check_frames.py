#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""头像库全量合规校验：一键报告「八帧全同」残留、尺寸异常与缺失文件。

校验规则（specs/001-fix-avatar-frames FR-008）:
    - 八帧全同 = 违规，但 ID 546（「自定义」灰占位）列入白名单
    - 尺寸必须 256×40
    - actors.json 有记录但缺头像文件的 ID 单独提示（如 2563），不算违规
    - 存在违规时退出码非 0，便于 CI/脚本判定

用法:
    python3 check_frames.py --dir ../../bwdl/packed/images/actor/face/avatar
    python3 check_frames.py --dir <目录> --actors <actors.json 路径>   # 测试注入
"""
import argparse
import json
import os
import sys

from PIL import Image

from expressions import W, H

AVATAR_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                          "..", "..", "bwdl", "packed", "images", "actor", "face", "avatar")
ACTORS_JSON = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "..", "bwdl", "packed", "data", "actors.json")
WHITELIST = {546}  # 「自定义」灰占位：8 帧全同属设计使然


def frame_bytes(img, i):
    """取表情条第 i 帧的原始字节。"""
    return img.crop((i * W, 0, i * W + W, H)).tobytes()


def check_dir(dirpath, actor_ids):
    """扫描目录执行三项校验，返回 (flat_ids, bad_size, missing_ids)。

    - flat_ids: 八帧全同的头像 ID（白名单除外）
    - bad_size: 尺寸异常的 (ID, 实际尺寸)
    - missing_ids: actors.json 有记录但目录缺文件的 ID
    """
    flat, bad_size, seen = [], [], set()
    for name in sorted(os.listdir(dirpath)):
        if not name.endswith(".png"):
            continue
        try:
            aid = int(os.path.splitext(name)[0])
        except ValueError:
            continue
        seen.add(aid)
        img = Image.open(os.path.join(dirpath, name)).convert("RGB")
        if img.size != (W * 8, H):
            bad_size.append((aid, img.size))
            continue
        if aid in WHITELIST:
            continue
        if len({frame_bytes(img, i) for i in range(8)}) == 1:
            flat.append(aid)
    missing = [aid for aid in actor_ids if aid not in seen]
    return sorted(flat), bad_size, sorted(missing)


def main():
    ap = argparse.ArgumentParser(description="头像库八帧合规校验")
    ap.add_argument("--dir", default=AVATAR_DIR, help="头像目录")
    ap.add_argument("--actors", default=ACTORS_JSON, help="actors.json 路径")
    args = ap.parse_args()

    actor_ids = [a["ID"] for a in json.load(open(args.actors))]
    flat, bad_size, missing = check_dir(args.dir, actor_ids)

    print(f"扫描 {args.dir}")
    if flat:
        print(f"八帧全同（违规，白名单除外）: {len(flat)} 张 → {flat[:20]}"
              f"{'...' if len(flat) > 20 else ''}")
    else:
        print("八帧全同（违规，白名单除外）: 0 张")
    for aid, size in bad_size:
        print(f"尺寸异常: ID {aid} 实际 {size}，应为 {(W * 8, H)}")
    if missing:
        print(f"缺头像文件（仅提示，不算违规）: {len(missing)} 个 → {missing[:20]}"
              f"{'...' if len(missing) > 20 else ''}")

    ok = not flat and not bad_size
    print("结果:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
