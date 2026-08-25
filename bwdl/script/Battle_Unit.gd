# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/Battle_Unit.gd
# 说明：战斗单位基类。定义 HP、兵种、行动次数、伤害率、攻击距离、Buff 等战斗核心属性与方法。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "clEnvBase.gd"
class_name Battle_Unit


var unitId: int = 0;

var leaderId: int = - 1;

var Type: String = "无";

var _private_hp: float;

var wait_action_times = 0;

var other_wait_type = "";


var wait_action_name = "";

var last_action_name = "";


var last_attack_units = [];


var direction: int = 1;

var default_direction: int = 1;

var unit_position: Vector2 = Vector2( - 1, - 1);

var is_surrend = false;

var disabled = false;

var dic_other_variable: Dictionary = {};


var requires_update = false;


var iunit_logic


var ibd


var extra_armor = 0


var dic_combat: Dictionary = {
	"近战距离": 1, 
	"原行动次数": 2, 
	"行动次数": 2, 
	"射击距离": 0, 
	"近身伤害": 1.0, 
	"射击伤害": 0.6, 
	"最小投掷距离": 0, 
	"投掷距离": 0, 
	"投掷伤害": 0.5, 
	"受击免伤": 0.5, 
	"图像": "0.png", 
	"新图像": "0.png", 
	"移动规则": 1, 
	"士兵分配顺序": 0, 
	"不布阵": false, 
	"行动次数血线补充": [], 
		};

func _init(actorId: int):
	leaderId = actorId
	iunit_logic = Global.load_script(DataManager.mod_path + "sgz_script/battle/IUnitLogic.gd")
	ibd = Global.load_script(DataManager.mod_path + "sgz_script/battle/IBattle_Damage.gd")
	return





func formation_init(newType: String, forced: bool = false) -> bool:
	if newType != Type\
	and not forced\
	and get_extra_buff_val("兵种锁定") > 0:
		return false
	var changed = Type != newType
	Type = newType
	init_combat_info( not changed)
	dic_other_variable["初始兵种"] = Type
	return true




func reset_type(newType: String) -> bool:
	if not is_soldier() and not is_general():
		return false
	var originalType = Type
	Type = newType
	init_combat_info()
	return true


func init_combat_info(skipTrigger: bool = false):
	dic_combat = {}
	if not _reset_combat_info():
		return
	
	dic_combat["原行动次数"] = dic_combat["行动次数"]
	if (is_soldier() or is_general())\
	and not skipTrigger:
		DataManager.set_env("白兵.初始化单位ID", unitId)
		SkillHelper.auto_trigger_skill(leaderId, 30024)
	var bf = DataManager.get_current_battle_fight()
	bf.update_unit_types(leaderId)
	return


func _reset_combat_info() -> bool:
	var settings = StaticManager.get_battle_troops_setting()
	if Type in settings:
		for key in settings[Type]:
			dic_combat[key] = settings[Type][key]
	
	turn_init()
	requires_update = true
	return true


func turn_init():
	clear_tmp_variables()
	if is_general():
		var extraBackStep = actor().get_equip_feature_total("额外后退")
		if extraBackStep > 0:
			var bia = Battle_Instant_Action.new()
			bia.unitId = unitId
			bia.action = "移动"
			bia.targetUnitId = - 1
			bia.actionTimes = extraBackStep
			bia.need_state.append("后退");
			bia.insert_to_env()
	wait_action_times = get_action_times()
	check_buff()
	
	check_severe_damage_status()
	action_turn_init()
	
	check_action_suppressed(true)
	return

func check_buff() -> void :
	var leader = leader()
	if leader == null:
		return
	
	if get_unit_type() in ["步", "骑"]:
		if leader.get_buff_label_turn(["长兵"]) > 0:
			set_combat_val("近战距离", 2, "长兵")
			set_combat_val("穿刺距离", 1, "长兵")
			set_combat_val("BUFF", 1, "长兵")
			requires_update = true
		else:
			dic_combat.erase("长兵")
			requires_update = true
	
	var enemyLeader = leader().get_battle_enemy_war_actor()
	if enemyLeader != null:
		if enemyLeader.get_buff_label_turn(["抑制行动"]) > 0:
			if is_soldier():
				set_action_suppressed()
	return


func action_turn_init():
	other_wait_type = ""
	var hp = get_hp()
	if is_action_times_fixed():
		return
	if dic_combat.has("行动次数血线补充"):
		var hp_array: Array = dic_combat["行动次数血线补充"]
		
		
		
		wait_action_times = min(wait_action_times, get_action_times())
		for i in hp_array.size():
			if hp <= hp_array[i]:
				wait_action_times += 1
			else:
				break
	if dic_combat.has("骁果") and int(dic_combat["骁果"]) == 1:
		wait_action_times += 1
	dic_combat.erase("骁果")
	return

func get_save_dit():
	var dit = {
		"unitId": unitId, 
		"leaderId": leaderId, 
		"Type": Type, 
		"_private_hp": _private_hp, 
		"wait_action_times": wait_action_times, 
		"direction": direction, 
		"default_direction": default_direction, 
		"unit_position": {"x": unit_position.x, "y": unit_position.y}, 
		"dic_combat": dic_combat.duplicate(), 
		"wait_action_name": wait_action_name, 
		"last_action_name": last_action_name, 
		"is_surrend": is_surrend, 
		"disabled": disabled, 
		"dic_other_variable": dic_other_variable, 
		"other_wait_type": other_wait_type, 
		"last_attack_units": last_attack_units, 
		"extra_armor": extra_armor, 
	};
	return dit;

func set_save_dit(dit: Dictionary):
	unitId = int(dit["unitId"]);
	leaderId = int(dit["leaderId"]);
	Type = str(dit["Type"]);
	_private_hp = int(dit["_private_hp"]);
	wait_action_times = int(dit["wait_action_times"]);
	direction = int(dit["direction"]);
	default_direction = int(dit["default_direction"]);
	unit_position = Vector2(int(dit["unit_position"]["x"]), int(dit["unit_position"]["y"]));
	dic_combat = Dictionary(dit["dic_combat"]).duplicate();
	wait_action_name = str(dit["wait_action_name"]);
	if (dit.has("last_action_name")):
		last_action_name = str(dit["last_action_name"]);
	if (dit.has("is_surrend")):
		is_surrend = dit["is_surrend"];
	if (dit.has("disabled")):
		disabled = dit["disabled"];
	if (dit.has("dic_other_variable")):
		dic_other_variable = dit["dic_other_variable"];
	if (dit.has("other_wait_type_array")):
		other_wait_type = dit["other_wait_type"];
	if (dit.has("last_attack_units")):
		last_attack_units = dit["last_attack_units"]
	if dit.has("extra_armor"):
		extra_armor = int(dit["extra_armor"])

