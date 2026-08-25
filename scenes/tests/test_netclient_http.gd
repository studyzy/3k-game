extends GdUnitTestSuite
## NetClient HTTP 层测试：连接 MockServer，验证 login/build/load 流程与信号。
## MockServer 地址在 scripts/run_client_tests.sh 中通过 K3G_SERVER_URL/K3G_WS_URL 注入。

const ClientScript := preload("res://scripts/net/client.gd")


func _new_client() -> Node:
	var node := Node.new()
	node.set_script(ClientScript)
	add_child(node)  # 触发 _ready 读取注入地址
	return node


func test_login_emits_auth_done() -> void:
	var node := _new_client()
	await await_idle_frame()  # 确保 HTTPRequest add_child 后 inside tree，再发请求
	node.login("p1")
	var args: Variant = await await_signal_on(node, "auth_done", [], 5000)
	assert_that(args).is_not_null()
	# auth_done(player_id, token)
	assert_that((args as Array)[0]).is_equal("p1")
	assert_that((args as Array)[1]).is_equal("mock-token-1")


func test_create_game_emits_new_game_done() -> void:
	var node := _new_client()
	await await_idle_frame()
	node.login("p1")
	await await_signal_on(node, "auth_done", [], 5000)
	var args: Variant = await await_signal_on(node, "new_game_done", [], 5000)
	assert_that(args).is_not_null()
	# new_game_done(snapshot)：校验 sessionId 已写入
	assert_that(node.get("_session_id")).is_equal("session-abc-123")


func test_login_sets_endpoint_from_env() -> void:
	var node: Node = _new_client()
	var env_url := OS.get_environment("K3G_SERVER_URL")
	if env_url == "":
		assert_that(node.server_url).is_equal("http://127.0.0.1:8080")
	else:
		assert_that(node.server_url).is_equal(env_url)