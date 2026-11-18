extends Control

onready var scon = get_node("ScrollContainer");
onready var vflow = get_node("ScrollContainer/VFlowContainer");

var main_skills = {}
var active_skills = []


var skill_block_offsets = []
const RESEARCH_PADDING = 40
const RESEARCH_LINES_PER_BLOCK = 4
var research_font: DynamicFont = null

var inited: bool = false
var actorId: int


var research_index: Array = []
var research_history: Array = []
var _current_research_entry = null


func _ready() -> void :
	inited = false
	return

func init_data(targetId: int) -> void :
	
	actorId = targetId
	reload_skills()
	switch_mode_skill()

	scroll_top()
	inited = true
	return

func fit_heights() -> void :
	if not inited:
		return
	skill_block_offsets.clear()
	var y = 0
	var height = 0
	skill_block_offsets.append(y)
	for pnl in vflow.get_children():
		if not pnl.name.begins_with("BLOCK#"):
			continue
		if pnl.name.begins_with("BLOCK#research"):
			pnl.rect_position = Vector2(RESEARCH_PADDING, y)
			height = pnl.rect_size.y
			if pnl.name == "BLOCK#research_content" and research_font != null:
				var line_h = research_font.get_height()
				var chunk = line_h * RESEARCH_LINES_PER_BLOCK
				if chunk > 0 and height > chunk:
					var offset = 0.0
					while offset + chunk < height:
						offset += chunk
						skill_block_offsets.append(y + offset)
		else:
			pnl.rect_position = Vector2(0, y)
			height = pnl.fit_height()
		y += height
		skill_block_offsets.append(y)
	vflow.rect_min_size.y = y
	vflow.rect_size.y = y
	return

func create_skill_pnl(lv: String, skillName: String, isPrimary: bool = false, isActive: bool = true, showBackground: bool = false):
	var fromSkill = ""
	if skillName.find("#") >= 0:
		fromSkill = skillName.split("#")[1]
		skillName = skillName.split("#")[0]
	if showBackground:
		if skillName == "--":
			return
		var skill = StaticManager.get_skill(skillName)
		if skill == null:
			return
	var pnlPck: PackedScene = load("res://windows/skill_description.tscn")
	var pnl = pnlPck.instance()
	pnl.name = "BLOCK#" + lv + ":" + skillName
	pnl.init_skill(actorId, lv, skillName, isPrimary, isActive, showBackground, fromSkill)
	pnl.attach_to(self)
	vflow.add_child(pnl)
	return

func _process(delta: float) -> void :
	fit_heights()
	return

func scroll_top():
	scroll_to(0)
	return

func scroll_to(idx: int):
	var vsc: VScrollBar = scon.get_v_scrollbar()
	vsc.max_value = vflow.rect_size.y
	if skill_block_offsets.empty():
		return
	idx = max(0, idx)
	idx = min(skill_block_offsets.size() - 1, idx)
	vsc.value = skill_block_offsets[idx]
	vsc.value = min(vsc.value, vsc.max_value - scon.rect_size.y)
	return

func reload_skills():
	var actor = ActorHelper.actor(actorId)
	var defaults = SkillHelper.get_actor_default_skill_names(actorId)
	main_skills = {}
	for lv in defaults:
		if defaults[lv] == "":
			continue
		main_skills[lv] = defaults[lv]
	
	
	if actor.get_side() in ["", "阴", "阳"] and main_skills.size() < 4:
		for lv in ["LV1", "LV3", "LV5", "LV7"]:
			if lv in main_skills and main_skills[lv] != "":
				continue
			main_skills[lv] = "--"

	active_skills = []
	for item in SkillHelper.get_actor_all_skills(actorId, - 1):
		if item[0].scene == "":
			
			continue
		active_skills.append(item)
	return

func switch_mode_skill(showBackground: bool = false):
	Global.clearNode(vflow)
	vflow.rect_size = Vector2(0, 0)
	
	var keys = main_skills.keys()
	keys.sort()
	for lv in keys:
		var skillName = main_skills[lv]
		var isActive = false
		for item in active_skills:
			if skillName == item[0].name:
				isActive = true
				break
		
		create_skill_pnl(lv, skillName, true, isActive, showBackground)
	
	for item in active_skills:
		var skill = item[0]
		var fromSkill = item[1]
		if skill.name in main_skills.values():
			continue
		var skillName = skill.name
		if fromSkill != null:
			skillName += "#" + fromSkill.name
		create_skill_pnl("", skillName, false, true, showBackground)
	fit_heights()
	scroll_to(0)
	return

func switch_mode_background():
	switch_mode_skill(true)
	return

func switch_mode_equip():
	Global.clearNode(vflow)
	vflow.rect_size = Vector2(0, 0)
	var actor = ActorHelper.actor(actorId)
	for ut in StaticManager.EQUIPMENT_TYPES:
		create_equip_pnl(ut, actor.get_equip(ut).id)
	fit_heights()
	scroll_to(0)
	return

func switch_mode_level():
	Global.clearNode(vflow)
	vflow.rect_size = Vector2(0, 0)
	create_level_pnl()
	fit_heights()
	scroll_to(0)
	return

func create_equip_pnl(type: String, id: int):
	var pnlPck: PackedScene = load("res://windows/skill_description.tscn")
	var pnl = pnlPck.instance()
	pnl.name = "BLOCK#{0}#{1}".format([type, id])
	pnl.init_equip(actorId, type, id)
	pnl.attach_to(self)
	vflow.add_child(pnl)
	return

