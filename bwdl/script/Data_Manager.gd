extends Node

signal soldier_damaged(targetId, damage)
signal hp_damaged(targetId, damage)

const DISPLAY_VERSION = "2.560"
const VERSION = "2.560"
const DEFAULT_CONTACT = "(28群)1025656970"






const COMPABILITY = 2






var game_saving_enabled = true

const DEFAULT_MOD_PATH = "res://resource/"

var debug_info = {}

var history_version = []

var unify_times = 0;


var cloudVersion: Dictionary = {}


var cityInfo_type = 0;

var citys_unoffice: Array = [];

var actor_follower: Array = [];

var drama_events_process: Dictionary = {}


var last_trace_time = - 1

var first_grouped_trace = - 1
var last_grouped_trace = - 1
var grouped_trace_dic = {}



var test_player_flag: int = - 1
var test_player_specials: Dictionary = {}
var test_content: String = ""



var mod_path = "";
var drama_path = "";
var mod;
var mod_name_CN = "原版";

var cur_skill_triggers = [];


var common_variable: Dictionary = {};

var players: Array = [Player.new()];

var actors: Array = [];

var actor_scene_skill: Dictionary = {};

var actor_ban_scene_skill: Array = [];

var actor_disabled_equip_types: Dictionary = {}

var citys: Array = [];

var vstates: Array = [];

var vstates_alliance: Dictionary = {};

var weapons: Array = [];

var suits: Array = [];

var jewelrys: Array = [];

var steeds: Array = [];


var diffculities: int = 0;

# 修改：AI Agent 接入——仅「大模型」难度为 true，控制战争层与白兵战是否使用远程决策器
var ai_agent_mode: bool = false;

# 修改：AI Agent 接入——远程服务地址，可配置并持久化到 user://ai_agent.cfg
# 空字符串表示「自动」：Web 端用当前站点 origin，桌面端用本机 8060
var ai_agent_base_url: String = "";
const AI_AGENT_CFG_PATH = "user://ai_agent.cfg"

var game_mode: int = 0;

var game_mode2: int = 0;

var year: int = 189;

var month: int = 1;

var secret_mood: int = - 1;

var skill_cd = {};

var skill_variable = {};

var skill_range_buff: Array = []



var game_set = {};


var twinkle_citys: Array = [];

var show_orderbook = false;

var vstates_sort: Array = [];

var vstate_no: int = 0;

var control_sort: Array = [];

var control_sort_no = 0;

var orderbook: int = 0;

var player_choose_city: int = 0;

var player_choose_actor: int = 0;

var player_choose_skill: String = "";



var war_neutralors: Array = [];

var war_control_sort: Array = [];

var war_control_sort_no = 0;

var battle_run: bool = false;

var battle_actors: PoolIntArray = [];

var battle_turns = 0;

var battle_units: Array = [];

var battle_type_sort: PoolStringArray = [];

var battle_type_no: int = 0

var battle_first_sort: Array = [];

var solo_run = false;

var solo_actors: PoolIntArray = [0, 1];

var solo_sort: Array = ["左", "右"];

var solo_sort_no = 0;


var endless_mode = false;


var war_history = [];


var affair_log = []


var war_log = [];


var affair_command: DevelopCommand = null


var policy_command: PolicyCommand = null


var search_command: SearchCommand = null


var stratagem_execution: StratagemExecution = null


var solo_fight: SoloFight = null


var battle_fight: BattleFight = null


var war_fight: WarFight = null


var ske: SkillEffectInfo = null


var conditionalEquipments: Array = []

func _init() -> void :
	test_content = Global.get_file_text(get_common_path() + "save/test.txt")
	return

func _ready() -> void :
	loading_version_resource(DEFAULT_MOD_PATH)
	load_ai_agent_config()
	load_ai_agent_debug()
	return

# 修改：AI Agent 接入——调试日志开关（网页版调试用）
# 开启方式（优先级从高到低）：
#   1. 页面 URL 带 ?ai_debug=1（或 #ai_debug=1）
#   2. 浏览器控制台执行：window.__k3gAiDebug = 1
#   3. user://ai_agent_debug.txt 内容为 1
# 开启后 ai_debug_log() 会直接 print()，在 Chrome 控制台可见（不受 is_developer 限制）。
const AI_AGENT_DEBUG_PATH = "user://ai_agent_debug.txt"

var ai_debug_enabled: bool = false
var ai_debug_checked: bool = false

func is_ai_debug() -> bool:
	if ai_debug_checked:
		return ai_debug_enabled
	ai_debug_checked = true
	ai_debug_enabled = false
	if OS.has_feature("HTML5"):
		# window.__k3gAiDebug 允许运行时在控制台临时打开，无需刷新
		var flag = String(JavaScript.eval(
			"(window.__k3gAiDebug === 1 || window.__k3gAiDebug === true) ? 1 : "
			+ "((/[?#&]ai_debug=1/.test(location.href)) ? 1 : 0)",
			true))
		if flag == "1":
			ai_debug_enabled = true
	if not ai_debug_enabled:
		var text = Global.get_file_text(AI_AGENT_DEBUG_PATH)
		if text.strip_edges() == "1":
			ai_debug_enabled = true
	return ai_debug_enabled

func load_ai_agent_debug() -> void:
	ai_debug_checked = false
	return

# AI Agent 调试日志：优先走控制台可见的 print()，并带 [AI] 前缀便于筛选
func ai_debug_log(msg: String, always: bool = false) -> void:
	if not always and not is_ai_debug():
		return
	print("[AI] ", msg)
	return

# 修改：AI Agent 接入——远程服务地址的读取与保存
# 优先级：环境变量 K3G_AI_AGENT_URL > user://ai_agent.cfg > 平台默认（见 resolve_ai_agent_url）
func load_ai_agent_config() -> void:
	var env_url = OS.get_environment("K3G_AI_AGENT_URL")
	if env_url != "":
		ai_agent_base_url = env_url.strip_edges()
		return
	var text = Global.get_file_text(AI_AGENT_CFG_PATH)
	if text == "":
		return
	ai_agent_base_url = text.strip_edges()
	return

func save_ai_agent_config(url: String) -> bool:
	ai_agent_base_url = url.strip_edges()
	return Global.save_file_text(AI_AGENT_CFG_PATH, ai_agent_base_url)

# 解析出实际使用的服务地址；空配置时按平台回落到默认值。
# Web 端用当前站点（同源，天然免 CORS 预检），桌面端用本机 8060。
func resolve_ai_agent_url(path: String) -> String:
	var base = ai_agent_base_url
	if base == "":
		if OS.has_feature("HTML5"):
			var origin = String(JavaScript.eval("window.location.origin", true))
			if origin != "" and origin != "null":
				base = origin
		if base == "":
			base = "http://127.0.0.1:8060"
	base = base.strip_edges()
	if base.ends_with("/"):
		base = base.substr(0, base.length() - 1)
	return base + path

func _reset_data():
	history_version = [];
	secret_mood = - 1;
	control_sort_no = 0;
	control_sort.clear();
	vstates_alliance.clear();
	battle_run = false;
	show_orderbook = false;
	endless_mode = false;
	common_variable.clear();
	twinkle_citys.clear();
	skill_cd = {};
	skill_variable = {};
	skill_range_buff = [];
	actor_scene_skill = {};
	actor_ban_scene_skill = [];
	actor_disabled_equip_types = {}
	cur_skill_triggers = [];
	game_set = StaticManager.get_default_game_setting()
	war_history = []
	affair_log = []
	war_log = []
	affair_command = null
	policy_command = null
	search_command = null
	stratagem_execution = null
	solo_fight = null
	battle_fight = null
	war_fight = null
	ske = null
	drama_events_process = {}
	OrderHistory.history = {}
	return

func _reload_resource():
	var times_str = Global.get_file_text("user://unify_times.txt");
	self.unify_times = int(times_str)
	
	endless_mode = false;
	mod = StaticManager.get_mod_info(mod_path)
	mod_name_CN = mod["名称"];

	actors = StaticManager.actors.duplicate(true)
	citys = StaticManager.citys.duplicate(true)
	vstates = StaticManager.vstates_static.duplicate(true)

	
	weapons = _equip_static_to_runtime(StaticManager.weapons_static)
	suits = _equip_static_to_runtime(StaticManager.suits_static)
	jewelrys = _equip_static_to_runtime(StaticManager.jewelrys_static)
	steeds = _equip_static_to_runtime(StaticManager.steeds_static)

	citys_unoffice = StaticManager.citys_unoffice.duplicate(true);
	actor_follower = StaticManager.actor_follower.duplicate(true);
	year = StaticManager.get_starting_year(drama_path)
	month = StaticManager.get_starting_month(drama_path)
	
	for vs in clVState.all_vstates():
		vs.init_stored_equipments()
	game_saving_enabled = true
	return


