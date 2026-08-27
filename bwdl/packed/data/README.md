# bwdl/packed/data 数据目录说明

本目录是《霸王的大陆》（bwdl）mod「原版」的全部游戏数据。所有数据以 JSON 格式存储，字段名多为中文，由 Godot 工程在运行时直接加载解析。

整体可划分为几大类：

| 类别 | 说明 |
| --- | --- |
| 武将/角色 | 武将属性、技能、人际关系、登场 |
| 城池/势力 | 城池、势力（vstates）及开局状态 |
| 装备/道具 | 武器、防具（套装）、饰品（书/宝）、坐骑、消耗道具 |
| 技能系统 | 技能效果、增益状态（buff）、计策 |
| 战场 | 大地图/小战场地图、动画、武将站位、NPC |
| 剧情/剧本 | 剧情关卡（story）、时代剧本（drama）、特殊事件 |
| 考据/百科 | 游戏内置的史实考据文档（research_bbcode）与索引 |
| 文字/检索 | 汉字-拼音互查、问答（QA） |
| 签名 | 数据完整性校验用的证书/密钥 |

---

## 一、顶层核心数据文件

### actors.json —— 武将主表（1661 条）

游戏中最核心的表，记录每个武将的完整静态属性。数组，每条记录字段：

| 字段 | 含义 |
| --- | --- |
| `ID` | 武将编号（全局唯一，其他表通过它引用武将） |
| `姓名` / `姓` / `字` | 姓名、姓氏、表字 |
| `性别` | 男 / 女 / 无性别 |
| `军种` | 兵种，取值如 `平`（平地）、`山`、`水`、`仙` 等 |
| `体` `武` `知` `忠` `德` `政` `统` `胆` | 属性：体力、武力、智力、忠诚、德望、政治、统率、胆略（0~99） |
| `武器` `防具` `道具` `坐骑` | 初始装备 ID（引用 equip 目录下的表） |
| `大限` | 死亡年份（游戏内纪年，如 220 表示 220 年） |
| `流放地` | 流放所在城池 ID |
| `兵力` | 初始兵力 |
| `状态` | `在野` / `出仕` / `流放` / `死亡` 等 |
| `等级` `经验` | 初始等级与经验 |
| `面`（可选） | 阴 / 阳 面，表示该武将拥有两套技能（详见 `actor_skills.json` 中带 `/` 的技能名） |

### actors_extra.json —— 武将附加属性

与 `actors.json` 按 `ID` 对应，补充主表之外的信息：

| 字段 | 含义 |
| --- | --- |
| `ID` | 武将编号 |
| `相性` | 相性值（0~150+），决定武将之间的亲疏与「特定势力武将」的加入概率 |
| `标签`（可选） | 附加标签，如 `["乐"]`，用于某些技能/机制判定 |

### actors_others.json —— 特殊单位

少量非常规「武将」，如 `ID=-10` 的「象群」（象兵单位），字段结构与 `actors.json` 相同但 `ID` 为负数，表示非人类战斗单位。

> ⚠️ 当前全工程无任何 `.gd` 代码加载此文件（死数据），改动不生效。

### actor_skills.json —— 武将技能表（1661 条）

按 `ID` 对应武将，记录每个武将 8 个等级档位的技能名（`LV1`~`LV8`）：

- 每个档位可填一个或多个技能名，多个用 `/` 分隔（对应阴/阳两面两套技能）。
- 空字符串表示该档位无技能。

技能名的具体效果见 `description/skills.json` 与 `skill_system/skill.json`。

### old_skills.json —— 旧技能名列表

一个纯字符串数组，列出全部（旧版）技能名，是技能名的总清单，可用于对照/迁移。

### actor_relation.json —— 武将人际关系

对象，含 `relations` 数组，描述武将之间的两两关系：

| 字段 | 含义 |
| --- | --- |
| `from` / `to` | 关系双方武将 ID |
| `relation` | 关系类型，如 `痛恨`、`密友`、`部将`、`妻弟`、`仇视`、`拥立`、`纳降`、`堂兄`、`族兄` 等 |

