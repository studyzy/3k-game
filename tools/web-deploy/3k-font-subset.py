#!/usr/bin/env python3
"""给 3k 游戏用的字体子集：收集工程里所有用到的字 + GB2312 常用字，生成 msyh.subset.ttf"""
import os, sys, subprocess, pathlib

PROJ = "/home/ubuntu/3k-game/bwdl"
FONT = os.path.join(PROJ, "resource/font/FandolSong-Bold/msyh.ttf")
PYFT = "/home/ubuntu/.venv-font/bin/pyftsubset"

chars = set()

# 1) 工程里出现的所有字符（脚本/场景/数据/主题）
for root, dirs, files in os.walk(PROJ):
    dirs[:] = [d for d in dirs if d not in (".import", ".git", "build", ".ci-signing", "Godot_3.6.3.app")]
    for fn in files:
        if not fn.endswith((".gd", ".tscn", ".tres", ".json", ".cfg", ".md")):
            continue
        try:
            chars |= set(open(os.path.join(root, fn), encoding="utf-8", errors="ignore").read())
        except OSError:
            pass

# 2) ASCII 可打印 + 常用标点/符号区段
chars |= {chr(c) for c in range(0x20, 0x7F)}
for lo, hi in [(0x2000, 0x206F), (0x2190, 0x21FF), (0x2460, 0x24FF),
               (0x25A0, 0x25FF), (0x2600, 0x26FF), (0x3000, 0x303F),
               (0xFF00, 0xFF65)]:
    chars |= {chr(c) for c in range(lo, hi + 1)}

# 3) GB2312 全字集（一级+二级 6763 字）：玩家自定义武将名可能用到任意常用字
for hi in range(0xB0, 0xF8):
    for lo in range(0xA1, 0xFF):
        try:
            chars.add(bytes([hi, lo]).decode("gb2312"))
        except UnicodeDecodeError:
            pass

chars = {c for c in chars if ord(c) >= 0x20 and ord(c) != 0x7F}
text = "".join(sorted(chars))
out_txt = "/tmp/3k-charset.txt"
pathlib.Path(out_txt).write_text(text, encoding="utf-8")
print("字符数", len(chars))

out = sys.argv[1] if len(sys.argv) > 1 else "/tmp/msyh.subset.ttf"
cmd = [PYFT, FONT, "--text-file=" + out_txt, "--output-file=" + out, "--layout-features=*",
       "--drop-tables+=DSIG", "--name-IDs=*", "--recalc-bounds"]
subprocess.run(cmd, check=True)
print(f"{os.path.getsize(FONT)/1048576:.2f} MB -> {os.path.getsize(out)/1048576:.2f} MB")