func loading_version_resource(path: String, drama: String = "", extraEnv: Dictionary = {}):
	if path == "":
		path = DEFAULT_MOD_PATH
	grouped_trace("")
	_reset_data()
	
	common_variable = extraEnv.duplicate(true)
	grouped_trace("DM-RST")
	StaticManager.reload(path, drama)
	if mod_path != path or drama_path != drama:
		mod_path = path
		drama_path = drama
		_reload_resource()
	grouped_trace("ST-RLD")
	fix_data(true)
	grouped_trace("DM-FIX")
	
	ActorHelper.reload()
	grouped_trace("ACT-LD")
	conditionalEquipments.clear()
	
	for equip in clEquip.all_equips():
		var conditions = equip.get_attr_array("解锁条件")
		if conditions.empty():
			continue
		conditionalEquipments.append([equip.id, equip.type, conditions])
	return

func fix_data(full: bool = false):
	if full:
		
		ActorHelper.add_new_static_actors()

		
		for actor in ActorHelper.all_actors():
			actor.fix_data()

		
		clVState.fix_vstate_status()

		
		clVState.add_new_static_vstates()

		
		clVState.check_and_fix_duplicates()

	war_control_sort = _get_fix_data(war_control_sort);
	war_control_sort_no = int(war_control_sort_no);
	return


func _get_fix_data(data):
	if typeof(data) == TYPE_REAL:
		var data_int: int = int(data);
		if (data == float(data_int)):
			data = data_int;
	elif typeof(data) == TYPE_ARRAY:
		for k in data.size():
			var item = data[k];
			item = _get_fix_data(item);
			data[k] = item;
	elif typeof(data) == TYPE_DICTIONARY:
		for k in data.keys():
			var item = data[k];
			item = _get_fix_data(item);
			data[k] = item;
	return data;
	

func get_save_data() -> Dictionary:
	var save_dit = {};
	save_dit["COMPABILITY"] = COMPABILITY
	save_dit["VERSION"] = VERSION;
	save_dit["history_version"] = history_version;
	save_dit["secret_mood"] = secret_mood
	save_dit["twinkle_citys"] = twinkle_citys;
	save_dit["cityInfo_type"] = cityInfo_type;
	save_dit["show_orderbook"] = show_orderbook
	save_dit["current_scene_path"] = SceneManager.current_scene_path
	save_dit["存档时间"] = Global.get_datetime_now().to_str();
	save_dit["mod_path"] = mod_path;
	save_dit["drama_path"] = drama_path;
	
	
	var cur_skill_triggers_json = [];
	for st in cur_skill_triggers:
		if st != null:
			cur_skill_triggers_json.append(st.output_data());
	save_dit["cur_skill_triggers"] = cur_skill_triggers_json;
	
	save_dit["actors"] = actors.duplicate(true)
	save_dit["actor_scene_skill"] = actor_scene_skill.duplicate(true);
	save_dit["actor_ban_scene_skill"] = actor_ban_scene_skill.duplicate(true);
	save_dit["actor_disabled_equip_types"] = actor_disabled_equip_types.duplicate(true)
	save_dit["citys"] = citys.duplicate(true)
	save_dit["vstates"] = vstates.duplicate(true)
	save_dit["vstates_alliance"] = vstates_alliance.duplicate(true)

	save_dit["weapons"] = weapons.duplicate(true)
	save_dit["suits"] = suits.duplicate(true)
	save_dit["jewelrys"] = jewelrys.duplicate(true)
	save_dit["steeds"] = steeds.duplicate(true)

	save_dit["diffculities"] = diffculities
	# 修改：AI Agent 接入——大模型难度标记随存档持久化
	save_dit["ai_agent_mode"] = ai_agent_mode
	save_dit["year"] = year
	save_dit["month"] = month
	save_dit["vstates_sort"] = vstates_sort.duplicate(true)
	save_dit["vstate_no"] = vstate_no
	save_dit["orderbook"] = orderbook
	save_dit["player_choose_actor"] = player_choose_actor
	save_dit["skill_cd"] = skill_cd;
	save_dit["skill_variable"] = skill_variable;

	var saved_skill_range_buff = []
	for srb in skill_range_buff:
		saved_skill_range_buff.append(srb.to_string())
	save_dit["skill_range_buff"] = saved_skill_range_buff
	
	save_dit["player_choose_skill"] = player_choose_skill;
	save_dit["player_choose_city"] = player_choose_city
	save_dit["game_mode"] = game_mode
	save_dit["game_mode2"] = game_mode2
	save_dit["flows_history_list"] = FlowManager.flows_history_list.duplicate(true)
	save_dit["controlNo"] = FlowManager.controlNo
	save_dit["control_sort_no"] = control_sort_no
	save_dit["control_sort"] = control_sort.duplicate(true)
	save_dit["common_variable"] = common_variable.duplicate(true);
	save_dit["game_set"] = game_set.duplicate(true);

	save_dit["war_neutralors"] = [];
	for wa in war_neutralors:
		save_dit["war_neutralors"].append(wa.get_save_dit());
	
	save_dit["war_control_sort"] = war_control_sort.duplicate(true);
	save_dit["war_control_sort_no"] = war_control_sort_no;
	
	save_dit["battle_run"] = battle_run;
	
	save_dit["call_battle_actors"] = []
	save_dit["battle_actors"] = Array(battle_actors).duplicate(true);
	save_dit["battle_turns"] = battle_turns;
	save_dit["battle_units"] = [];
	for unit in battle_units:
		save_dit["battle_units"].append(unit.get_save_dit());
	
	save_dit["battle_type_sort"] = Array(battle_type_sort).duplicate(true);
	save_dit["battle_type_no"] = battle_type_no;
	save_dit["battle_first_sort"] = Array(battle_first_sort).duplicate(true);
	var player_arrays = [];
	for p in players:
		if (p == null):
			player_arrays.append(null);
		else:
			var dit = p.get_dit();
			player_arrays.append(dit);
	save_dit["players"] = player_arrays.duplicate(true)

	save_dit["view_model_name"] = LoadControl.view_model_name;
	save_dit["endless_model"] = endless_mode;
	save_dit["endless_data"] = EndlessGame.get_data();
	
	save_dit["debug_info"] = debug_info
	
	save_dit["war_history"] = war_history
	save_dit["affair_log"] = affair_log.duplicate(true)
	
	save_dit["war_log"] = war_log.duplicate(true)
	save_dit["affair_command"] = {}
	if affair_command != null:
		save_dit["affair_command"] = affair_command.get_save_data()
	save_dit["policy_command"] = {}
	if policy_command != null:
		save_dit["policy_command"] = policy_command.get_save_data()
	save_dit["search_command"] = {}
	if search_command != null:
		save_dit["search_command"] = search_command.get_save_data()
	save_dit["stratagem_execution"] = {}
	if stratagem_execution != null:
		save_dit["stratagem_execution"] = stratagem_execution.get_save_data()

	
	save_dit["solo_fight"] = {}
	if solo_fight != null:
		save_dit["solo_fight"] = solo_fight.get_save_data()
	save_dit["battle_fight"] = {}
	if battle_fight != null:
		save_dit["battle_fight"] = battle_fight.get_save_data()
	if war_fight != null:
		save_dit["war_fight"] = war_fight.get_save_data()
	save_dit["ske"] = {}
	if ske != null:
		save_dit["ske"] = ske.output_data()
	
	save_dit["order_history"] = OrderHistory.history.duplicate(true)
	
	save_dit["drama_events_process"] = drama_events_process
	return save_dit;

