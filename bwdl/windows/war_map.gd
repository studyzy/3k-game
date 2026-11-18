extends Control

const MASK_COLOR = "#60F00000"
const SELECTOR_COLOR = "#400000F0"
const DISABLED_COLOR = "#A0FF2100"
const GRID_COLOR = "#F0F0F0F0"
const FIVE_PHASES_AGAINST_COLOR = "#A0FF4C00"
const CAMER_DONE_STEPS = "战争.镜头移动方法"

onready var view = get_node("view");
onready var mapA = get_node("view/mapA");
onready var mapB = get_node("view/mapB");
onready var show_select_layer = get_node("view/show_select_layer");
onready var tweenMap = get_node("Tween")
onready var tweenWA = get_node("TweenWA")

onready var warStatus = get_node("showInfo")


var actorViewMode: int = 0


var observerId: int = - 1


var blockInfo: Dictionary = {}


var originalBlockInfo: Dictionary = {}

var builds_position: Dictionary = {}


onready var dic_actor_layer = {
	"战斗区": get_node("view/actor_battle_layer"), 
	"NPC区": get_node("view/actor_npc_layer"), 
}
onready var fog = get_node("view/fog");
onready var build_layer = get_node("view/build_layer");
onready var cursor = get_node("view/top/cursor");

export var cursor_position: Vector2 = Vector2(18, 8);
export var camer_position: Vector2 = Vector2(10, 3);


var warCityPosition: Vector2 = Vector2( - 1, - 1)

var door_position: PoolVector2Array = []

var inner_door_positions: PoolVector2Array = []

const cell_columns = 32;
const cell_rows = 20;
const block_size = 40;

const camer_times = 0.05;


export var next_shrink_actors = []
export var _current_shrink_actors = []
export var can_choose_actors = []
export var disabledTargets = []
var _can_choose_actors = []

export var map_data: Array


var aStar: AStar2D


var apActorId = - 1


var _rect_tips_queue: Dictionary = {}

var _rect_tips_playing: Dictionary = {}

func set_save_cursor_position(v: Vector2):
	DataManager.set_env("光标位置", {
		"x": v.x, 
		"y": v.y
	})
	SceneManager.update_runtime_info({"pos": v})
	return

func get_save_cursor_position() -> Vector2:
	var dic = DataManager.get_env_dict("光标位置")
	if not "x" in dic or not "y" in dic:
		return Vector2(18, 8)
	return Vector2(int(dic["x"]), int(dic["y"]))

func set_save_carmer_position(v: Vector2):
	DataManager.set_env("镜头位置", {
		"x": v.x, 
		"y": v.y
	})
	return

func get_save_carmer_position() -> Vector2:
	var dic = DataManager.get_env_dict("镜头位置")
	if not "x" in dic or not "y" in dic:
		return Vector2(10, 3)
	return Vector2(int(dic["x"]), int(dic["y"]))


func _ready() -> void :

	warStatus.visible = false
	DataManager.connect("soldier_damaged", self, "_on_soldier_damaged")
	DataManager.connect("hp_damaged", self, "_on_hp_damaged")
	
	map_data = StaticManager.get_war_map_data(cityId())

	init_map()
	cursor.hide();
	
	for key in dic_actor_layer:
		Global.clearNode(dic_actor_layer[key]);
	
	update_camer_position_at_once(get_save_carmer_position());
	
	cursor_position = get_save_cursor_position();
	


	update_cursor_position_at_once();
	draw_actors();
	return
	
func request_ready():
	return

func cityId():
	var wf = DataManager.get_current_war_fight()
	return wf.target_city().ID

func get_blockCN_by_EN(blockEN: String):
	if StaticManager.BLOCKS_EN_CN.has(blockEN):
		return StaticManager.BLOCKS_EN_CN[blockEN]
	return "未知"

func get_blockEN_by_CN(blockCN: String):
	for bEN in StaticManager.BLOCKS_EN_CN.keys():
		if StaticManager.BLOCKS_EN_CN[bEN] == blockCN:
			return bEN
	return "unknown"

func init_map():
	Global.clearNode(mapA)
	Global.clearNode(mapB)
	Global.clearNode(build_layer)
	blockInfo.clear()
	originalBlockInfo.clear()
	door_position = []

	var mapData = get_map_data()
	for x in cell_columns:
		for y in cell_rows:
			redraw_position(Vector2(x, y), mapData)

	init_astar()
	endless_specials()
	return

func redraw_position(pos: Vector2, mapData: Array = []) -> void :
	if mapData.empty():
		mapData = get_map_data()
	var idx = pos.y * cell_columns + pos.x
	if idx < 0 or idx >= mapData.size():
		return
	var blockName = mapData[idx]
	var exactPosition = pos * block_size

	
	var buildings = ["wallcity", "hospital", "equip", "rice", "walldoor", "village"]
	
	var war_into_land = ["hospital", "equip", "rice", "village"]

	var is_building = false
	var block_EN = blockName.split("_")[0]
	var block_CN = get_blockCN_by_EN(block_EN)

	
	if block_EN in buildings:
		if block_EN in ["walldoor"]:
			door_position.append(pos)
		else:
			is_building = true

	for child in build_layer.get_children():
		if child.rect_position == exactPosition:
			build_layer.remove_child(child)
			break
	if is_building:
		var rect = create_block_image_tect(blockName, "A", pos)
		builds_position[block_CN] = pos
		
		build_layer.add_child(rect)

	if block_EN in war_into_land:
		block_EN = "land"
		block_CN = "平原"
		blockName = "land_118"
	set_map_block(blockName, pos)
	return


