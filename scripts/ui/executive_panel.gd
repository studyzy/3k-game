extends Control
## 任务执行面板（对应 Unity UIExecutivePanel）

var _result_label: Label
var _input_panel: Panel
var _current_input_callback: Callable


func _ready() -> void:
	# 全屏背景（sanguo 迁移资源 bg4.jpg）
	add_child(UIFactory.make_bg("res://assets/bg/bg4.jpg"))

	var title := UIFactory.make_label("执行指令", 36, Color(0.95, 0.85, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-100, 20)
	title.size = Vector2(200, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_result_label = UIFactory.make_label("", 22, Color.WHITE)
	_result_label.position = Vector2(100, 100)
	_result_label.size = Vector2(700, 300)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_result_label)

	var next := UIFactory.make_button("继 续", Vector2(180, 56), 24)
	next.position = Vector2(360, 640)
	next.pressed.connect(_on_next)
	add_child(next)

	_execute()


func _task_name() -> String:
	var names := {
		GameInfo.TaskType.SEARCH: "搜索", GameInfo.TaskType.EMPLOY: "登用",
		GameInfo.TaskType.REWARD: "奖赏", GameInfo.TaskType.APPOINT: "任命",
		GameInfo.TaskType.RECLAIM: "开垦", GameInfo.TaskType.MERCANTILE: "劝商",
		GameInfo.TaskType.TAME: "治水", GameInfo.TaskType.PATROL: "巡查",
		GameInfo.TaskType.CONSCRIPT: "征兵", GameInfo.TaskType.SHOP: "金粮",
		GameInfo.TaskType.SMITHY: "武器", GameInfo.TaskType.SCHOOL: "学院",
		GameInfo.TaskType.HOSPITAL: "医馆", GameInfo.TaskType.MOVE: "移动",
		GameInfo.TaskType.ATTACK: "攻城", GameInfo.TaskType.TRANSPORT: "输送",
		GameInfo.TaskType.TRUCE: "同盟", GameInfo.TaskType.ALIENATE: "离间",
		GameInfo.TaskType.BRIBE: "招揽",
	}
	return names.get(GameInfo.task, "任务")


func _execute() -> void:
	# 需要数值输入的指令先弹输入框，否则直接发服务器
	match GameInfo.task:
		GameInfo.TaskType.CONSCRIPT:
			_show_input("输入征兵数量", "1000", func(text: String):
				_pending_inputs = {"amount": clampi(int(text), 0, 30000)}
				_send_task())
			return
		GameInfo.TaskType.SHOP:
			_show_input("输入购买粮食数量（4粮=3金）", "100", func(text: String):
				_pending_inputs = {"amount": clampi(int(text), 0, 30000)}
				_send_task())
			return
		GameInfo.TaskType.TRANSPORT:
			_show_input("输入输送粮食数量", "100", func(text: String):
				_pending_inputs = {"food": clampi(int(text), 0, 99999), "gold": 0}
				_send_task())
			return
		GameInfo.TaskType.ATTACK:
			# 攻城：通知服务器发起战争（war_prepare）
			_send_attack()
			return
		_:
			_pending_inputs = {}
			_send_task()


func _send_task() -> void:
	_result_label.text = "指令执行中..."
	var body := {
		"task": GameInfo.task,
		"doCityId": GameInfo.doCityId,
		"targetCityId": GameInfo.targetCityId,
		"doGeneralIds": GameInfo.doGeneralIds,
		"targetGeneralIds": GameInfo.targetGeneralIds,
		"inputs": _pending_inputs,
	}
	NetClient.send(NetClient.C2S_EXECUTE_TASK, body)
	if not NetClient.server_push.is_connected(_on_task_result):
		NetClient.server_push.connect(_on_task_result)


func _send_attack() -> void:
	# 通知服务器准备战争，服务器返回后进入战争场景
	_result_label.text = "发起攻城..."
	var body := {
		"doCityId": GameInfo.doCityId,
		"targetCityId": GameInfo.targetCityId,
		"doGeneralIds": GameInfo.doGeneralIds,
	}
	NetClient.send(NetClient.C2S_ATTACK, body)
	if not NetClient.server_push.is_connected(_on_attack_result):
		NetClient.server_push.connect(_on_attack_result)


func _on_attack_result(op: int, body: Dictionary) -> void:
	if op != NetClient.S2C_WAR_START:
		return
	NetClient.server_push.disconnect(_on_attack_result)
	SceneRouter.change_scene("res://scenes/ui/war_scene.tscn")


var _pending_inputs := {}


func _on_task_result(op: int, body: Dictionary) -> void:
	if op != NetClient.S2C_TASK_RESULT:
		return
	NetClient.server_push.disconnect(_on_task_result)
	var results: Array = body.get("results", [])
	_result_label.text = "\n".join(results)
	# 更新命令数
	if body.has("orderNum"):
		GameInfo.playerOrderNum = int(body.orderNum)


func _on_next() -> void:
	# 扣命令并返回（服务器已扣，客户端仅更新镜像）
	GameInfo.task = GameInfo.TaskType.NONE
	SceneRouter.change_scene("res://scenes/ui/city_scene.tscn")


func _show_input(title_text: String, default_text: String, callback: Callable) -> void:
	if _input_panel != null:
		_input_panel.queue_free()
	_input_panel = Panel.new()
	_input_panel.set_anchors_preset(Control.PRESET_CENTER)
	_input_panel.position = Vector2(-200, -100)
	_input_panel.size = Vector2(400, 200)
	add_child(_input_panel)
	UIFactory.add_label(_input_panel, title_text, Vector2(30, 20), 24)
	var line_edit := LineEdit.new()
	line_edit.text = default_text
	line_edit.position = Vector2(30, 70)
	line_edit.size = Vector2(340, 40)
	_input_panel.add_child(line_edit)
	var ok := UIFactory.make_button("确 定", Vector2(120, 44), 22)
	ok.pressed.connect(func():
		callback.call(line_edit.text)
		_input_panel.queue_free())
	_input_panel.add_child(ok)
	ok.position = Vector2(140, 130)
	_current_input_callback = callback
