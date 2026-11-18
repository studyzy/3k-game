extends Control

onready var nrpface = get_node("Control/nprFace");
onready var lblName = get_node("Control/lblName");
onready var lblTypes = get_node("Control/lblTypes");
onready var lblLevel = get_node("Control/lblLevel");
onready var conSkills = get_node("conSkills")

const PAGE_DELTA_VALUE = 128

var styleBoxActive

var actorIds = []
var actorId = - 1
var currentTab = "skill"

onready var tabs = {
	"skill": get_node("Control/FlowTabBox/lblTabSkill"), 
	"background": get_node("Control/FlowTabBox/lblTabBackground"), 
	"equip": get_node("Control/FlowTabBox/lblTabEquip"), 
	"level": get_node("Control/FlowTabBox/lblTabLevel"), 
	"research": get_node("Control/FlowTabBox/lblTabResearch")
}
onready var tabKeys = ["skill", "background", "equip", "level", "research"]

func _ready() -> void :
	styleBoxActive = StyleBoxFlat.new()
	styleBoxActive.bg_color = Color(0, 0, 0)
	_notification(NOTIFICATION_VISIBILITY_CHANGED)
	return

func init_actor(_actorId: int, _actorIds: PoolIntArray = []):
	var is_skill_model = DataManager.get_game_setting("技能系统") == "是";
	for tab in ["skill", "background"]:
		var label: Label = tabs[tab];
		label.visible = is_skill_model;
	
	actorId = _actorId
	conSkills.init_data(actorId)
	if not _actorIds.empty():
		actorIds.clear()
		actorIds.append_array(_actorIds)

	nrpface.set_actor(actorId);
	var actor = ActorHelper.actor(actorId)
	lblName.text = actor.get_name()
	lblTypes.text = "";
	if actor.get_nick() != "":
		lblTypes.text = "字 " + actor.get_nick()
	
	var side = actor.get_side()
	match side:
		"":
			get_node("Control/lblSkillSide").text = ""
		"醉":
			get_node("Control/lblSkillSide").text = "醉乡"
		_:
			get_node("Control/lblSkillSide").text = side + "面"
	
	lblLevel.text = "LV" + str(actor.get_level())

	if currentTab == null or not currentTab in tabs:
		currentTab = tabs.keys()[0];
	switch_tab(currentTab)
	show()
	return

func back():
	match DataManager.get_current_scene_id():
		10000:
			SceneManager.actor_info.switch_to_actor(actorId)
		20000:
			if DataManager.common_variable.has("战争-玩家-步骤")\
			and int(DataManager.common_variable["战争-玩家-步骤"]) == 6:
				var wa = DataManager.get_war_actor(actorId)
				if wa != null:
					var map = SceneManager.current_scene().war_map
					map.set_cursor_location(wa.position, true)
					DataManager.common_variable["武将"] = actorId
					map.camer_to_actorId(actorId, "actor_info")
	get_tree().paused = false;
	hide();
	return

func _on_Button_pressed() -> void :
	back()
	return

func _physics_process(delta: float) -> void :
	if not visible:
		return
	get_tree().paused = true
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		var tabIndex = tabKeys.find(currentTab)
		tabIndex = max(0, tabIndex - 1)
		switch_tab(tabKeys[tabIndex])
		return
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		var tabIndex = tabKeys.find(currentTab)
		tabIndex = min(tabKeys.size() - 1, tabIndex + 1)
		switch_tab(tabKeys[tabIndex])
		return
	if Input.is_action_just_pressed("ANALOG_UP"):
		scroll_up()
		return
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		scroll_down()
		return
	if Input.is_action_just_pressed("EMU_SELECT"):
		back()
		return
	if actorIds.empty():
		return
	var index = actorIds.find(actorId)
	var changed = false
	if Global.is_action_pressed_BY():
		index = ((index - 1) + actorIds.size()) % actorIds.size()
		changed = true
	if Global.is_action_pressed_AX():
		index = (index + 1) % actorIds.size()
		changed = true
	if changed:
		if index >= 0 and index < actorIds.size():
			var new_actorId = actorIds[index]
			if new_actorId == actorId:
				return
			init_actor(new_actorId, actorIds)
	return

func switch_tab(tab: String):
	if not tab in tabs:
		return
	currentTab = tab
	for t in tabs.values():
		t.add_stylebox_override("normal", null)
		t.set("custom_colors/font_color", Color(0, 0, 0))
	
	if not tabs[tab].visible:
		for t in tabs.keys():
			if not tabs[t].visible:
				continue;
			currentTab = t;
			tab = t;
			break
	tabs[tab].add_stylebox_override("normal", styleBoxActive)
	tabs[tab].set("custom_colors/font_color", Color(1, 1, 1))

	var method = "switch_mode_" + tab
	if conSkills.has_method(method):
		conSkills.call(method)
	if SceneManager.portrait_mode:
		reset_layout_portrait()
	else:
		reset_layout_landscape()
	return

func scroll_up():
	conSkills.scroll_up()
	return

func scroll_down():
	conSkills.scroll_down()
	return

func reset_layout_portrait():
	rect_scale = Vector2(1.70666, 1.6)
	rect_position = Vector2(0, 0)
	return

func reset_layout_landscape():
	rect_scale = Vector2(1.0, 1.0)
	rect_position = Vector2(212, 0)
	return

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			set_process(true)
			set_physics_process(true)
		else:
			set_process(false)
			set_physics_process(false)
	return