func set_save_data(_load_dit: Dictionary):
	if (_load_dit == null):
		return ;
	var load_dit = _load_dit.duplicate(true);
	var mod = load_dit["mod_path"];
	var drama = ""
	if load_dit.has("drama_path"):
		drama = str(load_dit["drama_path"])
	
	loading_version_resource(mod, drama)
	
	var version = "";
	if load_dit.has("VERSION"):
		version = load_dit["VERSION"];
	
	history_version = [];
	if load_dit.has("history_version"):
		history_version = load_dit["history_version"];
		
	if version != VERSION and not history_version.has(version):
		history_version.append(version);

	secret_mood = Global.dic_val(load_dit, "secret_mood", - 1)
	cityInfo_type = load_dit["cityInfo_type"];
	show_orderbook = bool(load_dit["show_orderbook"]);
	SceneManager.current_scene_path = load_dit["current_scene_path"];
	FlowManager.controlNo = load_dit["controlNo"];
	var list = load_dit["flows_history_list"];
	FlowManager.flows_history_list = Global.arrval(list)
	
	twinkle_citys = PoolIntArray(load_dit["twinkle_citys"]);
	actors = load_dit["actors"];

	if (load_dit.has("actor_scene_skill")):
		actor_scene_skill = load_dit["actor_scene_skill"];

	
	var jw = str(StaticManager.ACTOR_ID_JIANGWEI)
	if jw in actor_scene_skill:
		var updated = []
		for dic in actor_scene_skill[jw]:
			if Global.dic_val(dic, "skill_name", "") == "八阵":
				if Global.intval(Global.dic_val(dic, "sceneId", 0)) == 10000:
					continue
			updated.append(dic)
		actor_scene_skill[jw] = updated

	if (load_dit.has("cur_skill_triggers")):
		var cur_skill_triggers_json = load_dit["cur_skill_triggers"];
		cur_skill_triggers = [];
		for st_dic in cur_skill_triggers_json:
			if st_dic.empty():
				continue;
			var st = SkillTriggerInfo.new();
			st.input_data(st_dic)
			cur_skill_triggers.append(st);

	actor_ban_scene_skill = []
	if (load_dit.has("actor_ban_scene_skill")):
		actor_ban_scene_skill = load_dit["actor_ban_scene_skill"];

	actor_disabled_equip_types = Global.dic_val(load_dit, "actor_disabled_equip_types", {})

	citys = load_dit["citys"];
	vstates = load_dit["vstates"];
	vstates_alliance = load_dit["vstates_alliance"];

	weapons = _equip_static_to_runtime(StaticManager.weapons_static, load_dit["weapons"])
	suits = _equip_static_to_runtime(StaticManager.suits_static, load_dit["suits"])
	jewelrys = _equip_static_to_runtime(StaticManager.jewelrys_static, load_dit["jewelrys"])
	steeds = _equip_static_to_runtime(StaticManager.steeds_static, load_dit["steeds"])

	if (load_dit.has("endless_model")):
		endless_mode = load_dit["endless_model"];
		EndlessGame.set_data(load_dit["endless_data"]);
	diffculities = load_dit["diffculities"];
	# 修改：AI Agent 接入——兼容没有该字段的旧存档（默认关闭）
	ai_agent_mode = bool(load_dit["ai_agent_mode"]) if load_dit.has("ai_agent_mode") else false;
	year = int(load_dit["year"]);
	month = int(load_dit["month"]);
	vstates_sort = Array(PoolIntArray(load_dit["vstates_sort"]));
	vstate_no = int(load_dit["vstate_no"]);
	orderbook = int(load_dit["orderbook"]);
	player_choose_actor = int(load_dit["player_choose_actor"]);
	if (load_dit.has("player_choose_skill")):
		player_choose_skill = str(load_dit["player_choose_skill"])
	skill_range_buff = [];
	if (load_dit.has("skill_range_buff")):
		for row in Array(load_dit["skill_range_buff"]):
			var srb = SkillRangeBuff.new()
			srb.from_string(str(row))
			skill_range_buff.append(srb)
	if (load_dit.has("skill_cd")):
		skill_cd = load_dit["skill_cd"];
	if (load_dit.has("skill_variable")):
		skill_variable = load_dit["skill_variable"];
	player_choose_city = int(load_dit["player_choose_city"]);
	game_mode = load_dit["game_mode"];
	if (load_dit.has("game_mode2")):
		game_mode2 = load_dit["game_mode2"];
	else:
		game_mode2 = 0;
	control_sort_no = load_dit["control_sort_no"];
	control_sort = Array(PoolIntArray(load_dit["control_sort"]));
	common_variable = load_dit["common_variable"];

	
	game_set = StaticManager.get_default_game_setting()
	var loaded_game_set = Global.dic_val(load_dit, "game_set", {})
	for key in game_set:
		if key in loaded_game_set:
			game_set[key] = loaded_game_set[key]

	
	if "war_vstate" in load_dit:
		set_env("war_vstate", Global.arrval(load_dit["war_vstate"]))
	if "war_actors" in load_dit:
		set_env("war_actors", Global.arrval(load_dit["war_actors"]))
	war_neutralors.clear();
	if load_dit.has("war_neutralors"):
		var data_war_neutralors = Array(load_dit["war_neutralors"]);
		for data in data_war_neutralors:
			var wa = War_Neutralor.new();
			wa.set_save_dit(data);
			war_neutralors.append(wa);

	war_control_sort = Array(PoolIntArray(load_dit["war_control_sort"]));
	war_control_sort_no = int(load_dit["war_control_sort_no"]);
	
	if "war_run" in load_dit:
		if Global.boolval(load_dit["war_run"]):
			set_env("war_run", 1)
	if "war_sort_no" in load_dit:
		set_env("war_sort_no", int(load_dit["war_sort_no"]))
	if "war_day" in load_dit:
		set_env("war_day", int(load_dit["war_day"]))

	battle_run = load_dit["battle_run"];
	battle_actors = PoolIntArray(load_dit["battle_actors"]);
	battle_turns = int(load_dit["battle_turns"]);
	var data_battle_units = Array(load_dit["battle_units"]);
	battle_units.clear();
	for data in data_battle_units:
		var bu = Battle_Unit.new( - 1)
		bu.set_save_dit(data)
		battle_units.append(bu)
	
	battle_type_sort = Array(load_dit["battle_type_sort"]).duplicate(true);
	battle_type_no = int(load_dit["battle_type_no"]);
	battle_first_sort = Array(load_dit["battle_first_sort"]).duplicate(true);
	
	var player_arrays = load_dit["players"];
	players = [];
	for dit in player_arrays:
		var p: Player = Player.new();
		p.set_dit(dit);
		players.append(p);

	
	if load_dit.has("solo_run"):
		solo_run = load_dit["solo_run"]
		solo_actors = Global.intarrval(load_dit["solo_actors"])
		solo_sort = Global.arrval(load_dit["solo_sort"])
		solo_sort_no = Global.intval(load_dit["solo_sort_no"])

	if (load_dit.has("view_model_name")):
		LoadControl.view_model_name = str(load_dit["view_model_name"]);
		
	
	if load_dit.has("war_history"):
		war_history = Global.arrval(load_dit["war_history"])
	affair_log = []
	if load_dit.has("affair_log"):
		affair_log = Global.arrval(load_dit["affair_log"])
	war_log = []
	if load_dit.has("war_log"):
		war_log = Global.arrval(load_dit["war_log"])
	affair_command = null
	if load_dit.has("affair_command"):
		var dic = Global.dicval(load_dit["affair_command"])
		if not dic.empty():
			affair_command = DevelopCommand.new("", - 1)
			affair_command.load_from_save_data(dic)
	policy_command = null
	if load_dit.has("policy_command"):
		var dic = Global.dicval(load_dit["policy_command"])
		if not dic.empty():
			policy_command = PolicyCommand.new("", - 1)
			policy_command.load_from_save_data(dic)
	search_command = null
	if load_dit.has("search_command"):
		var dic = Global.dicval(load_dit["search_command"])
		if not dic.empty():
			search_command = SearchCommand.new( - 1, - 1)
			search_command.load_from_save_data(dic)
	
	stratagem_execution = null
	if load_dit.has("stratagem_execution"):
		var dic = Global.dicval(load_dit["stratagem_execution"])
		if not dic.empty():
			stratagem_execution = StratagemExecution.new( - 1, "")
			stratagem_execution.load_from_save_data(dic)
	solo_fight = null
	if load_dit.has("solo_fight"):
		var dic = Global.dicval(load_dit["solo_fight"])
		if not dic.empty():
			solo_fight = SoloFight.new( - 1, - 1)
			solo_fight.load_from_save_data(dic)
	battle_fight = null
	if load_dit.has("battle_fight"):
		var dic = Global.dicval(load_dit["battle_fight"])
		if not dic.empty():
			battle_fight = BattleFight.new( - 1)
			battle_fight.load_from_save_data(dic)
	ske = SkillEffectInfo.new()
	if load_dit.has("ske"):
		var dic = Global.dicval(load_dit["ske"])
		ske.input_data(dic)
	
	OrderHistory.history = {}
	if load_dit.has("order_history"):
		OrderHistory.history = Global.dicval(load_dit["order_history"])
	
	drama_events_process = {}
	if load_dit.has("drama_events_process"):
		drama_events_process = Global.dicval(load_dit["drama_events_process"])

	
	war_fight = null
	if load_dit.has("war_fight"):
		var dic = Global.dicval(load_dit["war_fight"])
		if not dic.empty():
			war_fight = WarFight.new( - 1, - 1)
			war_fight.load_from_save_data(dic)
	if war_fight == null:
		
		war_fight = DataManager.get_current_war_fight()

	fix_data(true);
	
	ActorHelper.reload()
	return

