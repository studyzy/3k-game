extends Resource
class_name StringBuilder

var __str: PoolStringArray = [];

func _init(_str: String = "") -> void :
	if (_str == ""):
		return ;
	__str = [_str];
	pass

func clear():
	__str = [];
	
func append(_str: String):
	if (_str == ""):
		return ;
	__str.append(_str);
	
func insert(p: int, _str: String):
	if (_str == ""):
		return ;
	__str.insert(p, _str);

func to_string(join_str: String = "") -> String:
	return join_str.join(__str);

func empty() -> bool:
	return __str.size() == 0;

func size() -> int:
	return __str.size();
