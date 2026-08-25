extends Node
## 网络客户端（autoload: NetClient）
## 负责与 Go 服务器通信：HTTP 登录/建局/存读档 + WebSocket 游戏长连接。
## 所有服务器推送经 SignalBus 广播给 UI。

signal connected
signal disconnected
signal auth_done(player_id, token)
signal new_game_done(snapshot)
signal load_game_done(save_id)
signal server_push(op, body)   # 通用服务器推送（opcode + body）
signal static_done             # 静态渲染数据拉取完成
signal static_failed(msg)      # 静态渲染数据拉取失败

## 服务器地址。默认连本机 8080；可用环境变量覆盖（测试时指向 mock server）。
var server_url := "http://127.0.0.1:8080"
var ws_url := "ws://127.0.0.1:8080/game/ws"

var _token := ""
var _player_id := ""
var _session_id := ""
var _ws: WebSocketPeer = null
var _seq := 0
var _connected := false

## 客户端命令 opcode（与 Go 服务器 internal/ws/protocol.go 对应）
const C2S_SELECT_KING := 0x100
const C2S_SELECT_GENERAL := 0x105
const C2S_EXECUTE_TASK := 0x106
const C2S_END_TURN := 0x107
const C2S_WAR_MOVE := 0x108
const C2S_WAR_END_TURN := 0x109
const C2S_WAR_ACTION := 0x10A
const C2S_BATTLE_SELECT := 0x10B
const C2S_BATTLE_TACTIC := 0x10C
const C2S_BATTLE_ADVANCE := 0x10D
const C2S_PING := 0x10F
const C2S_ATTACK := 0x110

## 服务器推送 opcode
const S2C_WORLD_SNAPSHOT := 0x200
const S2C_DELTA := 0x201
const S2C_TASK_RESULT := 0x202
const S2C_TURN_RESULT := 0x203
const S2C_MONTH_RESULT := 0x204
const S2C_WAR_START := 0x205
const S2C_WAR_STEP := 0x206
const S2C_BATTLE_START := 0x207
const S2C_BATTLE_STEP := 0x208
const S2C_SERVER_EVENT := 0x209
const S2C_PONG := 0x20F
const S2C_BATTLE_RESULT := 0x212


func _ready() -> void:
	set_process(false)
	_ws = _make_peer()
	# Mirror 更新后把服务器 gameInfo 同步到 GameInfo（UI 状态只读）
	Mirror.state_changed.connect(_sync_game_info)
	# 环境变量覆盖（测试注入 mock server 地址）
	var env_url := OS.get_environment("K3G_SERVER_URL")
	if env_url != "":
		server_url = env_url
	var env_ws := OS.get_environment("K3G_WS_URL")
	if env_ws != "":
		ws_url = env_ws


## 手动指定服务器地址（测试用），优先级最高；env 覆盖次之。
func set_endpoints(http_url: String, ws_uri: String) -> void:
	server_url = http_url
	ws_url = ws_uri


## 让网络层处理一帧（轮询 WS；便于测试在无自动 _process 循环下驱动）。
func pump() -> void:
	_process(0.016)


## 登录（HTTP），成功后自动连接 WebSocket
func login(player_id: String = "p1") -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_login_done.bind(http))
	var body := "playerId=%s" % player_id
	http.request(server_url + "/auth/login", [], HTTPClient.METHOD_POST, body)


func _on_login_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200:
		push_error("登录失败: HTTP %d" % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary:
		var d: Dictionary = data
		_token = d.get("token", "")
		_player_id = d.get("playerId", "")
		auth_done.emit(_player_id, _token)
		# 自动创建新局并连接 WS
		create_game()


## 拉取静态渲染数据（GET /game/static），成功后填充 DataManager/TextLibrary。
## 服务器是唯一数据源，客户端不再读本地 data/*.json / Map / Formation。
func fetch_static() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_static_done.bind(http))
	http.request(server_url + "/game/static", [], HTTPClient.METHOD_GET)


func _on_static_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200:
		static_failed.emit("拉取静态数据失败: HTTP %d" % code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		static_failed.emit("静态数据解析失败")
		return
	var d: Dictionary = parsed
	var sdata: Variant = d.get("data", {})
	if not sdata is Dictionary:
		static_failed.emit("静态数据缺少 data 字段")
		return
	DataManager.apply_static(sdata)
	TextLibrary.apply_texts(sdata.get("texts", {}))
	static_done.emit()


## 创建新局（HTTP），成功后返回 snapshot
func create_game() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_new_game_done.bind(http))
	http.request(server_url + "/game/new", [], HTTPClient.METHOD_POST, "{}")