func set_playerNo_actor(playerNo: int, player: Player):
	players[playerNo] = player
	

func get_city_num_by_vstate(vstateId: int, excludeDelegated: bool = false) -> int:
	var ret = 0
	for city in clCity.all_cities([vstateId]):
		if excludeDelegated and city.is_delegated():
			continue
		ret += 1
	return ret


func get_office_city_by_actor(actorId: int) -> clCity.CityInfo:
	var actor = ActorHelper.actor(actorId)
	if not actor.is_status_officed():
		return null
	var cityId = actor._get_attr_int("所在城")
	if cityId >= 0:
		var city = clCity.city(cityId)
		if actorId in city.get_actor_ids():
			return city
	for city in clCity.all_cities():
		if actorId in city.get_actor_ids():
			actor._set_attr("所在城", city.ID)
			return city
	return null


func get_actor_at_cityId(actorId) -> int:
	var actor = ActorHelper.actor(actorId)
	if actor.is_status_dead():
		return actor.get_exiled_city_id()
	if actor.is_status_exiled():
		return actor.get_exiled_city_id()
	if actor.is_status_secluded():
		return actor.get_exiled_city_id()
	if actor.is_status_officed():
		var city = get_office_city_by_actor(actorId)
		if city != null:
			return city.ID
	
	for sett in DataManager.actor_follower:
		if int(sett["子将"]) != actorId:
			continue
		var t_parent = int(sett["父将"])
		return get_actor_at_cityId(t_parent)
	
	for dit in DataManager.citys_unoffice:
		if int(dit["武将"]) == actorId:
			return int(dit["城池"])
	return clCity.random_city_id()

func get_actor_controlNo(actorId: int):
	var pno = - 1;
	for p in DataManager.players:
		pno += 1;
		if (p == null):
			continue;
		if (p.actorId != int(actorId)):
			continue;
		return pno;
	return - 1;


func get_scene_actor_control(actorId: int):
	
	if DataManager.get_current_scene_id() >= 20000:
		var wf = DataManager.get_current_war_fight()
		for wv in wf.war_vstates():
			if wv.has_actor(actorId):
				return wv.get_main_controlNo()
	var pno = get_actor_controlNo(actorId);
	if pno >= 0:
		return pno
	
	var city = get_office_city_by_actor(actorId)
	if city == null:
		
		return - 1
	return get_actor_controlNo(city.get_lord_id())


func get_actor_max_soldiers(actorId: int):
	if actorId < 0:
		return 1000
	var actor = ActorHelper.actor(actorId)
	var ret = get_actor_max_soldiers_no_skill(actorId)
	if is_special_version_for("慕容"):
		match actor.get_level():
			5:
				return 3000
			6:
				return 4000
			7:
				return 5500
			8:
				return 8000
	
	var most = SkillRangeBuff.min_val_for_actor("士兵上限至多", actorId)
	if most > 0:
		return most
	var least = SkillRangeBuff.max_val_for_actor("士兵上限至少", actorId)
	if least > 0:
		ret = max(least, ret)
	for srb in SkillRangeBuff.find_for_actor("士兵上限额外", actorId):
		ret += srb.effectTagVal
	
	
	if DataManager.endless_mode:
		if EndlessGame.player_actors.size() > 0 and actorId == EndlessGame.player_actors[0]:
			ret = max(2500, ret)
	ret = min(3000, ret)
	
	var city = DataManager.get_office_city_by_actor(actorId)
	var vstateId = - 1
	if city != null:
		vstateId = city.get_vstate_id()
	if DataManager.get_current_scene_id() >= 20000:
		
		var wa = DataManager.get_war_actor(actorId)
		if wa != null:
			var wv = wa.war_vstate()
			if wv != null:
				vstateId = wv.vstate().id
	if vstateId < 0:
		return ret
	var kingId = clVState.vstate(vstateId).get_lord_id()
	if kingId < 0:
		return ret
	if kingId == actorId:
		return ret
	
	if ret < 2500\
	and SkillRangeBuff.max_val_for_actor("权付", actorId) > 0:
		var cityCount = DataManager.get_city_num_by_vstate(vstateId)
		if cityCount == 1:
			ret = max(ret, get_actor_max_soldiers(kingId))
	if ret < 2500\
	and actor.get_power() >= 99\
	and SkillRangeBuff.max_val_for_actor("饲虎", kingId) > 0:
		ret = max(ret, get_actor_max_soldiers(kingId))
	if ret >= 2000:
		
		return ret
	if SkillRangeBuff.max_val_for_actor("望族", kingId) > 0:
		var cityCount = DataManager.get_city_num_by_vstate(vstateId)
		ret = min(2000, ret + 50 * cityCount)
	return ret

func get_actor_max_soldiers_no_skill(actorId: int):
	if actorId < 0:
		return 1000
	var actor = ActorHelper.actor(actorId)
	if actor.get_loyalty() == 100:
		
		return 2500
	var ret = 1000 + actor.get_leadership() * 10
	ret = max(ret, actor.get_equip_feature_max("兵力上限"))
	var city = get_office_city_by_actor(actorId)
	if city == null:
		return ret
	var cityActors = city.get_actor_ids()
	if cityActors.empty() or cityActors[0] == actorId:
		return ret
	var leader = city.get_leader()
	if leader.get_equip_feature_max("影响全城征兵") > 0:
		ret = max(1000 + leader.get_leadership() * 10, ret)
	return ret


func get_direction_by_city_AtoB(city_A: int, city_B: int) -> float:
	var A = clCity.city(city_A);
	var B = clCity.city(city_B);
	
	var AtoB = B.get_location() - A.get_location()
	
	var dk = cartesian2polar(AtoB.x, - AtoB.y);
	var rad = round(rad2deg(dk.y) * 10) / 10.0;
	if (rad < 0):
		rad = 360.0 + rad;
	
	while (rad >= 360.0):
		rad -= 360.0;
		
	return rad;

func get_war_npc(npcId: int) -> War_Neutralor:
	for wn in war_neutralors:
		if (wn.npcId == npcId):
			return wn;
	return null;

func get_war_actor(actorId: int) -> War_Actor:
	var wf = get_current_war_fight()
	for wv in wf.war_vstates():
		for wa in wv.warActors:
			if wa.actorId == actorId:
				return wa
	return null

func get_war_actor_by_position(position: Vector2, excepted: PoolIntArray = []) -> War_Actor:
	var wf = get_current_war_fight()
	for wa in wf.get_war_actors(false, true):
		if wa.position != position:
			continue
		if wa.actorId in excepted:
			continue
		return wa
	return null



func get_move_cost(actorId: int, pos: Vector2, considerSkill: bool = true) -> Dictionary:
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return {"机": 99, "点": 99}
	var troopsType = wa.actor().get_troops_type()
	if troopsType == "仙":
		return {"机": 0, "点": 1}
	var map = SceneManager.current_scene().war_map
	var move_cost_AP_set = StaticManager.get_move_ap_setting()
	var terrian = map.get_blockCN_by_position(pos)
	var b_index = 0
	if wa.actor().get_soldiers() <= 500:
		b_index = 1
	if not terrian in move_cost_AP_set:
		terrian = "平原"
	var costAP = move_cost_AP_set[terrian][troopsType][b_index]
	for expectedType in ["平", "山", "水"]:
		if troopsType != expectedType and wa.actor().get_equip_feature_max(expectedType + "军移动") > 0:
			costAP = min(costAP, move_cost_AP_set[terrian][expectedType][b_index])
	if wa.get_buff_label_turn(["迟滞"]) > 0:
		costAP += 2
	if wa.get_buff_label_turn(["潜行"]) > 0:
		costAP = max(1, costAP - 1)
	DataManager.set_env("行军目标", {"x": pos.x, "y": pos.y})
	DataManager.set_env("行军消耗机动力", costAP)
	DataManager.set_env("行军地形", terrian)
	SkillHelper.auto_trigger_skill(actorId, 20007, "")
	costAP = DataManager.get_env_int("行军消耗机动力")

	return {"机": costAP, "点": 0}


