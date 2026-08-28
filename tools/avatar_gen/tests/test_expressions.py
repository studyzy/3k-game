# -*- coding: utf-8 -*-
# ==============================================================================
# expressions 单元测试：五官检测与表情派生
#
# 全部使用程序合成的 32×40 假头像（不依赖真实游戏资产），
# 保证 headless 可跑、结果可复现（specs/001-fix-avatar-frames/research.md R7）。
# ==============================================================================
import os
import sys
import unittest

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from expressions import locate_features, derive_frames, derive_sheet

W, H = 32, 40
SKIN = (232, 160, 110)   # 肤色（符合工具内 skin() 判定区间）
DARK = (40, 30, 30)      # 眼/嘴线暗色


def make_face(eye_top=15, eye_bottom=17, mouth_y=28, has_beard=False):
    """合成一张标准假脸：肤色底 + 左右黑眼簇 + 1 行嘴线。

    - 左眼 x∈[6,10]，右眼 x∈[21,25]，y∈[eye_top, eye_bottom]
    - 嘴线 y=mouth_y，x∈[12,19]（宽 8）
    - has_beard=True 时在嘴周画大块黑色（模拟胡须遮挡嘴线的头像）
    返回 32×40 RGB Image。
    """
    img = Image.new("RGB", (W, H), SKIN)
    px = img.load()
    for y in range(eye_top, eye_bottom + 1):
        for x in list(range(6, 11)) + list(range(21, 26)):
            px[x, y] = DARK
    for x in range(12, 20):
        px[x, mouth_y] = DARK
    if has_beard:
        # 胡须：覆盖嘴线并向下延伸的大块暗色（宽 17 > 嘴线宽上限 12，令嘴检测失败）
        for y in range(mouth_y - 2, min(mouth_y + 6, H)):
            for x in range(7, 25):
                px[x, y] = DARK
    return img


def frame(img, idx):
    """从 256×40 表情条取第 idx 帧（32×40）。"""
    return img.crop((idx * 32, 0, idx * 32 + 32, H))


class TestLocateFeatures(unittest.TestCase):
    """五官检测定位测试（对应任务 T004）。"""

    def test_standard_face(self):
        """标准脸：眼区与嘴线均应被正确定位。"""
        img = make_face()
        feats = locate_features(img)
        self.assertIsNotNone(feats["eyes"])
        self.assertEqual(feats["eyes"], (15, 17))
        self.assertIsNotNone(feats["mouth"])
        my, x0, x1 = feats["mouth"]
        self.assertEqual(my, 28)
        self.assertEqual((x0, x1), (12, 19))

    def test_mouth_missing_fallback(self):
        """嘴线被胡须遮挡：嘴定位应返回 None（派生时跳过嘴变形）。"""
        img = make_face(has_beard=True)
        feats = locate_features(img)
        self.assertIsNotNone(feats["eyes"])
        self.assertIsNone(feats["mouth"])

    def test_empty_canvas_returns_none(self):
        """纯色画布无五官：眼与嘴检测均应安全返回 None，不抛异常。"""
        feats = locate_features(Image.new("RGB", (W, H), SKIN))
        self.assertIsNone(feats["eyes"])
        self.assertIsNone(feats["mouth"])


class TestDeriveFrames(unittest.TestCase):
    """表情派生不变量测试（对应任务 T007）。"""

    def setUp(self):
        self.base = make_face()
        self.frames = derive_frames(self.base)

    def test_eight_frames(self):
        """派生结果必须为 8 帧，每帧 32×40。"""
        self.assertEqual(len(self.frames), 8)
        for f in self.frames:
            self.assertEqual(f.size, (W, H))

    def test_frame4_unchanged(self):
        """帧 4（平静-闭嘴）必须与基底逐像素一致（容貌零改变）。"""
        self.assertEqual(self.frames[4].tobytes(), self.base.tobytes())

    def test_eight_frames_distinct(self):
        """8 帧必须互不相同（修复的核心目标：不再全同）。"""
        datas = [f.tobytes() for f in self.frames]
        self.assertEqual(len(set(datas)), 8)

    def test_closed_open_differ_only_in_mouth(self):
        """同心情闭/张两帧：仅嘴部附近（检测到的嘴线 y±1~+3、x 两端外扩 1）允许差异。"""
        mouth = locate_features(self.base)["mouth"]
        my, mx0, mx1 = mouth
        for closed, opened in ((0, 1), (2, 3), (4, 5), (6, 7)):
            a, b = self.frames[closed], self.frames[opened]
            pa, pb = a.load(), b.load()
            for y in range(H):
                for x in range(W):
                    if my - 1 <= y <= my + 3 and mx0 - 1 <= x <= mx1 + 1:
                        continue
                    self.assertEqual(pa[x, y], pb[x, y],
                                     f"帧{closed}/帧{opened} 在 ({x},{y}) 意外差异")

    def test_eye_shapes_distinguishable(self):
        """四种心情眼区高度可区分：怒眼增高、喜眼压扁、哀眼下移。"""
        eyes = locate_features(self.base)["eyes"]
        height = eyes[1] - eyes[0] + 1
        feats = [locate_features(self.frames[i])["eyes"] for i in (0, 2, 4, 6)]
        # 怒(帧0): 眼区增高
        self.assertGreater(feats[0][1] - feats[0][0] + 1, height)
        # 喜(帧2): 眼区压扁（高度 < 原高）
        self.assertLess(feats[1][1] - feats[1][0] + 1, height)
        # 哀(帧6): 眼区下移（顶行下移、底行下移）
        self.assertGreater(feats[3][0], eyes[0])
        self.assertGreater(feats[3][1], eyes[1])

    def test_colors_from_base_only(self):
        """派生图所有颜色必须 ⊆ 帧原色集合（只用帧内已有颜色）。"""
        allowed = set(self.base.getdata())
        for f in self.frames:
            self.assertTrue(set(f.getdata()) <= allowed)

    def test_idempotent(self):
        """幂等：对派生结果的帧 4 再派生一次，8 帧逐像素不变。"""
        again = derive_frames(self.frames[4])
        for a, b in zip(self.frames, again):
            self.assertEqual(a.tobytes(), b.tobytes())

    def test_mouth_missing_skips_mouth_change(self):
        """胡须遮挡（无嘴线）：张嘴帧必须等于同心情闭嘴帧，只保留眼表情。"""
        base = make_face(has_beard=True)
        frames = derive_frames(base)
        for closed, opened in ((0, 1), (2, 3), (4, 5), (6, 7)):
            self.assertEqual(frames[closed].tobytes(),
                             frames[opened].tobytes())


class TestDeriveSheet(unittest.TestCase):
    """八帧表拼接测试。"""

    def test_sheet_layout(self):
        """derive_sheet 返回 256×40，且第 i 帧与 derive_frames 第 i 帧一致。"""
        base = make_face()
        sheet = derive_sheet(base)
        self.assertEqual(sheet.size, (256, H))
        frames = derive_frames(base)
        for i in range(8):
            self.assertEqual(frame(sheet, i).tobytes(),
                             frames[i].tobytes())


if __name__ == "__main__":
    unittest.main()
