extends Control
## 战术战斗（服务器驱动）
## 服务器通过 C2S_BATTLE_SELECT 演算战斗，客户端展示结果后返回战争场景。

var _info_label: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.1, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIFactory.make_label("战 术 战 斗", 36, Color(0.9, 0.7, 0.3))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-100, 10)
	title.size = Vector2(200, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_info_label = UIFactory.make_label("战斗演算中...", 22, Color.WHITE)
	_info_label.position = Vector2(60, 200)
	_info_label.size = Vector2(1200, 80)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_info_label)

	# 通知服务器演算自动战斗
	NetClient.send(NetClient.C2S_BATTLE_SELECT, {"formationIndex": 0, "mode": "auto"})
	if not NetClient.server_push.is_connected(_on_battle_result):
		NetClient.server_push.connect(_on_battle_result)


func _on_battle_result(op: int, body: Dictionary) -> void:
	if op != NetClient.S2C_BATTLE_RESULT:
		return
	NetClient.server_push.disconnect(_on_battle_result)
	var win: bool = body.get("win", false)
	if win:
		_info_label.text = "我军胜利！"
	else:
		_info_label.text = "我军战败！"
	# 延迟返回战争场景
	get_tree().create_timer(1.5).timeout.connect(func():
		SceneRouter.change_scene("res://scenes/ui/war_scene.tscn"))
