#!/usr/bin/env python3
"""通用武将头像生成器（程序化部件组合，非 AIGC）。

从现有头像池按「头发 + 脸 + 服饰」三段拼接，生成风格同源的新头像。

用法（命令行）：
  python3 avatar_composer.py --kind warrior --count 5 --out dir/
用法（库）：
  from avatar_composer import generate_warrior, to_sheet
  img = generate_warrior()          # 32x40 RGB
  sheet = to_sheet(img)             # 256x40 八帧条
"""
import argparse
import json
import os
import random
import sys

from PIL import Image

from compose import compose, load
from palette_utils import load_palette, map_to_palette

ACTORS = os.path.join(os.path.dirname(__file__), "..", "..",
                      "bwdl", "packed", "data", "actors.json")
PALETTE = os.path.join(os.path.dirname(__file__), "palette.txt")
KINDS = ("warrior", "official", "female")
THRESHOLD = 20  # 武-政 或 政-武 差值阈值


def classify(threshold=THRESHOLD):
    """按能力值把有头像的武将分为 武将/文官/女性 三组。返回 {kind: [id...]}。"""
    data = json.load(open(ACTORS))
    pools = {k: [] for k in KINDS}
    for a in data:
        fid = a.get("ID", 0)
        if fid >= 561:  # 只取有头像的（三国 561 人）
            continue
        if a.get("性别") == "女":
            pools["female"].append(fid)
        elif a.get("武", 0) - a.get("政", 0) >= threshold:
            pools["warrior"].append(fid)
        elif a.get("政", 0) - a.get("武", 0) >= threshold:
            pools["official"].append(fid)
    return pools


POOLS = classify()
GAME_PALETTE = load_palette(PALETTE)


def generate(kind, seed=None):
    """从指定类型的头像池随机拼一个新头像，返回 32x40 RGB 图。"""
    if kind not in KINDS:
        raise ValueError(f"kind 必须是 {KINDS}")
    pool = POOLS[kind]
    if len(pool) < 2:
        raise ValueError(f"{kind} 池不足 2 个头像，无法拼接")
    rng = random.Random(seed)
    hair, face = rng.sample(pool, 2)
    out = compose(load(hair), load(face))
    return map_to_palette(out, GAME_PALETTE)


def generate_warrior(seed=None):
    """生成一个新武将（男）。"""
    return generate("warrior", seed)


def generate_official(seed=None):
    """生成一个新文官（男）。"""
    return generate("official", seed)


def generate_female(seed=None):
    """生成一个新女性角色。"""
    return generate("female", seed)


def to_sheet(frame):
    """把 32x40 单帧铺成 256x40 八帧表情条。"""
    sheet = Image.new("RGB", (32 * 8, 40))
    for i in range(8):
        sheet.paste(frame, (i * 32, 0))
    return sheet


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kind", choices=KINDS, required=True)
    ap.add_argument("--count", type=int, default=1)
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "output"))
    ap.add_argument("--seed", type=int, default=None)
    args = ap.parse_args()

    print(f"池大小: " + ", ".join(f"{k}={len(v)}" for k, v in POOLS.items()))
    os.makedirs(args.out, exist_ok=True)
    for i in range(args.count):
        frame = generate(args.kind, args.seed)
        name = f"{args.kind}_{i}.png"
        frame.save(os.path.join(args.out, name))
        to_sheet(frame).save(os.path.join(args.out, name.replace(".png", "_sheet.png")))
        print(f"生成 {name}")


if __name__ == "__main__":
    sys.exit(main())
