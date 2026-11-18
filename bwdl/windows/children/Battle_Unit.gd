extends Control

class BattleUnitAction:
	var bu: Battle_Unit;
	var action_name: String = "";
	var from_position: Vector2
	var to_position: Vector2;

const block_size = 40;
var before_times = 0;
var move_times = 1;
var atk_times = 0.18;
var shoot_times = 0.08;
var hp_show = false;
var is_ready = false;
var self_action_name = "";


var unitId = - 1;

onready var hp_rect = get_node("images/conRect");
onready var lblhp = get_node("images/conRect/lblValue");
onready var beat_effect = get_node("beat_effect");
onready var beat_defence = get_node("beat_defence");
onready var sharp_melee = get_node("sharp_melee");
onready var effect_images = get_node("effect_images");
onready var actioning = get_node("actioning");
onready var animation_hurt = get_node("animation_hurt");

onready var sp_A = get_node("images/A")
onready var sp_B = get_node("images/B")
onready var spCloud = get_node("images/cloud")

onready var buff_A = get_node("buff/A")
onready var buff_B = get_node("buff/B")


var Type: String = ""

var bua: BattleUnitAction = null;


var action_end_on_hurt = true;

const dic_imgs_position = [
	Vector2(0, 1), 
	Vector2( - 1, 0), 
	Vector2(1, 0), 
	Vector2(0, - 1), 
];

var iUnitLogic

func _ready() -> void :
	if ( not DataManager.battle_run):
		return ;
	get_node("buff/A").material = load_shader()
	get_node("buff/B").material = load_shader()
	$tornado.hide()
	$status.hide()
	hide_effect();
	update_unit();
	effect_images.show();
	actioning.get_node("Label").text = str(unitId);
	is_ready = true;
	iUnitLogic = Global.load_script(DataManager.mod_path + "sgz_script/battle/IUnitLogic.gd")
	return

func load_shader() -> Material:
	
	var shaderCode = load("res://SHADER/battle_unit.gdshader")
	var shader = ShaderMaterial.new()
	shader.shader = shaderCode
	return shader


func update_unit():
	if unitId < 0 or unitId >= DataManager.battle_units.size():
		return
	var bu: Battle_Unit = DataManager.battle_units[unitId]
	var texture = bu.get_texture()
	set_texture(texture, bu.direction)
	rect_position = bu.unit_position * block_size
	Type = bu.Type
	bu.requires_update = false
	_set_buff_color()
	return

func _set_buff_color():
	var buff_color = Vector3(1, 1, 0);
	var debuff_color = Vector3(0.41, 0.41, 0.41);
	
	var bu: Battle_Unit = DataManager.battle_units[unitId];
	if bu.leaderId == - 1:
		
		get_node("buff").hide()
		return
	if bu.Type == "城门":
		get_node("buff").hide();
		return

	var buff_A = get_node("buff/A");
	var buff_B = get_node("buff/B");
	var buff = 0
	
	for key in ["骁果", "暴走", "BUFF"]:
		if bu.get_combat_val_min(key, 0) < 0:
			buff = - 1
		if bu.get_combat_val_max(key, 0) > 0:
			buff = 1
	if buff == 0:
		if bu.get_extra_damage_rate() > 0:
			buff = 1
		elif bu.get_extra_damage_rate() < 0:
			buff = - 1
	if buff == 0:
		if bu.get_extra_damage_avoid_rate() > 0:
			buff = 1
		elif bu.get_extra_damage_avoid_rate() < 0:
			buff = - 1
	if buff == 1:
		buff_A.material.set_shader_param("color_rgb", buff_color)
		buff_B.material.set_shader_param("color_rgb", buff_color)
		get_node("buff").show()
	elif buff == - 1:
		buff_A.material.set_shader_param("color_rgb", debuff_color)
		buff_B.material.set_shader_param("color_rgb", debuff_color)
		get_node("buff").show()
	else:
		get_node("buff").hide()
	return

