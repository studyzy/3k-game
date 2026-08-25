# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/net_test/net_game_test.gd
# 说明：联网测试脚本。用于多人对战功能的测试。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Node2D

func _ready() -> void :
	var player1 = preload("res://scene/net_test/net_test_player.tscn").instance();
	player1.position = Vector2(50, 50);
	player1.set_name(str(AutoLoad.get_local_id()));
	player1.set_network_master(AutoLoad.get_local_id());
	add_child(player1);
	
	var i = 1;
	for pid in AutoLoad.other_players:
		var other_player = preload("res://scene/net_test/net_test_player.tscn").instance();
		other_player.position = Vector2(50 + i * 150, 50);
		other_player.set_name(str(pid));
		other_player.set_network_master(pid);
		add_child(other_player);
		i += 1;
	pass