func get_hp(include_disabled: bool = false) -> float:
	if get_unit_type() == "将":
		return actor().get_hp()
	if (disabled and not include_disabled):
		return 0.0;
	return _private_hp;

func set_hp(hp: float, setOnly: bool = false):
	var original = _private_hp
	if hp < original and extra_armor > 0:
		var armor_reduce = original - hp
		if armor_reduce > 0:
			if int(get_extra_buff_val("临界护甲")) >= 1 and armor_reduce >= extra_armor and extra_armor > 0:
				
				extra_armor = 0
				hp = original
			else:
				armor_reduce = min(extra_armor, armor_reduce)
				extra_armor -= armor_reduce
				hp += armor_reduce
	_private_hp = hp
	if hp <= 0:
		
		disabled = true
	var actor = actor()
	var type = get_unit_type()
	if type == "将":
		actor.set_hp(hp)
	if type == "城门":
		return

	if setOnly:
		return

	set_env("白兵.受伤单位", unitId)
	
	SkillHelper.auto_trigger_skill(leaderId, 30013)
	var wa = leader()
	var ea = wa.get_battle_enemy_war_actor()
	if ea != null and not ea.disabled:
		
		SkillHelper.auto_trigger_skill(ea.actorId, 30023)
	
	check_blocking_counter()
	
	check_shooting_back_counter()
	return

func get_side() -> Vector2:
	var bf = DataManager.get_current_battle_fight()
	if leaderId == bf.get_attacker_id():
		return Vector2.LEFT
	return Vector2.RIGHT


func has_action_task() -> String:
	if (disabled):
		
		wait_action_times = 0;
		return "";
	
	for dic in DataManager.battle_first_sort:
		if (int(dic["单位ID"]) != unitId):
			continue;
		if (dic["行为方式"] == "单挑"):
			return "单挑";
		if ( not dic.has("目标坐标")):
			continue;
		var ret = "{行为方式}|{目标坐标}"
		if "附加信息" in dic:
			ret += "|{附加信息}"
		ret = ret.format(dic)
		return ret
	return ""

func remove_action_task():
	for i in DataManager.battle_first_sort.size():
		var dic = DataManager.battle_first_sort[i];
		if (int(dic["单位ID"]) != unitId):
			continue;
		DataManager.battle_first_sort.remove(i);
		break;


func complete_action_task():
	wait_action_name = ""
	if unit_position.x < 0 or unit_position.x >= 16:
		if get_unit_type() != "将":
			var hp = get_hp(true)
			var lost = int(hp * leader().get_retreat_lost_rate() / 100)
			if lost > 0:
				set_hp(hp - lost, true)
		disabled = true;
	
	remove_action_task()
	
	var equip_type: PoolStringArray = get_unit_equip();
	var has_task: bool = str(has_action_task()) != "" or wait_action_times > 0;
	if ("剑" in equip_type and get_state() != "后退"):
		
		if ( not DataManager.common_variable.has("白兵.剑类影响目标") and not has_task):
			DataManager.common_variable["白兵.剑类影响目标"] = [];
			
			
			var dir_array = [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP];
			for i in dir_array.size():
				var dir_plus = dir_array[i];
				var position_plus: Vector2 = unit_position + dir_plus;
				var other_unit = DataManager.get_battle_unit_by_position(position_plus);
				if (other_unit == null):
					continue;
				
				if other_unit.get_unit_type() in ["将", "城门"]:
					continue;
				
				if (i == direction):
					continue;
				
				if (3 - i == direction):
					continue;
				var other_distance = abs(other_unit.unit_position.x - unit_position.x) + abs(other_unit.unit_position.y - unit_position.y);
				if (other_distance != 1):
					
					continue;
				
				if (other_unit.leaderId == leaderId):
					continue;
				DataManager.common_variable["白兵.剑类影响目标"].append(other_unit.unitId);
		
		var sworded = DataManager.get_env_int_array("白兵.剑类影响目标")
		if sworded.size() > 0:
			var swordedId = sworded.pop_front()
			DataManager.set_env("白兵.剑类影响目标", sworded)
			append_once_attack_tag("侧击", 1)
			var dic = iunit_logic.create_attack_action(unitId, swordedId)
			DataManager.battle_first_sort.append(dic)
	return


func action_run_call_UI():
	wait_action_name = has_action_task()
	return

func clear_once_flags(clearNextToo: bool = false):
	
	for k in dic_combat.keys():
		if k.begins_with("ONCE"):
			dic_combat.erase(k)
	
	for k in dic_combat.keys():
		if k.begins_with("NEXT"):
			if not clearNextToo:
				dic_combat[k.replace("NEXT", "ONCE")] = dic_combat[k]
			dic_combat.erase(k)
	return


func get_state() -> String:
	var bf = DataManager.get_current_battle_fight()
	if dic_combat.has("暴走") and dic_combat["暴走"] == 1:
		return "前进"
	if dic_combat.has("游走") and dic_combat["游走"] == 1:
		return "后退"
	return bf.get_unit_state(self)


func combat_action() -> String:
	var has_task = has_action_task();
	if (has_task != ""):
		return has_task;
	if (wait_action_times == 0):
		return "";

	wait_action_times -= 1;
	var dic = iunit_logic.check_action(self);
	if (dic.empty()):
		return "";
	if dic["行为方式"] == "移动" and dic_combat.has("移动所需行动次数"):
		wait_action_times -= (int(dic_combat["移动所需行动次数"]) - 1)

	if (other_wait_type != "" and dic["行为方式"] != other_wait_type):
		other_wait_type = "";
		if (wait_action_times == 0):
			return "";
		wait_action_times -= 1;
	if (dic.has("目标坐标")):
		DataManager.battle_first_sort.append(dic);
		return str(dic["行为方式"]) + "|" + str(dic["目标坐标"]);
	if (dic["行为方式"] == "单挑"):
		return "单挑";
	return "";