func is_task_run():
	if ($TweenAttack.is_active()):
		return true;
	if ($TweenShoot.is_active()):
		return true;
	if (animation_hurt.is_playing()):
		return true;
	if bua != null:
		return true;
	return false;

func _process(delta: float) -> void :
	if ( not is_ready):
		return ;
	if bua != null:
		_action_process(delta);
		return ;
	if (FlowManager.has_task()):
		return ;
	
	if (is_task_run()):
		return ;
	if (unitId >= DataManager.battle_units.size()):
		return ;
	var bu: Battle_Unit = DataManager.battle_units[unitId];
	if (bu.wait_action_name != "" and self_action_name != bu.wait_action_name):
		_deal_action(bu);
		return ;
	rect_position = bu.unit_position * block_size;
	return

func _on_Timer_timeout() -> void :
	if not is_ready:
		return
	if unitId >= DataManager.battle_units.size():
		return
	var bu: Battle_Unit = DataManager.battle_units[unitId]

	spCloud.visible = false
	var offset = Vector2.ZERO
	if bu.get_combat_val_max("仙兵") > 0:
		offset.y = - 10
		spCloud.visible = true
	sp_A.frame_coords = Vector2(bu.direction, 0)
	sp_A.offset = offset
	sp_B.frame_coords = Vector2(bu.direction, 1)
	sp_B.offset = offset

	if Type != bu.Type or bu.requires_update:
		update_unit()
	hp_rect.visible = hp_show
	var hp = int(ceil(bu.get_hp()))
	lblhp.text = str(min(999, hp))
	var chp = Color.white
	if Type == "将":
		if hp < 13:
			chp = Color.red
		elif hp < 50:
			chp = Color.orange
	lblhp.set("custom_colors/font_color", chp)
	return


func _deal_action(bu: Battle_Unit):
	var from = bu.unit_position;
	var action_name = str(bu.wait_action_name).split("|")[0];
	
	var params = [];
	for s in bu.wait_action_name.split("|"):
		if (s == action_name):
			continue;
		params.append(s);
	self_action_name = bu.wait_action_name;
	bu.default_direction = bu.direction;
	bu.last_action_name = action_name;
	
	match action_name:
		"待机":
			bu.wait_action_times = 0
			action_end()
		"移动":
			var new_x = int(str(params[0]).split(",")[0]);
			var new_y = int(str(params[0]).split(",")[1]);
			var new_position = Vector2(new_x, new_y);
			_play_move(bu, new_position);
		"攻击":
			var new_x = int(str(params[0]).split(",")[0]);
			var new_y = int(str(params[0]).split(",")[1]);
			var new_position = Vector2(new_x, new_y);
			var all_units = get_all_attack_unit();
			bu.last_attack_units = [];
			for unit in all_units:
				bu.last_attack_units.append(unit.unitId);
			var attackType = ""
			if params.size() >= 3:
				attackType = params[2]
			_play_attack(bu, new_position, attackType);
		"射箭":
			var new_x = int(str(params[0]).split(",")[0]);
			var new_y = int(str(params[0]).split(",")[1]);
			var new_position = Vector2(new_x, new_y);
			bu.last_attack_units = [];
			var all_units = get_all_attack_unit();
			for unit in all_units:
				bu.last_attack_units.append(unit.unitId);
			_play_arrow(bu, new_position, all_units);
		"投掷":
			var x = int(str(params[0]).split(",")[0]);
			var y = int(str(params[0]).split(",")[1]);
			var targetPos = Vector2(x, y)
			var frame = 0
			if params.size() > 1:
				frame = int(params[1])
			bu.last_attack_units = []
			var all_units = get_all_attack_unit()
			for unit in all_units:
				bu.last_attack_units.append(unit.unitId)
			_play_bolas(bu, targetPos, frame)
		"受击":
			animation_hurt.play("hurt");
		"被斩杀":
			bu.set_hp(0, true)
			animation_hurt.play("hurt")
		"反击":
			var x = int(str(params[0]).split(",")[0])
			var y = int(str(params[0]).split(",")[1])
			_counter_attack(bu, x, y)
		"暴走":
			var x = int(str(params[0]).split(",")[0])
			var y = int(str(params[0]).split(",")[1])
			var times = int(params[1])
			_go_ballistic(bu, x, y, times)
		"游走":
			var x = int(str(params[0]).split(",")[0])
			var y = int(str(params[0]).split(",")[1])
			var times = int(params[1])
			_go_ranger(bu, x, y, times)
		"击退":
			var x = int(str(params[0]).split(",")[0])
			var y = int(str(params[0]).split(",")[1])
			var pos = Vector2(x, y)
			_play_move(bu, pos, true)
		"减体":
			_play_hp_trick(bu)
		"伏尘":
			_play_tornado(bu)
		"状态":
			var tips = str(params[0]).split(",")
			show_special_tips(bu, tips, true, false)
		_:
			FlowManager.add_flow("unit_actioned");
	return

