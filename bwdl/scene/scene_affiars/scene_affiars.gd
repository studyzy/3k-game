extends Control

const SCENE_ID = 10000

const CITY_LINE_NOTICES = [
	"<< B   查看城池连线   A >>", 
	"<< B   查看城池地名   A >>", 
	"<< B   势力分布图略   A >>", 
	"<< B   特殊装备所在   A >>", 
]

onready var con_citys = get_node("others/con_citys")
onready var cursor = get_node("others/con_citys/curosr")
onready var con_citys_lines = get_node("others/con_citys_lines")

onready var map = get_node("map/map")
onready var region = get_node("region")
onready var ym = get_node("others/YearMonth")
onready var affair_log = get_node("others/affair_log")

var city_line_mode: int = 0
var is_ready = false
var affiars_run

var cityLineFromId: int = - 1

var citySpecialLineMode: int = 0


var inspecting: bool = false

func _ready() -> void :
	affiars_run = Global.load_script(DataManager.mod_path + "sgz_script/affiars/auto_events/affiars_auto_run.gd")
	DataManager.twinkle_citys.clear()
	SceneManager.load_scene_complete = true
	update_year_month()
	FlowManager.force_change_controlNo(0)
	init_city_nodes()
	SceneManager.hide_all_tool()
	SoundManager.play_bgm()
	reset_view()
	is_ready = true
	return


func init_city_nodes():
	var n_cursor = cursor.duplicate();
	Global.clearNode(con_citys);
	
	var btn_city_pack: PackedScene = load("res://windows/children/btn_city.tscn");
	for city in clCity.all_cities():
		var btn_city: Control = btn_city_pack.instance()
		btn_city.cityId = city.ID
		btn_city.name = str(city.ID)
		con_citys.add_child(btn_city)
	
	cursor = n_cursor;
	con_citys.add_child(n_cursor);
	return


func get_city_node(cityId: int) -> Node:
	return con_citys.get_node_or_null(str(cityId))

var _process_times = 0;

var cursor_last_move_h = - 1;
var cursor_last_move_v = - 1;
const cursor_move_interval = 60000;

func _process(delta: float) -> void :
	if is_instance_valid(affiars_run):
		affiars_run._process(delta)
	if DataManager.is_autoplay_mode() and not SceneManager.lsc_menu_top.visible:
		SceneManager.show_system_notice("演示中。长按「开始」键，次月接管")
	_check_city_twinkle()
	return

func update_year_month() -> void :
	_rpc_update_year_month();
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_update_year_month");
	return

remote func _rpc_update_year_month() -> void :
	var lblyear: Label = ym.get_node("year");
	var lblmonth: Label = ym.get_node("month");
	var lblseason: Label = ym.get_node("season");
	
	lblyear.text = str(DataManager.year) + "年";
	lblmonth.text = str(DataManager.month) + "月";
	
	var keys = ["color_rgb", "area_r", "area_g", "area_b"];
	var sh_material: ShaderMaterial = map.material;
	var dic_pre = {};
	var dic_new = {};
	for key in keys:
		dic_pre[key] = sh_material.get_shader_param(key);
		
	if (DataManager.month >= 3 and DataManager.month <= 5):
		lblseason.text = "春";
		dic_new["color_rgb"] = Vector3(2, 0.95, 2);
		dic_new["area_r"] = Vector2(0, 0.5);
		dic_new["area_g"] = Vector2(0, 2);
		dic_new["area_b"] = Vector2(0, 0.5);
	elif (DataManager.month >= 6 and DataManager.month <= 8):
		lblseason.text = "夏";
		dic_new["color_rgb"] = Vector3(1, 1, 1);
		dic_new["area_r"] = Vector2(0, 0.5);
		dic_new["area_g"] = Vector2(0, 2);
		dic_new["area_b"] = Vector2(0, 0.5);
	elif (DataManager.month >= 9 and DataManager.month <= 11):
		lblseason.text = "秋";
		dic_new["color_rgb"] = Vector3(6.0, 0.65, 1.0);
		dic_new["area_r"] = Vector2(0, 0.5);
		dic_new["area_g"] = Vector2(0, 2);
		dic_new["area_b"] = Vector2(0, 0.5);
	else:
		lblseason.text = "冬";
		dic_new["color_rgb"] = Vector3(4, 0.8, 4);
		dic_new["area_r"] = Vector2(0, 2);
		dic_new["area_g"] = Vector2(0.8, 2.0);
		dic_new["area_b"] = Vector2(0, 2);
	for key in dic_new:
		sh_material.set_shader_param(key, dic_new[key])
	return


func set_city_cursor_position(cityId: int) -> void :
	var node: Node = con_citys.get_node_or_null(str(cityId));
	if (node == null):
		return ;
	set_cursor_location(node.rect_position + Vector2(4, 10));