func get_unit_attack_area():
	var attackDistance = get_attack_distance()
	
	if attackDistance <= 0:
		return {}
	var leader = leader()

	var targetings = [
		[Vector2.LEFT, attackDistance, "left"], 
		[Vector2.RIGHT, attackDistance, "right"], 
		[Vector2.UP, attackDistance, "up"], 
		[Vector2.DOWN, attackDistance, "down"], 
	]
	var radiusAttackDistance = 0
	if not get_unit_equip().empty():
		
		radiusAttackDistance = actor().get_equip_feature_max("斜角攻击距离")
		if radiusAttackDistance <= 0 and "锤" in get_unit_equip():
			
			radiusAttackDistance = max(radiusAttackDistance, 1)
	if radiusAttackDistance <= 0\
	and get_unit_type() == "骑"\
	and leader != null\
	and leader.get_buff_label_turn(["骑兵斜角攻击"]) > 0:
		radiusAttackDistance = 1
	if radiusAttackDistance > 0:
		
		targetings.append([Vector2( - 1, - 1), radiusAttackDistance, "left"])
		targetings.append([Vector2( - 1, 1), radiusAttackDistance, "left"])
		targetings.append([Vector2(1, - 1), radiusAttackDistance, "right"])
		targetings.append([Vector2(1, 1), radiusAttackDistance, "right"])

	var ret = {}
	var state = get_state()
	
	for targeting in targetings:
		var dir = targeting[0]
		var rng = targeting[1]
		var key = targeting[2]
		var blocked = false
		for distance in range(1, rng + 1):
			if blocked:
				break
			
			var pos = dir * distance + unit_position
			var target = DataManager.get_battle_unit_by_position(pos)
			if target == null or target.disabled:
				continue
			var type = target.get_unit_type()
			
			if type == "城门":
				blocked = true
			
			if target.leaderId in [leaderId, - 1]:
				if get_extra_buff_val("乱兵") > 0:
					
					pass
				else:
					continue
			
			if type == "城门":
				var disv = pos - unit_position
				if disv.y != 0:
					
					continue
				if disv.x * get_side().x > 0:
					
					continue
			
			
			if state in ["包围"] and type in ["将"]:
				blocked = true
				continue
			
			if not key in ret:
				ret[key] = []
			ret[key].append(target)
	return ret

func get_unit_equip_effect_area(target_unit: Battle_Unit, attack_dir: String) -> PoolIntArray:
	DataManager.set_env("白兵.刀类影响目标", [])
	DataManager.set_env("白兵.枪类影响目标", [])
	
	var targets = [];
	var dic_direct_position = {
		"left": Vector2( - 1, 0), 
		"right": Vector2(1, 0), 
		"up": Vector2(0, - 1), 
		"down": Vector2(0, 1)
	};
	
	if ("刀" in get_unit_equip()):
		DataManager.common_variable["白兵.刀类影响目标"].append(target_unit.unitId);
		
		for dir_plus in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var position_plus: Vector2 = target_unit.unit_position + dir_plus;
			var other_unit = DataManager.get_battle_unit_by_position(position_plus);
			if (other_unit == null or other_unit.disabled):
				continue;
			
			if (other_unit.get_unit_type() == "将"):
				continue;
			if (other_unit.unit_position.x == unit_position.x or other_unit.unit_position.y == unit_position.y):
				
				continue;
			
			if (other_unit.leaderId == leaderId):
				continue;
			targets.append(other_unit.unitId);
			DataManager.common_variable["白兵.刀类影响目标"].append(other_unit.unitId);
			
	var attackThroughRange = get_attack_through_distance()
	if attackThroughRange > 0:
		
		var speared = []
		for x in attackThroughRange:
			var pos = target_unit.unit_position + dic_direct_position[attack_dir] * (x + 1)
			var other_unit = DataManager.get_battle_unit_by_position(pos)
			if other_unit == null or other_unit.disabled or other_unit.get_unit_type() == "将":
				continue
			if other_unit.leaderId != target_unit.leaderId or other_unit.unitId == target_unit.unitId:
				continue
			speared.append(other_unit.unitId)
		targets.append_array(speared)
		DataManager.set_env("白兵.枪类影响目标", speared)

	return PoolIntArray(targets)


func enemy_leaderId():
	for actorId in DataManager.battle_actors:
		if (actorId == leaderId):
			continue;
		return actorId;
	return - 1;