func _on_TweenAttack_tween_completed(object: Object, key: NodePath) -> void :
	return


func action_reset(bu: Battle_Unit):
	$status.hide()
	$tornado.hide()
	animation_hurt.play("RESET");
	bu.direction = bu.default_direction;
	hide_effect();
	self_action_name = "";
	bu.wait_action_name = "";
	bu.direction = bu.default_direction;
	bu.clear_once_flags()
	return



func action_end():
	var tarbu = get_attack_unit();
	var frombu = get_from_unit();
	if (tarbu != null and frombu != null and frombu.unitId == self.unitId):
		var prev_hp: float = tarbu.get_hp();
		for t in get_all_attack_unit():
			t.count_hurt_by(frombu);
		DataManager.common_variable.erase("白兵.攻击目标");

		
		var cur_hp: float = tarbu.get_hp();
		_check_reflect_damage(frombu, tarbu, prev_hp - cur_hp)
	
	if (frombu != null and frombu.unitId == unitId):
		DataManager.common_variable.erase("白兵.攻击来源");

	var bu: Battle_Unit = DataManager.battle_units[unitId]
	var extraDamageToSettle = Global.floatval(bu.get_tmp_variable("待结算伤害", - 1.0))
	if extraDamageToSettle > 0:
		bu.set_hp(bu.get_hp() - extraDamageToSettle, true)
	bu.set_tmp_variable("待结算伤害", null)
	action_reset(bu)
	var currentActionId = DataManager.get_env_int("白兵.行动单位")
	if currentActionId == bu.unitId:
		FlowManager.add_flow("unit_actioned")
	return


func _on_animation_hurt_animation_finished(anim_name: String) -> void :
	match anim_name:
		"RESET":
			return
		"hurt":
			if action_end_on_hurt:
				action_end()
			action_end_on_hurt = true
	return




func _play_move(bu: Battle_Unit, to: Vector2, backward: bool = false):
	animation_hurt.play("RESET")
	
	if bu.get_side() == Vector2.RIGHT:
		var targetUnit = DataManager.get_battle_unit_by_position(to)
		if targetUnit != null and not targetUnit.disabled and targetUnit.get_unit_type() == "城门":
			targetUnit.disabled = true
			SoundManager.play_se2("res://resource/sounds/se/open_gate.ogg")

	if not bu.can_move_to_position(to):
		action_end()
		return
	var from = bu.unit_position;
	
	if (to.x < from.x):
		bu.direction = 1;
	elif (to.x > from.x):
		bu.direction = 2;
	elif (to.y < from.y):
		bu.direction = 3;
	elif (to.y > from.y):
		bu.direction = 0;
	if backward:
		bu.direction = 3 - bu.direction;
	
	if (bu.default_direction != bu.direction):
		bu.default_direction = bu.direction;
		
		update_unit();
	
	var distance = abs(from.x - to.x) + abs(from.y - to.y);

	bua = BattleUnitAction.new();
	bua.bu = bu;
	bua.action_name = "移动";
	bua.from_position = bu.unit_position * block_size;
	bua.to_position = to * block_size;
	return


