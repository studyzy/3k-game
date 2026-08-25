# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_net/scene_net.gd
# 说明：联网场景主脚本。多人游戏大厅/联机入口。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const SCENE_ID = 0

onready var lblPlayersNum = get_node("lblPlayersNum");
onready var lblMessage = get_node("lblMessage");



func _ready() -> void :
	SceneManager.load_scene_complete = true;
	lblMessage.text = "";
	SoundManager.stop();
	SceneManager.VirtualKey.hide();
	get_tree().connect("network_peer_connected", self, "_player_connected");
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected");
	get_tree().connect("connection_failed", self, "_connection_failed");
	update_players_show();
	pass

func _connection_failed():
	get_node("btnServer").disabled = false;
	get_node("btnClient").disabled = false;
	show_message("无法建立连接");

remote func _set_player_no(playerNo: int):
	AutoLoad.playerNo = playerNo;
	SceneManager.update_playerNo();


func _player_connected(pid):
	if (AutoLoad.other_players.size() >= 3):
		get_tree().set_refuse_new_network_connections(true);
		return ;
	AutoLoad.add_other_player(pid);
	update_players_show();
	match int(pid):
		1:
			show_message("---加入了【玩家ID:" + str(pid) + "】的房间---");
		_:
			show_message("---【玩家ID:" + str(pid) + "】加入房间---");
	
	get_node("btnGameStart").disabled = false;
	
	if (get_tree().is_network_server()):
		
		var other_playerNo = AutoLoad.other_players.size();
		AutoLoad.update_player_no(int(other_playerNo), int(pid))
		rpc_id(pid, "_set_player_no", other_playerNo);
		

func _player_disconnected(pid):
	if (pid != 1 and not AutoLoad.other_players.has(pid)):
		return ;
	AutoLoad.remove_other_player(pid);
	update_players_show();
	show_message("---玩家ID" + str(pid) + "断开连接---");
	if (get_tree().is_network_server()):
		var pno = 1;
		for opid in AutoLoad.other_players:
			AutoLoad.update_player_no(int(pno), int(opid));
			rpc_id(pid, "_set_player_no", opid);
			pno += 1;
	if (AutoLoad.other_players.size() < 4):
		get_tree().set_refuse_new_network_connections(false);
		return ;

func update_players_show():
	lblPlayersNum.text = "玩家人数:" + str(1 + AutoLoad.other_players.size());

remote func show_message(text: String):
	if (lblMessage.text != ""):
		text = "\n" + str(text);
	lblMessage.text += text;


func _on_btnServer_pressed() -> void :
	get_node("btnServer").disabled = true;
	get_node("btnClient").disabled = true;
	var net = NetworkedMultiplayerENet.new();
	net.create_server(8080, 2);
	get_tree().set_network_peer(net);
	show_message("【本机作为服务器】");
	pass


func _on_btnClient_pressed() -> void :
	get_node("btnServer").disabled = true;
	get_node("btnClient").disabled = true;
	var net = NetworkedMultiplayerENet.new();
	var error = net.create_client("127.0.0.1", 8080);
	if (error != 0):
		_connection_failed();
		return ;
	get_tree().set_network_peer(net);
	show_message("【本机作为客户端】");
	pass


func _on_btnSend_pressed() -> void :
	var line = get_node("LineEdit");
	var pid = "【本地玩家】\n";
	
	var text = line.text;
	show_message(pid + text);
	if ( not AutoLoad.other_players.empty()):
		pid = "【玩家" + str(AutoLoad.get_local_id()) + "】\n";
		rpc("show_message", pid + text);
	line.text = "";
	pass


func _on_btnBack_pressed() -> void :
	get_tree().set_network_peer(null);
	AutoLoad.other_players = [];
	FlowManager.add_flow("go_to_scene|res://scene/scene_title/scene_title.tscn");
	SceneManager.VirtualKey.show();
	pass


func _on_btnGameStart_pressed() -> void :
	if (AutoLoad.get_local_id() != 1):
		var pid = "【本地玩家】\n";
		var text = "提醒房主进行开始游戏";
		show_message(pid + text);
		if ( not AutoLoad.other_players.empty()):
			pid = "【玩家" + str(AutoLoad.get_local_id()) + "】\n";
			rpc("show_message", pid + text);
		return ;
	
	get_tree().set_refuse_new_network_connections(true);
	var flows_history_list = [
		"go_to_scene|res://scene/scene_title/scene_title.tscn", 
		"_show_select_item_1", 
		"_show_select_item_2"
	]
	FlowManager.clear();
	for flow in flows_history_list:
		FlowManager.add_flow(flow);
	pass

func _process(delta: float) -> void :
	if (Input.is_action_just_pressed("EMU_MENU")):
		_on_btnBack_pressed();
		