# 核心：计算攻击单位对本单位造成的伤害。
# 流程：基础伤害(calc_classic_damage) -> 刀/枪/剑类修正 -> 触发技能 -> 最终修正 -> 扣血。
# 附带：斧头攻击加成、格挡、步兵伤停、重伤、射箭抑制、攻击回血等特殊效果。
func count_hurt_by(attackUnit: Battle_Unit):
	var isFarAttak = attackUnit.last_action_name in ["射箭", "投掷"]

	# 城门是特殊单位：近战 5 点、远程 1 点、象兵 15 点伤害
	if get_unit_type() == "城门":
		var doorDamage = 5
		if isFarAttak:
			doorDamage = 1
		elif attackUnit.get_unit_type() == "象":
			doorDamage = 15
		doorDamage += attackUnit.get_extra_buff_val("城门增伤")
		set_hp(get_hp() - doorDamage)
		return

	# 基础伤害（由 mod 可覆盖的 IBattle_Damage 接口计算）
	var damage = ibd.calc_classic_damage(attackUnit, self)

	# 刀类目标：按受影响的刀兵数量加成伤害
	var bladed = DataManager.get_env_int_array("白兵.刀类影响目标")
	if unitId in bladed:
		
		damage = int(damage * attackUnit.get_blade_damage_rate(bladed.size()))

	# 枪类目标：按枪兵伤害率修正
	if unitId in DataManager.get_env_int_array("白兵.枪类影响目标"):
		
		damage = int(damage * attackUnit.get_spear_damage_rate())

	# 剑类目标：伤害减半（「大斩」技能可保持全额）
	if DataManager.check_env(["白兵.剑类影响目标"]):
		
		var rate: float = 0.5
		
		if SkillHelper.actor_has_skills(attackUnit.leaderId, ["大斩"]):
			rate = 1.0
		damage = int(damage * rate)

	# 设置临时伤害环境变量，供技能系统进一步修正
	DataManager.set_env("白兵伤害.来源", attackUnit.unitId)
	DataManager.set_env("白兵伤害.单位", unitId)
	DataManager.set_env("白兵伤害.伤害", damage)
	
	SkillHelper.auto_trigger_skill(attackUnit.leaderId, 30021)
	
	SkillHelper.auto_trigger_skill(leaderId, 30011)
	damage = DataManager.get_env_float("白兵伤害.伤害")
	if damage <= 0:
		return
	
	# 最终伤害修正（护甲/地形/技能等）
	var finalDamage = final_adjust_damage(damage)
	
	# 斧兵近战额外附加攻击力
	if attackUnit.get_unit_equip().has("斧") and attackUnit.last_action_name == "攻击":
		finalDamage += attackUnit.actor().get_equip_attr_total("攻击力")

	# 被格挡则伤害归零
	if Global.dic_val(attackUnit.dic_other_variable, "被格挡", 0) > 0:
		finalDamage = 0

	# 记录受伤次数
	if finalDamage > 0:
		var hits = get_tmp_variable("受伤次数", 0)
		set_tmp_variable("受伤次数", hits + 1)

	var type = get_unit_type()
	if type != "将":
		# 普通单位伤害折算为士兵损失
		var expFactor = max(1, SkillRangeBuff.max_val_for_actor("小战场经验倍率", attackUnit.leaderId))
		DataManager.damage_sodiers(attackUnit.leaderId, leaderId, finalDamage, expFactor)

	# 步兵伤停：步兵被打可让攻击单位禁动
	if type == "步" and actor().get_equip_feature_max("步兵伤停") > 0:
		
		if attackUnit.get_unit_type() != "将":
			if attackUnit.wait_action_times > 0:
				attackUnit.wait_action_times = 0
				attackUnit.add_status_effect("禁动#FF0000")

	set_hp(get_hp() - finalDamage)
	if finalDamage > 0:
		var leader = leader()
		if get_unit_type() != "将" and leader != null and not leader.disabled and leader.get_buff_label_turn(["骁果"]) > 0:
			dic_combat["骁果"] = 1
			requires_update = true
	attackUnit.dic_other_variable["被格挡"] = 0

	if attackUnit.get_unit_type() in ["将"]:
		
		var rate = attackUnit.actor().get_equip_feature_max("重伤概率")
		if rate > 0 and Global.get_rate_result(rate):
			set_severe_damaged()
			add_status_effect("重伤#FF0000")
		
		if is_soldier() and attackUnit.last_action_name == "射箭" and not check_action_suppressed():
			var suppressing = attackUnit.actor().get_equip_feature_max("射箭抑制行动")
			if suppressing > 0:
				var suppressed = attackUnit.get_tmp_variable("射箭抑制行动", 0)
				if suppressing > suppressed:
					set_action_suppressed()
					add_status_effect("抑制#FF0000")
					attackUnit.set_tmp_variable("射箭抑制行动", suppressed + 1)
		
		var regenerateRate = 0
		var lastAction = attackUnit.last_action_name.split("|")[0]
		if lastAction in ["攻击", "反击"]:
			
			regenerateRate = attackUnit.actor().get_equip_feature_total("近身攻击回血")
		elif lastAction in ["射箭"]:
			
			regenerateRate = attackUnit.actor().get_equip_feature_total("射箭攻击回血")
		if regenerateRate > 0:
			var current = attackUnit.get_hp()
			var limit = attackUnit.actor().get_max_hp()
			var hp = min(current + finalDamage * regenerateRate / 100.0, limit)
			attackUnit.set_hp(hp, true)
	return


func get_shoot_distance():
	var distance = int(dic_combat["射击距离"])
	if get_unit_type() == "将":
		
		var equip_distance = actor().get_equip_feature_max("白兵射程")
		distance = max(equip_distance, distance)
	if distance <= 0:
		
		return 0
	
	if dic_combat.has("额外射程"):
		var extra_distance = int(dic_combat["额外射程"])
		distance = max(0, distance + extra_distance)
	
	if is_far_shooting():
		distance += 2
	
	distance += actor().get_equip_feature_max("全队射程提升")
	
	if DataManager.diffculities >= 3:
		var bf = DataManager.get_current_battle_fight()
		if bf.get_terrian() == "wallcity"\
		and get_side() == Vector2.RIGHT\
		and get_unit_type() == "弓":
			distance = 7
	distance = min(7, distance)
	return distance


func get_throw_from() -> int:
	var distance = get_combat_val_min("最小投掷距离")
	return distance


func get_throw_distance():
	var distance = get_combat_val_max("投掷距离")
	if get_unit_type() == "将":
		
		var equip_distance = actor().get_equip_feature_max("投掷距离")
		distance = max(equip_distance, distance)
	return distance






func get_throw_type() -> int:
	return get_combat_val_max("投掷类型")






func get_throw_target_types() -> Array:
	match get_throw_type():
		1:
			return []
		2:
			return []
		3:
			return []
	return ["将"]


func get_attack_distance():
	var distance = get_combat_val_max("近战距离", 1)
	if "枪" in get_unit_equip():
		
		distance = 2
	return min(2, distance)


func get_attack_through_distance():
	var distance = get_combat_val_max("穿刺距离", 0)
	if "枪" in get_unit_equip():
		
		distance = max(1, distance)
	
	return min(2, distance)

func get_unit_equip() -> PoolStringArray:
	if dic_combat.has("武器特性"):
		return PoolStringArray(Global.arrval(dic_combat["武器特性"]))
	if get_unit_type() == "将":
		return actor().get_weapon_types()
	return PoolStringArray([])

func get_unit_type() -> String:
	return Type.split("(")[0]



func get_extra_buff_val(key: String) -> float:
	var rate = 0.0
	if dic_combat.has(key):
		rate += float(dic_combat[key])
	for k in dic_combat:
		if typeof(dic_combat[k]) != TYPE_DICTIONARY:
			continue
		if key in dic_combat[k]:
			rate += float(dic_combat[k][key])
	return rate



func get_extra_damage_rate() -> int:
	return int(get_extra_buff_val("额外伤害") * 100)



func get_extra_damage_avoid_rate() -> int:
	return int(get_extra_buff_val("额外免伤") * 100)





func get_shooting_damage_rate(targetUnit: Battle_Unit = null) -> int:
	var rate: int = 100
	if dic_combat.has("射击伤害"):
		rate = int(Global.floatval(dic_combat["射击伤害"]) * 100)
	var specialDic = Global.dic_val(dic_combat, "特殊射击伤害", {})
	if targetUnit != null:
		var type = targetUnit.get_unit_type()
		if type in specialDic:
			rate = int(Global.floatval(specialDic[type]) * 100)
	rate += get_extra_damage_rate()
	return rate





func get_throwing_damage_rate(target: Battle_Unit = null) -> int:
	var rate: int = 50
	if dic_combat.has("投掷伤害"):
		var val = dic_combat["投掷伤害"]
		match typeof(val):
			TYPE_REAL:
				rate = int(float(val) * 100)
			TYPE_ARRAY:
				var distance = 0
				if target != null:
					distance = Global.get_distance(unit_position, target.unit_position)
				if distance == 0:
					rate = int(float(val[0]) * 100)
				elif distance <= val.size():
					rate = int(float(val[distance - 1]) * 100)
				else:
					rate = int(float(val[val.size() - 1]) * 100)
	rate += get_extra_damage_rate()
	return rate





