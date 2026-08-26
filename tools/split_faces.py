#!/usr/bin/env python3
"""把霸王的大陆默认武将头像拼图 face-0..7.png 拆成每名武将一个独立 PNG。

输入: bwdl/packed/images/actor/face/face-{0..7}.png (256x3000, 每张 75 人)
输出: bwdl/{resource,packed}/images/actor/face/avatar/{actorId}.png (256x40, 8 帧表情条)
映射: actorId = page * 75 + row
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "bwdl", "packed", "images", "actor", "face")
OUT_SUBDIRS = [
    os.path.join(ROOT, "bwdl", "resource", "images", "actor", "face", "avatar"),
    os.path.join(ROOT, "bwdl", "packed", "images", "actor", "face", "avatar"),
]

PAGES = 8
GROUP_SIZE = 75
STRIP_W = 256
STRIP_H = 40


def main():
    count = 0
    for page in range(PAGES):
        src = os.path.join(SRC_DIR, "face-%d.png" % page)
        img = Image.open(src)
        w, h = img.size
        assert (w, h) == (STRIP_W, GROUP_SIZE * STRIP_H), (src, w, h)
        for row in range(GROUP_SIZE):
            actor_id = page * GROUP_SIZE + row
            box = (0, row * STRIP_H, STRIP_W, (row + 1) * STRIP_H)
            strip = img.crop(box)
            for out_dir in OUT_SUBDIRS:
                os.makedirs(out_dir, exist_ok=True)
                strip.save(os.path.join(out_dir, "%d.png" % actor_id))
            count += 1
    print("generated %d avatars" % count)

    # 校验
    for out_dir in OUT_SUBDIRS:
        files = sorted(int(f[:-4]) for f in os.listdir(out_dir) if f.endswith(".png"))
        assert files == list(range(count)), (out_dir, files[0], files[-1])
        for i in (0, count // 2, count - 1):
            p = os.path.join(out_dir, "%d.png" % i)
            assert Image.open(p).size == (STRIP_W, STRIP_H), (p, Image.open(p).size)
        print("verified %s: %d files, size %dx%d" % (out_dir, len(files), STRIP_W, STRIP_H))


if __name__ == "__main__":
    main()
