extends ColorRect

onready var gv = get_node("gv");
onready var cursor = get_node("cursor");
onready var lblexp_rate = get_node("exp_rate");

var cursor_index = 0;
var actorId: int = 0;
var data = {
	"体上限": 0, 
	"武": 0, 
	"知": 0, 
	"政": 0, 
	"统": 0, 
	"胆": 0, 
	"经验": 0, 
	"大限": 0
}

var cityExpRate: int = 100

func _process(delta: float) -> void :
	if not Engine.editor_hint:
		UpdateCursor();

func set_actor(_actorId: int, _cityExpRate: int = 100):
	actorId = _actorId
	cityExpRate = _cityExpRate
	cursor_index = 0
	var actor = ActorHelper.actor(actorId)
	for key in data:
		match key:
			"体上限":
				data[key] = actor.get_max_hp( - 1, - 1, true)
			"经验":
				data[key] = actor.get_exp()
			_:
				data[key] = actor._get_attr_int_original(key)
	update_data()
	var expRate = get_exp_rate()
	lblexp_rate.text = " 折扣:{0}%".format([expRate])
	lblexp_rate.visible = expRate < 100
	return


func update_data():
	for key in data:
		_update_data_by_proname(key)
	get_node("Exp/Value").text = str(data["经验"])
	var actor = ActorHelper.actor(actorId)
	var full = false
	if actor.get_level() >= 8:
		full = true
	$title / needExp.rect_position.x = 167 + int(full) * 40
	$title / Property.rect_position.x = 292 + int(full) * 80
	$title / level.text = "Lv" + str(actor.get_level())
	$title / Next.visible = not full
	for child in gv.get_children():
		var needExp = child.get_node_or_null("NeedExp")
		if needExp == null:
			continue
		needExp.rect_position.x = 81 + int(full) * 40
		var val = child.get_node_or_null("Value")
		if val == null:
			continue
		val.rect_position.x = 230 + int(full) * 80
		var up = child.get_node_or_null("Up")
		if up == null:
			continue
		up.text = ""
		up.visible = not full
	if not full:
		
		var lv_up_proname = ""
		if actor.get_equip_feature_max("强制统系") > 0:
			lv_up_proname = "统"
		var prop_array = ["武", "统", "知", "政"];
		var props = {}
		for prop in prop_array:
			props[prop] = data[prop]
		var lvlups = actor._check_levelup_props(props, lv_up_proname)
		for lvlup in lvlups:
			var prop = str(lvlup[0])
			var val = data[prop] + int(lvlup[1])
			_update_next_level_prop(prop, val)
		
		var maxHP = actor.get_max_hp( - 1, - 1, true)
		var simulatedExtra = actor._get_attr_int_original("体上限")
		if simulatedExtra < 0:
			simulatedExtra = 0
		simulatedExtra += data["体上限"] - maxHP
		maxHP = actor.get_max_hp(actor.get_level() + 1, simulatedExtra, true)
		if maxHP != data["体上限"]:
			_update_next_level_prop("体上限", maxHP)
	return

func _update_next_level_prop(prop: String, val: int):
	for child in gv.get_children():
		if child.editor_description != prop:
			continue
		var up = child.get_node_or_null("Up")
		if up == null:
			continue
		up.text = str(val)
	return

func _update_data_by_proname(proname: String):
	for con in gv.get_children():
		if (con.editor_description != proname):
			continue;
		var lblNeedExp = con.get_node("NeedExp");
		var lblvalue: Label = con.get_node("Value");
		var pre = "";
		var current_value = get_actor_current_provalue(proname);
		if (data[proname] != get_actor_current_provalue(proname)):

			pre = str(current_value) + "→"
		else:
			lblvalue.set("custom_colors/font_color", Color.black);
		var value = data[proname];
		if proname == "大限" and "无大限" == DataManager.get_game_setting("人物大限"):
			lblvalue.text = str("∞");
		else:
			lblvalue.text = pre + str(value);
		lblNeedExp.text = str(_get_need_exp(proname, value))
	return


func UpdateCursor():
	if (gv.get_child_count() == 0):
		return ;

	cursor.rect_position.x = 59;
	cursor.rect_position.y = 66 + cursor_index * gv.get("custom_constants/vseparation");