func battle_unit_type_hp(actorId: int, type_name: String) -> float:
	var total_hp = 0;
	for i in battle_units.size():
		var bu: Battle_Unit = battle_units[i];
		if (bu.disabled):
			continue;
		if (bu.leaderId != actorId):
			continue;
		if (bu.get_unit_type() != type_name):
			continue;
		total_hp += bu.get_hp();
	return total_hp;

func data_all_clear():
	DataManager.mod_path = "";
	DataManager.drama_path = "";
	LoadControl.end_script();
	SceneManager.load_scene_complete = true;
	DataManager.common_variable.clear();
	SceneManager.hide_all_tool();
	SoundManager.stop();
	DataManager._ready();
	return


func get_battle_unit_by_position(position: Vector2) -> Battle_Unit:
	for unit in DataManager.battle_units:
		if (unit.disabled):
			continue;
		
		if int(round(unit.unit_position.x)) == position.x\
		and int(round(unit.unit_position.y)) == position.y:
			return unit;
	return null






func war_damage_hp(fromId: int, targetId: int, damage: int) -> int:
	if damage <= 0:
		return 0
	var target = DataManager.get_war_actor(targetId)
	if target == null:
		return 0
	target.actor().set_hp(target.actor().get_hp() - damage)
	if get_current_scene_id() == 20000:
		emit_signal("hp_damaged", targetId, damage)
	return damage








func damage_sodiers(fromId: int, targetId: int, damage: int, expFactor: int = 1) -> int:
	if damage <= 0:
		return 0
	
	var target = DataManager.get_war_actor(targetId)
	if target == null:
		return 0
	var current = target.actor().get_soldiers()
	damage = min(damage, current)
	if damage <= 0:
		return 0
	target.actor().set_soldiers(current - damage)
	if get_current_scene_id() == 20000:
		emit_signal("soldier_damaged", targetId, damage)
	
	var wv = target.war_vstate()
	if wv != null:
		wv._lose_sodiers += damage
	
	var from = DataManager.get_war_actor(fromId)
	if from != null:
		if DataManager.get_current_scene_id() == 20000:
			expFactor = max(expFactor, SkillRangeBuff.max_val_for_actor("大战场经验倍率", fromId))
		var expGain = int(damage * expFactor)
		if from.vstate().id == target.vstate().id:
			expGain = - abs(expGain)
		actor_add_Exp(from.actorId, expGain)
	return damage



func actor_add_Exp(actorId: int, expVal: int, teamExp: bool = true):
	if DataManager.is_special_version_for("慕容"):
		teamExp = false
	expVal = int(expVal * get_war_actor_exp_rate(actorId))
	var wa = DataManager.get_war_actor(actorId)
	var actor = ActorHelper.actor(actorId)
	if DataManager.get_current_scene_id() < 20000:
		teamExp = false
	if wa == null:
		teamExp = false
	if teamExp:
		
		for srb in SkillRangeBuff.find_for_war_vstate("抢夺经验", wa.wvId):
			var robber = DataManager.get_war_actor(srb.actorId)
			if robber == null or robber.disabled:
				continue
			
			actor = robber.actor()
			
			
			var paiyiEffectId = 20451
			var accumulated = SkillHelper.get_skill_variable_int(20000, paiyiEffectId, robber.actorId, 0)
			accumulated += expVal
			SkillHelper.set_skill_variable(20000, paiyiEffectId, robber.actorId, accumulated, 99999)
			var info = "- <y{0}>【<r{1}>】抢夺经验".format([
				robber.get_name(), srb.skillName, 
			])
			DataManager.record_war_log(info)
			
			break
	else:
		
		if wa != null:
			for b in wa.get_buffs_with_label(["截夺团队经验"]):
				var robberId = Global.intval(b["来源武将"])
				if robberId < 0:
					continue
				var robber = DataManager.get_war_actor(robberId)
				if robber == null or robber.disabled:
					continue
				
				actor = robber.actor()
				break
	actor.add_exp(expVal)
	
	if teamExp:
		teammate_add_Exp(actor.actorId, expVal)

	if actor.get_equip_feature_max("避免升级") > 0:
		return
	
	var levelUps = actor.check_levelup()
	if not levelUps.empty():
		SkillHelper.update_all_skill_buff("ActorLevelup")
	return




func get_war_actor_exp_rate(actorId: int) -> float:
	var rate = 1.0
	if DataManager.get_current_scene_id() < 20000:
		return rate
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return rate
	var leader = wa.get_leader()
	if leader == null or leader.disabled:
		return rate
	if ActorHelper.actor(actorId).get_level() < 8:
		return rate
	if not SkillHelper.actor_has_skills(leader.actorId, ["赋诗"]):
		return rate
	rate = 1.1
	return rate



func teammate_add_Exp(actorId: int, expVal: int):
	if DataManager.get_current_scene_id() < 20000:
		return
	var me = DataManager.get_war_actor(actorId)
	if me == null or me.disabled:
		return

	
	var leader = me.get_leader()
	
	var teamExpRate: float = 0.125
	if leader != null:
		teamExpRate += leader.actor().get_equip_feature_total("团队经验加成") / 100.0
		teamExpRate += leader.get_ext_variable("团队经验加成", 0.0)
	teamExpRate += SkillRangeBuff.max_val_for_war_vstate("团队经验加成", me.wvId) / 100.0
	var wf = DataManager.get_current_war_fight()
	for wa in wf.get_war_actors(false):
		
		if me.actorId == wa.actorId:
			continue
		if SkillHelper.actor_has_skills(wa.actorId, ["损蓄"]):
			
			continue
		if not me.is_teammate(wa):
			
			if not SkillHelper.actor_has_skills(wa.actorId, ["观照"]):
				continue
		var teammateExp = int(expVal * teamExpRate)
		var personalExtraRate = SkillRangeBuff.max_val_for_actor("团队经验个人加成", wa.actorId, 0)
		if personalExtraRate > 0:
			teammateExp = int(expVal * (teamExpRate + personalExtraRate / 100.0))
		actor_add_Exp(wa.actorId, teammateExp, false)
	var wv = me.war_vstate()
	if wv != null:
		for campActorId in wv.camp_actors:
			if SkillHelper.actor_has_skills(campActorId, ["如临"], false):
				var teammateExp = int(expVal * teamExpRate)
				var personalExtraRate = SkillRangeBuff.max_val_for_actor("团队经验个人加成", campActorId, 0)
				if personalExtraRate > 0:
					teammateExp = int(expVal * teamExpRate + personalExtraRate / 100.0)
				actor_add_Exp(campActorId, teammateExp, false)
	return


func is_developer_at_work() -> bool:
	return false
	if not is_developer():
		return false
	var time = Time.get_time_dict_from_system()
	var date = Time.get_date_dict_from_system()
	var weekday = int(date["weekday"])
	if weekday in [0, 6]:
		return false
	var hour = time["hour"]
	if hour < 10 or hour > 19:
		return false
	return true


func is_developer() -> bool:
	if test_player_flag == - 1:
		if test_content == "":
			test_player_flag = - 2
			return false
		test_player_flag = int(test_content.split("\n")[0])
		if test_player_flag > 1:
			if not Global.file_exists("resource/data/bwdl.key.json"):
				test_player_flag = 1
		test_player_specials = {}
		if get_test_player_content("慕容") == "1":
			test_player_specials["慕容"] = 1
	return test_player_flag > 1


func is_special_version_for(key: String) -> bool:
	return key in test_player_specials and test_player_specials[key] == 1


func is_beta_version() -> bool:
	return VERSION != DISPLAY_VERSION


func is_test_player() -> bool:
	if is_developer():
		return true
	return test_player_flag == 1

func get_test_player_content(key: String) -> String:
	if not is_test_player():
		return "";
	var key_ecal = "{0}=".format([key]);
	if not key_ecal in test_content:
		return "";
	for _str in test_content.split("\n"):
		if not str(_str).begins_with(key_ecal):
			continue
		
		return _str.replace(key_ecal, "");
	return ""