用于游戏中的对话、事件、忠诚与加入判定。

> ⚠️ 当前全工程无任何 `.gd` 代码加载此文件（死数据），改动不生效。

### actor_follower.json —— 父子登场关系

数组，记录「子将」随「父将」登场的规则：

| 字段 | 含义 |
| --- | --- |
| `父将` | 父武将 ID |
| `子将` | 子武将 ID |
| `登场年` | 子将登场年份 |

### actor_special_titles.json —— 武将特殊称呼/昵称

数组，描述武将之间的特殊称呼（用于对话称谓）及称号：

| 字段 | 含义 |
| --- | --- |
| `FROM` / `TO` | 关系双方武将 ID（相同时表示自身称号） |
| `NICK` | 相互称呼，如 `"三弟,二哥"`（前者叫后者、后者叫前者） |
| `面`（可选） | 阴 / 阳 面限定 |
| `DISS`（可选） | 蔑称，如许攸叫曹操「阿瞒」 |
| `memo` | 备注（人物名） |

### attribute_set.json —— 属性/版本配置

对象，键为 `版本名称`（当前为「原版」）。含大量全局规则，例如：

- `内政.命令书`：各「统治度」档位对应的每月命令书数量数组。
- `内政.搜索结果`：按德/政属性分档，搜索在野武将时得到的产物列表。
- `内政.势力易招武将`：各势力（键为势力 ID）容易招到的武将列表。
- 其他升级、招募、生产等全局数值规则。

### items.json —— 消耗道具

数组，仅 1 条示例（`草药`），描述消耗品：`ID`、`name`、`desc`、`effect`（如回血 `{"hp":20}`）。

### citys.json —— 城池主表（42 条）

数组，记录每座城池的开局与静态属性：

| 字段 | 含义 |
| --- | --- |
| `ID` | 城池编号 |
| `城池名` | 城名 |
| `归属` | 所属势力 ID（-1 表示无主/空城） |
| `金` `米` | 初始金钱、粮草 |
| `人口` `土地` `防灾` `统治度` `后备兵` `产业` | 内政数值 |
| `宝` | 宝物编号 |
| `集市` | 集市类型（如 `武知商`、`武医`） |
| `卖米价` / `买米价` | 米价 |
| `武将` | 城中武将 ID 列表 |
| `连接城` | 相邻城池 ID 列表 |
| `城池坐标` | 地图坐标 `{x,y}` |
| `装备店` | `{内政, 战场}` 装备店等级 |
| `旱灾` / `洪涝` | 灾害标记 |
| `行政区` / `地域` | 州与地区 |

### citys_unoffice.json —— 城池在野武将登场表

数组，记录某武将「在某城池、某年登场（在野）」的规则：`城池`、`登场年`、`武将`。用于未出仕武将按历史时间在各城出现。

### vstates.json —— 势力表（21 条）

数组，描述每个势力的静态信息：

| 字段 | 含义 |
| --- | --- |
| `ID` | 势力编号 |
| `君主` | 君主武将 ID（-1 或 `状态:"灭亡"` 表示已灭亡势力） |
| `继承人` | 继承人（武将 ID 列表，按顺位） |
| `目标城池` | AI 的目标城池 ID |
| `仇恨势力` / `友好势力` | 外交关系（势力 ID 列表） |
| `颜色` | 势力配色 `[前景色, 背景色]`（十六进制） |
| `装备仓库`（可选） | 剧本中势力的初始装备仓库 |
| `状态`（可选） | `灭亡` 等 |

### story.json —— 剧情关卡

对象，键为关卡序号（`"1"` 等）。每关记录一场脚本化战斗：`playerSide`、双方兵力/武将（`playerHeroes`/`enemyHeroes`）、`city`、`direction`、`player`/`enemy`（含 `leader`、`gold`、`rice`、每个武将的 `troops/level/exp/hp/power/int/leadership`），以及 `dialogs` 对话脚本（按 `condition` 如 `回合内`/`胜利`/`失败` 触发，含说话武将、头像与台词）。用于教学/剧情战役。