func get_melee_damage_rate() -> int:
	var rate: int = 100
	if dic_combat.has("近身伤害"):
		rate = int(float(dic_combat["近身伤害"]) * 100)
	rate += get_extra_damage_rate()

	if get_unit_type() == "将":
		rate += actor().get_equip_feature_total("近身倍率加成")

	return rate






func get_damage_avoid_rate() -> int:
	var rate: int = 0
	if dic_combat.has("受击免伤"):
		rate = int(dic_combat["受击免伤"] * 100)
	rate += get_extra_damage_avoid_rate()

	if get_unit_type() == "将":
		rate += actor().get_equip_feature_total("白兵免伤")
		rate += actor().get_equip_feature_total("白兵免伤叠加") * get_tmp_variable("受伤次数", 0)

	if rate > 80:
		rate = 80
	return rate







func final_adjust_damage(damage: float) -> float:
	
	
	
	var min_damage = 0.5
	if DataManager.diffculities >= 3:
		min_damage = 1
	damage = max(min_damage, damage)

	var leader = leader()
	if get_unit_type() == "将":
		damage = min(12, damage)
		var minVal = leader.actor().get_equip_feature_min("白刃战最大受伤")
		if minVal > 0 and minVal < 12:
			damage = min(minVal, damage)
	else:
		
		var minDamage = 10
		if leader != null and leader.battle_lead >= 0:
			minDamage -= int(leader.battle_lead / 10)
		minDamage = max(1, minDamage)
		
		damage = max(damage, minDamage)

	return min(get_hp(), damage)


func prepare_instant_action(bia: Battle_Instant_Action) -> bool:
	var bf = DataManager.get_current_battle_fight()
	dic_combat["ONCE.临时行动"] = 1
	DataManager.common_variable["白兵.行动单位"] = unitId
	var additionalAttackType = ""
	var actionPieces = bia.action.split("@")
	var action = actionPieces[0]
	if action in ["攻击", "射箭"]:
		DataManager.set_env("白兵.攻击来源", bia.unitId)
		var targets = []
		if bia.targetUnitId >= 0:
			targets.append(bia.targetUnitId)
		if not bia.targets.empty():
			targets.append_array(bia.targets)
		DataManager.set_env("白兵.攻击目标", targets)
		if actionPieces.size() > 1:
			additionalAttackType = actionPieces[1]
			append_once_attack_tag(additionalAttackType, 1)
		if actionPieces.size() > 2:
			append_once_damage_rate(float(actionPieces[2]))
	elif bia.action == "迫退":
		
		for targetId in bia.targets:
			var bu = bf.battle_unit(targetId)
			if bu == null:
				continue
			var pos = bu.unit_position - bia.targetPos
			if bu.can_move_to_position(pos):
				bu.unit_position = pos
		return false
	elif bia.action == "漫射":
		DataManager.common_variable["白兵.攻击来源"] = bia.unitId
		var targets = []
		
		var minBias = 9
		for bu in DataManager.battle_units:
			if bu == null or bu.disabled:
				continue
			if bu.leaderId in [ - 1, leaderId]:
				continue
			if bu.get_unit_type() == "将":
				continue
			var disv = bu.unit_position - unit_position
			if abs(disv.x) + abs(disv.y) > get_shoot_distance() + 1:
				continue
			targets.append(bu.unitId)
			var bias = min(abs(disv.x), abs(disv.y))
			if bias < minBias:
				minBias = bias
				bia.targetPos = bu.unit_position
		
		targets.erase(bia.targetUnitId)
		if targets.empty():
			return false
		
		
		
		
		
		targets.shuffle()
		if targets.size() > 3:
			targets.resize(3)
		append_once_damage_rate(0.5)
		append_once_attack_tag("漫射", 1)
		DataManager.common_variable["白兵.攻击目标"] = targets
		action = "射箭"
		additionalAttackType = "漫射"
	elif bia.action == "广射":
		var unit = bf.battle_unit(bia.unitId)
		DataManager.common_variable["白兵.攻击来源"] = bia.unitId
		var targets = []
		
		var minBias = 9
		for bu in DataManager.battle_units:
			if bu == null or bu.disabled:
				continue
			if bu.leaderId in [ - 1, leaderId]:
				continue
			if bu.get_unit_type() in ["城门"]:
				continue
			if not unit.shootable(bu):
				continue
			targets.append(bu.unitId)
			var disv = bu.unit_position - unit_position
			var bias = min(abs(disv.x), abs(disv.y))
			
			if bias <= minBias:
				minBias = bias
				bia.targetUnitId = bu.unitId
				bia.targetPos = bu.unit_position
		
		targets.erase(bia.targetUnitId)
		if targets.empty():
			return false
		if targets.size() > 2:
			targets.resize(2)
		targets.insert(0, bia.targetUnitId)
		append_once_damage_rate(0.5)
		append_once_attack_tag("广射", 1)
		DataManager.common_variable["白兵.攻击目标"] = targets
		action = "射箭"
		additionalAttackType = "广射"
	
	if action == "移动" and bia.targetPos.x < 0 and bia.targetPos.y < 0:
		var unit = DataManager.battle_units[bia.unitId];
		var action_dic = iunit_logic._action_move(unit);
		if not action_dic.has("目标坐标"):
			return false
		self.wait_action_name = "{0}|{1}|{3}|{4}".format([
			action, action_dic["目标坐标"], bia.actionTimes, additionalAttackType
		])
	else:
		self.wait_action_name = "{0}|{1},{2}|{3}|{4}".format([
			action, bia.targetPos.x, bia.targetPos.y, bia.actionTimes, additionalAttackType
		])
		DataManager.game_trace("{0}#{1}临时行动: {2}".format([
			Type, unitId, wait_action_name
		]))
	return true


