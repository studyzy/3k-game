# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/clDictionary.gd
# 说明：词典/百科数据对象。管理游戏内置词典（人物、地名、名词）查询。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource
class_name DictionaryInfo

var _dic: Dictionary;

func _init(dic: Dictionary) -> void :
	_dic = dic;

func get_value(key):
	if _dic.has(key):
		return _dic[key];
	return null;
	
func set_value(key, value):
	_dic[key] = value;

func keys():
	return _dic.keys();

func values():
	return _dic.values();