func get_buildCN_by_position(position: Vector2) -> String:
	position = Vector2(int(position.x), int(position.y));
	for bulid_rect in build_layer.get_children():
		var x = int(bulid_rect.rect_position.x / block_size);
		var y = int(bulid_rect.rect_position.y / block_size);
		
		var bulid_position: Vector2 = Vector2(x, y);
		if (bulid_position == position):
			return bulid_rect.editor_description;
	return "";

func get_position_by_buildCN(build_name: String) -> Vector2:
	for bulid_rect in build_layer.get_children():
		var x = int(bulid_rect.rect_position.x / block_size);
		var y = int(bulid_rect.rect_position.y / block_size);
		
		var bulid_position: Vector2 = Vector2(x, y);
		if (bulid_rect.editor_description == build_name):
			return bulid_position;
	return Vector2( - 1, - 1);


func get_blockCN_by_position(pos: Vector2, original: bool = false) -> String:
	pos = Vector2(int(pos.x), int(pos.y))
	if not is_valid_position(pos):
		return ""
	if original:
		if not pos in originalBlockInfo:
			var block = map_data[pos.y * cell_columns + pos.x]
			block = block.split("_")[0]
			block = get_blockCN_by_EN(block)
			originalBlockInfo[pos] = block
		return originalBlockInfo[pos]
	if not "A" in blockInfo:
		return ""
	if not pos in blockInfo["A"]:
		return ""
	return blockInfo["A"][pos]


func clear_area_trapped() -> void :
	var c = Color(1, 1, 1, 1)
	for block in mapA.get_children():
		block.self_modulate = c
	for block in mapB.get_children():
		block.self_modulate = c
	return


func mark_area_trapped(on: bool, pos: Vector2, rng: int) -> void :
	var terrian = get_blockCN_by_position(pos)
	var terrianEN = get_blockEN_by_CN(terrian)
	var c = Color(0.5, 0.5, 0.5, 0.9)
	if not on:
		c = Color(1, 1, 1, 1)
	for block in mapA.get_children():
		var v = Vector2(int(block.rect_position.x / block_size), int(block.rect_position.y / block_size))
		var disv = v - pos
		if max(abs(disv.x), abs(disv.y)) > rng:
			continue
		if on and block.editor_description != terrian:
			continue
		block.self_modulate = c
	for block in mapB.get_children():
		var v = Vector2(int(block.rect_position.x / block_size), int(block.rect_position.y / block_size))
		var disv = v - pos
		if max(abs(disv.x), abs(disv.y)) > rng:
			continue
		if on and block.editor_description != terrianEN:
			continue
		block.self_modulate = c
	return


func show_color_block_by_position(positions: PoolVector2Array, color: Color = MASK_COLOR):
	Global.clearNode(show_select_layer);
	show_select_layer.visible = not positions.empty();
	for pos in positions:
		var rect = get_node("example_choose").duplicate()
		rect.color = color
		rect.rect_position = pos * block_size
		show_select_layer.add_child(rect)
	return




func draw_outline_by_range(center: Vector2, rng: int, color: Color = GRID_COLOR, showExtra: bool = true, rangeDistance: bool = true):
	if rng == 0 or rng >= 99:
		return
	if not rangeDistance:
		
		draw_outline_by_diamond(center, rng, color)
		return
	var centers = [center]
	if showExtra:
		for posInfo in DataManager.get_env_array("额外技能选区"):
			centers.append(Vector2(int(posInfo["x"]), int(posInfo["y"])))
	var rects = []
	for c in centers:
		var rect = Rect2()
		rect.position.x = c.x - rng
		rect.position.y = c.y - rng
		rect.size.x = rng * 2 + 1
		rect.size.y = rng * 2 + 1
		rects.append(rect)
	draw_outline_by_rects(rects, color)
	return

func draw_outline_by_rects(rects: Array, color: Color = GRID_COLOR) -> void :
	Global.clearNode(show_select_layer)
	show_select_layer.visible = true
	for rect in rects:
		var settings = []
		for x in rect.size.x:
			
			var pt1 = Vector2(rect.position.x + x, rect.position.y)
			settings.append([pt1, false, false])
			
			var pt2 = Vector2(rect.position.x + x, rect.position.y + rect.size.y - 1)
			settings.append([pt2, false, true])
		for y in rect.size.y:
			
			var pt1 = Vector2(rect.position.x, rect.position.y + y)
			settings.append([pt1, true, false])
			
			var pt2 = Vector2(rect.position.x + rect.size.x - 1, rect.position.y + y)
			settings.append([pt2, true, true])
		for setting in settings:
			var pos = setting[0]
			var vertical = setting[1]
			var opposite = setting[2]
			if not is_valid_position(pos):
				continue
			var overlapped = false
			for r in rects:
				if r == rect:
					continue
				if not r.has_point(pos):
					continue
				var disv = pos - r.position
				if disv.x > 0 and vertical:
					overlapped = true
					break
				if disv.y > 0 and not vertical:
					overlapped = true
					break
			if overlapped:
				continue
			var pnl = get_node("sample_grid").duplicate()
			var st = pnl.get_stylebox("panel").duplicate()
			st.vertical = vertical
			st.color = color
			pnl.add_stylebox_override("panel", st)
			pnl.rect_position = pos * block_size
			if opposite:
				if vertical:
					pnl.rect_position += Vector2(38, 0)
				else:
					pnl.rect_position += Vector2(0, 38)
			show_select_layer.add_child(pnl)
	return

