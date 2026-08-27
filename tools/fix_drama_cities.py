#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""修复跨朝代剧本 citys.json：给「归属势力但空城」的城池补武将。

背景：游戏约束「归属势力的城池必须至少 1 名武将，否则开局被清成无主（归属=-1）」。
旧数据只把君主+继承人放进首都，其余势力城池全是空城，导致开局只剩一座城。

本脚本：
1. 按「相性（actors_extra.json）+ 身份（docs 身份字段）」把在野武将归类到对应势力；
2. 给每个势力的城池逐城补 1 名太守（君主留首都，继承人、其余武将依次分到空城）；
3. 若某势力武将数少于城池数，则把多出的城池改为无主（归属=-1）；
4. 同步 actors.json（在野→出仕、兵力=1000）与 citys_unoffice.json（移除已出仕者）。

用法：python3 tools/fix_drama_cities.py            # 直接写盘
      python3 tools/fix_drama_cities.py --dry-run  # 只打印报告
"""
import json
import os
import re
import sys

BASE = os.path.join(os.path.dirname(__file__), '..', 'bwdl', 'packed', 'data')
DOCS = os.path.join(os.path.dirname(__file__), '..', 'docs', 'actors_expansion')

DRAMAS = ['liangjin', 'nanbeichao', 'suitang', 'wudai', 'song', 'yuanming', 'qing']

# 默认兵力（对齐 guandu 剧本的出仕武将）
SOLDIERS = 1000


def load_doc_identity():
    """解析 docs，返回 name -> {'身份': ..., 'h2': ..., 'h3': ...}"""
    ret = {}
    for fn in os.listdir(DOCS):
        if not fn.endswith('.md'):
            continue
        h2 = h3 = ''
        for ln in open(os.path.join(DOCS, fn), encoding='utf-8'):
            ln = ln.rstrip('\n')
            if ln.startswith('## '):
                h2 = ln[3:].strip()
                continue
            if ln.startswith('### '):
                h3 = ln[4:].strip()
                continue
            if ln.startswith('|') and '姓名' not in ln and not ln.startswith('|---'):
                cols = [c.strip() for c in ln.split('|')]
                if len(cols) != 17:
                    continue
                name = cols[1].split('#')[0].strip()
                ret[name] = {'身份': cols[5], 'h2': h2, 'h3': h3}
    return ret


def load_xiang():
    extra = json.load(open(os.path.join(BASE, 'actors_extra.json'), encoding='utf-8'))
    return {r['ID']: r.get('相性') for r in extra}


# 每个朝代：势力 -> 用于「在野归类」的规则。
# 规则为 (相性集合, 身份关键词集合)。身份关键词用于在共享相性时细分（可选）。
# 相性相同的势力，靠身份关键词区分。
DRAMA_RULES = {
    'liangjin': {
        # 势力: (相性, 身份关键词) —— 身份关键词命中即归该势力（用于共享相性细分）
        0: ([31], None),
        1: ([93], None),
        2: ([94], None),
        3: ([91], None),
        4: ([30], ['前凉']),
    },
    'nanbeichao': {
        0: ([100], None),
        1: ([97], None),
        2: ([96], ['北凉']),
        3: ([96], ['夏国', '夏']),
        4: ([96], ['北燕']),
    },
    'suitang': {
        0: ([42], None),
        1: ([41], ['郑国']),
        2: ([41], ['河北义军', '窦建德']),
        3: ([41], ['瓦岗']),
        4: ([41], ['西秦']),
        5: ([41], ['梁国']),
        6: ([41], ['定杨']),
        7: ([40], None),
    },
    'wudai': {
        # 朱温=后梁(相性44 君主 + 相性60 后梁)；李克用=后唐(相性44 君主 + 相性61 后唐)
        0: ([44, 60], ['后梁', '朱温', '宣武']),
        1: ([44, 61], ['后唐', '李克用', '沙陀']),
        2: ([65], ['吴']),
        3: ([65], ['吴越']),
        4: ([70], None),
        5: ([72], None),
        6: ([68], None),
        7: ([69], None),
    },
    'song': {
        0: ([80], None),
        1: ([82], None),
        2: ([66], None),
        3: ([65], ['吴越']),
        4: ([71], None),
        5: ([69], None),
        6: ([74], None),
        7: ([73], None),
    },
    'yuanming': {
        0: ([110], ['元']),  # 元朝（含镇压将领）
        1: ([110], ['刘福通', '韩山童']),
        2: ([110], ['徐寿辉', '陈友谅', '明玉珍']),
        3: ([110], ['张士诚']),
        4: ([110], ['郭子兴']),
        5: ([110], ['方国珍']),
    },
    'qing': {
        0: ([120], None),
        1: ([111], ['李自成', '大顺', '闯']),
        2: ([111], ['张献忠', '大西']),
        3: ([111], None),  # 南明忠臣（郑成功、史可法等）
    },
}


def classify(force_rules, xiang, docinfo, actor_id, name):
    """把 actor 归类到某个势力（返回 force_id 或 None）。

    规则：先看相性是否命中某势力；若多个势力共享相性，则用身份关键词细分。
    """
    x = xiang.get(actor_id)
    info = docinfo.get(name, {})
    ident = info.get('身份', '')
    candidates = []
    for fid, (xs, kws) in force_rules.items():
        if x is not None and x in xs:
            candidates.append(fid)
    if len(candidates) == 1:
        return candidates[0]
    # 多个候选（共享相性），用身份关键词细分
    for fid in candidates:
        _, kws = force_rules[fid]
        if kws:
            for kw in kws:
                if kw in ident:
                    return fid
    # 仍无法区分：若身份为空或没有专属关键词，交给身份直接匹配
    for fid, (xs, kws) in force_rules.items():
        if not kws:
            continue
        for kw in kws:
            if kw in ident:
                return fid
    if len(candidates) == 1:
        return candidates[0]
    return None


def main():
    dry = '--dry-run' in sys.argv
    docinfo = load_doc_identity()
    xiang = load_xiang()
    base_actors = json.load(open(os.path.join(BASE, 'actors.json'), encoding='utf-8'))
    id2name = {a['ID']: a['姓名'] for a in base_actors}

    for d in DRAMAS:
        dpath = os.path.join(BASE, 'drama', d)
        actors = json.load(open(os.path.join(dpath, 'actors.json'), encoding='utf-8'))
        citys = json.load(open(os.path.join(dpath, 'citys.json'), encoding='utf-8'))
        vstates = json.load(open(os.path.join(dpath, 'vstates.json'), encoding='utf-8'))
        amap = {a['ID']: a for a in actors}
        cmap = {c['ID']: c for c in citys}

        # 势力 -> 君主、继承人（已出仕者）
        force_lord = {}
        force_heirs = {}
        for vs in vstates:
            if vs.get('状态') == '灭亡':
                continue
            force_lord[vs['ID']] = vs['君主']
            force_heirs[vs['ID']] = [int(h) for h in vs.get('继承人', []) if int(h) >= 0]

        # 首都 = 君主当前所在城（扫描武将列表）。若该城归属写错，先纠正归属。
        force_capital = {}
        for fid, lord in force_lord.items():
            cap = None
            for c in citys:
                if lord in c.get('武将', []):
                    cap = c['ID']
                    break
            if cap is None:
                cap = cmap[vstates[fid].get('目标城池', 0)]['ID'] if fid < len(vstates) else None
            force_capital[fid] = cap
            # 首都归属必须等于本势力，否则 fix_vstate_status 会把势力判灭亡
            if cap is not None and cmap[cap]['归属'] != fid:
                cmap[cap]['归属'] = fid

        # 当前每个势力的城（归属 == 势力，纠正后）
        force_cities = {}
        for c in citys:
            fid = c['归属']
            if fid >= 0 and fid in force_lord:
                force_cities.setdefault(fid, []).append(c['ID'])

        rules = DRAMA_RULES[d]

        # 君主 + 继承人的硬归属（vstates 里已明确，最可靠）
        heir_to_force = {}
        for fid in force_lord:
            heir_to_force[force_lord[fid]] = fid
            for h in force_heirs[fid]:
                heir_to_force[h] = fid

        # 每个势力的武将池：君主/继承人硬归属 > 出仕者按城归属 > 相性/身份归类
        force_pool = {fid: [] for fid in force_lord}
        for a in actors:
            if a.get('状态') == '死亡':
                continue
            if a['ID'] in heir_to_force:
                fid = heir_to_force[a['ID']]
            else:
                fid = classify(rules, xiang, docinfo, a['ID'], a['姓名'])
                if a.get('状态') == '出仕':
                    # 出仕武将以所在城归属为准（覆盖相性，兼容手工安放的跨相性武将）
                    for c in citys:
                        if a['ID'] in c.get('武将', []):
                            fid = c['归属']
                            break
            if fid is not None and fid in force_pool:
                force_pool[fid].append(a['ID'])

        # 排序：君主第一，继承人其次，其余按 ID
        def key_of(fid, aid):
            if aid == force_lord[fid]:
                return (0, 0)
            if aid in force_heirs[fid]:
                return (1, force_heirs[fid].index(aid))
            return (2, aid)

        report = {}
        new_city_actors = {}  # city_id -> [actor ids]
        for fid in force_lord:
            pool = sorted(set(force_pool[fid]), key=lambda a: key_of(fid, a))
            cities = force_cities.get(fid, [])
            cap = force_capital[fid]
            # 首都放君主；其余城市逐城放 1 名太守；多余武将回首都
            ordered_cities = [cap] + [cid for cid in cities if cid != cap] if cap is not None else cities
            assign = {}
            for i, aid in enumerate(pool):
                if i < len(ordered_cities):
                    assign.setdefault(ordered_cities[i], []).append(aid)
                else:
                    # 武将多于城池：多余者放回首都
                    assign.setdefault(cap, []).append(aid)
            kept = len(assign)
            dropped = len(cities) - kept
            report[fid] = (len(cities), kept, dropped)
            for cid, aids in assign.items():
                new_city_actors[cid] = aids

        print('==== %s ====' % d)
        for fid in sorted(force_lord):
            lord_name = amap[force_lord[fid]]['姓名']
            total, kept, dropped = report[fid]
            flag = '   ← 武将不足，缩城%d' % dropped if dropped else ''
            print('  势力%d %s：城%d → 保留%d（%s）%s' % (fid, lord_name, total, kept, '满' if dropped == 0 else '减', flag))

        if dry:
            continue

        # 落盘：更新 citys.json 武将列表与归属
        for c in citys:
            cid = c['ID']
            if cid in new_city_actors:
                c['武将'] = new_city_actors[cid]
            else:
                c['武将'] = []
                if c['归属'] >= 0:
                    c['归属'] = -1

        # 更新 actors.json：在野→出仕、兵力
        promoted = set()
        for cid, aids in new_city_actors.items():
            for aid in aids:
                promoted.add(aid)
        for a in actors:
            if a['ID'] in promoted:
                a['状态'] = '出仕'
                a['兵力'] = SOLDIERS
            elif a.get('状态') == '出仕':
                # 已是出仕但没被安排（不应发生），仍补兵力
                a['兵力'] = SOLDIERS

        # 更新 citys_unoffice.json：移除已出仕者
        cu = json.load(open(os.path.join(dpath, 'citys_unoffice.json'), encoding='utf-8'))
        cu = [r for r in cu if int(r['武将']) not in promoted]

        if not dry:
            # 保持与原始文件一致的格式：citys.json 用 tab 缩进，actors/unoffice 用紧凑单行
            json.dump(citys, open(os.path.join(dpath, 'citys.json'), 'w', encoding='utf-8'),
                      ensure_ascii=False, indent='\t')
            json.dump(actors, open(os.path.join(dpath, 'actors.json'), 'w', encoding='utf-8'),
                      ensure_ascii=False, separators=(',', ': '))
            json.dump(cu, open(os.path.join(dpath, 'citys_unoffice.json'), 'w', encoding='utf-8'),
                      ensure_ascii=False, separators=(',', ': '))
            print('  [已写盘] citys/actors/citys_unoffice')


if __name__ == '__main__':
    main()
