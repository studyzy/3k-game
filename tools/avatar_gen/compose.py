#!/usr/bin/env python3
"""程序化部件组合：从三张头像取「头发 + 脸 + 服饰」拼成全新头像。

用法：
  python3 compose.py --hair 322 --face 266 --body 528 --output new.png
"""
import argparse
import os
import sys

from PIL import Image

from palette_utils import quantize

REF = os.path.join(os.path.dirname(__file__), "reference")
W, H = 32, 40
FACE_H = 16  # 脸部段固定高度（眼到下巴）


def load(fid):
    return Image.open(os.path.join(REF, f"{fid}.png")).convert("RGB")


def skin(r, g, b):
    return r > 220 and 130 < g < 185 and 80 < b < 140


def face_top(img):
    """找到连续肤色块的起始行（真正的脸），跳过零散浅色头饰。"""
    px = img.load()

    def row_skin(y):
        return sum(1 for x in range(W) if skin(*px[x, y]))

    # 脸是连续大块肤色：要求连续 3 行每行 >= 6 个肤色像素
    for y in range(H - 2):
        if all(row_skin(y + i) >= 6 for i in range(3)):
            return y
    # 兜底：单行足够多肤色
    for y in range(H):
        if row_skin(y) >= 10:
            return y
    return 12  # 兜底


def compose(hair, face):
    """两段拼接：hair 提供冠/盔，face 提供脸+胡子+衣领（完整下半身）。

    face 的「发际线到脚」缩放到目标高度，避免越界并自适应不同发际线。
    """
    ht = min(face_top(hair), 12)  # 头发段最多 12 行，避免发髻过厚压缩脸
    ft = face_top(face)
    hair_seg = hair.crop((0, 0, W, ht))
    face_seg = face.crop((0, ft, W, H)).resize((W, H - ht), Image.NEAREST)

    out = Image.new("RGB", (W, H))
    out.paste(hair_seg, (0, 0))
    out.paste(face_seg, (0, ht))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hair", type=int, required=True)
    ap.add_argument("--face", type=int, required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("-n", "--colors", type=int, default=32)
    args = ap.parse_args()

    out = compose(load(args.hair), load(args.face))
    out = quantize(out, args.colors)
    out.save(args.output)
    print(f"hair={args.hair} face={args.face} -> {args.output}")


if __name__ == "__main__":
    sys.exit(main())
