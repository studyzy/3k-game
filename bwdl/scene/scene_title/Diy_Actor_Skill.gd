# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_title/Diy_Actor_Skill.gd
# 说明：自定义武将技能界面脚本。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const SCENE_ID = 0

const MAIN_PROPERTIES = ["文臣", "武将", "凡人", "仙体"]

class DIYSetting:
	var enabled: bool
	var actorId: int
	var vstateId: int
	var mainProperty: String
	var skillsCache: Dictionary
	var skillLocks: Array

	func _init() -> void :
		var saved = DataManager.get_env_dict("DIY")
		actorId = StaticManager.ACTOR_ID_DIY

		if saved.empty():
			enabled = true
			vstateId = StaticManager.RANDOM_VSTATE_LORD
			mainProperty = "武将"
			skillsCache = {}
			skillLocks = []
		else:
			enabled = bool(saved["enabled"])
			vstateId = int(saved["vstateId"])
			mainProperty = str(saved["main_property"])
			if not mainProperty in MAIN_PROPERTIES:
				mainProperty = MAIN_PROPERTIES[0]
			skillsCache = {}
			if "skills" in saved:
				skillsCache = Global.dicval(saved["skills"])
			skillLocks = []
			if "locked" in saved:
				skillLocks = Global.arrval(saved["locked"])
		return

	func save() -> void :
		DataManager.set_env("DIY", {
			"enabled": enabled, 
			"actorId": actorId, 
			"vstateId": vstateId, 
			"main_property": mainProperty, 
			"skills": skillsCache, 
			"locked": skillLocks, 
		})
		return

onready var vstateOB: OptionButton = get_node("OptionButton")
onready var btnRefreshSkill = get_node("con_Skill/btnRefreshSkill")
onready var skillDescription = get_node("skillDescription")
onready var avatarSelector = $avatar_selector

const MAIN_PROPS = ["武", "知", "统", "政"]
const RANDOM_PROPS = ["武", "知", "统", "政", "胆", "德"]
const TROOPS_TYPE = ["平", "山", "水"]
const WEAPONS = [0, 8, 16, 30, 33]
const SUITS = [0, 1]
const JEWELRYS = [0, 6]

onready var propertyButtons = [
	get_node("HBoxContainer/文"), 
	get_node("HBoxContainer/武"), 
	get_node("HBoxContainer/凡"), 
	get_node("HBoxContainer/仙"), 
]

onready var genderCheckboxes = [
	get_node("sex/chkMale"), 
	get_node("sex/chkFemale"), 
	get_node("sex/chkNoGender"), 
]

var setting: DIYSetting


var skills_pool: Dictionary = {}

func _ready() -> void :
	
	hide()
	setting = DIYSetting.new()
	_init_skill_pool()
	skillDescription.hide()
	_init_buttons()
	_init_vstate_options()
	var ok = $SLConfirmation.get_ok()
	ok.add_font_override("font", Global.get_font(25))
	ok.text = "确定"
	ok.rect_position -= Vector2(0, 40)
	var cancel = $SLConfirmation.get_cancel()
	cancel.add_font_override("font", Global.get_font(25))
	cancel.text = "算了"
	cancel.rect_position -= Vector2(0, 40)
	hide_levelup_all()

	
	if DataManager.game_set["技能系统"] != "是":
		$con_Skill.hide()

	$avatar_selector.connect("avatar", self, "set_avatar")
	SceneManager.load_scene_complete = true
	return

func _init_vstate_options():
	var items = []
	for vs in clVState.all_vstates():
		var lordId = vs.get_lord_id()
		if lordId < 0:
			continue
		if DataManager.get_city_num_by_vstate(vs.id) == 0:
			continue
		items.append([vs.get_lord_name(), vs.id])
	items.append(["随机势力(君主)", StaticManager.RANDOM_VSTATE_LORD])
	items.append(["随机势力(部下)", StaticManager.RANDOM_VSTATE_COMMON])
	var idx = 0
	for i in items.size():
		var name = items[i][0]
		var vstateId = items[i][1]
		if vstateId == setting.vstateId:
			idx = i
		vstateOB.add_item(name, vstateId)
	_on_OptionButton_item_selected(idx)
	return

