# -*- coding: utf-8 -*-
# ==============================================================================
# fix_all_frames / check_frames 集成测试：临时目录端到端（修复 → 幂等 → 校验）
#
# 不依赖真实游戏资产：fixture 程序化合成 256×40 全同表情条，
# 覆盖「未修复 → 修复 → 重跑（幂等）→ 校验」全流程（tasks.md T006/T011）。
# ==============================================================================
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # tools/avatar_gen
sys.path.insert(0, TOOLS)

from expressions import W, H  # noqa: E402

SKIN = (232, 160, 110)
DARK = (40, 30, 30)


def make_flat_sheet(path):
    """合成一张「8 帧全同」的 256×40 假头像并保存（模拟待修复的生成头像）。"""
    frame = Image.new("RGB", (W, H), SKIN)
    px = frame.load()
    for y in range(15, 18):                      # 双眼
        for x in list(range(6, 11)) + list(range(21, 26)):
            px[x, y] = DARK
    for x in range(12, 20):                      # 嘴线
        px[x, 28] = DARK
    sheet = Image.new("RGB", (W * 8, H))
    for i in range(8):
        sheet.paste(frame, (i * W, 0))
    sheet.save(path)


def make_original_sheet(path):
    """合成一张「原版风格」（8 帧互异）头像，验证修复不碰原版段。"""
    sheet = Image.new("RGB", (W * 8, H), SKIN)
    px = sheet.load()
    for i in range(8):                           # 每帧加一个不同的标记点
        px[i * W + 2, 2] = (i, i, i)
    sheet.save(path)
    return sheet


def run_py(script, args):
    """以子进程运行 tools/avatar_gen 下的脚本，返回 CompletedProcess。"""
    env = dict(os.environ)
    env.pop("PYTHONPATH", None)  # 规避与本仓库无关的同名 tests 包干扰
    return subprocess.run(
        [sys.executable, os.path.join(TOOLS, script)] + args,
        capture_output=True, text=True, env=env)


class TestFixAllFrames(unittest.TestCase):
    """修复入口端到端测试（对应任务 T008 验收）。"""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="avatar_fix_test_")
        # 场景: 700=待修生成段, 100=原版段, 546=灰占位白名单
        make_flat_sheet(os.path.join(self.tmp, "700.png"))
        make_original_sheet(os.path.join(self.tmp, "100.png"))
        self.original_bytes = open(os.path.join(self.tmp, "100.png"), "rb").read()
        make_flat_sheet(os.path.join(self.tmp, "546.png"))

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def test_fix_preserves_frame4_and_varies_frames(self):
        """修复后：帧 4 不变、8 帧互异、原版段与 546 不被修改。"""
        # 修复前先取出帧 4 内容（PIL 懒加载，替换后 open 句柄读到的是新文件）
        before = Image.open(os.path.join(self.tmp, "700.png")).convert("RGB")
        frame4_before = before.crop((4 * W, 0, 5 * W, H)).tobytes()
        r = run_py("fix_all_frames.py", ["--dir", self.tmp])
        self.assertEqual(r.returncode, 0, r.stderr)
        fixed = Image.open(os.path.join(self.tmp, "700.png")).convert("RGB")
        self.assertEqual(fixed.crop((4 * W, 0, 5 * W, H)).tobytes(), frame4_before)
        datas = {fixed.crop((i * W, 0, i * W + W, H)).tobytes() for i in range(8)}
        self.assertEqual(len(datas), 8)
        # 原版段与 546 逐字节不变
        self.assertEqual(open(os.path.join(self.tmp, "100.png"), "rb").read(),
                         self.original_bytes)
        five46 = Image.open(os.path.join(self.tmp, "546.png")).convert("RGB")
        self.assertEqual(len({five46.crop((i * W, 0, i * W + W, H)).tobytes()
                              for i in range(8)}), 1)

    def test_fix_idempotent(self):
        """重跑修复：已合规的图逐字节不变。"""
        run_py("fix_all_frames.py", ["--dir", self.tmp])
        first = open(os.path.join(self.tmp, "700.png"), "rb").read()
        run_py("fix_all_frames.py", ["--dir", self.tmp])
        self.assertEqual(open(os.path.join(self.tmp, "700.png"), "rb").read(), first)

    def test_dry_run_writes_nothing(self):
        """--dry-run：只统计不落盘，文件内容不变。"""
        before = open(os.path.join(self.tmp, "700.png"), "rb").read()
        r = run_py("fix_all_frames.py", ["--dir", self.tmp, "--dry-run"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(open(os.path.join(self.tmp, "700.png"), "rb").read(), before)


class TestCheckFrames(unittest.TestCase):
    """校验工具测试（对应任务 T012 验收）。"""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="avatar_check_test_")

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def _write_actors(self, ids):
        """在临时目录写一份最小 actors.json，经 --actors 参数注入校验脚本。"""
        p = os.path.join(self.tmp, "actors.json")
        json.dump([{"ID": i} for i in ids], open(p, "w"))
        return p

    def test_clean_dir_passes(self):
        """全部合规（仅 546 白名单全同）：退出码 0。"""
        make_original_sheet(os.path.join(self.tmp, "100.png"))
        make_flat_sheet(os.path.join(self.tmp, "546.png"))
        actors = self._write_actors([100, 546])
        r = run_py("check_frames.py", ["--dir", self.tmp, "--actors", actors])
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)

    def test_flat_frame_fails(self):
        """存在全同图（非白名单）：退出码非 0 且清单中含该 ID。"""
        make_flat_sheet(os.path.join(self.tmp, "700.png"))
        actors = self._write_actors([700])
        r = run_py("check_frames.py", ["--dir", self.tmp, "--actors", actors])
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("700", r.stdout)

    def test_bad_size_fails(self):
        """尺寸异常（非 256×40）：退出码非 0。"""
        Image.new("RGB", (64, 40), SKIN).save(os.path.join(self.tmp, "700.png"))
        actors = self._write_actors([700])
        r = run_py("check_frames.py", ["--dir", self.tmp, "--actors", actors])
        self.assertNotEqual(r.returncode, 0)

    def test_missing_file_reported(self):
        """actors.json 有记录但缺头像文件：报告中列出（如 ID 2563 的情形）。"""
        make_original_sheet(os.path.join(self.tmp, "100.png"))
        actors = self._write_actors([100, 2563])
        r = run_py("check_frames.py", ["--dir", self.tmp, "--actors", actors])
        self.assertIn("2563", r.stdout)
        self.assertEqual(r.returncode, 0)  # 缺文件只提示，不算违规


if __name__ == "__main__":
    unittest.main()
