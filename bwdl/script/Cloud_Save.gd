# ==============================================================================
# 新增：云存档（网页版）
# 文件：script/Cloud_Save.gd
# 说明：负责 URL 里的云存档 ID、单槽上传、整包下载与合并。
#       仅在 HTML5 导出下启用；桌面/安卓上所有入口都是空操作。
#       设计：docs/superpowers/specs/2026-11-21-web-cloud-save-design.md
# ==============================================================================
extends Node

const ID_FILE = "user://sgz/cloud_id.txt"
const HTTP_TIMEOUT = 30
const SLOT_MIN = 0
const SLOT_MAX = 51

var enabled := false
var cloud_id := ""
var synced_slots := 0

var _http: HTTPRequest = null
var _busy := false
var _current := {}
var _pending_get := false
var _pending_put := {}
var _get_owner: Object = null
var _get_method := ""

func _ready() -> void:
	enabled = is_web()
	return

func is_web() -> bool:
	return OS.get_name() == "HTML5"

# ---- 纯逻辑（headless 可验证） ----

func is_valid_uuid(value: String) -> bool:
	var re = RegEx.new()
	re.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-4[0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
	return re.search(value) != null

# 显示编号为奇数的手动槽位才是网络存档，且必须落在 0..51。
func is_network_slot(slot: String) -> bool:
	if not slot.is_valid_integer():
		return false
	if str(int(slot)) != slot:
		return false
	var n = int(slot)
	return n >= SLOT_MIN and n <= SLOT_MAX and n % 2 == 1

# "YYYY-MM-DD HH:MM:SS" 定长格式，字符串比较即时间比较；空串视为最旧。
# 参数不能叫 remote：它是 GDScript 3 的 RPC 关键字，会直接 Parse Error。
func is_newer(remote_text: String, local_text: String) -> bool:
	if remote_text == "":
		return false
	if local_text == "":
		return true
	return remote_text > local_text

# ---- ID 与 URL ----

func ensure_id() -> String:
	if not enabled:
		return ""
	# 服务端只认小写 UUID，两个来源都先归一化再校验，避免大写链接每次启动被 400。
	var from_url = _id_from_url().to_lower()
	if is_valid_uuid(from_url):
		cloud_id = from_url
		_write_id(cloud_id)
		_replace_url_id(cloud_id)
		return cloud_id
	var stored = Global.get_file_text(ID_FILE).strip_edges().to_lower()
	if is_valid_uuid(stored):
		cloud_id = stored
		_replace_url_id(cloud_id)
		return cloud_id
	cloud_id = _new_uuid()
	_write_id(cloud_id)
	_replace_url_id(cloud_id)
	return cloud_id

func _id_from_url() -> String:
	if not enabled:
		return ""
	return String(JavaScript.eval(
		"(function(){try{var v=new URLSearchParams(location.search).get('save');return v?v:'';}catch(e){return '';}})()", true)).strip_edges()

func _replace_url_id(value: String) -> void:
	if not enabled:
		return
	# 用 URLSearchParams 回写，保留 URL 上的其它查询参数
	JavaScript.eval(
		"(function(){try{var u=new URLSearchParams(location.search);u.set('save','%s');history.replaceState(null,'',location.pathname+'?'+u.toString()+location.hash);}catch(e){}})()" % value, true)
	return

func _new_uuid() -> String:
	if enabled:
		var v = String(JavaScript.eval(
			"(function(){try{if(window.crypto&&crypto.randomUUID){return crypto.randomUUID();}}catch(e){}return '';})()", true))
		if is_valid_uuid(v):
			return v
	return _fallback_uuid()

# crypto.randomUUID 需要安全上下文（https/localhost），局域网 http 下用这个兜底。
func _fallback_uuid() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var hex = "0123456789abcdef"
	var parts = []
	for group in [8, 4, 4, 4, 12]:
		var s = ""
		for i in group:
			s += hex[rng.randi_range(0, 15)]
		parts.append(s)
	# v4 固定位：第 3 组首位是版本号 4，第 4 组首位是变体 8/9/a/b。
	var seg3 = "4" + parts[2].substr(1)
	var seg4 = "89ab"[rng.randi_range(0, 3)] + parts[3].substr(1)
	return "%s-%s-%s-%s-%s" % [parts[0], parts[1], seg3, seg4, parts[4]]

func _write_id(value: String) -> void:
	var dir = Directory.new()
	if not dir.dir_exists("user://sgz"):
		dir.make_dir_recursive("user://sgz")
	Global.save_file_text(ID_FILE, value)
	return

# ---- 上传 / 下载队列 ----

func begin_session(owner: Object, method: String) -> void:
	if not enabled:
		return
	if ensure_id() == "":
		return
	_get_owner = owner
	_get_method = method
	_pending_get = true
	_pump()
	return

func upload_slot(slot: String, save_path: String) -> void:
	if not enabled or cloud_id == "":
		return
	if not is_network_slot(slot):
		return
	# 只保留最后一次待办：上传途中又存了一次档，前一份已经过时
	_pending_put = {"kind": "put", "slot": slot, "path": save_path}
	_pump()
	return

func _pump() -> void:
	if _busy:
		return
	_start_next()
	return

# GET 与 PUT 各自排队，GET 优先；PUT 永远只保留最后一次。
func _start_next() -> void:
	if _pending_get:
		_pending_get = false
		_busy = true
		_current = {"kind": "get"}
		_request_get()
		return
	if not _pending_put.empty():
		var action = _pending_put
		_pending_put = {}
		_busy = true
		_current = action
		_request_put(action)
		return
	_busy = false
	return

func _request_get() -> void:
	if not _ensure_http():
		_finish_get({"ok": false, "slots": {}, "total": 0, "error": "http_unavailable"})
		return
	var url = _base_url() + "/save/" + cloud_id
	var err = _http.request(url, PoolStringArray(["Cache-Control: no-cache"]), true, HTTPClient.METHOD_GET, "")
	if err != OK:
		_finish_get({"ok": false, "slots": {}, "total": 0, "error": "request_failed"})
	return

func _request_put(action: Dictionary) -> void:
	var text = ""
	if _ensure_http():
		text = Global.get_file_text(action["path"])
	if text == "":
		SceneManager.show_system_notice("本地已保存，云端同步失败")
		_finish_put()
		return
	var url = _base_url() + "/save/" + cloud_id + "/" + str(action["slot"])
	var err = _http.request(url, PoolStringArray(["Content-Type: text/plain; charset=utf-8"]), true, HTTPClient.METHOD_PUT, text)
	if err != OK:
		SceneManager.show_system_notice("本地已保存，云端同步失败")
		_finish_put()
	return

func _finish_put() -> void:
	_busy = false
	_current = {}
	_start_next()
	return

func _finish_get(result: Dictionary) -> void:
	_current = {}
	# 先抄走回调目标并清字段：回调里可能重入 begin_session，不能把新值当旧值清掉。
	# _busy 保持 true 直到回调返回，避免回调里的 _pump() 起第二个请求。
	var owner_obj = _get_owner
	var owner_method = _get_method
	_get_owner = null
	_get_method = ""
	if owner_obj != null and owner_method != "" and is_instance_valid(owner_obj) and owner_obj.has_method(owner_method):
		owner_obj.call(owner_method, result)
	_busy = false
	_start_next()
	return

func _ensure_http() -> bool:
	if _http == null:
		_http = HTTPRequest.new()
		_http.connect("request_completed", self, "_on_completed")
		# 与 AIHttpClient 同因：/root 在场景搭建期间 busy，挂到已就绪的 SceneManager 下
		SceneManager.add_child(_http)
	if not _http.is_inside_tree():
		return false
	_http.timeout = HTTP_TIMEOUT
	return true

func _base_url() -> String:
	if not enabled:
		return ""
	return String(JavaScript.eval("window.location.origin", true))

func _on_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void:
	if not _busy:
		return
	var text = body.get_string_from_utf8()
	if str(_current.get("kind", "")) == "get":
		_handle_get(result, response_code, text)
		return
	_handle_put(result, response_code, text)
	return

func _handle_get(result: int, code: int, text: String) -> void:
	if result != 0:
		_finish_get({"ok": false, "slots": {}, "total": 0, "error": "network"})
		return
	if code == 404:
		synced_slots = 0
		_finish_get({"ok": true, "slots": {}, "total": 0, "error": ""})
		return
	var data = parse_json(text)
	if code != 200 or typeof(data) != TYPE_DICTIONARY:
		_finish_get({"ok": false, "slots": {}, "total": 0, "error": "bad_response"})
		return
	var slots = Global.dic_val(data, "slots", {})
	if typeof(slots) != TYPE_DICTIONARY:
		slots = {}
	var total = int(Global.dic_val(data, "syncedSlots", slots.size()))
	synced_slots = total
	_finish_get({"ok": true, "slots": slots, "total": total, "error": ""})
	return

func _handle_put(result: int, code: int, text: String) -> void:
	if result == 0 and code == 200:
		var data = parse_json(text)
		if typeof(data) == TYPE_DICTIONARY:
			synced_slots = int(Global.dic_val(data, "syncedSlots", synced_slots))
		SceneManager.show_system_notice("网络存档已同步（共{0}个）".format([synced_slots]))
	else:
		SceneManager.show_system_notice("本地已保存，云端同步失败")
	_finish_put()
	return

# ---- 合并 / 展示 ----

# 只处理单数槽位；云端较新才覆盖本地，覆盖前把旧档留成 .sav.bak。
func merge_into_local(slots: Dictionary) -> Dictionary:
	if not enabled:
		return {"total": 0, "restored": 0, "kept": 0}
	var dir_path = DataManager.get_common_path() + "save/"
	var d = Directory.new()
	if not d.dir_exists(dir_path):
		d.make_dir_recursive(dir_path)

	var total = 0
	var restored = 0
	var kept = 0
	for key in slots.keys():
		var slot = str(key)
		if not is_network_slot(slot):
			continue
		var data = slots[key]
		if typeof(data) != TYPE_DICTIONARY:
			continue
		total += 1
		var remote_time = str(Global.dic_val(data, "存档时间", ""))
		var path = dir_path + slot + ".sav"
		var local_text = Global.get_file_text(path)
		var local_time = ""
		if local_text != "":
			var local_data = parse_json(local_text)
			if typeof(local_data) == TYPE_DICTIONARY:
				local_time = str(Global.dic_val(local_data, "存档时间", ""))
		if local_text == "" or is_newer(remote_time, local_time):
			# 备份失败就不覆盖：宁可留旧档，也不能把唯一的本地存档写坏。
			var wrote = true
			if local_text != "":
				wrote = Global.save_file_text(path + ".bak", local_text)
			if wrote:
				wrote = Global.save_file_text(path, JSON.print(data))
			if wrote:
				StaticManager.saveIdx.update_save_index(slot)
				restored += 1
			else:
				# 写盘失败：保持索引原样（不要 erase 缓存，下次还会读到本地旧档）
				kept += 1
		else:
			kept += 1
	return {"total": total, "restored": restored, "kept": kept}

func get_synced_count() -> int:
	return synced_slots

func copy_link() -> void:
	if not enabled:
		return
	var url = String(JavaScript.eval("location.href", true))
	var ok = String(JavaScript.eval(
		"(function(){try{if(window.isSecureContext&&navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(location.href).catch(function(){});return '1';}}catch(e){}return '0';})()", true))
	if ok == "1":
		SceneManager.show_system_notice("链接已复制")
		return
	# 非安全上下文（局域网 http）拿不到 clipboard，退化成手动复制
	SceneManager.confirm("请手动复制下面的链接：\n" + url, null, "", Vector2(420, 260), "知道了", "关闭")
	return