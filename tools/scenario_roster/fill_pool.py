#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""为 7 个剧本筛选「可用于补将」的在野武将候选。

规则（与 docs/plans/2026-08-28-drama-roster-design.md 口径一致）：
1. 状态 = 在野
2. 大限 >= 开局年（开局在世）
3. 防穿越：出场 缺失 或 出场 <= 开局+20（排除开局未成年/后世人物）
4. 仅史实：排除身份含 水浒/梁山/小说/金瓶梅/西游记/封神/演义/虚构/说岳/杨家将 等虚构标记者

输出: tools/scenario_roster/context/<剧本>_candidates.json
  候选按「有 md 城市(可定位)」与「无 md 城市(需靠历史知识)」分组，供子 Agent 使用。
用法: python3 tools/scenario_roster/fill_pool.py
"""
import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
CTX = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'context')

SCENARIOS = {
    'liangjin': 386, 'nanbeichao': 420, 'suitang': 618, 'wudai': 907,
    'song': 1208, 'yuanming': 1360, 'qing': 1645,
}

FICT_MARK = ['水浒', '梁山', '小说', '金瓶梅', '西游记', '封神', '演义',
             '虚构', '说岳', '杨家将', '红拂', '评书', '传说', '话本']

# 已知演义/小说/传奇虚构人名（含隋唐演义、说岳、杨家将、水浒、施公案、太平天国传说等）
FICT_NAMES = {
    '伍云召', '伍天锡', '何元庆', '何路通', '佘太君', '公孙胜', '关小西', '关胜', '关铃',
    '刘唐', '十三妹', '卢俊义', '史进', '吴用', '呼延灼', '孙二娘', '孟绝海', '孟良',
    '宇文成都', '尚师徒', '张顺', '戴宗', '扈三娘', '新文礼', '时迁', '晁盖', '曹宁',
    '李俊', '李元霸', '李逵', '杨宗保', '杨志', '杨排风', '杨林', '杨香武', '林冲',
    '柴进', '樊梨花', '武松', '洪宣娇', '潘金莲', '焦赞', '燕青', '石秀', '秦明',
    '秦用', '穆桂英', '红拂女', '罗成', '花木兰', '花荣', '裴元庆', '西门庆', '计全',
    '谢映登', '邓天王', '阮小七', '阮小二', '阮小五', '陆文龙', '雄阔海', '顾大嫂',
    '马玉龙', '高宠', '魏文通', '鲁智深', '黄三太', '黄天霸', '陈真', '高思继',
    '杨五郎', '杨六郎', '杨七郎', '自定义',
}


def is_fictional(ident, name):
    return any(k in (ident or '') for k in FICT_MARK) or name in FICT_NAMES


def main():
    for scen, start in SCENARIOS.items():
        with open(os.path.join(CTX, scen + '.json'), encoding='utf-8') as f:
            ctx = json.load(f)
        pool = ctx['pool']
        start = ctx['start_year']
        limit = start + 20

        cands = []
        skipped = []
        for e in pool:
            if e['状态'] != '在野':
                continue
            dx = e['大限']
            if dx is None or dx < start:
                skipped.append((e['ID'], e['姓名'], '开局已死/大限'))
                continue
            cc = e['出场']
            if isinstance(cc, int) and cc > limit:
                skipped.append((e['ID'], e['姓名'], f'穿越出场{cc}>{limit}'))
                continue
            if is_fictional(e.get('身份', ''), e['姓名']):
                skipped.append((e['ID'], e['姓名'], '虚构:' + e.get('身份', '') + e['姓名']))
                continue
            cands.append(e)

        # 按是否有 md 城市分组
        with_city = [e for e in cands if e.get('md城市')]
        no_city = [e for e in cands if not e.get('md城市')]
        for e in with_city:
            e['分组'] = 'md城市可定位'
        for e in no_city:
            e['分组'] = '需历史知识'

        out = {
            'scenario': scen, 'start_year': start, 'candidate_total': len(cands),
            'with_city': with_city, 'no_city': no_city,
            'skipped_examples': skipped[:20], 'skipped_total': len(skipped),
        }
        op = os.path.join(CTX, scen + '_candidates.json')
        with open(op, 'w', encoding='utf-8') as f:
            json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
        print(f"{scen}: 可用候选 {len(cands)} (md城市可定位 {len(with_city)} / 需历史知识 {len(no_city)}) "
              f"排除 {len(skipped)} -> {os.path.relpath(op, ROOT)}")


if __name__ == '__main__':
    main()