func can_move_to_position(targetPos: Vector2, retreatAllowed: bool = false) -> bool:
	if DataManager.get_battle_unit_by_position(targetPos) != null:
		
		return false

	var sceneBattle = SceneManager.current_scene()
	if (targetPos.x < 0 or targetPos.x >= sceneBattle.cell_columns)\
	or (targetPos.y < 0 or targetPos.y >= sceneBattle.cell_rows):
		
		if get_state() != "后退" and not retreatAllowed:
			return false
		if get_unit_type() == "将":
			var wa = DataManager.get_war_actor(leaderId)
			if wa == null or wa.disabled:
				return false
			if wa.get_buff_label_turn(["全军死战"]) > 0:
				
				var enemyTroops: float = 0
				for bu in DataManager.battle_units:
					if bu == null or bu.disabled:
						continue
					if bu.get_unit_type() == "将" or bu.leaderId == self.leaderId:
						continue
					enemyTroops += bu.get_hp()
				
				if enemyTroops >= 200:
					return false
			if wa.get_buff_label_turn(["武将死战"]) > 0:
				return false

	var blocked: bool = sceneBattle.get_position_is_roadblock(targetPos)
	var blockIgnored: bool = false
	if blocked:
		
		if get_combat_val_max("仙兵") > 0:
			blockIgnored = true
		else:
			var blockIgnoreSettings = StaticManager.get_battle_ignore_block_setting()
			var wa = DataManager.get_war_actor(self.leaderId)
			var troopsType = wa.get_troops_type()
			var bf = DataManager.get_current_battle_fight()
			if blockIgnoreSettings.has(troopsType)\
			and blockIgnoreSettings[troopsType].has(bf.get_terrian()):
					blockIgnored = true

	return not blocked or blockIgnored

func get_spear_damage_rate() -> float:
	if dic_combat.has("枪倍率"):
		return float(dic_combat["枪倍率"])
	return 0.7


func get_blade_damage_rate(hitCount: int) -> float:
	hitCount = max(1, hitCount)
	var totalRate = 1.5
	if hitCount == 2 and dic_combat.has("刀倍率2"):
		totalRate = float(dic_combat["刀倍率2"])
	elif hitCount > 2 and dic_combat.has("刀倍率x"):
		totalRate = float(dic_combat["刀倍率x"])
	return totalRate / hitCount



func get_extra_attack_power() -> int:
	return get_combat_val_max("额外攻击力", 0)

func set_combat_val(key: String, val: int, category: String) -> void :
	if not dic_combat.has(category):
		dic_combat[category] = {}
	var dic = Global.dicval(dic_combat[category])
	dic[key] = val
	dic_combat[category] = dic
	return

func get_combat_val_total(key: String, defVal: float = 0.0) -> float:
	var ret = defVal
	for k in dic_combat:
		if k == key:
			ret += Global.floatval(dic_combat[k])
			continue
		if typeof(dic_combat[k]) == TYPE_DICTIONARY:
			if key in dic_combat[k]:
				ret += Global.floatval(dic_combat[k][key])
	return ret

func get_combat_val_maxf(key: String, defVal: float = 0.0) -> int:
	var ret = - 99999
	for k in dic_combat:
		if k == key:
			ret = max(ret, Global.floatval(dic_combat[k]))
			continue
		if typeof(dic_combat[k]) == TYPE_DICTIONARY:
			if key in dic_combat[k]:
				ret = max(ret, Global.floatval(dic_combat[k][key]))
	if ret < - 90000:
		ret = defVal
	return ret

func get_combat_val_max(key: String, defVal: int = 0) -> int:
	return int(get_combat_val_maxf(key, defVal))

func get_combat_val_minf(key: String, defVal: float = 0.0) -> int:
	var ret = 99999
	for k in dic_combat:
		if k == key:
			ret = min(ret, Global.floatval(dic_combat[k]))
			continue
		if typeof(dic_combat[k]) == TYPE_DICTIONARY:
			if key in dic_combat[k]:
				ret = min(ret, Global.floatval(dic_combat[k][key]))
	if ret > 90000:
		ret = defVal
	return ret

func get_combat_val_min(key: String, defVal: int = 0) -> int:
	return int(get_combat_val_minf(key, defVal))


func append_combat_val(key: String, val: float) -> float:
	if not dic_combat.has(key):
		dic_combat[key] = 0
	val = float(dic_combat[key]) + val
	dic_combat[key] = val
	return val


func mark_buffed(val: int = 1) -> void :
	dic_combat["BUFF"] = val
	requires_update = true
	return

func leader():
	return DataManager.get_war_actor(leaderId)


func accept_solo() -> bool:
	return get_unit_type() == "将"

func append_next_attack_tag(tag: String, priority: int) -> bool:
	var current = 0
	if dic_combat.has("NEXT.攻击标签.优先"):
		current = int(dic_combat["NEXT.攻击标签.优先"])
	if priority <= current:
		return false
	dic_combat["NEXT.攻击标签"] = tag
	dic_combat["NEXT.攻击标签.优先"] = priority
	return true


func append_once_attack_tag(tag: String, priority: int) -> bool:
	if not dic_combat.has("ONCE.攻击标签.ALL"):
		dic_combat["ONCE.攻击标签.ALL"] = []
	dic_combat["ONCE.攻击标签.ALL"].append(tag)
	var current = 0
	if dic_combat.has("ONCE.攻击标签.优先"):
		current = int(dic_combat["ONCE.攻击标签.优先"])
	if priority <= current:
		return false
	dic_combat["ONCE.攻击标签"] = tag
	dic_combat["ONCE.攻击标签.优先"] = priority
	return true

func get_once_attack_tag() -> String:
	var key = "ONCE.攻击标签"
	if dic_combat.has(key):
		return str(dic_combat[key])
	if dic_other_variable.has("暴击"):
		return "暴击#FF0000"
	return ""

func get_once_attack_tags_all() -> PoolStringArray:
	var ret = []
	if not dic_combat.has("ONCE.攻击标签.ALL"):
		var tag = get_once_attack_tag()
		ret.erase(tag)
		ret.append(tag)
		return ret
	ret = Global.arrval(dic_combat["ONCE.攻击标签.ALL"])
	return ret

func get_once_attack_se() -> String:
	if get_once_attack_tag() == "侧击":
		return "res://resource/sounds/se/Arrow_ToUnit.ogg"
	return "res://resource/sounds/se/Battle_Attacking.ogg"


func append_once_damage_rate(rate: float) -> float:
	var key = "ONCE.伤害倍率"
	var current = 1.0
	if dic_combat.has(key):
		current = float(dic_combat[key])
	rate = current * rate
	dic_combat[key] = rate
	return rate

func get_once_damage_rate() -> float:
	var key = "ONCE.伤害倍率"
	if dic_combat.has(key):
		return float(dic_combat[key])
	return 1.0



func get_runtime_blocking_rate(against: Battle_Unit) -> int:
	var rate = get_blocking_rate()
	if get_unit_type() in ["将"]:
		var wa = leader()
		if wa != null and wa.actorId == StaticManager.ACTOR_ID_ZHAOYUN and wa.get_controlNo() >= 0:
			
			rate += 20
		if against != null:
			match against.get_unit_type():
				"步":
					var extra = wa.actor().get_equip_feature_max("对步兵格挡率加成")
					if extra > 0:
						rate += extra
	return rate


