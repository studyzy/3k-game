extends Control

class SimulatedBattleTactic extends Resource:

	var selectedTactic: String = ""

	func set_select_tactic_name(tactic: String) -> void :
		selectedTactic = tactic
		return

	func get_select_tactic_name() -> String:
		return selectedTactic

	func show():
		return

	func hide():
		return

var SCENE_ID: int = 0

const TEST_SCRIPT_BASE = "res://test/"

onready var lsc = get_node("lsc");
onready var console = get_node("bottom/RichTextLabel");
onready var memo = get_node("Label")


onready var war_map = $war_map


var battle_tactic = SimulatedBattleTactic.new()

var model_view = 0
var cases = []

var war_communique = self

var messages: String = ""
var runningTest: Thread = null

signal traced
signal test_finished

func _ready() -> void :
	connect("test_finished", self, "test_finished")
	model_view = 0
	
	SceneManager.load_scene_complete = true;
	FlowManager.clear_bind_method();
	FlowManager.bind_import_flow("start_test", self)

	DataManager.game_set["技能系统"] = "是"
	
	cases.clear()
	lsc.items = []

	add_case("基础数据", ["random.gd", "actor_info.gd"])
	add_case("内政技能", "skills_10000.gd")
	add_case("技能框架", "skill_basics.gd")
	add_case("大战场技能", "skills_20000.gd")
	add_case("脚本正确性", "script_load.gd")
	add_case("小战场技能", "skills_30000.gd")
	add_case("功能回归", "regressions.gd")
	add_case("单挑技能", "skills_40000.gd")
	
	lsc._set_data()
	_show_case_info()
	return

func add_case(name: String, scriptPath):
	for case in cases:
		if case[0] == name:
			return
	cases.append([name, scriptPath])
	lsc.items.append(name)
	return
	

func _process(delta: float) -> void :
	match model_view:
		0:
			SceneManager.actor_dialog.hide()
			
			if Input.is_action_just_pressed("ANALOG_DOWN"):
				lsc.move_down()
			if Input.is_action_just_pressed("ANALOG_UP"):
				lsc.move_up()
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				lsc.move_left()
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				lsc.move_right()
			_show_case_info()
			if Input.is_action_just_pressed("EMU_START"):
				model_view = - 1
				FlowManager.add_flow("start_test")
	return

func start_test():
	if runningTest != null:
		trace("有测试正在执行")
		model_view = 0
		return
	reset_console()
	lsc.cursor.hide()
	run_test()
	
	
	return

func run_test():
	var case = cases[lsc.cursor_index][0]
	var paths = cases[lsc.cursor_index][1]
	if typeof(paths) == TYPE_STRING:
		paths = [paths]
	for path in paths:
		path = TEST_SCRIPT_BASE + path
		var script = Global.load_script(path)
		var time = Time.get_ticks_usec()
		trace("开始运行测试用例：" + case)
		trace("=============")
		var res = script.runAll()
		time = Time.get_ticks_usec() - time
		if not res:
			trace("测试异常结束！耗时：{0}秒".format([time / 1000.0 / 1000.0]))
		else:
			trace("=============")
			trace("测试正常，耗时：{0}秒".format([time / 1000.0 / 1000.0]))
	SceneManager.current_scene().emit_signal("test_finished")
	return

func test_finished() -> void :
	
	runningTest = null
	lsc.cursor.show()
	model_view = 0
	return

func _show_case_info():
	var case = cases[lsc.cursor_index][0]
	var paths = cases[lsc.cursor_index][1]
	var path = ""
	if typeof(paths) == TYPE_STRING:
		path = TEST_SCRIPT_BASE + paths
	else:
		path = TEST_SCRIPT_BASE + "|".join(paths)
	memo.text = "【用例】{0}：{1}".format([case, path])
	return

func reset_console():
	messages = ""
	console.bbcode_text = ""
	return

func trace(info: String):
	messages = messages + "\n" + info
	call_deferred("traced")
	yield(SceneManager.current_scene(), "traced")
	return

func traced():
	console.bbcode_text = messages
	emit_signal("traced")
	return


func update_units() -> void :
	return

func reset_layout_landscape():
	rect_scale = Vector2(1, 1)
	rect_position = Vector2(0, 0)
	lsc.rect_position = Vector2(269, 29)
	return

func reset_layout_portrait():
	rect_scale = Vector2(1.6, 1.6)
	rect_position = Vector2( - 308, 0)
	lsc.rect_position = Vector2(269, 29)
	return


func create_or_update_unit(bu) -> void :
	return
