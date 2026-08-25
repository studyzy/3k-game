# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_net/scene_net_p2p.gd
# 说明：P2P 联网场景脚本。处理点对点联机。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const SCENE_ID = 0


func _ready() -> void :
	get_tree().connect("network_peer_connected", self, "_connected_with_player");
	get_tree().connect("network_peer_disconnected", self, "_disconnected_with_player");
	get_tree().connect("connection_failed", self, "_connection_failed");
	
	SceneManager.load_scene_complete = true;
	SoundManager.stop();
	SceneManager.set_virtukey_show(false)
	_on_Server_pressed();
	_local_clear_message();
	pass



func _connected_with_player(pid):
	rpc_id(pid, "_join_game", get_tree().network_peer.get_unique_id(), AutoLoad.nick_name)
	
		

func _disconnected_with_player(pid):
	if (pid != 1 and not AutoLoad.other_players.has(pid)):
		return ;
	var netPlayer: AutoLoad.NetPlayerInfo = AutoLoad.get_other_playerInfo(pid)
	AutoLoad.remove_other_player(pid);
	_local_show_message("---【玩家ID" + str(netPlayer.nickName) + "】断开连接---");
	if (get_tree().is_network_server()):
		var pno = 1;
		for opid in AutoLoad.other_players:
			AutoLoad.update_player_no(int(pno), int(opid));
			rpc_id(pid, "_send_player_no", opid);
			pno += 1;


remote func _join_game(pid, nickname):
	var netPlayer = AutoLoad.NetPlayerInfo.new();
	netPlayer.Id = int(pid);
	netPlayer.nickName = nickname;
	AutoLoad.add_other_player(netPlayer);
	
	netPlayer = AutoLoad.get_other_playerInfo(pid);
	
	if not get_tree().is_network_server():
		
		_local_show_message("---加入了【玩家ID:" + str(netPlayer.nickName) + "】的游戏---");
	else:
		
		_local_show_message("---【玩家ID:" + str(netPlayer.nickName) + "】加入游戏---");
		
		var other_playerNo = AutoLoad.other_players.size();
		AutoLoad.update_player_no(int(other_playerNo), int(pid))
		rpc_id(pid, "_send_player_no", other_playerNo);
	

remote func _send_player_no(playerNo: int):
	AutoLoad.playerNo = playerNo;
	SceneManager.update_playerNo();


func _connection_failed():
	_local_show_message("连接失败");
	pass


func _on_Server_pressed() -> void :

	var btnServer = get_node("Panel/HFlowContainer/Server");
	var btnClient = get_node("Panel/HFlowContainer/Client");
	btnServer.pressed = true;
	btnClient.pressed = false;
	_update_panel_show()
	pass


func _on_Client_pressed() -> void :

	var btnServer = get_node("Panel/HFlowContainer/Server");
	var btnClient = get_node("Panel/HFlowContainer/Client");
	
	btnServer.pressed = false;
	btnClient.pressed = true;
	_update_panel_show()
	pass

func _update_panel_show():
	var pnlServer = get_node("Panel/pnlServer");
	var pnlClient = get_node("Panel/pnlClient");
	var pnlTalk = get_node("Panel/pnlTalk");
	
	AutoLoad.nick_name = str(get_node("conNickName/LineEdit").text);
	
	if get_tree().network_peer != null:
		pnlTalk.visible = true;
		return ;
	pnlTalk.visible = false;
	var btnServer = get_node("Panel/HFlowContainer/Server");
	var btnClient = get_node("Panel/HFlowContainer/Client");
	pnlServer.visible = btnServer.pressed;
	pnlClient.visible = btnClient.pressed;


func _on_btnCreateRoom_pressed() -> void :
	get_node("Panel/pnlTalk/btnStart").toggle_mode = false;
	get_node("Panel/pnlTalk/btnStart").pressed = false;
	get_node("Panel/pnlTalk/btnStart").text = "开始游戏";
	
	_local_clear_message()
	var port = int(get_node("conPort/LineEdit").text);
	var max_players = int(get_node("Panel/pnlServer/conPlayers/LineEdit").text);
	if max_players <= 1:
		return ;
	var net = NetworkedMultiplayerENet.new();
	net.create_server(port, max_players);
	get_tree().set_network_peer(net);
	_update_panel_show();
	_local_show_message("本机作为服务器");
	_local_show_message("等待其他玩家加入（最大游戏人数:{0}人）".format([max_players]));
	pass


