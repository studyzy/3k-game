# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/Flow_Manager.gd
# 说明：游戏流程调度器（自动加载）。用「流程字符串」驱动场景切换、动画播放、数据存取等状态机流转。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Node

# ------------------------------------------------------------------------------
# 流程系统核心说明：
# 本游戏用「流程字符串」驱动所有状态切换，字符串格式为 "流程名|参数1|参数2|..."。
# 例如 "go_to_scene|scene_war" 表示切换到战争场景。
#  - flow_array / pre_flow_array：待执行流程队列（pre 为预加载阶段队列）
#  - dic_method：流程名 -> 对象方法的绑定表（由各 UI/场景注册）
#  - _translate()：解析并分发流程字符串
# ------------------------------------------------------------------------------

# 是否允许添加新流程（加载/黑屏期间会暂时关闭，转而进入 pending 队列）
var enable_add = true;

# 当前拥有控制权的玩家编号（多人联机用）
remote var controlNo = 0;

# 主流程队列
var flow_array = [];

# 预加载流程队列（用于读档等需要先暂停画面的场景）
var pre_flow_array = [];

# 暂缓执行的流程队列（enable_add 关闭期间收集）
var pending_flows = []

# 各玩家流程完成标记（联机同步用）
var player_flow_end = {};
var dic_method: Dictionary = {};
var _next_flow = ""
var last_flow: String = ""


var flows_history_list = [];
var clear_pre_history: Array = [];

func _ready() -> void :
	set_pause_mode(Node.PAUSE_MODE_PROCESS)
	return

func has_task() -> bool:
	
	if (AutoLoad.playerNo != 0):
		return false;
	return flow_array.size() + pre_flow_array.size() > 0;

func clear_bind_method():
	dic_method = {};
	clear_pre_history.clear();
	return

func bind_signal_method(flow_name: String, obj, method: String = ""):
	if method == "":
		method = flow_name
	var gdsc: GDScript = obj.script;
	dic_method[flow_name] = {"obj": obj, "method": method, "gdpath": gdsc.resource_path}
	return

func bind_import_flow(flow_name: String, obj, method: String = ""):
	if method == "":
		method = flow_name
	bind_signal_method(flow_name, obj, method);
	if ( not clear_pre_history.has(flow_name)):
		clear_pre_history.append(flow_name);
	return

func clear():
	FlowManager.force_change_controlNo(0);
	dic_method = {}
	pre_flow_array = []
	flow_array = []
	player_flow_end = {}
	pending_flows = []
	_next_flow = "";
	flows_history_list = []
	clear_pre_history = []
	return

func set_current_control_playerNo(pno):
	if (AutoLoad.playerNo != 0):
		return ;
	
	FlowManager.add_flow("controlNo|" + str(pno))
	return


func force_change_controlNo(pno):
	controlNo = pno;
	if (AutoLoad.check_is_multigame()):
		rset("controlNo", pno);
	return

func add_flow(flow: String, instantRun: bool = false) -> bool:
	if SceneManager.is_test_running:
		
		last_flow = flow
		return true

	
	SceneManager.get_node("Virtukey/VirtualKey/btnShowSkill").hide()

	
	if flow in dic_method:
		
		instantRun = true

	DataManager.game_trace("== ADDING {0}FLOW {1}".format([
		"LOCAL " if instantRun else "", flow
	]))

	Input.action_release("EMU_A")
	Input.action_release("EMU_B")
	
	if flow == "":
		return false
	
	if not enable_add:
		add_pending_flow(flow)
		return false
	
	if AutoLoad.playerNo != 0:
		if AutoLoad.playerNo == controlNo:
			rpc_id(1, "rpc_add_flow", flow, instantRun)
			return true
	else:
		if AutoLoad.playerNo == controlNo:
			rpc_add_flow(flow, instantRun)
			return true
	return false


remote func rpc_add_flow(flow: String, instantRun: bool = false):
	if not flow_array.empty():
		if flow_array[flow_array.size() - 1] == flow:
			return
	if not pre_flow_array.empty():
		if pre_flow_array[0] in ["enable_add", "draw_actors"]:
			add_pending_flow(flow)
			return
	flow_array.append(flow)
	if instantRun:
		_start()
	return

func add_pre_flows(flows: Array):
	if AutoLoad.playerNo != 0:
		return
	SceneManager.VirtualKey.emu_enable = false
	SceneManager.black.show()
	var new_flows: Array = flows.duplicate()
	new_flows.append("enable_add")

	for flow in new_flows:
		add_pre_flow(flow)
	return

func add_pre_flow(flow: String):
	DataManager.game_trace("== ADDING PRE FLOW " + flow)

	if flow.split("|")[0] == "load_game_data":
		return
	if flow.split("|")[0] == "save_game_data":
		return
	for prefix in ["month_auto", "tactic_impact"]:
		if flow.begins_with(prefix):
			
			
			
			add_pending_flow(flow)
			return
	if AutoLoad.playerNo != 0:
		if (AutoLoad.playerNo == controlNo):
			rpc_id(1, "rpc_add_pre_flow", flow)
			return ;
	else:
		rpc_add_pre_flow(flow)
		return


