#!/usr/bin/env python3
"""为扩展武将（ID>=561）批量填充技能 LV1~LV8。

参考前 561 名武将的填写规律：
- 主技能槽为 LV1/LV3/LV5/LV7（奇数槽），偶数槽 LV2/LV4/LV6/LV8 基本留空；
- 每个槽位以「锁定技」为主、「主动技」为辅，LV7 可放「诱发技」/「限定技」；
- 标准配置 4 个技能，顶级人物（上档）多 1 个技能（补 LV2）。

分档：
- 文臣（政>=武 或 政-武>=20）：按「知」主、「政」辅分上/中/下三档。
- 武将（其余）：按「武」主、「统」辅分上/中/下三档。
- 女性按武/政归边后同规则。

分配：用 ID 作为随机种子，从对应技能池无放回抽取，保证同一人技能不重复、可复现。

用法：
  python3 fill_skills.py --dry-run       # 只统计，不写文件
  python3 fill_skills.py                 # 正式写回 actor_skills.json
"""
import argparse
import json
import os
import random
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "bwdl", "packed", "data")
ACTORS = os.path.join(ROOT, "actors.json")
SKILLS = os.path.join(ROOT, "actor_skills.json")
SKILL_DEF = os.path.join(ROOT, "skill_system", "skill.json")

# 技能池：只放「干净」通用技能（无专属、无性别限制、无君主/仙/道术等标签）。
# 排除地域限定（收羌/收越/纳蛮）、负面惩罚、装备依赖（枪神/剑舞/狂斧/重锤/虎魄/龙魂等）。
WEN_LOCK = [
    "明政", "水利", "善政", "事半", "功倍", "屯田", "勤政", "勤业", "勤耕", "勤户",
    "安民", "政通", "人和", "爱民", "匡政", "辅市", "康民", "忠纯", "智辩", "说盟",
    "正礼", "衡法", "解仇", "谍网", "木牛", "流马", "崇佛", "柔克",
]
WEN_ACTIVE = [
    "治典", "奇策", "正奇", "谋局", "引计", "散谣", "论势", "直言", "诚治", "苦谏",
    "联商", "沉计", "铁索", "伏策", "励商", "定品", "推心", "藏卷", "仿制", "助势",
    "陈势", "济乡", "急救", "智救", "完复",
]
WEN_INDUCE = [
    "看破", "复策", "思慎", "计袭", "青囊", "智援", "智破", "共患", "远虑", "胁停",
    "统摄", "忠谏", "避祸", "深谋", "贵胄", "警叛", "避凶", "无咎",
]
WEN_LIMIT = [
    "文涌", "镇围", "怀仁", "设援", "钧发", "求计", "让贤", "承诏", "断归", "穷守",
    "知机", "仿笔",
]

WU_LOCK = [
    "马术", "先锋", "骁袭", "旋风", "耀武", "卫士", "虎啸", "上将", "寻嫉", "猛探",
    "破势", "冲阵", "神武", "射戟", "烈弓", "漫射", "破围", "龙战", "强袭", "拔矢",
    "长兵", "重击", "马槊", "巨力", "无当", "精骑", "甲骑", "毒矢", "硬弩", "义从",
    "锐步", "怒剑", "虎骑", "豹骑", "戟士", "铁骑", "暴弓", "挺刺", "游弓", "山骑",
    "勇突", "百鸟", "朝凤", "解烦", "枪术", "弓骑", "城槌", "神勇", "远射", "催阵",
    "并骑", "大斩", "回矢", "疾驰", "怒斩", "招架", "无前",
]
WU_ACTIVE = [
    "龙胆", "骁勇", "劫营", "暗杀", "平讨", "血卫", "讨难", "咆哮", "扬威", "抬棺",
    "骑突", "长啸", "巨喝", "广射",
]
WU_INDUCE = [
    "武守", "恃武", "援护", "彰勇", "天义", "追袭", "援主", "换帻", "截杀", "救主",
    "挺援", "遥援",
]
WU_LIMIT = [
    "临征", "连杀", "千追", "趫猛", "震塞", "雄异", "雄骑", "密信", "衰劫", "急功",
]

BAD_TAGS = {"君主", "仙", "道术", "仙术", "秘术", "神策", "转换", "规则"}


def kind_of(a):
    if a.get("性别") == "女":
        return "female"
    return "official" if is_official(a) else "warrior"


def is_official(a):
    """判断走文臣还是武将技能池（女性也按武/政归边）。"""
    w, p = a.get("武", 0), a.get("政", 0)
    if p - w >= 20:
        return True
    if w - p >= 20:
        return False
    return p >= w


def tier_of(a):
    if is_official(a):
        zhi, zheng = a.get("知", 0), a.get("政", 0)
        if zhi >= 95 or zheng >= 88:
            return "high"
        if zhi >= 90 or zheng >= 70:
            return "mid"
        return "low"
    # warrior
    wu, tong = a.get("武", 0), a.get("统", 0)
    if wu >= 95 or tong >= 88:
        return "high"
    if wu >= 90 or tong >= 70:
        return "mid"
    return "low"


