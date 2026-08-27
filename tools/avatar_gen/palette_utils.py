"""颜色量化工具：中位切分提取色板 + 图像量化。"""
from collections import Counter

from PIL import Image


def median_cut(colors, n):
    """中位切分：把 (r,g,b) 颜色计数切分聚类，返回最多 n 个平均色。"""
    items = list(colors.items())

    def cut(bucket):
        if len(bucket) <= 1:
            return None
        channels = zip(*(c for c, _ in bucket))
        rng = [max(ch) - min(ch) for ch in channels]
        axis = rng.index(max(rng))
        bucket.sort(key=lambda x: x[0][axis])
        total = sum(cnt for _, cnt in bucket)
        acc = 0
        mid = total // 2
        for i, (_, cnt) in enumerate(bucket):
            acc += cnt
            if acc >= mid and i + 1 < len(bucket):
                return bucket[:i + 1], bucket[i + 1:]
        return None

    buckets = [items]
    while len(buckets) < n:
        new_buckets = []
        split = False
        for b in buckets:
            parts = cut(b)
            if parts:
                new_buckets.extend(parts)
                split = True
            else:
                new_buckets.append(b)
        buckets = new_buckets
        if not split:
            break
    # 若切分超出 n，合并计数最小的桶
    buckets.sort(key=lambda b: sum(cnt for _, cnt in b))
    while len(buckets) > n:
        a, b = buckets[:2]
        buckets = buckets[2:] + [a + b]
    palette = []
    for b in buckets:
        total = sum(cnt for _, cnt in b)
        r = sum(c[0] * cnt for c, cnt in b) // total
        g = sum(c[1] * cnt for c, cnt in b) // total
        bl = sum(c[2] * cnt for c, cnt in b) // total
        palette.append((r, g, bl))
    palette.sort(key=lambda c: (c[0], c[1], c[2]))
    return palette


def quantize(img, n):
    """把 RGB 图量化到 n 色，返回新图。"""
    im = img.convert("RGB")
    counter = Counter(im.getdata())
    if len(counter) <= n:
        return im
    palette = median_cut(counter, n)
    lookup = {c: min(palette, key=lambda p: sum((a - b) ** 2
                                                for a, b in zip(c, p)))
              for c in counter}
    out = Image.new("RGB", im.size)
    out.putdata([lookup[c] for c in im.getdata()])
    return out


def load_palette(path):
    """读取游戏主色板（extract.py 生成的 palette.txt，每行 r,g,b）。"""
    with open(path) as fp:
        return [tuple(map(int, line.strip().split(","))) for line in fp]


def map_to_palette(img, palette):
    """把图像每个像素映射到主色板最近色（不混合，肤色/白色各归各）。"""
    im = img.convert("RGB")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = px[x, y]
            px[x, y] = min(palette, key=lambda p: (r - p[0]) ** 2
                           + (g - p[1]) ** 2 + (b - p[2]) ** 2)
    return im
