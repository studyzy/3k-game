#!/usr/bin/env python3
"""根据 docs/actors_expansion/*.md 把扩展人物的（城池, 登场年, 武将）维护进
bwdl/packed/data/citys_unoffice.json（仅顶层文件，不改剧本目录）。

规则：
- 「城市」=? ：按所属朝代（01-07 取整表众数，08 从「身份」列提取朝代取众数城池）分配。
- 「出场(约)」=? ：卒年-60 估算；卒年也不详则跳过（不写条目）。
- 同名多 ID：按 md 卒年(约) 与主表「大限」匹配消歧；未被认领的候选留给无卒年行。
"""
import json, os, re, collections

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, 'docs', 'actors_expansion')
DATA = os.path.join(ROOT, 'bwdl', 'packed', 'data')
FILES = ['01_两晋十六国', '02_南北朝', '03_隋唐', '04_五代十国',
         '05_两宋辽金西夏', '06_元明', '07_清', '08_历代状元']
# 出场地有线索但城市列缺失的人工映射
BIRTH_CITY_FIX = {'莒县': '下邳'}
# 08 身份列中的朝代关键词（长词在前）
DYNASTIES = ['太平天国', '大顺', '大西', '南明', '后梁', '后唐', '后晋', '后汉', '后周',
             '吴越', '南唐', '前蜀', '后蜀', '荆南', '北汉', '杨吴', '西夏',
             '辽', '金', '宋', '元', '明', '清', '唐', '隋', '闽', '南汉', '楚', '吴', '大理']


def parse_year(s):
    m = re.fullmatch(r'约?(\d{1,4})', s.strip())
    return int(m.group(1)) if m else None


def load_md_rows():
    rows = []
    for fn in FILES:
        with open(os.path.join(DOCS, fn + '.md')) as f:
            for line in f:
                if not line.startswith('|') or '--' in line:
                    continue
                c = [x.strip() for x in line.strip().strip('|').split('|')]
                if len(c) < 16 or c[0] == '姓名':
                    continue
                rows.append({'file': fn, 'name': c[0], 'zi': c[1], 'year_raw': c[2],
                             'death_raw': c[3], 'birth': c[5], 'city': c[6],
                             'identity': c[4]})
    return rows