func _play_arrow(bu: Battle_Unit, shoot_to: Vector2, targets: Array):

	if (shoot_to.x < bu.unit_position.x):
		bu.direction = 1;
	elif (shoot_to.x > bu.unit_position.x):
		bu.direction = 2;
	elif (shoot_to.y < bu.unit_position.y):
		bu.direction = 3;
	elif (shoot_to.y > bu.unit_position.y):
		bu.direction = 0;
		
	var dic_sp_rotation = {
		"0": 180, 
		"1": - 90, 
		"2": 90, 
		"3": 0
	};

	var arrow = get_node("effect_images/arrow");
	var arrow_sp = get_node("effect_images/arrow/sprite");
	arrow_sp.rotation_degrees = int(dic_sp_rotation[str(bu.direction)]);

	arrow_sp.frame = 0
	if bu.get_combat_val_max("双矢") > 0:
		var rng = bu.get_combat_val_max("双矢")
		if Global.get_distance(bu.unit_position, shoot_to) <= rng:
			bu.append_once_attack_tag("双矢", 1)
			arrow_sp.frame = 2
	elif bu.is_fire_shooting(targets):
		if bu.get_combat_val_max("火矢") > 0:
			bu.append_once_attack_tag("火矢#FF0000", 1)
		arrow_sp.frame = 1

	var distance = abs(bu.unit_position.x - shoot_to.x) + abs(bu.unit_position.y - shoot_to.y);
	var total_time = distance * shoot_times;
	var shoot_from = Vector2(0, 0);
	shoot_to -= bu.unit_position;
	arrow.rect_position = shoot_from * block_size;
	update_unit();
	is_shooting = 0;
	$TweenShoot.interpolate_property(
		arrow, 
		"rect_position", 
		shoot_from * block_size, 
		shoot_to * block_size, 
		total_time, 
		Tween.TRANS_LINEAR, 
		0, 
		before_times)
	
	$TweenShoot.start();
	arrow.show();

	
	bu.check_critical_hit(true, targets)

	beat_effect.rect_position = dic_imgs_position[bu.direction] * block_size / 2;
	var tag = bu.get_once_attack_tag()
	if tag != "":
		var color = "00B3FF"
		if tag.find("#") > 0:
			color = tag.split("#")[1]
			tag = tag.split("#")[0]
		beat_effect.get_node("lblValue").set("custom_colors/font_color", Color(color))
		beat_effect.get_node("lblValue").text = tag
		beat_effect.get_node("lblValue").show()
		beat_effect.get_node("sprite").hide()
		beat_effect.show()
	else:
		beat_effect.get_node("lblValue").hide()
		beat_effect.get_node("sprite").show()
		beat_effect.show()
	return


func _play_bolas(bu: Battle_Unit, shoot_to: Vector2, frame: int = 0):
	if (shoot_to.x < bu.unit_position.x):
		bu.direction = 1;
	elif (shoot_to.x > bu.unit_position.x):
		bu.direction = 2;
	elif (shoot_to.y < bu.unit_position.y):
		bu.direction = 3;
	elif (shoot_to.y > bu.unit_position.y):
		bu.direction = 0;

	var dic_sp_rotation = {
		"0": 180, 
		"1": - 90, 
		"2": 90, 
		"3": 0
	};

	var bolas = get_node("effect_images/bolas");
	var bolas_sp = get_node("effect_images/bolas/sprite");
	bolas_sp.frame = frame
	bolas_sp.rotation_degrees = int(dic_sp_rotation[str(bu.direction)])

	var distance = abs(bu.unit_position.x - shoot_to.x) + abs(bu.unit_position.y - shoot_to.y);
	var total_time = distance * shoot_times;
	var shoot_from = Vector2(0, 0);
	shoot_to -= bu.unit_position;
	bolas.rect_position = shoot_from * block_size;
	update_unit();
	is_shooting = 0

	if frame == 3:
		
		_arc_node = bolas
		_arc_from = shoot_from * block_size
		_arc_to = shoot_to * block_size
		_arc_height = distance * block_size * 0.4
		$TweenShoot.interpolate_method(
			self, 
			"_bolas_arc_update", 
			0.0, 
			1.0, 
			total_time, 
			Tween.TRANS_LINEAR, 
			Tween.EASE_IN, 
			before_times)
	else:
		$TweenShoot.interpolate_property(
			bolas, 
			"rect_position", 
			shoot_from * block_size, 
			shoot_to * block_size, 
			total_time, 
			Tween.TRANS_SINE, 
			Tween.EASE_IN_OUT, 
			before_times)

	$TweenShoot.start()
	bolas.show()

	beat_effect.rect_position = dic_imgs_position[bu.direction] * block_size / 2;
	return


