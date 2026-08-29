#!/usr/bin/env python3
"""终检：写入后校验 7 个剧本的城池-武将一致性。"""
import json, os, sys
from collections import defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, 'bwdl/packed/data/drama')
SCENS = ['liangjin', 'nanbeichao', 'suitang', 'wudai', 'song', 'yuanming', 'qing']


def main(scen):
    citys = json.load(open(os.path.join(DATA, scen, 'citys.json'), encoding='utf-8'))
    actors = json.load(open(os.path.join(DATA, scen, 'actors.json'), encoding='utf-8'))
    vs = json.load(open(os.path.join(DATA, scen, 'vstates.json'), encoding='utf-8'))
    act = {a['ID']: a for a in actors}
    cby = {c['ID']: c for c in citys}

    owner = {}   # aid -> city id
    for c in citys:
        for a in c.get('武将', []):
            owner[a] = c['ID']

    err = []
    empty = []
    ghost = []   # 归属-1 却有武将
    for c in citys:
        n = len(c.get('武将', []))
        if c['归属'] >= 0 and n == 0:
            empty.append((c['ID'], c['城池名'], c['归属']))
        if c['归属'] < 0 and n > 0:
            ghost.append((c['ID'], c['城池名'], n))
        if n > 17:
            err.append('city%d %s 超17人(%d)' % (c['ID'], c['城池名'], n))
        for a in c.get('武将', []):
            if a not in act:
                err.append('city%d 含不存在武将 %d' % (c['ID'], a))
            elif act[a].get('状态') != '出仕':
                err.append('city%d 武将 %d 状态=%s' % (c['ID'], a, act[a].get('状态')))

    # 君主在己方城
    for v in vs:
        m = v.get('君主', -1)
        if m < 0:
            continue
        cid = owner.get(m)
        if cid is None:
            err.append('势力%d 君主%d 不在任何城中' % (v['ID'], m))
        elif cby[cid]['归属'] != v['ID']:
            err.append('势力%d 君主%d 在city%d 归属%d' % (v['ID'], m, cid, cby[cid]['归属']))

    # 势力城数
    cnt = defaultdict(list)
    for c in citys:
        if c['归属'] >= 0:
            cnt[c['归属']].append(len(c.get('武将', [])))

    print('== %s' % scen)
    print('   归属>=0 空城 %d 座 %s' % (len(empty), empty if empty else ''))
    if ghost:
        print('   [warn] 无主城却有将 %s' % ghost)
    for f in sorted(cnt):
        s = cnt[f]
        print('   势力%-3d 城%-3d 将%-3d 最少%d 最多%d'
              % (f, len(s), sum(s), min(s), max(s)))
    for e in err:
        print('   [错误] %s' % e)
    return len(err), len(empty)


if __name__ == '__main__':
    tot = 0
    for s in (sys.argv[1:] or SCENS):
        e, em = main(s)
        tot += e + em
    print('\n总问题数: %d' % tot)