---

## 二、装备 / 道具子目录 `equip/`

### weapons.json —— 武器（47 条）

| 字段 | 含义 |
| --- | --- |
| `ID` | 武器编号 |
| `名称` | 武器名 |
| `持法` | 如 `短兵`、`长兵`（决定攻击方式） |
| `类型` | 剑 / 刀 / 枪 等 |
| `品质` | 品质等级（数字字符串） |
| `攻击力` `防御力` | 攻防加成 |
| `重量` | 重量 |
| `价格` | 价格 |
| `图像` | 立绘/图标编号 |

### suits.json —— 防具/套装（16 条）

字段与武器类似（`ID`、`名称`、`品质`、`攻击力`、`防御力`、`重量`、`价格`、`图像`），但作为防具（盔甲/服饰），以防御为主。

### jewelrys.json —— 饰品（书/宝，42 条）

| 字段 | 含义 |
| --- | --- |
| `ID` `名称` `类型` `品质` `价格` `图像` | 基础信息 |
| `特性` | 附加效果数组，如 `{"白兵附加战术":1}`、`{"计策附加智力":5}`、`{"开发附加人口":1000}` |

`类型` 取值如 `书`（兵书类）等。

### steeds.json —— 坐骑（12 条）

| 字段 | 含义 |
| --- | --- |
| `ID` `名称` `品质` `价格` `图像` | 基础信息 |
| `马力` | 马力值 |
| `机动力恢复` | 机动力恢复量 |
| `购买条件` | 条件表达式，如 `"a.体>=70||a.等级>=2"` |

---

## 三、技能系统子目录 `skill_system/`

### skill.json —— 技能效果定义

对象，键为技能名。每个技能：

| 字段 | 含义 |
| --- | --- |
| `类型` | 如 `锁定` |
| `标签` | 技能标签数组，如 `["仙","道术"]`、`["文"]` |
| `效果` | 效果数组，每项含 `类型`（锁定/光环）、`ID`、`触发ID`、`触发范围`、`场景ID`、`触发标签`、`标签值` 等，指向 buff 定义 |

技能是 buff 的「触发器」，实际数值逻辑在 `buff.json` 中。

### buff.json —— 增益/减益状态（buff）

数组，每条描述一种战斗状态/效果：

| 字段 | 含义 |
| --- | --- |
| `name` | buff 名 |
| `data` | 含 `scene`（小战场/大战场）、`type`（正面/负面）、`label`、`settlement`（己方）等 |

### stratagem.json —— 计策定义

数组，描述每个计策：

| 字段 | 含义 |
| --- | --- |
| `name` | 计策名（如 `火计`；带 `*` 表示强化版） |
| `data.desc` | 说明文字（含伤害公式） |
| `data.formula` | 命中率公式（字符串表达式，含 `a.知`、`b.知` 等变量） |
| `data.anim` | 动画名 |
| `data.message` | 施放提示语 |
| `data.nature` | 属性（火等） |
| `data.learn` | 习得条件（`minInt/maxInt/minLevel/maxLevel/actorIds`） |
| `data.cost` | 消耗（`ap` 行动点） |
| `data.impact` | 伤害/影响公式 |
| `data.targeting` | 目标范围、地形、范围类型等 |

---

## 四、描述 / 说明子目录 `description/`

### skills.json —— 技能详细说明（约 1MB）

对象，键为技能名，值为技能的完整描述：

| 字段 | 含义 |
| --- | --- |
| `name` | 技能名 |
| `scene` | 生效场景（大战场等） |
| `category` | 类别（锁定技/诱发技/主将限定技等） |
| `effect` / `desc` | 效果与描述 |
| `memo` | 出处/典故说明 |

### skills_info.json —— 技能补充信息

对象，键为技能名，值记录该技能涉及的「势力」参数模板（如 `初势力`、`势力#2` 等），用于需要指定势力的技能。

### QA.json —— 常见问题问答

数组，每条为 `question` / `answer`，是游戏内置 FAQ，包含 BBCode 格式与 `[url={"code":"..."}]` 指令式跳转。

