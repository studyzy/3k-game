#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""应用 7 个剧本的出仕归属（assign/*.json），重建剧本级在野表。

流程（每剧本）：
1. 窗口复核移除：开局未出生/幼童的已出仕者 → 降级在野。
2. 应用 moves（同势力内换城，目标城归属必须与当前城一致）。
3. 应用 placements（pool 在野者 → 指定势力的城市）。
4. 一致性修正与校验，重建剧本级 citys_unoffice.json（= 顶层表 ∩ 该剧本最终在野者）。
用法: python3 tools/scenario_roster/apply.py [--dry]
"""
import json
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATA = os.path.join(ROOT, 'bwdl', 'packed', 'data')
HERE = os.path.dirname(os.path.abspath(__file__))

SCENARIOS = {
    'liangjin': 386, 'nanbeichao': 420, 'suitang': 618, 'wudai': 907,
    'song': 1208, 'yuanming': 1360, 'qing': 1645,
}

# 窗口复核移除：开局年 < 出场年 ≤ 开局+20 中经逐个核实「开局未出生或幼童」者
WINDOW_REMOVALS = {
    'liangjin': [647, 646, 695, 645, 612],          # 沈田子 朱龄石 檀道济 王镇恶 司马德宗
    'nanbeichao': [685, 689, 759, 698],             # 拓跋焘 刘骏 源贺 柳元景
    'suitang': [821],                               # 武则天
    'wudai': [966, 975],                            # 李从厚 孔谦
    'song': [1274, 1258, 1257, 1165, 1184, 1220, 1203],  # 完颜守绪 李睍 李德旺 赵昀 孟珙 吴文英 江万里
    'yuanming': [],
    'qing': [1549, 1541, 1589, 1542, 1532, 1579, 1547],  # 靳辅 索额图 蒲松龄 明珠 玄烨 阎若璩 熊赐履
}

# 补充换城：机械填充遗留位置不当的势力宗室（同势力内挪到都城）
EXTRA_MOVES = {
    'wudai': [(1000, '建业')],                      # 杨溥（吴主之弟）夷洲→建业
}

# 剧本快照字段修正：君主开局必须在世（杨行密卒于905，早于开局907）
LORD_FIXES = {
    'wudai': [(997, '大限', 912)],                  # 杨行密
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
    top = load(os.path.join(DATA, 'citys_unoffice.json'))

    for scen, start in SCENARIOS.items():
        ddir = os.path.join(DATA, 'drama', scen)
        actors = load(os.path.join(ddir, 'actors.json'))
        citys = load(os.path.join(ddir, 'citys.json'))
        vstates = load(os.path.join(ddir, 'vstates.json'))
        assign = load(os.path.join(HERE, 'assign', scen + '.json'))
        city_by_id = {c['ID']: c for c in citys}
        city_by_name = {c['城池名']: c for c in citys}
        errors, skipped = [], []

        # 剧本专属 ID（快照与主表姓名不一致，或超出主表）
        local_extra = set(i for i in range(min(len(actors), len(master)))
                          if actors[i].get('姓名') != master[i].get('姓名'))
        local_extra.update(range(len(master), len(actors)))

        def roster_of(aid):
            for c in citys:
                if aid in c['武将']:
                    return c
            return None

        # 1) 窗口复核移除
        for aid in WINDOW_REMOVALS.get(scen, []):
            c = roster_of(aid)
            if c is None:
                skipped.append(f'窗口移除 {aid} {actors[aid]["姓名"]}: 不在任何城中')
                continue
            c['武将'].remove(aid)
            actors[aid]['状态'] = '在野'

        # 1.4) 君主大限修正（剧本快照内，主表不动）
        for aid, attr, val in LORD_FIXES.get(scen, []):
            if actors[aid].get(attr) != val:
                print(f'   [修正] {actors[aid]["姓名"]} {attr}: {actors[aid].get(attr)} -> {val}')
                actors[aid][attr] = val

        # 1.5) 死亡扫描：大限早于开局的在野/出仕者 → 死亡（出仕者同时移出城）
        dead_n = 0
        for aid, x in enumerate(actors):
            dx = x.get('大限')
            dx = int(dx) if isinstance(dx, (int, float)) else None
            if dx is None or dx >= start or x['状态'] not in ('在野', '出仕'):
                continue
            if x['状态'] == '出仕':
                c = roster_of(aid)
                if c is not None:
                    c['武将'].remove(aid)
                    skipped.append(f'死亡扫描移出: {aid} {x["姓名"]} (大限{dx})')
            x['状态'] = '死亡'
            dead_n += 1

        # 2) moves
        moves = list(assign.get('moves', []))
        for aid, cname in EXTRA_MOVES.get(scen, []):
            moves.append({'ID': aid, 'to_city': city_by_name[cname]['ID'], 'why': '宗室归都城'})
        for mv in moves:
            aid, to = int(mv['ID']), int(mv['to_city'])
            frm = roster_of(aid)
            if frm is None:
                skipped.append(f'move {aid} {actors[aid]["姓名"]}: 已不在城中(可能被窗口移除)')
                continue
            if to not in city_by_id:
                errors.append(f'move {aid}: 目标城 {to} 不存在')
                continue
            if city_by_id[to]['归属'] != frm['归属']:
                errors.append(f'move {aid} {actors[aid]["姓名"]}: 跨势力 {frm["城池名"]}({frm["归属"]})→{city_by_id[to]["城池名"]}({city_by_id[to]["归属"]})')
                continue
            frm['武将'].remove(aid)
            city_by_id[to]['武将'].append(aid)

        # 3) placements
        seen = set()
        for p in assign.get('placements', []):
            aid, vs, cid = int(p['ID']), int(p['vstate']), int(p['city'])
            if aid in seen:
                errors.append(f'placement {aid}: 重复')
                continue
            seen.add(aid)
            if aid >= len(actors):
                errors.append(f'placement {aid}: 超出快照')
                continue
            if cid not in city_by_id:
                errors.append(f'placement {aid}: 目标城 {cid} 不存在')
                continue
            if city_by_id[cid]['归属'] != vs:
                errors.append(f'placement {aid} {actors[aid]["姓名"]}: 城{city_by_id[cid]["城池名"]}归属{city_by_id[cid]["归属"]}≠势力{vs}')
                continue
            st = actors[aid]['状态']
            if st == '在野':
                if roster_of(aid) is not None:
                    errors.append(f'placement {aid} {actors[aid]["姓名"]}: 已在 {roster_of(aid)["城池名"]}')
                    continue
                city_by_id[cid]['武将'].append(aid)
                actors[aid]['状态'] = '出仕'
            elif st == '出仕':
                # 幂等：重复执行时已出仕者直接就位/换城，不再报错
                cur = roster_of(aid)
                if cur is None:
                    errors.append(f'placement {aid} {actors[aid]["姓名"]}: 状态出仕却不在任何城')
                elif cur['ID'] != cid:
                    cur['武将'].remove(aid)
                    city_by_id[cid]['武将'].append(aid)
            else:
                errors.append(f'placement {aid} {actors[aid]["姓名"]}: 状态={st} 不可出仕')

        # 4) 校验
        placed_cnt = {}
        for c in citys:
            ids = c['武将']
            if len(set(ids)) != len(ids):
                errors.append(f'城 {c["城池名"]}: 武将列表有重复')
            if c['归属'] == -1 and ids:
                errors.append(f'城 {c["城池名"]}: 空城却有武将')
            for aid in ids:
                placed_cnt[aid] = placed_cnt.get(aid, 0) + 1
                if actors[aid]['状态'] != '出仕':
                    errors.append(f'{aid} {actors[aid]["姓名"]}: 在城中但状态={actors[aid]["状态"]}')
        dup = [aid for aid, n in placed_cnt.items() if n > 1]
        if dup:
            errors.append(f'一人多城: {[(a, actors[a]["姓名"]) for a in dup]}')
        for vs in vstates:
            lord = vs.get('君主', -1)
            if isinstance(lord, int) and lord >= 0:
                c = roster_of(lord)
                if c is None:
                    errors.append(f'势力{vs["ID"]} 君主 {actors[lord]["姓名"]} 不在任何城')
                elif c['归属'] != vs['ID']:
                    errors.append(f'势力{vs["ID"]} 君主 {actors[lord]["姓名"]} 在他势力城 {c["城池名"]}')

        # 5) 重建剧本级在野表
        entries = []
        covered = set()
        for e in top:
            aid = e['武将']
            if aid >= len(actors) or aid in local_extra or aid in covered:
                continue
            if actors[aid]['状态'] != '在野':
                continue
            covered.add(aid)
            entries.append({'城池': e['城池'], '登场年': e['登场年'], '武将': aid})

        if not dry:
            save(os.path.join(ddir, 'citys.json'), citys)
            save(os.path.join(ddir, 'actors.json'), actors)
            save(os.path.join(ddir, 'citys_unoffice.json'), entries)

        total = len(placed_cnt)
        per_faction = {}
        for c in citys:
            per_faction[c['归属']] = per_faction.get(c['归属'], 0) + len(c['武将'])
        per_city = sorted((len(c['武将']) for c in citys))
        tag = '(dry run 未写入)' if dry else ''
        print(f'== {scen}: 出仕总数 {total} {tag}')
        print(f'   每势力: {dict(sorted(per_faction.items()))}')
        print(f'   每城人数(升序): {per_city}')
        print(f'   在野表条目: {len(entries)} (死亡扫描 {dead_n} 人)')
        if skipped:
            print(f'   跳过: {skipped}')
        if errors:
            print(f'   [错误] {errors}')
        else:
            print('   校验全部通过')


if __name__ == '__main__':
    main()