func check_exists_Actors_BUG():
	if not is_test_player():
		return

	var common_bug_path = DataManager.get_common_path() + "save/bug.txt"

	var sb = StringBuilder.new()
	for actor in ActorHelper.all_actors():
		var liveCity = get_office_city_by_actor(actor.actorId)
		if actor.is_status_officed():
			if liveCity == null:
				sb.append("出仕武将【{0}】#{1}没在任何城中\n".format([
					actor.get_name(), actor.actorId
				]))
		elif liveCity != null:
			sb.append("{0}武将【{1}】#{2}在城【{3}】\n".format([
				actor.get_status(), actor.get_name(), actor.actorId, 
				liveCity.get_name(), 
			]));
	var dic: Dictionary = {};
	for city in clCity.all_cities():
		if city.get_vstate_id() < 0:
			if city.get_actors_count() > 0:
				sb.append("空城【{0}】#{1}里存在武将！\n".format([
					city.get_name(), city.ID
				]))
				continue
		else:
			var actorIds = city.get_actor_ids()
			if actorIds.empty():
				sb.append("城池【{0}】#{1}里不存在武将！\n".format([
					city.get_name(), city.ID, 
				]))
				continue
			var satrap = ActorHelper.actor(actorIds[0])
			if satrap.get_loyalty() < 100:
				for actorId in actorIds:
					var actor = ActorHelper.actor(actorId)
					if actor.get_loyalty() >= 100:
						sb.append("城池【{0}】#{1}中君主{2}#{3}不是太守！\n".format([
							city.get_name(), city.ID, 
							actor.get_name(), actor.actorId, 
						]))
		for key in ["武将", "监狱"]:
			var rawActorsData = city.get_property(key)
			if rawActorsData == null:
				continue
			if typeof(rawActorsData) != TYPE_ARRAY:
				sb.append("城池【{0}】#{1}的{2}数据不是数组！\n".format([
					city.get_name(), city.ID, key
				]))
				continue
			for id in rawActorsData:
				if not typeof(id) in [TYPE_REAL, TYPE_INT]:
					sb.append("城池【{0}】#{1}里{2}ID【{3}】类型不是INT！\n".format([
						city.get_name(), city.ID, key, id
					]))
					continue
				if not id in dic:
					dic[id] = city.ID
				else:
					sb.append("武将【{0}】#{1}存在复制情况，于城池ID【{2}】#{3}和【{4}】#{5}中同时存在！\n".format([
						ActorHelper.actor(id).get_name(), id, 
						clCity.city(dic[id]).get_name(), dic[id], 
						city.get_name(), city.ID, 
					]))
	if ( not sb.empty()):
		SceneManager.get_node("Virtukey/VirtualKey/lblPlayerNo").text = "当前存在BUG，请上传存档目录下的bug.txt";
		var pre_text = Global.get_file_text(common_bug_path);
		var new_text = sb.to_string();
		if (new_text in pre_text):
			return ;
		Global.save_file_text(common_bug_path, pre_text + "\n" + new_text);
		auto_save("bug")
	return


func get_fix_v_rate(basicRate: int, fixKey: String):
	var extraRate = 0
	var total = 0
	var succeeded = 0
	for n in DataManager.get_env_int_array(fixKey):
		total += 1
		if n > 0:
			succeeded += 1
	var realRate = int(succeeded * 100 / max(1, total))
	if realRate < basicRate:
		extraRate = max(10, (basicRate - realRate) * succeeded / 3)
	var ret = basicRate + extraRate
	ret = min(95, ret)
	return ret


func set_fix_rate_v(fixKey: String, success: bool):
	var history = DataManager.get_env_int_array(fixKey)
	history.append(1 if success else 0)
	DataManager.set_env(fixKey, history)
	return


func clear_common_variable(prename: PoolStringArray):
	for key in DataManager.common_variable.keys():
		for n in prename:
			if (str(key).begins_with(n)):
				DataManager.common_variable.erase(key);
				break;

func get_common_path():
	var common_save_path = "";
	var player_machine_name = OS.get_name();
	if player_machine_name == "Android":
		common_save_path = OS.get_system_dir(0) + "/sgz/";
	elif player_machine_name == "HTML5":
		# 网页版没有可执行文件目录：web 平台 get_executable_path() 拿不到真实路径
		#（实测返回页面名，如 index），拼出来的 "index/sgz/" 只是浏览器内存文件系统，刷新即丢。
		# 改用 user://，Godot 3 web 会把它映射到 IDBFS(/userfs)，持久化进浏览器 IndexedDB。
		common_save_path = "user://sgz/";
	else:
		common_save_path = OS.get_executable_path();
		var index = common_save_path.find_last("/");
		common_save_path = common_save_path.substr(0, index);
		common_save_path += "/sgz/";
	return common_save_path







func game_trace(method_name: String = "", addingToDebug: bool = false, force: bool = false):
	if not force and not DataManager.is_developer():
		return
	var time = Time.get_ticks_usec();
	var use_time = time - DataManager.last_trace_time
	if method_name != "":
		var msec = " ".repeat(5) + str(int(use_time / 1000.0))
		msec = msec.substr(msec.length() - 6)
		Global.log("{1} msec. {0}".format([method_name, msec]))
	DataManager.last_trace_time = time
	return

func grouped_trace_reset() -> void :
	first_grouped_trace = Time.get_ticks_usec()
	grouped_trace_dic.clear()
	grouped_trace("")
	return

func grouped_trace(key: String = "") -> void :
	var last = last_grouped_trace
	last_grouped_trace = Time.get_ticks_usec()
	var elapsed = last_grouped_trace - last
	if key == "":
		return
	if not key in grouped_trace_dic:
		grouped_trace_dic[key] = [0, 0, 0]
	grouped_trace_dic[key][0] += elapsed
	grouped_trace_dic[key][1] += 1
	grouped_trace_dic[key][2] = max(int(grouped_trace_dic[key][2]), elapsed)
	return

func grouped_trace_output(record: bool = false, memo: String = "") -> Dictionary:
	var ret = {}
	var msg = "\n[" + memo + "] 分组用时统计：\n|       key       |  times  |  msec  |   avg  |   max  |"
	var keys = grouped_trace_dic.keys()
	keys.sort()
	
	last_grouped_trace = first_grouped_trace
	grouped_trace("TOTAL")
	keys.append("TOTAL")
	for key in keys:
		var msec = int(grouped_trace_dic[key][0] / 1000.0)
		var times = grouped_trace_dic[key][1]
		var avg = int(grouped_trace_dic[key][0] / times / 1000.0)
		var maxVal = int(grouped_trace_dic[key][2] / 1000.0)
		ret[key] = {
			"msec": msec, 
			"times": times, 
			"avg": avg, 
			"max": maxVal, 
		}
		msg += "\n|  {0}   |  {1}  |  {2}  |  {3}  |  {4}  |".format([
			_pad(key, 12, false, true), _pad(times, 5), 
			_pad(msec, 4), _pad(avg, 4), _pad(maxVal, 4), 
		])
	Global.log(msg)
	if record:
		debug_info = ret
	grouped_trace_reset()
	return ret

static func get_actor_self_title(actorId: int) -> String:
	var title = StaticManager.get_actor_self_title(actorId)
	if not title.empty():
		return title
	var actor = ActorHelper.actor(actorId)
	if actor.get_gender() == "女":
		return "妾"
	return actor.get_short_name()

static func get_actor_honored_title(actorId: int, fromId: int = - 1) -> String:
	if actorId == fromId:
		return "吾"
	if fromId >= 0:
		var ret = StaticManager.get_actor_honored_title(actorId, fromId)
		if ret != "":
			return ret
	var actor = ActorHelper.actor(actorId)
	if actor.get_loyalty() == 100:
		if DataManager.get_current_scene_id() >= 20000:
			
			var me = DataManager.get_war_actor(fromId)
			if me != null and me.get_lord_id() == actorId:
				return "主公"
		else:
			
			var city = DataManager.get_office_city_by_actor(fromId)
			if city != null and city.get_lord_id() == actorId:
				return "主公"
	var name = actor.get_name()
	var nick = actor.get_nick()
	if nick.empty():
		if name.length() > 2:
			name = actor.get_first_name()
		return name + "将军"
	return nick

static func get_actor_naughty_title(actorId: int, fromId: int = - 1) -> String:
	if fromId >= 0:
		var ret = StaticManager.get_actor_naughty_title(actorId, fromId)
		if ret != "":
			return ret
	var actor = ActorHelper.actor(actorId)
	var name = actor.get_name()
	var nick = actor.get_nick()
	if nick.empty():
		if actor.get_gender() == "女":
			return name + "贼妇"
		if actor.get_wisdom() > actor.get_power():
			return name + "小儿"
		else:
			return name + "匹夫"
	if name.length() > 2:
		return actor.get_first_name() + nick
	return name.left(1) + nick

