# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/global.gd
# 说明：全局工具函数（自动加载）。日志、脚本加载、场景/速度控制等通用能力。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

tool
extends Node

const gd_code = "gdpwd";

var SCRIPT_CACHE = {}

class DateTime:
	var year: int;
	var month: int;
	var day: int;
	var hour: int;
	var minute: int;
	var second: float;
	func to_str(format: = "{0}-{1}-{2} {3}:{4}:{5}"):
		var str_year = str(year);
		if str_year.length() == 1:
			str_year = "0" + str_year;
			
		var str_month = str(month);
		if str_month.length() == 1:
			str_month = "0" + str_month;
		
		var str_day = str(day);
		if str_day.length() == 1:
			str_day = "0" + str_day;
			
		var str_hour = str(hour);
		if str_hour.length() == 1:
			str_hour = "0" + str_hour;
		
		var str_minute = str(minute);
		if str_minute.length() == 1:
			str_minute = "0" + str_minute;
		
		var str_second = str(second);
		if str_second.length() == 1:
			str_second = "0" + str_second;
		
		return format.format([str_year, str_month, str_day, str_hour, str_minute, str_second]);

class VectorSorter extends Reference:
	var direction: Vector2
	var center: Vector2

	func by_direction(a: Vector2, b: Vector2) -> bool:
		var target = center + direction * 5
		return a.distance_squared_to(target) < b.distance_squared_to(target)

	func by_distance(a: Vector2, b: Vector2) -> bool:
		var aa = a - center
		var bb = b - center
		return abs(aa.x) + abs(aa.y) < abs(bb.x) + abs(bb.y)

class DistanceComparator extends Reference:
	var from: Vector2

	func _init(_from: Vector2):
		from = _from
		return

	func _sort_custom(wa, wb):
		return Global.get_distance(wa.position, from) - Global.get_distance(wb.position, from)





class ActorComparator extends Reference:

	func by_actor_power(a, b) -> bool:
		if typeof(a) == TYPE_INT:
			a = ActorHelper.actor(a)
		if typeof(b) == TYPE_INT:
			b = ActorHelper.actor(b)
		return a.get_power() > b.get_power()

	func by_power(a, b) -> bool:
		if typeof(a) == TYPE_INT:
			a = ActorHelper.actor(a)
		if typeof(b) == TYPE_INT:
			b = ActorHelper.actor(b)
		var score = a.get_power_score() - b.get_power_score()
		return score > 0

	func by_soldiers(a, b) -> bool:
		if typeof(a) == TYPE_INT:
			a = ActorHelper.actor(a)
		if typeof(b) == TYPE_INT:
			b = ActorHelper.actor(b)
		return a.get_soldiers() > b.get_soldiers()

var actorComp = ActorComparator.new()

func _ready() -> void :
	reset()


func reset():
	clearNode(self);
	
	var my_seed = "bwddl-GD" + Global.get_datetime_now().to_str();
	seed(my_seed.hash())




func clearNode(node: Node, excepts: PoolStringArray = []):
	var array = [];
	if ( not is_instance_valid(node)):
		return ;
	for child in node.get_children():
		if child.name in excepts:
			continue
		array.append(child);
		
	for child in array:
		if (is_instance_valid(child)):
			child.name = "temp_delete_node_" + child.name;
			child.queue_free();
	return




func get_file_length(path: String) -> int:
	var f = File.new()
	if f.open(path, File.READ) == OK:
		return f.get_len()
	return - 1


func get_file_text(path: String) -> String:
	var f = File.new()
	if not f.file_exists(path):
		return ""
	f.open(path, File.READ)
	var text = f.get_as_text()
	f.close()
	if DataManager != null:
		DataManager.game_trace("GET_FILE: " + path, false, true)
	return text


func save_file_text(path: String, data: String) -> bool:
	print("SAVE_FILE: " + path)
	var file = File.new()
	var error = file.open(path, File.WRITE)
	if error != OK:
		print_debug("Error(code {0}) opening {1}".format([error, path]))
		return false
	
	file.store_line(data)
	file.close()
	return true

var PICTURE_CACHE = {}

func load_pic_with_cache(path: String):
	if not DataManager.is_developer():
		path = path.replace("res://resource/images/", "res://packed/images/")
	if path in PICTURE_CACHE:
		return PICTURE_CACHE[path]
	if not Global.file_exists(path):
		return null
	DataManager.grouped_trace("")
	var loaded = load_pic(path)
	DataManager.grouped_trace("IMG")
	PICTURE_CACHE[path] = loaded
	return loaded


