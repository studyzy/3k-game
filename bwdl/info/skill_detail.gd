# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/skill_detail.gd
# 说明：信息面板-技能详情。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Panel

var lst: Node = null
var skill: SkillInfo.SkillRecord = null
var allSkills: Array = []

onready var detail = $detail
onready var nav = $nav
onready var prevBtn = $nav / prev
onready var nextBtn = $nav / next

func _ready():
	return

func reload() -> void :
	if skill == null:
		return
	var records: Array = SkillInfo.records_by_name(skill.name)
	if records.empty():
		return

	var prev = prev()
	var next = next()
	if prev == null:
		prevBtn.text = "< 没有了"
		prevBtn.disabled = true
	else:
		prevBtn.text = "< " + prev.name
		prevBtn.disabled = false
	if next == null:
		nextBtn.text = "< 没有了"
		nextBtn.disabled = true
	else:
		nextBtn.text = next.name + " >"
		nextBtn.disabled = false

	for tab in ["技能效果", "创作背景", "所属武将"]:
		detail.get_node(tab).get_node("header/name").text = skill.name
		var more = ""
		if "（专）" in records[0].fullName:
			more = "，[color=yellow]武将专属[/color]"
		elif "（女）" in records[0].fullName:
			more = "，[color=yellow]女性限定[/color]"
		elif "（男）" in records[0].fullName:
			more = "，[color=yellow]男性限定[/color]"
		for k in ["文", "武", "仙"]:
			if records[0].skill.has_feature(k):
				more += "，[color=yellow][" + k + "][/color]"
		detail.get_node(tab).get_node("header/brief").bbcode_text = "{0}，{1}{2}".format([
			records[0].scene, records[0].category, more
		])
	
	detail.get_node("技能效果/effect").bbcode_text = skill.full_description()
	detail.get_node("创作背景/memo").bbcode_text = skill.full_background()
	var lst = detail.get_node("所属武将/list")
	var lbl = detail.get_node("所属武将/belong")
	var added = 0
	lbl.hide()
	Global.clearNode(lst)
	for sr in records:
		var belong = lbl.duplicate()
		belong.text = sr.assignment()
		belong.show()
		lst.add_child(belong)
		belong.rect_position.x = added % 4 * 180
		belong.rect_position.y = int(added / 4) * 50
		added += 1
	return

func close() -> void :
	if lst != null and lst.has_method("reload_list"):
		var idx = allSkills.find(skill)
		var page = int((idx - 1) / lst.pageSize)
		lst.reload_list(lst.keyword, page)
	hide()
	return

func prev() -> SkillInfo.SkillRecord:
	var idx = allSkills.find(skill)
	if idx < 0:
		return null
	var cur = idx
	cur = (cur + allSkills.size() - 1) % allSkills.size()
	while cur != idx:
		if allSkills[cur].name != skill.name:
			return allSkills[cur]
		cur = (cur + allSkills.size() - 1) % allSkills.size()
	return null

func next() -> SkillInfo.SkillRecord:
	var idx = allSkills.find(skill)
	if idx < 0:
		return null
	var cur = idx
	cur = (cur + 1) % allSkills.size()
	while cur != idx:
		if allSkills[cur] != skill:
			return allSkills[cur]
		cur = (cur + 1) % allSkills.size()
	return null

func nav_prev():
	var prev = prev()
	if prev == null:
		return
	skill = prev
	reload()
	return

func nav_next():
	var next = next()
	if next == null:
		return
	skill = next
	reload()
	return

func reset_layout_landscape() -> void :
	detail.rect_min_size = Vector2(900, 370)
	detail.rect_size = detail.rect_min_size
	var eff = get_node("detail/技能效果/effect")
	eff.rect_min_size = Vector2(700, 200)
	eff.rect_size = eff.rect_min_size
	var memo = get_node("detail/创作背景/memo")
	memo.rect_min_size = Vector2(700, 200)
	memo.rect_size = eff.rect_min_size
	var lst = get_node("detail/所属武将/list")
	lst.rect_min_size = Vector2(700, 180)
	lst.rect_size = eff.rect_min_size
	nav.rect_position = Vector2(0, 380)
	return

func reset_layout_portrait() -> void :
	detail.rect_min_size = Vector2(900, 720)
	detail.rect_size = detail.rect_min_size
	var eff = get_node("detail/技能效果/effect")
	eff.rect_min_size = Vector2(700, 500)
	eff.rect_size = eff.rect_min_size
	var memo = get_node("detail/创作背景/memo")
	memo.rect_min_size = Vector2(700, 500)
	memo.rect_size = eff.rect_min_size
	var lst = get_node("detail/所属武将/list")
	lst.rect_min_size = Vector2(700, 480)
	lst.rect_size = eff.rect_min_size
	nav.rect_position = Vector2(0, 740)
	return