---

## 五、剧情 / 剧本子目录 `drama/`

### drama.json —— 时代剧本列表

数组，每个剧本：

| 字段 | 含义 |
| --- | --- |
| `ID` / `name` | 剧本编号与名称 |
| `enabled` / `testing` | 是否启用 / 是否测试中 |
| `path` | 对应子目录名（空表示基础剧本） |
| `description` | 剧本简介 |
| `fromYear` / `fromMonth` | 开始时间 |
| `alliances`（可选） | 开局联盟关系（`"势力A-势力B": 12` 表示结盟月份） |
| `events`（可选） | 剧本关联事件 ID 列表 |

已定义剧本：董卓弄权（基础）、官渡之战、卧龙出山、赤壁之战、三国鼎立、星耀九州，以及跨朝代扩展剧本两晋十六国（liangjin）、南北朝（nanbeichao）、隋唐（suitang）、五代十国（wudai）、两宋辽金西夏（song）、元明（yuanming）、清（qing）。

### drama/<剧本>/ 子目录

每个剧本子目录（`guandu`、`wolong`、`chibi`、`stars`）内包含该剧本的独立开局快照：

- `actors.json` —— 该剧本的武将快照（属性、状态可能不同于主表，如「死亡」、`流放地` 变化）。
- `citys.json` —— 该剧本的城池快照（归属、人口、土地、产业等历史开局值）。
- `vstates.json` —— 该剧本的势力快照（君主、继承人、外交、装备仓库等，可带 `状态:"灭亡"`）。

---

## 六、考据 / 百科子目录 `research_bbcode/`

游戏内置的「史实考据」资料库，按类别分目录：

| 子目录 | 内容 |
| --- | --- |
| `people/` | 人物条目（约 1100 个，含异体字/别名的重复条目） |
| `events/` | 历史事件条目（官渡之战、赤壁之战等） |
| `context/` | 背景/制度/文化条目（屯田制、九品中正制、建安文学等） |
| `geography/` | 地理条目（长安、邺城、汉中阳平关等） |

### 内容格式

每个条目是一个 JSON 字符串（实际就是一段文本），使用自定义 **BBCode** 标记排版：

- `[b]`、`[color=#RRGGBB]`、`[indent]`、`[table=N]` / `[cell]` —— 排版。
- `[font=res://resource/font/...]` —— 引用 Godot 内置字体。
- `[url={"research": "名称", "cat": "people|events|context|geography"}]` —— 条目间超链接跳转。

条目内容通常包含「基本信息、生平/战役考证、史实 vs 演义、历代评价、考古/文献对照」等小节，标注史料来源与辨伪结论。

### research_index.json —— 考据索引（1115 条）

数组，每条为 `{name, category, file}`，是 `research_bbcode/` 下所有条目的目录索引，用于在游戏内检索与跳转。

---

## 七、特殊事件子目录 `special_events/`

### sangumaolu.json —— 「三顾茅庐」事件

对象，含 `事件名称`、`事件类型`（势力事件）、`触发武将`、`流程`。`流程` 是一个数组，每步含：

| 字段 | 含义 |
| --- | --- |
| `ID` | 步骤序号 |
| `条件` | 触发条件数组，如 `武将x在城池y中`、`年月>=x`、`武将x的y属性为z`、`x<城池y的武将数<z` |
| `效果` | 效果数组，如 `武将x说文字y|心情z`（对话，含说话人、台词、表情）、`武将x加入武将y所在城` |

是脚本化历史事件的示例，通过条件-效果驱动剧情演出与游戏状态变更。

---

## 八、战场相关

### battle_map.json —— 小战场地图

对象，键为地形类型（如 `desert`），值为地形格子（资源名）的列表，逐格描述小战场的地形布局。

### war_map.json —— 大地图（战场地图）

对象，键为地图/方向编号（`"0"`、`"45"` 等），值为地形格子资源名数组（如 `forest_44`、`land_110`、`river_6`），描述大地图战斗场景的地形。