func draw_outline_by_diamond(center: Vector2, rng: int, color: Color = GRID_COLOR) -> void :
	Global.clearNode(show_select_layer)
	show_select_layer.visible = true
	var settings = []
	for i in range(rng + 1):
		var pt = Vector2(center.x + (rng - i), center.y - i)
		settings.append([pt, false, false])
		settings.append([pt, true, true])
		pt = Vector2(center.x - (rng - i), center.y - i)
		settings.append([pt, false, false])
		settings.append([pt, true, false])
		pt = Vector2(center.x + (rng - i), center.y + i)
		settings.append([pt, false, true])
		settings.append([pt, true, true])
		pt = Vector2(center.x - (rng - i), center.y + i)
		settings.append([pt, false, true])
		settings.append([pt, true, false])
	for setting in settings:
		var pos = setting[0]
		var vertical = setting[1]
		var opposite = setting[2]
		if not is_valid_position(pos):
			continue
		var pnl = get_node("sample_grid").duplicate()
		var st = pnl.get_stylebox("panel").duplicate()
		st.vertical = vertical
		st.color = color
		pnl.add_stylebox_override("panel", st)
		pnl.rect_position = pos * block_size
		if opposite:
			if vertical:
				pnl.rect_position += Vector2(38, 0)
			else:
				pnl.rect_position += Vector2(0, 38)
		show_select_layer.add_child(pnl)
	return

var shrink_times = 0;
var shrink_show = false;
var shrink_build_times = - 1;
var shrink_build_show = false;

var cursor_last_move_h = - 1;
var cursor_last_move_v = - 1;
const cursor_move_interval = 80000;


func _process(delta: float) -> void :
	var wf = DataManager.get_current_war_fight()
	if wf == null or wf.status != 1:
		return
	var wv = wf.current_war_vstate()
	if wv == null:
		return

	if is_animating():
		return

	
	
	
	
	
	
	
	
	

	update_war_status(wv, delta)

	var battleLayer = dic_actor_layer["战斗区"]
	var del_shrinks = [];
	for shrinkId in PoolIntArray(_current_shrink_actors):
		if ( not PoolIntArray(next_shrink_actors).has(shrinkId)):
			del_shrinks.append(shrinkId)

	_current_shrink_actors = PoolIntArray(next_shrink_actors);

	for actorId in del_shrinks:
		var waNode = get_actor_rect(actorId)
		if waNode == null:
			continue
		waNode.set_rect_show(true)

	shrink_times += delta * 100
	if shrink_times > 40:
		shrink_times = 0
		shrink_show = not shrink_show
		if not shrink_show:
			shrink_build_times += 1
		for actorId in _current_shrink_actors:
			var waNode = get_actor_rect(actorId)
			if waNode == null:
				continue
			waNode.set_rect_show(shrink_show)
			battleLayer.move_child(waNode, battleLayer.get_child_count() - 1)

	if shrink_build_times >= 1:
		shrink_build_times = - 1
		shrink_build_show = not shrink_build_show
		for bulid_rect in build_layer.get_children():
			var build_x = int(bulid_rect.rect_position.x / block_size)
			var build_y = int(bulid_rect.rect_position.y / block_size)
			var build_position = Vector2(build_x, build_y)
			bulid_rect.visible = true
			
			for wa in wf.get_war_actors(false, true):
				if wa.position == build_position:
					bulid_rect.visible = shrink_build_show
					break

	_can_choose_actors.sort()
	can_choose_actors.sort()
	if str(_can_choose_actors) != str(can_choose_actors):
		show_can_choose_actors(can_choose_actors, observerId, disabledTargets);

	clear_area_trapped()
	for wa in wf.get_war_actors(false, false):
		
		var rect = get_actor_rect(wa.actorId)
		if rect != null:
			rect.update_buff()

		
		
		for k in wa.dic_areas:
			var area = wa.dic_areas[k]
			if not area.has("影响坐标") or not area.has("BUFF"):
				continue
			var buff = StaticManager.get_buff(str(area["BUFF"]))
			if buff == null:
				continue
			var pos = Vector2(int(area["影响坐标"]["x"]), int(area["影响坐标"]["y"]))
			if area["回合数"] <= 0:
				mark_area_trapped(false, pos, buff.get_area_radius())
			else:
				mark_area_trapped(true, pos, buff.get_area_radius())

		
		var waterLocks = wf.get_env_array("WATER_LOCKS")
		for lock in waterLocks:
			if "x" in lock and "y" in lock:
				var pos = Vector2(int(lock["x"]), int(lock["y"]))
				mark_area_trapped(true, pos, 0)
	return

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

func cursor_move_up():
	if not cursor_move_check(true):
		return
	cursor_position.y -= 1;
	if cursor_position.y < 0:
		cursor_position.y = 0
	rpc_set_cursor_location(cursor_position, true);
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_set_cursor_location", cursor_position, true);
	return

func cursor_move_down():
	if not cursor_move_check(true):
		return
	cursor_position.y += 1
	if cursor_position.y > cell_rows - 2:
		cursor_position.y = cell_rows - 2
	rpc_set_cursor_location(cursor_position, true);
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_set_cursor_location", cursor_position, true);
	return

func cursor_move_left():
	if not cursor_move_check():
		return
	cursor_position.x -= 1
	if cursor_position.x < 0:
		cursor_position.x = 0
	rpc_set_cursor_location(cursor_position, true);
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_set_cursor_location", cursor_position, true);
	return
	
func cursor_move_right():
	if not cursor_move_check():
		return
	cursor_position.x += 1
	if cursor_position.x > cell_columns - 1:
		cursor_position.x = cell_columns - 1
	rpc_set_cursor_location(cursor_position, true);
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_set_cursor_location", cursor_position, true);
	return