## 存档到服务器（HTTP）
func save_game(save_id: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_save_done.bind(http, save_id))
	var body := "playerId=%s&sessionId=%s&saveId=%s" % [_player_id, _session_id, save_id]
	http.request(server_url + "/game/save", [], HTTPClient.METHOD_POST, body)


func _on_save_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, save_id: String) -> void:
	http.queue_free()
	if code != 200:
		push_error("存档失败: HTTP %d" % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary and data.get("ok", false):
		print("[Net] 已存档 %s" % save_id)


## 读档（HTTP），成功后切换到新 session
func load_game(save_id: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_load_done.bind(http, save_id))
	var body := "playerId=%s&saveId=%s" % [_player_id, save_id]
	http.request(server_url + "/game/load", [], HTTPClient.METHOD_POST, body)


func _on_load_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, save_id: String) -> void:
	http.queue_free()
	if code != 200:
		push_error("读档失败: HTTP %d" % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary and data.get("ok", false):
		var d: Dictionary = data
		_session_id = d.get("sessionId", "")
		var snapshot: Variant = d.get("snapshot", {})
		if snapshot is Dictionary:
			Mirror.apply_delta(snapshot)
		load_game_done.emit(save_id)


func _on_new_game_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	if code != 200:
		push_error("建局失败: HTTP %d" % code)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if data is Dictionary:
		var d: Dictionary = data
		_session_id = d.get("sessionId", "")
		# 应用建局全量快照到 Mirror（含 gameInfo），后续增量在 gameInfo 上叠加
		var snapshot: Variant = d.get("snapshot", {})
		if snapshot is Dictionary:
			Mirror.apply_delta(snapshot)
		new_game_done.emit(d)
		connect_ws()


## 创建 WebSocketPeer。
## 服务器全量 Delta（选君主/回合结束等）可能远超默认入站缓冲，
## 过大会被 WebSocket 以 1009(Message too big) 关闭，故放大到 16MB。
func _make_peer() -> WebSocketPeer:
	var peer := WebSocketPeer.new()
	peer.inbound_buffer_size = 16 * 1024 * 1024
	return peer


## 连接 WebSocket
func connect_ws() -> void:
	if _ws == null:
		_ws = _make_peer()
	var err := _ws.connect_to_url(ws_url + "?sessionId=%s" % _session_id)
	if err != OK:
		push_error("WS 连接失败: %d" % err)
		return
	set_process(true)
	_connected = true
	connected.emit()


## 发送请求（C2S）
func send(op: int, body: Dictionary = {}) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_error("WS 未连接，无法发送 op 0x%X" % op)
		return
	_seq += 1
	var msg: Dictionary = {"v": 1, "type": "req", "seq": _seq, "op": op, "body": body}
	_ws.send_text(JSON.stringify(msg))


func _process(_delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state: int = _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while _ws.get_available_packet_count() > 0:
			var packet: PackedByteArray = _ws.get_packet()
			var text: String = packet.get_string_from_utf8()
			_handle_push(text)
	elif state == WebSocketPeer.STATE_CLOSED:
		_connected = false
		disconnected.emit()


## 处理服务器推送
func _handle_push(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if data == null or not data is Dictionary:
		return
	var d: Dictionary = data
	var op: int = int(d.get("op", 0))
	var body: Variant = d.get("body", {})
	# 更新镜像
	if op == S2C_DELTA or op == S2C_WORLD_SNAPSHOT:
		if body is Dictionary:
			Mirror.apply_delta(body)
	elif op == S2C_WAR_START or op == S2C_WAR_STEP:
		if body is Dictionary:
			Mirror.apply_war(body)
	server_push.emit(op, body)


## 把服务器权威 gameInfo 同步到 UI 用的 GameInfo autoload（只读，不写回服务器）。
func _sync_game_info() -> void:
	var gi: Dictionary = Mirror.game_info
	if gi.is_empty():
		return
	GameInfo.years = int(gi.get("years", GameInfo.years))
	GameInfo.month = int(gi.get("month", GameInfo.month))
	GameInfo.curTurnIndex = int(gi.get("curTurnIndex", GameInfo.curTurnIndex))
	GameInfo.curTurnCountryId = int(gi.get("curTurnCountryId", GameInfo.curTurnCountryId))
	GameInfo.playerCountryId = int(gi.get("playerCountryId", GameInfo.playerCountryId))
	GameInfo.playerOrderNum = int(gi.get("playerOrderNum", GameInfo.playerOrderNum))
	GameInfo.difficult = int(gi.get("difficult", GameInfo.difficult))
	GameInfo.attackCount = int(gi.get("attackCount", GameInfo.attackCount))
	GameInfo.playingState = int(gi.get("playingState", GameInfo.playingState))
	GameInfo.doCityId = int(gi.get("doCityId", GameInfo.doCityId))
	GameInfo.show_info = str(gi.get("showInfo", GameInfo.show_info))