func _bolas_arc_update(t: float):
	if _arc_node == null:
		return
	var x = lerp(_arc_from.x, _arc_to.x, t)
	var y = lerp(_arc_from.y, _arc_to.y, t) - _arc_height * 4.0 * t * (1.0 - t)
	_arc_node.rect_position = Vector2(x, y)

var is_shooting = 0;


var _arc_node: Control = null
var _arc_from: Vector2 = Vector2.ZERO
var _arc_to: Vector2 = Vector2.ZERO
var _arc_height: float = 0.0

func _shoot_end():
	is_shooting += 1;
	if (is_shooting < 2):
		return ;
	for con in get_node("effect_images").get_children():
		con.hide();
	for t in get_all_attack_unit():
		t.wait_action_name = "受击";
	
	var is_defence = false;
	var bu = get_from_unit();
	if bu != null and not bu.dic_other_variable.has("被格挡"):
		var mainTargetUnit = get_attack_unit()
		var rate = mainTargetUnit.get_runtime_blocking_rate(bu)
		if Global.get_rate_result(rate):
			is_defence = true;
			bu.dic_other_variable["被格挡"] = 1;

	if is_defence:
		beat_defence.rect_position = dic_imgs_position[bu.direction] * block_size / 2;
		beat_defence.show();
		SoundManager.play_se("res://resource/sounds/se/ding.ogg", self, "action_end");
	else:
		SoundManager.play_se("res://resource/sounds/se/Arrow_ToUnit.ogg", self, "action_end");
	return

func _on_TweenShoot_tween_started(object: Object, key: NodePath) -> void :
	SoundManager.play_se("res://resource/sounds/se/arrow.ogg", self, "_shoot_end");
	return


func _on_TweenShoot_tween_completed(object: Object, key: NodePath) -> void :
	_shoot_end();
	return

