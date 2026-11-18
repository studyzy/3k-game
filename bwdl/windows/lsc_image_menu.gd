extends Control

onready var conActor = get_node("bottom_scene/conActor");
onready var nprFace = get_node("bottom_scene/conActor/nprFace");
onready var lblName = get_node("bottom_scene/conActor/lblName");
onready var rtlMessage = get_node("rtlMessage");
onready var conOrderbook = get_node("conOrderbook");
onready var container = get_node("CenterContainer");
onready var cursor = get_node("CenterContainer/container/curosr");


export (int) var cursor_index = 0;

export (Array) var items = ["选项1"];

export (Vector2) var cursor_offset = Vector2(0, - 50);


var mood: int = 2;
var mouth: bool = false;
var face_animation = false;
var _actorId = - 1;


func _ready() -> void :
	return

func show_msg(text: String, actorId: int = - 1):
	rtlMessage.text = text;
	rtlMessage.percent_visible = 0;
	_actorId = actorId;
	var total_time = text.length() * SceneManager.word_unittime;
	
	_actorId = actorId;
	if (actorId != - 1):
		mouth = false;
		conActor.visible = true;
		nprFace.set_actor(actorId);
		lblName.text = ActorHelper.actor(actorId).get_name()
	else:
		conActor.visible = false;
	face_animation = true;
	$Tween.interpolate_property(rtlMessage, "percent_visible", 0, 1, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT);
	$Tween.start();

func show_orderbook(b: bool):
	conOrderbook.update_orderbook();
	conOrderbook.visible = b;


func set_lsc(separation: int = 90):
	container.get_node("container").set("custom_constants/separation", separation);
	return


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

func _set_data(scale: float = 1.5):
	cursor_index = 0;
	var gv: HBoxContainer = container.get_node("container");
	var copy_cursor = cursor.duplicate();
	Global.clearNode(gv);
	for item in items:
		var control = Control.new();
		var sp = Sprite.new()
		sp.position = Vector2(0, 0)
		sp.scale = Vector2(scale, scale)
		if typeof(item) == TYPE_ARRAY:
			sp.texture = create_formation_texture(item[0], item[1], item[2])
		else:
			sp.texture = Global.load_pic(item)
		control.add_child(sp)
		gv.add_child(control);
	gv.add_child(copy_cursor);
	self.cursor = copy_cursor;
	DataManager.recover_lsc_index(self)
	return


func UpdateCursor():
	var gv: HBoxContainer = container.get_node("container");
	cursor.position.y = cursor_offset.y;
	cursor.position.x = cursor_offset.x + cursor_index * gv.get("custom_constants/separation");
	return

func move_left():
	var columns = items.size();
	var y = cursor_index / columns;
	var x = cursor_index % columns;
	x -= 1;
	if (x < 0):
		x = columns - 1;
	cursor_index = y * columns + x;
	while (cursor_index >= columns):
		x -= 1;
		cursor_index = y * columns + x;
	if (AutoLoad.other_players.size() > 0):
		rpc("set_cursor", cursor_index);

func move_right():
	var columns = items.size();
	var y = cursor_index / columns;
	var x = cursor_index % columns;
	x += 1;
	if (x >= columns):
		x = 0;
	var newindex = y * columns + x;
	if (newindex >= columns):
		x = 0;
	cursor_index = y * columns + x;
	if (AutoLoad.other_players.size() > 0):
		rpc("set_cursor", cursor_index);

func move_down():
	return

func move_up():
	return

remote func set_cursor(index: int):
	cursor_index = index;
	return

var _process_d = 0
func _process(delta: float) -> void :
	UpdateCursor();
	
	if (_actorId >= 0):
		_process_d += 1 * delta;
		if (_process_d >= 0.15):
			_process_d = 0;
			mouth = not mouth;
			if (mouth):
				if ( not face_animation):
					_actorId = - 1;
					return ;
			nprFace.mouth = mouth;
	return

func _on_Tween_tween_all_completed() -> void :
	face_animation = false;
	nprFace.mouth = false;
	return

func create_formation_texture(formation: int, inverted: bool, units: int) -> ImageTexture:
	var formationSetting = StaticManager.get_formation_setting(formation)
	var width = 108
	var height = 96
	var offset = 12
	var borderWidth = 3
	if formation == 4:
		width = 168
	var img = Image.new()
	img.create(width, height, false, Image.FORMAT_RGBA8)
	img.lock()
	
	img.fill("#FFFCBCB0")
	img.lock()
	for x in width:
		for y in borderWidth:
			img.set_pixel(x, y, Color.black)
			img.set_pixel(x, height - y - 1, Color.black)
	for y in height:
		for x in borderWidth:
			img.set_pixel(x, y, Color.black)
			img.set_pixel(width - x - 1, y, Color.black)
	var unitsCount = formationSetting["positions"].size()
	if "units" in formationSetting:
		unitsCount = min(unitsCount, Global.intval(formationSetting["units"]))
	for i in unitsCount:
		var color = Color.black if i > 0 else Color.red
		if i * 2 > units:
			color = Color("#FFCCCC")
			if i * 2 - 1 == units:
				color = Color("#666666")
		var pos = Vector2(formationSetting["positions"][i][0], formationSetting["positions"][i][1])
		for x in range(pos.x * 16 - 7, pos.x * 16 + 4):
			for y in range(pos.y * 10 - 5, pos.y * 10 + 2):
				var px = width - 1 - x - offset if inverted else x + offset
				if px < 0:
					continue
				img.set_pixel(px, y, color)
	img.unlock()
	var ret = ImageTexture.new()
	ret.create_from_image(img)
	return ret