### war_actorlocation_system.json —— 战场武将站位（系统表）

对象，键为方向角度（`0`、`45`、`90`…`315`），值为攻守双方的预设站位：

| 字段 | 含义 |
| --- | --- |
| `攻` / `守` | 进攻方 / 防守方各武将的坐标列表 `[{x,y}...]` |
| `攻范围` / `守范围` | 站位范围 `{minX,maxX,minY,maxY}` |

### war_actorlocation.json —— 战场武将站位（运行时）

空对象 `{}`，为运行时动态站位数据预留（系统默认站位见上面的 `_system` 表）。

### war_npc.json —— 战场 NPC

数组，描述战场中的 NPC：`NpcNo`、`Name`、`FaceList`、`troops_type`（军种）、`TalkToPlayer`（是否与玩家对话）。

### animation.json —— 动画配置

对象，键为动画名（如 `Town_Search`、`Town_Move`、`Town_Develop_Farm_00`），值为：

| 字段 | 含义 |
| --- | --- |
| `gif` / `data` | 对应的图集文件与帧数据文件名 |
| `se` | 音效文件名 |
| `width` / `height` | 尺寸 |
| `loops` | 是否循环播放 |

### animation_detail.json —— 动画帧数据

对象，键为动画数据名，值为 `frames` 数组，每帧含 `res`（资源哈希名）、`x`/`y` 偏移，用于逐帧还原动画。

---

## 九、文字 / 检索 / 百科

### hanzi.json —— 汉字 → 拼音

对象，键为汉字，值为该字所有读音的拼音列表（多音字列出多个）。

### pinyin.json —— 拼音 → 汉字

对象，键为拼音，值为该读音对应的汉字列表（含异体字）。与 `hanzi.json` 互为反向索引，用于武将名检索/输入。

### wiki_items.json —— 百科条目

对象，键为词条名，值为说明文本。收录游戏内特殊机制/名词的解释（如「常规技能」「大象」「投石车」「仙」「横劈」「人偶」「重伤」等），含数值公式与规则说明。

### multi_face.json —— 多立绘/多面配置

对象，键为武将 ID，值为一组「条件 → 立绘」规则：

- `if`：条件数组，如 `{"name":"面","value":"阴"}`、`{"name":"yearmonth","value":"{VAL}>=20800","expr":1}`。
- `then`：`{picture, sort, optional}` 指定立绘图片与排序。

用于根据武将状态（阴/阳/魂面、年份、装备等）切换头像/立绘。

---

## 十、签名 / 校验文件

以下四个文件是 mod 数据完整性签名所用的证书/密钥（内容为 PEM 格式，以 `.json` 后缀存储）：

| 文件 | 内容 |
| --- | --- |
| `bwdl.crt.json` | 主证书（CN=bwdl.fun, O=bwdl.ykn） |
| `bwdl.key.json` | 对应的 RSA 私钥 |
| `bwdl.signer.crt.json` | 签名者证书（CN=ykn.bwdl.fun） |
| `bwdl.signer.pub.json` | 签名者公钥 |

用于校验 mod 数据包是否被篡改（不属于游戏数据本身）。

---

## 十一、添加武将：需要改哪些文件

数据加载入口是 `bwdl/script/Static_Manager.gd` 的 `reload()`（约 1387 行），运行时把 `res://resource` 重写为 `res://packed`（`Static_Manager.gd:1395`），因此数据只需维护 `bwdl/packed/` 一份。

### 必改（缺了不生效）

| 文件 | 加载位置 | 说明 |
| --- | --- | --- |
| `actors.json` | `Static_Manager.gd:1399` | 武将主表，新增一条记录。`ID` 取当前最大 ID + 1（全局唯一）；字段见上文「actors.json」一节 |
| `actor_skills.json` | `Static_Manager.gd:1420` | 按 `ID` 对齐的技能表（`LV1`~`LV8`），空档位填 `""` |

### 可选（缺了不报错，按需加）