func _play_attack(bu: Battle_Unit, attack_to: Vector2, attackType: String = ""):
	if (attack_to.x < bu.unit_position.x):
		bu.direction = 1;
	elif (attack_to.x > bu.unit_position.x):
		bu.direction = 2;
	elif (attack_to.y < bu.unit_position.y):
		bu.direction = 3;
	elif (attack_to.y > bu.unit_position.y):
		bu.direction = 0;
	
	var distance = abs(bu.unit_position.x - attack_to.x) + abs(bu.unit_position.y - attack_to.y);
	var total_time = atk_times;
	update_unit();
	var targets = get_all_attack_unit()
	for t in targets:
		t.wait_action_name = "受击";
	
	var is_defence = false;
	
	if not bu.dic_other_variable.has("被格挡"):
		var mainTargetUnit: Battle_Unit = get_attack_unit();
		if mainTargetUnit != null:
			var blockRate = mainTargetUnit.get_runtime_blocking_rate(bu)
			if Global.get_rate_result(blockRate):
				is_defence = true;
				bu.dic_other_variable["被格挡"] = 1

	if attackType in ["反击"]:
		sharp_melee.rect_position = dic_imgs_position[bu.direction] * block_size / 2;
		sharp_melee.get_node("lblValue").text = attackType
		sharp_melee.show();
		SoundManager.play_se("res://resource/sounds/se/Battle_Attacking.ogg", self, "action_end");
		return

	
	bu.check_critical_hit(false, targets)

	if is_defence:
		
		beat_defence.rect_position = dic_imgs_position[bu.direction] * block_size / 2;
		beat_defence.show();
		SoundManager.play_se("res://resource/sounds/se/ding.ogg", self, "action_end")
		return

	
	beat_effect.rect_position = dic_imgs_position[bu.direction] * block_size / 2;
	var tag = bu.get_once_attack_tag()
	if tag != "":
		var color = "00B3FF"
		if tag.find("#") > 0:
			color = tag.split("#")[1]
			tag = tag.split("#")[0]
		beat_effect.get_node("lblValue").set("custom_colors/font_color", Color(color))
		beat_effect.get_node("lblValue").text = tag
		beat_effect.get_node("lblValue").show()
		beat_effect.get_node("sprite").show()
		beat_effect.show()
	else:
		beat_effect.get_node("lblValue").hide()
		beat_effect.get_node("sprite").show()
		beat_effect.show()
	SoundManager.play_se(bu.get_once_attack_se(), self, "action_end");
	return


func hide_effect():
	for eff_node in effect_images.get_children():
		eff_node.hide();
	beat_effect.hide();
	beat_effect.get_node("lblValue").hide();
	beat_defence.hide();
	sharp_melee.hide();
	animation_hurt.play("RESET");
	return


func get_attack_unit() -> Battle_Unit:
	var targets = DataManager.get_env_int_array("白兵.攻击目标")
	if targets.empty():
		return null
	var unitId = targets[0]
	if unitId < 0 or unitId >= DataManager.battle_units.size():
		return null
	return DataManager.battle_units[unitId]

func get_all_attack_unit() -> Array:
	var ret = []
	var targets = DataManager.get_env_int_array("白兵.攻击目标")
	for unitId in targets:
		if unitId < 0 or unitId >= DataManager.battle_units.size():
			continue
		ret.append(DataManager.battle_units[unitId])
	return ret

func get_from_unit() -> Battle_Unit:
	if ( not DataManager.common_variable.has("白兵.攻击来源")):
		return null;
	var unitId = int(DataManager.common_variable["白兵.攻击来源"]);
	return DataManager.battle_units[unitId];






func _check_reflect_damage(fromUnit: Battle_Unit, toUnit: Battle_Unit, damage: float) -> float:
	if fromUnit.get_unit_type() in ["将", "城门"]:
		return - 1.0
	if not toUnit.dic_combat.has("反伤倍率"):
		return - 1.0

	var reflectRate: float = float(toUnit.dic_combat["反伤倍率"])
	var reflectDamage: float = max(1.0, reflectRate * damage)
	fromUnit.set_hp(max(0.0, fromUnit.get_hp() - reflectDamage))
	_play_hp_trick(fromUnit, "反伤#FF0000")
	return reflectDamage


func _counter_attack(unit: Battle_Unit, x: int, y: int):
	var target_pos = Vector2(x, y)
	var target_unit = DataManager.get_battle_unit_by_position(target_pos)
	if target_unit == null:
		action_end()
		return
	unit.last_attack_units = [target_unit.unitId]
	DataManager.common_variable["白兵.攻击来源"] = unit.unitId
	DataManager.common_variable["白兵.攻击目标"] = [target_unit.unitId]
	_play_attack(unit, target_pos, "反击")