func fix_cursor_camer():
	while (cursor_position.y - camer_position.y <= 2 and camer_position.y > 0):
		update_camer_position_at_once(camer_position + Vector2.UP)
	while (cursor_position.y - camer_position.y >= 8 and camer_position.y < 9):
		update_camer_position_at_once(camer_position + Vector2.DOWN)
	while (cursor_position.x - camer_position.x <= 2 and camer_position.x > 0):
		update_camer_position_at_once(camer_position + Vector2.LEFT)
	while (cursor_position.x - camer_position.x >= 12 and camer_position.x < 17):
		update_camer_position_at_once(camer_position + Vector2.RIGHT)
	return


func update_cursor_position():
	var target_vect = cursor_position * block_size;
	if (target_vect == cursor.rect_position):
		return ;
	var camer = false;
	set_process(false);
	var temp = target_vect - cursor.rect_position
	var distance = abs(temp.x) + abs(temp.y)
	var total_time = 0.12;
	tweenMap.interpolate_property(cursor, "rect_position", cursor.rect_position, target_vect, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT_IN)
	tweenMap.start()
	return


func update_cursor_position_at_once():
	if (AutoLoad.playerNo != FlowManager.controlNo):
		return ;
	_rpc_update_cursor_position_at_once();
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_update_cursor_position_at_once");

remote func _rpc_update_cursor_position_at_once():
	var target_vect = cursor_position * block_size;
	if (target_vect == cursor.rect_position):
		return ;
	cursor.rect_position = target_vect;
	fix_cursor_camer();
	update_cursor_position_at_once();
	set_save_cursor_position(cursor_position);


func update_camer_position_at_once(new_position):
	if (AutoLoad.playerNo != FlowManager.controlNo):
		return ;
	_rpc_update_camer_position_at_once(new_position);
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_update_camer_position_at_once", new_position);

remote func _rpc_update_camer_position_at_once(new_position):
	if (new_position != null):
		camer_position = new_position;
	fix_camer_position();
	view.rect_position = - camer_position * block_size;
	set_save_carmer_position(camer_position);
	return


func play_camer_position(target_position: Vector2, _camer_next_step: String):
	if (AutoLoad.playerNo != FlowManager.controlNo):
		return ;
	_rpc_play_camer_position(target_position, _camer_next_step);
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_play_camer_position", target_position, _camer_next_step);


remote func _rpc_play_camer_position(targetPosition: Vector2, nextStep: String):
	if nextStep != "":
		var steps = DataManager.get_env_array(CAMER_DONE_STEPS)
		steps.append(nextStep)
		DataManager.set_env(CAMER_DONE_STEPS, steps)
	camer_position = Vector2(int(targetPosition.x), int(targetPosition.y))
	fix_camer_position()
	var target_vect = - camer_position * block_size;
	var temp = target_vect - view.rect_position;
	var distance = abs(temp.x) + abs(temp.y);
	var total_time = camer_times * int(distance / block_size);
	
	Global.clear_signals(tweenMap, ["tween_completed"])
	tweenMap.connect("tween_completed", self, "map_view_move_done", [])
	tweenMap.interpolate_property(
		view, "rect_position", view.rect_position, 
		target_vect, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT_IN, 0.1)
	tweenMap.start()
	return


func fix_camer_position():
	
	if (camer_position.x > 17):
		camer_position.x = 17
	if (camer_position.y > 9):
		camer_position.y = 9
	if (camer_position.x < 0):
		camer_position.x = 0;
	if (camer_position.y < 0):
		camer_position.y = 0;

func _on_Tween_tween_all_completed() -> void :
	set_process(true);
	set_save_carmer_position(camer_position);
	return


func set_map_block(block: String, pos: Vector2) -> void :
	var rectA = create_block_image_tect(block, "A", pos)
	for child in mapA.get_children():
		if child.rect_position == rectA.rect_position:
			mapA.remove_child(child)
			break
	mapA.add_child(rectA)
	var rectB = create_block_image_tect(block, "B", pos)
	for child in mapB.get_children():
		if child.rect_position == rectB.rect_position:
			mapB.remove_child(child)
			break
	mapB.add_child(rectB)
	return


func create_block_image_tect(blockNameEN: String, AB: String, pos: Vector2):
	var idx = 0 if AB == "A" else 1
	var rect = StaticManager.get_war_map_rect(blockNameEN, idx)
	rect.rect_size = Vector2(block_size, block_size)
	rect.name = "{0}_{1}".format([pos.x, pos.y])
	rect.rect_position = pos * block_size
	var blockEN = blockNameEN.split("_")[0]
	var desc = blockEN
	if idx == 0:
		desc = get_blockCN_by_EN(blockEN)
	rect.editor_description = desc
	if not AB in blockInfo:
		blockInfo[AB] = {}
	blockInfo[AB][pos] = desc
	return rect


func camer_to_actorId(actorId: int, next_step: String) -> void :
	var wa = DataManager.get_war_actor(actorId)
	if wa == null or not wa.has_position():
		if next_step != "":
			FlowManager.add_flow(next_step)
		return
	var from_position = cursor_position;
	var target_position = wa.position - Vector2(7, 5)
	play_camer_position(target_position, next_step)
	return

func set_cursor_location(location: Vector2, update_at_once = false):
	if (AutoLoad.playerNo != FlowManager.controlNo):
		return ;
	
	rpc_set_cursor_location(location, update_at_once);
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_set_cursor_location", cursor_position, update_at_once);
	
remote func rpc_set_cursor_location(location: Vector2, update_at_once: bool):
	cursor_position = location;
	set_save_cursor_position(location);
	if (update_at_once):
		update_cursor_position_at_once();
		fix_cursor_camer();


