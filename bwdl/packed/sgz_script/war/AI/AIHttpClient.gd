# ==============================================================================
# 新增：AI Agent 接入（战争场景）
# 文件：packed/sgz_script/war/AI/AIHttpClient.gd
# 说明：包装 Godot 3.5 的 HTTPRequest 节点，纯异步回调，不阻塞主循环。
#       依据设计文档 docs/plans/2026-11-18-ai-agent-enemy-design.md §3.4。
# ==============================================================================
extends Resource

var _http: HTTPRequest = null
var _queue: Array = []            # 排队中的请求 [{url, body, owner, method, timeout}]
var _owner: Object = null
var _owner_method: String = ""
var _pending: bool = false

func _init() -> void:
	# Global.load_script 命中缓存时会再次调用 _init()（返回同一个实例）。
	# 此时可能有一个请求正在飞行中：若在这里清 _pending / _owner，
	# _on_completed 会因 "not _pending" 直接丢弃响应，调用方永远等不到回调
	# （白兵战实测：open() 发出 POST 后 sid 一直为空，整场卡死）。
	# 所以已有请求在飞时保持原状，只在不忙时复位。
	if _pending:
		return
	_pending = false
	_owner = null
	_owner_method = ""
	return

func is_pending() -> bool:
	return _pending

func pending_count() -> int:
	return _queue.size()

func get_url(url: String, owner: Object, method: String, timeout_sec: int = 15) -> bool:
	return enqueue(url, method, owner, timeout_sec, "", false)

# 队列版：任何调用方随时可投递，内部同一时刻只飞一个请求，完成后再发下一个。
# 白兵战是准实时的，AI 轮询不能因为别处（战场/其他 tick）占了通道就静默失败，
# 所以这里不再「忙就返回 false」，而是排队。owner 失效（场景已释放）时直接跳过。
func enqueue(url: String, method_name: String, owner: Object, timeout_sec: int = 15, body_text: String = "", is_post: bool = false) -> bool:
	_queue.append({
		"url": url, "body": body_text, "owner": owner,
		"method": method_name, "timeout": timeout_sec, "post": is_post,
	})
	if not _pending:
		_pump()
	return true

func _pump() -> void:
	if _pending:
		return
	while not _queue.empty():
		var req = _queue.pop_front()
		_owner = req["owner"]
		# 投递后排队的请求，投递方可能已被释放（换场景）：直接丢弃，绝不对已释放对象 call
		if _owner == null or not is_instance_valid(_owner) or not _owner.has_method(req["method"]):
			_owner = null
			_owner_method = ""
			continue
		_owner_method = req["method"]
		if not _ensure_http(int(req["timeout"])):
			_owner = null
			_owner_method = ""
			continue
		_pending = true
		var err = 0
		if req["post"]:
			DataManager.ai_debug_log("HTTP POST " + req["url"] + " body=" + str(req["body"]).substr(0, 200), true)
			err = _http.request(req["url"], PoolStringArray(["Content-Type: text/plain; charset=utf-8"]), true, HTTPClient.METHOD_POST, req["body"])
		else:
			DataManager.ai_debug_log("HTTP GET " + req["url"], true)
			err = _http.request(req["url"], PoolStringArray(["Cache-Control: no-cache"]), true, HTTPClient.METHOD_GET, "")
		if err != OK:
			_pending = false
			DataManager.ai_debug_log("HTTP START FAILED err={0}".format([err]), true)
			var o = _owner
			var m = _owner_method
			_owner = null
			_owner_method = ""
			if o != null and is_instance_valid(o) and o.has_method(m):
				o.call(m, -1, 0, PoolByteArray())
			continue
		return
	return

func _ensure_http(timeout_sec: int) -> bool:
	if _http == null:
		_http = HTTPRequest.new()
		_http.connect("request_completed", self, "_on_completed")
		# 挂到已完全初始化的 SceneManager 单例下，而不是 /root：
		# /root 在场景搭建期间「busy setting up children」，直接 add_child 会失败（实测）。
		SceneManager.add_child(_http)
	if not _http.is_inside_tree():
		# 场景切换后节点可能已脱离树（此时 request() 会静默不发出），重新挂上
		DataManager.ai_debug_log("HTTP reattach: parent={0}".format([
			str(_http.get_parent() != null),
		]), true)
		if _http.get_parent() != null:
			_http.get_parent().remove_child(_http)
		SceneManager.add_child(_http)
	if not _http.is_inside_tree():
		DataManager.ai_debug_log("HTTP reattach failed: still not in tree", true)
		return false
	_http.timeout = timeout_sec
	return true

# Godot 3.5 签名：request(url, custom_headers, ssl_validate_domain, method, request_data)
# 第 4 参是 method(int)，请求体是第 5 参；text/plain 为 CORS 安全列表内容类型，同源下不触发 OPTIONS 预检
func post(url: String, body_text: String, owner: Object, method: String, timeout_sec: int = 15) -> bool:
	return enqueue(url, method, owner, timeout_sec, body_text, true)

func cancel() -> void:
	_queue.clear()
	if _http != null:
		_http.cancel_request()
	_pending = false
	_owner = null
	_owner_method = ""
	return

func _on_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
	if not _pending:
		return
	_pending = false
	var owner = _owner
	var method = _owner_method
	_owner = null
	_owner_method = ""
	DataManager.ai_debug_log("HTTP DONE result={0} code={1} body={2}".format([
		result, response_code, body.get_string_from_utf8().substr(0, 200),
	]), true)
	if owner != null and is_instance_valid(owner) and owner.has_method(method):
		owner.call(method, result, response_code, body)
	# 回调里可能又排了新请求（再 poll 等），统一由 _pump 接着发
	_pump()
	return
