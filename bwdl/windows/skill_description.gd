extends Control

const EQUIP_FORMATTINGS = {
	"武器": "品质：{品质}  攻击：{攻击力}  防御：{防御力}\n重量：{武器重量}  价格：{价格}", 
	"防具": "品质：{品质}  防御：{防御力}\n重量：{防具重量}  价格：{价格}", 
	"道具": "品质：{品质}  价格：{价格}", 
	"坐骑": "马力：{马力}  价格：{价格}  机动力恢复：{机动力恢复}", 
}


export (String) var skill_name;

export (bool) var special = false

export (bool) var isPrimary = true

export (bool) var available = true

var skill_desc = "";

onready var lblname = get_node("Name");
onready var spNameBg = get_node("NameBg");
onready var lbldesctiption = get_node("Description");
onready var skilldescription = get_node("Skilldescription");
onready var closeButton = get_node("CloseButton");
onready var extInfo = get_node("extInfo");
onready var extContent = get_node("extContent");

const name_default_font_color = "#000000";
const name_default_bg_color = "#fff500";

var conSkills: Control = null


func _ready() -> void :
	update_data()
	return

func attach_to(_conSkills: Control) -> void :
	conSkills = _conSkills
	return

func update_data() -> void :
	var bg_color: String = name_default_bg_color;
	var font_color: String = name_default_font_color;
	if special:
		font_color = "#F00000"
		bg_color = "#FFF500"
	elif not available:
		font_color = "#000000";
		bg_color = "#CCCCCC";
	elif not isPrimary:
		font_color = "#ffffff";
		bg_color = "#000000";
	lblname.set("custom_colors/font_color", Color(font_color));
	spNameBg.self_modulate = Color(bg_color);
	lblname.text = skill_name;
	lbldesctiption.bbcode_text = skill_desc;
	closeButton.hide()
	extInfo.hide()
	extContent.hide()
	return

func init_skill(actorId: int, lv: String, skillName: String, _isPrimary: bool = true, isActive: bool = true, showBackground: bool = false, fromSkill: String = "") -> void :
	skill_name = skillName
	var skill = StaticManager.get_skill(skillName)

	if showBackground:
		skill_desc = skill.background_for(actorId)
		if skill_desc.find("☆制作组") >= 0:
			var from = skill_desc.find("☆制作组")
			for ending in ["：", "，"]:
				var to = skill_desc.find(ending, from)
				if from >= 0 and to >= 0:
					var piece = skill_desc.substr(from, to - from + ending.length())
					skill_desc = skill_desc.replace(piece, "\n[color=blue]" + piece + "[/color]\n")
					break
		if skill_desc == "":
			skill_desc = "[color=gray]（尘封故事，尚待启述）[/color]"
		return

	isPrimary = _isPrimary
	available = true

	var actor = ActorHelper.actor(actorId)
	var wa = null

	var sceneId = DataManager.get_current_scene_id()
	if sceneId >= 20000:
		wa = DataManager.get_war_actor(actorId);

	if skill == null:
		
		available = false
		skill_desc = "[color=#404040]{0}技能未上线。请等待后续更新。[/color]".format([lv])
		return

	var status = lv
	var skillReplacement = [skill_name]
	var unlocked = true
	if lv.left(2) == "LV":
		status += "已解锁。"
	if actor.get_level() < int(lv.to_upper().replace("LV", "")):
		status = "[color=red]{0}未解锁。[/color]".format([lv])
		available = false
		unlocked = false
	var reason = SkillHelper.get_actor_skill_disabled_reason(sceneId, actorId, skill.name)
	if not reason.empty():
		status = "[color=red]{0}不可用。[/color]".format([lv])
		available = false
	elif unlocked and not isActive:
		status = "[color=red]{0}不可用。[/color]".format([lv])
		available = false
	if isActive and not unlocked:
		
		
		status = "{0}[color=blue]临时获得。[/color]".format([status])

	
	var desc = skill.get_runtime_description(actorId, true)

	var extra_info = get_skill_extra_info(sceneId, actorId, skill_name)
	if extra_info[0] != "":
		desc += "\n" + extra_info[0]
		skillReplacement.append_array(extra_info[1])

	if fromSkill != "":
		desc += "\n<{0}>附加".format([fromSkill])
		skillReplacement.append(fromSkill)
	desc = desc.trim_prefix("【" + skill_name + "】")

	var extended = skill.get_extended_info(actorId)
	for ek in extended.keys():
		var from = "@{0}".format([ek])
		var to = "[color=blue]{0}[/color]".format([extended[ek]])
		desc = desc.replace(from, to)
	for s in skillReplacement:
		var replacement = "【{0}】".format([s])
		var replaced = "[color=blue][url={\"skill\":\"{0}\"}]{1}[/url][/color]".format([
			s, replacement, 
		])
		desc = desc.replace(replacement, replaced)
	desc = _add_meta_info(desc)
	if desc.find("☆制作组") >= 0:
		var from = desc.find("☆制作组")
		var ending = "："
		var to = desc.find(ending, from)
		if from >= 0 and to >= 0:
			var piece = desc.substr(from, to - from + ending.length())
			desc = desc.replace(piece, "\n[color=blue]" + piece + "[/color]\n")
	skill_desc = status + desc
	return

