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
