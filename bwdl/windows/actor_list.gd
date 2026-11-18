tool
extends ColorRect

export (Array) var actorId_list = [];
onready var container: Control = get_node("Control/container");
onready var vbox = get_node("Control/container/VBoxContainer");
onready var cursor = get_node("Control/container/cursor");
onready var rtlMessage = get_node("rtlMessage");
onready var lbltypes = get_node("title/types");

var class_actor_row = preload("res://windows/children/actor_row.tscn");

export (bool) var change_sodiers = false;
export (int) var cursor_index = 0;

export var need_end_button: bool = false;
export var speak_text: String = "";
export var actor_properties = [];
export var sort_index = - 1;
var initial_actorIds = [];


var rows: int = 0

const DEFAULT_ACTOR_PROPERTIES = ["体", "武", "知", "忠", "德", "经验"]
const HEADER_DICT: Dictionary = {
	"等级": "级"
}

func _ready() -> void :

	return

func _process(delta: float) -> void :
	if not visible:
		return
	if not Engine.editor_hint:
		UpdateCursor()
	return

func set_actors(new_actorId_list: Array, need_end_button: bool, text: String, 
	_change_sodiers: bool = false, actor_properties: PoolStringArray = [], justSorting: bool = false):
	
	
	var statuses = {"出仕": 1}
	for actorId in new_actorId_list:
		if statuses.size() >= 2:
			break
		if ActorHelper.actor(actorId).is_status_officed():
			statuses["出仕"] = 1
			continue
		if ActorHelper.actor(actorId).is_status_captured():
			statuses["监狱"] = 1
			continue
	var mixed = statuses.size() >= 2
	self.need_end_button = need_end_button
	self.speak_text = text
	self.change_sodiers = _change_sodiers
	self.actor_properties = actor_properties
	if actor_properties.size() != 6:
		actor_properties = DEFAULT_ACTOR_PROPERTIES
	if not justSorting:
		self.initial_actorIds = new_actorId_list.duplicate()
		self.sort_index = - 1
		self.rows = self.initial_actorIds.size()
		if need_end_button:
			self.rows += 1
		for hdr in get_node("title").get_children():
			if hdr.name == "types":
				continue
			hdr.set("custom_colors/font_color", Color(0, 0, 0))
	get_node("conBackupSodiers").visible = _change_sodiers;
	lbltypes.text = "";
	cursor_index = 0;
	actorId_list = new_actorId_list.duplicate();
	for i in actor_properties.size():
		var hdr = actor_properties[i]
		if HEADER_DICT.has(hdr):
			hdr = HEADER_DICT[hdr]
		get_node("title/hdr{0}".format([i + 1])).text = hdr
	var alreadyPicked = []
	if justSorting:
		
		alreadyPicked = get_picked_actors()
	Global.clearNode(vbox);
	for actorId in actorId_list:
		var node = class_actor_row.instance();
		node.mixed = mixed
		node.name = str(actorId);
		node.actorId = int(actorId);
		node.actorProperties = actor_properties;
		node.highlighted = node.actorId == highlighted
		vbox.add_child(node)
		if node.actorId in alreadyPicked:
			node.set_picked(true)
		
	if (need_end_button):
		var end_node = class_actor_row.instance();
		end_node.name = str( - 1);
		end_node.actorId = - 1;
		end_node.actorProperties = actor_properties;
		vbox.add_child(end_node);
		actorId_list.append( - 1);
	if _change_sodiers:
		rtlMessage.rect_size.x = 404
	else:
		rtlMessage.rect_size.x = 624
	speak(text);
	get_node("has_nextpage").visible = actorId_list.size() > 11;
	if actor_properties[5] in ["武器", "防具", "道具", "坐骑"]:
		get_node("title/hdr6").rect_position.x = 437
	elif actor_properties[5] == "兵力":
		get_node("title/hdr6").rect_position.x = 511
		update_sodiers();
	elif actor_properties[5] == "经验":
		get_node("title/hdr6").rect_position.x = 507
	else:
		get_node("title/hdr6").rect_position.x = 501
	return

func speak(text: String, instant: bool = false):
	_rpc_speak(text, instant);
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_speak", text, instant);
	
remote func _rpc_speak(text: String, instant: bool = false):
	rtlMessage.text = text;
	if instant:
		rtlMessage.percent_visible = 100
		return
	rtlMessage.percent_visible = 0;
	var total_time = rtlMessage.text.length() * SceneManager.word_unittime;
	$Tween.interpolate_property(rtlMessage, "percent_visible", 0, 1, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT);
	$Tween.start();

func move_to(idx: int):
	if idx < 0:
		idx = rows - 1
	if idx > rows:
		idx = rows - 1
	cursor_index = idx
	if AutoLoad.check_is_multigame():
		rpc("_rpc_set_cursor_index", cursor_index)
	return

