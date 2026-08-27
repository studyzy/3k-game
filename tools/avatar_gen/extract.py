#!/usr/bin/env python3
"""抽取每张头像的第 4 帧（闭嘴静态帧）作为 img2img 参考，并统计全局主色板。"""
import os
import sys
from collections import Counter

from PIL import Image

from palette_utils import median_cut

SRC = os.path.join(os.path.dirname(__file__), "..", "..",
                   "bwdl", "packed", "images", "actor", "face", "avatar")
DST = os.path.join(os.path.dirname(__file__), "reference")

FRAME_W = 32
FRAME_H = 40
FRAME_IDX = 4          # 第 4 帧，对应 global.gd 静态显示帧
PALETTE_N = 64         # 主色板颜色数


def main():
    os.makedirs(DST, exist_ok=True)
    files = sorted([f for f in os.listdir(SRC) if f.endswith(".png")],
                   key=lambda x: int(x[:-4]))
    counter = Counter()
    count = 0
    for f in files:
        im = Image.open(os.path.join(SRC, f)).convert("RGB")
        # 第 4 帧区域
        frame = im.crop((FRAME_IDX * FRAME_W, 0,
                         (FRAME_IDX + 1) * FRAME_W, FRAME_H))
        frame.save(os.path.join(DST, f))
        counter.update(frame.getdata())
        count += 1
    palette = median_cut(counter, PALETTE_N)
    # 主色板写成色块图，便于肉眼检查（尺寸随颜色数自适应）
    side = 1
    while side * side < len(palette):
        side += 1
    swatch = Image.new("RGB", (side, side))
    swatch.putdata(palette + [(0, 0, 0)] * (side * side - len(palette)))
    swatch = swatch.resize((side * 8, side * 8), Image.NEAREST)
    swatch.save(os.path.join(os.path.dirname(__file__), "palette.png"))
    with open(os.path.join(os.path.dirname(__file__), "palette.txt"), "w") as fp:
        for c in palette:
            fp.write(f"{c[0]},{c[1]},{c[2]}\n")
    print(f"抽取 {count} 帧到 reference/")
    print(f"全局颜色 {len(counter)} 种，聚类为 {len(palette)} 色，见 palette.png")


if __name__ == "__main__":
    sys.exit(main())