func _init_buttons():
	for btn in propertyButtons:
		btn.connect("pressed", self, "_property_pressed", [btn.text])
	for btn in genderCheckboxes:
		btn.connect("pressed", self, "_gender_checked", [btn.text])

	var diyActor = ActorHelper.actor(setting.actorId)
	get_node("txtFirstName").text = diyActor.get_first_name()
	get_node("txtName").text = diyActor.get_name_only()
	get_node("txtNick").text = diyActor.get_nick()
	_gender_checked(diyActor.get_gender())
	if diyActor.get_exp() > 0 or diyActor.get_level() > 1:
		diyActor.set_exp(0)
		diyActor.set_level(1)
		_property_pressed(setting.mainProperty, true)
	else:
		_property_pressed(setting.mainProperty, false)
	_update_skill_show()
	
	var face = diyActor.get_avatar()
	set_btn_face(face)
	return

func init_show():
	SceneManager.VirtualKey.hide()
	show()
	return

func _process(delta):
	if not visible:
		return
	SceneManager.VirtualKey.hide()
	return

func _property_pressed(property: String, regenerate: bool = true):
	for btn in propertyButtons:
		if btn.text == property:
			btn.pressed = true
		else:
			btn.pressed = false
	var prevMainProperty = setting.mainProperty
	setting.mainProperty = property
	setting.save()
	if regenerate:
		var valueBounds = regenerate_actor_property(prevMainProperty)
		update_actor_property(valueBounds)
	revalidate_skills()
	if prevMainProperty != setting.mainProperty:
		reload_skill_cache()
		revalidate_skills()
		_update_skill_show()
	return

func _gender_checked(gender: String):
	var diyActor = ActorHelper.actor(setting.actorId)
	for btn in genderCheckboxes:
		if btn.text == gender:
			btn.pressed = true
		else:
			btn.pressed = false
	if diyActor.get_gender() != gender:
		diyActor.set_gender(gender)
		diyActor.set_avatar(get_face(gender))
		revalidate_skills()
	var face = diyActor.get_avatar()
	if face == "":
		diyActor.set_avatar(get_face(diyActor.get_gender()))
		face = diyActor.get_avatar()
	set_btn_face(face)
	update_actor_property()
	return


func update_actor_property(valueBounds: Dictionary = {}):
	var diyActor = ActorHelper.actor(setting.actorId)
	get_node("actorDetailInfo").nprFace.has_face = false
	get_node("actorDetailInfo")._load_base(diyActor.actorId, valueBounds)
	return



func regenerate_actor_property(prevMainProperty: String = "") -> Dictionary:
	var valueBounds = {}
	for prop in RANDOM_PROPS:
		valueBounds[prop] = [10, 80]
	valueBounds["德"] = [10, 90]
	match setting.mainProperty:
		"文臣":
			valueBounds["武"] = [10, 50]
			valueBounds["统"] = [30, 70]
			valueBounds["知"] = [60, 90]
			valueBounds["政"] = [60, 90]
		"武将":
			valueBounds["武"] = [60, 90]
			valueBounds["统"] = [60, 90]
			valueBounds["知"] = [30, 70]
			valueBounds["政"] = [10, 50]
	var diyActor = ActorHelper.actor(setting.actorId)
	if prevMainProperty != "凡人" and setting.mainProperty == "凡人":
		
		for prop in RANDOM_PROPS:
			diyActor._set_attr_int(prop, 1)
		diyActor.set_hp(10)
	else:
		
		for prop in RANDOM_PROPS:
			var minVal = valueBounds[prop][0]
			var maxVal = valueBounds[prop][1]
			var val = Global.get_random(minVal, maxVal)
			diyActor._set_attr_int(prop, val)
		
		var minHP = max(30, diyActor.get_power() - 10)
		var maxHP = min(99, diyActor.get_power() + 10)
		maxHP = max(maxHP, minHP + 10)
		valueBounds["体"] = [minHP, maxHP]
		diyActor.set_hp(Global.get_random(minHP, maxHP))

	
	diyActor._set_attr_int("原体力", diyActor.get_hp())
	var troopsType = TROOPS_TYPE.duplicate()
	troopsType.shuffle()
	diyActor.set_troops_type(troopsType[0])
	var weapons = WEAPONS.duplicate()
	weapons.shuffle()
	diyActor.set_equip(clEquip.equip(weapons[0], "武器"))
	var suits = SUITS.duplicate()
	suits.shuffle()
	diyActor.set_equip(clEquip.equip(suits[0], "防具"))
	var jewelrys = JEWELRYS.duplicate()
	jewelrys.shuffle()
	diyActor.set_equip(clEquip.equip(jewelrys[0], "道具"))
	diyActor.set_equip(clEquip.equip(0, "坐骑"))
	return valueBounds