func draw_actors():
	
	var exists_actors = []
	var wf = DataManager.get_current_war_fight()
	for wa in wf.get_war_actors(false, true):
		_create_or_update_actor(wa)
		exists_actors.append(wa.actorId)

	var node: Control = dic_actor_layer["战斗区"];
	for waNode in node.get_children():
		if waNode.actorId in exists_actors:
			continue
		waNode.name += "free"
		node.remove_child(waNode)

	
	var exists_npc = [];
	for i in DataManager.war_neutralors.size():
		var wn: War_Neutralor = DataManager.war_neutralors[i];
		if (wn.disabled):
			continue;
		_create_or_update_npc(wn);
		exists_npc.append(wn.npcId);

	node = dic_actor_layer["NPC区"];
	for war_actor_node in node.get_children():
		if (war_actor_node.npcId in exists_npc):
			continue;
		war_actor_node.name += "free";
		node.remove_child(war_actor_node);
	return

func touch_war_actor_rect(wa: War_Actor):
	var node = _create_or_update_actor(wa)
	node.raise()
	return


func _create_or_update_actor(wa: War_Actor) -> Control:
	var battleLayer: Control = dic_actor_layer["战斗区"]
	var waNode = get_actor_rect(wa.actorId)
	if is_instance_valid(waNode):
		waNode.vstateId = wa.vstate().id
		waNode.update_all()
		return waNode

	var waNodeScene: PackedScene = load("res://windows/children/war_actor_rect.tscn")
	waNode = waNodeScene.instance()
	waNode.name = str(wa.actorId)
	waNode.actorId = wa.actorId
	waNode.vstateId = wa.vstate().id
	battleLayer.add_child(waNode)
	return waNode

func get_actor_rect(actorId: int) -> Control:
	return dic_actor_layer["战斗区"].get_node_or_null(str(actorId))

func _on_soldier_damaged(targetId: int, damage: int) -> void :
	_enqueue_rect_tip(targetId, "兵-" + str(damage), Color.yellow)
	return

func _on_hp_damaged(targetId: int, damage: int) -> void :
	_enqueue_rect_tip(targetId, "体-" + str(damage), Color.yellow)
	return

func _enqueue_rect_tip(actorId: int, text: String, color: Color) -> void :
	var rect = get_actor_rect(actorId)
	if rect == null:
		return
	if not actorId in _rect_tips_queue:
		_rect_tips_queue[actorId] = []
	_rect_tips_queue[actorId].append({"text": text, "color": color})
	if not actorId in _rect_tips_playing:
		_play_next_rect_tip(actorId)
	return


func _create_or_update_npc(wa: War_Neutralor):
	var con_battle: Control = dic_actor_layer["NPC区"];
	var wnpc_node = get_npc_rect(wa.npcId);
	if (is_instance_valid(wnpc_node)):
		wnpc_node.vstateId = wa.vstate().id
		wnpc_node.update_all();
		return ;
	var war_actorR_pack: PackedScene = load("res://windows/children/war_actor_rect.tscn");
	wnpc_node = war_actorR_pack.instance();
	wnpc_node.name = str(wa.npcId);
	wnpc_node.npcId = wa.npcId;
	wnpc_node.vstateId = wa.vstate().id
	con_battle.add_child(wnpc_node);

func get_npc_rect(npcId: int) -> Control:
	var con_battle: Control = dic_actor_layer["NPC区"];
	var wnpc_node = con_battle.get_node_or_null(str(npcId));
	return wnpc_node;


func switch_view_mode(mode: int = - 1) -> void :
	
	if mode == 0:
		show_can_choose_actors([])
		show_actors_name(false)

	if mode >= 0:
		actorViewMode = mode
		return

	actorViewMode = (actorViewMode + 1) % 3
	return


func show_can_choose_actors(actors: PoolIntArray, fromId: int = - 1, _disabledTargets: PoolIntArray = []):
	var wf = DataManager.get_current_war_fight()
	observerId = fromId
	_can_choose_actors = []
	can_choose_actors = []
	can_choose_actors.append_array(actors)
	disabledTargets = []
	disabledTargets.append_array(_disabledTargets)
	show_actors_name(true);
	for wa in wf.get_war_actors(false, true):
		var rect = get_actor_rect(wa.actorId)
		if not is_instance_valid(rect):
			continue
		if wa.actorId in disabledTargets:
			rect.show_can_choose(true, DISABLED_COLOR)
			_can_choose_actors.append(wa.actorId)
			continue
		if wa.actorId in can_choose_actors:
			
			if wa.get_tmp_variable("五行克制", - 2) == fromId:
				rect.show_can_choose(true, FIVE_PHASES_AGAINST_COLOR)
			else:
				rect.show_can_choose(true)
			_can_choose_actors.append(wa.actorId)
			continue
		rect.show_can_choose(false)
	return

func show_actors_name(b: bool):
	var wf = DataManager.get_current_war_fight()
	for wa in wf.get_war_actors(false, true):
		var rect = get_actor_rect(wa.actorId)
		if not is_instance_valid(rect):
			continue
		rect.show_actor_name(b)
	return


func clear_can_choose_actors():
	var wf = DataManager.get_current_war_fight()
	can_choose_actors = [];
	show_actors_name(false);
	for wa in wf.get_war_actors(false, true):
		var rect = get_actor_rect(wa.actorId)
		if not is_instance_valid(rect):
			continue
		rect.show_can_choose(false)
	_can_choose_actors = can_choose_actors
	return


func require_camer_move(wa: War_Actor):
	if wa.get_controlNo() < 0:
		
		var disv = wa.position - cursor_position
		if abs(disv.x) <= 6 and abs(disv.y) <= 4:
			return false
	return true

func show_war_actors_disabled(disabled: bool, wvId: int, exceptActorIds: PoolIntArray = []):
	var wf = DataManager.get_current_war_fight()
	for wa in wf.get_war_actors(false, true):
		if wa.wvId != wvId or wa.actorId in exceptActorIds:
			continue
		var rect = get_actor_rect(wa.actorId)
		if disabled:
			rect.modulate = Color(0.5, 0.5, 0.5, 1.0)
		else:
			rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	return