static func get_city_rice_price(cityId: int, selling: bool = false) -> int:
	var city = clCity.city(cityId)
	var price = city.get_rice_buy_price()
	if selling:
		price = city.get_rice_sell_price()
	price = max(price, SkillRangeBuff.max_val_for_city("米价", cityId))
	return price

static func vector_to_string(vec: Vector2) -> String:
	return "{0}|{1}".format([vec.x, vec.y])

static func vector_from_string(s: String) -> Vector2:
	var pieces = s.split("|")
	if pieces.size() != 2:
		return Vector2.ZERO
	return Vector2(int(pieces[0]), int(pieces[1]))

func set_target_position(pos: Vector2) -> void :
	common_variable["目标位置"] = vector_to_string(pos)

func get_target_position() -> Vector2:
	if not common_variable.has("目标位置"):
		return Vector2( - 1, - 1);
	var posInfo = common_variable["目标位置"]
	if typeof(posInfo) == TYPE_DICTIONARY:
		return Vector2(int(posInfo["x"]), int(posInfo["y"]))
	return vector_from_string(str(posInfo))

func save_game_data(name: String) -> String:
	var path = get_common_path() + "save/" + name + ".sav"
	var save_data = get_save_data()
	var save_json: String
	if is_test_player():
		save_json = JSON.print(save_data, "\t")
	else:
		save_json = to_json(save_data)
	
	Global.save_file_text(path, save_json)
	StaticManager.saveIdx.update_save_index(name)
	return path

static func read_game_data_str(path: String) -> String:
	return Global.get_file_text(path)



static func lord_change(vstateId: int, newLordId: int) -> int:
	var oldVstateId = vstateId
	var oldVS = clVState.vstate(oldVstateId)
	
	for vs in clVState.all_vstates():
		if not vs.is_perished():
			continue
		
		if vs.get_lord_id() == newLordId:
			vstateId = vs.id
			break
	var newVS = clVState.vstate(vstateId)
	newVS.set_lord(newLordId)
	newVS.set_alive()
	
	
	if oldVstateId != vstateId:
		
		oldVS.set_perished()
		
		var index1 = DataManager.vstates_sort.find(oldVstateId)
		var index2 = DataManager.vstates_sort.find(vstateId)
		if index1 >= 0:
			DataManager.vstates_sort[index1] = vstateId
		if index2 >= 0:
			DataManager.vstates_sort[index2] = oldVstateId

		
		newVS.rob_all_stored_equipments(oldVstateId)

		
		for city in clCity.all_cities([oldVstateId]):
			city.set_vstate_id(vstateId)
	return vstateId


static func get_max_property_actorId(prop: String, vstateId: int, except: PoolIntArray = []):
	var maxVal = 0
	var ret = - 1
	for city in clCity.all_cities([vstateId]):
		for actorId in city.get_actor_ids():
			if actorId == city.get_lord_id():
				
				continue
			if actorId in except:
				
				continue
			var actor = ActorHelper.actor(actorId)
			if actor._get_attr_int(prop) > maxVal:
				maxVal = actor._get_attr_int(prop)
				ret = actorId
	return ret


func record_war_history(fromCity: clCity.CityInfo, targetCity: clCity.CityInfo) -> void :
	
	
	var renewed_history = []
	var currentTiming = DataManager.year * 12 + DataManager.month
	for row in war_history:
		if row.size() < 7:
			continue
		var timing = row[0] * 12 + row[1]
		if timing <= currentTiming - 3:
			continue
		renewed_history.append(row)
	var row = [
		DataManager.year, DataManager.month, 
		fromCity.get_vstate_id(), 
		fromCity.ID, targetCity.ID, 
		fromCity.get_vstate_id(), targetCity.get_vstate_id()
	]
	renewed_history.append(row)
	war_history = renewed_history
	return

func get_war_times(vstateId: int) -> int:
	var ret = 0
	for row in war_history:
		if int(row[0]) != year:
			continue
		if int(row[1]) != month:
			continue
		if int(row[5]) != vstateId:
			continue
		ret += 1
	return ret


func reset_affair_log() -> void :
	affair_log = []
	return


func record_affair_log(info: String, appendToLast: bool = false) -> void :
	if appendToLast and affair_log.size() > 0:
		affair_log[affair_log.size() - 1] += "\n" + info
		return
	affair_log.append(info)
	if affair_log.size() > 200:
		var from = affair_log.size() - 100
		var to = affair_log.size() - 1
		affair_log = affair_log.slice(from, to)
	return


func reset_war_log() -> void :
	war_log = []
	return


func record_war_log(info: String) -> void :
	war_log.append(info)
	return



func get_trace_id() -> int:
	
	return Time.get_ticks_usec()


func is_autoplay_mode() -> bool:
	for p in players:
		if p.actorId >= 0:
			return false
	return true


func clear_actor_buffs(actorId: int) -> void :
	var updated = []
	for srb in skill_range_buff:
		if srb.actorId == actorId:
			continue
		updated.append(srb)
	skill_range_buff = updated
	return



var pseudo_random_generator = RandomNumberGenerator.new()

func pseduo_random_war(rng: int = 100) -> int:
	var wf = DataManager.get_current_war_fight()
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for wa in wf.get_war_actors(false, true):
		ctx.update(JSON.print(wa.get_save_dit()).to_utf8())
	ctx.update(JSON.print(DataManager.skill_variable).to_utf8())
	var res = ctx.finish()
	var seeding = 0
	for i in 3:
		seeding = seeding * 256
		seeding += res[i]
	pseudo_random_generator.set_seed(seeding)
	return pseudo_random_generator.randi() % rng



static func get_current_scene_id() -> int:
	var scene = SceneManager.current_scene()
	if scene == null:
		return - 1
	return scene.SCENE_ID

func new_stratagem_execution(fromId: int, stratagemName: String, skill: String = "") -> StratagemExecution:
	
	
	
	var prev = DataManager.get_current_stratagem_execution()
	if prev.fromId >= 0 and prev.name != "":
		prev.report()
	stratagem_execution = StratagemExecution.new(fromId, stratagemName, skill)
	return stratagem_execution


func get_current_stratagem_execution() -> StratagemExecution:
	if stratagem_execution == null:
		
		var se = StratagemExecution.new( - 1, "")
		se.rebuild_from_env()
		stratagem_execution = se
	return stratagem_execution


func save_stratagem_execution(key: String) -> void :
	set_env(key, stratagem_execution.get_save_data())
	return


func recover_stratagem_execution(key: String) -> void :
	var se = StratagemExecution.new( - 1, "")
	se.load_from_save_data(get_env_dict(key))
	stratagem_execution = se
	return


func new_war_fight(fromCityId: int, targetCityId: int) -> WarFight:
	var prev = DataManager.get_current_war_fight()
	var wf = WarFight.new(fromCityId, targetCityId)
	
	for srb in SkillRangeBuff.find_for_vstate("撤退收容", wf.from_city().get_vstate_id()):
		var c = DataManager.get_office_city_by_actor(srb.actorId)
		if c == null:
			continue
		var extraExtractions = wf.get_env_int_array("额外可撤退城市")
		extraExtractions.erase(c.ID)
		extraExtractions.append(c.ID)
		wf.set_env("额外可撤退城市", extraExtractions)
	
	for srb in SkillRangeBuff.find_for_vstate("撤退收容", wf.target_city().get_vstate_id()):
		var c = DataManager.get_office_city_by_actor(srb.actorId)
		if c == null:
			continue
		var extraExtractions = wf.get_env_int_array("额外可撤退城市")
		extraExtractions.erase(c.ID)
		extraExtractions.append(c.ID)
		wf.set_env("额外可撤退城市", extraExtractions)
	
	war_fight = wf
	return war_fight

func get_current_war_fight() -> WarFight:
	if war_fight == null:
		
		var wf = WarFight.new( - 1, - 1)
		wf.rebuild_from_env()
		war_fight = wf
	return war_fight


func new_battle_fight(fromId: int) -> BattleFight:
	var prev = DataManager.get_current_battle_fight()
	if prev.fromId >= 0 and prev.targetId >= 0:
		prev.war_report()
	battle_fight = BattleFight.new(fromId)
	return battle_fight


func get_current_battle_fight() -> BattleFight:
	if battle_fight == null:
		
		var bf = BattleFight.new( - 1)
		bf.rebuild_from_env()
		battle_fight = bf
	return battle_fight


func new_solo_fight(leftId: int, rightId: int) -> SoloFight:
	solo_fight = SoloFight.new(leftId, rightId)
	return solo_fight


