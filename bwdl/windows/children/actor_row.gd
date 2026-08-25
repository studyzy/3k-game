# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/children/actor_row.gd
# 说明：武将行子控件。列表中的一行武将。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

tool
extends Control

onready var delete_line = get_node("delete_line");
onready var sploy100 = get_node("Loy100");

export (int) var actorId = - 1;
export (bool) var is_picked = false;

export (bool) var highlighted = false

var actorProperties: PoolStringArray = []
var mixed = false

func _ready() -> void :
	set_picked(false);
	set_actor();
	return
	

func set_actor() -> void :
	set_delete_line(false);
	sploy100.visible = false
	if actorId == - 1:
		for i in range(1, 7):
			get_node("prop{0}".format([i])).hide()
		$name.text = "结束"
		return
	var actor = ActorHelper.actor(actorId)
	$name.text = actor.get_name()
	$name.set("custom_colors/font_color", Color.black)
	if mixed and actor.is_status_captured():
		$name.set("custom_colors/font_color", StaticManager.COLOR_CAPTURED)
	if is_highlighted():
		$name.set("custom_colors/font_color", StaticManager.COLOR_HIGHLIGHTED)
	for i in actorProperties.size():
		
		var color = Color.white
		var node: Label = get_node("prop{0}".format([i + 1]))
		var prop = actorProperties[i]
		var val = actor._get_attr_int(prop)
		if prop == "经验":
			val = actor.get_exp()
		elif not actor._has_attr(prop):
			continue
		var maxVal = val
		node.text = str(val)
		node.align = Label.ALIGN_RIGHT
		node.rect_size.x = 43
		node.rect_position.y = 9
		if prop == "忠":
			maxVal = 99
			if val == 100:
				sploy100.position.x = node.rect_position.x + 22
				node.visible = false
				sploy100.visible = true
		elif prop == "体":
			maxVal = actor.get_max_hp()
		elif prop == "等级":
			node.align = Label.ALIGN_CENTER
		elif i == 5:
			node.rect_size.x = 87
			color = Color.black
			if prop in StaticManager.EQUIPMENT_TYPES:
				var equip = actor.get_equip(prop)
				node.set("custom_fonts/font", Global.get_font(30))
				node.rect_position.y = 13
				node.text = equip.name()
				color = equip.get_name_color()
				node.rect_position.x = 415
				node.align = Label.ALIGN_LEFT
			elif prop == "兵力":
				color = actor.get_troops_type_color()
				node.rect_position.x = 471
			elif prop == "经验":
				val = actor.get_exp()
				node.text = str(val)
				node.align = Label.ALIGN_RIGHT
				node.set("custom_fonts/font", Global.get_font(32))
				node.rect_position.y = 12
				node.rect_position.x = 436
				node.rect_size.x = 120
				if actor.get_learning_exp_rate() < 100:
					color = Color.blue
				if int(actor.get_equip_attr_max("避免升级")) > 0:
					color = Color.red
			else:
				node.rect_position.x = 466
		if is_highlighted():
			color = StaticManager.COLOR_HIGHLIGHTED
		
		if color == Color.white:
			if val > 99:
				color = StaticManager.COLOR_EXCEEDED
				node.rect_position.x -= 12
			elif val * 10 < maxVal * 3:
				color = StaticManager.COLOR_LOW
			else:
				color = Color.black
		node.set("custom_colors/font_color", color)
	return

func set_sodiers(sodiers: int):
	if actorId >= 0:
		get_node("prop6").text = str(sodiers)

func set_picked(b: bool):
	is_picked = b;
	get_node("Selected").visible = b;


func set_delete_line(b: bool):
	delete_line.visible = b;
	if not b:
		return ;
	var text = "";
	for i in get_node("name").text.length():
		text += "—";
	delete_line.text = text;
	return

func set_highlighted(b: bool) -> void :
	if highlighted != b:
		highlighted = b
		set_actor()
		visible = false
	return

func is_highlighted() -> bool:
	return highlighted