remote func rpc_add_pre_flow(flow: String):
	if not pre_flow_array.empty():
		if pre_flow_array[pre_flow_array.size() - 1] == flow:
			return
	pre_flow_array.append(flow)
	return

var delta_times = 0;
func _process(delta: float) -> void :
	if ( not SceneManager.load_scene_complete):
		return ;
	if ( not check_wait_complete()):
		return ;
	if ( not flow_array.empty() or not pre_flow_array.empty()):
		_start();
	else:
		if (AutoLoad.check_is_multigame()):
			delta_times += delta;
			if (delta_times > 0.2):
				delta_times = 0;
				
				if (AutoLoad.playerNo == 0):
					force_change_controlNo(FlowManager.controlNo);


func _start():
	player_flow_end = {};
	
	if (AutoLoad.playerNo != 0):
		return ;
	if ( not flow_array.empty()):
		
		var next_flow = flow_array.pop_front();
		player_flow_end = {};
		add_history(next_flow);
		_translate(next_flow, false);
		if (AutoLoad.check_is_multigame()):
			rpc("_translate", next_flow, false);
	elif ( not pre_flow_array.empty()):
		
		var next_flow = pre_flow_array.pop_front();
		player_flow_end = {};
		_translate(next_flow, true);
		if (AutoLoad.check_is_multigame()):
			rpc("_translate", next_flow, true);
	return

func add_history(flow: String):
	
	if "clear" in flows_history_list:
		if flows_history_list[flows_history_list.size() - 1] != "clear":
			while true:
				var front = flows_history_list.pop_front()
				if front == "clear":
					break
	if flow in clear_pre_history:
		flows_history_list.clear()
	if "load_script" in flow:
		return
	if "controlNo" in flow:
		return
	if "go_to_scene" in flow:
		flows_history_list.clear()
		return
	flows_history_list.append(flow)
	return


# 流程分发核心：解析 "流程名|参数1|参数2|..." 并执行对应动作。
# is_pre=true 表示处于预加载流程（读档等），执行前会先做临时存档/读档。
remote func _translate(next_flow: String, is_pre: bool):
	SceneManager.update_runtime_info({"flow": next_flow})
	# 取流程名（第一个 | 之前的部分）
	var type = next_flow.split("|")[0];
	var parms = [];
	for s in next_flow.split("|"):
		if (s == type):
			continue;
		parms.append(s);
	_next_flow = next_flow;
	if (is_pre):
		
		
		
		
		_temp_save_data()
		_temp_load_data()
	else:
		
		_clear_temp_data()
	match type:
		# 播放内政动画：参数 = [动画名, 后续流程, 是否自动BGM, 消息, 说话人, 情绪]
		"play_affiars_animation":
			var anim = str(parms[0])
			var nextFlow = str(parms[1])
			var bgmauto = str(parms[2]).to_lower() == "true"
			var withMessage = ""
			var withSpeaker = - 1
			var withMood = 2
			if parms.size() >= 4:
				withMessage = str(parms[3])
			if parms.size() >= 6:
				withSpeaker = int(parms[4])
				withMood = int(parms[5])
			SceneManager.play_affiars_animation(
				anim, nextFlow, bgmauto, 
				withMessage, withSpeaker, withMood
			)
		# 播放战争动画：参数 = [动画名, 目标ID, 后续流程, 消息, 说话人, 情绪]
		"play_war_animation":
			var anim = str(parms[0])
			var targetId = int(parms[1])
			var nextFlow = str(parms[2])
			var withMessage = ""
			var withSpeaker = - 1
			var withMood = - 1
			if parms.size() >= 6:
				withMessage = str(parms[3])
				withSpeaker = int(parms[4])
				withMood = int(parms[5])
			SceneManager.play_war_animation(
				anim, targetId, nextFlow, 
				withMessage, withSpeaker, withMood
			)
		"confirm_to_ready":
			LoadControl.confirm_to_ready();
		"clear":
			pass
		"pause":
			var b: bool = parms[0] == "true";
			SceneManager.pause(b);
		"show_confirm_dialog":
			SceneManager.show_confirm_dialog(parms[0], int(parms[1]), int(parms[2]));
			if (str(parms[3]).to_lower() == "true"):
				SceneManager.show_cityInfo(true);
		# 切换到目标场景：参数 = [场景路径]，切换前先释放所有输入
		"go_to_scene":
			
			Input.action_release("ANALOG_LEFT")
			Input.action_release("ANALOG_RIGHT")
			Input.action_release("ANALOG_UP")
			Input.action_release("ANALOG_DOWN")
			Input.action_release("EMU_A")
			Input.action_release("EMU_B")
			Input.action_release("EMU_X")
			Input.action_release("EMU_Y")
			Input.action_release("EMU_SELECT")
			Input.action_release("EMU_START")
			
			Global.change_speed(Global.get_speed())
			var scene = str(parms[0])
			SceneManager.go_to_scene(scene);
			
			if (AutoLoad.playerNo == 0):
				if (is_pre):
					pre_flow_array.append("open_process");
				else:
					flow_array.append("open_process");
		# 读取存档：参数 = [存档槽位]，读档后恢复流程历史并跳转到存档场景
		"load_game_data":
			
			var saveSlot = DataManager.get_env_str("saveSlot")
			var data = parse_json(DataManager.read_game_data_str(parms[0]))
			
			var drama_path = ""
			if "drama_path" in data:
				drama_path = data["drama_path"]
			DataManager.loading_version_resource(data["mod_path"], drama_path)
			DataManager.set_save_data(data)
			DataManager.set_env("saveSlot", saveSlot)
			
			var flows_list: Array = Array(data["flows_history_list"]).duplicate();
			var scene_path = data["current_scene_path"]
			flows_list.insert(0, "go_to_scene|" + scene_path)
			
			var wf = DataManager.get_current_war_fight()
			if wf != null and wf.status == 1:
				flows_list.append("draw_actors")
			FlowManager.add_pre_flows(flows_list)
		# 恢复流程添加能力：黑屏结束，重新启用输入
		"enable_add":
			enable_add = true;
			SceneManager.black.hide();
			SceneManager.VirtualKey.emu_enable = true;
		"show_war_intro":
			
			var wf = DataManager.get_current_war_fight()
			if wf != null and is_instance_valid(SceneManager.war_intro):
				
				SceneManager.war_intro.show_war_intro(wf, "")
			else:
				SceneManager.black.hide()
		# 切换控制权玩家：参数 = [玩家编号]
		"controlNo":
			controlNo = int(parms[0]);
		# 开启处理：场景加载完成后更新技能Buff、恢复运行、冲刷暂缓流程
		"open_process":
			SkillHelper.update_all_skill_buff("OPEN")
			_temp_save_data(true)
			var scene: Node = SceneManager.current_scene();
			if (is_instance_valid(scene) and not scene.is_processing()):
				scene.set_process(true);
			while not pending_flows.empty():
				var flow = pending_flows.pop_front()
				add_flow(flow)
		# 加载脚本：参数 = [脚本路径]
		"load_script":
			LoadControl.load_script(str(parms[0]));
		_:
			# 默认分支：查找是否绑定了对应流程名的对象方法，找到则延迟调用
			var pieces = next_flow.split("|")
			next_flow = pieces[0]
			if next_flow in dic_method.keys():
				var obj: Object = dic_method[next_flow]["obj"]
				var method = dic_method[next_flow]["method"]
				if is_instance_valid(obj):
					DataManager.fix_data()
					
					if pieces.size() > 1:
						obj.call_deferred(method, pieces[1])
					else:
						obj.call_deferred(method)
			else:
				print("无法识别流程:" + next_flow)
	_temp_load_data()
	_translate_complete(next_flow, is_pre)
	return


