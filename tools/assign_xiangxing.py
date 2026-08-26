#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""给 docs 新增武将批量赋相性（按政权分档），写入 actors_extra.json。"""
import json, os

BASE = os.path.join(os.path.dirname(__file__), '..', 'docs', 'actors_expansion')
OUT_EXTRA = os.path.join(os.path.dirname(__file__), '..', 'bwdl', 'packed', 'data', 'actors_extra.json')
OUT_ACTORS = os.path.join(os.path.dirname(__file__), '..', 'bwdl', 'packed', 'data', 'actors.json')

FILES = ['01_两晋十六国.md', '02_南北朝.md', '03_隋唐.md', '04_五代十国.md',
         '05_两宋辽金西夏.md', '06_元明.md', '07_清.md']

# 每个文件：按顺序的 (标题包含关键字, 相性)。命中 ## 或 ### 时更新当前相性。
RULES = {
    '01_两晋十六国.md': [
        ('西晋', 30), ('东晋', 31), ('十六国', None),
        ('汉赵', 90), ('后赵', 91), ('成汉', 92), ('前燕', 93),
        ('前秦', 94), ('后秦', 95), ('后凉', 96), ('北魏早期', 97),
    ],
    '02_南北朝.md': [
        ('南朝·宋', 100), ('南朝·齐', 101), ('南朝·梁', 102), ('南朝·陈', 103),
        ('北朝·北魏', 97), ('北朝·东魏', 104), ('北朝·西魏', 105),
        ('北朝·北齐', 106), ('北朝·北周', 107), ('民歌传说', 108),
    ],
    '03_隋唐.md': [
        ('一、隋', 40), ('隋末唐初割据', 41), ('二、唐', 42),
        ('安史之乱', 43), ('黄巢起义', 44), ('隋唐演义小说人物', 45),
    ],
    '04_五代十国.md': [
        ('后梁', 60), ('后唐', 61), ('后晋', 62), ('后汉', 63), ('后周', 64),
        ('十国·吴', 65), ('南唐', 66), ('吴越', 67), ('十国·闽', 68), ('南汉', 69),
        ('前蜀', 70), ('后蜀', 71), ('十国·楚', 72), ('荆南', 73), ('北汉', 74),
        ('演义小说人物', 75),
    ],
    '05_两宋辽金西夏.md': [
        ('北宋', 80), ('南宋', 81), ('三、辽', 82), ('西夏', 83), ('五、金', 84),
        ('杨家将', 85), ('说岳全传', 86), ('水浒传', 87),
    ],
    '06_元明.md': [
        ('一、元', 110), ('二、明', 111),
    ],
    '07_清.md': [
        ('清前期', 120), ('清中期', 120), ('晚清', 120), ('太平天国', 121),
        ('公案小说', 122), ('武术家', 123),
    ],
}


def main():
    actors = json.load(open(OUT_ACTORS, encoding='utf-8'))
    extra = json.load(open(OUT_EXTRA, encoding='utf-8'))
    existing_ids = set(e['ID'] for e in extra)
    order_idx = 0
    result = list(extra)
    ok = 0
    for fn in FILES:
        cur = None
        with open(os.path.join(BASE, fn), encoding='utf-8') as f:
            lines = f.read().splitlines()
        for ln in lines:
            if ln.startswith('##') or ln.startswith('###'):
                for marker, val in RULES[fn]:
                    if marker in ln:
                        if val is not None:
                            cur = val
                        break
                continue
            if not ln.startswith('|') or '姓名' in ln or ln.startswith('|---'):
                continue
            cols = [c.strip() for c in ln.split('|')]
            if len(cols) != 17:
                continue
            name = cols[1].split('#')[0]
            aid = 561 + order_idx
            order_idx += 1
            a = actors[aid]
            if a['姓名'] != name:
                print('顺序不一致!', aid, '期望', name, '实际', a['姓名'])
                continue
            if cur is None:
                print('无相性规则 for', fn, name, '-> 默认 0')
                cur = 0
            if aid not in existing_ids:
                result.append({'ID': aid, '相性': cur})
                existing_ids.add(aid)
            ok += 1
    result.sort(key=lambda e: e['ID'])
    with open(OUT_EXTRA, 'w', encoding='utf-8') as f:
        f.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('赋相性武将数:', ok)
    print('actors_extra 总数:', len(result))


if __name__ == '__main__':
    main()
