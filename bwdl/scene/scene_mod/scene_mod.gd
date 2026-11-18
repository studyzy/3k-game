extends Control

const SCENE_ID = 0

onready var lsc = get_node("lsc");
onready var richTextLabel = get_node("bottom/RichTextLabel");

var mod_name_array = [];
var mod_name_path = {};
var model_view = 0;


func _ready() -> void :
	model_view = 0;
	
	SceneManager.load_scene_complete = true;
	FlowManager.clear_bind_method();
	FlowManager.bind_signal_method("confirm", self, "confirm");
	
	mod_name_array.clear();
	mod_name_path.clear();
	lsc.items = [];
	var player_machine_name = OS.get_name();
	add_mod("原版", DataManager.DEFAULT_MOD_PATH);
	
	var dirs = [];
	var d: Directory = Directory.new();
	var common_mod_path = "";
	if (player_machine_name == "Android"):
		common_mod_path = OS.get_system_dir(0) + "/sgz/mod";
		richTextLabel.text = common_mod_path;
		if (d.dir_exists(common_mod_path)):
			richTextLabel.text += "\n存在！"
			dirs.append(common_mod_path);
		else:
			
			d.make_dir_recursive(common_mod_path);
	else:
		common_mod_path = OS.get_executable_path();
		var index = common_mod_path.find_last("/");
		common_mod_path = common_mod_path.substr(0, index);
		common_mod_path += "/sgz/mod";
		if (d.dir_exists(common_mod_path)):
			dirs.append(common_mod_path);
		else:
			d.make_dir_recursive(common_mod_path);
		
	get_node("Label").text = "如要添加改版,请将改版的文件夹放入【{0}/】文件夹下,之后重新启动游戏".format([common_mod_path]);

	for dir in dirs:
		var mods_dirs: Array = Global.scan_all_directory(dir);
		for mod_dir in mods_dirs:
			if mod_dir in ["mod_example", "avatars", "battle_character"]:
				continue;
			var total_path = dir + "/" + mod_dir + "/";
			var json = StaticManager.get_mod_info(total_path)
			if (json == ""):
				richTextLabel.text += "\n读不到文件:" + total_path + "mod.json";
				continue;
			var mod = parse_json(json);
			add_mod(str(mod["名称"]), total_path);
	lsc._set_data();
	_show_mod_info();
	
	if (lsc.items.size() == 1):
		confirm();
	pass

func add_mod(mod_name: String, res_path: String):
	if (mod_name in mod_name_array):
		return ;
	mod_name_array.append(mod_name);
	mod_name_path[mod_name] = res_path;
	lsc.items.append(mod_name);
	

func _process(delta: float) -> void :
	if (model_view == 0):
		
		if (Input.is_action_just_pressed("ANALOG_DOWN")):
			lsc.move_down();
			_show_mod_info();
		if (Input.is_action_just_pressed("ANALOG_UP")):
			lsc.move_up();
			_show_mod_info();
		if (Input.is_action_just_pressed("ANALOG_LEFT")):
			lsc.move_left();
			_show_mod_info();
		if (Input.is_action_just_pressed("ANALOG_RIGHT")):
			lsc.move_right();
			_show_mod_info();
		if (Input.is_action_just_pressed("EMU_START")):
			FlowManager.add_flow("confirm");
		if (Input.is_action_just_pressed("EMU_SELECT")):
			pass
	return

func confirm():
	model_view = 1;
	var mod_name = mod_name_array[lsc.cursor_index];
	var path = mod_name_path[mod_name];
	DataManager.loading_version_resource(path);
	FlowManager.add_flow("go_to_scene|res://scene/scene_drama/scene_drama.tscn");
	
	return


func _show_mod_info():
	var mod_name = mod_name_array[lsc.cursor_index];
	var maker = "";
	var description = "";
	var path = mod_name_path[mod_name];
	var mod = StaticManager.get_mod_info(path)
	
	maker = str(mod["作者"]);
	description = str(mod["描述"]);
	
	richTextLabel.text = "【作者】" + maker + "\n【描述】" + description;
	pass

func _on_FileDialog_file_selected(path: String) -> void :
	var dir = path.replace("mod.json", "");
	var mod = parse_json(Global.get_file_text(path));
	if (mod["名称"] in mod_name_array):
		return ;
	add_mod(str(mod["名称"]), dir);
	lsc._set_data();
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.6, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(192, 0)
	rect_scale = Vector2(1, 1)
	return
