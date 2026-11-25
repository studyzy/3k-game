# 白兵战专用异步 HTTP 客户端。
# 与 war/AI/AIHttpClient.gd 完全独立：不排队、不共享实例，避免影响战场 Agent。
extends Resource

var _http: HTTPRequest = null
var _owner: Object = null
var _owner_method: String = ""
var _pending: bool = false

func is_pending() -> bool:
	return _pending

func post(url: String, body_text: String, owner: Object, method: String, timeout_sec: int = 25) -> bool:
	if _pending:
		return false
	if not _ensure_http(timeout_sec):
		return false
	_owner = owner
	_owner_method = method
	_pending = true
	DataManager.ai_debug_log("B_HTTP POST " + url + " body=" + body_text.substr(0, 200), true)
	var err = _http.request(
		url,
		PoolStringArray(["Content-Type: text/plain; charset=utf-8"]),
		true,
		HTTPClient.METHOD_POST,
		body_text
	)
	if err != OK:
		_pending = false
		_owner = null
		_owner_method = ""
		DataManager.ai_debug_log("B_HTTP start failed err={0}".format([err]), true)
		return false
	return true

func cancel() -> void:
	if _http != null:
		_http.cancel_request()
	_pending = false
	_owner = null
	_owner_method = ""
	return

func _ensure_http(timeout_sec: int) -> bool:
	if _http == null:
		_http = HTTPRequest.new()
		_http.use_threads = false
		_http.connect("request_completed", self, "_on_completed")
		SceneManager.add_child(_http)
	if not _http.is_inside_tree():
		if _http.get_parent() != null:
			_http.get_parent().remove_child(_http)
		SceneManager.add_child(_http)
	if not _http.is_inside_tree():
		return false
	_http.timeout = timeout_sec
	return true

func _on_completed(result: int, response_code: int, _headers: PoolStringArray, body: PoolByteArray) -> void:
	if not _pending:
		return
	_pending = false
	var owner = _owner
	var method = _owner_method
	_owner = null
	_owner_method = ""
	DataManager.ai_debug_log("B_HTTP DONE result={0} code={1}".format([result, response_code]), true)
	if owner != null and is_instance_valid(owner) and owner.has_method(method):
		owner.call(method, result, response_code, body)
	return
