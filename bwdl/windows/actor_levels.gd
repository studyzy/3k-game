extends Control

export var actorId: int = - 1

onready var headers = {
	"武": get_node("static/header/武"), 
	"知": get_node("static/header/知"), 
	"统": get_node("static/header/统"), 
	"政": get_node("static/header/政"), 
	"经": get_node("static/header/经"), 
}
onready var current = {
	"LV": get_node("static/current/level"), 
	"武": get_node("static/current/武"), 
	"知": get_node("static/current/知"), 
	"统": get_node("static/current/统"), 
	"政": get_node("static/current/政"), 
	"经": get_node("static/current/经"), 
}
onready var statics = get_node("static")
onready var dynamic = get_node("static/dynamic")

var conSkills: Control = null

var data: Dictionary = {}


func _ready() -> void :
	update_data()
	return

func attach_to(_conSkills: Control) -> void :
	conSkills = _conSkills
	return

func update_data() -> void :
	var levelUpSettings = StaticManager.get_levelup_setting()
	var actor = ActorHelper.actor(actorId)
	var level = actor.get_level()
	current["LV"].text = "LV{0}".format([level])
	current["LV"].set("custom_colors/font_color", Color.blue)
	current["经"].text = "--"
	var props = {}
	for key in current:
		if key in actor.ATTR_DICT:
			var val = actor._get_attr_int_original(key)
			if key in data:
				val = data[key]
			current[key].text = str(val)
			props[key] = val
	Global.clearNode(dynamic)
	for i in range(level + 1, 9):
		var expRequipred = levelUpSettings["所需经验"][i - 1] * 100
		var expLeft = expRequipred - data["经验"]
		var next = statics.get_node("current").duplicate(true)
		next.get_node("level").text = "LV{0}".format([i])
		next.get_node("level").set("custom_colors/font_color", Color.black)
		next.get_node("经").text = "{0}".format([expLeft])
		if expLeft <= 0:
			next.get_node("经").text = "--"
		dynamic.add_child(next)
		next.rect_position.y = (i - level - 1) * 50
		var specified = ""
		if actor.get_equip_feature_max("强制统系") > 0:
			specified = "统"
		var lvlups = actor._check_levelup_props(props, specified)
		for lvlup in lvlups:
			props[lvlup[0]] += int(lvlup[1])
			next.get_node(lvlup[0]).set("custom_colors/font_color", Color.red)
		for key in props:
			next.get_node(key).text = str(props[key])
	dynamic.rect_min_size.y = max(260, 50 * (8 - level) + 30)
	statics.rect_min_size.y = dynamic.rect_min_size.y + 130
	return

func init(_actorId: int, _data: Dictionary = {}) -> void :
	actorId = _actorId
	data = _data.duplicate(true)
	if not "经验" in data:
		var actor = ActorHelper.actor(actorId)
		data["经验"] = actor.get_exp()
	return

func fit_height() -> float:
	return statics.rect_min_size.y
