# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/net_test/net_test.gd
# 说明：联网测试主脚本。组织联网测试流程。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

onready var label = get_node("Label")

func _ready() -> void :
	
	pass


func _player_connected(pid):
	AutoLoad.other_players.append(pid);
	label.text = "其他玩家人数:" + str(AutoLoad.other_players.size());


func _on_btn_host_pressed() -> void :
	var net = NetworkedMultiplayerENet.new();
	net.create_server(8080, 2);
	get_tree().set_network_peer(net);
	pass


func _on_btn_join_pressed() -> void :
	var net = NetworkedMultiplayerENet.new();
	net.create_client("127.0.0.1", 8080);
	get_tree().set_network_peer(net);
	pass


func _on_Button_pressed() -> void :
	var game = preload("res://scene/net_test/net_game_test.tscn").instance();
	get_tree().root.add_child(game);
	self.hide();
	pass