func move_up(delta: int = 1):
	var y = cursor_index;
	var x = 0;
	y -= delta;
	if (y < 0):
		if cursor_index == 0 and delta == 1:
			
			y = rows - 1;
		else:
			y = 0;
	self.move_to(y + x)

func move_down(delta: int = 1):
	var y = cursor_index;
	var x = 0;
	y += delta;
	var newindex = y + x;
	if (newindex >= rows):
		if cursor_index == rows - 1 and delta == 1:
			
			y = 0;
		else:
			y = rows - 1;
	self.move_to(y + x)


func page_up():
	move_to(max(0, cursor_index - 10))
	return


func page_down():
	move_to(min(rows - 1, cursor_index + 10))
	return

remote func _rpc_set_cursor_index(index: int):
	cursor_index = index
	return


func UpdateCursor():
	if vbox.get_child_count() == 0:
		return
	
	var scroll_speed = int(vbox.get("custom_constants/separation"));
	
	var show_min_y = - container.rect_position.y;
	var show_max_y = show_min_y + container.rect_size.y;
	
	cursor.rect_position.x = 28;
	cursor.rect_position.y = 19 + cursor_index * vbox.get("custom_constants/separation");
	
	while show_min_y > cursor.rect_position.y:
		container.rect_position.y += scroll_speed
		show_min_y = - (container.rect_position.y)
		show_max_y = show_min_y + container.rect_size.y
	
	while show_max_y < cursor.rect_position.y:
		container.rect_position.y -= scroll_speed
		show_min_y = - container.rect_position.y
		show_max_y = show_min_y + container.rect_size.y

	lbltypes.text = ""
	var actorId = get_select_actor()
	if actorId >= 0:
		var actor = ActorHelper.actor(actorId)
		lbltypes.text = actor.get_nick()
	return

func update_sodiers():
	for actorId in actorId_list:
		var actor = ActorHelper.actor(actorId)
		_rpc_update_actor_sodiers_show(actorId, actor.get_soldiers())
		if (AutoLoad.check_is_multigame()):
			rpc("_rpc_update_actor_sodiers_show", actorId, actor.get_soldiers())
	var city = clCity.city(DataManager.player_choose_city)
	_rpc_update_backsodiers(city.get_backup_soldiers())
	if AutoLoad.check_is_multigame():
		rpc("_rpc_update_backsodiers", city.get_backup_soldiers())
	return

func _rpc_update_backsodiers(back_sodiers: int):
	get_node("conBackupSodiers/lblBackupSodiers").text = str(back_sodiers);

remote func _rpc_update_actor_sodiers_show(actorId: int, sodiers: int):
	var node = vbox.get_node(str(actorId));
	node.set_sodiers(sodiers);

func get_select_actor() -> int:
	if cursor_index < 0 or cursor_index >= actorId_list.size():
		return - 1
	return int(actorId_list[cursor_index])


func set_actor_picked(actorId: int, max_picked = 10):
	_rpc_set_actor_picked(actorId, max_picked);
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_set_actor_picked", actorId, max_picked);

remote func _rpc_set_actor_picked(actorId: int, max_picked: int):
	var node = vbox.get_node_or_null(str(actorId));
	if (node != null):
		var is_picked = node.is_picked;
		if ( not is_picked):
			if (get_picked_actors().size() >= max_picked):
				return ;
		node.set_picked( not is_picked);

func is_actor_picked(actorId: int) -> bool:
	var node = vbox.get_node_or_null(str(actorId));
	return node != null and node.is_picked


func get_picked_actors() -> Array:
	var actors = [];
	for node in vbox.get_children():
		if (node.is_picked and node.actorId != - 1):
			actors.append(int(node.name));
	return actors;


func show_all_msg() -> void :
	_rpc_show_all_msg();
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_show_all_msg");

remote func _rpc_show_all_msg():
	var tween: Tween = get_node("Tween");
	if (tween.is_active()):
		tween.seek(tween.get_runtime());


func is_msg_complete():
	var tween: Tween = get_node("Tween");
	if (tween.is_active()):
		return false;
	return true;

func get_per_sodiers_number() -> int:
	return 100;


func increase_sodiers():
	var actorId = get_select_actor();
	if actorId < 0:
		return
	var city = clCity.city(DataManager.player_choose_city)
	
	var number: int = get_per_sodiers_number()
	number = min(number, city.get_backup_soldiers())
	var actor = ActorHelper.actor(actorId)
	
	number = min(number, DataManager.get_actor_max_soldiers(actorId) - actor.get_soldiers())
	actor.set_soldiers(actor.get_soldiers() + number)
	
	city.add_city_property("后备兵", - number)
	update_sodiers()
	return


