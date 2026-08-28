#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""移除各剧本现有出仕中的穿越错放（出场年 > 开局+20 的非剧本专属武将）。

降级为在野（之后由剧本在野表按其登场年自然出现）。
用法: python3 tools/scenario_roster/remove_anachronistic.py [--dry]
"""
import json
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA = os.path.join(ROOT, 'bwdl', 'packed', 'data')

SCENARIOS = {
    'liangjin': 386, 'nanbeichao': 420, 'suitang': 618, 'wudai': 907,
    'song': 1208, 'yuanming': 1360, 'qing': 1645,
}


def load(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def save(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))


def main():
    dry = '--dry' in sys.argv
    master = load(os.path.join(DATA, 'actors.json'))
    appear = {}
    for e in load(os.path.join(DATA, 'citys_unoffice.json')):
        appear.setdefault(e['武将'], e['登场年'])

    for scen, start in SCENARIOS.items():
        ddir = os.path.join(DATA, 'drama', scen)
        actors = load(os.path.join(ddir, 'actors.json'))
        citys = load(os.path.join(ddir, 'citys.json'))

        # 剧本专属 ID：与主表同下标姓名不一致，或超出主表长度
        local_extra = set(i for i in range(min(len(actors), len(master)))
                          if actors[i].get('姓名') != master[i].get('姓名'))
        local_extra.update(range(len(master), len(actors)))

        junk = []  # (aid, 城市)
        for c in citys:
            keep = []
            for aid in c.get('武将', []):
                aid = int(aid)
                exp = appear.get(aid)
                if aid not in local_extra and exp is not None and exp > start + 20:
                    junk.append((aid, c['ID']))
                else:
                    keep.append(aid)
            c['武将'] = keep

        for aid, _ in junk:
            if actors[aid].get('状态') == '出仕':
                actors[aid]['状态'] = '在野'

        if not dry:
            save(os.path.join(ddir, 'citys.json'), citys)
            save(os.path.join(ddir, 'actors.json'), actors)
        names = ', '.join(f"{actors[a]['姓名']}" for a, _ in junk[:8])
        print(f"{scen}: 移除穿越错放 {len(junk)} 人 {('[' + names + '...]') if junk else ''}"
              f"{' (dry run 未写入)' if dry else ''}")


if __name__ == '__main__':
    main()
