extends Node

class NetPlayerInfo:
	var Id: int;
	var nickName: String = "";
	var is_ready = false;
	
	func to_json_str():
		var data = {
			"Id": Id, 
			"nickName": nickName, 
			"is_ready": is_ready, 
		};
		return data;
	

var other_players: Array = [];
var playerNo: int = 0;
var nick_name = "";
var other_players_Info = {};


var playerNo_to_ID: Dictionary = {};


func _ready() -> void :
	clear_player_no()
	pass
	
func clear_player_no():
	other_players = [];
	other_players_Info.clear();
	playerNo_to_ID.clear();
	update_player_no(0, 1);




func get_local_id():
	if ( not check_is_multigame()):
		other_players.clear();
		clear_player_no();
		return 1;
	
	return get_tree().get_network_unique_id();

func add_other_player(net_player: NetPlayerInfo):
	other_players.append(net_player.Id);
	other_players_Info[str(net_player.Id)] = net_player;
	
func get_other_playerInfo(Id) -> NetPlayerInfo:
	var key = str(Id);
	return other_players_Info[key];
	
func remove_other_player(pid: int):
	other_players.erase(pid);
	other_players_Info.erase(str(pid));

func update_player_no(_playerNo: int, pid: int):
	_update_player_no(_playerNo, pid);
	if (AutoLoad.check_is_multigame()):
		rpc("_update_player_no", _playerNo, pid);

remote func _update_player_no(_playerNo: int, pid: int):
	playerNo_to_ID[str(_playerNo)] = pid;

func get_pid_by_playerNo(_playerNo: int) -> int:
	if (_playerNo == 0):
		return 1;
	if ( not playerNo_to_ID.has(str(_playerNo))):
		return - 1;
	return int(playerNo_to_ID[str(_playerNo)]);


func check_is_multigame() -> bool:
	if (get_tree().network_peer == null):
		return false;
	if (other_players.empty()):
		return false;
	return true;
