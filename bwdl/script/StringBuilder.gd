# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/StringBuilder.gd
# 说明：字符串拼接工具类。提供高效的字符串累加。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

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
