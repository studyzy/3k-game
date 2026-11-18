#!/usr/bin/env python3
"""把 Godot 3 的 index.pck 拆成「核心包」+「资源包」，用于网页版渐进加载。

核心包（index.pck）：脚本、场景、数据表、字体、菜单/界面纹理 —— 启动和标题画面必需。
资源包（assets.pck）：音频 + 战斗/战争用的大图 —— 引擎起来之后再后台下载并挂载。

用法: 3k-pck-split.py <index.pck> <core.pck> <assets.pck>
"""
import struct, sys, hashlib, os

def parse(path):
    f = open(path, "rb")
    if f.read(4) != b"GDPC":
        raise SystemExit("不是 pck: " + path)
    ver = struct.unpack("<I", f.read(4))[0]
    ver_maj, ver_min, ver_patch = struct.unpack("<III", f.read(12))
    f.read(64)  # reserved
    count = struct.unpack("<I", f.read(4))[0]
    ents = []
    for _ in range(count):
        nlen = struct.unpack("<I", f.read(4))[0]
        name = f.read(nlen).split(b"\0")[0].decode("utf-8")
        off, size = struct.unpack("<QQ", f.read(16))
        md5 = f.read(16)
        ents.append((name, off, size, md5))
    return f, (ver, ver_maj, ver_min, ver_patch), ents


def is_assets(name: str) -> bool:
    if name.endswith(".oggstr"):
        return True
    # 战斗/战争专用大图（标题、内政、菜单都要用到的纹理不放这里）
    for key in ("/battle_character/", "/battle_mapblock/"):
        if key in name:
            return True
    return False


def write_pck(path, header, items, src):
    ver, vmaj, vmin, vpatch = header
    # 先算索引大小：4 magic + 4 version + 12 version* + 64 reserved + 4 count + entries
    idx = 4 + 4 + 12 + 64 + 4
    payload = []
    for name, off, size, md5 in items:
        enc = name.encode("utf-8") + b"\0"
        nlen = len(enc)
        pad = (4 - nlen % 4) % 4
        idx += 4 + nlen + pad + 8 + 8 + 16
        payload.append((name, enc, pad, off, size))

    out = open(path, "wb")
    cur = idx
    out.write(b"GDPC")
    out.write(struct.pack("<I", ver))
    out.write(struct.pack("<III", vmaj, vmin, vpatch))
    out.write(b"\0" * 64)
    out.write(struct.pack("<I", len(payload)))
    body_offsets = []
    for name, enc, pad, off, size in payload:
        out.write(struct.pack("<I", len(enc) + pad))
        out.write(enc + b"\0" * pad)
        out.write(struct.pack("<QQ", cur, size))
        src.seek(off)
        # md5 需要用到的数据，分块算，避免 ==
        h = hashlib.md5()
        remaining = size
        src.seek(off)
        while remaining > 0:
            chunk = src.read(min(1048576, remaining))
            if not chunk:
                break
            h.update(chunk)
            remaining -= len(chunk)
        out.write(h.digest())
        body_offsets.append((cur, off, size))
        cur += size
    for cur, off, size in body_offsets:
        src.seek(off)
        remaining = size
        while remaining > 0:
            chunk = src.read(min(1048576, remaining))
            if not chunk:
                break
            out.write(chunk)
            remaining -= len(chunk)
    out.close()
    return idx


def main():
    src_path, core_path, assets_path = sys.argv[1:4]
    src, header, ents = parse(src_path)
    core = [e for e in ents if not is_assets(e[0])]
    assets = [e for e in ents if is_assets(e[0])]
    print(f"总条目 {len(ents)} -> 核心 {len(core)} / 资源 {len(assets)}")
    write_pck(core_path, header, core, src)
    write_pck(assets_path, header, assets, src)
    for p, items in ((core_path, core), (assets_path, assets)):
        print(f"  {os.path.basename(p):12s} {os.path.getsize(p)/1048576:7.2f} MB  {len(items)} entries")


if __name__ == "__main__":
    main()