func _on_txtFirstName_text_changed(fn: String) -> void :
	ActorHelper.actor(setting.actorId).set_first_name(fn)
	var name = get_node("txtName").text
	ActorHelper.actor(setting.actorId).set_name(fn + name)
	update_actor_property()
	return

func _on_txtName_text_changed(name: String) -> void :
	var actor = ActorHelper.actor(setting.actorId)
	var fn = actor.get_first_name()
	ActorHelper.actor(setting.actorId).set_name(fn + name)
	update_actor_property()
	return

func _on_txtNick_text_changed(nick: String) -> void :
	ActorHelper.actor(setting.actorId).set_nick(nick)
	update_actor_property()
	return

func _on_OptionButton_item_selected(index: int) -> void :
	vstateOB.selected = index
	setting.vstateId = vstateOB.get_item_id(index)
	setting.save()
	var diyActor = ActorHelper.actor(setting.actorId)
	if setting.vstateId == StaticManager.RANDOM_VSTATE_LORD:
		diyActor.set_loyalty(100)
	else:
		diyActor.set_loyalty(80)
	update_actor_property()
	return

func get_face(gender: String) -> String:
	match gender:
		"男":
			return "diy/male/1"
		"女":
			return "diy/female/0"
	return "diy/genderless/1"

func set_btn_face(face_name: String):
	var no = face_name
	no = no.replacen("mod/diy/genderless/", "")
	no = no.replacen("mod/diy/female/", "")
	no = no.replacen("mod/diy/male/", "")
	no = no.replacen("diy/genderless/", "无")
	no = no.replacen("diy/female/", "女")
	no = no.replacen("diy/male/", "男")
	get_node("sex/btnAvatar").text = no
	get_node("sex/btnAvatar").editor_description = face_name
	update_actor_property()
	return

func get_btn_face() -> String:
	return get_node("sex/btnAvatar").editor_description

func _on_btnMenu_pressed() -> void :
	Input.action_press("EMU_MENU");
	return

func _on_btnMenu_released() -> void :
	Input.action_release("EMU_MENU");
	return


func _on_btnRefreshSkill_pressed() -> void :
	skillDescription.hide()
	refresh_skills()
	return


func refresh_skills():
	var diyActor = ActorHelper.actor(setting.actorId)
	var current = diyActor.get_diy_skills()
	for lv in current:
		if lv in get_locked_skill_levels():
			continue
		current[lv] = ""
	diyActor.set_diy_skills(current)
	clear_skill_cache()
	revalidate_skills()
	return


func revalidate_skills():
	var diyActor = ActorHelper.actor(setting.actorId)
	var current = diyActor.get_diy_skills()
	var skills = {}
	var validated = []
	if DataManager.is_test_player():
		var specified = DataManager.get_test_player_content("技能").split("/")
		if specified.size() >= 4:
			for i in min(8, specified.size()):
				current["LV{0}".format([i + 1])] = specified[i]
			diyActor.set_diy_skills(current)
			_update_skill_show()
			return
	
	for i in range(1, 9, 2):
		var lv = "LV{0}".format([i])
		skills[lv] = ""
		if lv in current:
			skills[lv] = current[lv]
		if not _skill_valid(skills[lv]):
			skills[lv] = ""
			unlock_skill_level(lv)
		validated.append(skills[lv])
	var randoms = _regenerate_random_skills(validated)
	for i in 4:
		var lv = "LV{0}".format([i * 2 + 1])
		skills[lv] = randoms[i]
	diyActor.set_diy_skills(skills)
	update_skill_cache()
	_update_skill_show()
	return



