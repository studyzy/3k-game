# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/clEnv.gd
# 说明：环境变量对象。保存一组键值环境状态（类似字典）。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource



class_name Env

var data: Dictionary = {}

func unset_env(key: String) -> void :
	data.erase(key)
	return

func set_env(key: String, val) -> void :
	data[key] = val
	return

func get_int(key: String, defVal: int = - 1) -> int:
	if not key in data:
		return defVal
	return Global.intval(data[key], defVal)

func get_int_array(key: String) -> Array:
	if not key in data:
		return []
	return Global.intarrval(data[key])

func get_array(key: String) -> Array:
	if not key in data:
		return []
	return Global.arrval(data[key])

func get_dict(key: String) -> Dictionary:
	if not key in data:
		return {}
	return Global.dicval(data[key])

func to_save_data() -> Dictionary:
	return data.duplicate(true)

func from_save_data(val) -> void :
	data = Global.dicval(val)
	return