func is_valid_position(pos: Vector2) -> bool:
	if pos.x < 0 or pos.x >= cell_columns:
		return false
	if pos.y < 0 or pos.y >= cell_rows - 1:
		return false
	return true


func show_scheme_selector(se: StratagemExecution = null, fromWA: War_Actor = null, pos: Vector2 = Vector2.ZERO):
	if se == null:
		show_color_block_by_position([])
		return
	show_color_block_by_position([])
	draw_outline_by_range(pos, 0)
	var positions = se.get_affected_positions(pos)
	if positions.size() > 1:
		show_color_block_by_position(positions, MASK_COLOR)
		return
	if fromWA == null:
		return
	positions = se.stratagem.get_selectable_positions(fromWA)
	if positions.size() <= 1:
		return
	match se.stratagem.get_targeting_cursor_type():
		"十字":
			show_color_block_by_position(positions, SELECTOR_COLOR)
		"仅十字":
			show_color_block_by_position(positions, SELECTOR_COLOR)
		_:
			draw_outline_by_range(fromWA.position, se.stratagem.get_fixed_targeting_range(fromWA), GRID_COLOR, false)
	return


func init_astar():
	aStar = Global.load_script("res://resource/sgz_script/war/AI/War_AI_astar.gd")
	aStar.init_with_war_map(self)
	inner_door_positions = []
	if not "太守府" in builds_position:
		return
	warCityPosition = builds_position["太守府"]
	
	if "城墙" in aStar.idsByBlockCN:
		for id in aStar.idsByBlockCN["城墙"]:
			aStar.set_point_disabled(id, true)
	
	for pos in door_position:
		aStar.set_point_disabled(aStar._get_rect_id(pos), true)
	for pos in door_position:
		
		aStar.set_point_disabled(aStar._get_rect_id(pos), false)
		var route = aStar.get_clear_path(warCityPosition, pos)
		if route.size() > 1:
			inner_door_positions.append(pos)
		
		aStar.set_point_disabled(aStar._get_rect_id(pos), true)
	
	aStar.init_with_war_map(self)
	return


func get_map_data() -> Array:
	var ret = map_data.duplicate(true)
	var extraMapData = DataManager.get_env_dict("战争.临时地图")
	for key in extraMapData:
		var keys = key.split(",")
		if keys.size() != 2:
			continue
		var pos = Vector2(int(keys[0]), int(keys[1]))
		ret[pos.y * cell_columns + pos.x] = extraMapData[key]
	return ret


func set_temp_block(pos: Vector2, block: String, dates: int = 0) -> void :
	var key = "{0},{1}".format([pos.x, pos.y])
	var extraMapData = DataManager.get_env_dict("战争.临时地图")
	if block == "":
		
		block = map_data[pos.y * cell_columns + pos.x]
		extraMapData.erase(key)
	else:
		extraMapData[key] = block
	DataManager.set_env("战争.临时地图", extraMapData)
	if dates > 0:
		var wf = DataManager.get_current_war_fight()
		var extraMapExpire = DataManager.get_env_dict("战争.临时地图.到期")
		extraMapExpire[key] = wf.date + dates
		DataManager.set_env("战争.临时地图.到期", extraMapExpire)
	redraw_position(pos)
	return


func next_date() -> void :
	var wf = DataManager.get_current_war_fight()
	var extraMapExpire = DataManager.get_env_dict("战争.临时地图.到期")
	for key in extraMapExpire.keys():
		if not key in extraMapExpire:
			continue
		if int(extraMapExpire[key]) <= wf.date:
			extraMapExpire.erase(key)
			var keys = key.split(",")
			var pos = Vector2(int(keys[0]), int(keys[1]))
			set_temp_block(pos, "")
	return

func play_war_actor_move(wa: War_Actor, pos: Vector2) -> void :
	if wa == null:
		return
	
	var wr: Control = get_actor_rect(wa.actorId)
	if wr != null:
		wr.set_rect_show(true)

	if Global.get_distance(wa.position, pos) != 1:
		
		wa.position = pos
		return
	var rect = get_actor_rect(wa.actorId)
	if rect == null:
		wa.position = pos
	tweenWA.stop_all()
	var duration = 0.02 * Engine.time_scale
	
	if Engine.time_scale >= 4:
		duration = 0.05 * Engine.time_scale
	elif Engine.time_scale >= 16:
		duration = 0.1 * Engine.time_scale
	tweenWA.interpolate_property(
		rect, "rect_position", 
		rect.rect_position, pos * block_size, 
		duration, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0.1)
	Global.clear_signals(tweenWA, ["tween_completed"])
	tweenWA.connect("tween_completed", self, "war_actor_move_done", [wa, pos])
	tweenWA.start()
	return


func war_actor_move_done(obj, attr, wa: War_Actor, pos: Vector2):
	if wa == null:
		return
	wa.position = pos
	if wa.get_controlNo() < 0:
		FlowManager.add_flow("AI_move_done")
	else:
		FlowManager.add_flow("player_ready")
	return