func get_curosr_point_city() -> int:
	var allow_dis = 30;
	var choose_cityId = - 1;
	for city in clCity.all_cities():
		var node: Node = con_citys.get_node(str(city.ID));
		var fix_city_position: Vector2 = node.rect_position + Vector2(4, 10);
		var dis_v: Vector2 = cursor.rect_position - fix_city_position;
		var distance = abs(dis_v.x) + abs(dis_v.y);
		if (distance > allow_dis):
			continue;
		allow_dis = distance;
		choose_cityId = city.ID;
	return choose_cityId;

func cursor_move_check(vertical: bool = false):
	var now = Time.get_ticks_usec()
	var _last = cursor_last_move_h
	if vertical:
		_last = cursor_last_move_v
	if now - _last < cursor_move_interval:
		return false
	if vertical:
		cursor_last_move_v = now
	else:
		cursor_last_move_h = now
	return true

func cursor_move_up(delta: float) -> void :
	if not cursor_move_check(true):
		return
	if (cursor.rect_position.y <= 6):
		return ;
	set_cursor_location(cursor.rect_position - Vector2(0, SceneManager.cursor_speed))
	
func cursor_move_down(delta: float) -> void :
	if not cursor_move_check(true):
		return
	if (cursor.rect_position.y >= 377):
		return ;
	
	set_cursor_location(cursor.rect_position + Vector2(0, SceneManager.cursor_speed));

func cursor_move_left(delta: float) -> void :
	if not cursor_move_check():
		return
	if (cursor.rect_position.x <= 4):
		return ;
	set_cursor_location(cursor.rect_position - Vector2(SceneManager.cursor_speed, 0))

func cursor_move_right(delta: float) -> void :
	if not cursor_move_check():
		return
	if (cursor.rect_position.x >= 581):
		return ;
	set_cursor_location(cursor.rect_position + Vector2(SceneManager.cursor_speed, 0))

func set_cursor_location(location: Vector2):
	SceneManager.update_runtime_info({"pos": location})
	_set_cursor_location(location);
	if (AutoLoad.check_is_multigame()):
		rpc("_set_cursor_location", location);

remote func _set_cursor_location(location: Vector2):
	cursor.rect_position = location;

func show_affair_log() -> void :
	var msg = "[B] / [选择]，回到大地图\n上下左右移动查看日志"
	SceneManager.show_unconfirm_dialog(msg)
	SceneManager.dialog_msg_complete(true)
	affair_log.update_data()
	affair_log.show()
	return

func close_affair_log() -> void :
	affair_log.hide()
	return


func show_city_line(b: bool, mode: int = 0):
	city_line_mode = (mode + 4) % 4
	if not b:
		con_citys_lines.hide()
		show_region(false)
		return
	var msg = CITY_LINE_NOTICES[city_line_mode] + "\n「开始」查看大地图日志\n「选择」键返回"
	SceneManager.show_unconfirm_dialog(msg)
	SceneManager.dialog_msg_complete(true)
	con_citys_lines.update()
	con_citys_lines.show()
	show_region(city_line_mode == 2)
	return


func _on_con_citys_lines_draw() -> void :
	if cityLineFromId < 0:
		for id in clCity.all_city_ids():
			_draw_city_line(id)
	else:
		var fromCity = clCity.city(cityLineFromId)
		match citySpecialLineMode:
			0:
				var attackables = clCity.get_attackable_city_ids(fromCity)
				if attackables.empty():
					return
				_draw_city_line(cityLineFromId, attackables)
			1:
				var connected = clCity.get_movable_city_ids(fromCity)
				if connected.empty():
					return
				_draw_city_line(cityLineFromId, connected)
	return


