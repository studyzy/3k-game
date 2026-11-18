extends "effect_20000.gd"

#催进主动技，及监使附加效果
#【催进】大战场，主动技。你可以指定一个与你相邻的己方武将：若其体力＞50，则使其体力-3，并移动一格。每个回合限1次。
#【监使】大战场，锁定技。你的<催进>调整为每回合限3次；同时，你每执行一次<催进>你的机动力+3

const EFFECT_ID = 20212
const FLOW_BASE = "effect_" + str(EFFECT_ID)

const HP_LIMIT = 50

func effect_20212_start() -> void:
	var targetIds = []
	for wa in me.get_teammates(false, true):
		if Global.get_distance(wa.position, me.position) == 1:
			targetIds.append(wa.actorId)
	if not wait_choose_actors(targetIds, "选择队友发动【{0}】"):
		return
	LoadControl.set_view_model(2000)
	return

func on_view_model_2000() -> void:
	wait_for_choose_actor(FLOW_BASE + "_selected")
	return

func effect_20212_selected() -> void:
	var targetId = DataManager.get_env_int("目标")
	var targetWA = DataManager.get_war_actor(targetId)
	var targetActor = ActorHelper.actor(targetId)
	if targetActor.get_hp() <= HP_LIMIT:
		var msg = "{0}体力不足，需 > {1}".format([
			targetActor.get_name(), HP_LIMIT
		])
		play_dialog(actorId, msg, 3, 2999)
		return

	#移动目标列表
	var goto = []
	map.show_color_block_by_position([])
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var pos = targetWA.position + dir
		if not targetWA.can_move_to_position(pos):
			continue
		var blockCN = map.get_blockCN_by_position(pos)
		if blockCN in StaticManager.CITY_BLOCKS_CN:
			# 不能选城地形
			continue
		goto.append(pos)
	if goto.empty():
		var msg = "无可用位置"
		play_dialog(actorId, msg, 3, 2999)
		return

	map.set_cursor_location(goto[0], true)
	map.show_color_block_by_position(goto)
	var msg = "请指定【{0}】位移地点".format([ske.skill_name])
	SceneManager.show_unconfirm_dialog(msg)
	DataManager.set_env("可选目标", goto)
	DataManager.set_target_position(goto[0])
	LoadControl.set_view_model(2001)
	return

func on_view_model_2001() -> void:
	wait_for_choose_position(FLOW_BASE + "_targeted")
	return

func effect_20212_targeted() -> void:
	var targetId = DataManager.get_env_int("目标")
	var targetActor = ActorHelper.actor(targetId)
	var msg = "对{0}发动【{1}】\n{0}体力将会 -3，可否？".format([
		targetActor.get_name(), ske.skill_name
	])
	play_dialog(actorId, msg, 2, 2002, true)
	return

func on_view_model_2002() -> void:
	wait_for_yesno(FLOW_BASE + "_confirmed")
	return

func effect_20212_confirmed() -> void:
	var targetId = DataManager.get_env_int("目标")
	var targetPosition = DataManager.get_target_position()

	perform_cost()
	ske.change_actor_hp(targetId, -3)
	ske.change_war_actor_position(targetId, targetPosition)
	ske.war_report()

	var msg = "军情紧急，{0}速进".format([
		DataManager.get_actor_honored_title(targetId, actorId),
	])
	me.attach_free_dialog(msg, 2)

	map.show_color_block_by_position([])
	map.draw_actors()
	FlowManager.add_flow("player_skill_end_trigger")
	return

func perform_cost() -> void:
	var special = SkillHelper.actor_has_skills(actorId, ["监使"], false)
	if special:
		ske.cost_war_limited_times(3)
		ske.change_actor_ap(actorId, 3)
	else:
		ske.cost_war_cd(1)
	return