func get_horse_jump_positions(from: War_Actor, allowEnemy: bool = false) -> PoolVector2Array:
	var candidates = []
	for x in [ - 1, 1]:
		for y in [ - 2, 2]:
			candidates.append(from.position + Vector2(x, y))
			candidates.append(from.position + Vector2(y, x))
	var positions = []
	for pos in candidates:
		if not is_valid_position(pos):
			continue
		var wa = DataManager.get_war_actor_by_position(pos)
		if wa != null:
			if not allowEnemy or not wa.is_enemy(from):
				continue
		var terrian = get_blockCN_by_position(pos)
		if terrian in StaticManager.CITY_BLOCKS_CN:
			continue
		var checkings = []
		if abs(from.position.x - pos.x) == 1:
			
			var midY = int((pos.y + from.position.y) / 2)
			checkings.append(Vector2(pos.x, midY))
			checkings.append(Vector2(from.position.x, midY))
		else:
			
			var midX = int((pos.x + from.position.x) / 2)
			checkings.append(Vector2(midX, pos.y))
			checkings.append(Vector2(midX, from.position.y))
		var valid = false
		for p in checkings:
			var midTerrian = get_blockCN_by_position(p)
			if from.can_move_to_position(p) and not midTerrian == "城墙":
				valid = true
				break
		if not valid:
			continue
		positions.append(pos)
	return positions


func play_move(wa: War_Actor, target: Vector2, updateCamera: bool = true) -> bool:
	if not wa.try_move(target, false, false):
		return false

	play_war_actor_move(wa, target)

	if updateCamera and require_camer_move(wa):
		set_cursor_location(wa.position, true)

	return true


func map_view_move_done(obj, attr):
	var camerDoneSteps = DataManager.get_env_array(CAMER_DONE_STEPS)
	if not camerDoneSteps.empty():
		for step in camerDoneSteps:
			if FlowManager.flow_array.has(step):
				continue
			FlowManager.add_flow(step)
		DataManager.set_env(CAMER_DONE_STEPS, [])
	return

func is_animating() -> bool:
	return tweenMap.is_active() or tweenWA.is_active()



func check_trap_damage(wa: War_Actor) -> Array:
	var ret = [0, 0, null]
	if wa == null or wa.disabled or not wa.has_position():
		return ret
	var trapInfo = wa.check_has_areas_by_labels(["伏兵"])
	if trapInfo.empty():
		return ret
	if not "from_actorId" in trapInfo:
		return ret
	var fromId = Global.intval(trapInfo["from_actorId"])
	var fromWA = DataManager.get_war_actor(fromId)
	if fromWA == null or fromWA.disabled:
		return ret
	ret[2] = fromWA
	var damage = int(Global.get_random(30, 40) * fromWA.actor().get_wisdom() / 10)
	ret[0] = damage
	var actualDamage = min(damage, wa.actor().get_soldiers())
	if actualDamage <= 0:
		return ret
	
	if SkillHelper.actor_has_skills(wa.actorId, ["破伏"]):
		actualDamage = 0
	else:
		actualDamage = DataManager.damage_sodiers(fromWA.actorId, wa.actorId, damage)
	draw_actors()
	ret[1] = actualDamage
	return ret

func check_trap_trigger(wa: War_Actor, nextFlow: String) -> bool:
	if wa == null or wa.disabled or not wa.has_position():
		return false
	var trapInfo = wa.check_has_areas_by_labels(["触发"])
	if not trapInfo.empty():
		if SkillHelper.auto_trigger_skill(wa.actorId, 20042, nextFlow):
			return true

	var wf = DataManager.get_current_war_fight()
	var waterLocks = wf.get_env_array("WATER_LOCKS")
	for lock in waterLocks:
		if "x" in lock and "y" in lock and int(lock["x"]) == wa.position.x and int(lock["y"]) == wa.position.y:
			if SkillHelper.auto_trigger_skill(wa.actorId, 20042, nextFlow):
				return true
	
	return false

func check_facilities(wa: War_Actor) -> String:
	if wa == null or wa.disabled or not wa.has_position():
		return ""
	var facilityName = get_buildCN_by_position(wa.position)

	if facilityName in ["米屋", "装备店", "医馆"]:
		return facilityName
	return ""





const WATER_LOCK_MAX_COUNT = 5

func is_water_locked(pos: Vector2) -> bool:
	var wf = DataManager.get_current_war_fight()
	var waterLocks = wf.get_env_array("WATER_LOCKS")
	for lock in waterLocks:
		if "x" in lock and "y" in lock and int(lock["x"]) == pos.x and int(lock["y"]) == pos.y:
			return true
	return false

func is_water_locked_against(wa: War_Actor) -> bool:
	if wa == null or not wa.has_position():
		return false
	var pos = wa.position
	var wf = DataManager.get_current_war_fight()
	var waterLocks = wf.get_env_array("WATER_LOCKS")
	for lock in waterLocks:
		if "from" in lock and "x" in lock and "y" in lock and int(lock["x"]) == pos.x and int(lock["y"]) == pos.y:
			var from = DataManager.get_war_actor(int(lock["from"]))
			if wa.is_enemy(from):
				return true
	return false

func switch_water_lock(fromId: int, pos: Vector2) -> void :
	var wf = DataManager.get_current_war_fight()
	var waterLocks = wf.get_env_array("WATER_LOCKS")
	for lock in waterLocks:
		if "x" in lock and "y" in lock and int(lock["x"]) == pos.x and int(lock["y"]) == pos.y:
			waterLocks.erase(lock)
			return
	waterLocks.append({"x": pos.x, "y": pos.y, "from": fromId})
	if waterLocks.size() > WATER_LOCK_MAX_COUNT:
		waterLocks.pop_front()
	wf.set_env("WATER_LOCKS", waterLocks)
	return











