# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/conEquipInfo.gd
# 说明：装备信息 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control


var baseline = 410

func _ready() -> void :
	return

func _process(delta: float) -> void :
	if not visible:
		return
	update_offset()
	return
	
func show_equipinfo(equip: clEquip.EquipInfo, mode: String = "info"):
	baseline = 410
	var msg = "[center]" + equip.get_description() + "[/center]";
	match mode:
		"info":
			msg += "\n[center]（← →切换装备）[/center]";
			$txt.rect_min_size = Vector2(600, 180)
			$txt.rect_size = Vector2(600, 180)
		"shop":
			$txt.rect_min_size = Vector2(600, 150)
			$txt.rect_size = Vector2(600, 150)
		"warehouse":
			baseline = 600
			$txt.rect_min_size = Vector2(600, 200)
			$txt.rect_size = Vector2(600, 200)
		_:
			$txt.rect_min_size = Vector2(600, 150)
			$txt.rect_size = Vector2(600, 150)
	$txt.bbcode_text = msg;
	update_offset()
	return

func show_war_status(wa: War_Actor):
	baseline = 410
	$txt.rect_min_size = Vector2(600, 100)
	$txt.rect_size = Vector2(600, 100)
	var war_map = SceneManager.current_scene().war_map
	var statuses = []
	if wa.is_puppet():
		statuses.append("人偶")
	for buff in StaticManager.WAR_BUFF_STATUSES:
		var turn = wa.get_buff(buff)["回合数"]
		if turn > 0:
			var label = StaticManager.WAR_BUFF_STATUSES[buff]
			statuses.append("{0}:{1}".format([label, min(99, turn)]))
	var status = "　".join(statuses)
	if status.length() == 0:
		status = "正常"
	var blockCN = war_map.get_blockCN_by_position(wa.position)
	if statuses.size() >= 3:
		$txt.bbcode_text = "[center]　[/center]\n　　机动：{2}/{3}　　地形：{0}\n　　状态：{1}".format([
			blockCN, status, wa.action_point, wa.get_max_action_ap(), 
		])
	else:
		$txt.bbcode_text = "[center]　[/center]\n　　机动：{2}/{3}　　地形：{0}　　状态：{1}　　".format([
			blockCN, status, wa.action_point, wa.get_max_action_ap(), 
		])

	update_offset()
	return

func reset_layout_landscape():
	rect_scale = Vector2(1, 1)
	update_offset()
	return

func reset_layout_portrait():
	rect_scale = Vector2(1.70666, 1.6)
	update_offset()
	return

func update_offset():
	var w = 600
	var h = max($txt.rect_size.y, $txt.get_content_height())
	rect_min_size = Vector2(w, h)
	rect_size = Vector2(w, h)
	$txt.rect_min_size.y = h
	$txt.rect_size.y = h
	if SceneManager.portrait_mode:
		rect_position = Vector2(0, baseline * 1.6 - rect_size.y * 1.6 + 2)
		$txt.rect_position = Vector2(0, 0)
	else:
		rect_position = Vector2(212, baseline - rect_size.y + 2)
		$txt.rect_position = Vector2(0, 0)
	return
