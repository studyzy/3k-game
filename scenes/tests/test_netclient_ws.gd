extends GdUnitTestSuite
## NetClient WebSocket 层测试：连 MockServer WS，发 C2S 请求，断言收到推送后状态更新。
## 注意：在 gdUnit 测试里 client 的自动 _process 不会持续跑，因此测试用 `pump()` 手动轮询驱动网络层，
## 包括握手等待与接收推送。NetClient._handle_push 会把 Delta 应用到 autoload Mirror，测试校验全局镜像。

const ClientScript := preload("res://scripts/net/client.gd")


var _pushed := false
static var _pushed_count := 0


func _new_client() -> Node:
	var node := Node.new()
	node.set_script(ClientScript)
	add_child(node)
	return node


## 完成登录 → HTTP 建局 → 手动轮询直到 WS 握手成功，返回已连接的 client。
func _login_and_ws_ready() -> Node:
	var node := _new_client()
	await await_idle_frame()
	node.login("p1")
	await await_signal_on(node, "auth_done", [], 5000)
	await await_signal_on(node, "new_game_done", [], 5000)
	# 手动 pump 直到 WS 进入 OPEN
	for i in range(40):
		node.pump()
		var ws: Variant = node.get("_ws")
		if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			break
		await await_millis(50)
	return node


func test_send_receives_delta_and_updates_mirror() -> void:
	var node: Node = await _login_and_ws_ready()
	node.pump()
	# 发送 C2S_EXECUTE_TASK (0x106)，MockServer 回放一条 S2C_DELTA (0x201)
	node.send(int(node.get("C2S_EXECUTE_TASK")), {"cityId": 10, "task": 0})
	# 手动 pump 直到全局 Mirror 出现回放武将，说明推送已处理
	var got := false
	for i in range(60):
		node.pump()
		if Mirror.get_general(1).get("name", "") != "":
			got = true
			break
		await await_millis(50)
	assert_that(got).is_true()
	await await_millis(50)
	assert_that(Mirror.get_general(1).get("name", "")).is_equal("刘备")
	assert_that(int(Mirror.get_city(10).get("population", 0))).is_equal(50000)
	assert_that(Mirror.player_order_num()).is_equal(2)


func test_ping_flows_through_ws() -> void:
	var node: Node = await _login_and_ws_ready()
	node.pump()
	_pushed = false
	node.connect("server_push", _on_push)
	node.send(int(node.get("C2S_PING")))
	for i in range(60):
		node.pump()
		if _pushed:
			break
		await await_millis(50)
	node.disconnect("server_push", _on_push)
	assert_that(_pushed).is_true()


func _on_push(op, body) -> void:
	_pushed = true
	_pushed_count += 1