func endless_specials() -> void :
	var wf = DataManager.get_current_war_fight()
	var hiddenBlocks = wf.get_env_dict("hiddenBlocks")
	if not hiddenBlocks.empty():
		
		return
	
	hiddenBlocks["-1,-1"] = "none"
	if not DataManager.endless_mode:
		wf.set_env("hiddenBlocks", hiddenBlocks)
		return
	
	var plains = []
	for pos in blockInfo["A"]:
		if blockInfo["A"][pos] != "平原":
			continue
		
		if pos in builds_position.values():
			continue
		
		if pos.x < 2 or pos.y < 2:
			continue
		if pos.x > cell_columns - 3 or pos.y > cell_rows - 4:
			continue
		
		var nearCity = false
		var checkings = []
		checkings.append_array(door_position)
		checkings.append(warCityPosition)
		for cp in checkings:
			if min(abs(cp.x - pos.x), abs(cp.y - pos.y)) <= 3:
				nearCity = true
				break
		if nearCity:
			continue
		plains.append(pos)
	if plains.empty():
		wf.set_env("hiddenBlocks", hiddenBlocks)
		return
	plains.shuffle()
	var pos = plains[0]
	hiddenBlocks["{0},{1}".format([pos.x, pos.y])] = "village"
	
	for wv in wf.war_vstates():
		if wv.get_main_controlNo() < 0:
			continue
		if SkillRangeBuff.max_val_for_war_vstate("天象", wv.id) > 0:
			
			set_temp_block(pos, "village_4")
			break
	wf.set_env("hiddenBlocks", hiddenBlocks)
	return


func check_special_events(wa: War_Actor) -> String:
	if not DataManager.is_test_player():
		
		return ""
	if not DataManager.endless_mode:
		
		return ""
	if wa == null\
	or not wa.has_position()\
	or wa.get_controlNo() < 0:
		
		return ""
	var wf = DataManager.get_current_war_fight()
	var hiddenBlocks = wf.get_env_dict("hiddenBlocks")
	var posKey = "{0},{1}".format([wa.position.x, wa.position.y])
	if not posKey in hiddenBlocks:
		return ""
	if hiddenBlocks[posKey] != "village":
		return ""
	
	hiddenBlocks.erase(posKey)
	wf.set_env("hiddenBlocks", hiddenBlocks)
	return "player_enter_village"










var warStatusDelta: int = - 1

func update_war_status(wv: War_Vstate, delta: float) -> void :
	var wf = DataManager.get_current_war_fight()
	warStatus.get_node("days/value").text = str(wf.date)
	warStatus.get_node("endless").visible = DataManager.endless_mode
	warStatus.get_node("endless/value").text = "第{0}关".format([EndlessGame.pass_no + 1])

	if warStatusDelta < 0:
		warStatusDelta = int(delta * 1000)
	else:
		warStatusDelta += int(delta * 1000)
	var duration = int(500 * Engine.time_scale)
	if warStatus.visible:
		duration = int(500 * Engine.time_scale)
	if warStatusDelta > duration:
		warStatusDelta = - 1
		if not warStatus.visible:
			var title = warStatus.get_node("money_rice/title").text
			if title == "米":
				warStatus.get_node("money_rice/title").text = "金"
				warStatus.get_node("money_rice/value").text = str(wv.money)
			else:
				warStatus.get_node("money_rice/title").text = "米"
				warStatus.get_node("money_rice/value").text = str(wv.rice)
		warStatus.visible = not warStatus.visible
		update_ap()

	return

func update_ap(actorId: int = - 1):
	var wf = DataManager.get_current_war_fight()
	if wf.auto_play_mode():
		warStatus.get_node("AP/title").text = "托管中"
		warStatus.get_node("AP/value").text = ""
		return
	if actorId < 0:
		actorId = apActorId
	if actorId < 0:
		actorId = DataManager.player_choose_actor
	if actorId < 0:
		return
	apActorId = actorId
	var ap = 0
	var wa = DataManager.get_war_actor(actorId)
	if wa != null:
		ap = wa.action_point
	_rpc_show_ap(ap)
	if AutoLoad.check_is_multigame():
		rpc("_rpc_show_ap", ap)
	return

remote func _rpc_show_ap(ap: int):
	warStatus.get_node("AP/title").text = "機"
	warStatus.get_node("AP/value").text = str(ap)
	return





func _play_next_rect_tip(actorId: int) -> void :
	if not actorId in _rect_tips_queue or _rect_tips_queue[actorId].empty():
		_rect_tips_queue.erase(actorId)
		_rect_tips_playing.erase(actorId)
		return
	_rect_tips_playing[actorId] = true
	var tip = _rect_tips_queue[actorId].pop_front()
	var rect = get_actor_rect(actorId)
	if rect == null:
		_rect_tips_queue.erase(actorId)
		_rect_tips_playing.erase(actorId)
		return
	show_rect_tips(rect, tip["text"], tip["color"], actorId)
	return

func show_rect_tips(rect: Control, text: String, color: Color = Color.red, actorId: int = - 1) -> void :
	var font = load("res://resource/font/FandolSong-Bold/25_outline.tres")
	var lbl = Label.new()
	lbl.text = text
	lbl.add_color_override("font_color", color)
	lbl.add_font_override("font", font)
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.3)
	bg.content_margin_left = 2
	bg.content_margin_right = 2
	lbl.add_stylebox_override("normal", bg)
	lbl.rect_scale = Vector2(0.8, 0.8)
	lbl.rect_position = rect.rect_position
	lbl.rect_position.x += 0
	lbl.align = Label.ALIGN_CENTER
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.rect_min_size = Vector2(60, 0)
	view.add_child(lbl)
	var tween = get_tree().create_tween()
	var duration = 0.5 * Engine.time_scale
	tween.tween_property(lbl, "rect_position:y", rect.rect_position.y - 32, duration).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, duration).set_delay(duration * 0.5)
	tween.tween_callback(lbl, "queue_free")
	if actorId >= 0:
		tween.tween_callback(self, "_play_next_rect_tip", [actorId])
	return