func _draw_city_line(cityId: int, attackables: Dictionary = {}):
	var offset = Vector2(15, 15)
	var fromNode: Control = get_city_node(cityId)
	if fromNode == null:
		return
	var fromCity = clCity.city(cityId)
	var fromPoint: Vector2 = fromNode.rect_position + offset
	var thickness = 2.0
	if city_line_mode == 2:
		thickness = 1.0

	
	if attackables.empty():
		for toCityId in fromCity.get_connected_city_ids():
			var toNode: Control = get_city_node(toCityId)
			if toNode == null:
				continue
			var toCity = clCity.city(toCityId)
			var toPoint: Vector2 = toNode.rect_position + offset
			if cityId in toCity.get_connected_city_ids():
				
				con_citys_lines.draw_line(fromPoint, toPoint, Color("#ee0000"), thickness, true)
			else:
				
				con_citys_lines.draw_line(fromPoint, toPoint, Color.antiquewhite, thickness, true)
		return

	offset = Vector2(13, 13)
	var offset2 = Vector2(16, 16)
	
	for targetId in attackables:
		fromNode = get_city_node(targetId)
		if fromNode == null:
			continue
		var route = attackables[targetId]
		if route.size() == 1:
			fromPoint = fromNode.rect_position + offset
			var toNode: Control = get_city_node(cityId)
			if toNode == null:
				return
			var toPoint: Vector2 = toNode.rect_position + offset
			con_citys_lines.draw_line(fromPoint, toPoint, Color("#ee0000"), thickness, true)
			continue
		fromPoint = fromNode.rect_position + offset2
		while not route.empty():
			var toCityId = route.pop_back()
			var toNode: Control = get_city_node(toCityId)
			if toNode == null:
				break
			var toPoint: Vector2 = toNode.rect_position + offset2
			con_citys_lines.draw_line(fromPoint, toPoint, Color("#eeff00"), thickness, true)
			fromNode = toNode
			fromPoint = toPoint
	return

func _check_city_twinkle():
	var timer: Timer = get_node("Timer_city_twinkle");
	if DataManager.twinkle_citys.size() > 0:
		if timer.is_stopped():
			timer.start()
	else:
		_on_check_twinkle_citys()
	return

var _city_twinkle_show_state = true;
func _on_Timer_city_twinkle_timeout() -> void :
	var timer: Timer = get_node("Timer_city_twinkle");
	_city_twinkle_show_state = not _city_twinkle_show_state;
	for city in DataManager.citys:
		var cityId = int(city["ID"])
		var node: Node = con_citys.get_node_or_null(str(cityId))
		if node == null:
			continue;
		if cityId in DataManager.twinkle_citys:
			node.set_icon_visible(_city_twinkle_show_state)
		else:
			node.set_icon_visible(true)
	return

func _on_check_twinkle_citys():
	if DataManager.twinkle_citys.size() == 0:
		var timer: Timer = get_node("Timer_city_twinkle");
		timer.stop()
		for city in clCity.all_cities():
			var node: Node = con_citys.get_node_or_null(str(city.ID))
			if node == null:
				continue;
			node.set_icon_visible(true)
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.70666, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(212, 0)
	rect_scale = Vector2(1, 1)
	return

func show_region(on: bool) -> void :
	if not on:
		map.modulate = Color("#FFFFFFFF")
		region.hide()
		return
	var colors = {}
	for vs in clVState.all_vstates():
		if vs.is_perished():
			continue
		
		var borderColor = Color(vs.get_color()[0])
		var fillColor = Color(vs.get_color()[1])
		var color = fillColor
		
		if Global.color_distance(fillColor, Color.black) < 0.1\
		and Global.color_distance(borderColor, Color.white) > 0.1:
			color = borderColor
		var checking = colors.values()
		var checked = []
		var reCheckTimes = 3
		while reCheckTimes >= 0 and not checking.empty():
			var c = checking.pop_front()
			checked.append(c)
			if Global.color_distance(c, color) > 0.1:
				continue
			
			var r = color.r
			var g = color.g
			var b = color.b
			
			if max(max(r, g), b) < 0.3:
				r = r * 1.4
				g = g * 1.4
				b = b * 1.4
			else:
				r = r * 0.7
				g = g * 0.7
				b = b * 0.7
			color = Color(r, g, b)
			
			reCheckTimes -= 1
			checking.append_array(checked)
			checked = []
		colors[vs.id] = color
	for child in region.get_children():
		if not child is TextureRect:
			continue
		var cityId = Global.intval(child.name)
		if child.name != str(cityId):
			continue
		if cityId < 0:
			continue
		var city = clCity.city(cityId)
		var vstateId = city.get_vstate_id()
		if vstateId < 0 or not vstateId in colors:
			
			child.modulate = "#80000000"
			child.show()
			continue
		var mod = Color(colors[vstateId])
		mod.a = 1.0
		child.modulate = mod
		child.show()
	map.modulate = Color("#30FFFFFF")
	region.show()
	return


func reset_view() -> void :
	cityLineFromId = - 1
	citySpecialLineMode = 0
	city_line_mode = 0
	cursor.hide()
	con_citys_lines.hide()
	show_region(false)
	return


func show_attackable_city_lines(fromCityId: int) -> void :
	reset_view()
	cityLineFromId = fromCityId
	citySpecialLineMode = 0
	city_line_mode = 0
	con_citys_lines.show()
	cursor.show()
	return


func show_movable_city_lines(fromCityId: int) -> void :
	reset_view()
	cityLineFromId = fromCityId
	citySpecialLineMode = 1
	city_line_mode = 0
	con_citys_lines.show()
	cursor.show()
	return