func _regenerate_random_skills(validated: Array) -> Array:
	var diyActor = ActorHelper.actor(setting.actorId)
	var excludedTags = []
	var preferredTags = []
	match diyActor.get_gender():
		"男":
			excludedTags.append("女")
		"女":
			excludedTags.append("男")
		_:
			excludedTags.append("女")
			excludedTags.append("男")
	excludedTags.append("仙")
	match setting.mainProperty:
		"仙体":
			excludedTags.append("武")
			excludedTags.erase("仙")
			preferredTags.append("仙")
		"文臣":
			preferredTags.append("文")
		"武将":
			preferredTags.append("武")
	var candidates = []
	var preferred = []
	var feminines = []
	for skillName in skills_pool.keys():
		if skillName in validated:
			continue
		var tags = skills_pool[skillName]
		var excluded = false
		for tag in excludedTags:
			if tag in tags:
				excluded = true
				break
		if excluded:
			continue
		candidates.append(skillName)
		if "女" in tags:
			feminines.append(skillName)
		for tag in preferredTags:
			if tag in tags:
				preferred.append(skillName)
				break
	
	var ret = validated.duplicate()
	for i in ret.size():
		if ret[i] != "":
			candidates.erase(ret[i])
			feminines.erase(ret[i])
			preferred.erase(ret[i])
			continue
		if not feminines.empty() and diyActor.get_gender() == "女":
			if Global.get_rate_result(17):
				feminines.shuffle()
				ret[i] = feminines.pop_front()
				candidates.erase(ret[i])
				preferred.erase(ret[i])
				continue
		if not preferred.empty():
			if Global.get_rate_result(10):
				preferred.shuffle()
				ret[i] = preferred.pop_front()
				candidates.erase(ret[i])
				feminines.erase(ret[i])
				continue
		candidates.shuffle()
		ret[i] = candidates.pop_front()
		preferred.erase(ret[i])
		feminines.erase(ret[i])
	return ret

func _skill_valid(skillName: String) -> bool:
	if skillName == "":
		return false
	if not skillName in skills_pool:
		return false
	var tags = skills_pool[skillName]
	if "女" in tags:
		var diyActor = ActorHelper.actor(setting.actorId)
		if diyActor.get_gender() != "女":
			return false
	if "男" in tags:
		var diyActor = ActorHelper.actor(setting.actorId)
		if diyActor.get_gender() == "男":
			return false
	if "武" in tags:
		if setting.mainProperty == "仙体":
			return false
	if "仙" in tags:
		if setting.mainProperty != "仙体":
			return false
	return true


func _init_skill_pool():
	skills_pool.clear()
	for skill in StaticManager.get_all_possible_skills().values():
		skills_pool[skill.name] = []
		skills_pool[skill.name].append_array(skill._tags)
		skills_pool[skill.name].append_array(skill._gendersOnly)
	return


func _update_skill_show():
	var diyActor = ActorHelper.actor(setting.actorId)
	var diyskills = diyActor.get_diy_skills()
	for level in range(1, 9, 2):
		var levelKey = "LV{0}".format([level])
		if not diyskills.has(levelKey):
			continue
		var skillName = diyskills[levelKey]
		var skill = StaticManager.get_skill(skillName)
		if skill == null:
			continue
		var btn = get_node_or_null("con_Skill/GridContainer/con{0}/Button".format([levelKey]))
		if btn == null:
			continue
		btn.text = skillName
		var color = "FFF500"
		
		if skill._gendersOnly.has("女"):
			color = "FF80D5"
		elif skill._gendersOnly.has("男"):
			color = "C0C0FF"
		
		if not skill._exclusiveActorIds.empty():
			color = "FF0000"
		btn.set("custom_colors/font_color", color)
		for st in ["hover", "pressed", "focus"]:
			btn.set("custom_colors/font_color_" + st, color)
		
		var lock = get_node_or_null("con_Skill/GridContainer/con{0}/lock".format([levelKey]))
		if lock == null:
			continue
		lock.visible = levelKey in get_locked_skill_levels()
		
		if levelKey != skillDescription.editor_description:
			continue
		var text = skill.get_runtime_description()
		text += "\n\n"
		text += "　[color=white][url=swapLeft][u][换左][/u][/url][/color]"
		text += "　[color=white][url=swapRight][u][换右][/u][/url][/color]"
		text += "　　　　　　　　　　　　　　"
		if levelKey in get_locked_skill_levels():
			text += "[color=white][url=unlock][u][解锁][/u][/url][/color]"
		else:
			text += "[color=yellow][url=lock][u][锁定][/u][/url][/color]"
		var txt = skillDescription.get_node("txt")
		txt.bbcode_text = text
		var height = txt.get_content_height()
		height = max(txt.rect_min_size.y, height)
		txt.rect_size.y = height
		var current = skillDescription.rect_size.y
		skillDescription.rect_size.y = height + 20
		skillDescription.rect_position.y -= height + 20 - current
	return


