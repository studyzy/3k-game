#!/usr/bin/env python3
"""为扩展武将（ID>=561）批量生成头像（部件组合，非 AIGC）。

按能力值分类：女→female，武-政>=20→warrior，政-武>=20→official，其余按武/政大小归边。
用 ID 作为随机种子，保证每个武将头像固定可复现。

用法：
  python3 generate_all.py --out preview/ --limit 6          # 预览前 6 个
  python3 generate_all.py --out ../../bwdl/packed/images/actor/face/avatar/   # 正式生成
"""
import argparse
import json
import os
import sys

from avatar_composer import generate, to_sheet

ACTORS = os.path.join(os.path.dirname(__file__), "..", "..",
                      "bwdl", "packed", "data", "actors.json")


def kind_of(a):
    if a.get("性别") == "女":
        return "female"
    w, p = a.get("武", 0), a.get("政", 0)
    if w - p >= 20:
        return "warrior"
    if p - w >= 20:
        return "official"
    return "warrior" if w >= p else "official"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "preview"))
    ap.add_argument("--limit", type=int, default=0, help="0 = 全部")
    ap.add_argument("--start", type=int, default=561)
    args = ap.parse_args()

    data = json.load(open(ACTORS))
    targets = [a for a in data if a["ID"] >= args.start]
    if args.limit:
        targets = targets[: args.limit]

    os.makedirs(args.out, exist_ok=True)
    stat = {}
    for a in targets:
        fid = a["ID"]
        kind = kind_of(a)
        stat[kind] = stat.get(kind, 0) + 1
        frame = generate(kind, seed=fid)
        to_sheet(frame).save(os.path.join(args.out, f"{fid}.png"))
    print(f"生成 {len(targets)} 个头像到 {args.out}")
    print("分类统计:", stat)


if __name__ == "__main__":
    sys.exit(main())