func init_equip(actorId: int, type: String, id: int) -> void :
	skill_name = type
	var actor = ActorHelper.actor(actorId)
	var equip = actor.get_equip(type)
	var formatting = EQUIP_FORMATTINGS[type]
	var sb = StringBuilder.new()

	var icon = get_node("Skilldescription/icon")
	icon.visible = true
	var setting = equip.image_setting()
	icon.texture = setting["img"]
	icon.region_enabled = true
	icon.region_rect = Rect2(setting["x"], setting["y"], 32, 32)

	var naming = "      [b]{名称}[/b]"
	var code = equip.get_name_color_code()
	if code != "":
		special = true
		naming = "      [color=" + code + "][b]{名称}[/b][/color]"
	if type == "武器":
		naming += " （{持法} - {类型}）"
	else:
		if equip.subtype() != "":
			naming += " （{类型}）"
	if equip.disabled:
		naming += "[color=red]已禁用[/color]"
	naming += "\n"
	sb.append(naming.format(equip.as_dict()))
	var detail = formatting.format(equip.as_dict())
	
	var originalWeight = equip.weight(true)
	var runtimeWeight = originalWeight
	var weightFormat = "{0}"
	var weightReplacement = ""
	if type == "武器":
		runtimeWeight = actor.weapon_weight()
		weightReplacement = "{武器重量}"
	elif type == "防具":
		runtimeWeight = actor.suit_weight()
		weightReplacement = "{防具重量}"
	if runtimeWeight > originalWeight:
		weightFormat = "{0}[color=blue]+{2}[/color]"
	elif runtimeWeight < originalWeight:
		weightFormat = "[color=red]{1}[/color]"
	detail = detail.replace(weightReplacement, weightFormat.format([originalWeight, runtimeWeight, runtimeWeight - originalWeight]))
	sb.append(detail + "\n")
	var condition = equip.get_attr_str("购买条件描述")
	if condition == "":
		condition = equip.get_attr_str("购买条件")
		condition = condition.replace("a.", "")
		condition = condition.replace("||", "或")
		condition = condition.replace("==", "为")
	if condition != "":
		sb.append("购买条件：" + condition + "\n")
	var memo = equip.get_attr_str("描述")
	if memo != "":
		sb.append("[color=blue]" + memo + "[/color]\n")
	for desc in equip.get_features_description():
		sb.append("效果：" + desc + "\n")
	skill_desc = sb.to_string()
	return

func fit_height() -> float:
	var textheight: int = lbldesctiption.get_content_height()
	skilldescription.rect_size.y = max(textheight, skilldescription.rect_min_size.y)
	var height = max(skilldescription.rect_size.y + 12, rect_size.y)
	if extContent.visible:
		height += extContent.rect_size.y + 12
	return height

func _on_Description_meta_clicked(meta):
	closeButton.hide()
	extInfo.hide()
	extContent.hide()
	if "skill" in meta:
		var content = ""
		var dic: Dictionary = parse_json(meta)
		var skillName = str(dic["skill"])
		var skill = StaticManager.get_skill(skillName)
		if skill == null or not skill.visible():
			return
		content = skill.get_runtime_description()
		content = _add_meta_info(content)
		extContent.bbcode_text = content
	if "buff" in meta:
		var dic: Dictionary = parse_json(meta)
		var buff_name = str(dic["buff"])
		var buffInfo = StaticManager.get_buff(buff_name)
		var buffDesc = ""
		if buffInfo != null:
			buffDesc = buffInfo.get_description()
		var content = "【{0}】状态说明：\n{1}".format([
			buff_name, buffDesc, 
		])
		content = _add_meta_info(content)
		extContent.bbcode_text = content
	if "wiki" in meta:
		var dic: Dictionary = parse_json(meta)
		var content = "【{0}】：\n{1}".format([dic["wiki"], StaticManager.get_wiki_description(dic["wiki"])])
		content = _add_meta_info(content)
		extContent.bbcode_text = content
	if "tactic" in meta:
		var dic: Dictionary = parse_json(meta)
		if dic["tactic"] in StaticManager.TACTICS:
			var tactic = dic["tactic"]
			var content = "【{0}】：小战场战术。\n{1}".format([tactic, StaticManager.TACTICS[tactic]["描述"]])
			
			extContent.bbcode_text = content
	extInfo.rect_size.y = extContent.get_content_height() + 12
	var con = $Skilldescription
	var offset = con.rect_position.y + con.rect_size.y + 12
	extInfo.rect_position.y = offset
	closeButton.rect_position.y = offset
	extContent.rect_position.y = offset + 6
	closeButton.show()
	extInfo.show()
	extContent.show()
	
	if conSkills != null:
		conSkills.scroll_to_block(self)
	return

