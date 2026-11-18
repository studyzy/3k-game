# ==============================================================================
# 新增：AI Agent 接入（战争场景）
# 文件：packed/sgz_script/war/AI/AIHttpClient.gd
# 说明：包装 Godot 3.5 的 HTTPRequest 节点，纯异步回调，不阻塞主循环。
#       依据设计文档 docs/plans/2026-11-18-ai-agent-enemy-design.md §3.4。
# ==============================================================================
extends Resource

var _http: HTTPRequest = null
var _owner: Object = null
var _owner_method: String = ""
var _pending: bool = false

func _init() -> void:
	# Global.load_script 会复用缓存实例并再次调用 _init()，此处必须幂等
	_pending = false
	_owner = null
	_owner_method = ""
	return

func is_pending() -> bool:
	return _pending

func get_url(url: String, owner: Object, method: String, timeout_sec: int = 15) -> bool:
	if _pending:
		return false
	if not _ensure_http(timeout_sec):
		return false
	_owner = owner
	_owner_method = method
	_pending = true
	var err = _http.request(url, PoolStringArray(["Cache-Control: no-cache"]), true, HTTPClient.METHOD_GET, "")
	if err != OK:
		_fail(err)
		return false
	return true

func _ensure_http(timeout_sec: int) -> bool:
	if _http == null:
		_http = HTTPRequest.new()
		_http.connect("request_completed", self, "_on_completed")
		# 挂到已完全初始化的 SceneManager 单例下，而不是 /root：
		# /root 在场景搭建期间「busy setting up children」，直接 add_child 会失败（实测）。
		SceneManager.add_child(_http)
	if not _http.is_inside_tree():
		return false
	_http.timeout = timeout_sec
	return true

func post(url: String, body_text: String, owner: Object, method: String, timeout_sec: int = 15) -> bool:
	if _pending:
		return false
	if not _ensure_http(timeout_sec):
		return false
	_owner = owner
	_owner_method = method
	_pending = true
	# Godot 3.5 签名：request(url, custom_headers, ssl_validate_domain, method, request_data)
	# 第 4 参是 method(int)，请求体是第 5 参；text/plain 为 CORS 安全列表内容类型，同源下不触发 OPTIONS 预检
	var err = _http.request(url, PoolStringArray(["Content-Type: text/plain; charset=utf-8"]), true, HTTPClient.METHOD_POST, body_text)
	if err != OK:
		_fail(err)
		return false
	return true

func _fail(err: int) -> void:
	_pending = false
	DataManager.game_trace("[AI] http start failed: {0}".format([err]))
	if _owner != null and _owner.has_method(_owner_method):
		_owner.call(_owner_method, -1, 0, PoolByteArray())
	return

func cancel() -> void:
	if _http != null:
		_http.cancel_request()
	_pending = false
	return

func _on_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
	if not _pending:
		return
	_pending = false
	if _owner != null and _owner.has_method(_owner_method):
		_owner.call(_owner_method, result, response_code, body)
	return
