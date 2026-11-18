extends "basiclist.gd"

class SkillSorter extends Reference:

	func id(a: SkillInfo.SkillRecord, b: SkillInfo.SkillRecord) -> bool:
		return a.id < b.id

	func desc_id(a: SkillInfo.SkillRecord, b: SkillInfo.SkillRecord) -> bool:
		return a.id > b.id

	func scene(a: SkillInfo.SkillRecord, b: SkillInfo.SkillRecord) -> bool:
		return a.scene_score() < b.scene_score()

	func desc_scene(a: SkillInfo.SkillRecord, b: SkillInfo.SkillRecord) -> bool:
		return a.scene_score() > b.scene_score()

	func category(a: SkillInfo.SkillRecord, b: SkillInfo.SkillRecord) -> bool:
		return a.category() < b.category()

	func desc_category(a: SkillInfo.SkillRecord, b: SkillInfo.SkillRecord) -> bool:
		return a.category() > b.category()

	func assign(a: SkillInfo.SkillRecord, b: SkillInfo.SkillRecord) -> bool:
		if a.actorId == b.actorId:
			return a.lv < b.lv
		return a.actorId < b.actorId

	func desc_assign(a: SkillInfo.SkillRecord, b: SkillInfo.SkillRecord) -> bool:
		if a.actorId == b.actorId:
			return a.lv < b.lv
		return a.actorId > b.actorId

func init() -> void :
	sorter = SkillSorter.new()
	sorting = ""
	SkillInfo.reload_all_skills()
	reload_list()
	return

func reload_data() -> Array:
	$preview.hide()
	var ret = []
	for sr in SkillInfo.allSkills:
		if sr.name == "火神":
			pass
		if keyword == "":
			ret.append(sr)
			continue
		if keyword in [
			"[文]", "[武]", "[仙]", 
			"【文】", "【武】", "【仙】", 
			"神策", "秘术", "道术"
			]:
			var tag = keyword.replace("[", "")
			tag = tag.replace("]", "")
			tag = keyword.replace("【", "")
			tag = tag.replace("】", "")
			if sr.skill.has_feature(tag):
				ret.append(sr)
				continue
		if keyword == "[专属]":
			if sr.skill._exclusiveActorIds.size() > 0:
				ret.append(sr)
				continue
		if StaticManager.RE_ALPHA.search(keyword) != null:
			var found = false
			for r in StaticManager.pinyin(sr.name):
				if keyword in r:
					found = true
					if keyword == r:
						ret.insert(0, sr)
					else:
						ret.append(sr)
					break
			if found:
				continue
			for r in StaticManager.pinyin(sr.actor_name()):
				if keyword in r:
					found = true
					if keyword == r:
						ret.insert(0, sr)
					else:
						ret.append(sr)
					break
			if found:
				continue
		if keyword in sr.fullName:
			ret.append(sr)
			continue
		if keyword in sr.actor_name():
			ret.append(sr)
			continue
		if keyword in sr.description:
			ret.append(sr)
			continue
	return ret

func reload_list(_keyword: String = "", _page: int = 0) -> void :
	detail.hide()
	keyword = _keyword
	page = _page
	allItems = reload_data()
	var total = allItems.size()
	var maxPage = int((total - 1) / pageSize)
	maxPage = max(0, maxPage)
	if page < 0:
		page = maxPage
	if page > maxPage:
		page = 0
	var method = sorting
	if method.begins_with("-"):
		method = method.replace("-", "desc_")
	if sorter != null and sorter.has_method(method):
		allItems.sort_custom(sorter, method)
	var items = allItems.slice(page * pageSize, min(total - 1, page * pageSize + pageSize - 1))
	var skillList = []
	for item in allItems:
		skillList.append(item.name)
	Global.clearNode(list)
	var thisPage = items.size()
	for i in thisPage:
		var item = items[i]
		var row = create_skill_row(item)
		if row == null:
			break
		row.show()
		list.add_child(row)
	nav.get_node("page").text = str(page + 1)
	nav.get_node("total").text = "总计: " + str(total)
	return

func create_skill_row(item: Object) -> HBoxContainer:
	if not item is SkillInfo.SkillRecord:
		return null
	var sr: SkillInfo.SkillRecord = item
	var created = row.duplicate()
	created.get_node("名称").text = sr.fullName
	created.get_node("场景").text = sr.scene()
	var cate = created.get_node("类型")
	var cateContent = sr.category()
	cate.text = cateContent.left(5)
	Global.bind_button_tooltip(cate, cateContent)
	created.get_node("分配").text = sr.assignment()
	created.get_node("效果/lbl").text = sr.description
	created.get_node("效果").mouse_filter = MOUSE_FILTER_PASS
	created.get_node("效果/lbl").mouse_filter = MOUSE_FILTER_STOP
	created.get_node("效果/lbl").connect("gui_input", self, "desc_input", [sr])
	var btn = created.get_node("operation/btn")
	btn.connect("pressed", self, "skill_detail", [sr])
	btn.editor_description = str(sr.id)
	return created

func desc_input(event: InputEvent, sr: SkillInfo.SkillRecord):
	var touched = false
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and event.pressed:
			touched = true
	if event is InputEventScreenTouch:
		if event.pressed:
			touched = true
	if not touched:
		return
	$preview.get_node("name").text = sr.name
	$preview.get_node("brief").text = "{0}，{1}".format([
		sr.scene, sr.category, 
	])
	$preview.get_node("desc").text = sr.description
	$preview.show()
	return

func preview_close() -> void :
	$preview.hide()
	return

func skill_detail(skill: Object) -> void :
	if not skill is SkillInfo.SkillRecord:
		return
	preview_close()
	detail.lst = self
	detail.skill = skill
	detail.allSkills = allItems
	detail.reload()
	detail.show()
	return

func reset_layout_landscape() -> void :
	pageSize = 6
	reload_list()
	detail.reset_layout_landscape()
	return

func reset_layout_portrait() -> void :
	pageSize = 15
	reload_list()
	detail.reset_layout_portrait()
	return
