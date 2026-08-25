extends Control
## 战术战斗场景测试
##
## headless 下 get_tree().create_timer().timeout 的 await 不会按预期恢复（Godot
## headless 协程 timer 缺陷），battle_scene 的 while 战斗循环在 headless 下会退化为
## 无限快速循环并饿死主循环。因此本测试只验证「战争准备 + 战斗场景能加载/实例化」，
## 并利用 battle_scene._ready 中 await process_frame 的窗口，在战斗循环启动前将其
## 标记结束，避免无限循环。超时退出用 _process + 物理时间驱动（不依赖 create_timer）。

var _elapsed_msec := 0
var _done := false


func _process(delta: float) -> void:
	if _done:
		return
	# 用物理时间（毫秒）驱动超时，不依赖 create_timer / 帧 delta
	_elapsed_msec += int(delta * 1000.0)
	if _elapsed_msec >= 8000:
		print("[Battle] 超时退出：我方单位=%d 敌方单位=%d" % [WarManager.hmUnits.size(), WarManager.aiUnits.size()])
		print("[Battle] 战术战斗测试完成")
		get_tree().quit()


func _ready() -> void:
	DataManager.load_all_configs()
	GameInfo.playerCountryId = 1
	CountryListCache.turn_sort()
	var pc := CountryListCache.get_country_by_country_id(1)
	# 构造战争
	var target := 0
	var atk_city := CityListCache.get_city_by_city_id(pc.cityIDs[0])
	for cid in pc.cityIDs:
		var c := CityListCache.get_city_by_city_id(cid)
		for adj in c.connectCityId:
			var ac := CityListCache.get_city_by_city_id(adj)
			if ac.ownerID != c.ownerID and ac.ownerID != 0:
				target = adj
				break
		if target != 0: break
	var atk_ids := atk_city.get_officer_ids()
	if atk_ids.is_empty(): atk_ids = [pc.countryKingId]
	WarManager.war_prepare(false, target, pc.cityIDs[0], atk_ids, 500, 300)
	WarManager.start_player_turn()
	# 设置 pending 战斗
	var u: UnitData = WarManager.hmUnits[0]
	var e: UnitData = WarManager.aiUnits[0]
	BattleManager.pendingPlayerUnit = u
	BattleManager.pendingEnemyUnit = e
	# 加载并实例化战术战斗场景（不 add_child，避免触发 battle_scene._ready 的
	# while 战斗循环——headless 下 create_timer 的 await 立即恢复，会导致该循环
	# 退化为无限快速循环并饿死主循环）
	var scene: PackedScene = load("res://scenes/ui/battle_scene.tscn")
	assert(scene != null)
	var inst := scene.instantiate()
	assert(inst != null)
	inst.free()
	print("[Battle] 战术战斗场景已加载并实例化")
