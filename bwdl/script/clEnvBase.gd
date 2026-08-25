# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/clEnvBase.gd
# 说明：环境对象基类。提供单位/环境共用的基础字段与公共方法。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource

func _intval(val, def: int = - 1) -> int:
	if val == null:
		return def
	match typeof(val):
		TYPE_INT: pass
		TYPE_REAL: pass
		TYPE_STRING: pass
		TYPE_BOOL: pass
		_: return def
	return int(val)

func _floatval(val, def: float = - 1.0) -> float:
	if val == null:
		return def
	match typeof(val):
		TYPE_INT: pass
		TYPE_REAL: pass
		TYPE_STRING: pass
		TYPE_BOOL: pass
		_: return def
	return float(val)

func _strval(val, def: String = "") -> String:
	if val == null:
		return def
	return str(val)

func _arrval(val) -> Array:
	match typeof(val):
		TYPE_STRING_ARRAY: pass
		TYPE_INT_ARRAY: pass
		TYPE_RAW_ARRAY: pass
		TYPE_ARRAY: pass
		TYPE_COLOR_ARRAY: pass
		TYPE_VECTOR2_ARRAY: pass
		TYPE_VECTOR3_ARRAY: pass
		TYPE_REAL_ARRAY: pass
		_: return []
	return Array(val)

func _intarrval(val) -> PoolIntArray:
	var ret = []
	for item in _arrval(val):
		ret.append(_intval(item))
	return ret

func check_env(keys: PoolStringArray) -> bool:
	for key in keys:
		if not DataManager.common_variable.has(key):
			return false
	return true

func unset_env(key: String) -> void :
	DataManager.common_variable.erase(key)
	return

func set_env(key: String, val):
	DataManager.common_variable[key] = val

func get_env(key: String):
	if not DataManager.common_variable.has(key):
		return null
	return DataManager.common_variable[key]

func get_env_int(key: String) -> int:
	return _intval(get_env(key))

func get_env_float(key: String) -> float:
	return _floatval(get_env(key))

func get_env_str(key: String) -> String:
	return _strval(get_env(key))

func get_env_array(key: String) -> Array:
	return _arrval(get_env(key))

func get_env_int_array(key: String) -> PoolIntArray:
	return _intarrval(get_env(key))

func get_env_dict(key: String) -> Array:
	var ret = {}
	var val = get_env(key)
	if typeof(val) != TYPE_DICTIONARY:
		return ret
	for k in val:
		ret[k] = val[k]
	return ret