def main():
    rows = load_md_rows()
    actors = json.load(open(os.path.join(DATA, 'actors.json')))
    byid = {a['ID']: a for a in actors}
    citys = json.load(open(os.path.join(DATA, 'citys.json')))
    city_id = {x['城池名']: x['ID'] for x in citys}
    existing = json.load(open(os.path.join(DATA, 'citys_unoffice.json')))
    have = {e['武将'] for e in existing}

    # 众数城池：01-07 整表；08 按朝代（身份列含朝代关键词）
    def mode_city(sub):
        cnt = collections.Counter(r['city'] for r in sub if r['city'] in city_id)
        return cnt.most_common(1)[0][0] if cnt else None
    file_mode = {fn: mode_city([r for r in rows if r['file'] == fn]) for fn in FILES[:-1]}
    sub08 = [r for r in rows if r['file'] == '08_历代状元']
    for r in sub08:
        r['dyn'] = next((d for d in DYNASTIES if d in r['identity']), None)
    dyn_mode = {}
    for d in set(r['dyn'] for r in sub08 if r['dyn']):
        m = mode_city([r for r in sub08 if r['dyn'] == d])
        if m:
            dyn_mode[d] = m

    # 姓名 → 候选 ID
    byname = collections.defaultdict(list)
    for a in actors:
        byname[a['姓名']].append(a['ID'])

    parsed = []
    problems = []
    for r in rows:
        name = r['name'].split('#', 1)[0]
        cands = byname.get(name, [])
        if not cands:
            problems.append(f"未匹配: {r['file'][:2]} {r['name']}")
            continue
        parsed.append({'row': r, 'cands': cands})

    def death_of(i):
        try:
            return int(byid[i].get('大限'))
        except (TypeError, ValueError):
            return None

    def disambiguate(p):
        """返回唯一命中的候选 ID，否则 None。"""
        cands = p['cands']
        if len(cands) == 1:
            return cands[0]
        # 08 状元表行：科举始于隋唐，状元必在扩展段，排除混入的三国段候选
        if p['row']['file'] == '08_历代状元':
            seg = [i for i in cands if i >= 1661]
            if seg and any(i < 561 for i in cands):
                cands = seg
                if len(cands) == 1:
                    return cands[0]
        # md 字段与主表「字」精确匹配
        zi = p['row'].get('zi', '')
        if zi and zi != '?':
            hits = [i for i in cands if byid[i].get('字') == zi]
            if len(hits) == 1:
                return hits[0]
        # 出场年必须 ≤ 卒年（大限 9999=虚构不死，不参与）
        year = parse_year(p['row']['year_raw'])
        if year is not None:
            hits = [i for i in cands if death_of(i) not in (None, 9999) and year <= death_of(i)]
            if len(hits) == 1:
                return hits[0]
        # md 卒年 == 大限
        death = parse_year(p['row']['death_raw'])
        hits = [i for i in cands if death is not None and death_of(i) == death]
        if len(hits) == 1:
            return hits[0]
        return None

    # 第一轮：逐行消歧
    resolve = {}   # id(p) -> 武将ID
    unclaimed = {}
    claimed = set()
    for p in parsed:
        hit = disambiguate(p)
        if hit is not None:
            resolve[id(p)] = hit
            claimed.add(hit)
        else:
            unclaimed[id(p)] = p
    # 第二轮：仍未消歧的行认领剩余候选（排除已被认领的）
    for pid, p in list(unclaimed.items()):
        left = [i for i in p['cands'] if i not in claimed]
        if len(left) == 1:
            resolve[pid] = left[0]
            claimed.add(left[0])
            del unclaimed[pid]
    for pid, p in unclaimed.items():
        problems.append(f"无法消歧: {p['row']['file'][:2]} {p['row']['name']} 候选{p['cands']}")

    # 同 ID 多行：朝代文件（非08）优先，同优先级取先出现
    best = {}
    for p in parsed:
        if id(p) not in resolve:
            continue
        aid = resolve[id(p)]
        r = p['row']
        rank = 0 if r['file'] != '08_历代状元' else 1
        if aid not in best or rank < best[aid][0]:
            best[aid] = (rank, r)

    # 组装条目
    entries = list(existing)
    skip_year, skip_city, written = [], [], 0
    for aid, (_, r) in sorted(best.items()):
        if aid in have:
            continue
        year = parse_year(r['year_raw'])
        if year is None:
            death = parse_year(r['death_raw'])
            if death is not None:
                year = death - 60
            else:
                skip_year.append(f"{r['file'][:2]} {r['name']}(ID{aid})")
                continue
        city = r['city']
        if city not in city_id:
            manual = next((v for k, v in BIRTH_CITY_FIX.items() if k in r['birth']), None)
            if manual:
                city = manual
            elif r['file'] == '08_历代状元' and r['dyn'] and r['dyn'] in dyn_mode:
                city = dyn_mode[r['dyn']]
            else:
                city = file_mode.get(r['file'])
            if city not in city_id:
                skip_city.append(f"{r['file'][:2]} {r['name']}(ID{aid})")
                continue
        entries.append({'城池': city_id[city], '登场年': year, '武将': aid})
        written += 1

    entries.sort(key=lambda e: (e['城池'], e['登场年'], e['武将']))
    with open(os.path.join(DATA, 'citys_unoffice.json'), 'w') as f:
        json.dump(entries, f, ensure_ascii=False, indent=2)
        f.write('\n')

    print(f"md行: {len(rows)}  匹配ID: {len(best)}  新写条目: {written}  总条目: {len(entries)}")
    print(f"朝代众数城(01-07): {file_mode}")
    print(f"朝代众数城(08): {dyn_mode}")
    for label, lst in (('跳过-年份不详', skip_year), ('跳过-城池无法确定', skip_city), ('问题', problems)):
        if lst:
            print(f"{label} {len(lst)}:")
            for s in lst:
                print('  ', s)


if __name__ == '__main__':
    main()