func get_blocking_rate() -> int:
	var rate = 0
	if is_soldier():
		rate = get_combat_val_max("格挡率")
	elif get_unit_type() in ["将"]:
		rate = get_combat_val_max("格挡率")
		var wa = leader()
		if wa != null:
			
			rate += int(pow(wa.battle_courage, 2) / 200.0)
		var equipRate = wa.actor().get_equip_feature_max("格挡率加成")
		if equipRate > 0:
			rate += equipRate
	
	rate = min(80, rate)
	return rate

func actor() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(leaderId)


func get_action_times() -> int:
	if dic_combat.has("行动锁定"):
		return int(dic_combat["行动锁定"])
	return int(dic_combat["行动次数"])


func set_action_times(times: int, fixed: bool = false):
	dic_combat["行动次数"] = times
	if fixed:
		dic_combat["行动锁定"] = times
	return


func reset_action_times():
	dic_combat["行动次数"] = dic_combat["原行动次数"]
	return

func is_action_times_fixed() -> bool:
	return dic_combat.has("行动锁定")



func set_action_suppressed() -> void :
	if dic_combat.has("BUFF"):
		dic_combat["ORIGIN.BUFF"] = dic_combat["BUFF"]
	dic_combat["BUFF"] = - 1
	dic_combat["行动抑制"] = 1
	requires_update = true
	return




func check_action_suppressed(takeEffectAndRemove: bool = false) -> bool:
	if not dic_combat.has("行动抑制"):
		return false
	if takeEffectAndRemove:
		if dic_combat.has("ORIGIN.BUFF"):
			dic_combat["BUFF"] = dic_combat["ORIGIN.BUFF"]
		else:
			dic_combat.erase("BUFF")
		dic_combat.erase("行动抑制")
		wait_action_times = max(0, wait_action_times - 1)
	return true



func set_severe_damaged() -> void :
	if dic_combat.has("BUFF"):
		dic_combat["ORIGIN.BUFF"] = dic_combat["BUFF"]
	dic_combat["BUFF"] = - 1
	dic_combat["重伤"] = 1
	requires_update = true
	return


func check_severe_damage_status() -> bool:
	if not dic_combat.has("重伤"):
		return false
	if dic_combat.has("重伤完成"):
		if dic_combat.has("ORIGIN.BUFF"):
			dic_combat["BUFF"] = dic_combat["ORIGIN.BUFF"]
		else:
			dic_combat.erase("BUFF")
		for key in ["近身伤害", "射击伤害", "投掷伤害"]:
			var original = "ORIGIN." + key
			if dic_combat.has(original):
				dic_combat[key] = dic_combat[original]
		dic_combat.erase("重伤")
		dic_combat.erase("重伤完成")
		requires_update = true
		return false
	for key in ["近身伤害", "射击伤害", "投掷伤害"]:
		var original = "ORIGIN." + key
		if not dic_combat.has(original):
			dic_combat[original] = dic_combat[key]
			dic_combat[key] = float(dic_combat[key] * 0.25)
	dic_combat["重伤完成"] = 1
	return true



func check_critical_hit(isShooting: bool = false, targets: Array = []) -> bool:
	if not targets.empty() and targets[0].get_unit_type() in "城门":
		return false
	set_tmp_variable("暴击", 0)
	var criticalChance: float = get_combat_val_total("爆率")
	var criticalRate: float = get_combat_val_maxf("爆伤", 1.5)
	if isShooting:
		criticalChance = get_combat_val_total("射箭爆率")
		criticalRate = get_combat_val_maxf("射箭爆伤", 1.5)
	if criticalChance <= 0:
		return false
	if not Global.get_rate_result(int(criticalChance * 100)):
		return false
	set_tmp_variable("暴击", criticalRate)
	append_once_attack_tag("暴击#FF0000", 1)
	return true


func get_critical_damage_rate() -> float:
	var criticalRate = Global.floatval(get_tmp_variable("暴击", 1.0))
	
	return max(1.0, criticalRate)

func clear_tmp_variables():
	for k in dic_other_variable.keys():
		if k.begins_with("TMP."):
			dic_other_variable.erase(k)
	return

func get_tmp_variable(key: String, defVal = null):
	key = "TMP." + key
	if not key in dic_other_variable:
		return defVal
	return dic_other_variable[key]

func set_tmp_variable(key: String, val) -> void :
	key = "TMP." + key
	if val == null:
		dic_other_variable.erase(key)
		return
	dic_other_variable[key] = val
	return




func is_far_shooting() -> bool:
	if get_combat_val_max("视同强弩") >= 1:
		return true
	return leader().get_buff("强弩")["回合数"] > 0


func is_fire_shooting(targets: Array = []) -> bool:
	
	if dic_combat.has("禁用火矢"):
		return false
	
	
	if not targets.empty() and targets[0].get_unit_type() == "城门":
		return false
	var bf = DataManager.get_current_battle_fight()
	if get_unit_type() == "弓"\
	and bf.get_terrian() in ["walldoor", "wallcity"]\
	and bf.get_defender_id() == leaderId\
	and SkillRangeBuff.max_val_for_actor("守城火矢", leaderId) > 0:
		return true
	if get_combat_val_max("火矢") > 0:
		return true
	
	var buff_fire_arrow = leader().get_buff("火矢")
	if buff_fire_arrow["回合数"] > 0:
		return true
	return false


func cost_fire_shot() -> void :
	if not dic_combat.has("火矢"):
		return
	var times = Global.intval(dic_combat["火矢"])
	times = times - 1
	dic_combat["火矢"] = times
	if times <= 0:
		dic_combat.erase("火矢")
	return

func color() -> int:
	if leaderId < 0:
		return 4
	var leader = leader()
	if leader == null:
		return 2
	if leader.is_attacker():
		return 1
	if leader.is_defender():
		return 0
	return 4


func get_texture() -> Texture:
	var texture = null
	if DataManager.is_test_player():
		var modPath = "{0}mod/battle_character/{1}/{2}".format([
			DataManager.get_common_path(), color(), dic_combat["图像"], 
		])
		texture = Global.load_pic_with_cache(modPath)
		if texture != null:
			var width = texture.get_width()
			var height = texture.get_height()
			if width == 256 and height == 128:
				
				pass
			elif width == height * 2:
				
				pass
			elif width == height:
				
				pass
			else:
				
				texture = null
	if texture == null:
		var path = dic_combat["图像"]
		if not SoundManager.traditional_soldier_image and "新图像" in dic_combat:
			path = dic_combat["新图像"]
		path = "res://resource/images/battle_character/{0}/{1}".format([
			color(), path, 
		])
		texture = Global.load_pic_with_cache(path)
	return texture