func _go_ballistic(unit: Battle_Unit, x: int, y: int, times: int):
	if not unit.dic_combat.has("暴走.初始位置"):
		
		unit.dic_combat["暴走.初始位置"] = "{0},{1}".format([
			unit.unit_position.x, unit.unit_position.y
		])
	if not unit.dic_combat.has("暴走.原始行动次数"):
		
		unit.dic_combat["暴走.原始行动次数"] = unit.wait_action_times
	
	var stopped: int = 0
	var wa: War_Actor = DataManager.get_war_actor(unit.leaderId)
	var ea: War_Actor = wa.get_battle_enemy_war_actor()
	stopped = ea.get_buff("咒缚")["回合数"]
	if stopped > 0:
		unit.dic_combat["暴走.咒缚回合"] = stopped
		
		ea.dic_buffs["咒缚"]["回合数"] = 0

	if times == 0:
		
		
		var originalPosInfo = str(unit.dic_combat["暴走.初始位置"]).split(",")
		var originalPos = Vector2(originalPosInfo[0], originalPosInfo[1])
		
		if unit.dic_combat.has("暴走.咒缚回合"):
			var prevStopped: int = int(unit.dic_combat["暴走.咒缚回合"])
			ea.dic_buffs["咒缚"]["回合数"] = prevStopped
		
		if unit.dic_combat.has("暴走.原始行动次数"):
			unit.wait_action_times = int(unit.dic_combat["暴走.原始行动次数"])
		else:
			unit.wait_action_times = 2
		unit.dic_combat.erase("暴走")
		unit.dic_combat.erase("暴走.初始位置")
		unit.dic_combat.erase("暴走.咒缚回合")
		unit.dic_combat.erase("暴走.原始行动次数")
		unit.requires_update = true
		
		_play_move(unit, originalPos)
		return

	unit.dic_combat["暴走"] = 1
	unit.requires_update = true

	
	var bia = Battle_Instant_Action.new()
	bia.unitId = unit.unitId
	bia.action = "暴走"
	bia.targetUnitId = - 1
	bia.targetPos = Vector2(x, y)
	bia.actionTimes = times - 1

	var dic = iUnitLogic.check_action(unit)
	if dic.empty():
		unit.wait_action_times = 0
		bia.actionTimes = 0
		bia.insert_to_env()
		action_end()
		return

	bia.insert_to_env()
	var nextPos = Vector2( - 1, - 1)
	if dic.has("目标坐标"):
		var posSetting = str(dic["目标坐标"]).split(",")
		nextPos = Vector2(int(posSetting[0]), int(posSetting[1]))
	match dic["行为方式"]:
		"单挑":
			DataManager.common_variable["白兵.行动单位"] = unit.unitId;
			FlowManager.add_flow("go_to_solo");
		"移动":
			_play_move(unit, nextPos)
		"射箭":
			_play_arrow(unit, nextPos, get_all_attack_unit())
		"投掷":
			_play_bolas(unit, nextPos)
		"攻击":
			_play_attack(unit, nextPos)
		_:
			action_end()


func _go_ranger(unit: Battle_Unit, x: int, y: int, times: int):
	if not unit.dic_combat.has("游走.原始行动次数"):
		
		unit.dic_combat["游走.原始行动次数"] = unit.wait_action_times
	
	if times == 0:
		
		
		if unit.dic_combat.has("游走.原始行动次数"):
			unit.wait_action_times = int(unit.dic_combat["游走.原始行动次数"])
		else:
			unit.wait_action_times = 1
		unit.dic_combat.erase("游走")
		unit.dic_combat.erase("游走.原始行动次数")
		unit.requires_update = true
		action_end()
		return

	unit.dic_combat["游走"] = 1
	unit.requires_update = true

	
	var bia = Battle_Instant_Action.new()
	bia.unitId = unit.unitId
	bia.action = "游走"
	bia.targetUnitId = - 1
	bia.targetPos = Vector2(x, y)
	bia.actionTimes = times - 1

	
	if not unit.can_move_to_position(bia.targetPos):
		unit.wait_action_times = 0
		bia.actionTimes = 0
		bia.insert_to_env()
		action_end()
		return

	bia.insert_to_env()
	_play_move(unit, bia.targetPos, true)
	return

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	