func _translate_complete(next_flow: String, is_pre: bool):
	var tracing = "== TRANSLATED FLOW "
	if is_pre:
		tracing = "== TRANSLATED PRE FLOW "
	if not is_pre or not _next_flow.begins_with("load_game"):
		last_flow = _next_flow
	_next_flow = "";
	
	
	for key_flow in dic_method.keys():
		var dic = dic_method[key_flow];
		var obj = dic["obj"];
		if (is_instance_valid(obj)):
			continue;
		dic_method.erase(key_flow);
	
	var new_clear_array = [];
	for cl in clear_pre_history:
		if cl in dic_method.keys():
			new_clear_array.erase(cl)
			new_clear_array.append(cl)
	
	clear_pre_history = new_clear_array.duplicate();

	if ( not AutoLoad.check_is_multigame()):
		


		return ;
	elif (AutoLoad.playerNo != 0):
		
		rpc_id(1, "_call_back", AutoLoad.playerNo);
	return


remote func _call_back(_pno):
	player_flow_end[str(_pno)] = true;
	

func check_wait_complete() -> bool:
	if (_next_flow == ""):
		return true;
	for pno in AutoLoad.other_players.size():
		var key = str(pno);
		if ( not player_flow_end.has(key)):
			return false;
	return true;

var temp_data_exists = false


func _temp_save_data(force: bool = false) -> void :
	if temp_data_exists and not force:
		return
	temp_data_exists = true
	StaticManager.temp_data = to_json(DataManager.get_save_data())
	DataManager.game_trace("SAVING tmp DATA")
	return


func _temp_load_data():
	if not temp_data_exists:
		return
	DataManager.set_save_data(parse_json(StaticManager.temp_data))
	
	
	LoadControl.create()
	DataManager.game_trace("LOADING tmp DATA")
	return

func _clear_temp_data():
	temp_data_exists = false
	return

func add_pending_flow(flow: String) -> void :
	if not pending_flows.empty():
		if pending_flows[pending_flows.size() - 1] == flow:
			return
	pending_flows.append(flow)
	return