func _on_btnConfirm_pressed() -> void :
	_quit(true);
	return


func _on_btnBack_pressed() -> void :
	_quit(false);
	return

func _quit(enabled: bool):
	setting.enabled = enabled
	setting.save()
	SceneManager.VirtualKey.show()
	hide()
	return ;

func _popup(notice: String, callback: String = ""):
	var btn = $SLConfirmation.get_ok()
	Global.clear_signals(btn, ["pressed"])
	get_node("SLConfirmation/notice").bbcode_text = notice
	if callback == "":
		return
	btn.connect("pressed", self, callback)
	$SLConfirmation.popup_centered()
	return

func _on_btnSave_pressed():
	var msg = "保存当前的自建属性和技能组\n以后自建时可以加载使用\n会覆盖之前保存的数据，确定吗？"
	_popup(msg, "save_confirmed")
	return

func save_confirmed():
	$SLConfirmation.hide()
	var actor = ActorHelper.actor(setting.actorId)
	var data = {}
	data["skills"] = actor._get_attr_str("diy_skills")
	data["系"] = setting.mainProperty
	data["姓"] = actor.get_first_name()
	data["姓名"] = actor.get_name()
	data["字"] = actor.get_nick()
	data["性别"] = actor.get_gender()
	data["头像"] = actor.get_avatar()
	data["体"] = actor.get_hp()
	data["德"] = actor.get_moral()
	for prop in RANDOM_PROPS:
		data[prop] = actor._get_attr_int(prop)
	var content = JSON.print([data], "  ")
	Global.save_file_text("user://diy.json", content)
	return

func _on_btnLoad_pressed():
	var btn = $SLConfirmation.get_ok()
	Global.clear_signals(btn, ["pressed"])
	var content = Global.get_file_text("user://diy.json")
	if content == "":
		_popup("未找到之前保存的数据")
		return
	var data = parse_json(content)
	if typeof(data) != TYPE_ARRAY:
		_popup("未找到之前保存的数据")
		return
	var saved = data[0]
	
	var actor = ActorHelper.actor(setting.actorId)
	var original = actor._get_attr_str("diy_skills")
	actor._set_attr_str("diy_skills", saved["skills"])
	var skills = actor.get_diy_skills().values()
	while "" in skills:
		skills.erase("")
	actor._set_attr_str("diy_skills", original)
	var msg = "加载之前保存的自建属性\n技能组：[color=red]{0}[/color]\n会覆盖当前数据，确定吗？".format([
		"、".join(skills)
	])
	_popup(msg, "load_confirmed")
	return

func load_confirmed():
	$SLConfirmation.hide()
	var content = Global.get_file_text("user://diy.json")
	if content == "":
		return
	var data = parse_json(content)
	if typeof(data) != TYPE_ARRAY:
		return
	var saved = data[0]
	var actor = ActorHelper.actor(setting.actorId)
	actor._set_attr_str("diy_skills", saved["skills"])
	actor.set_first_name(saved["姓"])
	$txtFirstName.text = saved["姓"]
	actor.set_name(saved["姓名"])
	$txtName.text = actor.get_name_only()
	actor.set_nick(saved["字"])
	$txtNick.text = saved["字"]
	actor.set_gender(saved["性别"])
	actor.set_avatar(saved["头像"])
	actor.set_hp(int(saved["体"]))
	actor._set_attr_int("原体力", int(saved["体"]))
	actor.set_moral(int(saved["德"]))
	for prop in RANDOM_PROPS:
		actor._set_attr_int(prop, int(saved[prop]))
	_update_skill_show()
	update_actor_property()
	set_btn_face(actor.get_avatar())
	_property_pressed(saved["系"], false);
	_gender_checked(actor.get_gender())
	return

func reset_layout_landscape():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1, 1)
	return

func reset_layout_portrait():
	
	rect_position = Vector2(128, 0)
	rect_scale = Vector2(0.8, 0.8)
	return