func decrease_sodiers():
	var actorId = get_select_actor()
	if actorId < 0:
		return
	var city = clCity.city(DataManager.player_choose_city)
	var actor = ActorHelper.actor(actorId)
	
	var number: int = get_per_sodiers_number()
	var least = actor.get_soldiers() - int(actor.get_soldiers() / 100) * 100
	if least > 0:
		number = least
	number = min(number, actor.get_soldiers())
	actor.set_soldiers(actor.get_soldiers() - number)
	city.add_city_property("后备兵", number)
	update_sodiers()
	return


func increase_to_full_sodiers():
	var actorId = get_select_actor()
	if actorId < 0:
		return
	var city = clCity.city(DataManager.player_choose_city)
	var actor = ActorHelper.actor(actorId)
	var max_sodiers = DataManager.get_actor_max_soldiers(actorId)
	var number = min(max_sodiers - actor.get_soldiers(), city.get_backup_soldiers())
	actor.set_soldiers(actor.get_soldiers() + number)
	city.add_city_property("后备兵", - number)
	update_sodiers()
	return


func decrease_to_zero_sodiers():
	var actorId = get_select_actor()
	if actorId < 0:
		return
	var city = clCity.city(DataManager.player_choose_city)
	var actor = ActorHelper.actor(actorId)
	var number = actor.get_soldiers()
	actor.set_soldiers(0)
	city.add_city_property("后备兵", number)
	update_sodiers()
	return


func full_all_sodiers():
	var city = clCity.city(DataManager.player_choose_city)
	for actorId in actorId_list:
		if actorId < 0:
			continue
		var actor = ActorHelper.actor(actorId)
		var max_sodiers = DataManager.get_actor_max_soldiers(actorId)
		var number = min(max_sodiers - actor.get_soldiers(), city.get_backup_soldiers())
		actor.set_soldiers(actor.get_soldiers() + number)
		city.add_city_property("后备兵", - number)
		if city.get_backup_soldiers() <= 0:
			break
	update_sodiers()
	return


func clear_all_sodiers():
	var city = clCity.city(DataManager.player_choose_city)
	for actorId in actorId_list:
		if actorId < 0:
			continue
		var actor = ActorHelper.actor(actorId)
		var number = actor.get_soldiers()
		actor.set_soldiers(0)
		city.add_city_property("后备兵", number)
	update_sodiers()
	return

func sort_toggle():
	var sorted = actorId_list.duplicate()
	sorted.erase( - 1)
	sort_index += 1
	if sort_index >= 6:
		sort_index = - 1
	else:
		var prop = actor_properties[sort_index]
		while prop == "":
			sort_index += 1
			if sort_index >= 6:
				sort_index = - 1
				break
			else:
				prop = actor_properties[sort_index]
	for i in range(1, 7):
		get_node("title/hdr{0}".format([i])).set("custom_colors/font_color", Color(0, 0, 0))
	if sort_index == - 1:
		sorted = self.initial_actorIds.duplicate()
	else:
		get_node("title/hdr{0}".format([sort_index + 1])).set("custom_colors/font_color", Color(0, 0, 0.88))
		sorted.sort_custom(self, "sort_actors")
	set_actors(sorted, need_end_button, speak_text, change_sodiers, actor_properties, true)
	return

func sort_actors(a, b):
	if a == - 1:
		return true
	if b == - 1:
		return false
	if sort_index < 0 or sort_index >= actor_properties.size():
		return false
	var prop = actor_properties[sort_index]
	if prop == "":
		return false
	var aa = ActorHelper.actor(a)
	var ab = ActorHelper.actor(b)
	if prop == "经验":
		return ab.get_exp() < aa.get_exp()
	return ab._get_attr_int(prop) < aa._get_attr_int(prop)

func clear_picked_actors():
	for node in vbox.get_children():
		node.is_picked = false
	return

func get_actor_ids() -> PoolIntArray:
	return initial_actorIds.duplicate()



func update_actor_list(actorIds: PoolIntArray, picked: PoolIntArray, msg: String = "") -> void :
	set_process(false)
	var lastCursor = cursor_index
	set_actors(actorIds, true, msg, false, actor_properties, true)
	cursor_index = lastCursor
	clear_picked_actors()
	for actorId in picked:
		set_actor_picked(actorId)
	set_process(true)
	return



export var highlighted: int = - 1

func get_highlighted() -> int:
	return highlighted

func set_highlight(targetId: int) -> void :
	highlighted = targetId
	if highlighted < 0:
		return
	for node in vbox.get_children():
		if node.actorId == highlighted:
			node.set_highlighted(true)
		elif node.is_highlighted():
			node.set_highlighted(false)
	return

func update_message(msg: String) -> void :
	rtlMessage.text = msg
	speak_text = msg
	return
