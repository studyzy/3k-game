#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""为 7 个跨朝代剧本生成出仕归属任务所需的上下文文件。

用法: python3 tools/scenario_roster/precompute.py
输出: tools/scenario_roster/context/<剧本>.json
"""
import json
import os
import re
import collections

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA = os.path.join(ROOT, 'bwdl', 'packed', 'data')
DOCS = os.path.join(ROOT, 'docs', 'actors_expansion')
OUTDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'context')

SCENARIOS = {
    'liangjin':   {'start': 386,  'mds': ['01_两晋十六国.md', '02_南北朝.md']},
    'nanbeichao': {'start': 420,  'mds': ['01_两晋十六国.md', '02_南北朝.md']},
    'suitang':    {'start': 618,  'mds': ['02_南北朝.md', '03_隋唐.md']},
    'wudai':      {'start': 907,  'mds': ['03_隋唐.md', '04_五代十国.md']},
    'song':       {'start': 1208, 'mds': ['04_五代十国.md', '05_两宋辽金西夏.md', '08_历代状元.md']},
    'yuanming':   {'start': 1360, 'mds': ['05_两宋辽金西夏.md', '06_元明.md', '08_历代状元.md']},
    'qing':       {'start': 1645, 'mds': ['06_元明.md', '07_清.md', '08_历代状元.md']},
}


def load_json(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def parse_mds(md_files):
    """解析人物表 md，返回 姓名 -> [(卒年, 身份, 城市), ...]"""
    table = collections.defaultdict(list)
    for fn in md_files:
        path = os.path.join(DOCS, fn)
        if not os.path.exists(path):
            continue
        with open(path, encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line.startswith('|'):
                    continue
                cells = [c.strip() for c in line.strip('|').split('|')]
                if len(cells) < 7 or cells[0] in ('姓名', '', '------'):
                    continue
                name = re.sub(r'\s', '', cells[0])
                if not name or name == '------':
                    continue
                zsy = cells[3]           # 卒年(约)
                shenfen = cells[4]       # 身份
                city = cells[6]          # 城市
                m = re.search(r'(\d{3,4})', zsy)
                zsy_year = int(m.group(1)) if m else None
                table[name].append((zsy_year, shenfen, city))
    return table


def md_info(table, name, daxian):
    """按卒年最接近大限挑选同名者。"""
    rows = table.get(name)
    if not rows:
        return '', ''
    if len(rows) == 1 or daxian is None:
        return rows[0][1], rows[0][2]
    best = min(rows, key=lambda r: abs((r[0] if r[0] is not None else -9999) - daxian))
    return best[1], best[2]


def main():
    master = load_json(os.path.join(DATA, 'actors.json'))
    top_unoffice = load_json(os.path.join(DATA, 'citys_unoffice.json'))
    appear = {}
    for e in top_unoffice:
        appear.setdefault(e['武将'], e['登场年'])

    os.makedirs(OUTDIR, exist_ok=True)
    for scen, cfg in SCENARIOS.items():
        ddir = os.path.join(DATA, 'drama', scen)
        actors = load_json(os.path.join(ddir, 'actors.json'))
        citys = load_json(os.path.join(ddir, 'citys.json'))
        vstates = load_json(os.path.join(ddir, 'vstates.json'))

        start = cfg['start']
        md_table = parse_mds(cfg['mds'])
        # 顶层在野表覆盖不到的剧本专属 ID 段（快照与主表姓名不一致的下标）
        local_extra = [i for i in range(min(len(actors), len(master)))
                       if actors[i].get('姓名') != master[i].get('姓名')]
        local_extra += list(range(len(master), len(actors)))

        # 大限缺失或早于开局的，标记死亡（写回在 apply 阶段，这里只影响候选池）
        pool = []
        placed = {}
        for i, x in enumerate(actors):
            st = x.get('状态')
            dx = x.get('大限')
            dx = int(dx) if isinstance(dx, (int, float)) else None
            if st not in ('在野', '出仕'):
                continue
            if dx is not None and dx < start:
                continue  # 开局前已死，不入池（apply 阶段统一修正状态）
            shenfen, city = md_info(md_table, x.get('姓名', ''), dx)
            entry = {
                'ID': i, '姓名': x.get('姓名'), '字': x.get('字', ''),
                '大限': dx, '出场': appear.get(i, '?'),
                '身份': shenfen, 'md城市': city, '状态': st,
            }
            if i in local_extra:
                entry['剧本专属'] = True
            pool.append(entry)
            if st == '出仕':
                placed[i] = None  # 稍后填城市

        current_rosters = {}
        for c in citys:
            ids = [int(a) for a in c.get('武将', [])]
            current_rosters[str(c['ID'])] = ids
            for a in ids:
                if a in placed:
                    placed[a] = c['ID']

        factions = []
        for vs in vstates:
            lord = vs.get('君主', -1)
            factions.append({
                'ID': vs['ID'],
                '君主': lord,
                '君主名': actors[lord]['姓名'] if isinstance(lord, int) and 0 <= lord < len(actors) else None,
                '继承人': vs.get('继承人'),
                '城池': [c['ID'] for c in citys if c.get('归属') == vs['ID']],
            })

        ctx = {
            'scenario': scen,
            'start_year': start,
            'snapshot_len': len(actors),
            'md_sources': cfg['mds'],
            'cities': [{'ID': c['ID'], '城池名': c['城池名'], '归属': c.get('归属'),
                        '地域': c.get('地域', ''), '行政区': c.get('行政区', '')} for c in citys],
            'factions': factions,
            'current_rosters': current_rosters,
            'local_extra_ids': local_extra,
            'pool_size': len(pool),
            'pool': pool,
        }
        out = os.path.join(OUTDIR, scen + '.json')
        with open(out, 'w', encoding='utf-8') as f:
            json.dump(ctx, f, ensure_ascii=False, separators=(',', ':'))

        # 诊断
        placed_cnt = sum(1 for e in pool if e['状态'] == '出仕')
        no_appear = sum(1 for e in pool if e['出场'] == '?')
        extra = len(local_extra)
        print(f"{scen}: start={start} 池={len(pool)} (已出仕{placed_cnt}/在野{len(pool)-placed_cnt}) "
              f"出场年缺失{no_appear} 剧本专属ID{extra} -> {os.path.relpath(out, ROOT)}")

    # 顶层在野表覆盖率
    no_entry = [m['姓名'] for m in master if m['ID'] not in appear
                and m.get('状态') != '死亡' and m['ID'] >= 561]
    print(f"顶层在野表 {len(top_unoffice)} 条, 扩展段无条目者 {len(no_entry)}")


if __name__ == '__main__':
    main()