func add_status_effect(status: String) -> void :
	var bf = DataManager.get_current_battle_fight()
	bf.add_status_effect(self, status)
	return


func check_for_kill_instant() -> bool:
	if disabled:
		return false
	if get_unit_type() != "将":
		return false
	if wait_action_times > 0:
		return false
	
	if last_action_name.begins_with("状态"):
		return false

	var wa = DataManager.get_war_actor(leaderId)
	if wa == null or wa.disabled:
		return false
	var killHP = wa.actor().get_equip_feature_max("斩杀线")
	killHP = min(99, killHP)
	if killHP <= 0:
		return false
	var toKill = []
	for dir in StaticManager.NEARBY_DIRECTIONS:
		var pos = unit_position + dir
		var bu = DataManager.get_battle_unit_by_position(pos)
		if bu == null or bu.disabled or bu.leaderId == leaderId:
			continue
		if bu.get_hp() > killHP or bu.get_unit_type() in ["将", "城门"]:
			continue
		toKill.append(bu)
	if toKill.empty():
		return false
	toKill.shuffle()
	toKill[0].wait_action_name = "被斩杀"
	add_status_effect("斩杀#FF0000")
	return true


func check_blocking_counter() -> bool:
	if get_unit_type() != "将":
		return false

	var attackUnitId = DataManager.get_env_int("白兵.攻击来源")
	if attackUnitId < 0 or attackUnitId >= DataManager.battle_units.size():
		return false
	var attackUnit = DataManager.battle_units[attackUnitId]
	if not "被格挡" in attackUnit.dic_other_variable:
		return false
	if not attackUnit.dic_other_variable["被格挡"]:
		return false

	var target = null
	var attackables = []
	for targets in get_unit_attack_area().values():
		for u in targets:
			if u.disabled or u.get_unit_type() in ["城门", "将"]:
				continue
			attackables.append(u)
	if attackables.empty():
		return false

	if attackUnit in attackables:
		target = attackUnit
	else:
		attackables.shuffle()
		target = attackables[0]

	var counter = false
	var actor = ActorHelper.actor(leaderId)
	if actor.get_equip_feature_max("格返") > 0:
		counter = true
	elif SkillRangeBuff.max_val_for_actor("格返", leaderId) > 0:
		counter = true
	if not counter:
		return false

	var bia = Battle_Instant_Action.new()
	bia.unitId = unitId
	bia.action = "攻击@格返#FF0000@0.5"
	bia.targetUnitId = target.unitId
	bia.targetPos = target.unit_position
	bia.actionTimes = 1
	bia.insert_to_env()
	return true


func check_shooting_back_counter() -> bool:
	if get_unit_type() != "将":
		return false

	var attackUnitId = DataManager.get_env_int("白兵.攻击来源")
	if attackUnitId < 0 or attackUnitId >= DataManager.battle_units.size():
		return false
	var attackUnit = DataManager.battle_units[attackUnitId]
	if not "被格挡" in attackUnit.dic_other_variable:
		return false
	if not attackUnit.dic_other_variable["被格挡"]:
		return false
	if attackUnit.last_action_name != "射箭":
		return false

	if SkillRangeBuff.max_val_for_actor("回矢", leaderId) <= 0:
		return false

	var bia = Battle_Instant_Action.new()
	bia.unitId = unitId
	bia.action = "射箭@回矢#FF0000"
	bia.targetUnitId = attackUnit.unitId
	bia.targetPos = attackUnit.unit_position
	bia.actionTimes = 1
	bia.insert_to_env()
	return true


func shootable(target: Battle_Unit) -> bool:
	if get_unit_type() != "将":
		return get_shoot_distance() > 0
	if target.get_unit_type() != "将":
		return get_shoot_distance() > 0
	
	var actor = actor()
	var hp = actor.get_equip_feature_min("允许射武将")
	if actor.get_jewelry().subtype() == "弓":
		var equipHP = SkillRangeBuff.max_val_for_actor("射击武将", leaderId)
		if equipHP > 0:
			hp = equipHP if hp <= 0 else min(hp, equipHP)
	if hp <= 0:
		return false
	hp = int(hp)
	if target.get_hp() < hp:
		
		return false
	return true


func is_general() -> bool:
	return get_unit_type() == "将"


func is_soldier() -> bool:
	if is_general():
		return false
	if get_unit_type() in ["城门", "拒马"]:
		return false
	return true


func get_basic_attack_val() -> int:
	var ret: int = 0
	var leader = leader()
	if leader == null:
		return ret
	match get_unit_type():
		"将":
			ret = leader.get_battle_power() * leader.battle_courage / 100.0 * 0.7
			ret += leader.actor().get_equip_attr_total("攻击力")
			ret += leader.actor().get_equip_feature_total("白兵攻击力")
			ret += get_extra_attack_power()
		_:
			var locked = get_combat_val_max("锁定士气")
			if locked > 0:
				return locked
			ret = leader.battle_morale

	
	if leader.get_buff("士气向上")["回合数"] > 0:
		ret += Global.get_random(5, 9)

	return ret



func get_defence_val(isBeingShot: bool = false, fireShooting: bool = false) -> float:
	var ret: float = 0.0
	var leader = leader()
	if get_unit_type() == "将":
		if leader != null:
			ret = leader.actor().get_equip_attr_total("防御力")
			ret += leader.battle_courage / 8.0
			ret = ret / 2.0
	else:
		if leader != null:
			ret = leader.battle_lead / 12.0
	if dic_combat.has("防御倍率"):
		ret = ret * float(dic_combat["防御倍率"])
	if leader != null and leader.get_buff("士气向上")["回合数"] > 0:
		
		ret = ret * 1.2
	if isBeingShot and get_unit_type() != "将":
		
		if fireShooting:
			ret -= ret / 3.0

	
	if leader != null and get_unit_type() != "将":
		var extra = SkillRangeBuff.max_val_for_actor("绮胄", leader.actorId)
		if extra > 0:
			ret += min(extra, leader.actor().get_equip_attr_total("防御力"))
	return ret


func initial_type_changed() -> bool:
	if not "初始兵种" in dic_other_variable:
		return false
	var origialType = Global.strval(dic_other_variable["初始兵种"])
	return origialType != Type


func reset_initial_type() -> bool:
	if not "初始兵种" in dic_other_variable:
		return false
	var origialType = Global.strval(dic_other_variable["初始兵种"])
	if origialType == Type:
		return false
	return reset_type(origialType)