func _on_CloseButton_pressed():
	closeButton.hide()
	extInfo.hide()
	extContent.hide()
	return



func get_skill_extra_info(sceneId: int, actorId: int, skillName: String) -> Array:
	var ret = ["", []]
	var reason = SkillHelper.get_actor_skill_disabled_reason(sceneId, actorId, skillName)
	if reason.size() == 2:
		ret[0] = "（{0}）。".format(reason)
		ret[1].append(str(reason[1]))
		return ret
	for dic in SkillHelper.get_actor_scene_skills(actorId, sceneId):
		if str(dic["skill_name"]) != skillName:
			continue
		if dic.has("from") and dic.has("source") and str(dic["source"]) != "":
			ret[0] = "（因{0} <{1}> 获得）".format([
				ActorHelper.actor(int(dic["from"])).get_name(), 
				str(dic["source"])
			])
			ret[1].append(str(dic["source"]))
			return ret
	var skill = StaticManager.get_skill(skillName)
	if not skill.exclusive_valid_for_actor(actorId):
		var names = []
		for specified in skill._exclusiveActorIds:
			names.append(ActorHelper.actor(specified).get_name())
		var memo = "、".join(names)
		if names.size() > 3:
			memo = "\n".join(names.slice(0, 2)) + "等人"
		ret[0] = "此为[color=blue]{0}[/color]专属技能，[color=red]不可用[/color]".format([
			memo
		])
		return ret
	if not skill.gender_valid_for_actor(actorId):
		ret[0] = "此为[color=blue]{0}性专属技能，[color=red]不可用[/color]".format([
			"、".join(skill._gendersOnly)
		])
		return ret
	for effect in skill.effects:
		var status = effect.get_basic_status(actorId)
		if status != "":
			ret[0] = status
			break
	return ret

func _translate_condition(condition: String) -> String:
	condition = condition.replace("a.", "")
	condition = condition.replace("||", " 或 ")
	condition = condition.replace("&&", " 且 ")
	return condition

func _add_meta_info(desc: String) -> String:
	if desc.find("{") >= 0:
		var desc_cut_array = desc.split("{")
		for i in desc_cut_array.size():
			if not "}" in desc_cut_array[i]:
				continue;
			var item = desc_cut_array[i].split("}")[0]
			var buffInfo = StaticManager.get_buff(item)
			if buffInfo != null:
				var buff_found_piece = "{{0}}".format([item])
				var buff_found_with_url = "[color=red][url={\"buff\":\"" + item + "\"}]" + item + "[/url][/color]"
				desc = desc.replace(buff_found_piece, buff_found_with_url)
				continue
			var wiki = StaticManager.get_wiki_description(item)
			if wiki != "":
				var wiki_piece = "{{0}}".format([item])
				var wiki_with_url = "[color=red][url={\"wiki\":\"" + item + "\"}]" + item + "[/url][/color]"
				desc = desc.replace(wiki_piece, wiki_with_url)
				continue
	if desc.find("<") >= 0:
		var desc_cut_array = desc.split("<")
		for i in desc_cut_array.size():
			if not ">" in desc_cut_array[i]:
				continue;
			var skill_found = desc_cut_array[i].split(">")[0]
			var skill = StaticManager.get_skill(skill_found)
			if skill == null:
			
				continue
			var skill_found_piece = "<{0}>".format([skill_found])
			var skill_found_with_url = "[color=red][url={\"skill\":\"" + skill_found + "\"}]" + skill_found_piece + "[/url][/color]"
			desc = desc.replace(skill_found_piece, skill_found_with_url)
	if desc.find("[") >= 0:
		var desc_cut_array = desc.split("[")
		for i in desc_cut_array.size():
			if not "]" in desc_cut_array[i]:
				continue;
			var tactic = desc_cut_array[i].split("]")[0]
			if not tactic in StaticManager.TACTICS:
				continue
			var tactic_piece = "[{0}]".format([tactic])
			var tactic_with_url = "[color=red][url={\"tactic\":\"" + tactic + "\"}]" + tactic_piece + "[/url][/color]"
			desc = desc.replace(tactic_piece, tactic_with_url)
	return desc
