extends Node
## 只读镜像（autoload: Mirror）
## 持有服务器下发的权威状态，UI 只读取，不允许写回。
## 服务器通过 S2C_Delta 增量更新，客户端据此渲染。

signal state_changed

var generals := {}   # id -> {field: value}
var cities := {}     # id -> {field: value}
var countries := {}  # id -> {field: value}
var game_info := {}
var war := {}        # 战争状态（服务器 S2C_WarStart/WarStep 更新）

## 应用服务器增量（delta body）
func apply_delta(body: Dictionary) -> void:
	var changed: Dictionary = body.get("changed", {})
	if changed.has("generals"):
		_merge(generals, changed.generals)
	if changed.has("cities"):
		_merge(cities, changed.cities)
	if changed.has("countries"):
		_merge(countries, changed.countries)
	if body.has("gameInfo"):
		var gi: Dictionary = body.gameInfo
		for k in gi:
			game_info[k] = gi[k]
	state_changed.emit()


## 合并字典（id -> 字段覆盖）
func _merge(target: Dictionary, source: Variant) -> void:
	if not source is Dictionary:
		return
	var src: Dictionary = source
	for id in src:
		if not target.has(id):
			target[id] = {}
		var fields: Dictionary = src[id]
		for f in fields:
			target[id][f] = fields[f]


## 获取某城对象（返回只读字典）
func get_city(city_id: int) -> Dictionary:
	return cities.get(str(city_id), {})


## 获取某武将对象
func get_general(gid: int) -> Dictionary:
	return generals.get(str(gid), {})


## 获取某势力对象
func get_country(cid: int) -> Dictionary:
	return countries.get(str(cid), {})


## 当前玩家势力
func player_country_id() -> int:
	return int(game_info.get("playerCountryId", 0))


## 当前操作城
func do_city_id() -> int:
	return int(game_info.get("doCityId", 0))


## 玩家剩余命令数
func player_order_num() -> int:
	return int(game_info.get("playerOrderNum", 0))


## 年月
func years() -> int: return int(game_info.get("years", 251))
func month() -> int: return int(game_info.get("month", 1))


## 应用战争状态（S2C_WarStart / S2C_WarStep）
func apply_war(body: Dictionary) -> void:
	war = body
	state_changed.emit()
