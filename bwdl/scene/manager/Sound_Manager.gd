# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/manager/Sound_Manager.gd
# 说明：声音管理器（自动加载）。管理背景音乐与音效的播放。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

var sign_obj = null;
var sign_method = "";

var sign_se_obj = null;
var sign_se_method = "";

var sound_speed_not_change = false
var sound_effect_disabled = false
var layout_landscape_extend = false
var traditional_soldier_image = false
var custom_avatar_prefered = false

onready var bgm = get_node("bgm");
onready var se = get_node("se");
onready var se2 = get_node("se2");
onready var anim = get_node("anim")


var last_track_url: String = ""

var last_anim_track_url: String = ""

var anim_playing: bool = false


func _ready() -> void :
	var db = get_sound_set()
	update_volume()
	
	pause_mode = PAUSE_MODE_PROCESS
	return

func update_volume() -> void :
	var db = get_sound_set()
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear2db(1.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(float(db["音乐音量"])))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SE"), linear2db(float(db["音效音量"])))
	return


func reset():
	disconnect_finished();
	stop();
	return

func get_sound_set() -> Dictionary:
	var ret = {
		"音乐音量": 1, 
		"音效音量": 1, 
		"不加速": false, 
		"关闭音效": false, 
		"横屏扩展": false, 
		"传统兵模": false, 
		"自定义头像": false, 
	}
	var dic_str = Global.get_file_text("user://sound_set.json");
	if dic_str == "":
		return ret
	var dic = parse_json(dic_str)
	
	if "音量" in dic:
		ret["音乐音量"] = db2linear(float(dic["音量"]))
	for k in ["音乐音量", "音效音量"]:
		if dic.has(k):
			ret[k] = float(dic[k])
	for k in ["不加速", "关闭音效", "横屏扩展", "传统兵模", "自定义头像"]:
		if dic.has(k):
			ret[k] = bool(dic[k])
	sound_speed_not_change = dic["不加速"]
	sound_effect_disabled = dic["关闭音效"]
	if "横屏扩展" in dic:
		layout_landscape_extend = dic["横屏扩展"]
	if "传统兵模" in dic:
		traditional_soldier_image = dic["传统兵模"]
	if "自定义头像" in dic:
		custom_avatar_prefered = dic["自定义头像"]
	return ret

func set_sound_set(dic: Dictionary):
	Global.save_file_text("user://sound_set.json", to_json(dic))
	get_sound_set()
	return

func set_bgm_loop(loop: bool):
	if (bgm != null and bgm.stream != null):
		bgm.stream.set("loop", loop);

func load_bgm(track_url: String = "") -> bool:
	var track = null;
	if track_url == "":
		track = get_default_track()
	track = load(track_url);
	if track == null:
		bgm.stop();
		return false
	bgm.stream = track;
	bgm.stream.resource_local_to_scene = true;
	return true;

func get_default_track() -> String:
	match DataManager.get_current_scene_id():
		0:
			return "res://resource/sounds/bgm/Scene_Title.ogg"
		10000:
			return "res://resource/sounds/bgm/Scene_Affiars.ogg"
		20000:
			return "res://resource/sounds/bgm/Scene_War.ogg"
		30000:
			return "res://resource/sounds/bgm/Scene_Battle.ogg"
		40000:
			return "res://resource/sounds/bgm/Scene_Solo.ogg"
	return ""


func play_bgm(track_url: String = "", loop: bool = true, forceAnimStop: bool = false, ignoreLast: bool = false):
	if anim.playing:
		if not forceAnimStop:
			return
		anim.stop()
	if track_url == "":
		track_url = get_default_track()
	if bgm.playing and last_track_url == track_url:
		return
	if not ignoreLast:
		last_track_url = track_url
	if track_url == "":
		return
	bgm.stop();
	if not load_bgm(track_url):
		return
	set_bgm_loop(loop)
	bgm.play()
	return


func play_anim_bgm(track_url: String = ""):
	if anim.playing and track_url == last_anim_track_url:
		
		return
	var current = bgm.stream
	if track_url != "":
		stop()
	anim_playing = true
	last_anim_track_url = track_url
	anim.stream = load(track_url);
	anim.stream.set("loop", false);
	anim.play();
	return

func play_se(track_url: String = "", _sign_se_obj = null, _sign_se_method: String = "", hasAnimation: bool = false):
	if (is_se_playing()):
		return ;
	sign_se_obj = _sign_se_obj;
	sign_se_method = _sign_se_method;
	if sound_effect_disabled:
		if hasAnimation:
			var waits = StaticManager.NO_SE_WAIT_TIME * Engine.time_scale
			Global.wait(waits, self, "_on_se_finished")
		else:
			_on_se_finished()
	else:
		se.stream = load(track_url);
		se.stream.set("loop", false);
		se.play();
	return


func play_se2(track_url: String, offset: float = 0.0, callbackObject = null, callback: String = "", callbackBinds: Array = []):
	if sound_effect_disabled:
		if callbackObject != null:
			var waits = StaticManager.NO_SE_WAIT_TIME * Engine.time_scale
			Global.wait(waits, callbackObject, callback, callbackBinds)
			return
	se2.stream = load(track_url)
	se2.stream.set("loop", false)
	if callbackObject != null:
		se2.connect("finished", callbackObject, callback, callbackBinds, CONNECT_REFERENCE_COUNTED)
	se2.play(offset)
	return

func is_se_playing():
	return se.playing

func is_se2_playing():
	return se.playing

func _on_se_finished():
	if (sign_se_obj != null and is_instance_valid(sign_se_obj)):
		
		if (sign_se_method != ""):
			sign_se_obj.call_deferred(sign_se_method);
	else:
		
		if ( not is_bgm_playing()):
			play_bgm();
	sign_se_obj = null;
	sign_se_method = "";
	return


func stop():
	bgm.stop();
	se.stop();
	se2.stop();
	anim.stop();
	return


func pause(b: bool):
	if b:
		pause_mode = PAUSE_MODE_STOP
	else:
		pause_mode = PAUSE_MODE_PROCESS
	bgm.stream_paused = b;
	se.stream_paused = b;
	se2.stream_paused = b;
	anim.stream_paused = b;
	return


func replay():
	bgm.stop();
	bgm.play();
	pass


func connect_finished(obj: Object, method: String):
	disconnect_finished();
	sign_obj = obj;
	sign_method = method;
	return


func disconnect_finished():
	sign_obj = null;
	sign_method = "";
	sign_se_obj = null;
	sign_se_method = "";
	return


func is_bgm_playing():
	return bgm.playing;

func _on_bgm_finished() -> void :
	if (sign_obj != null and is_instance_valid(sign_obj)):
		if (sign_method != ""):
			sign_obj.call_deferred(sign_method);
	sign_obj = null;
	sign_method = "";
	return
	
func change_speed(speed: float):
	se.pitch_scale = speed;
	if (sound_speed_not_change):
		speed = 1;
	bgm.pitch_scale = speed;
	anim.pitch_scale = speed;
	return

func _on_Timer_timeout() -> void :
	if (sign_se_obj != null and is_instance_valid(sign_se_obj)):
		if not is_se_playing():
			_on_se_finished();
	
	if (sign_obj != null and is_instance_valid(sign_obj)):
		if not is_bgm_playing():
			_on_bgm_finished();

	return