func _play_hp_trick(bu: Battle_Unit, tag: String = ""):
	action_end_on_hurt = false
	animation_hurt.play("hurt")
	if tag != "":
		show_special_tips(bu, [tag])
	return

func _action_process(delta: float) -> void :
	if bua == null:
		return ;
	match bua.action_name:
		"移动":
			var speed = 0.15;
			var dist_total = bua.to_position - bua.from_position;
			if bua.to_position == bua.bu.unit_position * block_size:
				bua = null;
				action_end();
				return ;
			var dist_unit_step = dist_total / move_times * delta * speed;
			
			bua.bu.unit_position.x += dist_unit_step.x;
			bua.bu.unit_position.y += dist_unit_step.y;

			var dist_curr = bua.to_position - bua.bu.unit_position * block_size;
			
			
			
			if dist_total.x * dist_curr.x <= 0:
				bua.bu.unit_position.x = int(bua.to_position.x / block_size);
				
			if dist_total.y * dist_curr.y <= 0:
				bua.bu.unit_position.y = int(bua.to_position.y / block_size);
			
			rect_position = bua.bu.unit_position * block_size;
			
			if bua.to_position == bua.bu.unit_position * block_size:
				bua = null;
				action_end();
				return ;
	return

func show_special_tips(bu: Battle_Unit, tips: Array, endAction: bool = false, beatEffect: bool = true) -> void :
	var msg = "{0}#{1} 标签特殊行动结束".format([
		bu.Type, bu.unitId, 
	])
	if not tips.empty():
		msg = "{0}#{1} 标签特殊行动{2}".format([
			bu.Type, bu.unitId, tips[0]
		])
	DataManager.game_trace(msg)
	var lbl = $lblStatus
	if tips.empty():
		lbl.text = ""
		lbl.hide()
		if endAction:
			action_end()
		return
	var tip = tips.pop_front()
	lbl.rect_position = Vector2(0, - block_size / 2)
	if "#" in tip:
		var color = tip.split("#")[1]
		lbl.set("custom_colors/font_color", Color(color))
		tip = tip.split("#")[0]
	lbl.text = tip
	lbl.show()
	if beatEffect:
		beat_effect.show()
	else:
		beat_effect.hide()
	var tween = get_tree().create_tween()
	var pos = lbl.rect_position - Vector2(0, block_size)
	var time: float = 0.3 * float(Engine.time_scale)
	tween.tween_property(lbl, "rect_position", pos, time).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(self, "show_special_tips", [bu, tips, endAction])
	return


func _play_tornado(bu: Battle_Unit) -> void :
	SoundManager.play_se2("res://resource/sounds/se/tornado.ogg", 0.4, self, "_tornado_finished", [bu])
	animation_hurt.play("tornado")
	return

func _tornado_finished(bu: Battle_Unit) -> void :
	$tornado.hide()
	bu.disabled = true
	action_end()
	return

func set_texture(texture, dir: int = 0) -> bool:
	if texture == null:
		return false
	var width = texture.get_width()
	var height = texture.get_height()
	var hFrames = 4
	var vFrames = 2
	var secondaryIndex = 0
	var scale = 0.625
	if width == 256 and height == 128:
		
		secondaryIndex = 1
	elif width == height:
		
		hFrames = 1
		vFrames = 1
		scale = 40.0 / width
	elif width == height * 2:
		
		hFrames = 2
		vFrames = 1
		secondaryIndex = 1
		scale = 40.0 / width
	else:
		
		return false
	for sp in [sp_A, buff_A, sp_B, buff_B]:
		sp.texture = texture
		sp.hframes = hFrames
		sp.vframes = vFrames
		sp.frame_coords = Vector2(dir, 0)
		sp.scale = Vector2(scale, scale)
	for sp in [sp_B, buff_B]:
		sp.frame_coords = Vector2(dir, secondaryIndex)
	return true