func create_level_pnl():
	var pnlPck: PackedScene = load("res://windows/actor_levels.tscn")
	var pnl = pnlPck.instance()
	pnl.name = "BLOCK#{0}".format([actorId])
	pnl.init(actorId)
	pnl.attach_to(self)
	vflow.add_child(pnl)
	return

func scroll_up():
	var vsc: VScrollBar = scon.get_v_scrollbar()
	vsc.max_value = vflow.rect_size.y
	var idx = - 1
	for i in skill_block_offsets.size():
		if vsc.value > skill_block_offsets[i]:
			continue
		idx = i
		break
	scroll_to(idx - 1)
	return

func scroll_down():
	var vsc: VScrollBar = scon.get_v_scrollbar()
	vsc.max_value = vflow.rect_size.y
	var idx = - 1
	for i in skill_block_offsets.size():
		if vsc.value > skill_block_offsets[i]:
			continue
		idx = i
		break
	
	if idx + 1 < skill_block_offsets.size():
		var block_height = skill_block_offsets[idx + 1] - skill_block_offsets[idx]
		if block_height >= 350:
			vsc.value = vsc.value + 350
			vsc.value = min(vsc.value, vsc.max_value - scon.rect_size.y)
			return
	scroll_to(idx + 1)
	return

func scroll_to_block(con: Control):
	fit_heights()
	var i = 0
	for child in vflow.get_children():
		if child == con:
			scroll_to(i)
			return
		i += 1
	return



func switch_mode_research():
	Global.clearNode(vflow)
	vflow.rect_size = Vector2(0, 0)
	research_history = []
	_load_research_index()
	var actor_name = ActorHelper.actor(actorId).get_full_name()
	var found_entry = null
	for entry in research_index:
		if entry["category"] == "people" and entry["name"] == actor_name:
			found_entry = entry
			break
	if found_entry != null:
		_show_research_entry(found_entry)
	else:
		var lbl = Label.new()
		lbl.name = "BLOCK#research_empty"
		lbl.text = "暂无资料"
		lbl.size_flags_horizontal = SIZE_EXPAND_FILL
		lbl.align = Label.ALIGN_CENTER
		lbl.rect_min_size = Vector2(0, 60)
		vflow.add_child(lbl)
		skill_block_offsets = [0, 60]
		vflow.rect_min_size.y = 60
		vflow.rect_size.y = 60
	scroll_top()
	return

func _load_research_index():
	if not research_index.empty():
		return
	var f = File.new()
	var path = "res://packed/data/research_index.json"
	if not f.file_exists(path):
		return
	f.open(path, File.READ)
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse(text)
	if parsed.error == OK:
		research_index = parsed.result
	return

func _show_research_entry(entry: Dictionary):
	_current_research_entry = entry
	if research_font == null:
		research_font = load("res://resource/font/FandolSong-Bold/20.tres")
	Global.clearNode(vflow)
	vflow.rect_size = Vector2(0, 0)
	
	if not research_history.empty():
		var back_rtl = RichTextLabel.new()
		back_rtl.name = "BLOCK#research_back"
		back_rtl.bbcode_enabled = true
		back_rtl.fit_content_height = true
		back_rtl.scroll_active = false
		back_rtl.size_flags_horizontal = SIZE_EXPAND_FILL
		back_rtl.rect_min_size = Vector2(scon.rect_size.x - RESEARCH_PADDING * 2, 0)
		back_rtl.set("custom_colors/default_color", Color(0, 0, 0))
		if research_font:
			back_rtl.set("custom_fonts/normal_font", research_font)
		back_rtl.bbcode_text = "[color=#0066FF][url=research_back]>> 返回[/url][/color]"
		back_rtl.connect("meta_clicked", self, "_on_research_back_clicked")
		vflow.add_child(back_rtl)
	
	var f = File.new()
	var path = "res://packed/data/research_bbcode/" + entry["file"]
	var content = ""
	if f.file_exists(path):
		f.open(path, File.READ)
		content = f.get_as_text()
		f.close()
	else:
		content = "资料文件未找到: " + entry["file"]
	
	var rtl = RichTextLabel.new()
	rtl.name = "BLOCK#research_content"
	rtl.bbcode_enabled = true
	rtl.fit_content_height = true
	rtl.scroll_active = false
	rtl.size_flags_horizontal = SIZE_EXPAND_FILL
	rtl.rect_min_size = Vector2(scon.rect_size.x - RESEARCH_PADDING * 2, 0)
	rtl.set("custom_colors/default_color", Color(0.2, 0.2, 0.2))
	rtl.set("custom_constants/table_hseparation", 12)
	rtl.set("custom_constants/table_vseparation", 6)
	if research_font:
		rtl.set("custom_fonts/normal_font", research_font)
	rtl.bbcode_text = content
	rtl.connect("meta_clicked", self, "_on_research_meta_clicked")
	vflow.add_child(rtl)
	scroll_top()
	return

func _on_research_meta_clicked(meta):
	var meta_str = str(meta)
	var parsed = JSON.parse(meta_str)
	if parsed.error != OK:
		return
	var data = parsed.result
	if not data is Dictionary:
		return
	if not data.has("research") or not data.has("cat"):
		return
	var target_name = data["research"]
	var target_cat = data["cat"]
	for entry in research_index:
		if entry["name"] == target_name and entry["category"] == target_cat:
			if _current_research_entry != null:
				research_history.append(_current_research_entry)
			_show_research_entry(entry)
			return
	return

func _on_research_back_clicked(_meta):
	_on_research_back()
	return

func _on_research_back():
	if research_history.empty():
		switch_mode_research()
		return
	var prev_entry = research_history.pop_back()
	_show_research_entry(prev_entry)
	return