func get_current_solo_fight() -> SoloFight:
	if solo_fight == null:
		
		var sf = SoloFight.new( - 1, - 1)
		sf.rebuild_from_env()
		solo_fight = sf
	return solo_fight

func auto_save(name: String) -> void :
	DataManager.game_trace("")
	save_game_data(name)
	DataManager.game_trace("AUTO SAVED " + name)
	return


func game_saving_enabled() -> bool:
	if get_current_scene_id() == - 1:
		return false
	if Global.waiting_timers.size() > 0:
		return false
	return game_saving_enabled

func set_env(key: String, val) -> void :
	common_variable[key] = val
	return

func check_env(keys: PoolStringArray) -> bool:
	for key in keys:
		if not common_variable.has(key):
			return false
	return true

func get_env(key: String):
	if not common_variable.has(key):
		return null
	return common_variable[key]

func get_env_bool(key: String) -> bool:
	return Global.boolval(get_env(key))

func get_env_int(key: String, defVal: int = - 1) -> int:
	return Global.intval(get_env(key), defVal)

func get_env_float(key: String, defVal: float = 0.0) -> float:
	return Global.floatval(get_env(key), defVal)

func get_env_str(key: String) -> String:
	return Global.strval(get_env(key))

func get_env_array(key: String) -> Array:
	return Global.arrval(get_env(key))

func get_env_dict(key: String) -> Dictionary:
	return Global.dicval(get_env(key))

func get_env_int_array(key: String) -> Array:
	return Global.intarrval(get_env(key))

func unset_env(key: String) -> void :
	common_variable.erase(key)
	return


func new_develop_command(type: String, actorId: int, cityId: int) -> DevelopCommand:
	affair_command = DevelopCommand.new(type, actorId, cityId)
	return affair_command


func get_current_develop_command() -> DevelopCommand:
	if affair_command == null:
		
		var cmd = DevelopCommand.new("", - 1)
		cmd.rebuild_from_env()
		affair_command = cmd
	return affair_command


func new_policy_command(type: String, actorId: int, cityId: int = - 1) -> PolicyCommand:
	policy_command = PolicyCommand.new(type, actorId, cityId)
	return policy_command


func get_current_policy_command() -> PolicyCommand:
	
	
	
	return policy_command


func new_search_command(cityId: int, fromId: int) -> SearchCommand:
	search_command = SearchCommand.new(cityId, fromId)
	return search_command


func get_current_search_command() -> SearchCommand:
	
	
	
	return search_command


func is_drama_event_processed(name: String) -> bool:
	if not name in DataManager.drama_events_process:
		return false
	return Global.intval(DataManager.drama_events_process[name]) == 1

func discard_lsc_index(lsc) -> void :
	var key = "lsc.{0}".format([lsc.get_path()])
	unset_env(key)
	return

func remember_lsc_index(lsc) -> void :
	var key = "lsc.{0}".format([lsc.get_path()])
	set_env(key, lsc.cursor_index)
	return

func recover_lsc_index(lsc) -> void :
	var key = "lsc.{0}".format([lsc.get_path()])
	var idx = get_env_int(key, - 1)
	idx = max(0, idx)
	idx = min(lsc.items.size() - 1, idx)
	lsc.cursor_index = idx
	return

func _pad(val, length: int, cn: bool = false, reverse: bool = false) -> String:
	var padding = " "
	if cn:
		padding = "　"
	var ret = padding.repeat(length) + Global.strval(val)
	ret = ret.substr(ret.length() - length)
	if reverse:
		ret = Global.strval(val) + padding.repeat(length)
		ret = ret.substr(0, length)
	return ret



func get_current_control_sort() -> int:
	if DataManager.control_sort_no < 0:
		return - 1
	if DataManager.control_sort_no >= DataManager.control_sort.size():
		return - 1
	return DataManager.control_sort[DataManager.control_sort_no]


func get_alliance_months(vstateIdA: int, vstateIdB: int) -> int:
	var key = "{0}-{1}".format([vstateIdA, vstateIdB])
	if DataManager.vstates_alliance.has(key) and int(DataManager.vstates_alliance[key]) > 0:
		return int(DataManager.vstates_alliance[key])
	key = "{1}-{0}".format([vstateIdA, vstateIdB])
	if DataManager.vstates_alliance.has(key) and int(DataManager.vstates_alliance[key]) > 0:
		return int(DataManager.vstates_alliance[key])
	return 0


func is_alliance(vstateIdA: int, vstateIdB: int) -> bool:
	return get_alliance_months(vstateIdA, vstateIdB) > 0


func is_stars_drama() -> bool:
	return drama_path == "stars"

func clear_actor_disabled_equip_types(forSceneId: int) -> void :
	for key in actor_disabled_equip_types:
		for subkey in actor_disabled_equip_types[key].keys():
			var sceneId = int(subkey)
			if sceneId < forSceneId:
				continue
			actor_disabled_equip_types[key].erase(subkey)
	return






func get_actor_disabled_equip_types(actorId: int) -> Array:
	var ret = []
	var currentSceneId = get_current_scene_id()
	var key = str(actorId)
	if not key in actor_disabled_equip_types:
		return []
	for subkey in actor_disabled_equip_types[key]:
		var sceneId = int(subkey)
		if sceneId > currentSceneId:
			continue
		ret.append_array(Global.arrval(actor_disabled_equip_types[key][subkey]))
	return ret


func disable_actor_equip_type(specifiedSceneId: int, actorId: int, type: String) -> void :
	var key = str(actorId)
	if not key in actor_disabled_equip_types:
		actor_disabled_equip_types[key] = {}
	for subkey in actor_disabled_equip_types[key]:
		var sceneId = int(subkey)
		if sceneId != specifiedSceneId:
			continue
		var disabled = actor_disabled_equip_types[key][subkey]
		disabled.erase(type)
		disabled.append(type)
		actor_disabled_equip_types[key][subkey] = disabled
		return
	var subkey = str(specifiedSceneId)
	actor_disabled_equip_types[key][subkey] = [type]
	return


func disable_actor_equip(specifiedSceneId: int, actorId: int, equip: clEquip.EquipInfo) -> void :
	var target = equip.type + "|" + str(equip.id)
	var key = str(actorId)
	if not key in actor_disabled_equip_types:
		actor_disabled_equip_types[key] = {}
	for subkey in actor_disabled_equip_types[key]:
		var sceneId = int(subkey)
		if sceneId != specifiedSceneId:
			continue
		var disabled = actor_disabled_equip_types[key][subkey]
		disabled.erase(target)
		disabled.append(target)
		actor_disabled_equip_types[key][subkey] = disabled
		return
	var subkey = str(specifiedSceneId)
	actor_disabled_equip_types[key][subkey] = [target]
	return

func _equip_static_to_runtime(statics: Array, loaded: Array = []) -> Array:
	var ret = []
	for item in statics:
		var row = {}
		row["ID"] = Global.dic_val(item, "ID", 0)
		row["数量"] = Global.dic_val(item, "数量", - 1)
		ret.append(row)
	for item in loaded:
		var id = Global.dic_val(item, "ID", - 1)
		if id < 0 or id >= ret.size():
			continue
		var cnt = Global.dic_val(item, "数量", - 1)
		if ret[id]["数量"] >= 0:
			ret[id]["数量"] = cnt
	return ret



func get_game_setting(key: String) -> String:
	var ret = ""
	if key in game_set:
		ret = Global.strval(game_set[key])
	for setting in StaticManager.get_all_game_setting(drama_path):
		if key != setting["name"]:
			continue
		var options = setting["options"]
		if not ret in options:
			ret = options[0]
		break
	return ret


func is_challange_game() -> bool:
	var dic = get_env_dict("挑战赛")
	if dic.empty() or not "version" in dic:
		return false
	if Global.intval(dic["version"]) != StaticManager.CURRENT_CHALLANGE_VERSION:
		return false
	return true


func cheater_disabled() -> String:
	if is_challange_game():
		return "挑战赛禁用修改器"
	return ""

func get_challange_game_score() -> int:
	if not is_challange_game():
		return 0
	
	var dic = get_env_dict("挑战赛")
	var extraScore = Global.intval(Global.dic_val(dic, "extraScore", 0))
	return extraScore

func add_challange_game_score(score: int) -> void :
	var dic = get_env_dict("挑战赛")
	if not "extraScore" in dic:
		dic["extraScore"] = 0
	dic["extraScore"] += score
	set_env("挑战赛", dic)
	return
