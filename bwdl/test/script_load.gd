extends "base.gd"

func runAll() -> bool:
	return runLoadAll() and runCheckAll()

func runLoadAll() -> bool:
	return _loadPath("resource/sgz_script/")

func runCheckAll() -> bool:
	return true\
	and _checkSkills("resource/sgz_script/effects/10000-affiars")\
	and _checkSkills("resource/sgz_script/effects/20000-war")\
	and _checkSkills("resource/sgz_script/effects/30000-battle")\
	and _checkSkills("resource/sgz_script/effects/40000-solo")\
	and true

func _loadPath(dir: String) -> bool:
	trace("Loading... " + dir)
	var paths = Global.scan_all_files(dir)
	var cnt = 0
	for path in paths:
		if not str(path).ends_with(".gd"):
			continue
		var script = Global.load_script(path)
		var msg = "加载" + path
		assertTrue(script != null, msg)
		cnt += 1
		yield(SceneManager.current_scene(), "traced")
	trace("{0}个脚本加载正常".format([cnt]))
	return true

func _checkSkills(dir: String) -> bool:
	trace("Loading... " + dir)
	var paths = Global.scan_all_files(dir)
	var cnt = 0
	var triggers = 0
	var triggered = 0
	var AI_enabled = 0
	trace("{0} scripts found".format([paths.size()]))
	for i in paths.size():
		var path = str(paths[i])
		if not path.ends_with(".gd"):
			continue
		var effectId = int(path.get_file().get_basename().replace(".gd", "").replace("effect_", ""))
		var actorId = ActorHelper.random_actor_id()
		var enemyId = ActorHelper.random_actor_id()
		var ske = SkillEffectInfo.new()
		ske.skill_actorId = actorId
		ske.skill_name = path.get_basename()
		ske.actorId = actorId
		ske.effect_Id = effectId
		SkillHelper.save_skill_effectinfo(ske)
		DataManager.grouped_trace_reset()
		for triggerId in get_all_trigger_ids(effectId):
			SceneManager.current_scene().SCENE_ID = effectId - effectId % 10000
			DataManager.grouped_trace("")
			var script = Global.load_script(path)
			var msg = "加载" + path
			assertTrue(script != null, msg)
			script.triggerId = triggerId
			script.actorId = actorId
			script._init()
			
			script.check_trigger_correct()
			script.check_AI_perform()
			ske.trigger_Id = triggerId
			SkillHelper.save_skill_effectinfo(ske)
			DataManager.grouped_trace("SKE")
			if triggerId >= 20000:
				initWar(0, 1, 0)
				createWarActor(actorId, 0, true)
				createWarActor(enemyId, 1, true)
			if triggerId >= 30000:
				initBattle(actorId, enemyId)
			DataManager.grouped_trace("PRE")
			var initMethod = "init_env_for_trigger_{0}".format([triggerId])
			if has_method(initMethod):
				call(initMethod, actorId, enemyId)
			DataManager.grouped_trace("INIT")
			
			script = Global.load_script(path)
			script.triggerId = triggerId
			script.actorId = actorId
			DataManager.grouped_trace("RELOAD")
			if script.check_trigger_correct():
				triggered += 1
			triggers += 1
			DataManager.grouped_trace("TRIGGER")
			if script.check_AI_perform():
				AI_enabled += 1
			DataManager.grouped_trace("AI")
		
		cnt += 1
	trace("{0}个技能脚本基本检查正常".format([cnt]))
	trace("{0}个技能触发检查正常".format([triggers]))
	trace("{0}个技能脚本被触发".format([triggered]))
	trace("{0}个技能脚本支持AI触发".format([AI_enabled]))
	return true

func get_all_trigger_ids(effectId: int) -> PoolIntArray:
	var ret = []
	for skill in StaticManager.skillDict.values():
		for effect in skill.effects:
			if effect.id != effectId:
				continue
			if effect.triggerId <= 0:
				continue
			ret.append(effect.triggerId)
	return ret

func init_env_for_trigger_20014(actorId: int, enemyId: int):
	DataManager.set_env("战争.攻击消耗", {
		"攻击来源": actorId, 
		"攻击目标": enemyId, 
		"初始": 4, 
		"减少": 0, 
		"增加": 0, 
		"至少": 0, 
		"至多": - 1, 
		"固定": - 1, 
	})
	return

func init_env_for_trigger_20011(actorId: int, enemyId: int):
	DataManager.set_env("计策.ONCE.伤害武将", actorId)
	return

func init_env_for_trigger_30001(actorId: int, enemyId: int):
	DataManager.set_env("白兵.行动单位", 0)
	return