func load_pic(path: String):
	
	if ResourceLoader.exists(path) or path.begins_with("res://"):
		var texture: StreamTexture = load(path)
		if texture == null:
			print_debug("ERROR loading pic: " + path)
		return texture;
	
	
	var f = File.new();
	var err = f.open(path, File.READ)
	if err != OK:
		printerr("读取 " + path + " 失败：" + str(err))
		return null
	var buffer = f.get_buffer(f.get_len())
	f.close()
	var img = Image.new()
	var ret = - 1
	if path.ends_with(".png"):
		ret = img.load_png_from_buffer(buffer)
	elif path.ends_with(".jpg"):
		ret = img.load_jpg_from_buffer(buffer)
	elif path.ends_with(".jpeg"):
		ret = img.load_jpg_from_buffer(buffer)
	elif path.ends_with(".webp"):
		ret = img.load_webp_from_buffer(buffer)
	if ret != 0:
		printerr("加载 " + path + " 失败：" + str(err))
		return null
	var texture = ImageTexture.new()
	texture.resource_local_to_scene = true;
	texture.create_from_image(img)
	return texture


func scan_all_files(dir_path: String, recursive: bool = true) -> Array:
	var file_name: = ""
	var files: = []
	var dir: = Directory.new()
	var ret = dir.open(dir_path)
	if ret != OK:
		printerr("Code: ", ret, ", error opening ", dir_path)
		return []
	dir.list_dir_begin(true)
	if ( not dir_path.ends_with("/")):
		dir_path += "/";
	file_name = dir.get_next()
	while file_name != "":
		if recursive and dir.current_is_dir():
			var sub_path = dir_path + file_name
			files += scan_all_files(sub_path, recursive)
		else:
			var name: = dir_path + file_name
			files.push_back(name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return files


func scan_all_directory(dir_path: String) -> Array:
	var file_name: = ""
	var files: = []
	var dir: Directory = Directory.new()
	if dir.open(dir_path) != OK:
		printerr("Failed to open:" + dir_path);
	else:
		dir.list_dir_begin(true)
		file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				files.push_back(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		
	return files


var loadedFonts = {}

func get_font(size: int):
	
	var key = str(size)
	var ret = null
	if key in loadedFonts:
		ret = loadedFonts[key]
	else:
		ret = load("res://resource/font/FandolSong-Bold/" + key + ".tres")
		loadedFonts[key] = ret
	
	return ret


var press_dic: Dictionary = {};
const delay_time_emu_set = 0.07;
var delay_time_X = 0;
var delay_time_Y = 0;

func reset_input_press() -> void :
	press_dic.clear()
	return


func is_action_pressed_AX():
	var emu_A = "EMU_A";
	var emu_X = "EMU_X"
	if not (emu_A in press_dic):
		press_dic[emu_A] = false;
	
	var is_a_press = Input.is_action_pressed(emu_A);
	var is_just_a_press = Input.is_action_just_pressed(emu_A);
	var is_just_x_press = Input.is_action_just_pressed(emu_X);
	var is_x_press = Input.is_action_pressed(emu_X);
	if ( not is_a_press):
		press_dic[emu_A] = false;
	else:
		if (press_dic[emu_A]):
			is_a_press = false;
		else:
			press_dic[emu_A] = true;
	if (is_x_press):
		delay_time_X += SceneManager.public_detla;
		if (delay_time_X >= delay_time_emu_set):
			delay_time_X = 0;
			is_x_press = true;
		else:
			is_x_press = false;
	return is_just_a_press or is_a_press or is_x_press or is_just_x_press;


func is_action_pressed_BY():
	var emu_B = "EMU_B";
	var emu_Y = "EMU_Y"
	if not (emu_B in press_dic):
		press_dic[emu_B] = false;
	
	var is_b_press = Input.is_action_pressed(emu_B);
	var is_just_y_press = Input.is_action_just_pressed(emu_Y);
	var is_y_press = Input.is_action_pressed(emu_Y);
	if ( not is_b_press):
		press_dic[emu_B] = false;
	else:
		if (press_dic[emu_B]):
			is_b_press = false;
		else:
			press_dic[emu_B] = true;
	if (is_y_press):
		delay_time_Y += SceneManager.public_detla;
		if (delay_time_Y >= delay_time_emu_set):
			delay_time_Y = 0;
			is_y_press = true;
		else:
			is_y_press = false;
	return is_b_press or is_y_press or is_just_y_press;

var dic_press = {};
var dic_press_delay = {};
const delay_times = 45;
var delay_speed = 500;

func is_action_pressed_Up():
	var analog = "ANALOG_UP";
	if ( not dic_press_delay.has(analog)):
		dic_press_delay[analog] = 0;
	var is_press = Input.is_action_pressed(analog);
	var pre_is_press = false;
	if (dic_press.has(analog)):
		pre_is_press = dic_press[analog];
	dic_press[analog] = is_press;
	var is_just_press = ( not pre_is_press and is_press);
	if (is_just_press):
		return true;
	if ( not is_press):
		dic_press_delay[analog] = 0;
		return false;
	dic_press_delay[analog] += delay_speed * SceneManager.public_detla;
	if (dic_press_delay[analog] > delay_times):
		dic_press_delay[analog] = 0;
		return true;

func is_action_pressed_Down():
	var analog = "ANALOG_DOWN";
	if ( not dic_press_delay.has(analog)):
		dic_press_delay[analog] = 0;
	var is_press = Input.is_action_pressed(analog);
	var pre_is_press = false;
	if (dic_press.has(analog)):
		pre_is_press = dic_press[analog];
	dic_press[analog] = is_press;
	var is_just_press = ( not pre_is_press and is_press);
	if (is_just_press):
		return true;
	if ( not is_press):
		dic_press_delay[analog] = 0;
		return false;
	dic_press_delay[analog] += delay_speed * SceneManager.public_detla;
	if (dic_press_delay[analog] > delay_times):
		dic_press_delay[analog] = 0;
		return true;

func is_action_pressed_Left():
	var analog = "ANALOG_LEFT";
	if ( not dic_press_delay.has(analog)):
		dic_press_delay[analog] = 0;
	var is_press = Input.is_action_pressed(analog);
	var pre_is_press = false;
	if (dic_press.has(analog)):
		pre_is_press = dic_press[analog];
	dic_press[analog] = is_press;
	var is_just_press = ( not pre_is_press and is_press);
	if (is_just_press):
		return true;
	if ( not is_press):
		dic_press_delay[analog] = 0;
		return false;
	dic_press_delay[analog] += delay_speed * SceneManager.public_detla;
	if (dic_press_delay[analog] > delay_times):
		dic_press_delay[analog] = 0;
		return true;

func is_action_pressed_Right():
	var analog = "ANALOG_RIGHT";
	if ( not dic_press_delay.has(analog)):
		dic_press_delay[analog] = 0;
	var is_press = Input.is_action_pressed(analog);
	var pre_is_press = false;
	if (dic_press.has(analog)):
		pre_is_press = dic_press[analog];
	dic_press[analog] = is_press;
	var is_just_press = ( not pre_is_press and is_press);
	if (is_just_press):
		return true;
	if ( not is_press):
		dic_press_delay[analog] = 0;
		return false;
	dic_press_delay[analog] += delay_speed * SceneManager.public_detla;
	if (dic_press_delay[analog] > delay_times):
		dic_press_delay[analog] = 0;
		return true;

func get_datetime_now() -> DateTime:
	var dic_datetime: Dictionary = Time.get_datetime_dict_from_system()

	var dt = DateTime.new();
	dt.year = int(dic_datetime["year"]);
	dt.month = int(dic_datetime["month"]);
	dt.day = int(dic_datetime["day"]);
	dt.hour = int(dic_datetime["hour"]);
	dt.minute = int(dic_datetime["minute"]);
	dt.second = int(dic_datetime["second"]);
	
	return dt;




func get_random(from: int, to: int) -> int:
	while (true):
		randomize();
		var rand = int(round(randi() % (to - from + 1)) + from);
		
		if rand <= to and rand >= from:
			return rand;
	return to;


func get_rate_result(rate) -> bool:
	if rate <= 0:
		return false
	return get_random(0, 99) < int(ceil(rate));

var waiting_timers = []


func wait(sec: float, obj: Object, method: String, binds: Array = []) -> Timer:
	var node_name = str(OS.get_ticks_msec());
	var dic: Dictionary = {
		"id": node_name, 
		"obj": obj, 
		"method": method, 
		"binds": binds
	}
	var timer = Timer.new();
	timer.process_mode = 1;
	timer.one_shot = true;
	timer.name = node_name;
	timer.connect("timeout", self, "_on_wait_to", [dic]);
	add_child(timer);
	timer.wait_time = sec;
	timer.start();
	waiting_timers.append(timer)
	
	return timer;

func _on_wait_to(dic: Dictionary):
	
	var timer: Timer = get_node_or_null(dic["id"]);
	if (timer != null):
		waiting_timers.erase(timer)
		timer.stop();
		timer.name = dic["id"] + "_free";
		timer.queue_free();
	var obj: Object = dic["obj"];
	var method: String = dic["method"];
	var binds: Array = dic["binds"];
	obj.callv(method, binds);
	return

func clear_waits() -> void :
	waiting_timers.clear()
	return


func excute_str_code(code_line: String) -> String:
	var save_name = "temp_code.gd";
	var str_code = "";
	str_code += "extends Object\n";
	str_code += "func eval():\n";
	str_code += "\t" + "return " + code_line + "\n";
	var path = "user://" + str(save_name);
	Global.save_file_text(path, str_code);
	var sc = ResourceLoader.load(path, "", true).new();
	var result = sc.eval();
	Directory.new().remove(path);
	return str(result);


func count_formula_string(formula: String, a_actorId: int = - 1, b_actorId: int = - 1, dic_add = {}, obj: Object = null) -> String:
	var result_formula = formula;
	var replace_dict = {
		"random": "Global.get_random", 
		"阴": "-1", 
		"阳": "1", 
		"DataManager.year": str(DataManager.year), 
		"DataManager.month": str(DataManager.month), 
		"DataManager.orderbook": str(DataManager.orderbook), 
	}
	if a_actorId != - 1:
		var a = ActorHelper.actor(a_actorId)
		for property in ActorHelper.ActorInfo.ATTR_DICT:
			var old_str = "a." + property
			
			var val = 0
			match property:
				"知":
					val = a.get_wisdom();
				"武":
					val = a.get_power();
				"相性":
					val = a.get_personality()
				"面":
					val = a._get_attr_str("面")
				_:
					val = a._get_attr_int(property);
			if dic_add.has(property):
				val += int(dic_add[property])
			if dic_add.has("a." + property):
				val += int(dic_add["a." + property])
			var new_str = str(val)
			replace_dict[old_str] = new_str
		replace_dict["a.面"] = "0"
		if a._get_attr_str("面") == "阳":
			replace_dict["a.面"] = "1"
		elif a._get_attr_str("面") == "阴":
			replace_dict["a.面"] = "-1"
		replace_dict["a.相性"] = a.get_personality()
		replace_dict["a.性别"] = "'" + a.get_gender() + "'"
	if b_actorId != - 1:
		var b = ActorHelper.actor(b_actorId)
		for property in ActorHelper.ActorInfo.ATTR_DICT:
			var old_str = "b." + property
			
			var val = 0
			match property:
				"知":
					val = b.get_wisdom()
				"武":
					val = b.get_power()
				"相性":
					val = b.get_personality()
				"面":
					val = b._get_attr_str("面")
				_:
					val = b._get_attr_int(property)
			if dic_add.has("b." + property):
				val += int(dic_add["b." + property])
			var new_str = str(val)
			replace_dict[old_str] = new_str
		replace_dict["b.面"] = "0"
		if b._get_attr_str("面") == "阳":
			replace_dict["b.面"] = "1"
		elif b._get_attr_str("面") == "阴":
			replace_dict["b.面"] = "-1"
		replace_dict["b.相性"] = b.get_personality()
		replace_dict["b.性别"] = "'" + b.get_gender() + "'"
	
	var replace_keys = replace_dict.keys()
	replace_keys.sort_custom(self, "sort_string_by_length")
	for old_str in replace_keys:
		var new_str = str(replace_dict[old_str])
		result_formula = result_formula.replace(old_str, new_str)
	return Global.execute_expression(result_formula, obj)

func count_formula_bool(formula: String, a_actorId: int = - 1, b_actorId: int = - 1, dic_add = {}, obj: Object = null) -> bool:
	return count_formula_string(formula, a_actorId, b_actorId, dic_add, obj).to_lower() == "true"


func count_formula_number(formula: String, a_actorId: int = - 1, b_actorId: int = - 1, dic_add = {}) -> float:
	return float(count_formula_string(formula, a_actorId, b_actorId, dic_add))


func array_filter(array: Array):
	var new_array = [];
	for a in array:
		if (new_array.has(a)):
			continue;
		new_array.append(a);
	return new_array;


func execute_expression(code: String, obj: Object = null) -> String:
	if obj == null:
		obj = self
	var expression = Expression.new()
	code = code.replace("Global.get_random", "get_random")
	var error = expression.parse(code)
	if error != OK:
		print("ERROR CODE: ", code)
		print("ERROR INFO: ", expression.get_error_text())
	var result = expression.execute([], obj)
	if expression.has_execute_failed():
		print("FAILED CODE: ", code)
		print("FAILED INFO: ", expression.get_error_text())
	return str(result)

func log(info: String) -> void :
	print("{0} {1}".format([
		Time.get_datetime_string_from_system(false, true), 
		info
	]))
	return

func sort_string_by_length(a: String, b: String) -> bool:
	return b.length() < a.length()


static func to_hex(number, dit) -> String:
	var hex_digits = "0123456789ABCDEF"
	var hex = ""
	var decimal = int(number);
	
	while decimal > 0:
		var remainder = decimal % 16
		hex = hex_digits[remainder] + hex
		decimal = int(decimal / 16)
	
	while len(hex) < dit:
		hex = "0" + hex;
	
	return hex


static func color_to_hex(color: Color) -> String:
	var r = to_hex(color.r8, 2);
	var g = to_hex(color.g8, 2);
	var b = to_hex(color.b8, 2);
	
	
	var hex = "#" + str(r) + str(g) + str(b)
	return hex


static func load_script(path: String):
	if not path.begins_with("res://") and not path.begins_with("resource/"):
		path = "res://resource/sgz_script/" + path
	if not DataManager.is_developer():
		path = path.replace("res://resource/sgz_script/", "res://packed/sgz_script/")
	if Global.SCRIPT_CACHE.has(path):
		var prevLoaded = Global.SCRIPT_CACHE[path]
		if prevLoaded != null:
			prevLoaded._init()
			return prevLoaded
	var loaded = load(path)
	if loaded == null:
		printerr("error loading resource. path: ", path)
		return null
	var sc = loaded.new()
	Global.SCRIPT_CACHE[path] = sc
	return sc

func file_exists(path: String) -> bool:
	var f = File.new()
	return f.file_exists(path)

func get_file_size(path: String) -> int:
	var f = File.new()
	if f.open(path, File.READ) != OK:
		return 0
	var size = f.get_len()
	f.close()
	return size

func dir_exists(path: String) -> bool:
	var d = Directory.new()
	return d.dir_exists(path)


var user_preference: Dictionary = {}

func save_user_preference() -> void :
	if not update_user_preference():
		return
	Global.save_file_text("user://preference.json", to_json(user_preference))
	return

func update_user_preference() -> bool:
	var p = {}
	p["time_scale"] = Engine.time_scale
	p["x"] = OS.window_position.x
	p["y"] = OS.window_position.y
	p["w"] = OS.window_size.x
	p["h"] = OS.window_size.y
	p["mode"] = 1 if SceneManager.portrait_mode else 0
	var changed = false
	for key in p:
		if not key in user_preference:
			changed = true
			break
		if int(p[key]) != int(user_preference[key]):
			changed = true
			break
	if changed:
		user_preference = p
	return changed

func load_user_preference() -> void :
	user_preference = Global.dicval(parse_json(Global.get_file_text("user://preference.json")))
	return

func apply_user_preference() -> void :
	load_user_preference()
	for k in ["x", "y", "w", "h"]:
		if not k in user_preference:
			return
		if int(user_preference[k]) < 0:
			return
		user_preference[k] = int(user_preference[k])
	if not "time_scale" in user_preference:
		return
	user_preference["time_scale"] = float(user_preference["time_scale"])
	var x = Global.intval(user_preference["x"])
	x = max(0, x)
	var y = Global.intval(user_preference["y"])
	y = max(0, y)
	OS.window_position = Vector2(x, y)
	var w = Global.intval(user_preference["w"])
	w = max(300, w)
	var h = Global.intval(user_preference["h"])
	h = max(200, h)
	OS.window_size = Vector2(w, h)
	change_speed(float(user_preference["time_scale"]))
	if int(user_preference["mode"]) > 0:
		user_preference["mode"] = 1
		if not SceneManager.portrait_mode:
			SceneManager.switch_layout()
	else:
		user_preference["mode"] = 0
	return

var kept_speed: float = 1.0

func get_speed() -> float:
	return kept_speed

func change_speed(speed: float, temporary: bool = false):
	if not temporary:
		kept_speed = speed
	Engine.time_scale = speed
	SoundManager.change_speed(speed)
	return


func hex_decode(data: String) -> PoolByteArray:
	var ret = []
	var b: int = 0
	var odd = true
	for c in data.to_lower():
		if c in "abcdef":
			b += ord(c) - ord("a") + 10
		else:
			b += int(c)
		if odd:
			b *= 16
			odd = false
		else:
			ret.append(b)
			odd = true
			b = 0
	return ret

func intval(val, def: int = - 1) -> int:
	if val == null:
		return def
	match typeof(val):
		TYPE_INT: pass
		TYPE_REAL: pass
		TYPE_STRING: pass
		TYPE_BOOL: pass
		_: return def
	return int(val)

func boolval(val, def: bool = false) -> bool:
	return bool(intval(val, 1 if def else 0))

func strval(val, def: String = "") -> String:
	if val == null:
		return def
	return str(val)

func arrval(val) -> Array:
	match typeof(val):
		TYPE_STRING_ARRAY: pass
		TYPE_INT_ARRAY: pass
		TYPE_RAW_ARRAY: pass
		TYPE_ARRAY: pass
		TYPE_COLOR_ARRAY: pass
		TYPE_VECTOR2_ARRAY: pass
		TYPE_VECTOR3_ARRAY: pass
		TYPE_REAL_ARRAY: pass
		TYPE_STRING:
			
			
			if val.begins_with("[") and val.ends_with("]"):
				val = val.trim_prefix("[")
				val = val.trim_suffix("]")
				var ret = []
				for piece in val.split("), ("):
					piece = piece.trim_prefix("(")
					piece = piece.trim_suffix(")")
					var subpiece = piece.split(", ")
					if subpiece.size() == 2:
						ret.append(Vector2(int(subpiece[0]), int(subpiece[1])))
				return ret
			return []
		_: return []
	return Array(val)

func intarrval(val, removeDuplicated: bool = false) -> Array:
	var ret = []
	for item in arrval(val):
		var v = intval(item)
		if removeDuplicated and v in ret:
			continue
		ret.append(v)
	return ret

func dicval(val) -> Dictionary:
	var ret = {}
	if typeof(val) != TYPE_DICTIONARY:
		return ret
	for k in val:
		ret[k] = val[k]
	return ret

func floatval(val, def: float = - 1.0) -> float:
	if val == null:
		return def
	match typeof(val):
		TYPE_INT: pass
		TYPE_REAL: pass
		TYPE_STRING: pass
		TYPE_BOOL: pass
		_: return def
	return float(val)

func get_distance(a: Vector2, b: Vector2) -> int:
	var disv = a - b
	return int(abs(disv.x)) + int(abs(disv.y))

func get_range_distance(a: Vector2, b: Vector2) -> int:
	var disv = a - b
	return int(max(abs(disv.x), abs(disv.y)))


func clear_signals(control, signals: PoolStringArray) -> void :
	for sig in signals:
		for binded in control.get_signal_connection_list(sig):
			control.disconnect(binded.signal , binded.target, binded.method)
	return



func wait_for_confirmation(nextFlow: String, viewModelName: String = "", delta: float = - 1) -> bool:
	if viewModelName == "":
		viewModelName = LoadControl.view_model_name
	var sceneId = DataManager.get_current_scene_id()
	if sceneId >= 20000:
		var wf = DataManager.get_current_war_fight()
		if wf.auto_play_mode() and SceneManager.dialog_msg_complete():
			var now = int(Time.get_unix_time_from_system() * 1000)
			var completed = DataManager.get_env_int("DIALOG_COMPLETED")
			if completed <= 0:
				completed = now
				DataManager.set_env("DIALOG_COMPLETED", completed)
			elif now >= completed + 200:
				DataManager.unset_env("DIALOG_COMPLETED")
				next(nextFlow, viewModelName)
				return true
			return false
	if sceneId == 10000:
		if DataManager.is_autoplay_mode() and delta >= 0:
			var accumulated = DataManager.get_env_float("delta")
			DataManager.set_env("delta", accumulated + delta)
			if accumulated >= 1.0 * Engine.time_scale:
				DataManager.unset_env("delta")
				next(nextFlow, viewModelName)
				return true
	if not Global.is_action_pressed_AX():
		return false
	if not SceneManager.dialog_msg_complete(true):
		return false
	Input.action_release("EMU_A")
	next(nextFlow, viewModelName)
	return true


func wait_for_yesno(flowForYes: String, flowForNo: String, viewModelName: String = "", endOnNo: bool = false) -> void :
	if viewModelName == "":
		viewModelName = LoadControl.view_model_name
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		SceneManager.actor_dialog.move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		SceneManager.actor_dialog.move_right()
	if Global.is_action_pressed_BY():
		if not SceneManager.dialog_msg_complete(false):
			return
		DataManager.set_env(viewModelName, - 1)
		if endOnNo:
			LoadControl.end_script()
		FlowManager.add_flow(flowForNo)
		return
	if not Global.is_action_pressed_AX():
		return
	if not SceneManager.dialog_msg_complete(true):
		return
	DataManager.set_env(viewModelName, - 1)
	match SceneManager.actor_dialog.lsc.cursor_index:
		0:
			FlowManager.add_flow(flowForYes)
		1:
			if endOnNo:
				LoadControl.end_script()
			FlowManager.add_flow(flowForNo)
	return


func wait_for_choose_skill(nextFlow: String, backFlow: String, actorId: int = - 1) -> bool:
	if actorId < 0:
		actorId = DataManager.player_choose_actor
	if wait_for_choose_item(nextFlow, backFlow):
		return true
	var top = SceneManager.lsc_menu_top
	var list = DataManager.get_env_array("列表值")
	var currentSkill = ""
	if top.lsc.cursor_index >= 0 and top.lsc.cursor_index < list.size():
		var current = list[top.lsc.cursor_index]
		if typeof(current) == TYPE_ARRAY:
			
			currentSkill = current[1]
		elif typeof(current) == TYPE_DICTIONARY:
			
			if "skill_name" in current:
				currentSkill = current["skill_name"]
		else:
			current = str(current)
			
			currentSkill = current.split("#")[0]
			
			currentSkill = currentSkill.split("（")[0]
	if currentSkill.begins_with("-"):
		
		currentSkill = currentSkill.substr(1)
	if currentSkill != "":
		if currentSkill in ["上一页", "下一页"]:
			top.set_TopMsg_text("[center]{0}[/center]".format([currentSkill]))
		else:
			var sr = SkillInfo.SkillRecord.new(currentSkill, actorId)
			var content = "[center][color=yellow]【{0}】[/color]{1}，{2}[/center]".format([
				sr.name, sr.scene, sr.category
			])
			content += "\n\n" + sr.full_description()
			top.set_TopMsg_text(content)

	if Input.is_action_just_pressed("EMU_SELECT"):
		if top.get_TopMsg_visible():
			top.set_TopMsg_visible(false)
		else:
			top.set_TopMsg_visible(true)
	top.set_memo("查看/隐藏技能说明")
	return false


func wait_for_choose_item(nextFlow: String, backFlow: String = "", viewModelName: String = "") -> bool:
	if backFlow != "" and Global.is_action_pressed_BY():
		if not SceneManager.dialog_msg_complete():
			return false
		next(backFlow, viewModelName)
		return false

	var top = SceneManager.lsc_menu_top

	if Input.is_action_just_pressed("ANALOG_UP"):
		top.lsc.move_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		top.lsc.move_down()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		top.lsc.move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		top.lsc.move_right()

	var list = DataManager.get_env_array("列表值")
	if top.lsc.cursor_index < 0 or top.lsc.cursor_index >= list.size():
		return false

	var item = list[top.lsc.cursor_index]
	DataManager.set_env("当前项", item)

	if not Global.is_action_pressed_AX():
		return false
	if not SceneManager.dialog_msg_complete(true):
		return false

	DataManager.set_env("目标项", item)
	next(nextFlow, viewModelName)
	return true


func wait_for_choose_equip(nextFlow: String, backFlow: String = "", showEquipInfo: String = "") -> bool:
	var conEquipInfo: Control = SceneManager.conEquipInfo
	if conEquipInfo != null:
		conEquipInfo.hide()

	
	var currentFlow = DataManager.get_env_str("CURRENT_FLOW")
	var page = DataManager.get_env_int("列表页码")

	if wait_for_choose_item(nextFlow, backFlow):
		var selected = DataManager.get_env_dict("目标项")
		if not "ID" in selected:
			return false
		if not "类型" in selected:
			return false
		var equipId = int(selected["ID"])
		var equipType = str(selected["类型"])
		if currentFlow != "" and equipId == - 1:
			match equipType:
				"下一页":
					DataManager.set_env("列表页码", page + 1)
				"上一页":
					DataManager.set_env("列表页码", page - 1)
			FlowManager.add_flow(currentFlow)
			return false
		DataManager.set_env("CURRENT_FLOW", "")
		return true

	if currentFlow != "" and Input.is_action_just_pressed("EMU_START"):
		if not SceneManager.dialog_msg_complete(true):
			return false
		DataManager.set_env("列表页码", page + 1)
		FlowManager.add_flow(currentFlow)
		return false
	if currentFlow != "" and Input.is_action_just_pressed("EMU_SELECT"):
		if not SceneManager.dialog_msg_complete(true):
			return false
		DataManager.set_env("列表页码", page - 1)
		FlowManager.add_flow(currentFlow)
		return false

	if showEquipInfo == "" or conEquipInfo == null:
		return false

	var selected = DataManager.get_env_dict("当前项")
	if not "ID" in selected:
		return false
	if not "类型" in selected:
		return false
	var equipId = int(selected["ID"])
	var equipType = str(selected["类型"])
	if equipId >= 0:
		var equip = clEquip.equip(equipId, equipType)
		conEquipInfo.show_equipinfo(equip, showEquipInfo)
		conEquipInfo.show()

	return false


func wait_for_choose_option(nextFlow: String, viewModelName: String = "") -> bool:
	var menu = SceneManager.lsc_menu

	if Input.is_action_just_pressed("ANALOG_UP"):
		menu.lsc.move_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		menu.lsc.move_down()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		menu.lsc.move_left()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		menu.lsc.move_right()

	var list = DataManager.get_env_array("列表值")
	if menu.lsc.cursor_index < 0 or menu.lsc.cursor_index >= list.size():
		return false

	var item = list[menu.lsc.cursor_index]
	DataManager.set_env("当前项", item)

	if not Global.is_action_pressed_AX():
		return false
	if not SceneManager.dialog_msg_complete(true):
		return false

	DataManager.set_env("目标项", item)
	if nextFlow != "":
		next(nextFlow, viewModelName)
	return true

func next(nextFlow: String, viewModelName: String = "") -> void :
	if viewModelName == "":
		LoadControl.set_view_model( - 1)
	else:
		DataManager.set_env(viewModelName, - 1)
	if nextFlow != "":
		FlowManager.add_flow(nextFlow)
	return

func dic_val(dic: Dictionary, key: String, defVal = null):
	if key in dic:
		return dic[key]
	return defVal

func dic_val_int(dic: Dictionary, key: String, defVal = - 1):
	return intval(dic_val(dic, key, defVal))

func dic_val_int_array(dic: Dictionary, key: String):
	return Global.intarrval(dic_val(dic, key, []))

func bind_button_tooltip(btn: Node, tooltip: String):
	btn.hint_tooltip = tooltip
	clear_signals(btn, ["pressed"])
	btn.connect("pressed", self, "tooltip_button_pressed", [btn])
	return

func tooltip_button_pressed(btn: Button):
	var tooltip = btn.hint_tooltip
	if tooltip == "":
		return
	var popup = PopupPanel.new()
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.2, 0.2, 0.2, 1)
	stylebox.set_corner_radius_all(8)
	stylebox.set_border_width_all(2)
	stylebox.border_color = Color(1, 1, 1)
	var margin = MarginContainer.new()
	margin.add_constant_override("margin_top", 8)
	margin.add_constant_override("margin_bottom", 8)
	margin.add_constant_override("margin_left", 16)
	margin.add_constant_override("margin_right", 16)
	popup.add_stylebox_override("panel", stylebox)
	popup.add_child(margin)
	var label = Label.new()
	label.autowrap = true
	label.valign = Label.VALIGN_TOP
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.rect_min_size.x = 320
	label.text = tooltip
	margin.add_child(label)
	btn.add_child(popup)
	popup.popup_centered()
	var pos = btn.get_global_rect().position + Vector2(40, - 40)
	pos.x = min(pos.x, 600 - btn.rect_size.x)
	popup.rect_position = pos
	return


func color_distance(color1: Color, color2: Color) -> float:
	var rDiff = color1.r - color2.r
	var gDiff = color1.g - color2.g
	var bDiff = color1.b - color2.b

	var distance = sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
	return distance

func load_actor_avatar(actorId: int, avatar: Sprite, scale: float) -> void :
	var actor = ActorHelper.actor(actorId)
	var setting = actor.get_avatar_setting()
	var idx = setting[0]
	var img = setting[1]
	var width = img.get_width()
	var height = 40
	var xFrames = 8
	if width != 32 * 8:
		
		height = img.get_height()
		var ratio = int(width * 50 / height)
		if ratio >= 36 and ratio <= 44:
			xFrames = 1
		width = int(width / xFrames)
	else:
		width = 32
	avatar.texture = img
	avatar.region_enabled = true
	avatar.region_rect = Rect2(0, height * idx, width, height)
	if xFrames == 8:
		avatar.region_rect = Rect2(4 * width, height * idx, width, height)
	avatar.scale = scale * Vector2(32.0 / width, 40.0 / height)
	return

