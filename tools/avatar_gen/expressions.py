#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""表情派生模块：把 32×40 单帧头像派生为「4 心情 × 2 嘴型」八帧表情条。

帧序契约（与游戏渲染 actor_face.gd:100 的取帧公式一致）:
    帧序 = [怒闭, 怒张, 喜闭, 喜张, 平闭, 平张, 哀闭, 哀张]
    帧横坐标 = mood*2*32 + mouthFlag*32，mood 0~3 = 愤怒/高兴/平静/沮丧

派生策略（specs/001-fix-avatar-frames/research.md R2/R4/R5）:
    - 永远以「平静-闭嘴」帧（帧 4）为唯一基底，帧 4 本身不修改 → 幂等
    - 心情差异通过眉眼区行级几何变换实现（怒=瞪眼、喜=眯眼、哀=垂眼）
    - 嘴型差异通过「端点保留、中段清空、下方开口」实现
    - 所有新像素只复用基底帧内已有颜色，天然满足 64 色板约束
"""
from PIL import Image

W, H = 32, 40          # 单帧尺寸
DARK_SUM = 180         # 暗色判定阈值（r+g+b < 180，实证命中率见 research.md R3）
EYE_BAND = (12, 24)    # 眼区检测行范围
MOUTH_BAND = (26, 33)  # 嘴线检测行范围（眼底线 +2 起，见 locate_features）


def _dark(p):
    """暗色像素判定（眼、眉、嘴线等五官色）。"""
    return p[0] + p[1] + p[2] < DARK_SUM


def locate_features(frame4):
    """从平静-闭嘴帧定位五官。

    返回 {"eyes": (top, bot) | None, "mouth": (y, x0, x1) | None}。
    - 眼: 行 12~24 内暗色像素计数峰值行，向上/下扩展（条件：行内暗像素 >= 2）
    - 嘴: 眼底线 +2 起、行 33 止，找宽 3~12 的暗色横段；找不到（如胡须遮挡）返回 None
    """
    px = frame4.load()

    # —— 眼区 ——
    counts = {y: sum(1 for x in range(4, 28) if _dark(px[x, y]))
              for y in range(EYE_BAND[0], EYE_BAND[1] + 1)}
    eyes = None
    if counts:
        y_mid = max(counts, key=lambda y: counts[y])  # 首个峰值行
        if counts[y_mid] >= 4:
            top = y_mid
            while top > EYE_BAND[0] and sum(1 for x in range(4, 28) if _dark(px[x, top - 1])) >= 2:
                top -= 1
            bot = y_mid
            while bot < EYE_BAND[1] and sum(1 for x in range(4, 28) if _dark(px[x, bot + 1])) >= 2:
                bot += 1
            eyes = (top, bot)

    # —— 嘴线 ——
    mouth = None
    if eyes:
        y0 = min(eyes[1] + 2, MOUTH_BAND[1])
        for y in range(y0, MOUTH_BAND[1] + 1):
            run = best = 0
            end = 0
            for x in range(6, 26):
                if _dark(px[x, y]):
                    run += 1
                    if run > best:
                        best, end = run, x
                else:
                    run = 0
            if 3 <= best <= 12:
                mouth = (y, end - best + 1, end)
                break
    return {"eyes": eyes, "mouth": mouth}


def _eye_columns(px, top, bot):
    """在眼区内按 x 聚类出左右眼列范围，返回 [(x0, x1), ...]（忽略单像素噪点）。"""
    xs = sorted({x for y in range(top, bot + 1) for x in range(4, 28) if _dark(px[x, y])})
    clusters = []
    for x in xs:
        if clusters and x - clusters[-1][-1] <= 2:
            clusters[-1].append(x)
        else:
            clusters.append([x])
    return [(c[0], c[-1]) for c in clusters if len(c) >= 2]


def _bg_color(px, x, y):
    """取 (x, y) 周围的非暗色作为清除填充色（眼/嘴外侧肤色）。"""
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        nx, ny = x + dx, y + dy
        if 0 <= nx < W and 0 <= ny < H and not _dark(px[nx, ny]):
            return px[nx, ny]
    return px[0, 0]


def _apply_eyes(base, feats, mode):
    """眼区行级变换，返回新帧。

    mode:
      "angry" — 瞪眼: 每只眼顶行像素向上复制一行（眼高 +1）
      "happy" — 眯眼: 每只眼顶行清除（眼高 -1，剩细缝）
      "sad"   — 垂眼: 顶行清除 + 底行像素向下复制一行（整体下移 1px）
    """
    img = base.copy()
    if not feats["eyes"]:
        return img
    px = img.load()
    top, bot = feats["eyes"]
    cols = _eye_columns(px, top, bot) or [(6, 10), (21, 25)]  # 兜底：标准眼位
    if mode == "angry":
        for x0, x1 in cols:
            for x in range(x0, x1 + 1):
                px[x, top - 1] = px[x, top]
    elif mode in ("happy", "sad"):
        for x0, x1 in cols:
            for x in range(x0, x1 + 1):
                px[x, top] = _bg_color(px, x, top)
        if mode == "sad":
            for x0, x1 in cols:
                for x in range(x0, x1 + 1):
                    px[x, bot + 1] = base.load()[x, bot]
    return img


def _open_mouth(base, mouth):
    """张嘴变换，返回新帧：端点保留、嘴线中段清空、下方 2 行深色开口。

    开口画法参照原版张嘴帧（如刘备帧 1 怒张）：开口位于原嘴线下方，
    宽度为两端点内缩 2px，颜色取嘴线原色（帧内已有颜色）。
    """
    img = base.copy()
    if not mouth:
        return img
    y, x0, x1 = mouth
    px = img.load()
    src = base.load()
    fill = _bg_color(px, x0, y)           # 嘴线外侧肤色
    line = src[x0, y]                      # 嘴线原色（开口色）
    for x in range(x0 + 1, x1):            # 中段清空（端点保留）
        px[x, y] = fill
    ox0, ox1 = max(x0 + 2, x0 + 1), min(x1 - 2, x1 - 1)
    if ox1 < ox0:                          # 短嘴线：开口取全段
        ox0, ox1 = x0 + 1, x1 - 1
    for yy in (y + 1, y + 2):              # 2 行高开口
        if yy < H:
            for x in range(ox0, ox1 + 1):
                px[x, yy] = line
    return img


def derive_frames(frame4):
    """从平静-闭嘴帧派生 8 帧，返回 [Image×8]（帧序见模块头注释）。

    - 帧序: 0怒闭 1怒张 2喜闭 3喜张 4平闭 5平张 6哀闭 7哀张
    - 帧原样返回；嘴线缺失（胡须遮挡）时张嘴帧=同心情闭嘴帧
    - 幂等：对派生结果的帧 4 再次派生，输出逐像素不变
    """
    feats = locate_features(frame4)
    flat = frame4.convert("RGB")
    angry = _apply_eyes(flat, feats, "angry")
    happy = _apply_eyes(flat, feats, "happy")
    sad = _apply_eyes(flat, feats, "sad")
    frames = [
        angry, _open_mouth(angry, feats["mouth"]),
        happy, _open_mouth(happy, feats["mouth"]),
        flat, _open_mouth(flat, feats["mouth"]),
        sad, _open_mouth(sad, feats["mouth"]),
    ]
    return frames


def derive_sheet(frame4):
    """把 32×40 单帧派生并拼成 256×40 八帧表情条。"""
    sheet = Image.new("RGB", (W * 8, H))
    for i, f in enumerate(derive_frames(frame4)):
        sheet.paste(f, (i * W, 0))
    return sheet