func _on_Button_skill_pressed(level: String):
	level = level.to_upper()
	if skillDescription.visible and skillDescription.editor_description == level:
		skillDescription.hide()
		return
	skillDescription.hide()
	skillDescription.editor_description = level
	_update_skill_show()
	skillDescription.show()
	return

func _on_skillDescription_meta_clicked(meta):
	var level = skillDescription.editor_description
	var levels = ["LV1", "LV3", "LV5", "LV7"]
	var idx = levels.find(level)
	if idx < 0:
		return
	match meta:
		"lock":
			lock_skill_level(level)
		"unlock":
			unlock_skill_level(level)
		"swapLeft":
			var targetLevel = levels[(idx + levels.size() - 1) % levels.size()]
			var diyActor = ActorHelper.actor(setting.actorId)
			var diyskills = diyActor.get_diy_skills()
			var swap = diyskills[level]
			diyskills[level] = diyskills[targetLevel]
			diyskills[targetLevel] = swap
			diyActor.set_diy_skills(diyskills)
			var currentLocked = get_locked_skill_levels()
			if level in currentLocked:
				lock_skill_level(targetLevel)
			else:
				unlock_skill_level(targetLevel)
			if targetLevel in currentLocked:
				lock_skill_level(level)
			else:
				unlock_skill_level(level)
			_update_skill_show()
			skillDescription.hide()
		"swapRight":
			var targetLevel = levels[(idx + 1) % levels.size()]
			var diyActor = ActorHelper.actor(setting.actorId)
			var diyskills = diyActor.get_diy_skills()
			var swap = diyskills[level]
			diyskills[level] = diyskills[targetLevel]
			diyskills[targetLevel] = swap
			diyActor.set_diy_skills(diyskills)
			var currentLocked = get_locked_skill_levels()
			if level in currentLocked:
				lock_skill_level(targetLevel)
			else:
				unlock_skill_level(targetLevel)
			if targetLevel in currentLocked:
				lock_skill_level(level)
			else:
				unlock_skill_level(level)
			_update_skill_show()
			skillDescription.hide()
	_update_skill_show()
	return

func show_levelup_all() -> void :
	var levels = get_node_or_null("levels")
	if levels == null:
		var levelScene: PackedScene = load("res://windows/actor_levels.tscn")
		levels = levelScene.instance()
		levels.init(setting.actorId)
		levels.set_name("levels")
		add_child(levels)
		levels.rect_position = Vector2(200, 50)
	levels.init(setting.actorId)
	levels.update_data()
	
	levels.show()
	return

func hide_levelup_all() -> void :
	var levels = get_node_or_null("levels")
	if levels == null:
		return
	levels.hide()
	return

func _on_btnLevels_pressed():
	var levels = get_node_or_null("levels")
	if levels == null or not levels.visible:
		show_levelup_all()
	else:
		hide_levelup_all()
	return


func reload_skill_cache():
	var diyActor = ActorHelper.actor(setting.actorId)
	if not setting.mainProperty in setting.skillsCache:
		return
	if not "skills" in setting.skillsCache[setting.mainProperty]:
		return
	var cached = setting.skillsCache[setting.mainProperty]["skills"]
	if cached == "":
		return
	diyActor._set_attr_str("diy_skills", cached)
	return


func clear_skill_cache():
	var diyActor = ActorHelper.actor(setting.actorId)
	for key in setting.skillsCache:
		setting.skillsCache[key].erase("skills")
	return


func update_skill_cache():
	var diyActor = ActorHelper.actor(setting.actorId)
	if not setting.mainProperty in setting.skillsCache:
		setting.skillsCache[setting.mainProperty] = {"skills": "", "locked": []}
	setting.skillsCache[setting.mainProperty]["skills"] = diyActor._get_attr_str("diy_skills")
	return

func get_locked_skill_levels() -> PoolStringArray:
	var ret = []
	ret.append_array(setting.skillLocks)
	return ret

func unlock_skill_level(level: String) -> void :
	while level in setting.skillLocks:
		setting.skillLocks.erase(level)
	return

func lock_skill_level(level: String) -> void :
	unlock_skill_level(level)
	setting.skillLocks.append(level)
	return

func choose_avatar():
	$avatar_selector.start_for(setting.actorId)
	return

func set_avatar(name: String, avatar: String) -> void :
	set_btn_face(name)
	return
