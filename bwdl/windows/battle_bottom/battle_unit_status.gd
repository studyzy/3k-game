# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/battle_bottom/battle_unit_status.gd
# 说明：战斗底部-单位状态 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control


const X_BOUNDARY = 16
const Y_BOUNDARY = 10

onready var tsp = $info / avatar / sp
onready var lbl = $info / avatar / name
onready var status = $info / status

var current: Battle_Unit


func _ready() -> void :
	return

func show_status(bu: Battle_Unit) -> void :
	current = bu
	if update_status():
		show()
	else:
		hide()
	return

func update_status() -> bool:
	$info.hide()
	if current == null:
		return false
	if current.disabled:
		return false
	lbl.text = "{0} #{1}".format([
		current.get_unit_type(), current.unitId
	])
	var rangedRate = current.get_shooting_damage_rate()
	if current.get_throw_type() > 0:
		rangedRate = current.get_throwing_damage_rate()
	var statuses = {
		"hp": current.get_hp(), 
		"times": [current.wait_action_times, current.dic_combat["行动次数"]], 
		"melee%": current.get_melee_damage_rate(), 
		"range%": rangedRate, 
		"avoid%": current.get_damage_avoid_rate(), 
		"block%": current.get_blocking_rate(), 
		"attack": current.get_basic_attack_val(), 
		"defence": current.get_defence_val(), 
	}
	for key in statuses:
		var suffix = ""
		var npath = key.replace("%", "") + "/val"
		if key.ends_with("%"):
			suffix = "%"
		var node = status.get_node_or_null(npath)
		if node == null:
			continue
		var val = statuses[key]
		if typeof(val) == TYPE_ARRAY:
			node.text = "/".join(val)
		else:
			node.text = str(int(val)) + suffix
	match current.get_unit_type():
		"将":
			status.get_node("hp/lbl").text = "体力"
			lbl.text = current.leader().get_name()
		"城门":
			status.get_node("hp/lbl").text = "耐久"
		_:
			status.get_node("hp/lbl").text = "兵力"
	
	var texture = current.get_texture()
	set_texture(texture, current.direction)
	$info.show()
	return true

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
	for sp in [tsp]:
		sp.texture = texture
		sp.hframes = hFrames
		sp.vframes = vFrames
		sp.frame_coords = Vector2(dir, 0)
		sp.scale = Vector2(scale, scale) * 1.5
	for sp in []:
		sp.frame_coords = Vector2(dir, secondaryIndex)
	return true

func _process(delta: float) -> void :
	if Time.get_ticks_msec() % 400 >= 200:
		if tsp.vframes > 1:
			tsp.frame_coords.y = 1
	else:
		tsp.frame_coords.y = 0
	return

func move_up() -> void :
	if current == null:
		return
	for y in range(current.unit_position.y - 1, - 1, - 1):
		var pos = Vector2(current.unit_position.x, y)
		if check_unit_at(pos):
			return
	return

func move_down() -> void :
	if current == null:
		return
	for y in range(current.unit_position.y + 1, Y_BOUNDARY):
		var pos = Vector2(current.unit_position.x, y)
		if check_unit_at(pos):
			return
	return

func move_left() -> void :
	if current == null:
		return
	
	for x in range(current.unit_position.x - 1, - 1, - 1):
		
		for yDiff in range(Y_BOUNDARY):
			var pos = Vector2(x, current.unit_position.y - yDiff)
			if check_unit_at(pos):
				return
			pos = Vector2(x, current.unit_position.y + yDiff)
			if check_unit_at(pos):
				return
	return

func move_right() -> void :
	if current == null:
		return
	
	for x in range(current.unit_position.x + 1, X_BOUNDARY):
		
		for yDiff in range(Y_BOUNDARY):
			var pos = Vector2(x, current.unit_position.y - yDiff)
			if check_unit_at(pos):
				return
			pos = Vector2(x, current.unit_position.y + yDiff)
			if check_unit_at(pos):
				return
	return

func move_current() -> void :
	var currentId = DataManager.get_env_int("白兵.行动单位")
	get_parent().highlight_unit(currentId)
	return

func keyin() -> void :
	if not visible:
		return
	if Input.is_action_just_pressed("ANALOG_UP"):
		move_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		move_down()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		move_right()
	if Input.is_action_just_pressed("EMU_START"):
		move_current()
	return

func check_unit_at(pos: Vector2) -> bool:
	var bu = DataManager.get_battle_unit_by_position(pos)
	if bu == null or bu.disabled:
		return false
	get_parent().highlight_unit(bu.unitId)
	return true