| 文件 | 加载位置 | 说明 |
| --- | --- | --- |
| `actors_extra.json` | `Static_Manager.gd:1404` | 相性/标签，按 `ID` merge 进主表；缺失的 `ID` 会被跳过 |
| `actor_follower.json` | `Static_Manager.gd:1433` | 父子登场 |
| `actor_special_titles.json` | `Static_Manager.gd:1450` | 特殊称呼/蔑称 |
| `multi_face.json` | `Static_Manager.gd:1449` | 多面立绘，需配合主表的 `面` 字段 |
| `citys_unoffice.json` | `Static_Manager.gd:1432` | 在野登场表 |
| `citys.json` | `Static_Manager.gd:1398` | 若开局在某城，把新 `ID` 加进该城的 `武将` 列表 |
| `vstates.json` | `Static_Manager.gd:1434` | 若做君主/继承人/部将，势力表需引用新 `ID` |

### 图片

默认头像：`packed/images/actor/face/avatar/{ID}.png`（256×40 八帧表情条），由 `Actor_Helper.gd:1126` 按 `actorId` 直连加载。

### 剧本快照（按需）

剧本子目录缺少文件时会自动回退到主表（`Static_Manager.gd:1526` 的 `_get_file_path`），所以只有「该武将在某剧本里有不同开局状态」时才需改 `drama/<剧本>/actors.json`（完整快照，非差异补丁）等文件。

### 已知坑

1. **头像 ID 断层**：`avatar/` 目前只有 600 张（ID 0~599），而 `actors.json` 已到 1660。ID 561~1660 的跨朝代武将没有默认头像；`load_pic_with_cache` 遇缺文件返回 `null`（`global.gd:171`），不崩溃但无头像。
2. **三国剧本快照滞后**：`guandu`/`wolong`/`chibi`/`stars` 的 `actors.json` 仍是 561 条，跨朝代剧本才是 1661 条。新武将若要在三国剧本登场，需手动同步这些快照。
3. **死数据**：`actor_relation.json`、`actors_others.json` 全工程无加载，改动不生效。

### 添加流程

1. 改 `actors.json` + `actor_skills.json`（可先用 `tools/sync_actors.py` 从 `docs/actors_expansion/*.md` 生成主表，但该脚本**只写主表**，不写技能/相性/头像）。
2. 放头像图 `packed/images/actor/face/avatar/{ID}.png`（256×40）。
3. 跑 `make import` 生成 Godot 资源导入缓存（`.import`）。

---

## 附：文件总览

```
data/
├── actors.json              武将主表
├── actors_extra.json        武将附加属性（相性/标签）
├── actors_others.json       特殊单位（象群等）
├── actor_skills.json        武将技能
├── old_skills.json          旧技能名清单
├── actor_relation.json      武将人际关系
├── actor_follower.json      父子登场关系
├── actor_special_titles.json 特殊称呼/昵称
├── attribute_set.json       全局属性/版本配置
├── items.json               消耗道具
├── citys.json               城池主表
├── citys_unoffice.json      城池在野武将登场
├── vstates.json             势力表
├── story.json               剧情关卡
├── battle_map.json          小战场地图
├── war_map.json             大地图（战场）
├── war_actorlocation_system.json 战场武将站位（系统）
├── war_actorlocation.json   战场武将站位（运行时，空）
├── war_npc.json             战场 NPC
├── animation.json           动画配置
├── animation_detail.json    动画帧数据
├── hanzi.json               汉字→拼音
├── pinyin.json              拼音→汉字
├── multi_face.json          多立绘/多面配置
├── wiki_items.json          百科条目
├── research_index.json      考据索引
├── bwdl.crt.json / bwdl.key.json / bwdl.signer.crt.json / bwdl.signer.pub.json  签名证书/密钥
│
├── description/             QA、技能说明
├── drama/                   时代剧本（drama.json + guandu/wolong/chibi/stars 子目录）
├── equip/                   装备（weapons/suits/jewelrys/steeds）
├── research_bbcode/         考据文档（people/events/context/geography）
├── skill_system/            技能系统（skill/buff/stratagem）
└── special_events/          特殊事件（sangumaolu）
```