func _on_btnConnect_pressed() -> void :
	get_node("Panel/pnlTalk/btnStart").toggle_mode = true;
	get_node("Panel/pnlTalk/btnStart").pressed = false;
	get_node("Panel/pnlTalk/btnStart").text = "准备游戏";
	_local_clear_message()
	var port = int(get_node("conPort/LineEdit").text);
	var server_address = str(get_node("Panel/pnlClient/conIP/LineEdit").text);
	
	var net = NetworkedMultiplayerENet.new();
	var error = net.create_client(server_address, port);
	if (error != 0):
		_local_show_message("未找到{0}对应的主机".format([server_address]));
		_local_show_message("连接失败……请点击[断开连接]回到上一步");
		return ;
	
	get_tree().set_network_peer(net);
	
	_update_panel_show()
	_local_show_message("本机作为客户端");
	pass


func _local_show_message(msg: String):
	var newmsg = msg.replace("【", "[color=#0000ff]");
	newmsg = newmsg.replace("】", "[/color]");
	get_node("Panel/pnlTalk/txtMsg").bbcode_text += str(newmsg) + "\n";
	pass

func _local_clear_message():
	get_node("Panel/pnlTalk/txtMsg").bbcode_text = "";


func _on_btnEndLink_pressed() -> void :
	get_tree().set_network_peer(null);
	_local_clear_message()
	_update_panel_show()
	pass


remote func get_nick_name():
	return AutoLoad.nick_name;


func _on_btnSendMsg_pressed() -> void :
	var msg = get_node("Panel/pnlTalk/LineEdit").text;
	rpc("_send_msg", AutoLoad.get_local_id(), msg);
	
	_local_show_message("【{0}】  {2}\n{1}".format([AutoLoad.nick_name, msg, Global.get_datetime_now().to_str()]))
	pass

remote func _send_msg(fromId, msg):
	var playInfo = AutoLoad.get_other_playerInfo(fromId);
	_local_show_message("【{0}】  {2}\n{1}".format([playInfo.nickName, msg, Global.get_datetime_now().to_str()]))


func _on_btnStart_pressed() -> void :
	if (AutoLoad.get_local_id() != 1):
		
		var ready = get_node("Panel/pnlTalk/btnStart").pressed;
		if ready:
			get_node("Panel/pnlTalk/btnStart").text = "取消准备";
			_local_show_message("【{0}】   已准备".format([AutoLoad.nick_name]))
		else:
			get_node("Panel/pnlTalk/btnStart").text = "准备游戏";
			_local_show_message("【{0}】   取消准备".format([AutoLoad.nick_name]))
		rpc_id(1, "_send_ready", AutoLoad.get_local_id(), ready)
		return ;
	
	if AutoLoad.other_players.size() == 0:
		_local_show_message("当前不存在其他玩家，无法开始游戏")
		return ;
	
	for otherid in AutoLoad.other_players:
		var otherInfo = AutoLoad.get_other_playerInfo(otherid);
		if otherInfo.is_ready:
			continue;
		_local_show_message("游戏即将开始,提醒【{0}】进行准备！".format([otherInfo.nickName]))
		rpc("_send_msg", AutoLoad.get_local_id(), "游戏即将开始,提醒【{0}】进行准备！".format([otherInfo.nickName]));
		return
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

remote func _send_ready(fromId, ready):
	if fromId in AutoLoad.other_players:
		var pInfo = AutoLoad.get_other_playerInfo(fromId);
		pInfo.is_ready = ready;
		var msg = "取消准备"
		if ready:
			msg = "已准备";
		_local_show_message("【{0}】   {1}".format([pInfo.nickName, msg]))

