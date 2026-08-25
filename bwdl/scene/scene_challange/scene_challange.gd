# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_challange/scene_challange.gd
# 说明：挑战模式场景脚本。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const SCENE_ID = 0

onready var lsc = $"bottom/lsc"

var model = 0


func _ready():
	
	SceneManager.load_scene_complete = true
	
	DataManager.data_all_clear()
	
	OS.request_permissions()
	model = 0
	return

func _process(delta):
	if AutoLoad.playerNo != FlowManager.controlNo:
		return
	match model:
		0:
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				lsc.move_left()
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				lsc.move_right()
			
			if Input.is_action_just_pressed("EMU_START"):
				model = - 1
				var dic = {}
				dic["version"] = StaticManager.CURRENT_CHALLANGE_VERSION
				dic["start"] = Time.get_unix_time_from_system()
				DataManager.loading_version_resource(DataManager.mod_path, "", {"挑战赛": dic})
				DataManager.game_set["人物大限"] = "无大限"
				DataManager.game_set["出仕时间"] = "正常"
				DataManager.game_set["出仕地点"] = "随机"
				DataManager.game_set["自动复活"] = "无"
				DataManager.game_set["监狱系统"] = "无"
				DataManager.game_set["技能系统"] = "是"
				DataManager.game_set["武将成长"] = "就不加"
				DataManager.unset_env("DIY")
				DataManager.players.clear()
				DataManager.players.append(Player.new())
				DataManager.game_mode = 0
				DataManager.game_mode2 = 0
				DataManager.diffculities = 4
				DataManager.common_variable.erase("剧情.对白")
				DataManager.common_variable.erase("剧情.类型")
				FlowManager.add_flow("go_to_scene|res://scene/scene_endless/scene_endless.tscn")
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.6, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(192, 0)
	rect_scale = Vector2(1, 1)
	return
