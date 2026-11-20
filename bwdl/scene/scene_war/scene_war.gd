extends Control

const SCENE_ID = 20000

onready var bottom_scene_color = get_node("bottom_scene_color")
onready var war_map = get_node("war_map")
onready var war_communique = get_node("War_Communique")
onready var war_status = get_node("war_status")
onready var war_log = get_node("war_log")
onready var lbl_agent_message = get_node("lblAgentMessage")

# AI Agent 的思考进度：显示在底部黄色消息区，只保留最新一条
const AGENT_MAX_CHARS: int = 44

var war_auto_run


func _ready() -> void :
	war_auto_run = Global.load_script(DataManager.mod_path + "sgz_script/war/war_auto_run.gd")
	SceneManager.load_scene_complete = true
	war_communique.hide()
	war_status.hide()
	war_log.hide()
	lbl_agent_message.add_font_override("normal_font", Global.get_font(20))
	lbl_agent_message.hide()
	return


# 新增：显示 AI Agent 的最新一条思考进度（战争界面底部消息区）。
# 只显示最新一条，不累计历史；新消息直接替换旧消息。
func show_agent_progress(text: String) -> void :
	var s = text.replace("\n", " ").strip_edges()
	if s == "":
		return
	if s.length() > AGENT_MAX_CHARS:
		s = s.substr(0, AGENT_MAX_CHARS - 1) + "…"
	lbl_agent_message.text = "敌方AI：" + s
	lbl_agent_message.show()
	return


# 新增：AI 回合结束 / 回退本地 AI 时清空，避免把旧进度带进玩家回合
func clear_agent_progress() -> void :
	lbl_agent_message.text = ""
	lbl_agent_message.hide()
	return


func _process(delta: float) -> void :
	if war_auto_run == null:
		return
	var wf = DataManager.get_current_war_fight()
	if wf == null or wf.status != 1:
		return
	war_auto_run._process(delta)
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.70666, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(212, 0)
	rect_scale = Vector2(1, 1)
	return