def clean_pool(pool, skill_def):
    """过滤出「干净」且真实存在的技能名，保持顺序。"""
    out = []
    for name in pool:
        v = skill_def.get(name)
        if v is None:
            print(f"  [警告] 技能不存在: {name}", file=sys.stderr)
            continue
        if v.get("专属") or v.get("性别"):
            print(f"  [警告] 技能有专属/性别限制: {name}", file=sys.stderr)
            continue
        if set(v.get("标签", [])) & BAD_TAGS:
            print(f"  [警告] 技能含特殊标签: {name}", file=sys.stderr)
            continue
        out.append(name)
    return out


def fill_one(a, tier, pools, rng):
    """返回 {'LV1': ..., ...} 字典。"""
    skills = {}
    used = set()

    def pick(pool):
        # 无放回随机抽取，避免同人重复
        avail = [x for x in pool if x not in used]
        if not avail:
            return ""
        x = rng.choice(avail)
        used.add(x)
        return x

    if is_official(a):
        lock, active, induce, limit = pools["wen"]
    else:
        lock, active, induce, limit = pools["wu"]

    if tier == "high":
        # 5 技能：LV1锁 LV2锁 LV3主 LV5诱 LV7限
        skills["LV1"] = pick(lock)
        skills["LV2"] = pick(lock)
        skills["LV3"] = pick(active)
        skills["LV5"] = pick(induce)
        skills["LV7"] = pick(limit)
    elif tier == "mid":
        # 4 技能：LV1锁 LV3主 LV5诱 LV7诱/锁
        skills["LV1"] = pick(lock)
        skills["LV3"] = pick(active)
        skills["LV5"] = pick(induce)
        skills["LV7"] = pick(rng.choice([induce, lock]))
    else:
        # 4 技能：LV1锁 LV3锁/主 LV5主 LV7诱/锁
        skills["LV1"] = pick(lock)
        skills["LV3"] = pick(rng.choice([lock, active]))
        skills["LV5"] = pick(active)
        skills["LV7"] = pick(rng.choice([induce, lock]))

    # 补齐空槽
    for lv in ["LV1", "LV2", "LV3", "LV4", "LV5", "LV6", "LV7", "LV8"]:
        skills.setdefault(lv, "")
    return skills


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="只统计不写文件")
    ap.add_argument("--start", type=int, default=561)
    args = ap.parse_args()

    actors = json.load(open(ACTORS, encoding="utf-8"))
    skill_data = json.load(open(SKILLS, encoding="utf-8"))
    skill_def = json.load(open(SKILL_DEF, encoding="utf-8"))

    # 构建技能池
    pools = {
        "wen": (
            clean_pool(WEN_LOCK, skill_def),
            clean_pool(WEN_ACTIVE, skill_def),
            clean_pool(WEN_INDUCE, skill_def),
            clean_pool(WEN_LIMIT, skill_def),
        ),
        "wu": (
            clean_pool(WU_LOCK, skill_def),
            clean_pool(WU_ACTIVE, skill_def),
            clean_pool(WU_INDUCE, skill_def),
            clean_pool(WU_LIMIT, skill_def),
        ),
    }
    print("文臣池 锁/主/诱/限:", [len(x) for x in pools["wen"]])
    print("武将池 锁/主/诱/限:", [len(x) for x in pools["wu"]])

    # 索引技能表
    sk_by_id = {s["ID"]: s for s in skill_data}
    amap = {a["ID"]: a for a in actors}

    stat = {"high": 0, "mid": 0, "low": 0}
    kind_stat = {}
    changed = 0

    for a in actors:
        fid = a["ID"]
        if fid < args.start:
            continue
        s = sk_by_id.get(fid)
        if s is None:
            print(f"  [警告] actor_skills.json 缺 ID {fid}", file=sys.stderr)
            continue
        # 只填「当前全空」的人，避免覆盖已填内容
        if any(s.get(lv, "") for lv in ["LV1", "LV2", "LV3", "LV4", "LV5", "LV6", "LV7", "LV8"]):
            continue
        kind = kind_of(a)
        tier = tier_of(a)
        stat[tier] += 1
        kind_stat[kind] = kind_stat.get(kind, 0) + 1
        rng = random.Random(fid)
        new_skills = fill_one(a, tier, pools, rng)
        for lv, v in new_skills.items():
            s[lv] = v
        changed += 1

    print(f"待填且全空人数: {changed}")
    print("分档统计:", stat)
    print("分类统计:", kind_stat)

    if args.dry_run:
        print("[dry-run] 未写文件")
        return 0

    with open(SKILLS, "w", encoding="utf-8") as f:
        json.dump(skill_data, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"已写回 {SKILLS}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
