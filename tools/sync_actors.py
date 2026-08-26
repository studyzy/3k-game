#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""将 docs/actors_expansion/*.md 的人物同步到 bwdl/packed/data/actors.json。"""
import json, re, os

BASE = os.path.join(os.path.dirname(__file__), '..', 'docs', 'actors_expansion')
OUT = os.path.join(os.path.dirname(__file__), '..', 'bwdl', 'packed', 'data', 'actors.json')

FILES = ['01_两晋十六国.md', '02_南北朝.md', '03_隋唐.md', '04_五代十国.md',
         '05_两宋辽金西夏.md', '06_元明.md', '07_清.md']

# 复姓 / 少数族复姓（按长度降序匹配前缀）
COMPOUND = ('司马 诸葛 上官 欧阳 夏侯 长孙 尉迟 独孤 慕容 拓跋 宇文 呼延 公孙 皇甫 '
            '司徒 令狐 赫连 沮渠 秃发 乞伏 尔朱 侯莫陈 斛律 淳于 太史 东方 万俟 闻人 '
            '鲜于 闾丘 第五 钟离 濮阳 綦毋 完颜 耶律 仆固 纥石烈 徒单 仆散 野利 嵬名 '
            '赤盏 仁多 破六韩 纥豆陵 贺兰 豆卢 斛斯 叱列 贺拔 术虎 南宫 东门 西门 南门 '
            '北宫 羊舌 微生 公西 公冶 申屠 澹台 宗政 太叔 端木 巫马 漆雕 乐正 百里 东郭 '
            '梁丘 左丘 轩辕 单于 段干 司空 司寇 亓官 夹谷 谷梁 壤驷 子车 颛孙').split()

# 蒙古孛儿只斤氏（元君主及成吉思汗子孙）
BORJIGIN = {'铁木真', '窝阔台', '贵由', '蒙哥', '忽必烈', '铁穆耳', '海山', '爱育黎拔力八达',
            '硕德八剌', '也孙铁木儿', '图帖睦尔', '妥欢帖睦尔', '术赤', '察合台', '拖雷',
            '拔都', '旭烈兀', '海都', '阿里不哥'}

# 满族爱新觉罗氏（宗室）
AISIN_GIORO = {'努尔哈赤', '皇太极', '福临', '代善', '多尔衮', '多铎', '阿济格', '豪格',
               '岳托', '济尔哈朗', '莽古尔泰', '玄烨', '胤禛', '弘历', '颙琰', '旻宁',
               '奕詝', '载淳', '载湉', '溥仪', '奕訢', '肃顺'}

# 无明确汉姓（蒙古功臣，氏族生僻），姓留空
NO_SURNAME = {'木华黎', '博尔术', '博尔忽', '赤老温', '者勒蔑', '速不台', '哲别', '忽必来',
              '阿术', '伯颜', '察罕帖木儿', '扩廓帖木儿', '孛罗帖木儿'}

# 个别手动指定姓
SURNAME_OVERRIDE = {'慈禧太后': '叶赫那拉', '年羹尧': '年', '李永芳': '李', '佟养性': '佟',
                    '韩德让': '韩', '张元': '张', '梁乙埋': '梁', '刘彦宗': '刘', '韩企先': '韩'}

WOMEN = {'荀灌', '冼夫人', '花木兰', '武则天', '平阳公主', '红拂女', '樊梨花', '花蕊夫人',
         '梁红玉', '李清照', '萧绰', '佘太君', '穆桂英', '杨排风', '扈三娘', '孙二娘',
         '顾大嫂', '潘金莲', '秦良玉', '慈禧太后', '洪宣娇', '十三妹'}


def clean_name(name):
    return name.split('#')[0]


def surname(name, identity):
    n = clean_name(name).strip()
    if n in SURNAME_OVERRIDE:
        return SURNAME_OVERRIDE[n]
    if n in BORJIGIN:
        return '孛儿只斤'
    if n in AISIN_GIORO:
        return '爱新觉罗'
    if n in NO_SURNAME:
        return ''
    # 满族“X氏”标记
    m = re.search(r'([\u4e00-\u9fa5]{2,6})氏', identity)
    if m:
        return m.group(1)
    for c in COMPOUND:
        if n.startswith(c):
            return c
    return n[0] if n else ''


def parse_year(s):
    s = (s or '').strip()
    if not s or s == '?':
        return None
    return int(re.sub(r'约', '', s))


def main():
    with open(OUT, encoding='utf-8') as f:
        actors = json.load(f)
    nid = max(a['ID'] for a in actors) + 1
    added = []
    for fn in FILES:
        path = os.path.join(BASE, fn)
        with open(path, encoding='utf-8') as f:
            lines = f.read().splitlines()
        for ln in lines:
            if not ln.startswith('|') or '姓名' in ln or ln.startswith('|---'):
                continue
            cols = [c.strip() for c in ln.split('|')]
            # cols: ['', 姓名, 字, 出场, 卒年, 身份, 出处, 体, 武, 知, 忠, 德, 政, 统, 胆, 军种, '']
            if len(cols) != 17:
                print('SKIP(列数!=15):', fn, ln[:40])
                continue
            name, zi, chuchang, zunian, identity = cols[1], cols[2], cols[3], cols[4], cols[5]
            ti, wu, zhi, zhong, de, zheng, tong, dan = (int(cols[i]) for i in range(7, 15))
            junzhong = cols[15]
            n = clean_name(name)
            xing = surname(name, identity)
            gender = '女' if n in WOMEN else '男'
            zi = '' if zi == '?' else zi
            zunian_y = parse_year(zunian)
            chuchang_y = parse_year(chuchang)
            if zunian_y is not None:
                daxian = zunian_y
            elif chuchang_y is not None:
                daxian = chuchang_y + 40
            else:
                daxian = 9999
            score = max(tong, zheng, zhi, wu)
            if score >= 93:
                level, exp = 4, 70
            elif score >= 85:
                level, exp = 3, 40
            elif score >= 65:
                level, exp = 2, 20
            else:
                level, exp = 1, 0
            actors.append({
                'ID': nid, '姓名': n, '姓': xing, '字': zi, '性别': gender, '军种': junzhong,
                '体': ti, '武': wu, '知': zhi, '忠': zhong, '德': de, '政': zheng,
                '统': tong, '胆': dan, '武器': 0, '防具': 0, '道具': 0, '坐骑': 0,
                '大限': daxian, '流放地': 0, '兵力': 0, '状态': '在野', '等级': level, '经验': exp,
            })
            nid += 1
            added.append(n)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(json.dumps(actors, ensure_ascii=False, indent=2) + '\n')
    print('新增人物数:', len(added))
    print('总人数:', len(actors))
    print('重复姓名(新增内部):', [x for x in set(added) if added.count(x) > 1])


if __name__ == '__main__':
    main()