func move_up():
	var rows = gv.get_child_count();
	var y = cursor_index;
	var x = 0;
	y -= 1;
	if (y < 0):
		y = rows - 1;
	cursor_index = y + x;
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_set_cursor_index", cursor_index);

func move_down():
	var rows = gv.get_child_count();
	var y = cursor_index;
	var x = 0;
	y += 1;
	var newindex = y + x;
	if (newindex >= rows):
		y = 0;
	cursor_index = y + x;
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_set_cursor_index", cursor_index);

func decrease():
	var cursor_con: Control = gv.get_child(cursor_index);
	var lblTitle: Label = cursor_con.get_node("Title");
	var lblValue: Label = cursor_con.get_node("Value");
	var lblNeedExp: Label = cursor_con.get_node("NeedExp");
	var proname = cursor_con.editor_description;
	var value = int(data[proname]);
	if (value <= get_actor_current_provalue(proname)):
		return ;
	value -= 1;
	var _exp = _get_need_exp(proname, value)
	data["经验"] += _exp;
	data[proname] = value;
	update_data();

func increase():
	var cursor_con: Control = gv.get_child(cursor_index)
	var proname = cursor_con.editor_description;
	var value = int(data[proname])
	
	var max_value = 99
	if proname == "大限":
		if "无大限" == DataManager.get_game_setting("人物大限"):
			return
		max_value = 90000
	if value >= max_value:
		return ;
		
	var _exp = _get_need_exp(proname, value)
	if _exp > data["经验"]:
		
		return
	value += 1
	data["经验"] -= _exp
	data[proname] = value
	update_data()
	return

remote func _rpc_set_cursor_index(index: int):
	cursor_index = index;


func _get_need_exp(proname: String, value: int) -> float:
	
	
	
	
	
	
	var need_exp = 200
	var propThresholds = [90, 80, 60, 40, 20]
	var expRequired = [23000, 10200, 3800, 1200, 500]
	for i in propThresholds.size():
		if value >= propThresholds[i]:
			need_exp = expRequired[i]
			break
	if proname == "大限":
		need_exp = 1000
	
	need_exp = int(need_exp * get_exp_rate() / 100)
	return need_exp

func get_actor_current_provalue(proname: String) -> int:
	var actor = ActorHelper.actor(actorId)
	match proname:
		"体上限":
			return actor.get_max_hp( - 1, - 1, true)
		"经验":
			return actor.get_exp()
		_:
			return actor._get_attr_int_original(proname)

func into_actor():
	var actor = ActorHelper.actor(actorId)
	for key in data:
		var val = data[key]
		match key:
			"体上限":
				val = val - actor.get_max_hp( - 1, - 1, true)
				val += max(0, actor._get_attr_int_original(key))
				actor._set_attr_int(key, val)
			"经验":
				
				actor.set_exp(val)
			_:
				actor._set_attr_int(key, val)
	return

func get_exp_rate() -> int:
	var actor = ActorHelper.actor(actorId)
	return int(min(cityExpRate, actor.get_learning_exp_rate()))

func level_reset() -> void :
	var actor = ActorHelper.actor(actorId)
	for attr in ["武", "知", "统", "政"]:
		var val = Global.intval(StaticManager.actors[actorId][attr])
		actor._set_attr_int(attr, val)
	var level = Global.intval(StaticManager.actors[actorId]["等级"])
	actor.set_level(level)
	set_actor(actorId, cityExpRate)
	return

func show_levelup_all() -> void :
	var levels = $Window2.get_node_or_null("levels")
	if levels == null:
		var levelScene: PackedScene = load("res://windows/actor_levels.tscn")
		levels = levelScene.instance()
		levels.set_name("levels")
		$Window2.add_child(levels)
		levels.rect_position = Vector2( - 2, 32)
	levels.init(actorId, data)
	levels.update_data()
	
	$title.hide()
	$gv.hide()
	$cursor.hide()
	$Exp.hide()
	$exp_rate.hide()
	levels.show()
	return

func hide_levelup_all() -> void :
	var levels = $Window2.get_node_or_null("levels")
	if levels == null:
		return
	
	levels.hide()
	$title.show()
	$gv.show()
	$cursor.show()
	$Exp.show()
	$exp_rate.show()
	return
